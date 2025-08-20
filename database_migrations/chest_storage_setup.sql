-- Chest Storage Setup Migration
-- This migration ensures the game_objects table is properly configured for chest storage

-- Enable real-time for game_objects table if not already enabled
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'game_objects'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE game_objects;
    END IF;
END $$;

-- Ensure game_objects table has the required structure
-- (This should already exist, but we'll add any missing columns)

-- Add last_updated_by column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'game_objects' 
        AND column_name = 'last_updated_by'
    ) THEN
        ALTER TABLE game_objects ADD COLUMN last_updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Add version column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'game_objects' 
        AND column_name = 'version'
    ) THEN
        ALTER TABLE game_objects ADD COLUMN version INTEGER DEFAULT 1;
    END IF;
END $$;

-- Add sync_status column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'game_objects' 
        AND column_name = 'sync_status'
    ) THEN
        ALTER TABLE game_objects ADD COLUMN sync_status VARCHAR DEFAULT 'synced';
    END IF;
END $$;

-- Create index for efficient chest queries
CREATE INDEX IF NOT EXISTS idx_game_objects_couple_type 
ON game_objects(couple_id, type) 
WHERE type = 'chest';

-- Create index for position-based queries
CREATE INDEX IF NOT EXISTS idx_game_objects_position 
ON game_objects USING GIST(position) 
WHERE type = 'chest';

-- Create function to move items between chests (for future use)
CREATE OR REPLACE FUNCTION move_items_between_chests(
    from_chest_id UUID,
    to_chest_id UUID,
    item_id TEXT,
    quantity INTEGER,
    user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    from_chest_data JSONB;
    to_chest_data JSONB;
    from_items JSONB;
    to_items JSONB;
    item_to_move JSONB;
    item_index INTEGER;
    new_quantity INTEGER;
BEGIN
    -- Get the source chest
    SELECT properties INTO from_chest_data
    FROM game_objects
    WHERE id = from_chest_id AND type = 'chest';
    
    IF from_chest_data IS NULL THEN
        RAISE EXCEPTION 'Source chest not found';
    END IF;
    
    -- Get the destination chest
    SELECT properties INTO to_chest_data
    FROM game_objects
    WHERE id = to_chest_id AND type = 'chest';
    
    IF to_chest_data IS NULL THEN
        RAISE EXCEPTION 'Destination chest not found';
    END IF;
    
    -- Extract items arrays
    from_items := from_chest_data->'items';
    to_items := to_chest_data->'items';
    
    -- Find the item in source chest
    item_index := -1;
    FOR i IN 0..jsonb_array_length(from_items) - 1 LOOP
        IF (from_items->i->>'id') = item_id THEN
            item_index := i;
            EXIT;
        END IF;
    END LOOP;
    
    IF item_index = -1 THEN
        RAISE EXCEPTION 'Item not found in source chest';
    END IF;
    
    item_to_move := from_items->item_index;
    new_quantity := (item_to_move->>'quantity')::INTEGER - quantity;
    
    IF new_quantity < 0 THEN
        RAISE EXCEPTION 'Not enough items in source chest';
    END IF;
    
    -- Update source chest
    IF new_quantity = 0 THEN
        -- Remove item completely
        from_items := from_items - item_index;
    ELSE
        -- Update quantity
        from_items := jsonb_set(from_items, ARRAY[item_index::TEXT, 'quantity'], to_jsonb(new_quantity));
    END IF;
    
    -- Update destination chest
    -- Check if item already exists
    item_index := -1;
    FOR i IN 0..jsonb_array_length(to_items) - 1 LOOP
        IF (to_items->i->>'id') = item_id THEN
            item_index := i;
            EXIT;
        END IF;
    END LOOP;
    
    IF item_index = -1 THEN
        -- Add new item
        to_items := to_items || jsonb_build_object(
            'id', item_id,
            'name', item_to_move->>'name',
            'quantity', quantity,
            'description', item_to_move->>'description'
        );
    ELSE
        -- Update existing item quantity
        new_quantity := (to_items->item_index->>'quantity')::INTEGER + quantity;
        to_items := jsonb_set(to_items, ARRAY[item_index::TEXT, 'quantity'], to_jsonb(new_quantity));
    END IF;
    
    -- Update both chests in a transaction
    UPDATE game_objects
    SET 
        properties = jsonb_set(properties, ARRAY['items'], from_items),
        updated_at = NOW(),
        version = version + 1,
        last_updated_by = user_id
    WHERE id = from_chest_id;
    
    UPDATE game_objects
    SET 
        properties = jsonb_set(properties, ARRAY['items'], to_items),
        updated_at = NOW(),
        version = version + 1,
        last_updated_by = user_id
    WHERE id = to_chest_id;
    
END;
$$;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION move_items_between_chests(UUID, UUID, TEXT, INTEGER, UUID) TO authenticated;

-- Create trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_game_objects_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- Create the trigger if it doesn't exist
DROP TRIGGER IF EXISTS trigger_update_game_objects_updated_at ON game_objects;
CREATE TRIGGER trigger_update_game_objects_updated_at
    BEFORE UPDATE ON game_objects
    FOR EACH ROW
    EXECUTE FUNCTION update_game_objects_updated_at();

-- Ensure RLS is enabled and policies are in place
ALTER TABLE game_objects ENABLE ROW LEVEL SECURITY;

-- Policy for users to see game objects from their couples
CREATE POLICY IF NOT EXISTS "Users can view game objects from their couples"
ON game_objects FOR SELECT
USING (
    couple_id IN (
        SELECT id FROM couples 
        WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
);

-- Policy for users to insert game objects for their couples
CREATE POLICY IF NOT EXISTS "Users can insert game objects for their couples"
ON game_objects FOR INSERT
WITH CHECK (
    couple_id IN (
        SELECT id FROM couples 
        WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
);

-- Policy for users to update game objects for their couples
CREATE POLICY IF NOT EXISTS "Users can update game objects for their couples"
ON game_objects FOR UPDATE
USING (
    couple_id IN (
        SELECT id FROM couples 
        WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
)
WITH CHECK (
    couple_id IN (
        SELECT id FROM couples 
        WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
);

-- Policy for users to delete game objects for their couples
CREATE POLICY IF NOT EXISTS "Users can delete game objects for their couples"
ON game_objects FOR DELETE
USING (
    couple_id IN (
        SELECT id FROM couples 
        WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
);

-- Insert some sample chests for testing (optional)
-- Uncomment the following lines if you want to create test chests

/*
INSERT INTO game_objects (id, couple_id, type, position, properties, created_at, updated_at, version, sync_status)
SELECT 
    gen_random_uuid(),
    c.id,
    'chest',
    point(100, 100),
    '{"items": [], "maxCapacity": 20, "name": "Main Storage Chest"}'::jsonb,
    NOW(),
    NOW(),
    1,
    'synced'
FROM couples c
WHERE NOT EXISTS (
    SELECT 1 FROM game_objects 
    WHERE couple_id = c.id AND type = 'chest'
    LIMIT 1
);
*/ 