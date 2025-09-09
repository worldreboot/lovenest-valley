-- Add starter items tracking to profiles table
-- This ensures starter items are only given once per user

-- Add column to track if user has received starter items
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'has_received_starter_items'
  ) THEN
    ALTER TABLE profiles
      ADD COLUMN has_received_starter_items BOOLEAN NOT NULL DEFAULT FALSE;
  END IF;
END $$;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_profiles_starter_items ON profiles(has_received_starter_items);

-- Add comment for documentation
COMMENT ON COLUMN profiles.has_received_starter_items IS 'Tracks whether user has received their initial starter items (hoe, watering can, chest)';

-- Grant permissions (profiles table should already have RLS enabled)
-- No additional grants needed as this is just a new column on existing table
