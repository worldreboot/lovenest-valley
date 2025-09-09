import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:tiled/tiled.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lovenest_valley/components/player.dart';
import 'package:lovenest_valley/utils/pathfinding.dart';
import 'package:lovenest_valley/game/base/game_with_grid.dart';
import 'package:lovenest_valley/components/world/bonfire.dart';
import 'package:lovenest_valley/components/owl_npc.dart';
import 'package:lovenest_valley/services/question_service.dart';
import 'package:lovenest_valley/models/memory_garden/question.dart';
import 'package:lovenest_valley/models/chest_storage.dart';
import 'package:lovenest_valley/behaviors/camera_bounds.dart';
import 'package:lovenest_valley/components/world/hoe_animation.dart';
import 'package:lovenest_valley/models/inventory.dart';
import 'package:lovenest_valley/services/farm_tile_service.dart';
import 'package:lovenest_valley/services/farm_player_service.dart';
import 'package:lovenest_valley/config/supabase_config.dart';
import 'package:lovenest_valley/components/smooth_player.dart';
import 'package:lovenest_valley/models/farm_tile_model.dart';
import 'package:lovenest_valley/utils/tiled_parser.dart' as custom_parser;
import 'package:lovenest_valley/components/world/enhanced_dynamic_tilemap.dart';
import 'package:flame/effects.dart';
import 'dart:async';

/// Enhanced farm game that uses our custom Tiled parser for better auto-tiling and tile control
class EnhancedTiledFarmGame extends GameWithGrid with HasCollisionDetection, HasKeyboardHandlerComponents, TapCallbacks {
  final String farmId;
  late Player player;
  late CameraComponent cameraComponent;
  late PathfindingGrid _pathfindingGrid;
  late EnhancedDynamicTilemap _tilemap;
  
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
  bool _lastHoeState = false; // Track if hoe was equipped last frame
  Point? _lastPlayerPosition; // Track player's last grid position
  bool _isPlayerMoving = false; // Track if player is currently moving
  double _lastMovementTime = 0.0; // Track when player last moved

  // Custom parser instances
  late custom_parser.TilesetParser _tilesetParser;
  late custom_parser.MapParser _mapParser;
  late custom_parser.AutoTiler _autoTiler;

  EnhancedTiledFarmGame({
    required this.farmId,
    this.inventoryManager,
  });

  @override
  Color backgroundColor() => const Color(0xFF4A7C59); // Forest green

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Initialize custom parsers
    await _initializeCustomParsers();
    
    // Load the enhanced tilemap with our custom parser
    debugPrint('[EnhancedTiledFarmGame] Loading enhanced tilemap with custom parser...');
    await _initializeEnhancedTilemap();
    debugPrint('[EnhancedTiledFarmGame] ✅ Enhanced tilemap loaded successfully');
    
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
    debugPrint('[EnhancedTiledFarmGame] 🚀 Starting real-time initialization...');
    await _initializeMultiplayer();
    debugPrint('[EnhancedTiledFarmGame] ✅ Multiplayer initialized');
    await _initializeTileUpdates();
    debugPrint('[EnhancedTiledFarmGame] ✅ Tile updates initialized');
    
