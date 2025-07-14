-- Enhanced sync schema for Memory Garden
-- This extends the existing schema with sync optimization and conflict resolution

-- Sync events table for coordinating real-time updates
CREATE TABLE IF NOT EXISTS garden_sync_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL, -- 'batch_update_start', 'batch_update_end', 'conflict_resolution'
    event_data JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW() + INTERVAL '5 minutes'
);

-- Conflict resolution table
CREATE TABLE IF NOT EXISTS garden_conflicts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_id UUID NOT NULL REFERENCES couples(id) ON DELETE CASCADE,
    plot_position POINT NOT NULL,
    conflicting_seed_ids UUID[] NOT NULL,
    conflict_type VARCHAR(50) NOT NULL DEFAULT 'position_overlap',
    resolution_strategy VARCHAR(50), -- 'first_wins', 'merge', 'relocate'
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    resolution_data JSONB DEFAULT '{}'
);

-- Enhance existing seeds table with sync tracking
ALTER TABLE seeds ADD COLUMN IF NOT EXISTS last_updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE seeds ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE seeds ADD COLUMN IF NOT EXISTS sync_status VARCHAR(20) NOT NULL DEFAULT 'synced'; -- 'synced', 'pending', 'conflict'

-- Enhance existing waters_and_replies table with sync tracking
ALTER TABLE waters_and_replies ADD COLUMN IF NOT EXISTS last_updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE waters_and_replies ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE waters_and_replies ADD COLUMN IF NOT EXISTS sync_status VARCHAR(20) NOT NULL DEFAULT 'synced';

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_garden_sync_events_couple_id ON garden_sync_events(couple_id);
CREATE INDEX IF NOT EXISTS idx_garden_sync_events_created_at ON garden_sync_events(created_at);
CREATE INDEX IF NOT EXISTS idx_garden_sync_events_expires_at ON garden_sync_events(expires_at);
CREATE INDEX IF NOT EXISTS idx_garden_conflicts_couple_id ON garden_conflicts(couple_id);
CREATE INDEX IF NOT EXISTS idx_garden_conflicts_resolved_at ON garden_conflicts(resolved_at);
CREATE INDEX IF NOT EXISTS idx_seeds_last_updated_by ON seeds(last_updated_by);
CREATE INDEX IF NOT EXISTS idx_seeds_version ON seeds(version);
CREATE INDEX IF NOT EXISTS idx_seeds_sync_status ON seeds(sync_status);

-- Cleanup function for expired sync events
CREATE OR REPLACE FUNCTION cleanup_expired_sync_events()
RETURNS void AS $$
BEGIN
    DELETE FROM garden_sync_events 
    WHERE expires_at < NOW() - INTERVAL '1 hour';
END;
$$ LANGUAGE plpgsql;

-- Trigger to update version on seed updates
CREATE OR REPLACE FUNCTION update_seed_version()
RETURNS TRIGGER AS $$
BEGIN
    NEW.version = OLD.version + 1;
    NEW.last_updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply version trigger to seeds table
DROP TRIGGER IF EXISTS seeds_version_trigger ON seeds;
CREATE TRIGGER seeds_version_trigger
    BEFORE UPDATE ON seeds
    FOR EACH ROW
    EXECUTE FUNCTION update_seed_version();

-- Trigger to update version on water_reply updates
CREATE OR REPLACE FUNCTION update_water_reply_version()
RETURNS TRIGGER AS $$
BEGIN
    NEW.version = OLD.version + 1;
    NEW.created_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply version trigger to waters_and_replies table
DROP TRIGGER IF EXISTS waters_replies_version_trigger ON waters_and_replies;
CREATE TRIGGER waters_replies_version_trigger
    BEFORE UPDATE ON waters_and_replies
    FOR EACH ROW
    EXECUTE FUNCTION update_water_reply_version();

-- Function to detect and handle position conflicts
CREATE OR REPLACE FUNCTION detect_position_conflict()
RETURNS TRIGGER AS $$
DECLARE
    conflict_count INTEGER;
    conflict_ids UUID[];
BEGIN
    -- Check for existing seeds at the same position
    SELECT 
        COUNT(*),
        ARRAY_AGG(id)
    INTO 
        conflict_count,
        conflict_ids
    FROM seeds 
    WHERE 
        couple_id = NEW.couple_id 
        AND plot_position = NEW.plot_position
        AND id != NEW.id
        AND created_at >= NOW() - INTERVAL '30 seconds';
    
    -- If conflict detected, log it
    IF conflict_count > 0 THEN
        INSERT INTO garden_conflicts (
            couple_id,
            plot_position,
            conflicting_seed_ids,
            conflict_type
        ) VALUES (
            NEW.couple_id,
            NEW.plot_position,
            conflict_ids || NEW.id,
            'position_overlap'
        );
        
        -- Mark conflicting seeds
        UPDATE seeds 
        SET sync_status = 'conflict'
        WHERE id = ANY(conflict_ids || NEW.id);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply conflict detection trigger
