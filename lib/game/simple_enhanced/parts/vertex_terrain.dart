part of '../../simple_enhanced_farm_game.dart';

extension VertexTerrainExtension on SimpleEnhancedFarmGame {
  Future<void> _initializeVertexTerrainSystem() async {
    debugPrint('[SimpleEnhancedFarmGame] 🆕 Initializing vertex-based terrain system...');
    await _initializeTileData();
    _initializeVertexGrid();
    try {
      final farmTileService = FarmTileService();
      final savedVertexGrid = await farmTileService.loadVertexGridState(farmId);
      if (savedVertexGrid != null) {
        debugPrint('[SimpleEnhancedFarmGame] 📁 Loading vertex grid state from database...');
        if (savedVertexGrid.length == SimpleEnhancedFarmGame.mapHeight + 1 &&
            savedVertexGrid[0].length == SimpleEnhancedFarmGame.mapWidth + 1) {
          mapVertexGrid = savedVertexGrid;
          debugPrint('[SimpleEnhancedFarmGame] ✅ Vertex grid state loaded from database');
          _isUsingFreshTMXMap = false;
        } else {
          debugPrint('[SimpleEnhancedFarmGame] ⚠️ Loaded vertex grid has wrong dimensions, using TMX-based grid');
          await farmTileService.saveVertexGridState(farmId, mapVertexGrid);
          _isUsingFreshTMXMap = true;
        }
      } else {
        debugPrint('[SimpleEnhancedFarmGame] ℹ️ No vertex grid state found, saving TMX-based grid');
        await farmTileService.saveVertexGridState(farmId, mapVertexGrid);
        _isUsingFreshTMXMap = true;
      }
    } catch (e) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Error loading vertex grid state: $e');
      debugPrint('[SimpleEnhancedFarmGame] ℹ️ Using TMX-based terrain');
      try {
        await FarmTileService().saveVertexGridState(farmId, mapVertexGrid);
      } catch (saveError) {
        debugPrint('[SimpleEnhancedFarmGame] ❌ Error saving TMX-based vertex grid: $saveError');
      }
    }
    await _loadTerrainSignatureMap();
    _subscribeToVertexGridChanges();
    debugPrint('[SimpleEnhancedFarmGame] ✅ Vertex terrain system initialized');
  }

  Future<void> _loadTerrainSignatureMap() async {
    terrainSignatureMap = await TerrainParser.parseWangsetToSignatureMap('assets/ground.tsx', 1);
  }

  void _subscribeToVertexGridChanges() {
    try {
      final farmTileService = FarmTileService();
      final channel = farmTileService.subscribeToVertexGridChanges(farmId, (payload) {
        _handleVertexGridChange(payload);
      });
      channel.subscribe();
      debugPrint('[SimpleEnhancedFarmGame] 📡 Subscribed to real-time vertex grid changes');
    } catch (e) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Error subscribing to vertex grid changes: $e');
    }
  }

  void _handleVertexGridChange(PostgresChangePayload payload) {
    try {
      debugPrint('[SimpleEnhancedFarmGame] 📡 Processing vertex grid change from partner');
      if (payload.eventType == PostgresChangeEvent.insert || payload.eventType == PostgresChangeEvent.update) {
        final newRecord = payload.newRecord as Map<String, dynamic>?;
        if (newRecord != null) {
          final vertexGridData = newRecord['vertex_grid'] as List?;
          if (vertexGridData != null) {
            final newVertexGrid = List<List<int>>.from(vertexGridData.map((row) => List<int>.from(row)));
            if (newVertexGrid.length == SimpleEnhancedFarmGame.mapHeight + 1 && newVertexGrid[0].length == SimpleEnhancedFarmGame.mapWidth + 1) {
              debugPrint('[SimpleEnhancedFarmGame] 🔄 Updating vertex grid from partner changes');
              mapVertexGrid = newVertexGrid;
              _updateEntireMapVisual();
              debugPrint('[SimpleEnhancedFarmGame] ✅ Vertex grid updated from partner changes');
            } else {
              debugPrint('[SimpleEnhancedFarmGame] ⚠️ Partner vertex grid has wrong dimensions');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Error handling vertex grid change: $e');
    }
  }

  void _updateEntireMapVisual() {
    debugPrint('[SimpleEnhancedFarmGame] 🎨 Applying vertex deltas against TMX (no gating)');
    final baseline = _buildVertexGridFromTMX();
    int applied = 0;
    for (int y = 0; y < SimpleEnhancedFarmGame.mapHeight; y++) {
      for (int x = 0; x < SimpleEnhancedFarmGame.mapWidth; x++) {
        final tl0 = baseline[y][x];
        final tr0 = baseline[y][x + 1];
        final bl0 = baseline[y + 1][x];
        final br0 = baseline[y + 1][x + 1];
        final tl1 = mapVertexGrid[y][x];
        final tr1 = mapVertexGrid[y][x + 1];
        final bl1 = mapVertexGrid[y + 1][x];
        final br1 = mapVertexGrid[y + 1][x + 1];
        final differs = (tl0 != tl1) || (tr0 != tr1) || (bl0 != bl1) || (br0 != br1);
        if (differs) {
          final newGid = getGidForTile(x, y);
          _tileRenderer.setTileOverride(x, y, newGid);
          applied++;
        }
      }
    }
    debugPrint('[SimpleEnhancedFarmGame] ✅ Applied $applied vertex overrides (delta-based)');
  }

  // Build a baseline vertex grid derived from current TMX tile data without mutating state
  List<List<int>> _buildVertexGridFromTMX() {
    final height = SimpleEnhancedFarmGame.mapHeight;
    final width = SimpleEnhancedFarmGame.mapWidth;
    final grid = List.generate(
      height + 1,
      (_) => List.generate(width + 1, (_) => Terrain.GRASS.id),
    );
    if (_tileData != null) {
      for (int y = 0; y < _tileData!.length && y < height; y++) {
        for (int x = 0; x < _tileData![y].length && x < width; x++) {
          final gid = _tileData![y][x];
          int terrainId = Terrain.GRASS.id;
          if (gid > 0) {
            final terrainName = _autoTiler.gidToTerrain[gid];
            if (terrainName != null) {
              switch (terrainName.toLowerCase()) {
                case 'grass':
                  terrainId = Terrain.GRASS.id;
                  break;
                case 'dirt':
                  terrainId = Terrain.DIRT.id;
                  break;
                case 'tilled':
                case 'watered':
                  terrainId = Terrain.TILLED.id;
                  break;
                case 'pond':
                case 'water':
                case 'shallowwater':
                case 'deepwater':
                case 'abysswater':
                  terrainId = Terrain.POND.id;
                  break;
                case 'sand':
                  terrainId = Terrain.SAND.id;
                  break;
                case 'highground':
                case 'highgroundmid':
                  terrainId = Terrain.HIGH_GROUND.id;
                  break;
                default:
                  terrainId = Terrain.GRASS.id;
                  break;
              }
            } else {
              if (gid >= 181) {
                terrainId = Terrain.SAND.id;
              }
            }
          }
          grid[y][x] = terrainId;
          grid[y][x + 1] = terrainId;
          grid[y + 1][x] = terrainId;
          grid[y + 1][x + 1] = terrainId;
        }
      }
    }
    return grid;
  }

  void _initializeVertexGrid() {
    debugPrint('[SimpleEnhancedFarmGame] 🗺️ Initializing vertex grid from TMX data...');
    mapVertexGrid = List.generate(
      SimpleEnhancedFarmGame.mapHeight + 1,
      (_) => List.generate(SimpleEnhancedFarmGame.mapWidth + 1, (_) => Terrain.GRASS.id),
    );
    if (_tileData != null) {
      debugPrint('[SimpleEnhancedFarmGame] 📁 Converting TMX tile data to vertex grid...');
      for (int y = 0; y < _tileData!.length && y < SimpleEnhancedFarmGame.mapHeight; y++) {
        for (int x = 0; x < _tileData![y].length && x < SimpleEnhancedFarmGame.mapWidth; x++) {
          final gid = _tileData![y][x];
          int terrainId = Terrain.GRASS.id;
          if (gid > 0) {
            final terrainName = _autoTiler.gidToTerrain[gid];
            if (terrainName != null) {
              if (terrainName.toLowerCase().contains('water')) {
                debugPrint('[SimpleEnhancedFarmGame] 🌊 Found water terrain "$terrainName" for GID $gid, mapping to POND');
              }
              switch (terrainName.toLowerCase()) {
                case 'grass':
                  terrainId = Terrain.GRASS.id;
                  break;
                case 'dirt':
                terrainId = Terrain.DIRT.id;
                break;
              case 'tilled':
                terrainId = Terrain.TILLED.id;
                break;
                case 'watered':
                  terrainId = Terrain.TILLED.id;
                  break;
                case 'pond':
                case 'water':
                case 'shallowwater':
                case 'deepwater':
                case 'abysswater':
                  terrainId = Terrain.POND.id;
                  break;
                case 'sand':
                  terrainId = Terrain.SAND.id;
                  break;
                case 'highground':
                case 'highgroundmid':
                  terrainId = Terrain.HIGH_GROUND.id;
                  break;
                default:
                  terrainId = Terrain.GRASS.id;
                  debugPrint('[SimpleEnhancedFarmGame] ⚠️ Unknown terrain type "$terrainName" for GID $gid, defaulting to grass');
                  break;
              }
            } else {
              if (gid >= 181) {
                terrainId = Terrain.SAND.id;
                debugPrint('[SimpleEnhancedFarmGame] 🏖️ Unmapped beach tile GID $gid, defaulting to SAND terrain');
              }
            }
          }
          mapVertexGrid[y][x] = terrainId;
          mapVertexGrid[y][x + 1] = terrainId;
          mapVertexGrid[y + 1][x] = terrainId;
          mapVertexGrid[y + 1][x + 1] = terrainId;
        }
      }
      debugPrint('[SimpleEnhancedFarmGame] ✅ Vertex grid initialized from TMX data');
      // After initializing the vertex grid, rebuild pathfinding obstacles from terrain
      // Pathfinding grid is created later in onLoad; schedule obstacle build on next frame
      Future.microtask(() {
        if (isMounted) {
          try {
            _rebuildPathfindingObstaclesFromProperties();
          } catch (e) {
            debugPrint('[SimpleEnhancedFarmGame] ❌ Error rebuilding obstacles from properties: $e');
          }
        }
      });
    } else {
      debugPrint('[SimpleEnhancedFarmGame] ⚠️ No TMX tile data available, using default grass terrain');
    }
  }

  /// Public method to manually rebuild pathfinding obstacles (useful for testing)
  void rebuildPathfindingObstacles() {
    debugPrint('[SimpleEnhancedFarmGame] 🔄 Manually rebuilding pathfinding obstacles...');
    _rebuildPathfindingObstaclesFromProperties();
    debugPrint('[SimpleEnhancedFarmGame] ✅ Pathfinding obstacles rebuilt');
  }

  /// Check if player is stuck in an unwalkable area and allow escape
  /// Returns true if the player should be allowed to move through obstacles
  bool isPlayerStuckAndNeedsEscape(Vector2 playerPosition) {
    final tileSize = 32.0;
    final playerTileX = (playerPosition.x / tileSize).floor();
    final playerTileY = (playerPosition.y / tileSize).floor();
    
    // Check if player is currently on an obstacle
    if (!_pathfindingGrid.isObstacle(playerTileX, playerTileY)) {
      return false; // Player is not stuck
    }
    
    // Check if player is completely surrounded by obstacles (stuck)
    final directions = [
      Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0), // Cardinal directions
      Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1), // Diagonal directions
    ];
    
    bool hasEscapeRoute = false;
    for (final direction in directions) {
      final checkX = playerTileX + direction.x.toInt();
      final checkY = playerTileY + direction.y.toInt();
      
      if (checkX >= 0 && checkX < SimpleEnhancedFarmGame.mapWidth &&
          checkY >= 0 && checkY < SimpleEnhancedFarmGame.mapHeight &&
          !_pathfindingGrid.isObstacle(checkX, checkY)) {
        hasEscapeRoute = true;
        break;
      }
    }
    
    // If no escape route found, player is stuck and needs escape mode
    if (!hasEscapeRoute) {
      debugPrint('[SimpleEnhancedFarmGame] 🚨 Player is stuck at tile ($playerTileX, $playerTileY) - enabling escape mode');
      return true;
    }
    
    return false;
  }

  /// Get a safe escape position for a stuck player
  Vector2? getEscapePosition(Vector2 playerPosition) {
    final tileSize = 32.0;
    final playerTileX = (playerPosition.x / tileSize).floor();
    final playerTileY = (playerPosition.y / tileSize).floor();
    
    // Search in expanding circles for a walkable tile
    for (int radius = 1; radius <= 5; radius++) {
      for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
          // Only check tiles at the current radius (not inside)
          if (dx.abs() == radius || dy.abs() == radius) {
            final checkX = playerTileX + dx;
            final checkY = playerTileY + dy;
            
            if (checkX >= 0 && checkX < SimpleEnhancedFarmGame.mapWidth &&
                checkY >= 0 && checkY < SimpleEnhancedFarmGame.mapHeight &&
                !_pathfindingGrid.isObstacle(checkX, checkY)) {
              
              // Convert back to world coordinates
              final escapeX = (checkX * tileSize) + (tileSize / 2);
              final escapeY = (checkY * tileSize) + (tileSize / 2);
              
              debugPrint('[SimpleEnhancedFarmGame] 🚀 Found escape position at tile ($checkX, $checkY) -> world ($escapeX, $escapeY)');
              return Vector2(escapeX, escapeY);
            }
          }
        }
      }
    }
    
    debugPrint('[SimpleEnhancedFarmGame] ❌ No escape position found for stuck player');
    return null;
  }

  /// Helper method to get the tile coverage area for a decoration object
  /// Returns a list of (x, y) coordinates that the object occupies
  List<Point> _getDecorationObjectTileCoverage(int x, int y, int gid) {
    final List<Point> coverage = [];
    const int tileSize = 32; // Base tile size in pixels
    
    // Get object dimensions based on GID
    int objectWidth = tileSize;
    int objectHeight = tileSize;
    
    // Determine which tileset this decoration gid belongs to and get dimensions
    if (_housesFirstGid != null && gid >= _housesFirstGid! &&
        (_housesTileCount == 0 || gid < _housesFirstGid! + _housesTileCount)) {
      final tileId = gid - _housesFirstGid!;
      // Houses have various sizes: 84x97, 122x99, 51x56, 69x76, 53x63, 61x63
      switch (tileId) {
        case 0: // Farm house
          objectWidth = 100; objectHeight = 115;
          break;
        case 1: case 2: case 3: case 4: // Houses 1-4
          objectWidth = 84; objectHeight = 97;
          break;
        case 5: case 6: case 7: case 8: // Houses 5-8
          objectWidth = 122; objectHeight = 99;
          break;
        case 9: case 10: case 11: case 12: // Shops
          objectWidth = 51; objectHeight = 56;
          break;
        case 13: case 14: case 15: case 16: case 17: // Tents
          objectWidth = 69; objectHeight = 76;
          break;
        case 18: case 19: // Wells 1-2
          objectWidth = 53; objectHeight = 63;
          break;
        case 20: case 21: // Wells 3-4
          objectWidth = 61; objectHeight = 63;
          break;
      }
    } else if (_treesFirstGid != null && gid >= _treesFirstGid! &&
        (_treesTileCount == 0 || gid < _treesFirstGid! + _treesTileCount)) {
      final tileId = gid - _treesFirstGid!;
      if (tileId == 5) { // Tree1 - the only unwalkable tree
        objectWidth = 55; objectHeight = 54;
      }
    } else if (_woodenFirstGid != null && gid >= _woodenFirstGid! &&
        (_woodenTileCount == 0 || gid < _woodenFirstGid! + _woodenTileCount)) {
      final tileId = gid - _woodenFirstGid!;
      // Wooden objects: 25x28, 20x45, 58x45, 29x40, 29x24, 20x22
      switch (tileId) {
        case 0: objectWidth = 25; objectHeight = 28; break;
        case 1: objectWidth = 20; objectHeight = 45; break;
        case 2: objectWidth = 58; objectHeight = 45; break;
        case 3: objectWidth = 29; objectHeight = 40; break;
        case 4: objectWidth = 29; objectHeight = 24; break;
        case 5: objectWidth = 20; objectHeight = 22; break;
      }
    } else if (_beachObjectsFirstGid != null && gid >= _beachObjectsFirstGid! &&
        (_beachObjectsTileCount == 0 || gid < _beachObjectsFirstGid! + _beachObjectsTileCount)) {
      final tileId = gid - _beachObjectsFirstGid!;
      if (tileId <= 3) { // Beach umbrellas
        objectWidth = 30; objectHeight = 40;
      } else if (tileId <= 11) { // Beach chairs
        objectWidth = 16; objectHeight = 21;
      } else if (tileId == 12) { // Beach tree
        objectWidth = 38; objectHeight = 44;
      }
    }
    
    // Calculate how many tiles the object spans
    final tilesWide = (objectWidth / tileSize).ceil();
    final tilesHigh = (objectHeight / tileSize).ceil();
    
    // Add all tiles that the object covers
    for (int dy = 0; dy < tilesHigh; dy++) {
      for (int dx = 0; dx < tilesWide; dx++) {
        final tileX = x + dx;
        final tileY = y + dy;
        
                 // Check bounds
         if (tileX >= 0 && tileX < SimpleEnhancedFarmGame.mapWidth &&
             tileY >= 0 && tileY < SimpleEnhancedFarmGame.mapHeight) {
           coverage.add(Point(tileX.toDouble(), tileY.toDouble()));
         }
      }
    }
    
    return coverage;
  }

  /// Rebuild the obstacle grid using Tiled 'walkable' property per tile GID
  void _rebuildPathfindingObstaclesFromProperties() {
    // Ensure pathfinding grid exists (created in onLoad)
    // Guard: pathfinding grid must be initialized
    
    // First pass: handle ground layer obstacles (single tile)
    for (int y = 0; y < SimpleEnhancedFarmGame.mapHeight; y++) {
      for (int x = 0; x < SimpleEnhancedFarmGame.mapWidth; x++) {
        bool isObstacle = false;
        
        // Check ground layer for walkable property
        if (_groundTileData != null && y < _groundTileData!.length && x < _groundTileData![0].length) {
          final gid = _groundTileData![y][x];
          if (gid > 0) {
            // Determine which tileset this gid belongs to and fetch 'walkable' property
            Map<String, dynamic>? props;
            if (_groundFirstGid != null && gid >= _groundFirstGid! &&
                (_groundTileCount == 0 || gid < _groundFirstGid! + _groundTileCount)) {
              final tileId = gid - _groundFirstGid!; // 0-based id in ground.tsx
              props = _groundTilesetParser.getTileProperties()[tileId];
            } else if (_beachFirstGid != null && gid >= _beachFirstGid! &&
                (_beachTileCount == 0 || gid < _beachFirstGid! + _beachTileCount)) {
              final tileId = gid - _beachFirstGid!; // 0-based id in beach.tsx
              props = _beachTilesetParser.getTileProperties()[tileId];
            } else if (_stairsFirstGid != null && gid >= _stairsFirstGid! &&
                (_stairsTileCount == 0 || gid < _stairsFirstGid! + _stairsTileCount)) {
              final tileId = gid - _stairsFirstGid!; // 0-based id in stairs.tsx
              props = _stairsTilesetParser.getTileProperties()[tileId];
            }
            final walkable = props != null && props['walkable'] == true;
            isObstacle = !walkable;
          }
        }
        
        _pathfindingGrid.setObstacle(x, y, isObstacle);
      }
    }
    
    // Second pass: handle decoration layer obstacles (multi-tile objects)
    if (_decorationTileData != null) {
      for (int y = 0; y < _decorationTileData!.length; y++) {
        for (int x = 0; x < _decorationTileData![0].length; x++) {
          final decorationGid = _decorationTileData![y][x];
          if (decorationGid > 0) {
            // Determine which tileset this decoration gid belongs to and fetch 'walkable' property
            Map<String, dynamic>? decorationProps;
            if (_housesFirstGid != null && decorationGid >= _housesFirstGid! &&
                (_housesTileCount == 0 || decorationGid < _housesFirstGid! + _housesTileCount)) {
              final tileId = decorationGid - _housesFirstGid!; // 0-based id in houses.tsx
              decorationProps = _housesTilesetParser.getTileProperties()[tileId];
            } else if (_smokeFirstGid != null && decorationGid >= _smokeFirstGid! &&
                (_smokeTileCount == 0 || decorationGid < _smokeFirstGid! + _smokeTileCount)) {
              final tileId = decorationGid - _smokeFirstGid!; // 0-based id in smoke.tsx
              decorationProps = _smokeTilesetParser.getTileProperties()[tileId];
            } else if (_treesFirstGid != null && decorationGid >= _treesFirstGid! &&
                (_treesTileCount == 0 || decorationGid < _treesFirstGid! + _treesTileCount)) {
              final tileId = decorationGid - _treesFirstGid!; // 0-based id in trees.tsx
              decorationProps = _treesTilesetParser.getTileProperties()[tileId];
            } else if (_woodenFirstGid != null && decorationGid >= _woodenFirstGid! &&
                (_woodenTileCount == 0 || decorationGid < _woodenFirstGid! + _woodenTileCount)) {
              final tileId = decorationGid - _woodenFirstGid!; // 0-based id in wooden.tsx
              decorationProps = _woodenTilesetParser.getTileProperties()[tileId];
            } else if (_beachObjectsFirstGid != null && decorationGid >= _beachObjectsFirstGid! &&
                (_beachObjectsTileCount == 0 || decorationGid < _beachObjectsFirstGid! + _beachObjectsTileCount)) {
              final tileId = decorationGid - _beachObjectsFirstGid!; // 0-based id in beach_objects.tsx
              decorationProps = _beachObjectsTilesetParser.getTileProperties()[tileId];
            }
            
            // If decoration tile has walkable property and is unwalkable, set obstacles for entire object area
            if (decorationProps != null && decorationProps.containsKey('walkable')) {
              final decorationWalkable = decorationProps['walkable'] == true;
              if (!decorationWalkable) {
                // Get all tiles that this object covers
                final coverage = _getDecorationObjectTileCoverage(x, y, decorationGid);
                
                // DISABLED: Purple collision logic for decoration objects
                // Set obstacles for all covered tiles
                // for (final point in coverage) {
                //   _pathfindingGrid.setObstacle(point.x.toInt(), point.y.toInt(), true);
                // }
                
                debugPrint('[SimpleEnhancedFarmGame] DISABLED: Would have set decoration layer obstacle at ($x, $y): GID $decorationGid covers ${coverage.length} tiles');
              }
            }
          }
        }
      }
    }
    
    // Apply dynamic obstacles
    for (final b in bonfirePositions) {
      _pathfindingGrid.setObstacle(b.x, b.y, true);
    }
    for (final o in owlPositions) {
      _pathfindingGrid.setObstacle(o.x, o.y, true);
    }
    for (final c in chestPositions) {
      _pathfindingGrid.setObstacle(c.x, c.y, true);
    }
    for (final g in giftPositions) {
      _pathfindingGrid.setObstacle(g.x, g.y, true);
    }
    for (final s in seashellPositions) {
      _pathfindingGrid.setObstacle(s.x, s.y, true);
    }
    
    // Ensure spawn area is always walkable (player spawns at approximately tile 17,3)
    final spawnTileX = 17;
    final spawnTileY = 3;
    final spawnRadius = 2; // Clear a 5x5 area around spawn
    
    for (int dy = -spawnRadius; dy <= spawnRadius; dy++) {
      for (int dx = -spawnRadius; dx <= spawnRadius; dx++) {
        final x = spawnTileX + dx;
        final y = spawnTileY + dy;
        
        if (x >= 0 && x < SimpleEnhancedFarmGame.mapWidth &&
            y >= 0 && y < SimpleEnhancedFarmGame.mapHeight) {
          _pathfindingGrid.setObstacle(x, y, false);
        }
      }
    }
    
    debugPrint('[SimpleEnhancedFarmGame] 🚀 Ensured spawn area at ($spawnTileX, $spawnTileY) is walkable');
  }

  int getGidForTile(int x, int y) {
    final tl_id = mapVertexGrid[y][x];
    final tr_id = mapVertexGrid[y][x + 1];
    final bl_id = mapVertexGrid[y + 1][x];
    final br_id = mapVertexGrid[y + 1][x + 1];
    final signatureKey = "$tl_id,$tr_id,$bl_id,$br_id";
    final newGid = terrainSignatureMap[signatureKey];
    if (newGid != null) {
      return newGid;
    }

    // If any corner is TILLED, avoid majority fallback to prevent visual overexpansion
    if (tl_id == Terrain.TILLED.id || tr_id == Terrain.TILLED.id || bl_id == Terrain.TILLED.id || br_id == Terrain.TILLED.id) {
      return _tileData != null && y < _tileData!.length && x < _tileData![y].length
          ? _tileData![y][x]
          : -1;
    }

    // Fallback: prefer a uniform tile for the majority corner terrain to avoid cracks (non-tilled only)
    final Map<int, int> counts = {};
    for (final id in [tl_id, tr_id, bl_id, br_id]) {
      counts[id] = (counts[id] ?? 0) + 1;
    }

    int majorityId = tl_id;
    int majorityCount = 0;
    counts.forEach((id, count) {
      if (count > majorityCount) {
        majorityId = id;
        majorityCount = count;
      }
    });

    final uniformKey = "$majorityId,$majorityId,$majorityId,$majorityId";
    final uniformGid = terrainSignatureMap[uniformKey];
    if (uniformGid != null) {
      return uniformGid;
    }

    // Last resort: fall back to existing GID from TMX data if available
    return _tileData != null && y < _tileData!.length && x < _tileData![y].length
        ? _tileData![y][x]
        : -1;
  }

  void tillTileAtVertex(int tileX, int tileY) {
    debugPrint('[SimpleEnhancedFarmGame] 🚜 Attempting to till tile at ($tileX, $tileY) using vertex system');
    final int grassId = _grassTerrainId;
    final bool isGrass =
        mapVertexGrid[tileY][tileX] == grassId &&
        mapVertexGrid[tileY][tileX + 1] == grassId &&
        mapVertexGrid[tileY + 1][tileX] == grassId &&
        mapVertexGrid[tileY + 1][tileX + 1] == grassId;
    if (!isGrass) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Action failed: Tile at ($tileX, $tileY) is not a pure grass tile. Cannot till.');
      return;
    }
    
    // Remove any decorations on this tile before tilling
    _removeDecorationsAtGridPosition(tileX, tileY);
    
    debugPrint('[SimpleEnhancedFarmGame] ✅ Tile is grass. Converting to dirt.');
    _setTileTerrainAndPersist(tileX, tileY, _dirtTerrainId);
  }

  Future<void> waterTileAtVertex(int tileX, int tileY) async {
    debugPrint('[SimpleEnhancedFarmGame] 💧 Attempting to water tile at ($tileX, $tileY) using vertex system');
    final hasPlantedSeed = _checkForPlantedSeed(tileX, tileY);
    final int dirtId = _dirtTerrainId;
    final int tilledId = _tilledTerrainId;
    final tl_id = mapVertexGrid[tileY][tileX];
    final tr_id = mapVertexGrid[tileY][tileX + 1];
    final bl_id = mapVertexGrid[tileY + 1][tileX];
    final br_id = mapVertexGrid[tileY + 1][tileX + 1];
    final bool isAllDirt = tl_id == dirtId && tr_id == dirtId && bl_id == dirtId && br_id == dirtId;
    final bool isAlreadyTilled = tl_id == tilledId && tr_id == tilledId && bl_id == tilledId && br_id == tilledId;
    
    if (hasPlantedSeed) {
      final wateringSuccess = await _waterPlantedSeedAt(tileX, tileY);
      if (wateringSuccess && !isAlreadyTilled) {
        await _setTileTerrainAndPersist(tileX, tileY, _tilledTerrainId);
      } else if (!wateringSuccess) {
        debugPrint('[SimpleEnhancedFarmGame] ❌ Watering failed - no visual changes applied');
      }
      return;
    }
    
    if (isAlreadyTilled) return;
    if (!isAllDirt) return;
    
    try {
      final farmTileService = FarmTileService();
      await farmTileService.waterTile(farmId, tileX, tileY);
      await _setTileTerrainAndPersist(tileX, tileY, _tilledTerrainId);
    } catch (e) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Error watering tile: $e - no visual changes applied');
    }
  }

  void _updateSurroundingTilesVertex(int centerX, int centerY) {
    debugPrint('[SimpleEnhancedFarmGame] 🔄 Atomically updating surrounding tiles for ($centerX, $centerY) using vertex system');
    final Map<Point, int> updates = {};
    for (int y = centerY - 1; y <= centerY + 1; y++) {
      for (int x = centerX - 1; x <= centerX + 1; x++) {
        if (x >= 0 && x < SimpleEnhancedFarmGame.mapWidth && y >= 0 && y < SimpleEnhancedFarmGame.mapHeight) {
          final newGid = getGidForTile(x, y);
          updates[Point(x.toDouble(), y.toDouble())] = newGid;
          debugPrint('[SimpleEnhancedFarmGame] 📊 Tile ($x, $y): new GID = $newGid');
        }
      }
    }
    debugPrint('[SimpleEnhancedFarmGame] 📋 Calculated ${updates.length} tile updates');
    for (final entry in updates.entries) {
      final point = entry.key;
      final newGid = entry.value;
      debugPrint('[SimpleEnhancedFarmGame] 🎨 Applying override for tile (${point.x}, ${point.y}) -> GID $newGid');
      // Use non-destructive override so we do not mutate TMX ground data
      _tileRenderer.setTileOverride(point.x.toInt(), point.y.toInt(), newGid);
    }
    debugPrint('[SimpleEnhancedFarmGame] ✅ Visual update complete for surrounding tiles');
  }
  
  /// Remove decorations at a specific grid position and all adjacent tiles
  void _removeDecorationsAtGridPosition(int gridX, int gridY) {
    final tileSize = SimpleEnhancedFarmGame.tileSize;
    final decorationsToRemove = <DecorationObject>[];
    
    // Check the center tile and all 8 adjacent tiles (3x3 grid)
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        final checkX = gridX + dx;
        final checkY = gridY + dy;
        
        // Calculate tile boundaries for this position
        final tileLeft = checkX * tileSize;
        final tileTop = checkY * tileSize;
        final tileRight = tileLeft + tileSize;
        final tileBottom = tileTop + tileSize;
        
        // Find all decoration objects that overlap with this tile
        final decorations = this.descendants().whereType<DecorationObject>().toList();
        
        for (final decoration in decorations) {
          // Check if the decoration overlaps with the tile
          final decorationLeft = decoration.position.x;
          final decorationTop = decoration.position.y;
          final decorationRight = decorationLeft + decoration.size.x;
          final decorationBottom = decorationTop + decoration.size.y;
          
          // Check for overlap
          if (decorationLeft < tileRight && 
              decorationRight > tileLeft && 
              decorationTop < tileBottom && 
              decorationBottom > tileTop) {
            
            // Only add if not already in the list to avoid duplicates
            if (!decorationsToRemove.contains(decoration)) {
              debugPrint('[SimpleEnhancedFarmGame] 🗑️ Removing decoration ${decoration.objectType} at grid ($checkX, $checkY)');
              decorationsToRemove.add(decoration);
            }
          }
        }
      }
    }
    
    // Remove the decorations from the game world
    for (final decoration in decorationsToRemove) {
      decoration.removeFromParent();
    }
    
    if (decorationsToRemove.isNotEmpty) {
      debugPrint('[SimpleEnhancedFarmGame] ✅ Removed ${decorationsToRemove.length} decoration(s) from grid ($gridX, $gridY) and adjacent tiles');
    }
  }
}


