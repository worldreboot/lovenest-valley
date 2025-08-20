import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flame/geometry.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:tiled/tiled.dart' hide Point;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lovenest/components/player.dart';
import 'package:lovenest/utils/pathfinding.dart';
import 'package:lovenest/game/base/game_with_grid.dart';
import 'package:lovenest/components/world/bonfire.dart';
import 'package:lovenest/components/owl_npc.dart';
import 'package:lovenest/services/question_service.dart';
import 'package:lovenest/models/memory_garden/question.dart';
import 'package:lovenest/models/chest_storage.dart';
import 'package:lovenest/behaviors/camera_bounds.dart';
import 'package:lovenest/components/world/hoe_animation.dart';
import 'package:lovenest/components/world/watering_can_animation.dart';
import 'package:lovenest/models/inventory.dart';
import 'package:lovenest/services/farm_tile_service.dart';
import 'package:lovenest/services/farm_player_service.dart';
import 'package:lovenest/config/supabase_config.dart';
import 'package:lovenest/components/smooth_player.dart';
import 'package:lovenest/models/farm_tile_model.dart';
import 'package:lovenest/utils/tiled_parser.dart' as custom_parser;
import 'package:lovenest/components/world/enhanced_dynamic_tilemap.dart';
import 'package:flame/effects.dart';
import 'dart:async';
import 'dart:math' show Point;

class TiledFarmGame extends GameWithGrid with HasCollisionDetection, HasKeyboardHandlerComponents, TapCallbacks {
  final String farmId;
  late Player player;
  late CameraComponent cameraComponent;
  late PathfindingGrid _pathfindingGrid;
  late EnhancedDynamicTilemap _tilemap;
  
  // Custom parser instances
  late custom_parser.TilesetParser _tilesetParser;
  late custom_parser.MapParser _mapParser;
  late custom_parser.AutoTiler _autoTiler;
  
  // Map dimensions from the Tiled file
  static const int mapWidth = 64;
  static const int mapHeight = 28;
  static const double tileSize = 16.0;
  
  // Store bonfire positions for pathfinding
  final Set<String> bonfirePositions = {};
  
  // Store owl positions for pathfinding
  final Set<String> owlPositions = {};

  // Inventory manager for checking tools
  final InventoryManager? inventoryManager;

  // Multiplayer sync services
  final FarmTileService _farmTileService = FarmTileService();
  late final FarmPlayerService _farmPlayerService;
  String? _userId;
  StreamSubscription? _movementSub;
  StreamSubscription? _tileChangesSub;
  StreamSubscription? _tileBroadcastSub;
  
  // Store other players for multiplayer
  final Map<String, SmoothPlayer> otherPlayers = {};

  // Track tile modifications from backend
  final Map<String, FarmTileModel> modifiedTiles = {};

  // Track visual overlays for changed tiles
  final Map<String, SpriteComponent> tileOverlays = {};

  // Hoe highlighting system
  final Map<String, RectangleComponent> _hoeHighlights = {};
  bool _isPlayerMoving = false; // Track if player is currently moving
  double _lastMovementTime = 0.0; // Track when player last moved
  bool _currentHoeState = false; // Current hoe state
  MapEntry<int, int>? _lastPlayerPosition; // Track player's last grid position
  bool _isHoeAnimationPlaying = false; // Track if hoe animation is currently playing
  
  // Watering can highlighting system
  final Map<String, RectangleComponent> _wateringCanHighlights = {};
  bool _currentWateringCanState = false; // Current watering can state
  bool _isWateringCanAnimationPlaying = false; // Track if watering can animation is currently playing

  // Wang Set configuration for autotiling
  static const Map<String, int> wangColorIndices = {
    'Dirt': 0,
    'Pond': 1, 
    'Tilled': 2,
    'Grass': 3,
    'HighGround': 4,
    'HighGroundMid': 5,
  };

  // Wang Set tile mappings (tileId -> wangId)
  static const Map<int, List<int>> wangTileMappings = {
    1: [0,4,0,4,0,4,0,4],
    2: [0,4,0,4,0,4,0,4],
    3: [0,4,0,4,0,4,0,4],
    4: [0,4,0,4,0,4,0,4],
    8: [0,5,0,4,0,5,0,5],
    9: [0,5,0,4,0,4,0,5],
    10: [0,5,0,5,0,4,0,5],
    11: [0,4,0,1,0,4,0,4],
    12: [0,4,0,1,0,1,0,4],
    13: [0,4,0,4,0,1,0,4],
    16: [0,4,0,4,0,4,0,4],
    19: [0,4,0,4,0,4,0,4],
    23: [0,4,0,4,0,5,0,5],
    24: [0,4,0,4,0,4,0,4], // Grass tile
    25: [0,5,0,5,0,4,0,4],
    26: [0,1,0,1,0,4,0,4],
    27: [0,1,0,1,0,1,0,1], // Base tilled soil
    28: [0,4,0,4,0,1,0,1], // Tilled soil variant
    31: [0,4,0,4,0,4,0,4],
    34: [0,4,0,4,0,4,0,4],
    38: [0,4,0,5,0,5,0,5],
    39: [0,4,0,5,0,5,0,4],
    40: [0,5,0,5,0,5,0,4],
    41: [0,1,0,4,0,4,0,4],
    42: [0,1,0,4,0,4,0,1],
    43: [0,4,0,4,0,4,0,1],
    47: [0,4,0,2,0,4,0,4],
    48: [0,4,0,2,0,2,0,4],
    49: [0,4,0,4,0,2,0,4],
    54: [0,5,0,5,0,5,0,5],
    58: [0,1,0,4,0,1,0,1],
    59: [0,1,0,1,0,4,0,1],
    62: [0,2,0,2,0,4,0,4],
    63: [0,2,0,2,0,2,0,2],
    64: [0,4,0,4,0,2,0,2],
    73: [0,4,0,1,0,1,0,1],
    74: [0,1,0,1,0,1,0,4],
    77: [0,2,0,4,0,4,0,4],
    78: [0,2,0,4,0,4,0,2],
    79: [0,4,0,4,0,4,0,2],
    92: [0,2,0,4,0,2,0,2],
    93: [0,2,0,2,0,4,0,2],
    107: [0,4,0,2,0,2,0,2],
    108: [0,2,0,2,0,2,0,4],
    120: [0,3,0,4,0,3,0,3],
    121: [0,3,0,3,0,4,0,3],
    122: [0,4,0,3,0,4,0,4],
    123: [0,4,0,3,0,3,0,4],
    124: [0,4,0,4,0,3,0,4],
    135: [0,4,0,3,0,3,0,3],
    136: [0,3,0,3,0,3,0,4],
    137: [0,3,0,3,0,4,0,4],
    138: [0,3,0,3,0,3,0,3],
    139: [0,4,0,4,0,3,0,3],
    152: [0,3,0,4,0,4,0,4],
    153: [0,3,0,4,0,4,0,3],
    154: [0,4,0,4,0,4,0,3],
  };

