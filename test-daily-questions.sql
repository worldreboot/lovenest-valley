-- Test script for Daily Questions System
-- Run these queries in your Supabase SQL Editor

-- 1. First, test the basic stats
SELECT get_daily_question_stats();

-- 2. Test question assignment simulation
SELECT test_assign_daily_questions();

-- 3. Test reminder simulation
SELECT test_daily_question_reminder();

-- 4. Check what questions were assigned today
SELECT
  uq.id,
  p.username,
  q.text as question,
  uq.received_at,
  uq.answered
FROM user_questions uq
JOIN profiles p ON uq.user_id = p.id
JOIN questions q ON uq.question_id = q.id
WHERE uq.received_at >= CURRENT_DATE AT TIME ZONE 'UTC'
ORDER BY uq.received_at DESC;

-- 5. Check push subscriptions
SELECT
  p.username,
  ps.platform,
  ps.token,
  ps.created_at
FROM push_subscriptions ps
LEFT JOIN profiles p ON ps.user_id = p.id
ORDER BY ps.created_at DESC;

-- 6. To test the actual Edge Functions, you can run these commands in your terminal:
-- Replace YOUR_PROJECT_URL and YOUR_ANON_KEY with your actual values

-- Test assignment function:
-- curl -X POST "https://YOUR_PROJECT_URL/functions/v1/assign-daily-questions" \
--   -H "Authorization: Bearer YOUR_ANON_KEY" \
--   -H "Content-Type: application/json" \
--   -d '{}'

-- Test reminder function:
-- curl -X POST "https://YOUR_PROJECT_URL/functions/v1/daily-question-reminder" \
--   -H "Authorization: Bearer YOUR_ANON_KEY" \
--   -H "Content-Type: application/json" \
--   -d '{}'

-- 7. Check if there are any pending questions that would trigger notifications:
SELECT
  uq.id,
  p.username,
  q.text as question,
  uq.received_at,
  uq.answered,
  CASE WHEN c.id IS NOT NULL THEN 'couple' ELSE 'solo' END as user_type
FROM user_questions uq
JOIN profiles p ON uq.user_id = p.id
JOIN questions q ON uq.question_id = q.id
LEFT JOIN couples c ON uq.user_id IN (c.user1_id, c.user2_id)
WHERE uq.answered = false
  AND uq.received_at >= CURRENT_DATE AT TIME ZONE 'UTC'
ORDER BY uq.received_at DESC;

-- 8. To manually trigger the functions from SQL (if you have the http extension):
-- SELECT
--   status, content
-- FROM http((
--   'POST',
--   'https://YOUR_PROJECT_URL/functions/v1/assign-daily-questions',
--   ARRAY[
--     http_header('Authorization', 'Bearer YOUR_ANON_KEY'),
--     http_header('Content-Type', 'application/json')
--   ],
--   'application/json',
--   '{}'
-- ));

COMMENT ON DATABASE current_database IS 'Daily Questions System Test - Run the SELECT queries above to test functionality';
