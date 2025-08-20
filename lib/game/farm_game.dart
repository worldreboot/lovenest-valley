import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
// Duplicate import suppressed by lint: intentionally keep only one
import 'package:lovenest/behaviors/camera_bounds.dart';
import 'package:lovenest/components/player.dart';
import 'package:lovenest/components/smooth_player.dart';
// import 'package:lovenest/components/world/building.dart';
import 'package:lovenest/components/world/farm_tile.dart';
import 'package:lovenest/components/world/bonfire.dart';
import 'package:lovenest/utils/pathfinding.dart';
import 'package:lovenest/models/inventory.dart';
import 'package:lovenest/game/base/game_with_grid.dart';
import 'package:lovenest/components/owl_npc.dart';
import 'package:flame/sprite.dart';
import 'package:lovenest/services/question_service.dart';
import 'package:lovenest/models/memory_garden/question.dart';
import 'package:lovenest/services/daily_question_seed_service.dart';
import 'package:lovenest/models/memory_garden/seed.dart';
import 'package:lovenest/services/farm_tile_service.dart';
import 'package:lovenest/models/farm_tile_model.dart';
import 'package:lovenest/services/farm_player_service.dart';
import 'package:lovenest/config/supabase_config.dart';
// Removed duplicate async import above
import 'package:lovenest/components/chest_object.dart';
import 'package:lovenest/components/world/seashell_object.dart';
import 'package:lovenest/services/seashell_service.dart';
import '../models/chest_storage.dart';
 
// Position class is defined in chest_storage.dart

class FarmGame extends GameWithGrid with HasCollisionDetection, HasKeyboardHandlerComponents, TapCallbacks {
  final String farmId;
  late Player player;
  late CameraComponent cameraComponent;
  late PathfindingGrid pathfindingGrid;
  late InventoryManager inventoryManager;
  final FarmTileService _farmTileService = FarmTileService();
  
  // Store tiles in a 2D grid for easy access
  late List<List<FarmTile?>> tileGrid;
  static const int mapWidth = 32;
  static const int mapHeight = 14;
  static const double tileSize = 32.0;

  // Store seeds on the map by their plot position
  final Map<PlotPosition, Seed> seedsOnMap = {};

  // Store bonfire positions for pathfinding
  final Set<String> bonfirePositions = {};
  
  // Store owl positions for pathfinding
  final Set<String> owlPositions = {};

  // Add the onPlotTapped callback
  final void Function(int gridX, int gridY, dynamic seed)? onPlotTapped;
  final VoidCallback? onEnterFarmhouse;
  // Add a callback for when the owl is tapped
  final void Function(Question)? onOwlTapped;
  final void Function(String, ChestStorage?)? onExamine;
  final void Function(String audioUrl)? onAudioUploaded;

  // Farmhouse door position (bottom center of the house)
  static const int farmhouseDoorX = 19;
  static const int farmhouseDoorY = 5;

  bool isAtFarmhouseDoor(int gridX, int gridY) {
    // Cabin entry is disabled for now
    return false;
  }

  final Map<String, SmoothPlayer> otherPlayers = {};
  late final FarmPlayerService _farmPlayerService;
  String? _userId;
  StreamSubscription? _movementSub;
  StreamSubscription? _tileChangesSub;
  StreamSubscription? _tileBroadcastSub;
  double _wateringCheckTimer = 0.0;

  FarmGame({
    required this.farmId,
    required this.inventoryManager,
    this.onPlotTapped,
    this.onEnterFarmhouse,
    this.onOwlTapped,
    this.onExamine,
    this.onAudioUploaded,
  });
  
  @override
  Color backgroundColor() => const Color(0xFF4A7C59); // Forest green

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Initialize tile grid
    tileGrid = List.generate(mapWidth, (_) => List.filled(mapHeight, null));
    
    // Create pathfinding grid
    pathfindingGrid = PathfindingGrid(mapWidth, mapHeight, tileSize);
    
    // --- Load tiles from backend ---
    final tiles = await _farmTileService.fetchFarmTiles(farmId);
    if (tiles.isNotEmpty) {
      debugPrint('[FarmGame] Loaded ${tiles.length} tiles from backend.');
      for (final tile in tiles) {
        final x = tile.x;
        final y = tile.y;
        if (x >= 0 && x < mapWidth && y >= 0 && y < mapHeight) {
          final type = TileType.values.firstWhere(
            (t) => t.name == tile.tileType,
            orElse: () => TileType.grass,
          );
          final position = Vector2(x * tileSize, y * tileSize);
          final farmTile = FarmTile(
            position, 
            type,
            growthStage: tile.growthStage,
            plantType: tile.plantType,
            isWatered: tile.shouldShowAsWatered,
          );
          tileGrid[x][y] = farmTile;
          world.add(farmTile);
        }
      }
    } else {
      debugPrint('[FarmGame] No tiles found in backend, generating default map.');
      await _createFarmWorld();
    }
    
    // Update pathfinding grid with obstacles
    _updatePathfindingGrid();
    
    // Create player and add it to the world
    player = Player();
    // Set player spawn to the center of the map
    player.position = Vector2(9 * tileSize + tileSize / 2, 7 * tileSize + tileSize / 2);
    player.onPositionChanged = _handlePlayerPositionChange;
    world.add(player);

    // --- Add the Owl NPC for testing ---
    // Place owl at (11,7) or next available grass tile to the right
    int owlX = 11;
    int owlY = 7;
    bool owlPlaced = false;
    for (int dx = 0; dx < mapWidth - owlX && !owlPlaced; dx++) {
      int x = owlX + dx;
      if (x >= mapWidth) break;
      final tile = tileGrid[x][owlY];
      if (tile != null && tile.tileType == TileType.grass) {
        owlX = x;
        owlPlaced = true;
      }
    }
    final owlImage = await images.load('owl.png');
    final owlNotiImage = await images.load('owl_noti.png');
    final frameWidth = 382.0;
    final frameHeight = 478.0;
    final spriteSheet = SpriteSheet(image: owlImage, srcSize: Vector2(frameWidth, frameHeight));
    final idleSprite = spriteSheet.getSprite(0, 0);
    final notificationSprite = Sprite(owlNotiImage);
    final owlNpc = OwlNpcComponent(
      idleSprite: idleSprite,
      notificationSprite: notificationSprite,
      position: Vector2(owlX * tileSize, owlY * tileSize),
      size: Vector2(48, 60),
      onTapOwl: () async {
        debugPrint('[FarmGame] 🦉 Owl tapped in FarmGame');
        final dailyQuestion = await QuestionService.fetchDailyQuestion();
        if (dailyQuestion != null && onOwlTapped != null) {
          debugPrint('[FarmGame] 🦉 Calling onOwlTapped callback with question: ${dailyQuestion.text}');
          onOwlTapped!(dailyQuestion);
        } else {
          debugPrint('[FarmGame] 🦉 No daily question or callback available');
        }
      },
    );
    world.add(owlNpc);
    
