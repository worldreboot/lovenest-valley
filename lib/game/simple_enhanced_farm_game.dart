import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lovenest_valley/components/player.dart';
import 'package:lovenest_valley/utils/pathfinding.dart';
import 'package:lovenest_valley/game/base/game_with_grid.dart';
import 'package:lovenest_valley/components/world/hoe_animation.dart';
import 'package:lovenest_valley/components/world/watering_can_animation.dart';
import 'package:lovenest_valley/components/owl_npc.dart';
import 'package:lovenest_valley/services/question_service.dart';
import 'package:lovenest_valley/services/daily_question_seed_service.dart';
import 'package:lovenest_valley/services/daily_question_seed_collection_service.dart';
import 'package:lovenest_valley/services/seed_service.dart';
import 'package:lovenest_valley/models/memory_garden/question.dart';
import 'package:lovenest_valley/behaviors/camera_bounds.dart';
import 'package:lovenest_valley/models/inventory.dart';
import 'package:lovenest_valley/utils/tiled_parser.dart' as custom_parser;
import 'package:lovenest_valley/terrain/terrain_type.dart';
import 'package:lovenest_valley/terrain/terrain_parser.dart';
import 'package:lovenest_valley/components/planted_seed_component.dart';
import 'package:lovenest_valley/utils/seed_color_generator.dart';
import 'package:lovenest_valley/services/farm_tile_service.dart';
import 'package:lovenest_valley/services/seashell_service.dart';
import 'package:lovenest_valley/components/world/seashell_object.dart';
import 'package:lovenest_valley/components/world/relationship_bonfire.dart';
import 'package:lovenest_valley/components/world/day_night_overlay.dart';
import 'package:lovenest_valley/components/world/light_overlay.dart';
import 'package:lovenest_valley/components/world/gift_object.dart';
import 'package:lovenest_valley/components/world/obstacle_overlay.dart';
import 'package:lovenest_valley/services/placed_gift_service.dart';
import 'package:lovenest_valley/services/farm_player_service.dart';
import 'package:lovenest_valley/components/smooth_player.dart';
import 'package:lovenest_valley/config/supabase_config.dart';
import 'package:lovenest_valley/components/chest_object.dart';
import 'package:lovenest_valley/models/chest_storage.dart';
import 'package:lovenest_valley/services/chest_storage_service.dart';
import 'package:lovenest_valley/services/garden_repository.dart';
import 'package:lovenest_valley/services/starter_items_service.dart';
import 'package:lovenest_valley/components/world/decoration_object.dart';
// import 'package:flame/effects.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async' as dart_async;
import 'dart:math' as math;
// import 'dart:collection';

import 'package:lovenest_valley/game/simple_enhanced/utils/coord_utils.dart'
    as coord;
import 'package:lovenest_valley/game/simple_enhanced/terrain/tile_renderer.dart';
import 'package:lovenest_valley/game/simple_enhanced/ui/highlight_manager.dart';
import 'package:lovenest_valley/game/simple_enhanced/tools/tool_actions.dart';
import 'package:lovenest_valley/game/simple_enhanced/seeds/seed_sprites.dart';

part 'simple_enhanced/parts/seeds.dart';
part 'simple_enhanced/parts/backend_restore.dart';
part 'simple_enhanced/parts/seashells.dart';
part 'simple_enhanced/parts/rendering.dart';
part 'simple_enhanced/parts/parsers_autotile.dart';
part 'simple_enhanced/parts/player_camera_npc.dart';
part 'simple_enhanced/parts/vertex_terrain.dart';
part 'simple_enhanced/parts/tools_and_highlighting.dart';
part 'simple_enhanced/parts/autotile_helpers.dart';
part 'simple_enhanced/parts/input_and_rules.dart';
part 'simple_enhanced/parts/terrain_system.dart';

/// Typed grid coordinate used for sets/maps instead of string keys like "x,y"
class GridPos {
  final int x;
  final int y;
  const GridPos(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GridPos && other.x == x && other.y == y);

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x,$y)';
}

