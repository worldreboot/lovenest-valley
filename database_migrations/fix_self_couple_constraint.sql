-- Fix: Add CHECK constraint to prevent users from being coupled with themselves
-- This prevents the serious bug where a user could be both user1_id and user2_id

-- Add CHECK constraint to prevent self-couples
ALTER TABLE couples 
ADD CONSTRAINT couples_no_self_coupling 
CHECK (user1_id != user2_id);

-- Add comment explaining the constraint
COMMENT ON CONSTRAINT couples_no_self_coupling ON couples 
IS 'Prevents users from being coupled with themselves (user1_id cannot equal user2_id)';

-- Verify the constraint was added
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'couples'::regclass 
AND conname = 'couples_no_self_coupling';
