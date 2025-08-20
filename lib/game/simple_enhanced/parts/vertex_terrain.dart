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
    debugPrint('[SimpleEnhancedFarmGame] 🎨 Updating entire map visual from vertex grid');
    for (int y = 0; y < SimpleEnhancedFarmGame.mapHeight; y++) {
      for (int x = 0; x < SimpleEnhancedFarmGame.mapWidth; x++) {
        final newGid = getGidForTile(x, y);
        _updateTileVisual(_groundTileData!, x, y, newGid);
      }
    }
    debugPrint('[SimpleEnhancedFarmGame] ✅ Entire map visual updated');
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
    } else {
      debugPrint('[SimpleEnhancedFarmGame] ⚠️ No TMX tile data available, using default grass terrain');
    }
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
      debugPrint('[SimpleEnhancedFarmGame] 🎨 Updating visual for tile (${point.x}, ${point.y}) to GID $newGid');
              _updateTileVisual(_groundTileData!, point.x.toInt(), point.y.toInt(), newGid);
    }
    debugPrint('[SimpleEnhancedFarmGame] ✅ Visual update complete for surrounding tiles');
  }
}


