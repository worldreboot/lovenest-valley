-- Setup script for Daily Questions System
-- Run this in your Supabase SQL Editor

-- 1. Create a function to automatically assign daily questions at midnight UTC
-- Note: This requires setting up cron jobs in Supabase Dashboard

-- Simple test function that simulates daily question assignment
CREATE OR REPLACE FUNCTION test_assign_daily_questions()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_count integer;
  question_count integer;
  assignment_count integer;
  random_user_id uuid;
  random_question_id uuid;
  test_date timestamptz;
BEGIN
  -- Get counts
  SELECT COUNT(*) INTO user_count FROM profiles WHERE username IS NOT NULL;
  SELECT COUNT(*) INTO question_count FROM questions;

  -- Set test date
  test_date := CURRENT_DATE AT TIME ZONE 'UTC';

  -- Simulate assignment for testing (only if no real assignments exist today)
  IF NOT EXISTS (
    SELECT 1 FROM user_questions
    WHERE received_at >= test_date
    AND received_at < test_date + interval '1 day'
  ) THEN
    -- Get a random user
    SELECT id INTO random_user_id
    FROM profiles
    WHERE username IS NOT NULL
    ORDER BY RANDOM()
    LIMIT 1;

    -- Get a random question
    SELECT id INTO random_question_id
    FROM questions
    ORDER BY RANDOM()
    LIMIT 1;

    -- Create a test assignment
    INSERT INTO user_questions (user_id, question_id, received_at, answered)
    VALUES (random_user_id, random_question_id, test_date + interval '1 hour', false);

    assignment_count := 1;
  ELSE
    assignment_count := 0;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Test assignment simulation completed',
    'user_count', user_count,
    'question_count', question_count,
    'test_assignments_created', assignment_count,
    'test_date', test_date
  );
END;
$$;

-- Function to test the daily question reminder logic
CREATE OR REPLACE FUNCTION test_daily_question_reminder()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  pending_count integer;
  couple_count integer;
  solo_count integer;
  test_date timestamptz;
BEGIN
  -- Set test date
  test_date := CURRENT_DATE AT TIME ZONE 'UTC';

  -- Count pending questions
  SELECT COUNT(*) INTO pending_count
  FROM user_questions
  WHERE answered = false
  AND received_at >= test_date
  AND received_at < test_date + interval '1 day';

  -- Count couples and solo users with pending questions
  SELECT
    COUNT(DISTINCT CASE WHEN c.id IS NOT NULL THEN c.id END) as couple_groups,
    COUNT(DISTINCT CASE WHEN c.id IS NULL THEN uq.user_id END) as solo_users
  INTO couple_count, solo_count
  FROM user_questions uq
  LEFT JOIN couples c ON uq.user_id IN (c.user1_id, c.user2_id)
  WHERE uq.answered = false
  AND uq.received_at >= test_date
  AND uq.received_at < test_date + interval '1 day';

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Daily question reminder test completed',
    'pending_questions', pending_count,
    'couple_groups', couple_count,
    'solo_users', solo_count,
    'test_date', test_date,
    'would_send_notifications', pending_count > 0
  );
END;
$$;

-- Function to get daily question stats
CREATE OR REPLACE FUNCTION get_daily_question_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  today_start timestamptz;
  today_end timestamptz;
  stats jsonb;
BEGIN
  -- Get today's date range
  today_start := date_trunc('day', now() AT TIME ZONE 'UTC');
  today_end := today_start + interval '1 day';

  SELECT jsonb_build_object(
    'total_questions', (SELECT COUNT(*) FROM questions),
    'assigned_today', (
      SELECT COUNT(*)
      FROM user_questions
      WHERE received_at >= today_start AND received_at < today_end
    ),
    'answered_today', (
      SELECT COUNT(*)
      FROM user_daily_question_answers
      WHERE created_at >= today_start AND created_at < today_end
    ),
    'pending_answers', (
      SELECT COUNT(*)
      FROM user_questions
      WHERE received_at >= today_start
        AND received_at < today_end
        AND (answered = false OR answered IS NULL)
    ),
    'push_subscriptions', (
      SELECT COUNT(*)
      FROM push_subscriptions
    )
  ) INTO stats;

  RETURN stats;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION test_assign_daily_questions() TO authenticated;
GRANT EXECUTE ON FUNCTION test_daily_question_reminder() TO authenticated;
GRANT EXECUTE ON FUNCTION get_daily_question_stats() TO authenticated;

-- Add some test questions if none exist
INSERT INTO questions (text) VALUES
  ('What''s something you''re looking forward to this week?'),
  ('What''s a skill you''d love to learn or improve?'),
  ('What''s your favorite way to relax after a long day?'),
  ('What''s a memory that always makes you smile?'),
  ('What''s something you''re grateful for right now?'),
  ('What''s your favorite season and why?'),
  ('What''s a hobby you''d like to pick up?'),
  ('What''s the best piece of advice you''ve ever received?'),
  ('What''s something that made you laugh recently?'),
  ('What''s a goal you''re working toward?')
ON CONFLICT DO NOTHING;

COMMENT ON FUNCTION test_assign_daily_questions() IS 'Test function to manually trigger daily question assignment';
COMMENT ON FUNCTION test_daily_question_reminder() IS 'Test function to manually trigger daily question reminders';
COMMENT ON FUNCTION get_daily_question_stats() IS 'Get statistics about daily question system';
