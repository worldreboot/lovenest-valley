# Map Persistence System

This document explains how the farm map persistence system works in Lovenest Valley.

## Overview

The farm map persistence system ensures that when a user generates a new map or makes changes to their farm, these changes are saved to the backend database and can be restored when the user logs back in.

## Database Schema

### Tables Used

1. **`farms`** - Stores farm metadata
   - `id` (UUID) - Primary key
   - `owner_id` (UUID) - User who owns the farm
   - `partner_id` (UUID, nullable) - Partner user (for couples)
   - `created_at` (timestamp)
   - `updated_at` (timestamp)

2. **`farm_tiles`** - Stores individual tile data
   - `x` (int) - X coordinate
   - `y` (int) - Y coordinate  
   - `farm_id` (UUID) - References farms.id
   - `tile_type` (text) - Type of tile (grass, tree, water, etc.)
   - `watered` (boolean) - Whether tile is watered
   - `planted_at` (timestamp, nullable) - When plant was planted
   - `last_watered_at` (timestamp, nullable) - Last watering time
   - `water_count` (int) - Number of times watered
   - `growth_stage` (text) - Plant growth stage
   - `plant_type` (text, nullable) - Type of plant

## How It Works

### 1. Farm Creation
When a new user first accesses the game:
- A new farm record is created in the `farms` table
- The `generateAndSaveFarmMap()` method is called to create the initial map layout
- All tiles are saved to the `farm_tiles` table

### 2. Map Loading
When the game starts:
- The app checks if the user has an existing farm
- If a farm exists, it loads tiles from the `farm_tiles` table
- If no tiles exist, it generates a new map and saves it

### 3. Real-time Updates
- Tile changes (planting, watering, etc.) are immediately saved to the backend
- Real-time subscriptions notify other players of changes
- Changes persist across sessions

## Key Methods

### FarmTileService

- `fetchFarmTiles(farmId)` - Load tiles for a farm
- `generateAndSaveFarmMap(farmId)` - Create and save a complete map
- `regenerateFarmMap(farmId)` - Clear and recreate a map
- `updateTile(...)` - Update a single tile
- `batchUpdateTiles(farmId, tiles)` - Update multiple tiles at once
- `farmHasTiles(farmId)` - Check if a farm has any tiles

### Map Layout

The standard farm map is 32x14 tiles with the following layout:
- **Wood floor** (2x2) at spawn point (9,7)
- **Tree borders** around the perimeter (except water area)
- **Beach area** on the right side:
  - Grass-sand transition at x=16
  - Sand at x=17,18
  - Water at x≥19
- **Grass** for all other areas

## Usage Examples

### Creating a New Farm
```dart
final farmId = await repo.createFarmForCurrentUser();
await farmTileService.generateAndSaveFarmMap(farmId);
```

### Loading an Existing Farm
```dart
final tiles = await farmTileService.fetchFarmTiles(farmId);
if (tiles.isEmpty) {
  // Generate new map if none exists
  await farmTileService.generateAndSaveFarmMap(farmId);
}
```

### Updating a Tile
```dart
await farmTileService.updateTile(
  farmId: farmId,
  x: 10,
  y: 5,
  tileType: 'crop',
  watered: true,
  isPlanting: true,
  plantType: 'memory_seed',
);
```

### Regenerating a Map
```dart
await farmTileService.regenerateFarmMap(farmId);
```

## Benefits

1. **Persistence** - Maps survive app restarts and device changes
2. **Multiplayer** - Real-time sync between partners
3. **Consistency** - Centralized map generation logic
4. **Scalability** - Efficient batch operations for large maps
5. **Reliability** - Error handling and fallback mechanisms

## Future Enhancements

- Custom map layouts per user/couple
- Map templates and themes
- Seasonal map variations
- Map sharing between users
- Map import/export functionality 