    // Register owl as obstacle in pathfinding grid
    final owlKey = '$owlX,$owlY';
    owlPositions.add(owlKey);
    
    // Mark the 1x1 area as obstacle (owl takes up one tile)
    pathfindingGrid.setObstacle(owlX, owlY, true);
    debugPrint('[FarmGame] 🚧 Marking owl tile at ($owlX, $owlY) as obstacle');
    
    // --- End Owl NPC test ---

    // --- Add the Bonfire for testing ---
    // Place bonfire at (13,7) or next available grass tile to the right, skipping owl's tile
    int bonfireX = 13;
    int bonfireY = 7;
    bool bonfirePlaced = false;
    for (int dx = 0; dx < mapWidth - bonfireX && !bonfirePlaced; dx++) {
      int x = bonfireX + dx;
      if (x >= mapWidth) break;
      if (x == owlX && bonfireY == owlY) continue; // skip owl's tile
      final tile = tileGrid[x][bonfireY];
      if (tile != null && tile.tileType == TileType.grass) {
        bonfireX = x;
        bonfirePlaced = true;
      }
    }
    if (bonfirePlaced) {
      final bonfirePosition = Vector2(bonfireX * tileSize, bonfireY * tileSize);
      final bonfire = Bonfire(
        position: bonfirePosition,
        size: Vector2(tileSize, tileSize),
        maxWoodCapacity: 10,
        woodBurnRate: 0.5,
        maxFlameSize: 50,
        maxIntensity: 1.0,
      );
      world.add(bonfire);
      
      // Register test bonfire as obstacle in pathfinding grid
      final bonfireKey = '$bonfireX,$bonfireY';
      bonfirePositions.add(bonfireKey);
      
      // Mark the 1x1 area as obstacle (test bonfire is smaller)
      pathfindingGrid.setObstacle(bonfireX, bonfireY, true);
      debugPrint('[FarmGame] 🚧 Marking test bonfire tile at ($bonfireX, $bonfireY) as obstacle');
      
      bonfire.addWood(8);
      debugPrint('[FarmGame] 🔥 Added test bonfire at ($bonfireX, $bonfireY) with GLSL shader effects');
      debugPrint('[FarmGame] 🔥 Bonfire has  [33m${bonfire.currentWood} [0m wood and intensity ${bonfire.intensity}');
    } else {
      debugPrint('[FarmGame] ❌ Could not find a valid grass tile to place the test bonfire.');
    }

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