/// Simple enhanced farm game that uses our custom Tiled parser
class SimpleEnhancedFarmGame extends GameWithGrid
    with HasCollisionDetection, HasKeyboardHandlerComponents, TapCallbacks {
  final String farmId;
  late Player player;
  // Remove the unused cameraComponent declaration
  late PathfindingGrid _pathfindingGrid;

  // Map dimensions from the Tiled file
  static const int mapWidth = 64;
  static const int mapHeight = 28;
  static const double tileSize = 16.0;

  // Store bonfire positions for pathfinding
  final Set<GridPos> bonfirePositions = {};

  // Store owl positions for pathfinding
  final Set<GridPos> owlPositions = {};

  // Store chest positions for pathfinding
  final Set<GridPos> chestPositions = {};
  // Store gift positions for pathfinding
  final Set<GridPos> giftPositions = {};
  // Store seashell positions for pathfinding
  final Set<GridPos> seashellPositions = {};
  // Store decoration footprint obstacles for debug filtering
  final Set<GridPos> decorationObstaclePositions = {};

  final dart_async.Completer<void> _readyCompleter =
      dart_async.Completer<void>();
  bool _userInputEnabled = true;

  @override
  void markDecorationObstacle(int gridX, int gridY) {
    decorationObstaclePositions.add(GridPos(gridX, gridY));
    debugPrint(
        '[SimpleEnhancedFarmGame] Marked decoration obstacle at ($gridX, $gridY). Total: ${decorationObstaclePositions.length}');
  }

  @override
  bool isDecorationObstacleTile(int gridX, int gridY) {
    final isDecoration =
        decorationObstaclePositions.contains(GridPos(gridX, gridY));
    if (isDecoration) {
      debugPrint(
          '[SimpleEnhancedFarmGame] Tile ($gridX, $gridY) is decoration obstacle');
    }
    return isDecoration;
  }

  void setUserInputEnabled(bool enabled) {
    _userInputEnabled = enabled;
  }

  bool get isUserInputEnabled => _userInputEnabled;

  Future<void> waitUntilReady() => _readyCompleter.future;

  Future<void> movePlayerToGrid(int gridX, int gridY) async {
    if (!_readyCompleter.isCompleted) {
      await waitUntilReady();
    }
    player.pathfindTo(gridX, gridY);
    await _waitForPlayerIdle();
  }

  Future<void> movePlayerToWorld(Vector2 worldPosition) async {
    if (!_readyCompleter.isCompleted) {
      await waitUntilReady();
    }
    player.moveTowards(worldPosition);
    await _waitForPlayerIdle();
  }

  Vector2 gridToWorldCenter(int gridX, int gridY) {
    return Vector2(
      gridX * tileSize + tileSize / 2,
      gridY * tileSize + tileSize / 2,
    );
  }

  Future<void> _waitForPlayerIdle(
      {Duration timeout = const Duration(seconds: 8)}) async {
    if (!_readyCompleter.isCompleted) {
      await waitUntilReady();
    }
    final completer = dart_async.Completer<void>();
    final start = DateTime.now();
    dart_async.Timer? timer;
    timer = dart_async.Timer.periodic(const Duration(milliseconds: 50), (_) {
      final isMoving = player.currentPath.isNotEmpty ||
          player.manualTarget != null ||
          (player.velocity.x.abs() + player.velocity.y.abs()) > 0.01;
      if (!isMoving) {
        timer?.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      } else if (DateTime.now().difference(start) > timeout) {
        timer?.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });
    await completer.future;
  }

  // Realtime: subscription to chest updates
  dart_async.StreamSubscription<ChestStorage>? _chestUpdatesSub;

  // Inventory manager for checking tools
  final InventoryManager? inventoryManager;

  // Callback for owl tap events
  final void Function(Question)? onOwlTapped;

  // Callback for examine/open actions (e.g., chests)
  final void Function(String, ChestStorage?)? onExamine;

  // Callback for planting seeds
  final void Function(int gridX, int gridY, InventoryItem? selectedItem)?
      onPlantSeed;

  // Custom parser instances
  late custom_parser.TilesetParser _groundTilesetParser;
  late custom_parser.TilesetParser _beachTilesetParser;
  late custom_parser.TilesetParser _stairsTilesetParser;
  late custom_parser.TilesetParser _housesTilesetParser;
  late custom_parser.TilesetParser _smokeTilesetParser;
  late custom_parser.TilesetParser _treesTilesetParser;
  late custom_parser.TilesetParser _woodenTilesetParser;
  late custom_parser.TilesetParser _beachObjectsTilesetParser;
  late custom_parser.MapParser _mapParser;
  late custom_parser.AutoTiler _autoTiler;
  // Tileset GID offsets and counts for property lookup
  int? _groundFirstGid;
  int? _beachFirstGid;
  int? _stairsFirstGid;
  int? _housesFirstGid;
  int? _smokeFirstGid;
  int? _treesFirstGid;
  int? _woodenFirstGid;
  int? _beachObjectsFirstGid;
  int _groundTileCount = 0;
  int _beachTileCount = 0;
  int _stairsTileCount = 0;
  int _housesTileCount = 0;
  int _smokeTileCount = 0;
  int _treesTileCount = 0;
  int _woodenTileCount = 0;
  int _beachObjectsTileCount = 0;

  // Tile data from our custom parser - now supports multiple layers
  List<List<int>>? _groundTileData; // Ground layer (terrain)
  List<List<int>>? _decorationTileData; // Decoration layer (overlay)

  // Getter for backward compatibility (returns ground layer)
  List<List<int>>? get _tileData => _groundTileData;

  // Public getters for layer data
  List<List<int>>? get groundTileData => _groundTileData;
  List<List<int>>? get decorationTileData => _decorationTileData;

  // NEW: Vertex-based terrain system
  late List<List<int>> mapVertexGrid;
  late Map<String, int> terrainSignatureMap;
  bool _useVertexTerrainSystem = true; // Toggle to switch between systems
  // Gate: when false, do not auto-apply vertex overrides across the map
  bool _autoApplyVertexOverrides = false;

  // Flag to track if we're using a fresh TMX-based map
  bool _isUsingFreshTMXMap = false;

  /// Toggle between vertex-based and auto-tiling systems
  void toggleTerrainSystem() {
    _useVertexTerrainSystem = !_useVertexTerrainSystem;
    // debugPrint('[SimpleEnhancedFarmGame] 🔄 Switched to ${_useVertexTerrainSystem ? 'vertex-based' : 'auto-tiling'} terrain system');
    _terrainSystem = _useVertexTerrainSystem
        ? VertexTerrainSystem(this)
        : AutoTilingTerrainSystem(this);
  }

  /// Get current terrain system type
  String get currentTerrainSystem =>
      _useVertexTerrainSystem ? 'Vertex-Based' : 'Auto-Tiling';

  // Allow toggling vertex auto-apply behavior at runtime
  void setVertexAutoApply(bool enabled) {
    _autoApplyVertexOverrides = enabled;
  }

  // Tile rendering components
  // Tile rendering via TileRenderer
  late TileRenderer _tileRenderer;
  late ToolActions _toolActions;

  // Hoe highlighting system
  late HighlightManager _highlightManager;
  bool _isPlayerMoving = false; // Track if player is currently moving
  bool _currentHoeState = false; // Current hoe state
  bool _isHoeAnimationPlaying =
      false; // Track if hoe animation is currently playing

  // Watering can highlighting system
  // managed by HighlightManager
  bool _currentWateringCanState = false; // Current watering can state
  bool _isWateringCanAnimationPlaying =
      false; // Track if watering can animation is currently playing
  // Debounce timer for movement-driven highlight updates
  dart_async.Timer? _movementDebounceTimer;
  // Debounce timer for vertex grid persistence
  dart_async.Timer? _vertexSaveDebounceTimer;

  // Planted seeds system
  final Map<String, PlantedSeedComponent> _plantedSeeds = {};
  final SeedSpriteManager _seedSprites = SeedSpriteManager();
  late TerrainSystem _terrainSystem;
  // Multiplayer: realtime co-presence
  late final FarmPlayerService _farmPlayerService;
  String? _userId;
  final Map<String, SmoothPlayer> otherPlayers = {};
  dart_async.StreamSubscription<PlayerDestination>? _movementSub;

  @override
  PathfindingGrid get pathfindingGrid => _pathfindingGrid;

  SimpleEnhancedFarmGame({
    required this.farmId,
    this.inventoryManager,
    this.onOwlTapped,
    this.onPlantSeed,
    this.onExamine,
  });

  @override
  Color backgroundColor() => const Color(0xFF4A7C59); // Forest green

  // ===== Small helpers to improve readability =====
  int get _grassTerrainId => Terrain.GRASS.id;
  int get _dirtTerrainId => Terrain.DIRT.id;
  int get _tilledTerrainId => Terrain.TILLED.id;

// (moved to file top)

  bool _isValidTileIndex(int tileX, int tileY) {
    return tileX >= 0 && tileX < mapWidth && tileY >= 0 && tileY < mapHeight;
  }

  void _writeTileVertices(int tileX, int tileY, int terrainId) {
    // Guard: ensure indices are safe for the vertex grid (mapWidth+1 x mapHeight+1)
    if (!_isValidTileIndex(tileX, tileY)) return;
    mapVertexGrid[tileY][tileX] = terrainId;
    mapVertexGrid[tileY][tileX + 1] = terrainId;
    mapVertexGrid[tileY + 1][tileX] = terrainId;
    mapVertexGrid[tileY + 1][tileX + 1] = terrainId;
  }

  Future<void> _persistVertexGridState() async {
    try {
      final farmTileService = FarmTileService();
      await farmTileService.saveVertexGridState(farmId, mapVertexGrid);
      debugPrint(
          '[SimpleEnhancedFarmGame] ✅ Vertex grid state saved to database');
    } catch (e) {
      debugPrint(
          '[SimpleEnhancedFarmGame] ❌ Error saving vertex grid state: $e');
    }
  }

  Future<void> _setTileTerrainAndPersist(
      int tileX, int tileY, int terrainId) async {
    _writeTileVertices(tileX, tileY, terrainId);
    _schedulePersistVertexGridState();
    _updateSurroundingTilesVertex(tileX, tileY);
  }

  void _schedulePersistVertexGridState() {
    _vertexSaveDebounceTimer?.cancel();
    _vertexSaveDebounceTimer =
        dart_async.Timer(const Duration(milliseconds: 300), () {
      _persistVertexGridState();
    });
  }

  bool _isWithinOwlBounds(Vector2 worldPosition) {
    final owlX = 22;
    final owlY = 14;
    final owlPosition = Vector2(owlX * tileSize, owlY * tileSize);
    final scale = 0.10;
    final owlSize = Vector2(382.0 * scale, 478.0 * scale);
    final owlBounds = math.Rectangle(
      owlPosition.x,
      owlPosition.y,
      owlSize.x,
      owlSize.y,
    );
    return owlBounds
        .containsPoint(math.Point(worldPosition.x, worldPosition.y));
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Initialize custom parsers
    await _initializeCustomParsers();

    // Initialize vertex-based terrain system if enabled
    if (_useVertexTerrainSystem) {
      await _initializeVertexTerrainSystem();
    }

    // Initialize tile rendering
    await _initializeTileRendering();
    // Prepare helper renderer (not yet used to draw, to be swapped in next step)
    _tileRenderer = TileRenderer(
        images: images, tileSize: tileSize, world: world, game: this);
    await _tileRenderer.initialize();
    _highlightManager = HighlightManager(world: world, tileSize: tileSize);
    _toolActions = ToolActions(world: world, tileSize: tileSize);
    // debugPrint('[SimpleEnhancedFarmGame] ✅ Tile rendering initialized');
    _terrainSystem = _useVertexTerrainSystem
        ? VertexTerrainSystem(this)
        : AutoTilingTerrainSystem(this);

    // Create pathfinding grid
    _pathfindingGrid = PathfindingGrid(mapWidth, mapHeight, tileSize);
    // Populate obstacles based on Tiled walkable property
    try {
      _rebuildPathfindingObstaclesFromProperties();
    } catch (_) {}

    // Spawn player FIRST (before rendering tilemap)
    await _spawnPlayer();

    // Set up camera SECOND (before rendering tilemap)
    _setupCamera();

    // Add NPCs and objects
    await _addNPCsAndObjects();

    // Render the initial tilemap AFTER camera is set up
    await _renderTilemap();
    // debugPrint('[SimpleEnhancedFarmGame] ✅ Tilemap rendered');

    // Clean up any decorations that are on or adjacent to dirt tiles
    await _cleanupDecorationsOnDirtTiles();

    // Log performance stats after initialization
    _tileRenderer.logPerformanceStats();

    // Add obstacle debug overlay (toggle by feature flag)
    try {
      await world.add(ObstacleOverlay(tileSize: tileSize));
    } catch (_) {}

    // Initialize multiplayer after player/camera are ready
    await _initializeMultiplayer();
    // Initialize realtime chest updates so partner placements appear instantly
    await _initializeChestRealtime();

    // debugPrint('[SimpleEnhancedFarmGame] Game loaded successfully!');

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

    // Ensure starter chest exists in backend inventory
    await _ensureStarterChest();

    // Load backend state concurrently where possible
    await Future.wait([
      _loadPlantedSeedsFromBackend(),
      _checkAndRevertOldWateredTiles(),
      _loadTilledTilesFromBackend(),
      _loadWateredTilesFromBackend(),
      loadSeashells(),
      _loadPlacedGiftsFromBackend(),
      _loadChestsFromBackend(),
    ]);

    // Add day/night overlay over the world using screen space
    try {
      final overlay = DayNightOverlay(
        position: Vector2.zero(),
        maxNightStrength: 0.75,
      )..size = camera.viewport.size;
      await camera.viewport.add(overlay);
    } catch (_) {}

    // Add additive light overlay above the day/night overlay
    try {
      final lights = LightOverlay(tileSize: tileSize)
        ..position = Vector2.zero()
        ..size = camera.viewport.size;
      await camera.viewport.add(lights);
    } catch (_) {}

    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
  }

  Future<void> _initializeChestRealtime() async {
    try {
      final couple = await GardenRepository().getUserCouple();
      if (couple == null) return; // Only subscribe when a valid couple exists

      final service = ChestStorageService();
      await service.initializeRealtime(couple.id);

      // Listen for inserts/updates from partner and reflect them in the world
      _chestUpdatesSub?.cancel();
      _chestUpdatesSub = service.chestUpdates?.listen((updatedChest) async {
        try {
          final gridX = updatedChest.position.x.toInt();
          final gridY = updatedChest.position.y.toInt();

          // Check if a chest already exists at this grid position
          ChestObject? existingChest;
          for (final c in world.children.query<ChestObject>()) {
            final cx = (c.position.x / SimpleEnhancedFarmGame.tileSize).floor();
            final cy = (c.position.y / SimpleEnhancedFarmGame.tileSize).floor();
            if (cx == gridX && cy == gridY) {
              existingChest = c;
              break;
            }
          }
          final existingPosition =
              existingChest != null ? GridPos(gridX, gridY) : null;

          if (existingPosition == null) {
            // Add new chest object
            final pos = Vector2(
              gridX * SimpleEnhancedFarmGame.tileSize,
              gridY * SimpleEnhancedFarmGame.tileSize,
            );
            final chestObj = ChestObject(
              position: pos,
              size: Vector2.all(SimpleEnhancedFarmGame.tileSize),
              examineText: 'Open Chest',
              onExamineRequested: onExamine,
              chestStorage: updatedChest,
            );
            await world.add(chestObj);
            chestPositions.add(GridPos(gridX, gridY));
            _pathfindingGrid.setObstacle(gridX, gridY, true);
          } else {
            // Chest at position already exists; nothing to spawn.
          }
        } catch (_) {}
      });
    } catch (_) {}
  }

  /// Dispose realtime listeners (call from UI when tearing down the game)
  void disposeRealtime() {
    _chestUpdatesSub?.cancel();
    _chestUpdatesSub = null;
  }

  Future<void> _ensureStarterChest() async {
    if (inventoryManager == null) return;
    try {
      // Check if user has already received starter items
      final hasReceivedStarterItems =
          await StarterItemsService.hasReceivedStarterItems();

      if (hasReceivedStarterItems) {
        debugPrint(
            '[SimpleEnhancedFarmGame] ✅ User has already received starter items, skipping');
        // User has already received starter items, don't add anything
        return;
      }

      // Check if inventory is already initialized (has items)
      final hasItems = inventoryManager!.slots.any((item) => item != null);

      if (!hasItems) {
        // New user - initialize from backend (will be empty)
        await inventoryManager!.initialize();

        // Check if we still have no items after backend init (truly new user)
        final stillNoItems =
            inventoryManager!.slots.any((item) => item != null);
        if (!stillNoItems) {
          debugPrint(
              '[SimpleEnhancedFarmGame] 🎁 Adding starter items for new user (first time)');
          // Add all starter items for new users
          await inventoryManager!.addItem(const InventoryItem(
            id: 'watering_can',
            name: 'Watering Can',
            iconPath: 'assets/images/items/watering_can.png',
            quantity: 1,
          ));

          await inventoryManager!.addItem(const InventoryItem(
            id: 'hoe',
            name: 'Hoe',
            iconPath: 'assets/images/items/hoe.png',
            quantity: 1,
          ));

          await inventoryManager!.addItem(const InventoryItem(
            id: 'chest',
            name: 'Chest',
            iconPath: 'assets/images/Chests/1.png',
            quantity: 1,
          ));

          // Mark that user has received starter items
          await StarterItemsService.markStarterItemsReceived();
          debugPrint(
              '[SimpleEnhancedFarmGame] ✅ Marked starter items as received for user');
        }
      } else {
        // User has items but hasn't been marked as receiving starter items
        // This could happen if they had items before the tracking was implemented
        debugPrint(
            '[SimpleEnhancedFarmGame] 📦 User has items but no starter items tracking, marking as received');
        await StarterItemsService.markStarterItemsReceived();

        // Ensure they have a chest
        final hasChest =
            inventoryManager!.slots.any((item) => item?.id == 'chest');
        if (!hasChest) {
          debugPrint(
              '[SimpleEnhancedFarmGame] 📦 Adding missing chest to existing user');
          await inventoryManager!.addItem(const InventoryItem(
            id: 'chest',
            name: 'Chest',
            iconPath: 'assets/images/Chests/1.png',
            quantity: 1,
          ));
        }
      }
    } catch (e) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Error in _ensureStarterChest: $e');
    }
  }

  Future<void> _loadChestsFromBackend() async {
    try {
      final service = ChestStorageService();

      // Get chests for current user (couple or individual)
      final chests = await service.getCurrentUserChests();

      if (chests.isEmpty) {
        debugPrint('[SimpleEnhancedFarmGame] No chests found for current user');
        return;
      }

      debugPrint(
          '[SimpleEnhancedFarmGame] Loading ${chests.length} chests from backend');

      for (final chest in chests) {
        // Prevent duplicates if already present
        final existing = world.children.query<ChestObject>().any((c) {
          final gx = (c.position.x / SimpleEnhancedFarmGame.tileSize).floor();
          final gy = (c.position.y / SimpleEnhancedFarmGame.tileSize).floor();
          return gx == chest.position.x.toInt() &&
              gy == chest.position.y.toInt();
        });
        if (existing) continue;

        final pos = Vector2(
          chest.position.x * SimpleEnhancedFarmGame.tileSize,
          chest.position.y * SimpleEnhancedFarmGame.tileSize,
        );
        final chestObj = ChestObject(
          position: pos,
          size: Vector2.all(SimpleEnhancedFarmGame.tileSize),
          examineText: 'Open Chest',
          onExamineRequested: onExamine,
          chestStorage: chest,
          onPickUp: (chestId) async {
            print(
                '[SimpleEnhancedFarmGame] 🎯 onPickUp callback triggered for backend chest $chestId');
            // Only pick up if adjacent
            final gridX = chest.position.x.toInt();
            final gridY = chest.position.y.toInt();
            if (!_toolActions.isAdjacent(player.position, gridX, gridY)) {
              print(
                  '[SimpleEnhancedFarmGame] ❌ Cannot pick up backend chest - not adjacent to player');
              return;
            }

            print(
                '[SimpleEnhancedFarmGame] ✅ Player is adjacent, proceeding with backend chest pickup');
            // Add chest back to inventory WITH its storage data preserved
            await inventoryManager?.addItem(InventoryItem(
              id: 'chest',
              name: 'Chest',
              iconPath: 'assets/images/Chests/1.png',
              quantity: 1,
              chestStorage:
                  chest, // Preserve the chest storage with all its items
            ));

            print(
                '[SimpleEnhancedFarmGame] 📦 Backend chest added to inventory with ${chest.items.length} items preserved');

            // Remove chest from world
            for (final c in world.children.query<ChestObject>()) {
              final cx =
                  (c.position.x / SimpleEnhancedFarmGame.tileSize).floor();
              final gy =
                  (c.position.y / SimpleEnhancedFarmGame.tileSize).floor();
              if (cx == gridX && gy == gridY) {
                print(
                    '[SimpleEnhancedFarmGame] 🗑️ Removing backend chest from world at ($gridX, $gridY)');
                c.removeFromParent();
                break;
              }
            }

            // Remove from chest positions and pathfinding grid
            chestPositions.remove(GridPos(gridX, gridY));
            _pathfindingGrid.setObstacle(gridX, gridY, false);

            // IMPORTANT: Don't delete from backend - preserve the storage data
            // The chest storage will be reused when the chest is placed back down
            debugPrint(
                '[SimpleEnhancedFarmGame] 📦 Chest loaded from backend picked up with ${chest.items.length} items preserved');
          },
        );

        print(
            '[SimpleEnhancedFarmGame] 🏗️ Backend ChestObject created with onPickUp callback: ${chestObj.onPickUp != null}');
        await world.add(chestObj);
        print('[SimpleEnhancedFarmGame] 🌍 Backend chest added to world');
        chestPositions
            .add(GridPos(chest.position.x.toInt(), chest.position.y.toInt()));
        _pathfindingGrid.setObstacle(
            chest.position.x.toInt(), chest.position.y.toInt(), true);
      }
    } catch (e) {
      debugPrint(
          '[SimpleEnhancedFarmGame] ❌ Error loading chests from backend: $e');
    }
  }

  /// Check player status after game is fully loaded
  void _checkPlayerStatus() {
    // Wait a bit for components to fully mount
    Future.delayed(const Duration(milliseconds: 500), () {
      // debugPrint('[SimpleEnhancedFarmGame] 🔍 Final player status check:');
      // debugPrint('  - Is mounted: ${player.isMounted}');
      // debugPrint('  - Has animation: ${player.animation != null}');
      // debugPrint('  - Position: ${player.position}');
      // debugPrint('  - Parent: ${player.parent}');
      // debugPrint('  - Camera zoom: ${camera.viewfinder.zoom}');
// debugPrint('  - Camera position: ${camera.viewfinder.position}');

      if (!player.isMounted) {
        // debugPrint('[SimpleEnhancedFarmGame] ⚠️ Player is not mounted! This might cause rendering issues.');
      } else {
        // debugPrint('[SimpleEnhancedFarmGame] ✅ Player is properly mounted and should be visible!');
      }
    });
  }

  Future<void> _spawnPlayer() async {
    debugPrint('[SimpleEnhancedFarmGame] Spawning player...');

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
              player.onPositionChanged = (position, {animationState}) =>
                  _handlePlayerPositionChange(position);
              world.add(player);
              playerSpawned = true;
              debugPrint(
                  '[SimpleEnhancedFarmGame] ✅ Player spawned at (${player.position.x}, ${player.position.y}) from Spawn object');
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint(
          '[SimpleEnhancedFarmGame] ⚠️ Error accessing Tiled map objects: $e');
    }

    // Fallback to hardcoded position if no PlayerSpawn object found
    if (!playerSpawned) {
      debugPrint(
          '[SimpleEnhancedFarmGame] ⚠️ No PlayerSpawn object found, using fallback position');
      final spawnX = 488.0;
      final spawnY = 181.0;

      player = Player();
      player.position = Vector2(spawnX, spawnY);
      player.onPositionChanged =
          (position, {animationState}) => _handlePlayerPositionChange(position);
      world.add(player);

      debugPrint(
          '[SimpleEnhancedFarmGame] ✅ Player spawned at fallback position (${player.position.x}, ${player.position.y})');
    }

    // Let Flame handle the component lifecycle properly
    // debugPrint('[SimpleEnhancedFarmGame] ⏳ Player added to world, waiting for mount...');

    // Debug player info
    // debugPrint('[SimpleEnhancedFarmGame] 🔍 Player debug info:');
    // debugPrint('  - Position: ${player.position}');
    // debugPrint('  - Size: ${player.size}');
    // debugPrint('  - Priority: ${player.priority}');
    // debugPrint('  - Parent: ${player.parent}');

    // Debug player sprite info
    // debugPrint('[SimpleEnhancedFarmGame] 🎨 Player sprite debug info:');
    // debugPrint('  - Has animation: ${player.animation != null}');
    if (player.animation != null) {
      // debugPrint('  - Animation frame count: ${player.animation!.frames.length}');
    }
    // debugPrint('  - Anchor: ${player.anchor}');
    // debugPrint('  - Scale: ${player.scale}');
  }

  Future<void> _addNPCsAndObjects() async {
    // Load owl sprite
    final owlImage = await images.load('owl.png');
    final owlNotiImage = await images.load('owl_noti.png');

    // Create sprite sheet and extract the first frame
    final frameWidth = 382.0;
    final frameHeight = 478.0;
    final spriteSheet =
        SpriteSheet(image: owlImage, srcSize: Vector2(frameWidth, frameHeight));
    final idleSprite = spriteSheet.getSprite(0, 0); // Get the first frame
    final notificationSprite = Sprite(owlNotiImage);

    // Scale down to a reasonable NPC size while maintaining aspect ratio
    final scale = 0.10; // Scale down to 10% of original size
    final owlSize = Vector2(frameWidth * scale, frameHeight * scale);

    // Try to get spawn points from Tiled map
    Vector2? owlSpawnPosition;
    Vector2? bonfireSpawnPosition;

    try {
      final objectGroups = _mapParser.getObjectGroups();
      for (final group in objectGroups) {
        if (group.name == 'SpawnPoint') {
          for (final obj in group.objects) {
            if (obj.name == 'OwlSpawn') {
              owlSpawnPosition = Vector2(obj.x, obj.y);
              debugPrint(
                  '[SimpleEnhancedFarmGame] 🦉 Found OwlSpawn at (${obj.x}, ${obj.y})');
            } else if (obj.name == 'BonfireSpawn') {
              bonfireSpawnPosition = Vector2(obj.x, obj.y);
              debugPrint(
                  '[SimpleEnhancedFarmGame] 🔥 Found BonfireSpawn at (${obj.x}, ${obj.y})');
            }
          }
        }
      }
    } catch (e) {
      debugPrint(
          '[SimpleEnhancedFarmGame] ⚠️ Could not read spawn points from Tiled map: $e');
    }

    // Use spawn points from Tiled map, or fallback to hardcoded positions
    final owlPosition =
        owlSpawnPosition ?? Vector2(41 * tileSize, 5.5 * tileSize);
    final bonfirePosition =
        bonfireSpawnPosition ?? Vector2(34.5 * tileSize, 9.5 * tileSize);

    final owlNpc = OwlNpcComponent(
      position: owlPosition,
      size: owlSize,
      idleSprite: idleSprite,
      notificationSprite: notificationSprite,
      onTapOwl: () async {
        debugPrint('[SimpleEnhancedFarmGame] 🦉 Owl NPC tapped!');

        // Check for daily question
        final dailyQuestion = await QuestionService.fetchDailyQuestion();
        if (dailyQuestion != null) {
          debugPrint(
              '[SimpleEnhancedFarmGame] 🦉 Daily question available: ${dailyQuestion.text}');
          // Use the callback to show the daily question prompt
          onOwlTapped?.call(dailyQuestion);
        } else {
          debugPrint('[SimpleEnhancedFarmGame] 🦉 No daily question available');
          // Could show a different message or interaction
        }
      },
    );
    world.add(owlNpc);

    // Block all tiles covered by owl footprint
    final owlTileX = (owlPosition.x / tileSize).floor();
    final owlTileY = (owlPosition.y / tileSize).floor();
    final owlCoverW = (owlSize.x / tileSize).ceil();
    final owlCoverH = (owlSize.y / tileSize).ceil();
    for (int dy = 0; dy < owlCoverH; dy++) {
      for (int dx = 0; dx < owlCoverW; dx++) {
        final gx = owlTileX + dx;
        final gy = owlTileY + dy;
        if (gx >= 0 && gx < mapWidth && gy >= 0 && gy < mapHeight) {
          owlPositions.add(GridPos(gx, gy));
          _pathfindingGrid.setObstacle(gx, gy, true);
        }
      }
    }

    // Check for daily question and update owl notification
    final dailyQuestion = await QuestionService.fetchDailyQuestion();

    if (dailyQuestion != null) {
      // Check if user has already collected this seed
      final hasCollected =
          await DailyQuestionSeedCollectionService.hasUserCollectedSeed(
              dailyQuestion.id);

      if (!hasCollected) {
        owlNpc.showNotification(true);
        debugPrint(
            '[SimpleEnhancedFarmGame] 🦉 Owl notification ON - daily question available and not collected');
      } else {
        owlNpc.showNotification(false);
        debugPrint(
            '[SimpleEnhancedFarmGame] 🦉 Owl notification OFF - daily question already collected');
      }
    } else {
      owlNpc.showNotification(false);
      debugPrint(
          '[SimpleEnhancedFarmGame] 🦉 Owl notification OFF - no daily question available');
    }

    debugPrint(
        '[SimpleEnhancedFarmGame] 🦉 Owl NPC added at position (${owlPosition.x.toStringAsFixed(1)}, ${owlPosition.y.toStringAsFixed(1)}) with size ${owlSize}');

    // Relationship Bonfire (grows with shared goals)
    try {
      final bonfireSize = Vector2.all(32);
      final relationshipBonfire = RelationshipBonfire(
        farmId: farmId,
        position: bonfirePosition,
        size: bonfireSize,
      );
      await world.add(relationshipBonfire);

      // Block all tiles covered by bonfire footprint (likely 2x2)
      final bonfireTileX = (bonfirePosition.x / tileSize).floor();
      final bonfireTileY = (bonfirePosition.y / tileSize).floor();
      final fireCoverW = (bonfireSize.x / tileSize).ceil();
      final fireCoverH = (bonfireSize.y / tileSize).ceil();
      for (int dy = 0; dy < fireCoverH; dy++) {
        for (int dx = 0; dx < fireCoverW; dx++) {
          final gx = bonfireTileX + dx;
          final gy = bonfireTileY + dy;
          if (gx >= 0 && gx < mapWidth && gy >= 0 && gy < mapHeight) {
            bonfirePositions.add(GridPos(gx, gy));
            _pathfindingGrid.setObstacle(gx, gy, true);
          }
        }
      }
      debugPrint(
          '[SimpleEnhancedFarmGame] 🔥 RelationshipBonfire added at (${bonfirePosition.x.toStringAsFixed(1)}, ${bonfirePosition.y.toStringAsFixed(1)})');
    } catch (e, st) {
      debugPrint(
          '[SimpleEnhancedFarmGame] ❌ Failed to add RelationshipBonfire: $e');
      debugPrint('$st');
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
        debugPrint(
            '[SimpleEnhancedFarmGame] 🦉 Updated owl notification: ${showNotification ? 'ON' : 'OFF'}');
      } else {
        debugPrint('[SimpleEnhancedFarmGame] ⚠️ No owl NPC found in world');
      }
    } catch (e) {
      debugPrint(
          '[SimpleEnhancedFarmGame] ❌ Error updating owl notification: $e');
    }
  }

  void _setupCamera() {
    // Use the built-in camera from FlameGame rather than a separate CameraComponent
    camera.world = world;
    camera.follow(player);

    // Set initial camera position explicitly so the first frame is correct
    camera.viewfinder.position = player.position;

    // Prevent the camera from leaving the map bounds
    camera.viewfinder.add(CameraBoundsBehavior());

    // Reasonable zoom so player is visible
    camera.viewfinder.zoom = 2.0;

    // Ensure camera starts within bounds by forcing an update
    // This prevents the camera from starting outside the map boundaries
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Force camera bounds check after the first frame
      final boundsBehavior = camera.viewfinder.children
          .whereType<CameraBoundsBehavior>()
          .firstOrNull;
      if (boundsBehavior != null) {
        boundsBehavior.update(0.0);
      }
    });

    debugPrint('[SimpleEnhancedFarmGame] 📷 Camera configured:');
    debugPrint(
        '  - Map size: ${mapWidth}x${mapHeight} tiles (${mapWidth * tileSize}x${mapHeight * tileSize} pixels)');
    debugPrint('  - Player position: ${player.position}');
    debugPrint('  - Camera zoom: ${camera.viewfinder.zoom}');
    debugPrint('  - Camera bounds behavior added');

    // Force a refresh of decoration objects after camera is properly set up
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
          '[SimpleEnhancedFarmGame] 🔄 Forcing decoration refresh after camera setup...');
      _tileRenderer.updateVisibleTiles(force: true);
    });
  }

  /// Handle player position changes
  void _handlePlayerPositionChange(Vector2 position) {
    // Event-driven highlighting with debounce
    _isPlayerMoving = true;
    _movementDebounceTimer?.cancel();
    _movementDebounceTimer =
        dart_async.Timer(const Duration(milliseconds: 300), () {
      _isPlayerMoving = false;
      _updateHoeHighlights();
      _updateWateringCanHighlights();
    });
  }

  @override
  void onTapDown(TapDownEvent event) {
    debugPrint(
        '[SimpleEnhancedFarmGame] 🎯 Game received tap at ${event.canvasPosition}');
    debugPrint(
        '[SimpleEnhancedFarmGame] 🎯 Tap event device position: ${event.devicePosition}');
    // Call super first to allow child components (like owl) to handle their tap events
    super.onTapDown(event);
    // Then handle game-specific tap logic
    handleTapDown(
        event); // Fire and forget - async function will handle the logic
  }

  /// Public entrypoint to try watering a tile (used by components like plants)
  /// Returns true if watering was initiated (animation started)
  Future<bool> tryWaterAt(int gridX, int gridY) async {
    // Must have watering can selected
    if (!_currentWateringCanState) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ No watering can selected');
      return false;
    }

    // Must be adjacent to the player
    if (!_toolActions.isAdjacent(player.position, gridX, gridY)) {
      debugPrint(
          '[SimpleEnhancedFarmGame] ❌ Tile at ($gridX, $gridY) is not adjacent to player');
      return false;
    }

    // Must have a waterable seed on the tile
    final plant = _getPlantedSeedAt(gridX, gridY);
    if (plant == null) {
      debugPrint(
          '[SimpleEnhancedFarmGame] ❌ No seed found at ($gridX, $gridY) - cannot water empty tile');
      return false;
    }

    if (plant.growthStage == 'fully_grown') {
      debugPrint(
          '[SimpleEnhancedFarmGame] ❌ Seed at ($gridX, $gridY) is already fully grown - cannot water');
      return false;
    }

    // Check if watering will succeed before starting animation
    if (await _canWaterTile(gridX, gridY)) {
      // Start watering animation; completion will apply watering effects
      _playWateringCanAnimation(gridX, gridY);
      return true;
    } else {
      debugPrint(
          '[SimpleEnhancedFarmGame] ❌ Cannot water tile at ($gridX, $gridY) - no animation started');
      return false;
    }
  }

  /// Public method to update a tile with auto-tiling
  Future<void> updateTileWithAutoTiling(int x, int y, int newGid) async {
    if (_tileData != null &&
        x >= 0 &&
        x < _tileData![0].length &&
        y >= 0 &&
        y < _tileData!.length) {
      _tileData![y][x] = newGid;

      // Update visual representation
      await _updateTileVisual(_groundTileData!, x, y, newGid);

      // Apply auto-tiling to surrounding tiles
      await _applyAutoTilingToSurroundings(x, y);
    }
  }

  /// Check if a tile has a specific property
  bool hasTileProperty(int x, int y, String propertyName) {
    final properties = getTilePropertiesAt(x, y);
    return properties?.containsKey(propertyName) ?? false;
  }

  /// Get the current GID at a position (delegated to terrain system)
  int getGidAt(int x, int y) => _terrainSystem.getGidAt(x, y);

  /// Render a single tile
  // Removed: TileRenderer now handles rendering

  // Deprecated: adjacency now handled by ToolActions

  /// Event-based method to update hoe and watering can state (called when inventory changes)
  void onInventoryChanged() {
    final newHoeState = _checkIfPlayerHasHoe();
    if (newHoeState != _currentHoeState) {
      _currentHoeState = newHoeState;
      // debugPrint('[SimpleEnhancedFarmGame] Hoe state changed: $_currentHoeState');
      _updateHoeHighlights();
    }

    final newWateringCanState = _checkIfPlayerHasWateringCan();
    if (newWateringCanState != _currentWateringCanState) {
      _currentWateringCanState = newWateringCanState;
      // debugPrint('[SimpleEnhancedFarmGame] Watering can state changed: $_currentWateringCanState');
      _updateWateringCanHighlights();
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
    // Accept both testing and production ids
    return selectedItem.id == 'watering_can' ||
        selectedItem.id == 'watering_can_full';
  }

  /// Check if a tile is tillable (delegated to terrain system)
  bool _isTileTillable(int gridX, int gridY) =>
      _terrainSystem.isTillable(gridX, gridY);

  /// Check if a tile is tilled (dirt) and can be planted on
  // ignore: unused_element
  bool _isTileTilled(int gridX, int gridY) {
    // debugPrint('[SimpleEnhancedFarmGame] 🔍 Checking if tile is tilled at ($gridX, $gridY)');

    // Use vertex-based system if enabled
    if (_useVertexTerrainSystem) {
      if (gridX >= 0 &&
          gridX < mapWidth - 1 &&
          gridY >= 0 &&
          gridY < mapHeight - 1) {
        // Check if all 4 vertices of the tile are dirt (tilled)
        final dirtId = _dirtTerrainId;
        final bool isTilled = mapVertexGrid[gridY][gridX] == dirtId &&
            mapVertexGrid[gridY][gridX + 1] == dirtId &&
            mapVertexGrid[gridY + 1][gridX] == dirtId &&
            mapVertexGrid[gridY + 1][gridX + 1] == dirtId;

        // debugPrint('[SimpleEnhancedFarmGame]   - Vertex system: Tile is tilled: $isTilled');
        return isTilled;
      } else {
        // debugPrint('[SimpleEnhancedFarmGame]   - Vertex system: Tile out of bounds');
        return false;
      }
    } else {
      // Original GID-based system
      if (_tileData != null &&
          gridX >= 0 &&
          gridX < _tileData![0].length &&
          gridY >= 0 &&
          gridY < _tileData!.length) {
        final gid = _tileData![gridY][gridX];
        debugPrint('[SimpleEnhancedFarmGame]   - Tile GID: $gid');

        // Check if it's a tilled tile (dirt) that can be planted on
        // Based on ground.tsx, tiles with GID 27-35 are tilled soil
        // The _tillTileAt method sets GID to 28 for tilled soil
        if (gid >= 27 && gid <= 35) {
          debugPrint('[SimpleEnhancedFarmGame]   - Tile is tilled (GID 27-35)');
          return true;
        }

        // Also check specifically for GID 28 which is set by _tillTileAt
        if (gid == 28) {
          debugPrint(
              '[SimpleEnhancedFarmGame]   - Tile is tilled (GID 28 - set by hoe)');
          return true;
        }

        // Also check properties for explicit tilled flag
        final properties = getTilePropertiesAt(gridX, gridY);
        if (properties != null && properties.containsKey('isTilled')) {
          final isTilled = properties['isTilled'] == true;
          debugPrint(
              '[SimpleEnhancedFarmGame]   - Tile has isTilled property: $isTilled');
          return isTilled;
        }

        debugPrint('[SimpleEnhancedFarmGame]   - Tile is not tilled');
      } else {
        debugPrint(
            '[SimpleEnhancedFarmGame]   - Tile data is null or out of bounds');
      }

      return false;
    }
  }

  /// Check if a tile is tilled in the backend (async version)
  // Removed unused: _isTileTilledInBackend

  /// Check if a tile is watered in the backend
  // Removed unused: _isTileWateredInBackend

  /// Check if a tile is waterable (delegated to terrain system)
  bool _isTileWaterable(int gridX, int gridY) =>
      _terrainSystem.isWaterable(gridX, gridY);

  /// Helper method to compare two lists for equality
  bool _listsAreEqual(List<int> list1, List<int> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  /// Apply the "Tilled" Wang ID (3) to a tile to transform it to tilled soil
  Future<void> _applyTilledWangId(int gridX, int gridY) async {
    // debugPrint('[SimpleEnhancedFarmGame] 🚨 _applyTilledWangId called for ($gridX, $gridY)');

    // Remove any decorations on this tile before tilling
    // _removeDecorationsAtGridPosition(gridX, gridY); // Removed as per edit hint

    if (_tileData != null &&
        gridX >= 0 &&
        gridX < _tileData![0].length &&
        gridY >= 0 &&
        gridY < _tileData!.length) {
      final currentGid = _tileData![gridY][gridX];
      final currentTileId = currentGid - 1; // Convert GID to tile ID

      // debugPrint('[SimpleEnhancedFarmGame] Current tile GID: $currentGid, Tile ID: $currentTileId');

      // Get the current tile's wangid by searching through the autotiler's wang tiles
      List<int>? currentWangId;
      for (final wangTile in _autoTiler.wangTiles) {
        // Extract the original tile ID from the unique tile ID
        final originalTileId = wangTile.tileId % 1000;
        if (originalTileId == currentTileId) {
          currentWangId = wangTile.getWangIdValues();
          break;
        }
      }

      if (currentWangId != null) {
        // debugPrint('[SimpleEnhancedFarmGame] Current wangid: [${currentWangId.join(', ')}]');

        // Transform the wangid: replace color 1 (dirt) with color 3 (tilled soil)
        final transformedWangId = currentWangId.map((color) {
          if (color == 1) {
            // debugPrint('[SimpleEnhancedFarmGame] Transforming color 1 (dirt) -> 3 (tilled soil)');
            return 3; // Transform dirt to tilled soil
          }
          return color;
        }).toList();

        // debugPrint('[SimpleEnhancedFarmGame] Transformed wangid: [${transformedWangId.join(', ')}]');

        // Find the tile that matches the transformed wangid
        int? targetTileId;
        for (final wangTile in _autoTiler.wangTiles) {
          final tileWangId = wangTile.getWangIdValues();
          if (_listsAreEqual(tileWangId, transformedWangId)) {
            // Extract the original tile ID from the unique tile ID
            targetTileId = wangTile.tileId % 1000;
            break;
          }
        }

        if (targetTileId != null) {
          final targetGid = targetTileId + 1; // Convert tile ID to GID
          // debugPrint('[SimpleEnhancedFarmGame] Found matching tile: Tile ID $targetTileId (GID $targetGid)');

          // Update the tile data
          _tileData![gridY][gridX] = targetGid;

          // Update visual representation of the tile immediately
          await _updateTileVisual(_groundTileData!, gridX, gridY, targetGid);

          // Apply auto-tiling to surrounding tiles for seamless transitions
          await _applyAutoTilingToSurroundings(gridX, gridY);

          // debugPrint('[SimpleEnhancedFarmGame] ✅ Applied Tilled Wang ID transformation: GID $currentGid -> $targetGid');
        } else {
          // debugPrint('[SimpleEnhancedFarmGame] ❌ No matching tile found for transformed wangid: [${transformedWangId.join(', ')}]');
          // Fallback to the original hardcoded approach
          const tilledSoilGid = 28;
          _tileData![gridY][gridX] = tilledSoilGid;
          await _updateTileVisual(
              _groundTileData!, gridX, gridY, tilledSoilGid);
          await _applyAutoTilingToSurroundings(gridX, gridY);
        }
      } else {
        // debugPrint('[SimpleEnhancedFarmGame] ❌ No wangid found for current tile (GID: $currentGid)');
        // Fallback to the original hardcoded approach
        const tilledSoilGid = 28;
        _tileData![gridY][gridX] = tilledSoilGid;
        await _updateTileVisual(_groundTileData!, gridX, gridY, tilledSoilGid);
        await _applyAutoTilingToSurroundings(gridX, gridY);
      }
    }
  }

  /// Water a tile at the specified position
  Future<void> _waterTileAt(int gridX, int gridY) async {
    debugPrint(
        '[SimpleEnhancedFarmGame] 💧 Executing watering at ($gridX, $gridY)');
    try {
      final seedState = await SeedService.getSeedState(
          plotX: gridX, plotY: gridY, farmId: farmId);
      final plantType = seedState?['plant_type'] as String?;

      if (plantType == 'daily_question_seed') {
        final success = await DailyQuestionSeedService.waterDailyQuestionSeed(
            plotX: gridX, plotY: gridY, farmId: farmId);
        if (success) {
          // Only update visual state if watering succeeded
          final isReady = await DailyQuestionSeedService.isReadyToBloom(
              gridX, gridY, farmId);
          await updatePlantGrowth(
              gridX, gridY, isReady ? 'fully_grown' : 'growing');
          await _terrainSystem.water(gridX, gridY);
          // Also till the tile beneath the plant after watering
          await _tillTileAt(gridX, gridY);
        } else {
          debugPrint(
              '[SimpleEnhancedFarmGame] ❌ Daily question seed watering failed - no visual changes applied');
        }
        return;
      }

      if (plantType == 'regular_seed') {
        final success = await SeedService.waterRegularSeed(
            plotX: gridX, plotY: gridY, farmId: farmId);
        if (success) {
          // Only update visual state if watering succeeded
          final newState = await SeedService.getSeedState(
              plotX: gridX, plotY: gridY, farmId: farmId);
          final growthStage =
              (newState?['growth_stage'] as String?) ?? 'planted';
          await updatePlantGrowth(gridX, gridY, growthStage);
          await _terrainSystem.water(gridX, gridY);
          // Also till the tile beneath the plant after watering
          await _tillTileAt(gridX, gridY);
        } else {
          debugPrint(
              '[SimpleEnhancedFarmGame] ❌ Regular seed watering failed - no visual changes applied');
        }
        return;
      }
    } catch (e) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Error during watering: $e');
    }

    // Default: no seed or unknown type - always allow watering empty tiles
    await _terrainSystem.water(gridX, gridY);
  }

  /// Till a tile at the specified position
  Future<void> _tillTileAt(int gridX, int gridY) async {
    debugPrint('[SimpleEnhancedFarmGame] 🚜 Tilling tile at ($gridX, $gridY)');

    // Save to backend first
    try {
      final farmTileService = FarmTileService();
      await farmTileService.tillTile(farmId, gridX, gridY);
      debugPrint('[SimpleEnhancedFarmGame] ✅ Tile saved to backend');
    } catch (e) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Error saving tile to backend: $e');
      // Continue with local update even if backend fails
    }

    // Delegate to the active terrain system
    await _terrainSystem.till(gridX, gridY);
  }

  /// Remove decorations at a specific grid position and all adjacent tiles
  // void _removeDecorationsAtGridPosition(int gridX, int gridY) {
  //   final tileSize = SimpleEnhancedFarmGame.tileSize;
  //   final decorationsToRemove = <DecorationObject>[];

  //   // Check the center tile and all 8 adjacent tiles (3x3 grid)
  //   for (int dy = -1; dy <= 1; dy++) {
  //     for (int dx = -1; dx <= 1; dx++) {
  //       final checkX = gridX + dx;
  //       final checkY = gridY + dy;

  //       // Calculate tile boundaries for this position
  //       final tileLeft = checkX * tileSize;
  //       final tileTop = checkY * tileSize;
  //       final tileRight = tileLeft + tileSize;
  //       final tileBottom = tileTop + tileSize;

  //       // Find all decoration objects that overlap with this tile
  //       final decorations = descendants().whereType<DecorationObject>().toList();

  //       for (final decoration in decorations) {
  //         // Check if the decoration overlaps with the tile
  //         final decorationLeft = decoration.position.x;
  //         final decorationTop = decoration.position.y;
  //         final decorationRight = decorationLeft + decoration.size.x;
  //         final decorationBottom = decorationTop + decoration.size.y;

  //         // Check for overlap
  //         if (decorationLeft < tileRight &&
  //             decorationRight > tileLeft &&
  //             decorationTop < tileBottom &&
  //             decorationBottom > tileTop) {

  //           // Only add if not already in the list to avoid duplicates
  //           if (!decorationsToRemove.contains(decoration)) {
  //             debugPrint('[SimpleEnhancedFarmGame] 🗑️ Removing decoration ${decoration.objectType} at grid ($checkX, $checkY)');
  //             decorationsToRemove.add(decoration);
  //           }
  //         }
  //       }
  //     }
  //   }

  //   // Remove the decorations from the game world
  //   for (final decoration in decorationsToRemove) {
  //     decoration.removeFromParent();
  //   }

  //   if (decorationsToRemove.isNotEmpty) {
  //     debugPrint('[SimpleEnhancedFarmGame] ✅ Removed ${decorationsToRemove.length} decoration(s) from grid ($gridX, $gridY) and adjacent tiles');
  //   }
  // }

  /// Get all adjacent positions where the hoe can be used
  List<math.Point<double>> _getAdjacentHoePositions() {
    return _getAdjacentPositionsWhere(_isTileTillable);
  }

  /// Generic helper to compute all 8-adjacent positions around the player that satisfy a predicate
  List<math.Point<double>> _getAdjacentPositionsWhere(
      bool Function(int x, int y) predicate) {
    final positions = <math.Point<double>>[];
    final playerGridX = (player.position.x / tileSize).floor();
    final playerGridY = (player.position.y / tileSize).floor();
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        final x = playerGridX + dx;
        final y = playerGridY + dy;
        if (x >= 0 &&
            x < mapWidth &&
            y >= 0 &&
            y < mapHeight &&
            predicate(x, y)) {
          positions.add(math.Point<double>(x.toDouble(), y.toDouble()));
        }
      }
    }
    return positions;
  }

  /// Highlight tiles where the hoe can be used
  void _highlightHoePositions() {
    final hoePositions = _getAdjacentHoePositions();
    _highlightManager.showHoeAt(hoePositions);
  }

  /// Clear all hoe highlights
  void _clearHoeHighlights() {
    _highlightManager.clearHoe();
  }

  /// Update hoe highlights based on current state
  void _updateHoeHighlights() {
    if (_currentHoeState && !_isPlayerMoving) {
      _highlightHoePositions();
    } else {
      _clearHoeHighlights();
    }
  }

  /// Get all adjacent positions where the watering can can be used
  List<math.Point<double>> _getAdjacentWateringCanPositions() {
    return _getAdjacentPositionsWhere(_isTileWaterable);
  }

  /// Highlight tiles where the watering can can be used
  void _highlightWateringCanPositions() {
    final wateringCanPositions = _getAdjacentWateringCanPositions();
    _highlightManager.showWateringAt(wateringCanPositions);

    // debugPrint('[SimpleEnhancedFarmGame] 🌊 Highlighted ${wateringCanPositions.length} watering can-usable positions');
  }

  /// Clear all watering can highlights
  void _clearWateringCanHighlights() {
    _highlightManager.clearWatering();
  }

  /// Update watering can highlights based on current state
  void _updateWateringCanHighlights() {
    if (_currentWateringCanState && !_isPlayerMoving) {
      _highlightWateringCanPositions();
    } else {
      _clearWateringCanHighlights();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Highlight updates are event-driven via onPositionChanged debounce
  }

  @override
  void onRemove() {
    // Remove inventory listener
    if (inventoryManager != null) {
      inventoryManager!.removeListener(_onInventoryChanged);
    }
    _movementDebounceTimer?.cancel();
    // Ensure any pending vertex grid save is flushed before teardown
    if (_vertexSaveDebounceTimer?.isActive ?? false) {
      _vertexSaveDebounceTimer!.cancel();
      _persistVertexGridState();
    } else {
      _vertexSaveDebounceTimer?.cancel();
    }
    // Clean up multiplayer subscriptions
    _movementSub?.cancel();
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete();
    }
    super.onRemove();
  }

  /// Force refresh all planted seed components to check for generated sprites
  Future<void> forceRefreshPlantedSeeds() async {
    try {
      debugPrint(
          '[SimpleEnhancedFarmGame] 🔄 Force refreshing all planted seed components...');

      // Remove all existing planted seed components
      final existingSeeds =
          world.children.query<PlantedSeedComponent>().toList();
      for (final seed in existingSeeds) {
        seed.removeFromParent();
      }

      // Reload from backend
      await _loadPlantedSeedsFromBackend();

      debugPrint('[SimpleEnhancedFarmGame] ✅ Force refresh completed');
    } catch (e) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Error during force refresh: $e');
    }
  }

  /// Check if camera is within bounds and log status
  void checkCameraBounds() {
    final viewfinder = camera.viewfinder;
    final worldWidth = mapWidth * tileSize;
    final worldHeight = mapHeight * tileSize;

    final visibleRect = camera.visibleWorldRect;
    final halfViewportWidth = visibleRect.width / 2;
    final halfViewportHeight = visibleRect.height / 2;

    final minX = halfViewportWidth;
    final maxX = worldWidth - halfViewportWidth;
    final minY = halfViewportHeight;
    final maxY = worldHeight - halfViewportHeight;

    final isWithinBounds = viewfinder.position.x >= minX &&
        viewfinder.position.x <= maxX &&
        viewfinder.position.y >= minY &&
        viewfinder.position.y <= maxY;

    debugPrint('[SimpleEnhancedFarmGame] 📷 Camera bounds check:');
    debugPrint('  - Camera position: ${viewfinder.position}');
    debugPrint(
        '  - World bounds: (${minX.toStringAsFixed(1)}, ${minY.toStringAsFixed(1)}) to (${maxX.toStringAsFixed(1)}, ${maxY.toStringAsFixed(1)})');
    debugPrint('  - Within bounds: $isWithinBounds');

    if (!isWithinBounds) {
      debugPrint('  - ⚠️ Camera is outside bounds!');
    }
  }

  /// Reload the map data from valley.tmx file
  Future<void> reloadMap() async {
    try {
      debugPrint(
          '[SimpleEnhancedFarmGame] 🔄 Reloading map from valley.tmx...');

      // Re-initialize custom parsers to reload the map data
      await _initializeCustomParsers();

      // Re-initialize tile rendering
      await _initializeTileRendering();

      // Re-render the tilemap with new data (both ground and decoration layers)
      await _renderTilemap();

      debugPrint(
          '[SimpleEnhancedFarmGame] ✅ Map reloaded successfully from valley.tmx (Ground + Decorations)');
    } catch (e) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Error reloading map: $e');
    }
  }

  @override
  bool hasObjectAtPosition(int gridX, int gridY) {
    final pos = GridPos(gridX, gridY);
    return bonfirePositions.contains(pos) ||
        owlPositions.contains(pos) ||
        chestPositions.contains(pos) ||
        giftPositions.contains(pos) ||
        seashellPositions.contains(pos);
  }

  /// Clean up decorations that are on or adjacent to dirt tiles on app reload
  Future<void> _cleanupDecorationsOnDirtTiles() async {
    debugPrint(
        '[SimpleEnhancedFarmGame] 🧹 Cleaning up decorations on dirt tiles...');

    final decorations = descendants().whereType<DecorationObject>().toList();
    final decorationsToRemove = <DecorationObject>[];

    for (final decoration in decorations) {
      // Calculate the grid position of this decoration
      final decorationGridX = (decoration.position.x / tileSize).floor();
      final decorationGridY = (decoration.position.y / tileSize).floor();

      // Check if the decoration is on or adjacent to a dirt tile
      bool shouldRemove = false;

      // Check a 3x3 grid around the decoration
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          final checkX = decorationGridX + dx;
          final checkY = decorationGridY + dy;

          // Bounds check
          if (checkX >= 0 &&
              checkX < mapWidth &&
              checkY >= 0 &&
              checkY < mapHeight) {
            // Check if this tile is dirt (tilled)
            if (_isTileTilled(checkX, checkY)) {
              shouldRemove = true;
              break;
            }
          }
        }
        if (shouldRemove) break;
      }

      if (shouldRemove) {
        decorationsToRemove.add(decoration);
        debugPrint(
            '[SimpleEnhancedFarmGame] 🗑️ Marking decoration for removal: ${decoration.objectType} at grid ($decorationGridX, $decorationGridY)');
      }
    }

    // Remove the decorations
    for (final decoration in decorationsToRemove) {
      decoration.removeFromParent();
    }

    if (decorationsToRemove.isNotEmpty) {
      debugPrint(
          '[SimpleEnhancedFarmGame] ✅ Cleaned up ${decorationsToRemove.length} decoration(s) on dirt tiles');
    } else {
      debugPrint(
          '[SimpleEnhancedFarmGame] ✅ No decorations found on dirt tiles');
    }
  }
}
