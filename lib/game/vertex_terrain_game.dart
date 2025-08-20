import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lovenest/components/player.dart';
import 'package:lovenest/utils/pathfinding.dart';
import 'package:lovenest/game/base/game_with_grid.dart';
import 'package:lovenest/components/world/bonfire.dart';
import 'package:lovenest/components/world/hoe_animation.dart';
import 'package:lovenest/components/world/watering_can_animation.dart';
import 'package:lovenest/components/owl_npc.dart';
import 'package:lovenest/services/question_service.dart';
import 'package:lovenest/models/memory_garden/question.dart';
import 'package:lovenest/behaviors/camera_bounds.dart';
import 'package:lovenest/models/inventory.dart';
import 'package:lovenest/terrain/terrain_type.dart';
import 'package:lovenest/terrain/terrain_parser.dart';
import 'package:flame/camera.dart';
import 'dart:async';
import 'dart:math';

/// Vertex-based terrain game that uses the new terrain system
class VertexTerrainGame extends GameWithGrid with HasCollisionDetection, HasKeyboardHandlerComponents, TapCallbacks {
  final String farmId;
  late Player player;
  late PathfindingGrid _pathfindingGrid;
  
  // Map dimensions from the Tiled file
  static const int mapWidthInTiles = 64;
  static const int mapHeightInTiles = 28;
  static const double tileSize = 16.0;
  
  // Store bonfire positions for pathfinding
  final Set<String> bonfirePositions = {};
  
  // Store owl positions for pathfinding
  final Set<String> owlPositions = {};

  // Inventory manager for checking tools
  final InventoryManager? inventoryManager;

  // NEW: Vertex-based terrain system
  late List<List<int>> mapVertexGrid;
  late Map<String, int> terrainSignatureMap;
  
  // Tile rendering components
  late SpriteSheet _groundTileSpriteSheet;
  final Map<String, SpriteComponent> _tileSprites = {};
  
  // Hoe highlighting system
  final Map<String, RectangleComponent> _hoeHighlights = {};
  bool _isPlayerMoving = false;
  double _lastMovementTime = 0.0;
  bool _currentHoeState = false;
  Point? _lastPlayerPosition;
  bool _isHoeAnimationPlaying = false;
  
  // Watering can highlighting system
  final Map<String, RectangleComponent> _wateringCanHighlights = {};
  bool _currentWateringCanState = false;
  bool _isWateringCanAnimationPlaying = false;
  
  @override
  PathfindingGrid get pathfindingGrid => _pathfindingGrid;

  VertexTerrainGame({
    required this.farmId,
    this.inventoryManager,
  });

  @override
  Color backgroundColor() => const Color(0xFF4A7C59); // Forest green

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Initialize the vertex grid
    _initializeVertexGrid();
    
    // Load terrain signature map
    await _loadTerrainSignatureMap();
    
    // Initialize tile rendering
    await _initializeTileRendering();
    debugPrint('[VertexTerrainGame] ✅ Tile rendering initialized');
    
    // Render the initial tilemap
    await _renderInitialMap();
    debugPrint('[VertexTerrainGame] ✅ Tilemap rendered');
    
    // Create pathfinding grid
    _pathfindingGrid = PathfindingGrid(mapWidthInTiles, mapHeightInTiles, tileSize);
    
    // Spawn player
    await _spawnPlayer();
    
    // Add NPCs and objects
    await _addNPCsAndObjects();
    
    // Set up camera
    _setupCamera();
    
    debugPrint('[VertexTerrainGame] Game loaded successfully!');
    
    // Check player status after game is fully loaded
    _checkPlayerStatus();
    
    // Initialize hoe state
    _currentHoeState = _checkIfPlayerHasHoe();
    
    // Initialize watering can state
    _currentWateringCanState = _checkIfPlayerHasWateringCan();
    
