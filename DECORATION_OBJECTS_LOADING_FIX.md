# Decoration Objects Loading Fix

## Problem Description

Decoration objects from `houses.tsx` and `wooden.tsx` were not initially loading on screen when the user first loads the game. They would only appear after the user moved off-screen and came back, indicating a visibility calculation issue.

## Root Cause Analysis

The issue was caused by **two main problems**:

### 1. Insufficient Visibility Buffer
The `_updateVisibleTiles` method in `lib/game/simple_enhanced/terrain/tile_renderer.dart` was using a small buffer (4 tiles) around the camera view, but large decoration objects could extend well beyond this buffer.

### 2. Camera Initialization Timing Issue
The tilemap was being rendered **before** the camera was properly set up. This meant that when `_updateVisibleTiles(force: true)` was called during initial load, the camera didn't have a proper view rectangle yet, causing the visibility calculation to fail.

**Timeline of the problem:**
1. Game loads and initializes tile renderer
2. `_renderTilemap()` is called immediately
3. `_updateVisibleTiles(force: true)` tries to calculate visible area
4. Camera view rectangle is not properly initialized yet
5. Visibility calculation fails, decoration objects don't render
6. Player spawns and camera is set up
7. Only when player moves does the visibility update trigger properly

## Solution Implemented

### 1. Fixed Initialization Order

Reordered the game initialization sequence in `lib/game/simple_enhanced_farm_game.dart`:

```dart
// OLD ORDER (problematic):
// 1. Initialize tile renderer
// 2. Render tilemap (camera not ready)
// 3. Spawn player
// 4. Set up camera

// NEW ORDER (fixed):
// 1. Initialize tile renderer
// 2. Spawn player FIRST
// 3. Set up camera SECOND
// 4. Render tilemap AFTER camera is ready
```

### 2. Increased Visibility Buffer for Decoration Objects

Modified `updateVisibleTiles` method to use different buffer sizes:
- **Ground layer**: 4 tiles buffer (unchanged for performance)
- **Decoration layer**: 8 tiles buffer (doubled from 4 to 8)

```dart
// Use a larger buffer for decoration objects since they can be much larger than base tiles
// Houses can be up to 122x99 pixels, so we need a larger buffer to ensure they're visible
final decorationBuffer = 8; // Increased from 4 to 8 tiles for decoration objects
final groundBuffer = 4; // Keep ground buffer smaller for performance
```

### 3. Added Fallback Mechanism

Added a fallback visibility calculation for when the camera view is not properly initialized:

```dart
// Check if camera view is properly initialized
if (view.width <= 0 || view.height <= 0) {
  debugPrint('[TileRenderer] ⚠️ Camera view not properly initialized, using fallback visibility area');
  // Use a fallback area around the spawn point for initial load
  final spawnX = 34; // Approximate spawn tile X
  final spawnY = 9;  // Approximate spawn tile Y
  final fallbackRadius = 12; // Large enough to include nearby decoration objects
  
  // Render decoration objects in fallback area
  // ...
}
```

### 4. Added Post-Frame Decoration Refresh

Added a post-frame callback to force refresh decoration objects after camera setup:

```dart
// Force a refresh of decoration objects after camera is properly set up
WidgetsBinding.instance.addPostFrameCallback((_) {
  debugPrint('[SimpleEnhancedFarmGame] 🔄 Forcing decoration refresh after camera setup...');
  _tileRenderer.updateVisibleTiles(force: true);
});
```

### 5. Enhanced Debug Logging

Added comprehensive debug logging to track the rendering process:

```dart
debugPrint('[TileRenderer] 🎨 Starting initial tilemap render...');
debugPrint('[TileRenderer] 📊 Ground data: ${groundTileData.length}x${groundTileData[0].length}');
debugPrint('[TileRenderer] 🎨 Decoration data: ${decorationTileData?.length ?? 0}x${decorationTileData?[0].length ?? 0}');
debugPrint('[TileRenderer] 📷 Camera view: ${game.camera.visibleWorldRect}');
```

## Files Modified

- `lib/game/simple_enhanced_farm_game.dart`
  - Reordered initialization sequence
  - Added post-frame decoration refresh
- `lib/game/simple_enhanced/terrain/tile_renderer.dart`
  - Made `updateVisibleTiles` method public
  - Added fallback visibility mechanism
  - Increased decoration buffer size
  - Added comprehensive debug logging

## Testing

To verify the fix works:

1. Start the game and observe that decoration objects (houses, wooden objects) are visible immediately
2. Check the debug console for messages like:
   ```
   [TileRenderer] 🎨 Starting initial tilemap render...
   [TileRenderer] 📊 Ground data: 28x64
   [TileRenderer] 🎨 Decoration data: 28x64
   [TileRenderer] 📷 Camera view: Rectangle(0.0, 0.0, 800.0, 600.0)
   [TileRenderer] 🔍 Updating decoration visibility: area (26,1) to (42,17)
   [TileRenderer] 🏠 Rendered house at (17, 5): GID 282, size 84x97
   [TileRenderer] 🏠 Rendered wooden at (12, 5): GID 326, size 58x45
   [SimpleEnhancedFarmGame] 🔄 Forcing decoration refresh after camera setup...
   ```

## Performance Impact

- **Minimal**: The increased buffer only affects decoration objects, not ground tiles
- **Memory**: Slightly more decoration objects may be loaded at once, but this is necessary for proper visibility
- **CPU**: Negligible impact as the visibility update frequency remains the same (5 Hz)
- **Initialization**: Slightly faster initial load since decoration objects appear immediately

## Related Issues

This fix addresses the same underlying issue that could affect other large decoration objects in the future. The solution is scalable and will work for any decoration objects that are larger than the base tile size.

The fix also improves the overall game initialization reliability by ensuring proper sequencing of camera setup and tile rendering.
