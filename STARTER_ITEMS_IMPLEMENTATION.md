# Starter Items Implementation Guide

## Overview

This implementation ensures that starter items (hoe, watering can, chest) are only given to users **once** when they first join the world, not every time they have an empty inventory.

## What Was Changed

### 1. Database Migration
- **File**: `database_migrations/add_starter_items_tracking.sql`
- **Purpose**: Adds `has_received_starter_items` boolean field to `profiles` table
- **Default**: `FALSE` for all existing users

### 2. New Service
- **File**: `lib/services/starter_items_service.dart`
- **Purpose**: Manages starter items tracking state
- **Methods**:
  - `hasReceivedStarterItems()` - Check if user already got starter items
  - `markStarterItemsReceived()` - Mark user as having received starter items
  - `resetStarterItemsStatus()` - Reset status (for testing/admin)

### 3. Updated Game Logic
- **File**: `lib/game/simple_enhanced_farm_game.dart`
- **Method**: `_ensureStarterChest()`
- **Changes**: Now checks tracking status before giving items

### 4. Updated Test Screen
- **File**: `lib/screens/tiled_test_screen.dart`
- **Method**: `_initializeInventory()`
- **Changes**: Now checks tracking status before giving items

## How It Works

### First-Time User Flow
1. User spawns with empty inventory
2. Game checks `profiles.has_received_starter_items` (will be `FALSE`)
3. Game gives starter items (hoe, watering can, chest)
4. Game calls `StarterItemsService.markStarterItemsReceived()`
5. Database field is set to `TRUE`

### Subsequent Spawns
1. User spawns with empty inventory (maybe they dropped/lost items)
2. Game checks `profiles.has_received_starter_items` (will be `TRUE`)
3. Game skips giving starter items
4. Only ensures chest exists if missing

## Deployment Steps

### 1. Apply Database Migration
```bash
# Run the migration in your Supabase project
psql -h your-project-ref.supabase.co -U postgres -d postgres -f database_migrations/add_starter_items_tracking.sql
```

### 2. Test the Migration
```bash
# Run the test script to verify
psql -h your-project-ref.supabase.co -U postgres -d postgres -f test_starter_items_migration.sql
```

### 3. Deploy Code Changes
- Deploy the updated Flutter app with the new service and logic
- The app will automatically start using the tracking system

## Testing

### Test Scenarios

#### New User (First Time)
1. Create new user account
2. Spawn in game
3. Should receive starter items
4. Check database: `has_received_starter_items` should be `TRUE`

#### Existing User (Subsequent Spawns)
1. Use existing user account
2. Drop all items from inventory
3. Spawn in game again
4. Should NOT receive starter items
5. Check database: `has_received_starter_items` should remain `TRUE`

#### Legacy User (Had Items Before Implementation)
1. User who already had items before this change
2. Spawn in game
3. Should NOT receive starter items
4. Should be automatically marked as `has_received_starter_items = TRUE`

### Manual Testing Commands

```sql
-- Check current status
SELECT id, username, has_received_starter_items FROM profiles LIMIT 5;

-- Manually mark a user as having received starter items
UPDATE profiles 
SET has_received_starter_items = true 
WHERE id = 'user-uuid-here';

-- Reset a user's status for testing
UPDATE profiles 
SET has_received_starter_items = false 
WHERE id = 'user-uuid-here';
```

## Benefits

1. **One-time only**: Starter items are given exactly once per user
2. **Persistent tracking**: State is stored in database, survives app restarts
3. **Backward compatible**: Existing users are automatically handled
4. **Efficient**: No unnecessary item spawning on subsequent spawns
5. **Maintainable**: Clear separation of concerns with dedicated service

## Troubleshooting

### Common Issues

#### Migration Fails
- Ensure you have write permissions on the `profiles` table
- Check if the column already exists: `\d profiles` in psql

#### App Crashes on Startup
- Verify the `StarterItemsService` is properly imported
- Check that the `profiles` table has the new column
- Look for errors in the debug console

#### Users Still Getting Starter Items
- Check if `has_received_starter_items` is being set to `TRUE`
- Verify the service calls are working
- Check database logs for any errors

### Debug Logs

The implementation includes comprehensive logging:
- `🎁 Adding starter items for new user (first time)`
- `✅ User has already received starter items, skipping`
- `✅ Marked starter items as received for user`

Look for these logs in the Flutter debug console to verify the flow.

## Future Enhancements

1. **Admin Panel**: Add UI to reset starter items status
2. **Analytics**: Track how many users actually use their starter items
3. **Customization**: Allow different starter item sets for different user types
4. **Recovery**: Add option for users to request replacement starter items