    // Listen to inventory changes
    if (inventoryManager != null) {
      inventoryManager!.addListener(_onInventoryChanged);
    }
  }

  /// Initialize the vertex grid - the new source of truth
  void _initializeVertexGrid() {
    // Initialize the entire map to be a single terrain, e.g., GRASS.
    final initialTerrainId = Terrain.GRASS.id;
    mapVertexGrid = List.generate(
      mapHeightInTiles + 1,
      (_) => List.generate(mapWidthInTiles + 1, (_) => initialTerrainId),
    );
    debugPrint('[VertexTerrainGame] ✅ Vertex grid initialized: ${mapHeightInTiles + 1}x${mapWidthInTiles + 1}');
  }

  /// Load the terrain signature map from the .tsx file
  Future<void> _loadTerrainSignatureMap() async {
    debugPrint('[VertexTerrainGame] 📁 Loading terrain signature map from ground.tsx...');
    terrainSignatureMap = await TerrainParser.parseWangsetToSignatureMap('assets/ground.tsx', 1);
    debugPrint('[VertexTerrainGame] ✅ Terrain signature map loaded with ${terrainSignatureMap.length} entries');
  }

  /// Initialize tile rendering components
  Future<void> _initializeTileRendering() async {
          final image = await images.load('Tiles/Tile.png');
    _groundTileSpriteSheet = SpriteSheet(
      image: image,
      srcSize: Vector2.all(tileSize),
    );
  }

  /// Render the initial map using the vertex-based system
  Future<void> _renderInitialMap() async {
    debugPrint('[VertexTerrainGame] 🎨 Rendering initial map using vertex-based system...');
    
    for (int y = 0; y < mapHeightInTiles; y++) {
      for (int x = 0; x < mapWidthInTiles; x++) {
        final gid = getGidForTile(x, y);
        _renderTile(x, y, gid);
      }
    }
    
    debugPrint('[VertexTerrainGame] ✅ Initial map rendering complete');
  }

  /// Core function: Get GID for a tile based on vertex grid
  int getGidForTile(int x, int y) {
    // 1. Get the four corner terrain IDs from the vertex grid
    final tl_id = mapVertexGrid[y][x];
    final tr_id = mapVertexGrid[y][x + 1];
    final bl_id = mapVertexGrid[y + 1][x];
    final br_id = mapVertexGrid[y + 1][x + 1];

    // 2. Form the signature key
    final signatureKey = "$tl_id,$tr_id,$bl_id,$br_id";

    // 3. Look up the GID in our map
    // Provide a fallback GID (solid grass) if no match is found.
    return terrainSignatureMap[signatureKey] ?? 25; // 25 is solid grass GID
  }

  /// Render a single tile at the specified position
  void _renderTile(int x, int y, int gid) {
    final key = 'tile_${x}_$y';
    
    // Remove existing tile if it exists
    _tileSprites[key]?.removeFromParent();
    
    // Calculate sprite position
    final spriteX = x * tileSize;
    final spriteY = y * tileSize;
    
    // Get sprite from spritesheet
    final sprite = _groundTileSpriteSheet.getSpriteById(gid - 1); // GID to 0-based index
    if (sprite != null) {
      final tileComponent = SpriteComponent(
        sprite: sprite,
        position: Vector2(spriteX, spriteY),
        size: Vector2.all(tileSize),
      );
      
      _tileSprites[key] = tileComponent;
      add(tileComponent);
    }
  }

  /// Update tile visual at the specified position
  void _updateTileVisual(int x, int y, int newGid) {
    _renderTile(x, y, newGid);
  }

  /// Terrain modification: The "Hoe" action
  void tillTileAt(int tileX, int tileY) {
    debugPrint('[VertexTerrainGame] 🚜 Tilling tile at ($tileX, $tileY)');
    
    // 1. Check if the action is valid (e.g., hoeing grass).
    final currentGid = getGidForTile(tileX, tileY);
    // For now, allow tilling any tile. You can add validation here.
    
    // 2. Update the four vertices in the mapVertexGrid.
    final newTerrainId = Terrain.TILLED.id;
    mapVertexGrid[tileY][tileX] = newTerrainId;
    mapVertexGrid[tileY][tileX + 1] = newTerrainId;
    mapVertexGrid[tileY + 1][tileX] = newTerrainId;
    mapVertexGrid[tileY + 1][tileX + 1] = newTerrainId;

    // 3. Trigger a visual update for the surrounding 9 tiles.
    _updateSurroundingTiles(tileX, tileY);
  }

  /// Update surrounding tiles when a vertex changes
  void _updateSurroundingTiles(int centerX, int centerY) {
    debugPrint('[VertexTerrainGame] 🔄 Updating surrounding tiles for ($centerX, $centerY)');
    
    // Loop through the 3x3 grid centered on the original tile.
    // The original tile is at (centerX, centerY), but its vertices affect
    // tiles from (centerX-1, centerY-1) to (centerX+1, centerY+1).
    for (int y = centerY - 1; y <= centerY + 1; y++) {
      for (int x = centerX - 1; x <= centerX + 1; x++) {
        // Bounds check to ensure we don't go outside the map
        if (x >= 0 && x < mapWidthInTiles && y >= 0 && y < mapHeightInTiles) {
          final newGid = getGidForTile(x, y);
          _updateTileVisual(x, y, newGid);
        }
      }
    }
  }

  /// Check player status after game is fully loaded
  void _checkPlayerStatus() {
    Future.delayed(const Duration(milliseconds: 500), () {
      debugPrint('[VertexTerrainGame] 🔍 Final player status check:');
      debugPrint('  - Is mounted: ${player.isMounted}');
      debugPrint('  - Has animation: ${player.animation != null}');
      debugPrint('  - Position: ${player.position}');
      debugPrint('  - Parent: ${player.parent}');
      debugPrint('  - Camera zoom: ${camera.viewfinder.zoom}');
      debugPrint('  - Camera position: ${camera.viewfinder.position}');
      
      if (!player.isMounted) {
        debugPrint('[VertexTerrainGame] ⚠️ Player is not mounted! This might cause rendering issues.');
      } else {
        debugPrint('[VertexTerrainGame] ✅ Player is properly mounted and should be visible!');
      }
    });
  }

  /// Spawn player at the center of the map
  Future<void> _spawnPlayer() async {
    final centerX = (mapWidthInTiles * tileSize) / 2;
    final centerY = (mapHeightInTiles * tileSize) / 2;
    
    player = Player();
    player.position = Vector2(centerX, centerY);
    
    add(player);
    debugPrint('[VertexTerrainGame] ✅ Player spawned at ($centerX, $centerY)');
  }

  /// Add NPCs and objects to the world
  Future<void> _addNPCsAndObjects() async {
    // Add bonfire at a specific location
    final bonfireX = 20 * tileSize;
    final bonfireY = 15 * tileSize;
    
    final bonfire = Bonfire(
      position: Vector2(bonfireX, bonfireY),
      size: Vector2.all(tileSize),
      maxWoodCapacity: 10,
      woodBurnRate: 0.5,
      maxFlameSize: 50,
      maxIntensity: 1.0,
    );
    add(bonfire);
    bonfirePositions.add('${bonfireX.toInt()}_${bonfireY.toInt()}');
    
    // Add owl NPC
    final owlX = 40 * tileSize;
    final owlY = 10 * tileSize;
    
    // Load owl sprites
    final owlImage = await images.load('chibi.png');
    final owlNotiImage = await images.load('gift_1.png');
    
    final frameWidth = 478.0;
    final frameHeight = 478.0;
    final spriteSheet = SpriteSheet(image: owlImage, srcSize: Vector2(frameWidth, frameHeight));
    final idleSprite = spriteSheet.getSprite(0, 0);
    final notificationSprite = Sprite(owlNotiImage);
    
    final owl = OwlNpcComponent(
      position: Vector2(owlX, owlY),
      size: Vector2.all(tileSize),
      idleSprite: idleSprite,
      notificationSprite: notificationSprite,
    );
    add(owl);
    owlPositions.add('${owlX.toInt()}_${owlY.toInt()}');
    
    debugPrint('[VertexTerrainGame] ✅ NPCs and objects added');
  }

  /// Set up camera with bounds
  void _setupCamera() {
    final worldSize = Vector2(
      mapWidthInTiles * tileSize,
      mapHeightInTiles * tileSize,
    );
    
    camera.world = world;
    camera.follow(player);

    // Set initial camera position explicitly so the first frame is correct
    camera.viewfinder.position = player.position;

    // Prevent the camera from leaving the map bounds
    camera.viewfinder.add(CameraBoundsBehavior());

    // Reasonable zoom so player is visible
    camera.viewfinder.zoom = 2.0;
    
    debugPrint('[VertexTerrainGame] ✅ Camera setup complete');
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

  /// Handle inventory changes
  void _onInventoryChanged() {
    final newHoeState = _checkIfPlayerHasHoe();
    final newWateringCanState = _checkIfPlayerHasWateringCan();
    
    if (newHoeState != _currentHoeState) {
      _currentHoeState = newHoeState;
      debugPrint('[VertexTerrainGame] 🔧 Hoe state changed: $_currentHoeState');
    }
    
    if (newWateringCanState != _currentWateringCanState) {
      _currentWateringCanState = newWateringCanState;
      debugPrint('[VertexTerrainGame] 💧 Watering can state changed: $_currentWateringCanState');
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    
    // Convert screen position to world position
    // Screen coordinates are relative to the camera center, so we need to account for zoom and camera position
    final screenPos = event.canvasPosition;
    final cameraPos = camera.viewfinder.position;
    final zoom = camera.viewfinder.zoom;
    
    // Get screen center (camera center)
    final screenCenter = Vector2(size.x / 2, size.y / 2);
    
    // Calculate offset from screen center
    final offsetFromCenter = screenPos - screenCenter;
    
    // Convert to world coordinates
    final worldPosition = Vector2(
      cameraPos.x + (offsetFromCenter.x / zoom),
      cameraPos.y + (offsetFromCenter.y / zoom),
    );
    
    // Convert to grid coordinates
    final gridX = (worldPosition.x / tileSize).floor();
    final gridY = (worldPosition.y / tileSize).floor();
    
    debugPrint('[VertexTerrainGame] 👆 Tap at grid position ($gridX, $gridY)');
    
    // If player has hoe and is not moving, till the tile
    if (_currentHoeState && !_isPlayerMoving) {
      tillTileAt(gridX, gridY);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Update player movement tracking
    if (player.isMounted) {
      final currentPosition = Point(
        (player.position.x / tileSize).floor(),
        (player.position.y / tileSize).floor(),
      );
      
      if (_lastPlayerPosition != currentPosition) {
        _isPlayerMoving = true;
        _lastMovementTime = 0.0;
        _lastPlayerPosition = currentPosition;
      } else {
        _lastMovementTime += dt;
        if (_lastMovementTime > 0.1) { // Small delay to prevent immediate actions
          _isPlayerMoving = false;
        }
      }
    }
  }
} 