  // Callbacks
  final VoidCallback? onEnterFarmhouse;
  final void Function(Question)? onOwlTapped;
  final void Function(String, ChestStorage?)? onExamine;
  final void Function(String audioUrl)? onAudioUploaded;

  TiledFarmGame({
    required this.farmId,
    this.inventoryManager,
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
    
    // Initialize custom parsers
    await _initializeCustomParsers();
    
    // Load the enhanced tilemap with our custom parser
    debugPrint('[TiledFarmGame] Loading enhanced tilemap with custom parser...');
    await _initializeEnhancedTilemap();
    debugPrint('[TiledFarmGame] ✅ Enhanced tilemap loaded successfully');
    
    // Create pathfinding grid
    _pathfindingGrid = PathfindingGrid(mapWidth, mapHeight, tileSize);
    
    // Spawn player at hardcoded position (based on the PlayerSpawn object coordinates)
    await _spawnPlayer();
    
    // Add NPCs and objects
    await _addNPCsAndObjects();
    
    // Set up camera
    _setupCamera();
    
    // Add UI elements
    await _addUI();
    
    // Load saved tiles from backend and create overlays
    await _loadSavedTiles();
    
    // Initialize real-time multiplayer and tile updates
    debugPrint('[TiledFarmGame] 🚀 Starting real-time initialization...');
    await _initializeMultiplayer();
    debugPrint('[TiledFarmGame] ✅ Multiplayer initialized');
    await _initializeTileUpdates();
    debugPrint('[TiledFarmGame] ✅ Tile updates initialized');
    
    // Add a test log to verify the subscription is active
    debugPrint('[TiledFarmGame] 🧪 Real-time setup complete. Farm ID: $farmId');
    debugPrint('[TiledFarmGame] 🧪 Waiting for tile updates from other users...');
    debugPrint('[TiledFarmGame] 🧪 Current user ID: ${SupabaseConfig.currentUserId}');
    
    // Initialize hoe state and listen to inventory changes
    _currentHoeState = _checkIfPlayerHasHoe();
    
    // Initialize watering can state
    _currentWateringCanState = _checkIfPlayerHasWateringCan();
    
    if (inventoryManager != null) {
      inventoryManager!.addListener(_onInventoryChanged);
    }
  }

  /// Initialize our custom Tiled parsers
  Future<void> _initializeCustomParsers() async {
    debugPrint('[TiledFarmGame] Initializing custom parsers...');

    // Load tileset data
    _tilesetParser = custom_parser.TilesetParser('assets/ground.tsx');
    await _tilesetParser.load();

    // Load map data
    _mapParser = custom_parser.MapParser('assets/tiles/valley.tmx');
    await _mapParser.load();

    // Create auto-tiler with wang tiles
    final wangTiles = _tilesetParser.getWangTiles();
    _autoTiler = custom_parser.AutoTiler(wangTiles, {}); // Pass an empty map for legacy compatibility
    
    debugPrint('[TiledFarmGame] Parsers initialized:');
    debugPrint('  - Tileset: ${_tilesetParser.getTilesetInfo()}');
    debugPrint('  - Map: ${_mapParser.getMapInfo()}');
    debugPrint('  - Wang tiles: ${wangTiles.length}');
  }

  /// Initialize the enhanced tilemap component
  Future<void> _initializeEnhancedTilemap() async {
    debugPrint('[TiledFarmGame] Initializing enhanced tilemap...');

    // Create a mock RenderableTiledMap for compatibility
    final mockMap = _createMockTiledMap();
    
    _tilemap = EnhancedDynamicTilemap(mockMap, tileSize: tileSize);
    world.add(_tilemap);

    debugPrint('[TiledFarmGame] Tilemap initialized');
  }

  /// Create a mock RenderableTiledMap for compatibility with existing components
  RenderableTiledMap _createMockTiledMap() {
    // Create a minimal TiledMap for compatibility
    final map = TiledMap(
      width: mapWidth,
      height: mapHeight,
      tileWidth: tileSize.toInt(),
      tileHeight: tileSize.toInt(),
      orientation: MapOrientation.orthogonal,
      renderOrder: RenderOrder.rightDown,
    );
    
    // Create a simple mock - the enhanced tilemap will use our custom parsers anyway
    return RenderableTiledMap(
      map,
      [], // Empty layers - simplified
      Vector2.zero(), // No offset
    );
  }

  Future<void> _spawnPlayer() async {
    debugPrint('[TiledFarmGame] Spawning player...');
    
    // Try to find the PlayerSpawn object in the Tiled map
    bool playerSpawned = false;
    try {
      final objectGroups = _mapParser.getObjectGroups();
      for (final group in objectGroups) {
        if (group.name == 'SpawnPoint') {
          for (final obj in group.objects) {
            if (obj.name == 'Spawn') {
              player = Player();
              player.position = Vector2(obj.x, obj.y);
              player.onPositionChanged = (position, {animationState}) => _handlePlayerPositionChange(position);
              world.add(player);
              playerSpawned = true;
              debugPrint('[TiledFarmGame] ✅ Player spawned at (${player.position.x}, ${player.position.y}) from Spawn object');
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[TiledFarmGame] ⚠️ Error accessing Tiled map objects: $e');
    }
    
    // Fallback to hardcoded position if no PlayerSpawn object found
    if (!playerSpawned) {
      debugPrint('[TiledFarmGame] ⚠️ No PlayerSpawn object found, using fallback position');
      final spawnX = 488.0;
      final spawnY = 181.0;
      
      player = Player();
      player.position = Vector2(spawnX, spawnY);
      player.onPositionChanged = (position, {animationState}) => _handlePlayerPositionChange(position);
      world.add(player);
      
      debugPrint('[TiledFarmGame] ✅ Player spawned at fallback position (${player.position.x}, ${player.position.y})');
    }
  }

  Future<void> _addNPCsAndObjects() async {
    // Add the Owl NPC (using approximate position from original map)
    final owlX = 22; // Convert from original 32x32 coordinates to 16x16
    final owlY = 14;
    
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
        final dailyQuestion = await QuestionService.fetchDailyQuestion();
        if (dailyQuestion != null && onOwlTapped != null) {
          onOwlTapped!(dailyQuestion);
        }
      },
    );
    world.add(owlNpc);
    
    // Register owl as obstacle in pathfinding grid
    final owlKey = '$owlX,$owlY';
    owlPositions.add(owlKey);
    _pathfindingGrid.setObstacle(owlX, owlY, true);
    debugPrint('[TiledFarmGame] 🚧 Marking owl tile at ($owlX, $owlY) as obstacle');
    
    // Add a test bonfire
    final bonfireX = 26;
    final bonfireY = 14;
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
    
    // Register bonfire as obstacle
    final bonfireKey = '$bonfireX,$bonfireY';
    bonfirePositions.add(bonfireKey);
    _pathfindingGrid.setObstacle(bonfireX, bonfireY, true);
    debugPrint('[TiledFarmGame] 🚧 Marking bonfire tile at ($bonfireX, $bonfireY) as obstacle');
    
    bonfire.addWood(8);
    debugPrint('[TiledFarmGame] 🔥 Added bonfire at ($bonfireX, $bonfireY)');
    
    // Always show notification sprite for debugging
    owlNpc.showNotification(true);
    
    // Fetch daily question and update owl notification
    final dailyQuestion = await QuestionService.fetchDailyQuestion();
    if (dailyQuestion != null) {
      owlNpc.showNotification(true);
      debugPrint('Owl NPC: notification state ON');
    } else {
      owlNpc.showNotification(false);
      debugPrint('Owl NPC: notification state OFF');
    }
  }

  /// Update owl notification based on seed collection status
  Future<void> updateOwlNotification(bool showNotification) async {
    try {
      // Find the owl NPC component in the world
      final owlComponents = world.children.whereType<OwlNpcComponent>();
      if (owlComponents.isNotEmpty) {
        final owlNpc = owlComponents.first;
        owlNpc.showNotification(showNotification);
        debugPrint('[TiledFarmGame] 🦉 Updated owl notification: ${showNotification ? 'ON' : 'OFF'}');
      } else {
        debugPrint('[TiledFarmGame] ⚠️ No owl NPC found in world');
      }
    } catch (e) {
      debugPrint('[TiledFarmGame] ❌ Error updating owl notification: $e');
    }
  }

  void _setupCamera() {
    // Set up camera to follow player and fill the screen
    cameraComponent = CameraComponent();
    cameraComponent.follow(player);
    camera = cameraComponent;
    
    // Set the zoom level to make the world appear larger
    camera.viewfinder.zoom = 2.0;
    
    // Add camera bounds behavior
    camera.viewfinder.add(CameraBoundsBehavior());
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
    
    final fpsText = FpsTextComponent(
      position: Vector2(10, 30),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          shadows: [Shadow(color: Colors.black, blurRadius: 1)],
        ),
      ),
    );
    
    camera.viewport.add(instructionText);
    camera.viewport.add(fpsText);
  }

  /// Load saved tiles from backend and apply them to the map
  Future<void> _loadSavedTiles() async {
    try {
      debugPrint('[TiledFarmGame] 🔄 Loading saved tiles from backend...');
      
      final tiles = await _farmTileService.fetchFarmTiles(farmId);
      
      if (tiles.isNotEmpty) {
        debugPrint('[TiledFarmGame] ✅ Loaded ${tiles.length} saved tiles from backend');
        
        // First, apply all tile changes to the underlying data
        for (final tile in tiles) {
          final tileKey = '${tile.x},${tile.y}';
          modifiedTiles[tileKey] = tile;
          
          // Apply the tile change to the underlying data
          _applyTileChange(tile.x, tile.y, tile);
        }
        
        // Then, apply autotiling to all affected tiles and their neighbors
        final affectedTiles = <String>{};
        for (final tile in tiles) {
          // Add the tile itself and all its neighbors
          for (int ny = tile.y - 1; ny <= tile.y + 1; ny++) {
            for (int nx = tile.x - 1; nx <= tile.x + 1; nx++) {
              if (nx >= 0 && nx < mapWidth && ny >= 0 && ny < mapHeight) {
                affectedTiles.add('$nx,$ny');
              }
            }
          }
        }
        
                       // Apply autotiling to all affected tiles
               for (final tileKey in affectedTiles) {
                 final coords = tileKey.split(',');
                 final x = int.parse(coords[0]);
                 final y = int.parse(coords[1]);
                 _applyAutotilingToTile(x, y, null); // null means determine terrain type automatically
               }
        
        debugPrint('[TiledFarmGame] ✅ Applied autotiling to ${affectedTiles.length} affected tiles');
      } else {
        debugPrint('[TiledFarmGame] 📝 No saved tiles found in backend');
      }
    } catch (e) {
      debugPrint('[TiledFarmGame] ❌ ERROR loading saved tiles: $e');
    }
  }

  /// Apply a tile change using the efficient overlay system
  void _applyTileChange(int x, int y, FarmTileModel tile) {
    switch (tile.tileType) {
      case 'tilled':
        _tillTileAt(x, y);
        break;
      case 'planted':
        // For now, just till the tile as a placeholder
        // In the future, you could add different overlays for planted tiles
        _tillTileAt(x, y);
        break;
      case 'grown':
        // For now, just till the tile as a placeholder
        // In the future, you could add different overlays for grown tiles
        _tillTileAt(x, y);
        break;
      default:
        if (tile.shouldShowAsWatered) {
          // For now, just till the tile as a placeholder
          // In the future, you could add different overlays for watered tiles
          _tillTileAt(x, y);
        }
        break;
    }
  }

  void _handlePlayerPositionChange(Vector2 position) {
    // Handle player position changes for multiplayer
    final gridX = (position.x / tileSize).floor();
    final gridY = (position.y / tileSize).floor();
    
    // Rate limiting for position broadcasts
    if (_lastBroadcastGridX == gridX && _lastBroadcastGridY == gridY) {
      return; // Same position, skip broadcast
    }
    // Throttle to ~10 Hz
    final now = DateTime.now();
    if (_lastBroadcastAt != null &&
        now.difference(_lastBroadcastAt!).inMilliseconds < 100) {
      return;
    }
    
    _lastBroadcastGridX = gridX;
    _lastBroadcastGridY = gridY;
    _lastBroadcastAt = now;
    
    // Broadcast position to other players if user ID is available
    if (_userId != null) {
      _farmPlayerService.broadcastPlayerDestination(
        farmId: farmId,
        userId: _userId!,
        targetGridX: gridX,
        targetGridY: gridY,
        animationState: player.currentDirection.name,
        tileSize: tileSize, // Pass the correct tile size for TiledFarmGame
      );
    }
    
    // debugPrint('[TiledFarmGame] Player moved to (${position.x}, ${position.y})');
  }

  @override
  void onTapDown(TapDownEvent event) {
    // Prevent movement if hoe or watering can animation is playing
    if (_isHoeAnimationPlaying || _isWateringCanAnimationPlaying) {
      debugPrint('[TiledFarmGame] ⏸️ Movement blocked - tool animation is playing');
      return;
    }
    
    // Convert screen tap to world position
    final worldPosition = camera.globalToLocal(event.localPosition);
    
    // Convert world position to grid coordinates
    int gridX = (worldPosition.x / tileSize).floor();
    int gridY = (worldPosition.y / tileSize).floor();
    
    // Check if the tap is within bounds
    if (gridX < 0 || gridX >= mapWidth || gridY < 0 || gridY >= mapHeight) {
      return;
    }
    
    debugPrint('[TiledFarmGame] Tap at grid position ($gridX, $gridY)');
    
    // Check for isTillable property on the tapped tile
    final isTillable = _checkTileProperties(gridX, gridY);
    
    // Check if player has hoe and tapped on adjacent tillable tile
    if (isTillable && _isAdjacentToPlayer(gridX, gridY) && _currentHoeState) {
      _playHoeAnimation(gridX, gridY);
    } else if (isTillable && _isAdjacentToPlayer(gridX, gridY) && !_currentHoeState && !_currentWateringCanState) {
      // Player tried to till but doesn't have hoe selected
      debugPrint('[TiledFarmGame] Player tried to till tile but doesn\'t have hoe selected');
      // You could add a visual or audio feedback here
    }
    // Check if player has watering can and tapped on adjacent waterable tile
    else if (_isAdjacentToPlayer(gridX, gridY) && _currentWateringCanState && _isTileWaterable(gridX, gridY)) {
      debugPrint('[TiledFarmGame] 💧 Attempting to water tile at ($gridX, $gridY)');
      _playWateringCanAnimation(gridX, gridY);
    } else if (_isAdjacentToPlayer(gridX, gridY) && _currentWateringCanState && !_isTileWaterable(gridX, gridY)) {
      debugPrint('[TiledFarmGame] ❌ Tile at ($gridX, $gridY) is not waterable');
    } else if (_isAdjacentToPlayer(gridX, gridY) && !_currentHoeState && !_currentWateringCanState) {
      debugPrint('[TiledFarmGame] ❌ Player tried to use tool but doesn\'t have any tool selected');
    } else {
      // Use pathfinding to move player to tapped position
      player.pathfindTo(gridX, gridY);
    }
  }

  bool _checkTileProperties(int gridX, int gridY) {
    debugPrint('[TiledFarmGame] Checking tile at ($gridX, $gridY)');
    
    final isTillable = _isTileTillable(gridX, gridY);
    
    if (isTillable) {
      debugPrint('[TiledFarmGame] ✅ This appears to be the grass tile with isTillable=true');
      debugPrint('[TiledFarmGame] 🎯 This tile CAN be tilled!');
    } else {
      debugPrint('[TiledFarmGame] ❌ This tile is not tillable');
    }
    
    return isTillable;
  }

  bool _isAdjacentToPlayer(int gridX, int gridY) {
    // Get player's current grid position
    final playerGridX = (player.position.x / tileSize).floor();
    final playerGridY = (player.position.y / tileSize).floor();
    
    // Check if the tapped position is adjacent (including diagonal)
    final deltaX = (gridX - playerGridX).abs();
    final deltaY = (gridY - playerGridY).abs();
    
    final isAdjacent = deltaX <= 1 && deltaY <= 1 && !(deltaX == 0 && deltaY == 0);
    
    debugPrint('[TiledFarmGame] Player at ($playerGridX, $playerGridY), tapped at ($gridX, $gridY)');
    debugPrint('[TiledFarmGame] Is adjacent: $isAdjacent');
    
    return isAdjacent;
  }

  /// Event-based method to update hoe and watering can state (called when inventory changes)
  void onInventoryChanged() {
    final newHoeState = _checkIfPlayerHasHoe();
    if (newHoeState != _currentHoeState) {
      _currentHoeState = newHoeState;
      debugPrint('[TiledFarmGame] Hoe state changed: $_currentHoeState');
      _updateHoeHighlights();
    }
    
    final newWateringCanState = _checkIfPlayerHasWateringCan();
    if (newWateringCanState != _currentWateringCanState) {
      _currentWateringCanState = newWateringCanState;
      debugPrint('[TiledFarmGame] Watering can state changed: $_currentWateringCanState');
      // Note: Tiled farm game doesn't have watering can highlighting implemented yet
    }
  }

  /// Internal listener method for inventory changes
  void _onInventoryChanged() {
    onInventoryChanged();
  }

  /// Check if player has hoe selected in inventory (internal method)
  bool _checkIfPlayerHasHoe() {
    if (inventoryManager == null) {
      return false;
    }
    
    final selectedItem = inventoryManager!.selectedItem;
    if (selectedItem == null) {
      return false;
    }
    
    return selectedItem.id == 'hoe';
  }
  
  /// Check if player has watering can selected in inventory (internal method)
  bool _checkIfPlayerHasWateringCan() {
    if (inventoryManager == null) {
      return false;
    }
    
    final selectedItem = inventoryManager!.selectedItem;
    if (selectedItem == null) {
      return false;
    }
    
    return selectedItem.id == 'watering_can';
  }
  
  /// Check if a tile is waterable (can be watered)
  bool _isTileWaterable(int gridX, int gridY) {
    // Check if it's a tilled tile (can be watered)
    // A tilled tile is one that has the "Tilled" Wang ID (3) in its wangid
    // Based on ground.tsx, tiles with wangid containing "3" are tilled soil
    if (gridX >= 0 && gridX < mapWidth && gridY >= 0 && gridY < mapHeight) {
      final gid = _getTileGidAt(gridX, gridY);
      
      if (gid >= 27 && gid <= 35) {
        debugPrint('[TiledFarmGame] Tile at ($gridX, $gridY) is a tilled soil tile (GID: $gid) - allowing watering');
        return true;
      }
      
      // Check if it's a dirt tile that can be transformed to tilled soil
      // Dirt tiles are those with "Dirt" Wang ID (1) in their wangid
      // Based on ground.tsx, dirt tiles are typically GIDs 1-4, 16, 19, 31, 34
      final dirtTileGids = [1, 2, 3, 4, 16, 19, 31, 34];
      if (dirtTileGids.contains(gid)) {
        debugPrint('[TiledFarmGame] Tile at ($gridX, $gridY) is a dirt tile (GID: $gid) - allowing watering to transform to tilled soil');
        return true;
      }
    }
    
    return false;
  }
  
  /// Get the GID of a tile at the specified position
  int _getTileGidAt(int gridX, int gridY) {
    // This is a simplified version - you might need to implement this based on your tile data structure
    // For now, return a default value
    return 1; // Default dirt tile
  }

  void _playHoeAnimation(int gridX, int gridY) {
    // Calculate the direction from player to tapped tile
    final playerGridX = (player.position.x / tileSize).floor();
    final playerGridY = (player.position.y / tileSize).floor();
    final deltaX = gridX - playerGridX;
    final deltaY = gridY - playerGridY;
    
    debugPrint('[TiledFarmGame] Player at ($playerGridX, $playerGridY), tilling tile at ($gridX, $gridY)');
    debugPrint('[TiledFarmGame] Delta: ($deltaX, $deltaY)');
    
    int swingDirection = 1; // Default to front swing
    bool shouldFlip = false; // Track if we need to flip the animation

    // Calculate the direction from player to tapped tile
    if (deltaX > 0) {
      swingDirection = 0; // Right swing
      shouldFlip = false;
      debugPrint('[TiledFarmGame] Swinging hoe to the right');
    } else if (deltaX < 0) {
      swingDirection = 0; // Right swing (will be flipped)
      shouldFlip = true;
      debugPrint('[TiledFarmGame] Swinging hoe to the left (flipped)');
    } else if (deltaY > 0) {
      swingDirection = 1; // Front swing
      shouldFlip = false;
      debugPrint('[TiledFarmGame] Swinging hoe in front');
    } else if (deltaY < 0) {
      swingDirection = 2; // Behind swing
      shouldFlip = false;
      debugPrint('[TiledFarmGame] Swinging hoe behind');
    }

    // Make the player face the direction of the swing using directional sprites
    _makePlayerFaceHoeDirection(deltaX, deltaY);

    // Position the animation directly on the tapped tile
    final animationPosition = Vector2(gridX * tileSize, gridY * tileSize);

    // Create a hoe animation component at the tile position
    final hoeAnimation = HoeAnimation(
      position: animationPosition,
      size: Vector2(tileSize, tileSize),
      swingDirection: swingDirection,
      shouldFlip: shouldFlip,
      onAnimationComplete: () {
        // Reset player direction when hoe animation finishes
        _resetPlayerDirection();
        
        // Save the tilled tile to backend
        _saveTilledTile(gridX, gridY);
      },
    );

    // Add the animation to the world
    world.add(hoeAnimation);
    debugPrint('[TiledFarmGame] ✅ Hoe animation started with direction: $swingDirection, flipped: $shouldFlip at position: (${animationPosition.x}, ${animationPosition.y})');
  }
  
  /// Play watering can animation at the specified grid position
  void _playWateringCanAnimation(int gridX, int gridY) {
    // Calculate the direction from player to tapped tile
    final playerGridX = (player.position.x / tileSize).floor();
    final playerGridY = (player.position.y / tileSize).floor();
    final deltaX = gridX - playerGridX;
    final deltaY = gridY - playerGridY;
    
    debugPrint('[TiledFarmGame] Player at ($playerGridX, $playerGridY), watering tile at ($gridX, $gridY)');
    debugPrint('[TiledFarmGame] Delta: ($deltaX, $deltaY)');
    
    int wateringDirection = 1; // Default to front watering
    bool shouldFlip = false; // Track if we need to flip the animation

    // Calculate the direction from player to tapped tile
    if (deltaX > 0) {
      wateringDirection = 0; // Right watering
      shouldFlip = false;
      debugPrint('[TiledFarmGame] Watering to the right');
    } else if (deltaX < 0) {
      wateringDirection = 0; // Right watering (will be flipped)
      shouldFlip = true;
      debugPrint('[TiledFarmGame] Watering to the left (flipped)');
    } else if (deltaY > 0) {
      wateringDirection = 1; // Front watering
      shouldFlip = false;
      debugPrint('[TiledFarmGame] Watering in front');
    } else if (deltaY < 0) {
      wateringDirection = 2; // Behind watering
      shouldFlip = false;
      debugPrint('[TiledFarmGame] Watering behind');
    }

    // Make the player face the direction of the watering
    _makePlayerFaceWateringCanDirection(deltaX, deltaY);

    // Position the animation directly on the tapped tile
    final animationPosition = Vector2(gridX * tileSize, gridY * tileSize);

    // Create a watering can animation component at the tile position
    final wateringCanAnimation = WateringCanAnimation(
      position: animationPosition,
      size: Vector2(tileSize, tileSize),
      wateringDirection: wateringDirection,
      shouldFlip: shouldFlip,
      onAnimationComplete: () {
        // Water the tile when animation completes
        _waterTileAt(gridX, gridY);
        // Reset player direction after animation
        _resetPlayerDirection();
      },
    );

    // Add the animation to the world
    world.add(wateringCanAnimation);
    debugPrint('[TiledFarmGame] ✅ Watering can animation started with direction: $wateringDirection, flipped: $shouldFlip at position: (${animationPosition.x}, ${animationPosition.y})');
  }
  
  /// Water a tile at the specified position
  Future<void> _waterTileAt(int gridX, int gridY) async {
    debugPrint('[TiledFarmGame] 💧 Watering tile at ($gridX, $gridY)');
    
    // Get the current tile GID
    final currentGid = _getTileGidAt(gridX, gridY);
    debugPrint('[TiledFarmGame] Current tile GID: $currentGid');
    
    // Check if this is a dirt tile that can be transformed to tilled soil
    // Dirt tiles are those with "Dirt" Wang ID (1) in their wangid
    final dirtTileGids = [1, 2, 3, 4, 16, 19, 31, 34];
    
    if (dirtTileGids.contains(currentGid)) {
      // Transform to tilled soil by applying the "Tilled" Wang ID (3)
      // This will use the autotiling system to find the appropriate tilled tile
      _applyAutotilingToTile(gridX, gridY, 'Tilled');
      
      debugPrint('[TiledFarmGame] ✅ Dirt tile transformed to tilled soil (GID $currentGid -> tilled)');
    } else {
      debugPrint('[TiledFarmGame] ℹ️ Tile at ($gridX, $gridY) is not a dirt tile (GID: $currentGid), no transformation needed');
    }
    
    debugPrint('[TiledFarmGame] ✅ Tile watered successfully at ($gridX, $gridY)');
  }

  /// Save a tilled tile to the backend
  Future<void> _saveTilledTile(int gridX, int gridY) async {
    try {
      debugPrint('[TiledFarmGame] 💾 Saving tilled tile to backend: ($gridX, $gridY)');
      
      // First, change the tile GID using autotiling
      _tillTileAt(gridX, gridY);
      
      await _farmTileService.updateTile(
        farmId: farmId,
        x: gridX,
        y: gridY,
        tileType: 'tilled',
        watered: false,
        userId: _userId, // Pass user ID for broadcast
      );
      
      debugPrint('[TiledFarmGame] ✅ Successfully saved tilled tile to backend');
      
    } catch (e) {
      debugPrint('[TiledFarmGame] ❌ ERROR saving tilled tile: $e');
    }
  }

  /// The core autotiling function - changes tile data and applies proper Wang Set blending
  void _tillTileAt(int x, int y) {
    debugPrint('[TiledFarmGame] 🚜 Tilling tile at ($x, $y) using Wang Set autotiling system');

    // First, check if the action is even possible (client-side prediction)
    if (!_isTileTillable(x, y)) {
      debugPrint('[TiledFarmGame] ❌ Tile at ($x, $y) is not tillable');
      return;
    }

    // Update the center tile to tilled soil
    _applyAutotilingToTile(x, y, 'Tilled');

    // Apply autotiling to all 8 neighbors
    for (int ny = y - 1; ny <= y + 1; ny++) {
      for (int nx = x - 1; nx <= x + 1; nx++) {
        if (nx >= 0 && nx < mapWidth && ny >= 0 && ny < mapHeight) {
          if (nx != x || ny != y) { // Skip the center tile
            _applyAutotilingToTile(nx, ny, null); // null means determine terrain type automatically
          }
        }
      }
    }

    debugPrint('[TiledFarmGame] ✅ Wang Set autotiling completed for ($x, $y)');
  }

  /// Apply Wang Set autotiling logic to a specific tile
  /// DEPRECATED: This method is no longer used since we switched to custom parser
  void _applyAutotilingToTile(int x, int y, String? forceTerrainType) {
    // This method is deprecated - use SimpleEnhancedFarmGame instead
    debugPrint('[TiledFarmGame] ⚠️ _applyAutotilingToTile is deprecated - use SimpleEnhancedFarmGame');
  }

  /// Calculate the Wang ID for a tile based on its 8 neighbors
  /// DEPRECATED: This method is no longer used since we switched to custom parser
  List<int> _calculateWangId(int x, int y, String centerTerrainType) {
    // This method is deprecated - use SimpleEnhancedFarmGame instead
    debugPrint('[TiledFarmGame] ⚠️ _calculateWangId is deprecated - use SimpleEnhancedFarmGame');
    return List.filled(8, 0);
  }

  /// Find the best tile for a given Wang ID and terrain type
  int? _findBestTileForWangId(List<int> wangId, String terrainType) {
    int? bestTileId;
    int bestMatch = -1;

    // Look through all tiles that match this terrain type
    for (final entry in wangTileMappings.entries) {
      final tileId = entry.key;
      final tileWangId = entry.value;
      
      // Check if this tile belongs to the target terrain type
      if (_getTerrainTypeForGid(tileId) == terrainType) {
        // Calculate how well this tile matches our Wang ID
        final matchScore = _calculateWangMatchScore(wangId, tileWangId);
        
        if (matchScore > bestMatch) {
          bestMatch = matchScore;
          bestTileId = tileId;
        }
      }
    }

    return bestTileId;
  }

  /// Calculate how well a tile's Wang ID matches our target Wang ID
  int _calculateWangMatchScore(List<int> targetWangId, List<int> tileWangId) {
    int score = 0;
    
    for (int i = 0; i < 8; i++) {
      if (targetWangId[i] == tileWangId[i]) {
        score += 2; // Exact match
      } else if (targetWangId[i] == 0 || tileWangId[i] == 0) {
        score += 1; // Wildcard match (0 means "any")
      }
    }
    
    return score;
  }

  /// Get the terrain type for a given GID
  String _getTerrainTypeForGid(int gid) {
    // Map GIDs to terrain types based on ground.tsx configuration
    if (gid == 24) return 'Grass'; // Grass tile with isTillable=true
    if (gid >= 27 && gid <= 35) return 'Tilled'; // Tilled soil tiles
    if (gid >= 47 && gid <= 49) return 'Pond'; // Water tiles
    if (gid >= 120 && gid <= 154) return 'HighGround'; // High ground tiles
    if (gid >= 135 && gid <= 139) return 'HighGroundMid'; // High ground mid tiles
    
    return 'Dirt'; // Default terrain type
  }

  /// Get terrain types of the 8 neighbors
  /// DEPRECATED: This method is no longer used since we switched to custom parser
  List<String> _getNeighborTerrainTypes(int x, int y) {
    // This method is deprecated - use SimpleEnhancedFarmGame instead
    debugPrint('[TiledFarmGame] ⚠️ _getNeighborTerrainTypes is deprecated - use SimpleEnhancedFarmGame');
    return List.filled(8, 'Dirt');
  }

  /// Add a lightweight visual overlay for a changed tile
  void _addTileOverlay(int x, int y, int gid) async {
    final tileKey = '$x,$y';
    
    // Remove existing overlay if any
    tileOverlays[tileKey]?.removeFromParent();
    tileOverlays.remove(tileKey);
    
    // Get the sprite for the specific GID
    final sprite = await _getSpriteFromGid(gid);
    
    // Create a small overlay component
    final overlay = SpriteComponent(
      sprite: sprite,
      position: Vector2(x * tileSize, y * tileSize),
      size: Vector2.all(tileSize),
      priority: -1, // Render below NPCs but above base tiles
    );
    
    // Add to world and track
    world.add(overlay);
    tileOverlays[tileKey] = overlay;
    
    debugPrint('[TiledFarmGame] ✨ Added tile overlay at ($x, $y) with GID: $gid');
  }

  /// Get sprite from GID (supports all tile variants)
  Future<Sprite> _getSpriteFromGid(int gid) async {
    // Load the tileset image
          final tilesetImage = await images.load('Tiles/Tile.png');
    final spriteSheet = SpriteSheet(
      image: tilesetImage,
      srcSize: Vector2.all(tileSize),
      spacing: 0.0,
      margin: 0.0,
    );
    
    // Convert GID to tile ID (subtract firstGid which is 1)
    final tileId = gid - 1;
    return spriteSheet.getSpriteById(tileId);
  }

  /// Get the tilled soil sprite (deprecated - use _getSpriteFromGid instead)
  Future<Sprite> _getTilledSoilSprite() async {
    return _getSpriteFromGid(28); // Default tilled soil GID
  }

  /// Clear all tile overlays
  void _clearTileOverlays() {
    for (final overlay in tileOverlays.values) {
      overlay.removeFromParent();
    }
    tileOverlays.clear();
    debugPrint('[TiledFarmGame] 🧹 Cleared all tile overlays');
  }

    /// Check if a tile is tillable based on its GID
    /// DEPRECATED: This method is no longer used since we switched to custom parser
  bool _isTileTillable(int x, int y) {
    // This method is deprecated - use SimpleEnhancedFarmGame instead
    debugPrint('[TiledFarmGame] ⚠️ _isTileTillable is deprecated - use SimpleEnhancedFarmGame');
    return false;
  }
  
  void _makePlayerFaceHoeDirection(int deltaX, int deltaY) {
    // Set flag to indicate hoe animation is playing
    _isHoeAnimationPlaying = true;
    
    // Disable automatic animation updates and keyboard input
    player.disableAutoAnimation();
    player.disableKeyboardInput();
    
    // Set velocity to zero to prevent movement
    player.velocity = Vector2.zero();
    
    // Set the player's direction manually
    if (deltaX > 0) {
      // Face right
      player.setDirection(PlayerDirection.right);
      debugPrint('[TiledFarmGame] Player facing right (static)');
    } else if (deltaX < 0) {
      // Face left
      player.setDirection(PlayerDirection.left);
      debugPrint('[TiledFarmGame] Player facing left (static)');
    } else if (deltaY > 0) {
      // Face down (front)
      player.setDirection(PlayerDirection.down);
      debugPrint('[TiledFarmGame] Player facing down (static)');
    } else if (deltaY < 0) {
      // Face up (behind)
      player.setDirection(PlayerDirection.up);
      debugPrint('[TiledFarmGame] Player facing up (static)');
    }
  }
  
  void _makePlayerFaceWateringCanDirection(int deltaX, int deltaY) {
    // Set flag to indicate watering can animation is playing
    _isWateringCanAnimationPlaying = true;
    
    // Disable automatic animation updates and keyboard input
    player.disableAutoAnimation();
    player.disableKeyboardInput();
    
    // Set velocity to zero to prevent movement
    player.velocity = Vector2.zero();
    
    // Set the player's direction manually
    if (deltaX > 0) {
      // Face right
      player.setDirection(PlayerDirection.right);
      debugPrint('[TiledFarmGame] Player facing right (static)');
    } else if (deltaX < 0) {
      // Face left
      player.setDirection(PlayerDirection.left);
      debugPrint('[TiledFarmGame] Player facing left (static)');
    } else if (deltaY > 0) {
      // Face down (front)
      player.setDirection(PlayerDirection.down);
      debugPrint('[TiledFarmGame] Player facing down (static)');
    } else if (deltaY < 0) {
      // Face up (behind)
      player.setDirection(PlayerDirection.up);
      debugPrint('[TiledFarmGame] Player facing up (static)');
    }
  }
  
  void _resetPlayerDirection() {
    // Reset flags to indicate tool animation is complete
    _isHoeAnimationPlaying = false;
    _isWateringCanAnimationPlaying = false;
    
    // Re-enable automatic animation updates and keyboard input
    player.enableAutoAnimation();
    player.enableKeyboardInput();
    
    // Reset player to idle animation
    player.setDirection(PlayerDirection.idle);
    debugPrint('[TiledFarmGame] Player returned to idle animation');
  }

  /// Initialize real-time multiplayer features
  Future<void> _initializeMultiplayer() async {
    _farmPlayerService = FarmPlayerService();
    _userId = SupabaseConfig.currentUserId;
    
    if (_userId != null) {
      debugPrint('[TiledFarmGame] Initializing multiplayer for user: $_userId on farm: $farmId');
      
      // Subscribe to real-time player movements
      _subscribeToOtherPlayers();
      
      // Broadcast initial position
      _handlePlayerPositionChange(player.position);
      
      debugPrint('[TiledFarmGame] Multiplayer initialized successfully');
    } else {
      debugPrint('[TiledFarmGame] No user ID available, skipping multiplayer initialization');
    }
  }

  /// Initialize real-time tile updates
  Future<void> _initializeTileUpdates() async {
    debugPrint('[TiledFarmGame] Initializing real-time tile updates for farm: $farmId');
    
    try {
      // Subscribe to database changes (Postgres changes)
      _tileChangesSub = _farmTileService.subscribeToTileChanges(farmId).listen(
        (updatedTile) {
          debugPrint('[TiledFarmGame] ✅ RECEIVED DATABASE TILE UPDATE: (${updatedTile.x}, ${updatedTile.y}) -> ${updatedTile.tileType}');
          _handleTileUpdate(updatedTile);
        },
        onError: (error) {
          debugPrint('[TiledFarmGame] ❌ ERROR in database tile updates subscription: $error');
        },
        onDone: () {
          debugPrint('[TiledFarmGame] 🔚 Database tile updates subscription completed');
        },
      );
      
      // Subscribe to real-time broadcasts (for immediate updates)
      _tileBroadcastSub = _farmTileService.subscribeToTileChangeBroadcasts(farmId).listen(
        (broadcastData) {
          debugPrint('[TiledFarmGame] ✅ RECEIVED TILE BROADCAST: (${broadcastData['x']}, ${broadcastData['y']}) -> ${broadcastData['tile_type']}');
          _handleTileBroadcast(broadcastData);
        },
        onError: (error) {
          debugPrint('[TiledFarmGame] ❌ ERROR in tile broadcast subscription: $error');
        },
        onDone: () {
          debugPrint('[TiledFarmGame] 🔚 Tile broadcast subscription completed');
        },
      );
      
      debugPrint('[TiledFarmGame] ✅ Real-time tile updates initialized successfully');
    } catch (e) {
      debugPrint('[TiledFarmGame] ❌ ERROR initializing tile updates: $e');
    }
  }

  /// Handle real-time tile updates from other users
  void _handleTileUpdate(FarmTileModel updatedTile) {
    final x = updatedTile.x;
    final y = updatedTile.y;
    
    debugPrint('[TiledFarmGame] 🔄 Processing real-time tile update: (${updatedTile.x}, ${updatedTile.y}) -> ${updatedTile.tileType}');
    
    // Check if the tile is within bounds
    if (x < 0 || x >= mapWidth || y < 0 || y >= mapHeight) {
      debugPrint('[TiledFarmGame] ❌ Tile update out of bounds: ($x, $y)');
      return;
    }
    
    // Store the updated tile data
    final tileKey = '$x,$y';
    modifiedTiles[tileKey] = updatedTile;
    
    // Apply the tile change using the efficient overlay system
    _applyTileChange(x, y, updatedTile);
    
    // Add a visual effect to show the tile was updated by another user
    _addTileUpdateEffect(x, y);
    
    debugPrint('[TiledFarmGame] ✅ Real-time tile update processed for ($x, $y)');
  }

  /// Handle real-time tile broadcasts from other users (immediate updates)
  void _handleTileBroadcast(Map<String, dynamic> broadcastData) {
    final x = broadcastData['x'] as int;
    final y = broadcastData['y'] as int;
    final tileType = broadcastData['tile_type'] as String;
    final userId = broadcastData['user_id'] as String?;
    
    debugPrint('[TiledFarmGame] 🔄 Processing tile broadcast: ($x, $y) -> $tileType from user: $userId');
    
    // Skip if this is our own broadcast
    if (userId == _userId) {
      debugPrint('[TiledFarmGame] ⏭️ Skipping own tile broadcast');
      return;
    }
    
    // Check if the tile is within bounds
    if (x < 0 || x >= mapWidth || y < 0 || y >= mapHeight) {
      debugPrint('[TiledFarmGame] ❌ Tile broadcast out of bounds: ($x, $y)');
      return;
    }
    
    // Create a FarmTileModel from the broadcast data
    final broadcastTile = FarmTileModel(
      farmId: farmId,
      x: x,
      y: y,
      tileType: tileType,
      watered: broadcastData['watered'] as bool? ?? false,
      plantType: broadcastData['plant_type'] as String?,
      growthStage: broadcastData['growth_stage'] as String? ?? 'planted',
    );
    
    // Store the updated tile data
    final tileKey = '$x,$y';
    modifiedTiles[tileKey] = broadcastTile;
    
    // Apply the tile change using the efficient overlay system
    _applyTileChange(x, y, broadcastTile);
    
    // Add a visual effect to show the tile was updated by another user
    _addTileUpdateEffect(x, y);
    
    debugPrint('[TiledFarmGame] ✅ Tile broadcast processed for ($x, $y)');
  }

  /// Add a visual effect to show a tile was updated by another user
  void _addTileUpdateEffect(int x, int y) {
    final position = Vector2(x * tileSize + tileSize / 2, y * tileSize + tileSize / 2);
    
    // Create a glowing effect
    final effect = CircleComponent(
      radius: tileSize / 2,
      paint: Paint()
        ..color = Colors.yellow.withOpacity(0.6)
        ..style = PaintingStyle.fill,
      position: position,
    );
    
    // Add a pulsing animation
    effect.add(
      SequenceEffect([
        ScaleEffect.to(Vector2.all(1.5), EffectController(duration: 0.3)),
        ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.3)),
        ScaleEffect.to(Vector2.all(1.5), EffectController(duration: 0.3)),
        ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.3)),
        RemoveEffect(),
      ]),
    );
    
    world.add(effect);
    
    debugPrint('[TiledFarmGame] ✨ Added tile update effect at ($x, $y)');
  }

  /// Subscribe to other players' movements
  void _subscribeToOtherPlayers() {
    _movementSub?.cancel();
    _movementSub = _farmPlayerService.subscribeToPlayerDestinationBroadcast(farmId).listen((destination) {
      if (destination.userId == _userId) return; // Don't render self
      
      if (!otherPlayers.containsKey(destination.userId)) {
        // New player joined
        debugPrint('[TiledFarmGame] New player joined: ${destination.userId}');
        
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
        debugPrint('[TiledFarmGame] Your partner has joined the farm!');
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

  // Rate limiting for position broadcasts
  int? _lastBroadcastGridX;
  int? _lastBroadcastGridY;
  DateTime? _lastBroadcastAt;

  @override
  void onRemove() {
    // Remove inventory listener
    if (inventoryManager != null) {
      inventoryManager!.removeListener(_onInventoryChanged);
    }
    
    // Clean up multiplayer subscriptions
    _movementSub?.cancel();
    _tileChangesSub?.cancel();
    _tileBroadcastSub?.cancel();
    
    // Clean up tile overlays
    _clearTileOverlays();
    
    debugPrint('[TiledFarmGame] 🧹 Cleaned up multiplayer subscriptions');
    super.onRemove();
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    final result = super.onKeyEvent(event, keysPressed);
    if (result == KeyEventResult.handled) {
      return result;
    }
    return player.handleKeyEvent(keysPressed);
  }
  @override
  PathfindingGrid get pathfindingGrid => _pathfindingGrid;

  /// Get all adjacent positions where the hoe can be used
  List<MapEntry<int, int>> _getAdjacentHoePositions() {
    final positions = <MapEntry<int, int>>[];
    final playerGridX = (player.position.x / tileSize).floor();
    final playerGridY = (player.position.y / tileSize).floor();
    
    // Check all 8 adjacent positions (including diagonals)
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        // Skip the player's position
        if (dx == 0 && dy == 0) continue;
        
        final x = playerGridX + dx;
        final y = playerGridY + dy;
        
        // Check if position is within bounds and tillable
        if (x >= 0 && x < mapWidth && y >= 0 && y < mapHeight && _isTileTillable(x, y)) {
          positions.add(MapEntry(x, y));
        }
      }
    }
    
    return positions;
  }

  /// Highlight tiles where the hoe can be used
  void _highlightHoePositions() {
    // Clear existing highlights first
    _clearHoeHighlights();
    
    final hoePositions = _getAdjacentHoePositions();
    
    for (final position in hoePositions) {
      final key = '${position.key}_${position.value}';
      
      // Create a highlight rectangle
      final highlight = RectangleComponent(
        position: Vector2(position.key * tileSize, position.value * tileSize),
        size: Vector2(tileSize, tileSize),
        paint: Paint()
          ..color = Colors.orange.withOpacity(0.4)
          ..style = PaintingStyle.fill,
      );
      
      _hoeHighlights[key] = highlight;
      world.add(highlight);
    }
    
    // Debug log removed to prevent spam - highlighting works silently now
  }

  /// Clear all hoe highlights
  void _clearHoeHighlights() {
    for (final highlight in _hoeHighlights.values) {
      highlight.removeFromParent();
    }
    _hoeHighlights.clear();
  }

  /// Update hoe highlighting based on current state
  void _updateHoeHighlighting() {
    final currentPlayerPosition = MapEntry<int, int>(
      (player.position.x / tileSize).floor(),
      (player.position.y / tileSize).floor(),
    );
    
    // Check if player has moved
    final playerMoved = _lastPlayerPosition == null || 
                       currentPlayerPosition.key != _lastPlayerPosition!.key || 
                       currentPlayerPosition.value != _lastPlayerPosition!.value;
    
    // Update player movement state
    if (playerMoved) {
      _isPlayerMoving = true;
      _lastMovementTime = 0.0; // Reset movement timer
      _lastPlayerPosition = currentPlayerPosition;
    } else {
      // Check if enough time has passed since last movement
      _lastMovementTime += 1.0 / 60.0; // Assuming 60 FPS
      if (_lastMovementTime > 0.3) { // 300ms delay
        _isPlayerMoving = false;
        _updateHoeHighlights();
      }
    }
  }

  /// Update hoe highlights based on current state
  void _updateHoeHighlights() {
    if (_currentHoeState && !_isPlayerMoving) {
      _highlightHoePositions();
    } else {
      _clearHoeHighlights();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Only update highlighting when player is not moving and has a tool selected
    if (!_isPlayerMoving && (_currentHoeState || _currentWateringCanState)) {
      _updateHoeHighlighting();
    }
  }

} 
