# Chest Storage System Implementation

## Overview

This implementation provides a complete chest storage system with real-time synchronization for the LoveNest game. The system allows players to store items in chests that are shared between couples and synchronized across all clients in real-time.

## Architecture

### 🏗️ **Database Layer**
- **Table**: `game_objects` (existing table, extended for chests)
- **Type**: `'chest'` for chest objects
- **Position**: PostgreSQL `point` type for x,y coordinates
- **Properties**: JSONB field storing chest contents and metadata
- **Real-time**: Enabled via Supabase real-time subscriptions
- **RLS**: Row-level security policies for couple-based access

### 🔄 **Real-time Synchronization**
- **Supabase Channels**: PostgreSQL real-time for instant updates
- **Optimistic Locking**: Version-based conflict prevention
- **Echo Prevention**: Filters out own updates to prevent loops
- **Batch Operations**: Efficient item movement between chests

### 📱 **Client Architecture**
- **Models**: `ChestStorage`, `ChestItem`, `Position`
- **Service**: `ChestStorageService` for database operations
- **Providers**: Riverpod state management with real-time streams
- **UI**: Modern, game-like interface with drag-and-drop support

## Key Features

### ✅ **Real-time Multiplayer**
- Instant synchronization between partners
- Live updates when items are added/removed
- Conflict resolution with optimistic locking
- Offline support with sync queue

### 🎮 **Game Integration**
- Seamless integration with existing chest objects
- Position-based chest discovery
- Inventory management with stacking
- Capacity limits and overflow protection

### 🔒 **Security & Performance**
- Row-level security (RLS) policies
- Couple-based access control
- Optimized database queries with indexes
- Efficient JSONB operations for item storage

## Implementation Details

### 1. Database Schema

The system leverages the existing `game_objects` table:

```sql
-- Chest objects are stored as game_objects with type = 'chest'
CREATE TABLE game_objects (
    id UUID PRIMARY KEY,
    couple_id UUID REFERENCES couples(id),
    type VARCHAR NOT NULL, -- 'chest' for chest objects
    position POINT NOT NULL,
    properties JSONB NOT NULL, -- Stores chest contents
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    version INTEGER DEFAULT 1, -- For optimistic locking
    sync_status VARCHAR DEFAULT 'synced',
    last_updated_by UUID REFERENCES auth.users(id)
);
```

### 2. Real-time Setup

```sql
-- Enable real-time for game_objects table
ALTER PUBLICATION supabase_realtime ADD TABLE game_objects;

-- Create indexes for performance
CREATE INDEX idx_game_objects_couple_type ON game_objects(couple_id, type) WHERE type = 'chest';
CREATE INDEX idx_game_objects_position ON game_objects USING GIST(position) WHERE type = 'chest';
```

### 3. RLS Policies

```sql
-- Users can only access chests from their couples
CREATE POLICY "Users can view game objects from their couples"
ON game_objects FOR SELECT
USING (
    couple_id IN (
        SELECT id FROM couples 
        WHERE user1_id = auth.uid() OR user2_id = auth.uid()
    )
);
```

## Usage Examples

### Creating a Chest

```dart
final notifier = ref.read(chestStorageNotifierProvider.notifier);
await notifier.createChest(
  position: const Position(100, 100),
  name: 'Main Storage',
  maxCapacity: 20,
);
```

### Adding Items

```dart
final item = ChestItem(
  id: 'unique_id',
  name: 'Wood',
  quantity: 5,
  description: 'Basic building material',
);

await notifier.addItemToChest(chestId, item);
```

### Real-time Updates

```dart
// Watch for real-time updates
final chestsState = ref.watch(chestsStateProvider);
chestsState.when(
  data: (chests) => print('Chests updated: ${chests.length}'),
  loading: () => print('Loading...'),
  error: (error, stack) => print('Error: $error'),
);
```

## Integration with Existing Game

### 1. Chest Object Enhancement

