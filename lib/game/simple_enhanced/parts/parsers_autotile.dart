part of '../../simple_enhanced_farm_game.dart';

extension ParsersAutotileExtension on SimpleEnhancedFarmGame {
  Future<void> _initializeCustomParsers() async {
    _groundTilesetParser = custom_parser.TilesetParser('assets/ground.tsx');
    await _groundTilesetParser.load();

    _beachTilesetParser = custom_parser.TilesetParser('assets/beach.tsx');
    await _beachTilesetParser.load();

    _mapParser = custom_parser.MapParser('assets/tiles/valley.tmx');
    await _mapParser.load();

    final groundWangTiles = _groundTilesetParser.getWangTiles();
    final beachWangTiles = _beachTilesetParser.getWangTiles();
    final allWangTiles = [...groundWangTiles, ...beachWangTiles];

    final gidToTerrain = <int, String>{};

    if (beachWangTiles.isNotEmpty) {
      final sandGids = [182, 185, 194, 197, 200, 212, 215];
      for (final gid in sandGids) {
        gidToTerrain[gid] = 'Sand';
      }
      final waterGids = [239, 227];
      for (final gid in waterGids) {
        gidToTerrain[gid] = 'Water';
      }
      for (var i = 181; i <= 220; i++) {
        gidToTerrain.putIfAbsent(i, () => 'Sand');
      }
    }

    if (groundWangTiles.isNotEmpty) {
      final wangColors = groundWangTiles.first.wangColors;
      for (final wangTile in groundWangTiles) {
        final uniqueTileId = wangTile.tileId;
        final wangIdValues = wangTile.getWangIdValues();
        final originalTileId = uniqueTileId % 1000;
        final gid = originalTileId + 1;
        if (gid >= 181) {
          continue;
        }
        final nonZeroColors = wangIdValues.where((c) => c > 0).toSet();
        if (nonZeroColors.length == 1) {
          final colorId = nonZeroColors.first;
          if (colorId > 0 && colorId <= wangColors.length) {
            final terrainName = wangColors[colorId - 1].name;
            gidToTerrain[gid] = terrainName;
          }
        } else if (nonZeroColors.length > 1) {
          final colorCounts = <int, int>{};
          for (final c in wangIdValues) {
            if (c > 0) colorCounts[c] = (colorCounts[c] ?? 0) + 1;
          }
          int maxCount = 0;
          int primary = 0;
          for (final e in colorCounts.entries) {
            if (e.value > maxCount) {
              maxCount = e.value;
              primary = e.key;
            }
          }
          if (primary > 0 && primary <= wangColors.length) {
            gidToTerrain[gid] = wangColors[primary - 1].name;
          }
        }
      }
      final explicit = <int, String>{
        1: 'Tilled',
        2: 'Pond',
        3: 'Tilled',
        4: 'Grass',
        5: 'HighGround',
        6: 'HighGroundMid',
      };
      for (final wangTile in groundWangTiles) {
        final originalTileId = wangTile.tileId % 1000;
        final gid = originalTileId + 1;
        if (!gidToTerrain.containsKey(gid)) {
          final nonZero = wangTile.getWangIdValues().where((c) => c > 0).toSet();
          if (nonZero.isNotEmpty) {
            final colorId = nonZero.first;
            final mapped = explicit[colorId];
            if (mapped != null) gidToTerrain[gid] = mapped;
          }
        }
      }
    }

    _autoTiler = custom_parser.AutoTiler(allWangTiles, gidToTerrain);

    final layers = _mapParser.getLayerData('Ground');
    if (layers != null) {
      // layer present
    }
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