    // Add a test log to verify the subscription is active
    debugPrint('[EnhancedTiledFarmGame] 🧪 Real-time setup complete. Farm ID: $farmId');
    debugPrint('[EnhancedTiledFarmGame] 🧪 Waiting for tile updates from other users...');
    debugPrint('[EnhancedTiledFarmGame] 🧪 Current user ID: ${SupabaseConfig.currentUserId}');
  }

  /// Initialize our custom Tiled parsers
  Future<void> _initializeCustomParsers() async {
    debugPrint('[EnhancedTiledFarmGame] Initializing custom parsers...');

    // Load tileset data
    _tilesetParser = custom_parser.TilesetParser('assets/ground.tsx');
    await _tilesetParser.load();

    // Load map data
    _mapParser = custom_parser.MapParser('assets/tiles/valley.tmx');
    await _mapParser.load();

    // Create auto-tiler with wang tiles
    final wangTiles = _tilesetParser.getWangTiles();
    _autoTiler = custom_parser.AutoTiler(wangTiles);

    debugPrint('[EnhancedTiledFarmGame] Parsers initialized:');
    debugPrint('  - Tileset: ${_tilesetParser.getTilesetInfo()}');
    debugPrint('  - Map: ${_mapParser.getMapInfo()}');
    debugPrint('  - Wang tiles: ${wangTiles.length}');
  }

  /// Initialize the enhanced tilemap component
  Future<void> _initializeEnhancedTilemap() async {
    debugPrint('[EnhancedTiledFarmGame] Initializing enhanced tilemap...');

    // Create a mock RenderableTiledMap for compatibility
    final mockMap = _createMockTiledMap();
    
    _tilemap = EnhancedDynamicTilemap(mockMap, tileSize: tileSize);
    world.add(_tilemap);

    debugPrint('[EnhancedTiledFarmGame] Tilemap initialized');
  }

  /// Create a mock RenderableTiledMap for compatibility with existing components
  RenderableTiledMap _createMockTiledMap() {
    // Create a minimal TiledMap for compatibility
    final map = TiledMap(
      width: mapWidth,
      height: mapHeight,
      tileWidth: tileSize.toInt(),
      tileHeight: tileSize.toInt(),
      orientation: 'orthogonal',
      renderOrder: 'right-down',
    );
    
    return RenderableTiledMap(
      map,
      {}, // Empty images
      [], // Empty tilesets
    );
  }

  Future<void> _spawnPlayer() async {
    debugPrint('[EnhancedTiledFarmGame] Spawning player...');
    
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
              debugPrint('[EnhancedTiledFarmGame] ✅ Player spawned at (${player.position.x}, ${player.position.y}) from Spawn object');
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[EnhancedTiledFarmGame] ⚠️ Error accessing Tiled map objects: $e');
    }
    
    // Fallback to hardcoded position if no PlayerSpawn object found
    if (!playerSpawned) {
      debugPrint('[EnhancedTiledFarmGame] ⚠️ No PlayerSpawn object found, using fallback position');
      final spawnX = 488.0;
      final spawnY = 181.0;
      
      player = Player();
      player.position = Vector2(spawnX, spawnY);
      player.onPositionChanged = (position, {animationState}) => _handlePlayerPositionChange(position);
      world.add(player);
      
      debugPrint('[EnhancedTiledFarmGame] ✅ Player spawned at fallback position (${player.position.x}, ${player.position.y})');
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
      position: Vector2(owlX * tileSize, owlY * tileSize),
      size: Vector2.all(tileSize),
      idleSprite: idleSprite,
      notificationSprite: notificationSprite,
    );
    world.add(owlNpc);
    owlPositions.add('$owlX,$owlY');
    
    // Add bonfires at strategic locations
    final bonfirePositions = [
      Vector2(10, 10),
      Vector2(50, 15),
      Vector2(30, 25),
    ];

    for (final position in bonfirePositions) {
      final bonfire = Bonfire(
        position: Vector2(position.x * tileSize, position.y * tileSize),
        size: Vector2.all(tileSize),
      );
      world.add(bonfire);
      this.bonfirePositions.add('${position.x.toInt()},${position.y.toInt()}');
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
        debugPrint('[EnhancedTiledFarmGame] 🦉 Updated owl notification: ${showNotification ? 'ON' : 'OFF'}');
      } else {
        debugPrint('[EnhancedTiledFarmGame] ⚠️ No owl NPC found in world');
      }
    } catch (e) {
      debugPrint('[EnhancedTiledFarmGame] ❌ Error updating owl notification: $e');
    }
  }

  void _setupCamera() {
    cameraComponent = CameraComponent();
    world.add(cameraComponent);
    cameraComponent.add(player);
    cameraComponent.follow(player);
    
    // Add camera bounds
    final cameraBounds = CameraBounds(
      worldSize: Vector2(mapWidth * tileSize, mapHeight * tileSize),
    );
    cameraComponent.add(cameraBounds);
  }

  Future<void> _addUI() async {
    // Add any UI components here
    debugPrint('[EnhancedTiledFarmGame] UI components added');
  }

  Future<void> _loadSavedTiles() async {
    // Load saved tiles from backend
    debugPrint('[EnhancedTiledFarmGame] Loading saved tiles from backend...');
  }

  Future<void> _initializeMultiplayer() async {
    // Initialize Supabase
    await SupabaseConfig.initialize();

    // Get user ID
    _userId = SupabaseConfig.supabase.auth.currentUser?.id;

    if (_userId != null) {
      // Initialize farm player service
      _farmPlayerService = FarmPlayerService(farmId);

      // Start listening for other players
      _movementSub = _farmPlayerService.playerMovementStream.listen((event) {
        _handleOtherPlayerMovement(event);
      });

      // Start listening for tile changes
      _tileChangesSub = _farmTileService.tileChangesStream.listen((event) {
        _handleTileChange(event);
      });

      // Start broadcasting player position
      _startPositionBroadcast();

      debugPrint('[EnhancedTiledFarmGame] Multiplayer initialized');
    }
  }

  Future<void> _initializeTileUpdates() async {
    // Initialize tile update system
    debugPrint('[EnhancedTiledFarmGame] Tile updates initialized');
  }

  /// Handle movement from other players
  void _handleOtherPlayerMovement(Map<String, dynamic> event) {
    final playerId = event['player_id'];
    final x = event['x']?.toDouble() ?? 0.0;
    final y = event['y']?.toDouble() ?? 0.0;

    if (playerId != _userId) {
      if (!otherPlayers.containsKey(playerId)) {
        // Create new player
        final otherPlayer = SmoothPlayer(
          position: Vector2(x, y),
          size: Vector2.all(tileSize),
        );
        otherPlayers[playerId] = otherPlayer;
        world.add(otherPlayer);
      } else {
        // Update existing player position
        otherPlayers[playerId]?.moveTo(Vector2(x, y));
      }
    }
  }

  /// Handle tile changes from backend
  void _handleTileChange(Map<String, dynamic> event) {
    final x = event['x'] as int;
    final y = event['y'] as int;
    final gid = event['gid'] as int;

    // Update the tilemap with auto-tiling
    _tilemap.updateTileWithAutoTiling(x, y, gid);

    // Add visual overlay to show the change
    _addTileChangeOverlay(x, y);
  }

  /// Add visual overlay for tile changes
  void _addTileChangeOverlay(int x, int y) {
    final key = '$x,$y';
    
    // Remove existing overlay
    tileOverlays[key]?.removeFromParent();
    tileOverlays.remove(key);

    // Create new overlay
    final overlay = SpriteComponent(
      position: Vector2(x * tileSize, y * tileSize),
      size: Vector2.all(tileSize),
    );
    
    // Add a simple color overlay (you could use a sprite instead)
    world.add(overlay);
    tileOverlays[key] = overlay;

    // Remove overlay after a few seconds
    Timer(3.0, () {
      overlay.removeFromParent();
      tileOverlays.remove(key);
    });
  }

  /// Start broadcasting player position
  void _startPositionBroadcast() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_userId != null) {
        _farmPlayerService.broadcastPosition(
          player.position.x / tileSize,
          player.position.y / tileSize,
        );
      }
    });
  }

  /// Handle player position changes
  void _handlePlayerPositionChange(Vector2 position) {
    // Handle player movement logic
    debugPrint('[EnhancedTiledFarmGame] Player moved to: $position');
  }

  /// Public method to update a tile with auto-tiling
  Future<void> updateTileWithAutoTiling(int x, int y, int newGid) async {
    await _tilemap.updateTileWithAutoTiling(x, y, newGid);
    
    // Broadcast the change to other players
    if (_userId != null) {
      await _farmTileService.updateTile(farmId, x, y, newGid);
    }
  }

  /// Get tile properties at a position
  Map<String, dynamic>? getTilePropertiesAt(int x, int y) {
    return _tilemap.getTilePropertiesAt(x, y);
  }

  /// Check if a tile has a specific property
  bool hasTileProperty(int x, int y, String propertyName) {
    return _tilemap.hasTileProperty(x, y, propertyName);
  }

  /// Get the current GID at a position
  int getGidAt(int x, int y) {
    return _tilemap.getGidAt(x, y);
  }

  @override
  void onRemove() {
    _movementSub?.cancel();
    _tileChangesSub?.cancel();
    _tileBroadcastSub?.cancel();
    super.onRemove();
  }

  /// Get all adjacent positions where the hoe can be used
  List<Point> _getAdjacentHoePositions() {
    final positions = <Point>[];
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
          positions.add(Point(x, y));
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
      final key = '${position.x}_${position.y}';
      
      // Create a highlight rectangle
      final highlight = RectangleComponent(
        position: Vector2(position.x * tileSize, position.y * tileSize),
        size: Vector2(tileSize, tileSize),
        paint: Paint()
          ..color = Colors.orange.withOpacity(0.4)
          ..style = PaintingStyle.fill,
      );
      
      _hoeHighlights[key] = highlight;
      world.add(highlight);
    }
    
    debugPrint('[EnhancedTiledFarmGame] 🌟 Highlighted ${hoePositions.length} hoe-usable positions');
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
    final currentHoeState = _playerHasHoe();
    final currentPlayerPosition = Point(
      (player.position.x / tileSize).floor(),
      (player.position.y / tileSize).floor(),
    );
    
    // Check if player has moved
    final playerMoved = _lastPlayerPosition == null || 
                       currentPlayerPosition.x != _lastPlayerPosition!.x || 
                       currentPlayerPosition.y != _lastPlayerPosition!.y;
    
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
      }
    }
    
    // Update if hoe state has changed OR player stopped moving
    final hoeStateChanged = currentHoeState != _lastHoeState;
    final shouldUpdate = hoeStateChanged || (!_isPlayerMoving && playerMoved);
    
    if (shouldUpdate) {
      _updateHoeHighlights();
      _lastHoeState = currentHoeState;
    }
  }

  /// Update hoe highlights based on current state
  void _updateHoeHighlights() {
    final currentHoeState = _playerHasHoe();
    
    if (currentHoeState && !_isPlayerMoving) {
      _highlightHoePositions();
    } else {
      _clearHoeHighlights();
    }
  }

  /// Check if player has hoe selected in inventory
  bool _playerHasHoe() {
    if (inventoryManager == null) {
      debugPrint('[EnhancedTiledFarmGame] No inventory manager available');
      return false;
    }
    
    final selectedItem = inventoryManager!.selectedItem;
    if (selectedItem == null) {
      debugPrint('[EnhancedTiledFarmGame] No item selected in inventory');
      return false;
    }
    
    final hasHoe = selectedItem.id == 'hoe';
    debugPrint('[EnhancedTiledFarmGame] Checking if player has hoe... Selected item: ${selectedItem.name} (${selectedItem.id}), Has hoe: $hasHoe');
    return hasHoe;
  }

  /// Check if a tile is tillable
  bool _isTileTillable(int gridX, int gridY) {
    final properties = getTilePropertiesAt(gridX, gridY);
    if (properties != null && properties.containsKey('isTillable')) {
      return properties['isTillable'] == true;
    }
    
    // Also check if it's a grass tile by GID
    final gid = getGidAt(gridX, gridY);
    return gid >= 24 && gid <= 30; // Grass tiles
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Update hoe highlighting
    _updateHoeHighlighting();
  }
} 
