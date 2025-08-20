-- Currency and Bloom Reward Setup Migration

-- 1) profiles.coins column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'profiles' AND column_name = 'coins'
  ) THEN
    ALTER TABLE profiles
      ADD COLUMN coins INTEGER NOT NULL DEFAULT 0;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_profiles_coins ON profiles(coins);

-- 2) coin_transactions table
CREATE TABLE IF NOT EXISTS coin_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL,
  reason TEXT NOT NULL,
  idempotency_key TEXT UNIQUE,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE coin_transactions ENABLE ROW LEVEL SECURITY;

-- Users can view their own transactions (create if missing)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' AND tablename = 'coin_transactions' AND policyname = 'Users can view their own coin transactions'
  ) THEN
    CREATE POLICY "Users can view their own coin transactions"
    ON coin_transactions FOR SELECT
    USING (user_id = auth.uid());
  END IF;
END $$;

-- 3) Award coins helper (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION award_bloom_coins(
  p_user_id UUID,
  p_idempotency_key TEXT,
  p_amount INTEGER DEFAULT 100
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  -- Insert transaction only if not already awarded
  INSERT INTO coin_transactions(user_id, amount, reason, idempotency_key)
  VALUES (p_user_id, p_amount, 'bloom_reward', p_idempotency_key)
  ON CONFLICT (idempotency_key) DO NOTHING;

  IF FOUND THEN
    UPDATE profiles SET coins = coins + p_amount WHERE id = p_user_id;
  END IF;
END;
$$;

-- 4) Spend coins RPC (atomic)
CREATE OR REPLACE FUNCTION spend_coins(
  p_amount INTEGER,
  p_reason TEXT DEFAULT 'purchase',
  p_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS TABLE(success BOOLEAN, new_balance INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_new_balance INTEGER;
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, NULL;
    RETURN;
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN QUERY SELECT FALSE, (SELECT coins FROM profiles WHERE id = v_user_id);
    RETURN;
  END IF;

  UPDATE profiles
  SET coins = coins - p_amount
  WHERE id = v_user_id AND coins >= p_amount
  RETURNING coins INTO v_new_balance;

  IF v_new_balance IS NULL THEN
    RETURN QUERY SELECT FALSE, (SELECT coins FROM profiles WHERE id = v_user_id);
    RETURN;
  END IF;

  INSERT INTO coin_transactions(user_id, amount, reason, metadata)
  VALUES (v_user_id, -p_amount, COALESCE(p_reason, 'purchase'), COALESCE(p_metadata, '{}'::jsonb));

  RETURN QUERY SELECT TRUE, v_new_balance;
END;
$$;

GRANT EXECUTE ON FUNCTION spend_coins(INTEGER, TEXT, JSONB) TO authenticated;

-- 5) Triggers to award coins when seeds/tiles bloom

-- Helper: create trigger function for farm_seeds
CREATE OR REPLACE FUNCTION trg_award_bloom_on_farm_seeds()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_key TEXT;
BEGIN
  IF NEW.growth_stage = 'fully_grown' AND (OLD.growth_stage IS DISTINCT FROM 'fully_grown') THEN
    v_key := 'farm_seeds:' || NEW.farm_id || ':' || NEW.user_id || ':' || NEW.x || ':' || NEW.y;
    PERFORM award_bloom_coins(NEW.user_id, v_key, 100);
  END IF;
  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'farm_seeds'
  ) THEN
    DROP TRIGGER IF EXISTS trigger_award_bloom_on_farm_seeds ON farm_seeds;
    CREATE TRIGGER trigger_award_bloom_on_farm_seeds
      AFTER UPDATE ON farm_seeds
      FOR EACH ROW
      EXECUTE FUNCTION trg_award_bloom_on_farm_seeds();
  END IF;
END $$;

-- Helper: create trigger function for farm_tiles (derive user via farms.owner_id)
CREATE OR REPLACE FUNCTION trg_award_bloom_on_farm_tiles()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_key TEXT;
BEGIN
  IF NEW.growth_stage = 'fully_grown' AND (OLD.growth_stage IS DISTINCT FROM 'fully_grown') THEN
    SELECT owner_id INTO v_user_id FROM farms WHERE id = NEW.farm_id;
    IF v_user_id IS NOT NULL THEN
      v_key := 'farm_tiles:' || NEW.farm_id || ':' || NEW.x || ':' || NEW.y;
      PERFORM award_bloom_coins(v_user_id, v_key, 100);
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'farm_tiles'
  ) THEN
    DROP TRIGGER IF EXISTS trigger_award_bloom_on_farm_tiles ON farm_tiles;
    CREATE TRIGGER trigger_award_bloom_on_farm_tiles
      AFTER UPDATE ON farm_tiles
      FOR EACH ROW
      EXECUTE FUNCTION trg_award_bloom_on_farm_tiles();
  END IF;
END $$;


