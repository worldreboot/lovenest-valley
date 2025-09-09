part of '../../simple_enhanced_farm_game.dart';

extension ParsersAutotileExtension on SimpleEnhancedFarmGame {
  Future<void> _initializeCustomParsers() async {
    // Load all tilesets referenced in the Tiled map
    _groundTilesetParser = custom_parser.TilesetParser('assets/ground.tsx');
    await _groundTilesetParser.load();

    _beachTilesetParser = custom_parser.TilesetParser('assets/beach.tsx');
    await _beachTilesetParser.load();

    // Load additional tilesets that are referenced in valley.tmx
    _stairsTilesetParser = custom_parser.TilesetParser('assets/stairs.tsx');
    await _stairsTilesetParser.load();

    _housesTilesetParser = custom_parser.TilesetParser('assets/houses.tsx');
    await _housesTilesetParser.load();

    _smokeTilesetParser = custom_parser.TilesetParser('assets/smoke.tsx');
    await _smokeTilesetParser.load();

    _treesTilesetParser = custom_parser.TilesetParser('assets/trees.tsx');
    await _treesTilesetParser.load();

    _woodenTilesetParser = custom_parser.TilesetParser('assets/wooden.tsx');
    await _woodenTilesetParser.load();

    _beachObjectsTilesetParser = custom_parser.TilesetParser('assets/beach_objects.tsx');
    await _beachObjectsTilesetParser.load();

    _mapParser = custom_parser.MapParser('assets/tiles/valley.tmx');
    await _mapParser.load();

    // Capture firstgid and tileset sizes for property-based lookups
    final tilesets = _mapParser.getTilesets();
    for (final ts in tilesets) {
      final src = ts.source.toLowerCase();
      if (src.endsWith('ground.tsx') || src.endsWith('assets/ground.tsx')) {
        _groundFirstGid = ts.firstGid;
        _groundTileCount = _groundTilesetParser.getTilesetInfo()['tilecount'] ?? 0;
        debugPrint('[SimpleEnhancedFarmGame] 📦 Loaded ground.tsx (firstgid: ${ts.firstGid}, tiles: $_groundTileCount)');
      } else if (src.endsWith('beach.tsx') || src.endsWith('assets/beach.tsx')) {
        _beachFirstGid = ts.firstGid;
        _beachTileCount = _beachTilesetParser.getTilesetInfo()['tilecount'] ?? 0;
        debugPrint('[SimpleEnhancedFarmGame] 📦 Loaded beach.tsx (firstgid: ${ts.firstGid}, tiles: $_beachTileCount)');
      } else if (src.endsWith('stairs.tsx') || src.endsWith('assets/stairs.tsx')) {
        _stairsFirstGid = ts.firstGid;
        _stairsTileCount = _stairsTilesetParser.getTilesetInfo()['tilecount'] ?? 0;
        debugPrint('[SimpleEnhancedFarmGame] 📦 Loaded stairs.tsx (firstgid: ${ts.firstGid}, tiles: $_stairsTileCount)');
      } else if (src.endsWith('houses.tsx') || src.endsWith('assets/houses.tsx')) {
        _housesFirstGid = ts.firstGid;
        _housesTileCount = _housesTilesetParser.getTilesetInfo()['tilecount'] ?? 0;
        debugPrint('[SimpleEnhancedFarmGame] 📦 Loaded houses.tsx (firstgid: ${ts.firstGid}, tiles: $_housesTileCount)');
      } else if (src.endsWith('smoke.tsx') || src.endsWith('assets/smoke.tsx')) {
        _smokeFirstGid = ts.firstGid;
        _smokeTileCount = _smokeTilesetParser.getTilesetInfo()['tilecount'] ?? 0;
        debugPrint('[SimpleEnhancedFarmGame] 📦 Loaded smoke.tsx (firstgid: ${ts.firstGid}, tiles: $_smokeTileCount)');
      } else if (src.endsWith('trees.tsx') || src.endsWith('assets/trees.tsx')) {
        _treesFirstGid = ts.firstGid;
        _treesTileCount = _treesTilesetParser.getTilesetInfo()['tilecount'] ?? 0;
        debugPrint('[SimpleEnhancedFarmGame] 📦 Loaded trees.tsx (firstgid: ${ts.firstGid}, tiles: $_treesTileCount)');
      } else if (src.endsWith('wooden.tsx') || src.endsWith('assets/wooden.tsx')) {
        _woodenFirstGid = ts.firstGid;
        _woodenTileCount = _woodenTilesetParser.getTilesetInfo()['tilecount'] ?? 0;
        debugPrint('[SimpleEnhancedFarmGame] 📦 Loaded wooden.tsx (firstgid: ${ts.firstGid}, tiles: $_woodenTileCount)');
      } else if (src.endsWith('beach_objects.tsx') || src.endsWith('assets/beach_objects.tsx')) {
        _beachObjectsFirstGid = ts.firstGid;
        _beachObjectsTileCount = _beachObjectsTilesetParser.getTilesetInfo()['tilecount'] ?? 0;
        debugPrint('[SimpleEnhancedFarmGame] 📦 Loaded beach_objects.tsx (firstgid: ${ts.firstGid}, tiles: $_beachObjectsTileCount)');
      }
    }

    // Get Wang tiles from all tilesets for auto-tiling
    final groundWangTiles = _groundTilesetParser.getWangTiles();
    final beachWangTiles = _beachTilesetParser.getWangTiles();
    final stairsWangTiles = _stairsTilesetParser.getWangTiles();
    final housesWangTiles = _housesTilesetParser.getWangTiles();
    final smokeWangTiles = _smokeTilesetParser.getWangTiles();
    final treesWangTiles = _treesTilesetParser.getWangTiles();
    final woodenWangTiles = _woodenTilesetParser.getWangTiles();
    final beachObjectsWangTiles = _beachObjectsTilesetParser.getWangTiles();
    
    final allWangTiles = [
      ...groundWangTiles, 
      ...beachWangTiles, 
      ...stairsWangTiles,
      ...housesWangTiles,
      ...smokeWangTiles,
      ...treesWangTiles,
      ...woodenWangTiles,
      ...beachObjectsWangTiles,
    ];

    // Use captured firstgid values
    final int? groundFirstGid = _groundFirstGid;
    final int? beachFirstGid = _beachFirstGid;

    final gidToTerrain = <int, String>{};

    // Helper to map wang tiles to terrain names using wang colors, with proper gid offset
    void mapTiles(List<custom_parser.WangTile> wangTiles, int? firstGid) {
      if (wangTiles.isEmpty || firstGid == null) return;
      final wangColors = wangTiles.first.wangColors;
      for (final wangTile in wangTiles) {
        final originalTileId = wangTile.tileId % 1000;
        final gid = firstGid + originalTileId;
        final values = wangTile.getWangIdValues();
        final nonZero = values.where((c) => c > 0).toList();
        if (nonZero.isEmpty) continue;
        int chosenColor;
        if (nonZero.toSet().length == 1) {
          chosenColor = nonZero.first;
        } else {
          final counts = <int, int>{};
          for (final c in nonZero) {
            counts[c] = (counts[c] ?? 0) + 1;
          }
          chosenColor = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        }
        if (chosenColor > 0 && chosenColor <= wangColors.length) {
          gidToTerrain[gid] = wangColors[chosenColor - 1].name;
        }
      }
    }

    // Build mappings for both tilesets using their correct gid offsets
    mapTiles(groundWangTiles, groundFirstGid);
    mapTiles(beachWangTiles, beachFirstGid);

    _autoTiler = custom_parser.AutoTiler(allWangTiles, gidToTerrain);

    final layers = _mapParser.getLayerData('Ground');
    if (layers != null) {
      // layer present
    }
    
    debugPrint('[SimpleEnhancedFarmGame] ✅ All 8 tilesets loaded successfully');
  }

