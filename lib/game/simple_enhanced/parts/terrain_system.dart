part of '../../simple_enhanced_farm_game.dart';

abstract class TerrainSystem {
  Future<void> till(int x, int y);
  Future<void> water(int x, int y);
  bool isTillable(int x, int y);
  bool isWaterable(int x, int y);
  int getGidAt(int x, int y);
  bool isGrass(int x, int y);
}

class VertexTerrainSystem implements TerrainSystem {
  final SimpleEnhancedFarmGame game;
  VertexTerrainSystem(this.game);

  @override
  Future<void> till(int x, int y) async {
    game.tillTileAtVertex(x, y);
  }

  @override
  Future<void> water(int x, int y) async {
    await game.waterTileAtVertex(x, y);
  }

  @override
  bool isTillable(int x, int y) {
    if (!(x >= 0 && x < SimpleEnhancedFarmGame.mapWidth && y >= 0 && y < SimpleEnhancedFarmGame.mapHeight)) {
      return false;
    }
    final grassId = game._grassTerrainId;
    return game.mapVertexGrid[y][x] == grassId &&
        game.mapVertexGrid[y][x + 1] == grassId &&
        game.mapVertexGrid[y + 1][x] == grassId &&
        game.mapVertexGrid[y + 1][x + 1] == grassId;
  }

  @override
  bool isWaterable(int x, int y) {
    if (!(x >= 0 && x < SimpleEnhancedFarmGame.mapWidth && y >= 0 && y < SimpleEnhancedFarmGame.mapHeight)) {
      return false;
    }
    final dirtId = game._dirtTerrainId;
    final tilledId = game._tilledTerrainId;
    final tl = game.mapVertexGrid[y][x];
    final tr = game.mapVertexGrid[y][x + 1];
    final bl = game.mapVertexGrid[y + 1][x];
    final br = game.mapVertexGrid[y + 1][x + 1];
    final hasPlantedSeed = game._checkForPlantedSeed(x, y);
    final isAlreadyTilled = tl == tilledId && tr == tilledId && bl == tilledId && br == tilledId;
    // Require the entire tile to be dirt (all 4 vertices) to be waterable,
    // unless a seed is planted (seed-specific logic may allow watering).
    final isAllDirt = tl == dirtId && tr == dirtId && bl == dirtId && br == dirtId;
    if (hasPlantedSeed) return true;
    return isAllDirt && !isAlreadyTilled;
  }

  @override
  int getGidAt(int x, int y) {
    return game.getGidForTile(x, y);
  }

  @override
  bool isGrass(int x, int y) {
    if (!(x >= 0 && x < SimpleEnhancedFarmGame.mapWidth && y >= 0 && y < SimpleEnhancedFarmGame.mapHeight)) {
      return false;
    }
    final grassId = game._grassTerrainId;
    return game.mapVertexGrid[y][x] == grassId &&
        game.mapVertexGrid[y][x + 1] == grassId &&
        game.mapVertexGrid[y + 1][x] == grassId &&
        game.mapVertexGrid[y + 1][x + 1] == grassId;
  }
}

class AutoTilingTerrainSystem implements TerrainSystem {
  final SimpleEnhancedFarmGame game;
  AutoTilingTerrainSystem(this.game);

  @override
  Future<void> till(int x, int y) async {
    const tilledTileGid = 28;
    final tileData = game._groundTileData;
    if (tileData != null && x >= 0 && x < tileData[0].length && y >= 0 && y < tileData.length) {
      tileData[y][x] = tilledTileGid;
      await game._updateTileVisual(tileData, x, y, tilledTileGid);
      await game._applyAutoTilingToSurroundings(x, y);
      debugPrint('[SimpleEnhancedFarmGame] ✅ Tile tilled (auto-tiling) at ($x, $y)');
    } else {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Failed to till tile (auto-tiling) - out of bounds');
    }
  }

  @override
  Future<void> water(int x, int y) async {
    final tileData = game._groundTileData;
    if (tileData == null) return;
    if (!(x >= 0 && x < tileData[0].length && y >= 0 && y < tileData.length)) return;

    final currentGid = tileData[y][x];
    final currentTileId = currentGid - 1;
    bool isDirtTile = false;
    List<int>? currentWangId;

    for (final wangTile in game._autoTiler.wangTiles) {
      final originalTileId = wangTile.tileId % 1000;
      if (originalTileId == currentTileId) {
        currentWangId = wangTile.getWangIdValues();
        if (currentWangId.contains(1)) {
          isDirtTile = true;
        }
        break;
      }
    }

    if (isDirtTile) {
      // Transform dirt to tilled soil using autotiling
      await game._applyTilledWangId(x, y);
      debugPrint('[SimpleEnhancedFarmGame] 💧 Watered (auto-tiling): transformed dirt to tilled at ($x, $y)');
    }
  }

  @override
  bool isTillable(int x, int y) {
    final tileData = game._groundTileData;
    if (tileData == null) return false;
    if (!(x >= 0 && x < tileData[0].length && y >= 0 && y < tileData.length)) return false;
    final gid = tileData[y][x];
    final properties = game.getTilePropertiesAt(x, y);
    if (properties != null && properties.containsKey('isTillable')) {
      return properties['isTillable'] == true;
    }
    // Common grass GIDs
    if (gid >= 24 && gid <= 30) return true;
    return false;
  }

  @override
  bool isWaterable(int x, int y) {
    final tileData = game._groundTileData;
    if (tileData == null) return false;
    if (!(x >= 0 && x < tileData[0].length && y >= 0 && y < tileData.length)) return false;
    final gid = tileData[y][x];
    final properties = game.getTilePropertiesAt(x, y);
    // Tilled soil range
    if (gid >= 27 && gid <= 35) return true;
    // Dirt tiles via wang color 1
    final tileId = gid - 1;
    for (final wangTile in game._autoTiler.wangTiles) {
      final originalTileId = wangTile.tileId % 1000;
      if (originalTileId == tileId) {
        final wangId = wangTile.getWangIdValues();
        if (wangId.contains(1)) return true;
        break;
      }
    }
    if (properties != null && properties['isTillable'] == true) return true;
    if (properties != null && properties['isWaterable'] == true) return true;
    return false;
  }

  @override
  int getGidAt(int x, int y) {
    final tileData = game._groundTileData;
    if (tileData != null && x >= 0 && x < tileData[0].length && y >= 0 && y < tileData.length) {
      return tileData[y][x];
    }
    return 0;
  }

  @override
  bool isGrass(int x, int y) {
    final tileData = game._groundTileData;
    if (tileData == null) return false;
    if (!(x >= 0 && x < tileData[0].length && y >= 0 && y < tileData.length)) return false;
    final gid = tileData[y][x];
    // Common grass range (matches tillable check range here)
    if (gid >= 24 && gid <= 30) return true;
    final props = game.getTilePropertiesAt(x, y);
    if (props != null && props['isGrass'] == true) return true;
    return false;
  }
}