The existing `ChestObject` can be enhanced to support storage:

```dart
class ChestObject extends SpriteAnimationComponent with TapCallbacks {
  final ChestStorage? chestStorage;
  final ChestStorageService _chestService = ChestStorageService();
  
  // ... existing code ...
  
  @override
  bool onTapDown(TapDownEvent event) {
    if (chestStorage != null) {
      _openChestStorage();
    }
    return super.onTapDown(event);
  }
  
  void _openChestStorage() {
    // Show chest storage UI
    showDialog(
      context: context,
      builder: (context) => ChestStorageUI(chest: chestStorage!),
    );
  }
}
```

### 2. Game Integration

```dart
// In your game initialization
final chests = await _chestService.getChests(coupleId);
for (final chest in chests) {
  final chestObject = ChestObject(
    position: Vector2(chest.position.x, chest.position.y),
    size: Vector2(32, 32),
    examineText: 'Open ${chest.name ?? 'Chest'}',
    chestStorage: chest,
  );
  world.add(chestObject);
}
```

## Performance Optimizations

### 1. **Efficient Queries**
- Indexed queries by couple_id and type
- Spatial indexing for position-based searches
- JSONB operations for item management

### 2. **Real-time Efficiency**
- Echo prevention (filters own updates)
- Debounced updates for rapid changes
- Optimistic locking reduces conflicts

### 3. **Memory Management**
- Lazy loading of chest contents
- Efficient state management with Riverpod
- Proper disposal of real-time subscriptions

## Testing the Implementation

### 1. Run Database Migration

```bash
# Apply the chest storage setup
supabase db reset --with-seed
```

### 2. Test Real-time Features

1. Open the chest storage example screen
2. Create a test chest
3. Add items from multiple clients
4. Verify real-time synchronization

### 3. Integration Testing

```dart
// Test chest creation
final chest = await _chestService.createChest(
  coupleId: coupleId,
  position: const Position(100, 100),
  name: 'Test Chest',
);

// Test item addition
await _chestService.addItemToChest(chest.id, testItem);

// Test real-time updates
_chestService.chestUpdates.listen((updatedChest) {
  print('Chest updated: ${updatedChest.id}');
});
```

## Error Handling

### 1. **Network Issues**
- Automatic retry with exponential backoff
- Offline queue for pending operations
- Graceful degradation when real-time unavailable

### 2. **Conflict Resolution**
- Optimistic locking prevents most conflicts
- Version-based conflict detection
- User-friendly error messages

### 3. **Data Validation**
- Input validation for item quantities
- Capacity limit enforcement
- Type safety with strong typing

## Future Enhancements

### 1. **Advanced Features**
- Item categories and filtering
- Search functionality
- Item crafting and recipes
- Chest upgrades and expansion

### 2. **Performance Improvements**
- Virtual scrolling for large inventories
- Image caching for item icons
- Background sync for offline support

### 3. **Gameplay Integration**
- Item rarity and quality systems
- Trading between partners
- Achievement system for storage milestones

## Troubleshooting

### Common Issues

1. **Real-time not working**
   - Check Supabase real-time is enabled
   - Verify RLS policies are correct
   - Ensure proper authentication

2. **Items not syncing**
   - Check network connectivity
   - Verify couple relationship exists
   - Review error logs for details

3. **Performance issues**
   - Monitor database query performance
   - Check for excessive real-time events
   - Optimize item operations

### Debug Tools

```dart
// Enable debug logging
debugPrint('[ChestStorageService] Debug mode enabled');

// Monitor real-time events
_chestService.chestUpdates.listen((chest) {
  debugPrint('Real-time update: ${chest.id}');
});
```

## Conclusion

This chest storage system provides a robust, scalable solution for multiplayer item storage with real-time synchronization. The implementation follows best practices for performance, security, and user experience while maintaining compatibility with the existing game architecture.

The system is designed to be easily extensible for future features while providing a solid foundation for the current requirements. 