  /// Update owl notification based on seed collection status
  Future<void> updateOwlNotification(bool showNotification) async {
    try {
      // Find the owl NPC component in the world
      final owlComponents = world.children.whereType<OwlNpcComponent>();
      if (owlComponents.isNotEmpty) {
        final owlNpc = owlComponents.first;
        owlNpc.showNotification(showNotification);
        debugPrint('[FarmGame] 🦉 Updated owl notification: ${showNotification ? 'ON' : 'OFF'}');
      } else {
        debugPrint('[FarmGame] ⚠️ No owl NPC found in world');
      }
    } catch (e) {
      debugPrint('[FarmGame] ❌ Error updating owl notification: $e');
    }
  }

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
      plotPosition: PlotPosition(10, 6), // Place at (10,6) near center
      bloomVariantSeed: null,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      lastUpdatedAt: DateTime.now(),
    );
    seedsOnMap[dummySeed.plotPosition] = dummySeed;
    // Add the dummy seed to the world (simulate as if it was loaded from backend)
    final dummyTile = FarmTile(Vector2(10 * tileSize, 6 * tileSize), TileType.crop);
    tileGrid[10][6] = dummyTile;
    world.add(dummyTile);
    // Optionally, add a visual marker or log for testing
    debugPrint('Added dummy fully grown daily question plant at (10,6)');

    // Add a chest object near the center of the farm
    final chestStorage = ChestStorage(
      id: 'farm_chest_1',
      coupleId: 'dummy_couple_id', // TODO: get actual couple ID
      position: Position(10.0, 8.0),
      items: [
        ChestItem(id: 'wood', name: 'Wood', quantity: 10),
        ChestItem(id: 'seeds', name: 'Seeds', quantity: 5),
        ChestItem(id: 'watering_can_full', name: 'Watering Can', quantity: 3),
      ],
      name: 'Farm Chest',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      version: 1,
      syncStatus: 'synced',
    );
    
    final chest = ChestObject(
      position: Vector2(10 * tileSize, 8 * tileSize), // near center
      size: Vector2(32, 32),
      examineText: 'A mysterious chest. I wonder what\'s inside...',
      onExamineRequested: onExamine,
      chestStorage: chestStorage,
    );
    world.add(chest);

    // Initialize real-time multiplayer and tile updates
    debugPrint('[FarmGame] 🚀 Starting real-time initialization...');
    await _initializeMultiplayer();
    debugPrint('[FarmGame] ✅ Multiplayer initialized');
    await _initializeTileUpdates();
    debugPrint('[FarmGame] ✅ Tile updates initialized');
    
    // Add a test log to verify the subscription is active
    debugPrint('[FarmGame] 🧪 Real-time setup complete. Farm ID: $farmId');
    debugPrint('[FarmGame] 🧪 Waiting for tile updates from other users...');
    debugPrint('[FarmGame] 🧪 Current user ID: ${SupabaseConfig.currentUserId}');
    
    // Start timer to check watering states periodically
    _startWateringStateTimer();
    
    // Load seashells from the database
    await loadSeashells();
  }
  
  /// Initialize real-time multiplayer features
  Future<void> _initializeMultiplayer() async {
    _farmPlayerService = FarmPlayerService();
    _userId = SupabaseConfig.currentUserId;
    
    if (_userId != null) {
      debugPrint('[FarmGame] Initializing multiplayer for user: $_userId on farm: $farmId');
      
      // Subscribe to real-time player movements
      _subscribeToOtherPlayers();
      
      // Broadcast initial position
      _handlePlayerPositionChange(player.position);
      
      debugPrint('[FarmGame] Multiplayer initialized successfully');
    } else {
      debugPrint('[FarmGame] No user ID available, skipping multiplayer initialization');
    }
  }

  /// Initialize real-time tile updates
  Future<void> _initializeTileUpdates() async {
    debugPrint('[FarmGame] Initializing real-time tile updates for farm: $farmId');
    
    try {
      // Subscribe to database changes (Postgres changes)
      _tileChangesSub = _farmTileService.subscribeToTileChanges(farmId).listen(
        (updatedTile) {
          debugPrint('[FarmGame] ✅ RECEIVED DATABASE TILE UPDATE: (${updatedTile.x}, ${updatedTile.y}) -> ${updatedTile.tileType}');
          _handleTileUpdate(updatedTile);
        },
        onError: (error) {
          debugPrint('[FarmGame] ❌ ERROR in database tile updates subscription: $error');
        },
        onDone: () {
          debugPrint('[FarmGame] 🔚 Database tile updates subscription completed');
        },
      );
      
      // Subscribe to real-time broadcasts (for immediate updates)
      _tileBroadcastSub = _farmTileService.subscribeToTileChangeBroadcasts(farmId).listen(
        (broadcastData) {
          debugPrint('[FarmGame] ✅ RECEIVED TILE BROADCAST: (${broadcastData['x']}, ${broadcastData['y']}) -> ${broadcastData['tile_type']}');
          _handleTileBroadcast(broadcastData);
        },
        onError: (error) {
          debugPrint('[FarmGame] ❌ ERROR in tile broadcast subscription: $error');
        },
        onDone: () {
          debugPrint('[FarmGame] 🔚 Tile broadcast subscription completed');
        },
      );
      
      debugPrint('[FarmGame] ✅ Real-time tile updates initialized successfully');
    } catch (e) {
      debugPrint('[FarmGame] ❌ ERROR initializing tile updates: $e');
    }
  }

  Future<void> _createFarmWorld() async {
    debugPrint('[FarmGame] Creating new farm world and saving to backend...');
    
    // Use the centralized map generation service
    try {
      await _farmTileService.generateAndSaveFarmMap(farmId);
      debugPrint('[FarmGame] ✅ Successfully generated and saved farm map to backend');
    } catch (e) {
      debugPrint('[FarmGame] ❌ ERROR generating farm map: $e');
      // Continue with local map generation if backend fails
    }
    
    // Create the visual tiles for the game world
    for (int x = 0; x < mapWidth; x++) {
      for (int y = 0; y < mapHeight; y++) {
        final position = Vector2(x * tileSize, y * tileSize);
        FarmTile tile;

        // Place a 2x2 wood floor at the spawn (centered at 9,7)
        if (x >= 9 && x <= 10 && y >= 7 && y <= 8) {
          tile = FarmTile(position, TileType.wood);
        }
        // Border - trees/fence (but not in water area)
        else if ((x < 2 || y < 2 || y >= mapHeight - 2) || (x >= mapWidth - 2 && x < 16)) {
          tile = FarmTile(position, TileType.tree);
        }
        // Beach area (right side, now improved)
        else if (x == 16) {
          tile = FarmTile(position, TileType.grassSand);
          debugPrint('[FarmGame] Creating grassSand tile at ($x, $y)');
        } else if (x == 17 || x == 18) {
          tile = FarmTile(position, TileType.sand);
          debugPrint('[FarmGame] Creating sand tile at ($x, $y)');
        } else if (x >= 19) {
          tile = FarmTile(position, TileType.water);
          debugPrint('[FarmGame] Creating WATER tile at ($x, $y)');
        } else {
          // All other tiles are grass
          tile = FarmTile(position, TileType.grass);
        }
        
        // Debug: Log all tile types for water area
        if (x >= 16) {
          debugPrint('[FarmGame] Final tile type at ($x, $y):  [33m${tile.tileType} [0m');
        }
        
        // Store tile in grid and add to world
        tileGrid[x][y] = tile;
        world.add(tile);
      }
    }
    
    // Update pathfinding grid with obstacles
    _updatePathfindingGrid();
  }

  /// Public method to update the pathfinding grid (useful for debugging or external modifications)
  void updatePathfindingGrid() {
    _updatePathfindingGrid();
  }
  
  void _updatePathfindingGrid() {
    // Mark obstacles in pathfinding grid
    for (int x = 0; x < mapWidth; x++) {
      for (int y = 0; y < mapHeight; y++) {
        bool isObstacle = false;
        
        // Border - trees/fence (but not in beach area)
        if ((x < 2 || y < 2 || y >= mapHeight - 2) || (x >= mapWidth - 2 && x < 16)) {
          isObstacle = true;
        }
        // Water tiles are obstacles
        else if (x == 19) {
          isObstacle = true;
        }
        // Check if there's a tile at this position that should be an obstacle
        else {
          final tile = tileGrid[x][y];
          if (tile != null) {
            // Mark certain tile types as obstacles
            switch (tile.tileType) {
              case TileType.tree:
              case TileType.water:
              case TileType.wood:
                isObstacle = true;
                break;
              case TileType.crop:
                // Only make fully grown crops obstacles (optional - you can remove this if you want to walk through crops)
                if (tile.growthStage == 'fully_grown') {
                  isObstacle = true;
                }
                break;
              default:
                // Grass, tilled, grassSand, sand are not obstacles
                break;
            }
            
            // Debug logging for obstacle detection
            if (isObstacle) {
              debugPrint('[FarmGame] 🚧 Marking tile at ($x, $y) as obstacle: ${tile.tileType}${tile.growthStage != null ? ' (${tile.growthStage})' : ''}');
            }
          }
          
           // Check if this position is occupied by a bonfire
           if (!isObstacle) {
             for (final bonfireKey in bonfirePositions) {
               final parts = bonfireKey.split(',');
               if (parts.length == 2) {
                 final bonfireX = int.tryParse(parts[0]);
                 final bonfireY = int.tryParse(parts[1]);
                 if (bonfireX != null && bonfireY != null) {
                   // Check if current position is within the 2x2 bonfire area
                   if (x >= bonfireX && x < bonfireX + 2 && y >= bonfireY && y < bonfireY + 2) {
                     isObstacle = true;
                     debugPrint('[FarmGame] 🚧 Marking tile at ($x, $y) as obstacle: bonfire at ($bonfireX, $bonfireY)');
                     break;
                   }
                 }
               }
             }
           }
           
           // Check if this position is occupied by an owl
           if (!isObstacle) {
             for (final owlKey in owlPositions) {
               final parts = owlKey.split(',');
               if (parts.length == 2) {
                 final owlX = int.tryParse(parts[0]);
                 final owlY = int.tryParse(parts[1]);
                 if (owlX != null && owlY != null) {
                   // Check if current position is occupied by the owl (1x1 area)
                   if (x == owlX && y == owlY) {
                     isObstacle = true;
                     debugPrint('[FarmGame] 🚧 Marking tile at ($x, $y) as obstacle: owl at ($owlX, $owlY)');
                     break;
                   }
                 }
               }
             }
           }
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
      debugPrint('[FarmGame] 🌱 Seed detected at ($gridX, $gridY) - calling onPlotTapped');
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
    
    // Check if bonfire is selected and try to place it
    if (inventoryManager.selectedItem?.id == 'bonfire') {
      if (_tryPlaceBonfire(gridX, gridY)) {
        return;
      }
    }
    // Check if chest is selected and try to place it
    if (inventoryManager.selectedItem?.id == 'chest') {
      if (_tryPlaceChest(gridX, gridY)) {
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

  /// Attempts to place a bonfire on a grass tile
  bool _tryPlaceBonfire(int gridX, int gridY) {
    // Check if tile is adjacent to player
    if (!isTileAdjacentToPlayer(gridX, gridY)) {
      return false;
    }
    
    // Check if tile exists and is grass
    final tile = tileGrid[gridX][gridY];
    if (tile == null || tile.tileType != TileType.grass) {
      return false;
    }
    
    // Check if player has bonfire in inventory
    final selectedItem = inventoryManager.selectedItem;
    if (selectedItem == null || selectedItem.quantity <= 0) {
      return false;
    }
    
    // Place the bonfire
    final bonfirePosition = Vector2(gridX * tileSize, gridY * tileSize);
    final bonfire = Bonfire(
      position: bonfirePosition,
      size: Vector2(tileSize * 2, tileSize * 2), // 2x2 size
      maxWoodCapacity: 10,
      woodBurnRate: 0.5,
      maxFlameSize: 50,
      maxIntensity: 1.0,
    );
    
    // Add bonfire to world
    world.add(bonfire);
    
    // Register bonfire as obstacle in pathfinding grid (2x2 size)
    final bonfireKey = '$gridX,$gridY';
    bonfirePositions.add(bonfireKey);
    
    // Mark the 2x2 area as obstacles
    for (int dx = 0; dx < 2; dx++) {
      for (int dy = 0; dy < 2; dy++) {
        final x = gridX + dx;
        final y = gridY + dy;
        if (x >= 0 && x < mapWidth && y >= 0 && y < mapHeight) {
          pathfindingGrid.setObstacle(x, y, true);
          debugPrint('[FarmGame] 🚧 Marking bonfire tile at ($x, $y) as obstacle');
        }
      }
    }
    
    // Consume one bonfire from inventory
    _consumeSelectedItem(1);
    
    debugPrint('[FarmGame] 🔥 Placed bonfire at ($gridX, $gridY) and registered as obstacle');
    
    return true;
  }

  /// Attempts to place a chest on a grass tile and openable UI on tap
  bool _tryPlaceChest(int gridX, int gridY) {
    // Must be adjacent to player
    if (!isTileAdjacentToPlayer(gridX, gridY)) {
      return false;
    }
    // Must be placeable tile (use grass for now) and not already obstacle
    final tile = tileGrid[gridX][gridY];
    if (tile == null || tile.tileType != TileType.grass) {
      return false;
    }
    if (pathfindingGrid.isObstacle(gridX, gridY)) {
      return false;
    }

    // Create local chest storage entry
    final position = Position(gridX.toDouble(), gridY.toDouble());
    final chestStorage = ChestStorage(
      id: 'chest_${DateTime.now().millisecondsSinceEpoch}',
      coupleId: SupabaseConfig.currentUserId ?? 'local',
      position: position,
      items: const [],
      name: 'Chest',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      version: 1,
      syncStatus: 'local_only',
    );

    // Spawn chest object at tile
    final pos = Vector2(gridX * tileSize, gridY * tileSize);
    final chest = ChestObject(
      position: pos,
      size: Vector2(tileSize, tileSize),
      examineText: 'Open Chest',
      onExamineRequested: onExamine,
      chestStorage: chestStorage,
    );
    world.add(chest);

    // Register as obstacle
    pathfindingGrid.setObstacle(gridX, gridY, true);

    // Consume the chest item from inventory
    _consumeSelectedItem(1);

    return true;
  }

  // Public method to plant a seed at a given tile (called after memory input)
  bool plantSeedAt(int gridX, int gridY, {String? plantType}) {
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
    
    // Determine plant type based on selected item
    final actualPlantType = plantType ?? selectedItem.id;
    
    // Handle daily question seeds specially
    if (actualPlantType == 'daily_question_seed') {
      return _plantDailyQuestionSeed(gridX, gridY);
    }
    
    // Plant the seeds (change tile to seeded)
    _changeTileType(
      gridX, 
      gridY, 
      TileType.crop,
      growthStage: 'planted',
      plantType: actualPlantType,
    );
    
    // Consume one seed from inventory
    _consumeSelectedItem(1);
    
    // Update backend with planting information using new seed system
    debugPrint('[FarmGame] 🌱 Planting $actualPlantType at ($gridX, $gridY)');
    _farmTileService.plantSeed(
      farmId,
      gridX,
      gridY,
      actualPlantType,
      properties: {
        'seed_id': selectedItem.id,
      },
    );
    
    return true;
  }

  /// Plant a daily question seed with special handling
  bool _plantDailyQuestionSeed(int gridX, int gridY) {
    // This method will be called from the UI when the user provides an answer
    // For now, we'll just update the visual tile
    _changeTileType(
      gridX, 
      gridY, 
      TileType.crop,
      growthStage: 'planted',
      plantType: 'daily_question_seed',
    );
    
    // Consume one seed from inventory
    _consumeSelectedItem(1);
    
    debugPrint('[FarmGame] 🌱 Daily question seed planted at ($gridX, $gridY) - waiting for answer');
    
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
    
    // Check if this is a daily question seed that needs special watering
    if (tile.plantType == 'daily_question_seed') {
      // Use the daily question seed service for watering
      _waterDailyQuestionSeed(gridX, gridY);
    } else {
      // Regular watering for normal seeds using new seed system
      _waterRegularSeed(gridX, gridY);
    }
    
    // Consume one use of water from the watering can
    _consumeWateringCanUse();
    
    debugPrint('[FarmGame] 💧 Watering plant at ($gridX, $gridY)');
    
    return true;
  }

  /// Water a regular seed using the new seed system
  Future<void> _waterRegularSeed(int gridX, int gridY) async {
    try {
      debugPrint('[FarmGame] 💧 Watering regular seed at ($gridX, $gridY)');
      
      // Use the new seed system to water the seed
      await _farmTileService.waterSeed(farmId, gridX, gridY);
      
      // Update the visual tile to show it's watered
      _changeTileType(gridX, gridY, TileType.crop, isWatered: true);
      debugPrint('[FarmGame] 🎮 Updated visual tile to show watered state');
      
      debugPrint('[FarmGame] ✅ Regular seed watered successfully');
    } catch (e) {
      debugPrint('[FarmGame] ❌ Error watering regular seed: $e');
    }
  }

  /// Water a daily question seed using the specialized service
  Future<void> _waterDailyQuestionSeed(int gridX, int gridY) async {
    try {
      debugPrint('[FarmGame] 🚰 Attempting to water daily question seed at ($gridX, $gridY)');
      
      final success = await DailyQuestionSeedService.waterDailyQuestionSeed(
        plotX: gridX,
        plotY: gridY,
        farmId: farmId,
      );
      
      if (success) {
        debugPrint('[FarmGame] ✅ SUCCESS: Daily question seed watered at ($gridX, $gridY)');
        
        // Update the visual tile to show it's watered
        _changeTileType(gridX, gridY, TileType.crop, isWatered: true);
        debugPrint('[FarmGame] 🎮 Updated visual tile to show watered state');
        
        // Check if the seed is ready to bloom
        final isReady = await DailyQuestionSeedService.isReadyToBloom(gridX, gridY, farmId);
        if (isReady) {
          debugPrint('[FarmGame] 🌸 Daily question seed is ready to bloom!');
          debugPrint('[FarmGame] 🎮 Updating tile to fully grown stage');
          // Update tile to show it's fully grown
          _changeTileType(gridX, gridY, TileType.crop, growthStage: 'fully_grown');
        } else {
          debugPrint('[FarmGame] 🌱 Daily question seed still growing');
        }
      } else {
        debugPrint('[FarmGame] ❌ Daily question seed watering failed');
      }
    } catch (e) {
      debugPrint('[FarmGame] ❌ Error watering daily question seed: $e');
    }
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
  void _changeTileType(int gridX, int gridY, TileType newType, {bool skipBackendUpdate = false, String? growthStage, String? plantType, bool? isWatered}) {
    final oldTile = tileGrid[gridX][gridY];
    if (oldTile == null) {
      debugPrint('[FarmGame] Tried to change tile at ($gridX, $gridY) but no tile exists.');
      return;
    }
    debugPrint('[FarmGame] Changing tile at ($gridX, $gridY) from ${oldTile.tileType} to $newType');
    // Remove old tile from world
    world.remove(oldTile);
    // Create new tile with same position but different type
    final position = Vector2(gridX * tileSize, gridY * tileSize);
    final newTile = FarmTile(position, newType, growthStage: growthStage, plantType: plantType, isWatered: isWatered);
    // Update grid and add to world
    tileGrid[gridX][gridY] = newTile;
    world.add(newTile);
    
    // Update pathfinding grid to reflect the new obstacle
    _updatePathfindingGrid();
    
    // Only persist to backend if not skipping (prevents infinite loops from real-time updates)
    if (!skipBackendUpdate) {
      // --- Persist to backend ---
      // Determine watering state: use isWatered parameter if provided, otherwise check if tile type is water
      final wateredState = isWatered ?? (newType == TileType.water);
      debugPrint('[FarmGame] Calling updateTile on backend: farmId=$farmId, x=$gridX, y=$gridY, tileType=${newType.name}, watered=$wateredState');
      _farmTileService.updateTile(
        farmId: farmId,
        x: gridX,
        y: gridY,
        tileType: newType.name,
        watered: wateredState,
        userId: _userId, // Pass user ID for broadcast
      ).then((_) {
        debugPrint('[FarmGame] Successfully updated tile ($gridX, $gridY) to $newType on backend.');
      }).catchError((e) {
        debugPrint('[FarmGame] ERROR updating tile ($gridX, $gridY) to $newType on backend: $e');
      });
    } else {
      debugPrint('[FarmGame] Skipping backend update for real-time tile change at ($gridX, $gridY)');
    }
  }

  /// Public method to update a tile to crop (planted) after planting a seed externally
  void updateTileToCrop(int gridX, int gridY, {String? plantType}) {
    _changeTileType(
      gridX, 
      gridY, 
      TileType.crop,
      growthStage: 'planted',
      plantType: plantType,
    );
  }

  /// Public method to update a tile's growth stage
  void updateTileGrowthStage(int gridX, int gridY, String growthStage) {
    final currentTile = tileGrid[gridX][gridY];
    if (currentTile == null) return;
    
    _changeTileType(
      gridX,
      gridY,
      currentTile.tileType,
      growthStage: growthStage,
      plantType: currentTile.plantType,
    );
  }

  /// Remove a bonfire from the world and update pathfinding grid
  void removeBonfire(int gridX, int gridY) {
    final bonfireKey = '$gridX,$gridY';
    if (bonfirePositions.contains(bonfireKey)) {
      // Remove from tracking
      bonfirePositions.remove(bonfireKey);
      
      // Clear the 2x2 area from pathfinding obstacles
      for (int dx = 0; dx < 2; dx++) {
        for (int dy = 0; dy < 2; dy++) {
          final x = gridX + dx;
          final y = gridY + dy;
          if (x >= 0 && x < mapWidth && y >= 0 && y < mapHeight) {
            // Only clear if no other obstacles exist at this position
            final tile = tileGrid[x][y];
            bool shouldBeObstacle = false;
            
            if (tile != null) {
              switch (tile.tileType) {
                case TileType.tree:
                case TileType.water:
                case TileType.wood:
                  shouldBeObstacle = true;
                  break;
                case TileType.crop:
                  if (tile.growthStage == 'fully_grown') {
                    shouldBeObstacle = true;
                  }
                  break;
                default:
                  break;
              }
            }
            
            // Check if any other bonfires occupy this position
            for (final otherBonfireKey in bonfirePositions) {
              final parts = otherBonfireKey.split(',');
              if (parts.length == 2) {
                final otherBonfireX = int.tryParse(parts[0]);
                final otherBonfireY = int.tryParse(parts[1]);
                if (otherBonfireX != null && otherBonfireY != null) {
                  if (x >= otherBonfireX && x < otherBonfireX + 2 && y >= otherBonfireY && y < otherBonfireY + 2) {
                    shouldBeObstacle = true;
                    break;
                  }
                }
              }
            }
            
            pathfindingGrid.setObstacle(x, y, shouldBeObstacle);
            debugPrint('[FarmGame] 🚧 Updated tile at ($x, $y) obstacle status: $shouldBeObstacle (after bonfire removal)');
          }
        }
      }
      
      debugPrint('[FarmGame] 🔥 Removed bonfire at ($gridX, $gridY) from pathfinding grid');
    }
  }

  /// Remove an owl from the world and update pathfinding grid
  void removeOwl(int gridX, int gridY) {
    final owlKey = '$gridX,$gridY';
    if (owlPositions.contains(owlKey)) {
      // Remove from tracking
      owlPositions.remove(owlKey);
      
      // Clear the 1x1 area from pathfinding obstacles
      if (gridX >= 0 && gridX < mapWidth && gridY >= 0 && gridY < mapHeight) {
        // Only clear if no other obstacles exist at this position
        final tile = tileGrid[gridX][gridY];
        bool shouldBeObstacle = false;
        
        if (tile != null) {
          switch (tile.tileType) {
            case TileType.tree:
            case TileType.water:
            case TileType.wood:
              shouldBeObstacle = true;
              break;
            case TileType.crop:
              if (tile.growthStage == 'fully_grown') {
                shouldBeObstacle = true;
              }
              break;
            default:
              break;
          }
        }
        
        // Check if any other owls occupy this position
        for (final otherOwlKey in owlPositions) {
          final parts = otherOwlKey.split(',');
          if (parts.length == 2) {
            final otherOwlX = int.tryParse(parts[0]);
            final otherOwlY = int.tryParse(parts[1]);
            if (otherOwlX != null && otherOwlY != null) {
              if (gridX == otherOwlX && gridY == otherOwlY) {
                shouldBeObstacle = true;
                break;
              }
            }
          }
        }
        
        pathfindingGrid.setObstacle(gridX, gridY, shouldBeObstacle);
        debugPrint('[FarmGame] 🚧 Updated tile at ($gridX, $gridY) obstacle status: $shouldBeObstacle (after owl removal)');
      }
      
      debugPrint('[FarmGame] 🦉 Removed owl at ($gridX, $gridY) from pathfinding grid');
    }
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

  void _broadcastMyDestination(int gridX, int gridY, {String? animationState}) {
    if (_userId == null) return;
    // Throttle to ~10 Hz
    final now = DateTime.now();
    if (_lastDestinationBroadcastAt != null &&
        now.difference(_lastDestinationBroadcastAt!).inMilliseconds < 100) {
      return;
    }
    _lastDestinationBroadcastAt = now;
    _farmPlayerService.broadcastPlayerDestination(
      farmId: farmId,
      userId: _userId!,
      targetGridX: gridX,
      targetGridY: gridY,
      animationState: animationState,
      tileSize: tileSize, // Pass the correct tile size for FarmGame
    );
  }
  
  void _handlePlayerPositionChange(Vector2 pos, {String? animationState}) {
    // Convert position to grid coordinates for destination broadcasting
    final gridX = (pos.x / tileSize).floor();
    final gridY = (pos.y / tileSize).floor();
    
    // Only broadcast when player reaches a new tile
    if (_lastBroadcastGridX != gridX || _lastBroadcastGridY != gridY) {
      _lastBroadcastGridX = gridX;
      _lastBroadcastGridY = gridY;
      _broadcastMyDestination(gridX, gridY, animationState: animationState);
    }
  }
  
  int? _lastBroadcastGridX;
  int? _lastBroadcastGridY;
  DateTime? _lastDestinationBroadcastAt;

  void _subscribeToOtherPlayers() {
    _movementSub?.cancel();
    _movementSub = _farmPlayerService.subscribeToPlayerDestinationBroadcast(farmId).listen((destination) {
      if (destination.userId == _userId) return; // Don't render self
      
      if (!otherPlayers.containsKey(destination.userId)) {
        // New player joined
        debugPrint('[FarmGame] New player joined: ${destination.userId}');
        
        final other = SmoothPlayer();
        // Set initial position to the destination tile
        other.position = Vector2(
          destination.targetGridX * tileSize + tileSize / 2,
          destination.targetGridY * tileSize + tileSize / 2,
        );
        other.opacity = 0.7; // Make other players slightly transparent
        other.priority = 5; // Render below main player
        
        // Add a name tag or visual indicator
        other.add(
          TextComponent(
            text: 'Partner',
            position: Vector2(0, -30),
            textRenderer: TextPaint(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                shadows: [Shadow(color: Colors.black, blurRadius: 1)],
              ),
            ),
          ),
        );
        
        // Add a join effect (optional)
        other.add(
          CircleComponent(
            radius: 20,
            paint: Paint()
              ..color = Colors.green.withOpacity(0.3)
              ..style = PaintingStyle.fill,
          )..add(
            SequenceEffect([
              ScaleEffect.to(Vector2.all(2.0), EffectController(duration: 0.5)),
              ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.5)),
              RemoveEffect(),
            ]),
          ),
        );
        
        otherPlayers[destination.userId] = other;
        world.add(other);
        
        // Show notification
        debugPrint('[FarmGame] Your partner has joined the farm!');
      } else {
        // Use destination-based movement for existing players
        final otherPlayer = otherPlayers[destination.userId]!;
        
        // Move to the destination tile
        final targetPosition = Vector2(
          destination.targetGridX * tileSize + tileSize / 2,
          destination.targetGridY * tileSize + tileSize / 2,
        );
        
        otherPlayer.moveToPosition(targetPosition, tileSize: destination.tileSize);
        
        // Update animation state if provided
        if (destination.animationState != null) {
          _updateOtherPlayerAnimation(otherPlayer, destination.animationState!);
        }
      }
    });
  }
  
  void _updateOtherPlayerAnimation(SmoothPlayer otherPlayer, String animationState) {
    // Update the other player's animation based on the received state
    switch (animationState) {
      case 'up':
        otherPlayer.updateDirection(PlayerDirection.up);
        break;
      case 'down':
        otherPlayer.updateDirection(PlayerDirection.down);
        break;
      case 'left':
        otherPlayer.updateDirection(PlayerDirection.left);
        break;
      case 'right':
        otherPlayer.updateDirection(PlayerDirection.right);
        break;
      case 'idle':
        otherPlayer.updateDirection(PlayerDirection.idle);
        break;
    }
  }

  /// Handle real-time tile updates from other users
  void _handleTileUpdate(FarmTileModel updatedTile) {
    final x = updatedTile.x;
    final y = updatedTile.y;
    
    debugPrint('[FarmGame] 🔄 Processing real-time tile update: (${updatedTile.x}, ${updatedTile.y}) -> ${updatedTile.tileType}');
    
    // Check if the tile is within bounds
    if (x < 0 || x >= mapWidth || y < 0 || y >= mapHeight) {
      debugPrint('[FarmGame] ❌ Tile update out of bounds: ($x, $y)');
      return;
    }
    
    // Convert tile type string to enum
    final newType = TileType.values.firstWhere(
      (t) => t.name == updatedTile.tileType,
      orElse: () => TileType.grass,
    );
    
    debugPrint('[FarmGame] 📋 Converted tile type: ${updatedTile.tileType} -> $newType');
    
    // Check if the tile has actually changed (including watering state)
    final currentTile = tileGrid[x][y];
    final shouldUpdate = currentTile == null || 
                        currentTile.tileType != newType ||
                        currentTile.growthStage != updatedTile.growthStage ||
                        currentTile.plantType != updatedTile.plantType ||
                        currentTile.isWatered != updatedTile.shouldShowAsWatered;
    
    if (!shouldUpdate) {
      debugPrint('[FarmGame] ⏭️ Tile at ($x, $y) has no changes, skipping update');
      return;
    }
    
    debugPrint('[FarmGame] ✅ Updating tile at ($x, $y) to $newType (real-time update)');
    debugPrint('[FarmGame] 📊 Changes detected: type=${currentTile?.tileType}->$newType, growth=${currentTile?.growthStage}->${updatedTile.growthStage}, watered=${currentTile?.isWatered}->${updatedTile.shouldShowAsWatered}');
    
    // Update the tile visually with growth stage information
    _changeTileType(
      x, 
      y, 
      newType, 
      skipBackendUpdate: true,
      growthStage: updatedTile.growthStage,
      plantType: updatedTile.plantType,
      isWatered: updatedTile.shouldShowAsWatered,
    );
    
    // Add a visual effect to show the tile was updated by another user
    _addTileUpdateEffect(x, y, growthStage: updatedTile.growthStage);
    
    debugPrint('[FarmGame] ✅ Real-time tile update completed for ($x, $y)');
  }

  /// Handle real-time tile broadcasts from other users (immediate updates)
  void _handleTileBroadcast(Map<String, dynamic> broadcastData) {
    final x = broadcastData['x'] as int;
    final y = broadcastData['y'] as int;
    final tileType = broadcastData['tile_type'] as String;
    final userId = broadcastData['user_id'] as String?;
    
    debugPrint('[FarmGame] 🔄 Processing tile broadcast: ($x, $y) -> $tileType from user: $userId');
    
    // Skip if this is our own broadcast
    if (userId == _userId) {
      debugPrint('[FarmGame] ⏭️ Skipping own tile broadcast');
      return;
    }
    
    // Check if the tile is within bounds
    if (x < 0 || x >= mapWidth || y < 0 || y >= mapHeight) {
      debugPrint('[FarmGame] ❌ Tile broadcast out of bounds: ($x, $y)');
      return;
    }
    
    // Convert tile type string to enum
    final newType = TileType.values.firstWhere(
      (t) => t.name == tileType,
      orElse: () => TileType.grass,
    );
    
    debugPrint('[FarmGame] 📋 Converted broadcast tile type: $tileType -> $newType');
    
    // Update the tile immediately (this is a broadcast, so we trust it)
    _changeTileType(
      x, 
      y, 
      newType, 
      skipBackendUpdate: true, // Skip backend update since this came from a broadcast
      growthStage: broadcastData['growth_stage'] as String?,
      plantType: broadcastData['plant_type'] as String?,
      isWatered: broadcastData['watered'] as bool?,
    );
    
    // Add a visual effect to show the tile was updated by another user
    _addTileUpdateEffect(x, y, growthStage: broadcastData['growth_stage'] as String?);
    
    debugPrint('[FarmGame] ✅ Tile broadcast processed for ($x, $y)');
  }

  /// Add a visual effect to show a tile was updated by another user
  void _addTileUpdateEffect(int x, int y, {String? growthStage}) {
    final position = Vector2(x * tileSize + tileSize / 2, y * tileSize + tileSize / 2);
    
    // Choose effect color based on update type
    Color effectColor;
    String notificationText;
    
    if (growthStage == 'fully_grown') {
      effectColor = Colors.green;
      notificationText = 'Plant grown!';
    } else if (growthStage == 'planted') {
      // Check if this might be a watering update
      final currentTile = tileGrid[x][y];
      if (currentTile?.isWatered == true) {
        effectColor = Colors.blue;
        notificationText = 'Plant watered!';
      } else {
        effectColor = Colors.yellow;
        notificationText = 'Partner updated!';
      }
    } else {
      effectColor = Colors.yellow;
      notificationText = 'Partner updated!';
    }
    
    // Create a glowing effect
    final effect = CircleComponent(
      radius: tileSize / 2,
      paint: Paint()
        ..color = effectColor.withOpacity(0.6)
        ..style = PaintingStyle.fill,
      position: position,
    );
    
    // Add a pulsing animation
    effect.add(
      SequenceEffect([
        ScaleEffect.to(Vector2.all(1.5), EffectController(duration: 0.3)),
        ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.3)),
        ScaleEffect.to(Vector2.all(1.3), EffectController(duration: 0.2)),
        ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.2)),
        RemoveEffect(),
      ]),
    );
    
    world.add(effect);
    
    // Show a notification text
    final notification = TextComponent(
      text: notificationText,
      position: Vector2(position.x - 30, position.y - 40),
      textRenderer: TextPaint(
        style: TextStyle(
          color: effectColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black, blurRadius: 1)],
        ),
      ),
    );
    
    notification.add(
      SequenceEffect([
        MoveEffect.by(Vector2(0, -20), EffectController(duration: 1.0)),
        RemoveEffect(),
      ]),
    );
    
    world.add(notification);
  }

  /// Start a timer to periodically check and update watering states
  void _startWateringStateTimer() {
    // Reset the timer counter
    _wateringCheckTimer = 0.0;
  }

  /// Update the visual state of tiles based on their watering status
  void _updateWateringStates() {
    // This would need to fetch the latest tile data from the backend
    // For now, we'll implement a simpler approach by checking tiles we have in memory
    debugPrint('[FarmGame] 🔄 Checking watering states for all tiles...');
    
    // In a full implementation, you would:
    // 1. Fetch the latest tile data from the backend
    // 2. Compare with current visual states
    // 3. Update tiles that need visual changes
    
    // For now, we'll just log that this is happening
    // TODO: Implement full watering state update logic
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Update other players' positions
    for (final otherPlayer in otherPlayers.values) {
      otherPlayer.update(dt);
    }
    
    // Check watering states every 5 minutes (300 seconds)
    _wateringCheckTimer += dt;
    if (_wateringCheckTimer >= 300.0) {
      _updateWateringStates();
      _wateringCheckTimer = 0.0;
    }
  }

  @override
  void onRemove() {
    _movementSub?.cancel();
    _tileChangesSub?.cancel();
    _tileBroadcastSub?.cancel();
    super.onRemove();
  }

  /// Add a test bonfire for GLSL shader testing
  void _addTestBonfire() {
    // Try to find a valid grass tile near the center
    final centerX = mapWidth ~/ 2;
    final centerY = mapHeight ~/ 2;
    const searchRadius = 3;
    bool placed = false;
    for (int r = 0; r <= searchRadius && !placed; r++) {
      for (int dx = -r; dx <= r && !placed; dx++) {
        for (int dy = -r; dy <= r && !placed; dy++) {
          final x = centerX + dx;
          final y = centerY + dy;
          if (x >= 0 && x < mapWidth && y >= 0 && y < mapHeight) {
            final tile = tileGrid[x][y];
            if (tile != null && tile.tileType == TileType.grass) {
              final bonfirePosition = Vector2(x * tileSize, y * tileSize);
              final bonfire = Bonfire(
                position: bonfirePosition,
                size: Vector2(tileSize, tileSize), // 1x1 tile, matches 32x32 sprite
                maxWoodCapacity: 10,
                woodBurnRate: 0.5,
                maxFlameSize: 50,
                maxIntensity: 1.0,
              );
              world.add(bonfire);
              bonfire.addWood(8);
              debugPrint('[FarmGame] 🔥 Added test bonfire at ($x, $y) with GLSL shader effects');
              debugPrint('[FarmGame] 🔥 Bonfire has  [33m${bonfire.currentWood} [0m wood and intensity ${bonfire.intensity}');
              placed = true;
            }
          }
        }
      }
    }
    if (!placed) {
      debugPrint('[FarmGame] ❌ Could not find a valid grass tile to place the test bonfire.');
    }
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    final superResult = super.onKeyEvent(event, keysPressed);
    if (superResult == KeyEventResult.handled) return superResult;
    return player.handleKeyEvent(keysPressed);
  }

  // Method to spawn a seashell at a specific position
  void spawnSeashell(String id, String audioUrl, double x, double y, {bool highlightUnheard = false}) {
    final seashell = SeashellObject(
      position: Vector2(x * tileSize, y * tileSize),
      size: Vector2(tileSize * 0.8, tileSize * 0.8), // Slightly smaller than a tile
      audioUrl: audioUrl,
      id: id,
      highlightUnheard: highlightUnheard,
      onPlayAudio: () {
        print('Playing seashell audio: $audioUrl');
        // You can add additional audio handling here if needed
      },
    );
    
    world.add(seashell);
    print('Seashell spawned at position ($x, $y)');
  }

  /// Load and spawn the 5 most recent seashells from the database
  Future<void> loadSeashells() async {
    try {
      debugPrint('[FarmGame] 🐚 Loading seashells from database...');
      
      // Fetch the 5 most recent seashells
      final seashells = await SeashellService.fetchRecentSeashells(limit: 5);
      
      if (seashells.isEmpty) {
        debugPrint('[FarmGame] 🐚 No seashells found for this couple');
        return;
      }
      
      debugPrint('[FarmGame] 🐚 Found ${seashells.length} seashells to load');
      
      // Generate positions for seashells on the beach
      final positions = SeashellService.generateSeashellPositions(
        seashells,
        mapWidth: mapWidth,
        mapHeight: mapHeight,
        beachStartX: 16, // Beach starts at x=16
      );
      
      // Spawn seashells at the generated positions
      for (int i = 0; i < seashells.length && i < positions.length; i++) {
        final seashell = seashells[i];
        final position = positions[i];
        
        spawnSeashell(
          seashell.id,
          seashell.audioUrl,
          position.x,
          position.y,
          highlightUnheard: (seashell.userId != (_userId ?? SupabaseConfig.currentUserId)) && !seashell.heardByCurrentUser,
        );
        
        debugPrint('[FarmGame] 🐚 Spawned seashell ${seashell.id} at beach position (${position.x}, ${position.y})');
      }
      
      debugPrint('[FarmGame] 🐚 Successfully loaded ${seashells.length} seashells on the beach');
    } catch (e) {
      debugPrint('[FarmGame] ❌ Error loading seashells: $e');
    }
  }
} 