part of '../../simple_enhanced_farm_game.dart';

extension AutotileHelpersExtension on SimpleEnhancedFarmGame {
  Future<void> _applyAutoTilingToSurroundings(int centerX, int centerY) async {
    if (_groundTileData == null) return;
    final changes = <Point, int>{};
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        final x = centerX + dx;
        final y = centerY + dy;
        if (x >= 0 && x < _groundTileData![0].length && y >= 0 && y < _groundTileData!.length) {
          final oldGid = _groundTileData![y][x];
          final newGid = _calculateAutoTileGid(x, y);
          if (oldGid != newGid) {
            changes[Point(x.toDouble(), y.toDouble())] = newGid;
          }
        }
      }
    }
    final cornerPositions = [
      Point(centerX - 1, centerY - 1),
      Point(centerX + 1, centerY - 1),
      Point(centerX - 1, centerY + 1),
      Point(centerX + 1, centerY + 1),
    ];
    final edgePositions = [
      Point(centerX.toDouble(), (centerY - 1).toDouble()),
      Point((centerX - 1).toDouble(), centerY.toDouble()),
      Point((centerX + 1).toDouble(), centerY.toDouble()),
      Point(centerX.toDouble(), (centerY + 1).toDouble()),
    ];
    for (final position in cornerPositions) {
      if (changes.containsKey(position)) {
        final newGid = changes[position]!;
        _groundTileData![position.y.toInt()][position.x.toInt()] = newGid;
        await _updateTileVisual(_groundTileData!, position.x.toInt(), position.y.toInt(), newGid);
      }
    }
    for (final position in edgePositions) {
      if (changes.containsKey(position)) {
        final newGid = changes[position]!;
        _groundTileData![position.y.toInt()][position.x.toInt()] = newGid;
        await _updateTileVisual(_groundTileData!, position.x.toInt(), position.y.toInt(), newGid);
      }
    }
  }

  int _calculateAutoTileGid(int x, int y) {
    if (_groundTileData == null) return 0;
    final surroundingTiles = <List<int>>[];
    for (int dy = -1; dy <= 1; dy++) {
      final row = <int>[];
      for (int dx = -1; dx <= 1; dx++) {
        final checkX = x + dx;
        final checkY = y + dy;
        if (checkX >= 0 && checkX < _groundTileData![0].length && checkY >= 0 && checkY < _groundTileData!.length) {
          row.add(_groundTileData![checkY][checkX]);
        } else {
          row.add(0);
        }
      }
      surroundingTiles.add(row);
    }
    final appropriateTileId = _autoTiler.getTileForSurroundings(surroundingTiles);
    if (appropriateTileId >= 0) {
      return appropriateTileId + 1;
    }
    return _groundTileData![y][x];
  }
}


