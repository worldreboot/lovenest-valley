# Daily Questions System Setup Guide

## Overview
Your daily questions system is now fully implemented with the following components:

1. **Question Assignment System** (`assign-daily-questions`)
2. **Enhanced Reminder System** (`daily-question-reminder`)
3. **Question Tracking** (prevents duplicate questions)
4. **Couple-based Notifications** (notifies both users in a couple)

## 🚀 Quick Start

### 1. Run Setup Script
Execute the `setup-daily-questions.sql` file in your Supabase SQL Editor to:
- Create test functions
- Add sample questions
- Set up permissions

### 2. Test the System
Run these SQL queries in your Supabase SQL Editor:

```sql
-- Test basic functionality (safe - no external calls)
SELECT get_daily_question_stats();
SELECT test_assign_daily_questions();
SELECT test_daily_question_reminder();

-- Test actual Edge Functions (replace with your values):
-- curl -X POST "https://YOUR_PROJECT.supabase.co/functions/v1/assign-daily-questions" \
--   -H "Authorization: Bearer YOUR_ANON_KEY" \
--   -H "Content-Type: application/json" \
--   -d '{}'
```

## ⏰ Cron Job Setup

### Method 1: Supabase Dashboard (Recommended)
1. Go to **Project Settings** → **Edge Functions** → **Cron**
2. Add these cron jobs:

**Daily Question Assignment (12:00 AM UTC)**
```
Name: assign-daily-questions
Schedule: 0 0 * * *
Edge Function: assign-daily-questions
HTTP Method: POST
Headers: (leave empty)
Body: {}
```

**Daily Question Reminder (6:00 PM UTC)**
```
Name: daily-question-reminder
Schedule: 0 18 * * *
Edge Function: daily-question-reminder
HTTP Method: POST
Headers: (leave empty)
Body: {}
```

### Method 2: External Cron Service
Use services like cron-job.org, easycron.com, or GitHub Actions:

```bash
# Daily assignment at 12:00 AM UTC
curl -X POST "https://your-project.supabase.co/functions/v1/assign-daily-questions" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{}'

# Daily reminder at 6:00 PM UTC
curl -X POST "https://your-project.supabase.co/functions/v1/daily-question-reminder" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{}'
```

## 📱 How It Works

### Question Assignment (Daily at 12:00 AM UTC)
1. **Selects Random Unseen Questions**: Each user gets a random question they haven't seen before
2. **Handles Question Exhaustion**: If all questions are used, randomly selects from all questions
3. **Tracks Assignment**: Records in `user_questions` table with `answered = false`

### Push Notifications (Daily at 6:00 PM UTC)
1. **Checks Unanswered Questions**: Finds users who haven't answered their daily question
2. **Couple Logic**:
   - If both users in a couple haven't answered → Sends couple notification: *"Couple Question Reminder 💕 [Question]"*
   - If only one user hasn't answered → Sends solo notification: *"Daily Question Reminder [Question]"*
3. **Includes Question Text**: Push notifications show the actual question text
4. **Smart Grouping**: Groups users by question to send efficient batch notifications

## 🛠️ Customization Options

### Change Notification Times
Modify the cron schedules:
- Assignment time: Change the first cron job schedule
- Reminder time: Change the second cron job schedule

### Customize Questions
Add more questions to the `questions` table:
```sql
INSERT INTO questions (text) VALUES ('Your custom question here');
```

### Modify Notification Messages
Update the push notification content in the `daily-question-reminder` function:
```typescript
// In the daily-question-reminder function
title: "Your Custom Title",
body: "Your custom message format"
```

## 🔧 Monitoring & Testing

### Check System Status
```sql
SELECT get_daily_question_stats();
```

### View Today's Assignments
```sql
SELECT
  uq.user_id,
  p.username,
  q.text,
  uq.received_at,
  uq.answered
FROM user_questions uq
JOIN questions q ON uq.question_id = q.id
LEFT JOIN profiles p ON uq.user_id = p.id
WHERE uq.received_at >= CURRENT_DATE AT TIME ZONE 'UTC'
ORDER BY uq.received_at DESC;
```

### View Push Subscription Status
```sql
SELECT
  p.username,
  ps.platform,
  ps.created_at
FROM push_subscriptions ps
LEFT JOIN profiles p ON ps.user_id = p.id
ORDER BY ps.created_at DESC;
```

## 🎯 Expected Behavior

### For Solo Users
- Gets assigned a random question at midnight UTC
- If not answered by 6 PM UTC, receives: *"Daily Question Reminder: [Question text]"*

### For Couples
- Both users get assigned the same question at midnight UTC
- If both haven't answered by 6 PM UTC, both receive: *"Couple Question Reminder 💕 [Question text]"*
- If only one hasn't answered, that user receives: *"Daily Question Reminder [Question text]"*

## 📊 System Flow

```
12:00 AM UTC
    ↓
[assign-daily-questions]
    ↓
Select random unseen questions
    ↓
Assign to users (user_questions table)
    ↓
6:00 PM UTC
    ↓
[daily-question-reminder]
    ↓
Check unanswered questions
    ↓
Send personalized push notifications
    ↓
Users receive notifications with question text
```

## 🐛 Troubleshooting

### Configuration Parameter Errors
If you get errors like `unrecognized configuration parameter "app.supabase_url"`:
1. **Use the simple test functions** instead of the HTTP-based ones
2. **Run the basic tests first**:
   ```sql
   SELECT get_daily_question_stats();
   SELECT test_assign_daily_questions();
   SELECT test_daily_question_reminder();
   ```
3. **For Edge Function testing**, use curl commands in terminal instead of SQL

### No Questions Being Assigned
1. Check if users have profiles: `SELECT COUNT(*) FROM profiles WHERE username IS NOT NULL;`
2. Verify Edge Function is deployed: Check Supabase Dashboard → Edge Functions
3. Run basic test: `SELECT test_assign_daily_questions();`
4. Check function logs in Supabase Dashboard

### No Push Notifications
1. Check push subscriptions: `SELECT COUNT(*) FROM push_subscriptions;`
2. Verify FCM credentials are set up in environment variables
3. Test reminder function: `SELECT test_daily_question_reminder();`
4. Check function logs in Supabase Dashboard

### Questions Repeating Too Often
1. Add more questions to the `questions` table:
   ```sql
   INSERT INTO questions (text) VALUES ('Your new question here');
   ```
2. The system will reuse questions only after all are exhausted

### HTTP Extension Not Available
If you get HTTP-related errors:
1. Use the simplified test functions in `test-daily-questions.sql`
2. Test Edge Functions using curl commands in terminal
3. Check that the `http` extension is enabled in your database

## 🔐 Security Notes

- Functions use service role key for database access
- Cron jobs can include optional `CRON_SECRET` header for additional security
- Push notifications require `PUSH_FUNCTION_SECRET` for the send-push function
- All functions verify JWT tokens by default

## 📞 Support

If you encounter issues:
1. Check the Edge Function logs in Supabase Dashboard
2. Use the test functions to debug: `SELECT get_daily_question_stats();`
3. Verify environment variables are set correctly
4. Ensure cron jobs are scheduled properly

Your daily questions system is now ready to provide personalized, couple-aware question experiences with intelligent push notifications! 🎉
