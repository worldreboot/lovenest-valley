-- Test script for starter items tracking migration
-- Run this after applying the migration to verify it works

-- 1. Check if the column was added
SELECT 
  column_name, 
  data_type, 
  is_nullable, 
  column_default
FROM information_schema.columns 
WHERE table_name = 'profiles' 
  AND column_name = 'has_received_starter_items';

-- 2. Check current values for existing users
SELECT 
  id,
  username,
  has_received_starter_items,
  created_at
FROM profiles 
LIMIT 5;

-- 3. Test updating a user to mark them as having received starter items
-- (Replace 'your-user-id-here' with an actual user ID from your profiles table)
-- UPDATE profiles 
-- SET has_received_starter_items = true 
-- WHERE id = 'your-user-id-here';

-- 4. Verify the update worked
-- SELECT id, username, has_received_starter_items FROM profiles WHERE id = 'your-user-id-here';

-- 5. Check the index was created
SELECT 
  indexname, 
  indexdef 
FROM pg_indexes 
WHERE tablename = 'profiles' 
  AND indexname LIKE '%starter_items%';
