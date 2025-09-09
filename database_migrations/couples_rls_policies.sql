-- Couples table RLS policies migration
-- This fixes the "new row violates row-level security policy" error when accepting invites

-- Ensure couples table exists and has proper structure
CREATE TABLE IF NOT EXISTS couples (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user1_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    user2_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(user1_id, user2_id),
    -- Critical constraint: Prevent users from being coupled with themselves
    CHECK (user1_id != user2_id)
);

-- Enable RLS on couples table
ALTER TABLE couples ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS couples_select_policy ON couples;
DROP POLICY IF EXISTS couples_insert_policy ON couples;
DROP POLICY IF EXISTS couples_update_policy ON couples;
DROP POLICY IF EXISTS couples_delete_policy ON couples;

-- RLS Policy for couples table - users can only see couples they're part of
CREATE POLICY couples_select_policy ON couples
    FOR SELECT
    USING (user1_id = auth.uid() OR user2_id = auth.uid());

-- RLS Policy for couples table - users can insert couples where they are user1_id or user2_id
CREATE POLICY couples_insert_policy ON couples
    FOR INSERT
    WITH CHECK (user1_id = auth.uid() OR user2_id = auth.uid());

-- RLS Policy for couples table - users can update couples they're part of
CREATE POLICY couples_update_policy ON couples
    FOR UPDATE
    USING (user1_id = auth.uid() OR user2_id = auth.uid())
    WITH CHECK (user1_id = auth.uid() OR user2_id = auth.uid());

-- RLS Policy for couples table - users can delete couples they're part of
CREATE POLICY couples_delete_policy ON couples
    FOR DELETE
    USING (user1_id = auth.uid() OR user2_id = auth.uid());

-- Grant necessary permissions on couples table
GRANT ALL ON couples TO authenticated;

-- Create index for better performance on couple lookups
CREATE INDEX IF NOT EXISTS idx_couples_user1_id ON couples(user1_id);
CREATE INDEX IF NOT EXISTS idx_couples_user2_id ON couples(user2_id);
CREATE INDEX IF NOT EXISTS idx_couples_users ON couples(user1_id, user2_id);

-- Comments for documentation
COMMENT ON TABLE couples IS 'Stores couple relationships between users';
COMMENT ON COLUMN couples.user1_id IS 'First user in the couple relationship';
COMMENT ON COLUMN couples.user2_id IS 'Second user in the couple relationship';
COMMENT ON COLUMN couples.created_at IS 'When the couple relationship was established'; 