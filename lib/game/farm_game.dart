import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lovenest/behaviors/camera_bounds.dart';
import 'package:lovenest/components/player.dart';
import 'package:lovenest/components/world/building.dart';
import 'package:lovenest/components/world/farm_tile.dart';
import 'package:lovenest/utils/pathfinding.dart';
import 'package:lovenest/models/inventory.dart';
import 'package:lovenest/game/base/game_with_grid.dart';
import 'package:lovenest/components/owl_npc.dart';
import 'package:flame/sprite.dart';
import 'package:lovenest/services/question_service.dart';
import 'package:lovenest/models/memory_garden/question.dart';
import 'package:lovenest/models/memory_garden/seed.dart';

class FarmGame extends GameWithGrid with HasCollisionDetection, HasKeyboardHandlerComponents, TapCallbacks {
  late Player player;
  late CameraComponent cameraComponent;
  late PathfindingGrid pathfindingGrid;
  late InventoryManager inventoryManager;
  
  // Store tiles in a 2D grid for easy access
  late List<List<FarmTile?>> tileGrid;
  static const int mapWidth = 30;
  static const int mapHeight = 20;
  static const double tileSize = 32.0;

  // Store seeds on the map by their plot position
  final Map<PlotPosition, Seed> seedsOnMap = {};

  // Add the onPlotTapped callback
  final void Function(int gridX, int gridY, dynamic seed)? onPlotTapped;
  final VoidCallback? onEnterFarmhouse;
  // Add a callback for when the owl is tapped
  final void Function(Question)? onOwlTapped;

  // Farmhouse door position (bottom center of the house)
  static const int farmhouseDoorX = 19;
  static const int farmhouseDoorY = 5;

  bool isAtFarmhouseDoor(int gridX, int gridY) {
    return gridX == farmhouseDoorX && gridY == farmhouseDoorY;
  }

  FarmGame({required this.inventoryManager, this.onPlotTapped, this.onEnterFarmhouse, this.onOwlTapped});
  
  @override
  Color backgroundColor() => const Color(0xFF4A7C59); // Forest green

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Initialize tile grid
    tileGrid = List.generate(mapWidth, (_) => List.filled(mapHeight, null));
    
    // Create pathfinding grid
    pathfindingGrid = PathfindingGrid(mapWidth, mapHeight, tileSize);
    
    // Create the farm world
    await _createFarmWorld();
    
    // Create player and add it to the world
    player = Player();
    // Set player spawn to the center of the wood floor
    player.position = Vector2(7 * tileSize + tileSize / 2, 7 * tileSize + tileSize / 2);
    world.add(player);

    // --- Add the Owl NPC for testing ---
    final owlImage = await images.load('owl.png');
    final frameWidth = 382.0; // Updated from 384.0 to match actual sprite sheet
    final frameHeight = 478.0;
    final spriteSheet = SpriteSheet(image: owlImage, srcSize: Vector2(frameWidth, frameHeight));
    final idleSprite = spriteSheet.getSprite(0, 0); // First (left) sprite
    final notificationSprite = spriteSheet.getSprite(0, 1); // Second (right) sprite
    final owlNpc = OwlNpcComponent(
      idleSprite: idleSprite,
      notificationSprite: notificationSprite,
      position: Vector2(10 * tileSize, 10 * tileSize), // Near center
      size: Vector2(48, 60), // In scale with other game elements
      onTapOwl: () async {
        // Show daily question dialog if available
        final dailyQuestion = await QuestionService.fetchDailyQuestion();
        if (dailyQuestion != null && onOwlTapped != null) {
          onOwlTapped!(dailyQuestion);
        }
      },
    );
    world.add(owlNpc);
    // --- End Owl NPC test ---

    // Always show notification sprite for debugging
    owlNpc.showNotification(true);
    
    // Fetch daily question and update owl notification
    final dailyQuestion = await QuestionService.fetchDailyQuestion();
    if (dailyQuestion != null) {
      owlNpc.showNotification(true);
      debugPrint('Owl NPC: notification state ON');
      // Do NOT mark as received here. Only mark as read after user views the letter.
    } else {
      owlNpc.showNotification(false);
      debugPrint('Owl NPC: notification state OFF');
    }
    
    // Set up camera to follow player and fill the screen
    cameraComponent = CameraComponent(); // Uses MaxViewport by default
    cameraComponent.follow(player);
    camera = cameraComponent;
    
