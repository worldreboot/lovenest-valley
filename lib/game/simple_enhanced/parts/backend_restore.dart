part of '../../simple_enhanced_farm_game.dart';

extension BackendRestoreExtension on SimpleEnhancedFarmGame {
  Future<void> _loadTilledTilesFromBackend() async {
    try {
      debugPrint('[SimpleEnhancedFarmGame] 📁 Loading tilled tiles from backend...');
      final farmTileService = FarmTileService();
      final vertexGridState = await farmTileService.loadVertexGridState(farmId);
      if (vertexGridState != null) {
        debugPrint('[SimpleEnhancedFarmGame] ✅ Found vertex grid state, using new system');
        _updateEntireMapVisual();
        return;
      }
      debugPrint('[SimpleEnhancedFarmGame] ℹ️ No vertex grid state found, using legacy farm_tiles system');
      final tilledTiles = await farmTileService.loadTilledTiles(farmId);
      debugPrint('[SimpleEnhancedFarmGame] ✅ Loaded ${tilledTiles.length} tilled tiles from backend');
      bool anyUpdated = false;
      for (final tile in tilledTiles) {
        final gridX = tile['x'] as int;
        final gridY = tile['y'] as int;
        debugPrint('[SimpleEnhancedFarmGame] 📁 Processing tilled tile from backend: ($gridX, $gridY)');
        if (gridX >= 0 && gridX < SimpleEnhancedFarmGame.mapWidth && gridY >= 0 && gridY < SimpleEnhancedFarmGame.mapHeight) {
          final dirtId = Terrain.DIRT.id;
          _writeTileVertices(gridX, gridY, dirtId);
          anyUpdated = true;
        } else {
          debugPrint('[SimpleEnhancedFarmGame] ⚠️ Tilled tile at ($gridX, $gridY) is out of bounds');
        }
      }
      if (anyUpdated) {
        await _persistVertexGridState();
        _updateEntireMapVisual();
      }
    } catch (e) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Error loading tilled tiles: $e');
    }
  }

  Future<void> _loadWateredTilesFromBackend() async {
    try {
      debugPrint('[SimpleEnhancedFarmGame] 📁 Loading watered tiles from backend...');
      final farmTileService = FarmTileService();
      final vertexGridState = await farmTileService.loadVertexGridState(farmId);
      if (vertexGridState != null) {
        debugPrint('[SimpleEnhancedFarmGame] ✅ Found vertex grid state, using new system');
        _updateEntireMapVisual();
        return;
      }
      debugPrint('[SimpleEnhancedFarmGame] ℹ️ No vertex grid state found, using legacy farm_tiles system');
      final wateredTiles = await farmTileService.loadWateredTiles(farmId);
      debugPrint('[SimpleEnhancedFarmGame] ✅ Loaded ${wateredTiles.length} watered tiles from backend');
      bool anyUpdated = false;
      for (final tile in wateredTiles) {
        final gridX = tile['x'] as int;
        final gridY = tile['y'] as int;
        debugPrint('[SimpleEnhancedFarmGame] 📁 Processing watered tile from backend: ($gridX, $gridY)');
        if (gridX >= 0 && gridX < SimpleEnhancedFarmGame.mapWidth && gridY >= 0 && gridY < SimpleEnhancedFarmGame.mapHeight) {
          final wateredId = Terrain.TILLED.id;
          _writeTileVertices(gridX, gridY, wateredId);
          anyUpdated = true;
        } else {
          debugPrint('[SimpleEnhancedFarmGame] ⚠️ Watered tile at ($gridX, $gridY) is out of bounds');
        }
      }
      if (anyUpdated) {
        await _persistVertexGridState();
        _updateEntireMapVisual();
      }
    } catch (e) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Error loading watered tiles: $e');
    }
  }

  Future<void> _loadPlacedGiftsFromBackend() async {
    try {
      final rows = await PlacedGiftService.listPlacedGifts(farmId);
      for (final r in rows) {
        final x = (r['grid_x'] as int);
        final y = (r['grid_y'] as int);
        final giftId = r['gift_id'] as String;
        final spriteUrl = r['sprite_url'] as String?;
        final description = r['description'] as String?;

        bool exists = false;
        for (final g in world.children.query<GiftObject>()) {
          final gx = (g.position.x / SimpleEnhancedFarmGame.tileSize).floor();
          final gy = (g.position.y / SimpleEnhancedFarmGame.tileSize).floor();
          if (gx == x && gy == y) { exists = true; break; }
        }
        if (exists) continue;

        final pos = Vector2(x * SimpleEnhancedFarmGame.tileSize, y * SimpleEnhancedFarmGame.tileSize);
        final size = Vector2.all(SimpleEnhancedFarmGame.tileSize * 1.5);
        final gift = GiftObject(
          giftId: giftId,
          spriteUrl: spriteUrl,
          description: description,
          position: pos,
          size: size,
          tileSize: SimpleEnhancedFarmGame.tileSize,
          isPlayerAdjacent: (gx, gy) => _toolActions.isAdjacent(player.position, gx, gy),
          onPickUp: (id) async {
            if (!_toolActions.isAdjacent(player.position, x, y)) return;
            await inventoryManager?.addItem(InventoryItem(id: giftId, name: 'Gift', iconPath: spriteUrl, quantity: 1));
            await PlacedGiftService.removeGift(farmId: farmId, gridX: x, gridY: y);
            for (final g in world.children.query<GiftObject>()) {
              final tx = (g.position.x / SimpleEnhancedFarmGame.tileSize).floor();
              final ty = (g.position.y / SimpleEnhancedFarmGame.tileSize).floor();
              if (tx == x && ty == y) { g.removeFromParent(); break; }
            }
          },
        );
        await world.add(gift);
      }
    } catch (e) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Error loading placed gifts: $e');
    }
  }
}


