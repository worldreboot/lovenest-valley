part of '../../simple_enhanced_farm_game.dart';

extension RenderingExtension on SimpleEnhancedFarmGame {
  Future<void> _initializeTileRendering() async {
    // TileRenderer handles internal sprite sheets
  }

  Future<void> _renderTilemap() async {
    if (_groundTileData == null) {
      return;
    }
    await _tileRenderer.renderTilemap(_groundTileData!, _decorationTileData);
  }

  Future<void> _updateTileVisual(List<List<int>> tileData, int x, int y, int newGid) async {
    await _tileRenderer.updateTileVisual(tileData, x, y, newGid);
  }
}