    // Set the zoom level to make the world appear larger
    camera.viewfinder.zoom = 2.0; 
    
    // Add our custom behavior to enforce camera bounds
    camera.viewfinder.add(CameraBoundsBehavior());
    
    // Add UI elements
    await _addUI();

    // --- Add a dummy fully grown daily question plant for testing ---
    final dummySeed = Seed(
      id: 'dummy-seed-id',
      coupleId: 'dummy-couple-id',
      planterId: 'dummy-user-id',
      mediaType: MediaType.text,
      mediaUrl: null,
      textContent: 'This is a dummy answer to a daily question!',
      secretHope: null,
      state: SeedState.bloomStage3,
      growthScore: 10,
      plotPosition: PlotPosition(12, 8), // Place at (12,8)
      bloomVariantSeed: null,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      lastUpdatedAt: DateTime.now(),
    );
    seedsOnMap[dummySeed.plotPosition] = dummySeed;
    // Add the dummy seed to the world (simulate as if it was loaded from backend)
    final dummyTile = FarmTile(Vector2(12 * tileSize, 8 * tileSize), TileType.crop);
    tileGrid[12][8] = dummyTile;
    world.add(dummyTile);
    // Optionally, add a visual marker or log for testing
    debugPrint('Added dummy fully grown daily question plant at (12,8)');
  }

  Future<void> _createFarmWorld() async {
    // Create a simple farm map with different tiles
    for (int x = 0; x < mapWidth; x++) {
      for (int y = 0; y < mapHeight; y++) {
        final position = Vector2(x * tileSize, y * tileSize);
        FarmTile tile;

        // Place a 3x3 wood floor at the spawn (centered at 6,6)
        if (x >= 6 && x <= 8 && y >= 6 && y <= 8) {
          tile = FarmTile(position, TileType.wood);
        }
        // Border - trees/fence
        else if (x < 2 || x >= mapWidth - 2 || y < 2 || y >= mapHeight - 2) {
          tile = FarmTile(position, TileType.tree);
        } else {
          // All other tiles are grass
          tile = FarmTile(position, TileType.grass);
        }
        
        // Store tile in grid and add to world
        tileGrid[x][y] = tile;
        world.add(tile);
      }
    }
    
    // Update pathfinding grid with obstacles
    _updatePathfindingGrid();
  }

  void _updatePathfindingGrid() {
    // Mark obstacles in pathfinding grid
    for (int x = 0; x < mapWidth; x++) {
      for (int y = 0; y < mapHeight; y++) {
        bool isObstacle = false;
        
        // Trees are obstacles
        if (x < 2 || x >= mapWidth - 2 || y < 2 || y >= mapHeight - 2) {
          isObstacle = true;
        }
        
        // Buildings are obstacles (using more precise tile checking)
        if ((x >= 18 && x < 21 && y >= 3 && y < 5) || // House (3x2 tiles)
            (x >= 8 && x < 10 && y >= 15 && y < 17)) { // Barn (2x1.5 tiles, treat as 2x2)
          isObstacle = true;
        }
        
        // Pond area is an obstacle
        if (x >= 20 && x <= 25 && y >= 8 && y <= 15) {
          isObstacle = true;
        }
        
        pathfindingGrid.setObstacle(x, y, isObstacle);
      }
    }
  }

  Future<void> _addUI() async {
    // Add instruction text as viewport aware components
    final instructionText = TextComponent(
      text: 'Arrow keys/WASD to move, Tap to pathfind',
      position: Vector2(10, 10),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      ),
    );
    
    final titleText = TextComponent(
      text: 'Lovenest Valley Demo',
      position: Vector2(10, 30),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.pinkAccent,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      ),
    );
    
    final fpsText = FpsTextComponent(
      position: Vector2(10, 55),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          shadows: [Shadow(color: Colors.black, blurRadius: 1)],
        ),
      ),
    );
    
    camera.viewport.add(instructionText);
    camera.viewport.add(titleText);
    camera.viewport.add(fpsText);
  }

  @override
  void onTapDown(TapDownEvent event) {
    // Convert screen tap to world position using the correct camera method
    final worldPosition = camera.globalToLocal(event.localPosition);
    
    // Convert world position to grid coordinates
    int gridX = (worldPosition.x / tileSize).floor();
    int gridY = (worldPosition.y / tileSize).floor();
    
    // Check if the tap is within bounds
    if (gridX < 0 || gridX >= mapWidth || gridY < 0 || gridY >= mapHeight) {
      return;
    }

    // Look up if a seed exists at this position
    final plotPos = PlotPosition(gridX.toDouble(), gridY.toDouble());
    final tappedSeed = seedsOnMap[plotPos];
    final tile = tileGrid[gridX][gridY];
    final selectedItem = inventoryManager.selectedItem;

    // If there is a seed at this position, call onPlotTapped for reveal dialog
    if (tappedSeed != null) {
      onPlotTapped?.call(gridX, gridY, tappedSeed);
      return;
    }
    // If the tile is tilled and the player is holding seeds, allow planting
    if (tile != null && tile.tileType == TileType.tilled && selectedItem != null && (selectedItem.id == 'seeds' || selectedItem.id == 'daily_question_seed')) {
      onPlotTapped?.call(gridX, gridY, null);
      return;
    }

    // Check if player is tapping the farmhouse door while adjacent
    if (isAtFarmhouseDoor(gridX, gridY) && isTileAdjacentToPlayer(gridX, gridY)) {
      onEnterFarmhouse?.call();
      return;
    }
    
    // Check if hoe is selected and try to till the tile
    if (inventoryManager.selectedItem?.id == 'hoe') {
      if (_tryTillTile(gridX, gridY)) {
        return; // Successfully tilled, don't move player
      }
    }
    
    // Check if seeds are selected and try to plant them
    if (inventoryManager.selectedItem?.id == 'seeds') {
      // If _tryPlantSeeds returns true, planting UI was triggered, so don't move
      if (_tryPlantSeeds(gridX, gridY)) {
        return;
      }
    }
    
    // Check if watering can with water is selected and try to water plants
    if (inventoryManager.selectedItem?.id == 'watering_can_full') {
      if (_tryWaterSeeds(gridX, gridY)) {
        return; // Successfully watered, don't move player
      }
    }
    
    // If not tilling, planting, or watering, handle normal movement
    // If the target is an obstacle, find the nearest valid neighbor
    if (pathfindingGrid.isObstacle(gridX, gridY)) {
      final nearest = _findNearestValidTile(gridX, gridY);
      if (nearest == null) return; // No valid tile found
      gridX = nearest.x.toInt();
      gridY = nearest.y.toInt();
    }
    
    player.pathfindTo(gridX, gridY);
  }

  /// Attempts to till a tile if conditions are met
  bool _tryTillTile(int gridX, int gridY) {
    // Check if tile is adjacent to player
    if (!isTileAdjacentToPlayer(gridX, gridY)) {
      return false;
    }
    
    // Check if tile exists and is grass
    final tile = tileGrid[gridX][gridY];
    if (tile == null || tile.tileType != TileType.grass) {
      return false;
    }
    
    // Change the tile to tilled
    _changeTileType(gridX, gridY, TileType.tilled);
    return true;
  }

  /// Checks if a tile is adjacent (including diagonally) to the player
  bool isTileAdjacentToPlayer(int tileX, int tileY) {
    // Get player's grid position
    final playerGridX = (player.position.x / tileSize).floor();
    final playerGridY = (player.position.y / tileSize).floor();
    
    // Check if the tile is within 1 tile distance (including diagonals)
    final deltaX = (tileX - playerGridX).abs();
    final deltaY = (tileY - playerGridY).abs();
    
    return deltaX <= 1 && deltaY <= 1 && !(deltaX == 0 && deltaY == 0);
  }

  /// Attempts to plant seeds on a tilled soil tile
  bool _tryPlantSeeds(int gridX, int gridY) {
    // Only trigger the callback if the tile is tilled soil and adjacent to the player
    if (!isTileAdjacentToPlayer(gridX, gridY)) {
      return false;
    }
    final tile = tileGrid[gridX][gridY];
    if (tile == null || tile.tileType != TileType.tilled) {
      return false;
    }
    if (onPlotTapped != null) {
      onPlotTapped!(gridX, gridY, null); // Pass null for seed for now
    }
    return true; // Planting UI was triggered
  }

  // Public method to plant a seed at a given tile (called after memory input)
  bool plantSeedAt(int gridX, int gridY) {
    // Check if tile is adjacent to player
    if (!isTileAdjacentToPlayer(gridX, gridY)) {
      return false;
    }
    // Check if tile exists and is tilled soil
    final tile = tileGrid[gridX][gridY];
    if (tile == null || tile.tileType != TileType.tilled) {
      return false;
    }
    // Check if player has seeds in inventory
    final selectedItem = inventoryManager.selectedItem;
    if (selectedItem == null || selectedItem.quantity <= 0) {
      return false;
    }
    // Plant the seeds (change tile to seeded)
    _changeTileType(gridX, gridY, TileType.crop);
    // Consume one seed from inventory
    _consumeSelectedItem(1);
    return true;
  }

  /// Attempts to water seeded tiles with the watering can
  bool _tryWaterSeeds(int gridX, int gridY) {
    // Check if tile is adjacent to player
    if (!isTileAdjacentToPlayer(gridX, gridY)) {
      return false;
    }
    
    // Check if tile exists and has seeds planted (but not already watered)
    final tile = tileGrid[gridX][gridY];
    if (tile == null || tile.tileType != TileType.crop) {
      return false;
    }
    
    // Check if player has watering can with water
    final selectedItem = inventoryManager.selectedItem;
    if (selectedItem == null || selectedItem.quantity <= 0) {
      return false;
    }
    
    // Water the seeds (change tile to watered seeded)
    _changeTileType(gridX, gridY, TileType.water);
    
    // Consume one use of water from the watering can
    _consumeWateringCanUse();
    
    return true;
  }

  /// Consumes one use of water from the watering can
  void _consumeWateringCanUse() {
    final selectedItem = inventoryManager.selectedItem;
    if (selectedItem == null || selectedItem.id != 'watering_can_full') {
      return;
    }
    
    final slotIndex = inventoryManager.selectedSlotIndex;
    
    if (selectedItem.quantity == 1) {
      // Replace with empty watering can when last use is consumed
      final emptyWateringCan = InventoryItem(
        id: 'watering_can_empty',
        name: 'Empty Watering Can',
        quantity: 1,
      );
      inventoryManager.setItem(slotIndex, emptyWateringCan);
    } else {
      // Reduce the water uses
      final updatedItem = selectedItem.copyWith(
        quantity: selectedItem.quantity - 1,
      );
      inventoryManager.setItem(slotIndex, updatedItem);
    }
  }

  /// Consumes a quantity of the currently selected item
  void _consumeSelectedItem(int quantity) {
    final selectedItem = inventoryManager.selectedItem;
    if (selectedItem == null || selectedItem.quantity < quantity) {
      return;
    }
    
    final slotIndex = inventoryManager.selectedSlotIndex;
    
    if (selectedItem.quantity == quantity) {
      // Remove the item completely if we're consuming all of it
      inventoryManager.removeItem(slotIndex);
    } else {
      // Reduce the quantity
      final updatedItem = selectedItem.copyWith(
        quantity: selectedItem.quantity - quantity,
      );
      inventoryManager.setItem(slotIndex, updatedItem);
    }
  }

  /// Changes a tile's type and updates the world
  void _changeTileType(int gridX, int gridY, TileType newType) {
    final oldTile = tileGrid[gridX][gridY];
    if (oldTile == null) return;
    
    // Remove old tile from world
    world.remove(oldTile);
    
    // Create new tile with same position but different type
    final position = Vector2(gridX * tileSize, gridY * tileSize);
    final newTile = FarmTile(position, newType);
    
    // Update grid and add to world
    tileGrid[gridX][gridY] = newTile;
    world.add(newTile);
  }

  /// Public method to update a tile to crop (planted) after planting a seed externally
  void updateTileToCrop(int gridX, int gridY) {
    _changeTileType(gridX, gridY, TileType.crop);
  }

  // Helper method to find the closest non-obstacle tile using BFS
  Vector2? _findNearestValidTile(int startX, int startY) {
    final queue = <Vector2>[Vector2(startX.toDouble(), startY.toDouble())];
    final visited = <String>{'${startX},${startY}'};
    
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final x = current.x.toInt();
      final y = current.y.toInt();

      if (!pathfindingGrid.isObstacle(x, y)) {
        return current;
      }
      
      // Check neighbors (BFS)
      for (final direction in [
        Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0),
        Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)
      ]) {
        final neighborX = x + direction.x.toInt();
        final neighborY = y + direction.y.toInt();
        final key = '$neighborX,$neighborY';

        if (neighborX >= 0 && neighborX < mapWidth && neighborY >= 0 && neighborY < mapHeight && !visited.contains(key)) {
          visited.add(key);
          queue.add(Vector2(neighborX.toDouble(), neighborY.toDouble()));
        }
      }
    }
    return null; // Should not happen if there's at least one valid tile
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    return player.handleKeyEvent(keysPressed);
  }
} 