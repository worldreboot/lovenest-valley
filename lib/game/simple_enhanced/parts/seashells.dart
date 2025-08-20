part of '../../simple_enhanced_farm_game.dart';

extension SeashellsExtension on SimpleEnhancedFarmGame {
  bool _isSandTile(int x, int y) {
    if (_tileData == null) return false;
    if (x < 0 || y < 0 || y >= _tileData!.length || x >= _tileData![0].length) {
      return false;
    }
    final gid = _tileData![y][x];
    final terrainName = _autoTiler.gidToTerrain[gid];
    if (terrainName != null && terrainName.toLowerCase() == 'sand') {
      return true;
    }
    if (_useVertexTerrainSystem && _isValidTileIndex(x, y)) {
      final terrainId = mapVertexGrid[y][x];
      return terrainId == Terrain.SAND.id;
    }
    return false;
  }

  List<Point> _getValidSandPositions() {
    final sandPositions = <Point>[];
    if (_tileData == null) return sandPositions;
    for (int x = 32; x < 48; x++) {
      for (int y = 4; y < 24; y++) {
        if (_isSandTile(x, y)) {
          sandPositions.add(Point(x.toDouble(), y.toDouble()));
        }
      }
    }
    debugPrint('[SimpleEnhancedFarmGame] 🏖️ Found ${sandPositions.length} sand tiles for seashell spawning');
    return sandPositions;
  }

  void spawnSeashell(String id, String audioUrl, double x, double y, {bool highlightUnheard = false}) {
    final seashell = SeashellObject(
      position: Vector2(x * SimpleEnhancedFarmGame.tileSize, y * SimpleEnhancedFarmGame.tileSize),
      size: Vector2(SimpleEnhancedFarmGame.tileSize * 1.5, SimpleEnhancedFarmGame.tileSize * 1.5),
      audioUrl: audioUrl,
      id: id,
      highlightUnheard: highlightUnheard,
      onPlayAudio: () {
        debugPrint('[SimpleEnhancedFarmGame] 🐚 Playing seashell audio: $audioUrl');
      },
    );
    world.add(seashell);
    debugPrint('[SimpleEnhancedFarmGame] 🐚 Seashell spawned at position ($x, $y)');
  }

  Future<void> loadSeashells() async {
    try {
      debugPrint('[SimpleEnhancedFarmGame] 🐚 Loading seashells from database...');
      final seashells = await SeashellService.fetchRecentSeashells(limit: 5);
      if (seashells.isEmpty) {
        debugPrint('[SimpleEnhancedFarmGame] 🐚 No seashells found for this couple');
        return;
      }
      debugPrint('[SimpleEnhancedFarmGame] 🐚 Found ${seashells.length} seashells to load');
      debugPrint('[SimpleEnhancedFarmGame] 🐚 Generating positions for ${seashells.length} seashells...');
      debugPrint('[SimpleEnhancedFarmGame] 🐚 Looking for actual sand tiles in beach area...');
      final validSandPositions = _getValidSandPositions();
      if (validSandPositions.isEmpty) {
        debugPrint('[SimpleEnhancedFarmGame] ⚠️ No sand tiles found! Seashells cannot be spawned.');
        return;
      }
      final random = math.Random();
      final positions = <Point>[];
      final usedPositions = <Point>{};
      for (int i = 0; i < seashells.length && i < validSandPositions.length; i++) {
        Point position;
        int attempts = 0;
        do {
          position = validSandPositions[random.nextInt(validSandPositions.length)];
          attempts++;
        } while (usedPositions.contains(position) && attempts < 50);
        positions.add(position);
        usedPositions.add(position);
      }
      debugPrint('[SimpleEnhancedFarmGame] 🐚 Generated ${positions.length} positions on sand tiles');
      for (int i = 0; i < seashells.length && i < positions.length; i++) {
        final seashell = seashells[i];
        final position = positions[i];
        final currentUserId = SupabaseConfig.currentUserId;
        spawnSeashell(
          seashell.id,
          seashell.audioUrl,
          position.x,
          position.y,
          highlightUnheard: (seashell.userId != currentUserId) && !seashell.heardByCurrentUser,
        );
        debugPrint('[SimpleEnhancedFarmGame] 🐚 Spawned seashell ${seashell.id} at beach position (${position.x}, ${position.y})');
      }
      debugPrint('[SimpleEnhancedFarmGame] 🐚 Successfully loaded ${seashells.length} seashells on the beach');
    } catch (e) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Error loading seashells: $e');
    }
  }
}