  Future<void> _initializeTileData() async {
    // Load ground layer
    final groundLayerData = _mapParser.getLayerData('Ground');
    _groundTileData = groundLayerData?.data;
    
    // Load decoration layer
    final decorationLayerData = _mapParser.getLayerData('Decorations');
    _decorationTileData = decorationLayerData?.data;
    
    if (_groundTileData != null) {
      final tileCounts = <int, int>{};
      for (int y = 0; y < _groundTileData!.length; y++) {
        for (int x = 0; x < _groundTileData![0].length; x++) {
          final gidValue = _groundTileData![y][x];
          tileCounts[gidValue] = (tileCounts[gidValue] ?? 0) + 1;
        }
      }
      debugPrint('[SimpleEnhancedFarmGame] 📊 Ground layer loaded with ${tileCounts.length} unique tile types');
    }
    
    if (_decorationTileData != null) {
      final decorationCounts = <int, int>{};
      for (int y = 0; y < _decorationTileData!.length; y++) {
        for (int x = 0; x < _decorationTileData![0].length; x++) {
          final gidValue = _decorationTileData![y][x];
          if (gidValue > 0) { // Only count non-empty decoration tiles
            decorationCounts[gidValue] = (decorationCounts[gidValue] ?? 0) + 1;
          }
        }
      }
      debugPrint('[SimpleEnhancedFarmGame] 🎨 Decoration layer loaded with ${decorationCounts.length} unique decoration types');
    }
  }

}