DROP TRIGGER IF EXISTS seeds_conflict_trigger ON seeds;
CREATE TRIGGER seeds_conflict_trigger
    AFTER INSERT ON seeds
    FOR EACH ROW
    EXECUTE FUNCTION detect_position_conflict();

-- Row Level Security (RLS) policies
ALTER TABLE garden_sync_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE garden_conflicts ENABLE ROW LEVEL SECURITY;

-- Policy for garden_sync_events - users can only see events for their couple
CREATE POLICY garden_sync_events_policy ON garden_sync_events
    FOR ALL
    USING (
        couple_id IN (
            SELECT id FROM couples 
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );

-- Policy for garden_conflicts - users can only see conflicts for their couple
CREATE POLICY garden_conflicts_policy ON garden_conflicts
    FOR ALL
    USING (
        couple_id IN (
            SELECT id FROM couples 
            WHERE user1_id = auth.uid() OR user2_id = auth.uid()
        )
    );

-- Grant necessary permissions
GRANT ALL ON garden_sync_events TO authenticated;
GRANT ALL ON garden_conflicts TO authenticated;

-- Scheduled cleanup of expired sync events (requires pg_cron extension)
-- SELECT cron.schedule('cleanup-sync-events', '0 * * * *', 'SELECT cleanup_expired_sync_events();');

-- Views for easier querying
CREATE OR REPLACE VIEW garden_sync_summary AS
SELECT 
    c.id as couple_id,
    c.user1_id,
    c.user2_id,
    COUNT(s.id) as total_seeds,
    COUNT(CASE WHEN s.sync_status = 'synced' THEN 1 END) as synced_seeds,
    COUNT(CASE WHEN s.sync_status = 'pending' THEN 1 END) as pending_seeds,
    COUNT(CASE WHEN s.sync_status = 'conflict' THEN 1 END) as conflict_seeds,
    COUNT(gc.id) as unresolved_conflicts,
    MAX(s.last_updated_at) as last_activity
FROM couples c
LEFT JOIN seeds s ON c.id = s.couple_id
LEFT JOIN garden_conflicts gc ON c.id = gc.couple_id AND gc.resolved_at IS NULL
GROUP BY c.id, c.user1_id, c.user2_id;

-- Grant access to the view
GRANT SELECT ON garden_sync_summary TO authenticated;

-- Function to get conflict-free position suggestions
CREATE OR REPLACE FUNCTION suggest_empty_positions(
    target_couple_id UUID,
    center_x FLOAT,
    center_y FLOAT,
    max_radius INTEGER DEFAULT 3
)
RETURNS TABLE(x FLOAT, y FLOAT, distance FLOAT) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pos.x::FLOAT,
        pos.y::FLOAT,
        SQRT(POWER(pos.x - center_x, 2) + POWER(pos.y - center_y, 2)) as distance
    FROM (
        SELECT 
            generate_series(
                GREATEST(0, FLOOR(center_x - max_radius)::INTEGER),
                LEAST(9, CEIL(center_x + max_radius)::INTEGER)
            ) as x,
            generate_series(
                GREATEST(0, FLOOR(center_y - max_radius)::INTEGER),
                LEAST(9, CEIL(center_y + max_radius)::INTEGER)
            ) as y
    ) pos
    WHERE NOT EXISTS (
        SELECT 1 FROM seeds s 
        WHERE s.couple_id = target_couple_id 
        AND s.plot_position = POINT(pos.x, pos.y)
    )
    ORDER BY distance ASC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- Comments for documentation
COMMENT ON TABLE garden_sync_events IS 'Tracks real-time sync events for coordinating updates between partners';
COMMENT ON TABLE garden_conflicts IS 'Logs and tracks resolution of conflicts like overlapping seed positions';
COMMENT ON COLUMN seeds.last_updated_by IS 'User who last updated this seed for conflict resolution';
COMMENT ON COLUMN seeds.version IS 'Version number for optimistic locking and conflict detection';
COMMENT ON COLUMN seeds.sync_status IS 'Current sync status: synced, pending, or conflict';
COMMENT ON FUNCTION suggest_empty_positions IS 'Suggests nearby empty positions for conflict resolution'; 