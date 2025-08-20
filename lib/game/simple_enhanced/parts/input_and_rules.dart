part of '../../simple_enhanced_farm_game.dart';

extension InputAndRulesExtension on SimpleEnhancedFarmGame {
  Future<void> handleTapDown(TapDownEvent event) async {
    if (_isHoeAnimationPlaying || _isWateringCanAnimationPlaying) {
      return;
    }
    final screenPos = event.canvasPosition;
    final worldPosition = coord.screenToWorld(
      screenPos,
      camera.viewfinder.position,
      camera.viewfinder.zoom,
      size,
    );
    final grid = coord.worldToGrid(worldPosition, SimpleEnhancedFarmGame.tileSize);
    final gridX = grid.x;
    final gridY = grid.y;
    if (!_isValidTileIndex(gridX, gridY)) {
      return;
    }
    if (_toolActions.isAdjacent(player.position, gridX, gridY) && _currentHoeState && _isTileTillable(gridX, gridY)) {
      _playHoeAnimation(gridX, gridY);
    } else if (_toolActions.isAdjacent(player.position, gridX, gridY) && _currentHoeState && !_isTileTillable(gridX, gridY)) {
    } else if (_toolActions.isAdjacent(player.position, gridX, gridY) && !_currentHoeState && !_currentWateringCanState && inventoryManager?.selectedItem == null) {
    } else if (_toolActions.isAdjacent(player.position, gridX, gridY) && _currentWateringCanState) {
      // Only allow watering if there's a waterable seed on the tile
      final plant = _getPlantedSeedAt(gridX, gridY);
      if (plant != null && plant.growthStage != 'fully_grown') {
        debugPrint('[SimpleEnhancedFarmGame] 🌱 Checking if can water seed at ($gridX, $gridY)');
        // Check if watering will succeed before playing animation
        if (await _canWaterTile(gridX, gridY)) {
          _playWateringCanAnimation(gridX, gridY);
        } else {
          debugPrint('[SimpleEnhancedFarmGame] ❌ Cannot water seed at ($gridX, $gridY) - no animation played');
        }
        return;
      } else if (plant == null) {
        debugPrint('[SimpleEnhancedFarmGame] ❌ No seed found at ($gridX, $gridY) - cannot water empty tile');
      } else if (plant.growthStage == 'fully_grown') {
        debugPrint('[SimpleEnhancedFarmGame] ❌ Seed at ($gridX, $gridY) is already fully grown - cannot water');
      }
    } else if (_toolActions.isAdjacent(player.position, gridX, gridY) && !_currentHoeState && !_currentWateringCanState && inventoryManager?.selectedItem == null) {
    } else if (_toolActions.isAdjacent(player.position, gridX, gridY) && !_currentHoeState && !_currentWateringCanState && inventoryManager?.selectedItem != null) {
      final selectedItem = inventoryManager!.selectedItem;
      if (selectedItem != null) {
        // Place gift if selected item is a gift
        if (selectedItem.id.startsWith('gift_')) {
          _placeGiftAt(gridX, gridY, selectedItem);
          return;
        }
        // Place chest if selected item is a chest
        if (selectedItem.id == 'chest') {
          _placeChestAt(gridX, gridY);
          return;
        }
        // Otherwise, plant if tile is tilled
        if (_isTileTilled(gridX, gridY)) {
          onPlantSeed?.call(gridX, gridY, selectedItem);
          return;
        }
      }
    } else {
      if (_isWithinOwlBounds(worldPosition)) {
        return;
      }
      player.moveTowards(worldPosition);
    }
  }

  Future<void> _placeChestAt(int gridX, int gridY) async {
    // Must be adjacent
    if (!_toolActions.isAdjacent(player.position, gridX, gridY)) return;

    // Must be grass tile
    final isGrass = _terrainSystem.isGrass(gridX, gridY);
    if (!isGrass) return;

    // Prevent double placement on same tile
    for (final c in world.children.query<ChestObject>()) {
      final cx = (c.position.x / SimpleEnhancedFarmGame.tileSize).floor();
      final cy = (c.position.y / SimpleEnhancedFarmGame.tileSize).floor();
      if (cx == gridX && cy == gridY) return;
    }

    // Try to persist chest to backend - ensure a valid couple exists
    ChestStorage storage;
    try {
      final coupleRepo = GardenRepository();
      var couple = await coupleRepo.getUserCouple();
      final userId = Supabase.instance.client.auth.currentUser?.id;

      // If no couple exists yet but user is signed in, create a self-couple (user paired with self)
      if (couple == null && userId != null) {
        try {
          couple = await coupleRepo.createCouple(userId);
          debugPrint('[SimpleEnhancedFarmGame] ✅ Created self-couple for user $userId');
        } catch (e) {
          debugPrint('[SimpleEnhancedFarmGame] ❌ Failed to create self-couple: $e');
        }
      }

      if (couple != null) {
        // Persist chest under a valid couple ID (FK satisfied)
        storage = await ChestStorageService().createChest(
          coupleId: couple.id,
          position: Position(gridX.toDouble(), gridY.toDouble()),
          name: 'Chest',
          maxCapacity: 20,
        );
      } else {
        // Fallback to local-only if still no couple/user context
        storage = ChestStorage(
          id: 'chest_${DateTime.now().millisecondsSinceEpoch}',
          coupleId: 'local',
          position: Position(gridX.toDouble(), gridY.toDouble()),
          items: const [],
          name: 'Chest',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          version: 1,
          syncStatus: 'local_only',
        );
      }
    } catch (e) {
      // If anything fails, create local-only chest
      storage = ChestStorage(
        id: 'chest_${DateTime.now().millisecondsSinceEpoch}',
        coupleId: Supabase.instance.client.auth.currentUser?.id ?? 'local',
        position: Position(gridX.toDouble(), gridY.toDouble()),
        items: const [],
        name: 'Chest',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        version: 1,
        syncStatus: 'local_only',
      );
    }

    final pos = Vector2(gridX * SimpleEnhancedFarmGame.tileSize, gridY * SimpleEnhancedFarmGame.tileSize);
    final chest = ChestObject(
      position: pos,
      size: Vector2.all(SimpleEnhancedFarmGame.tileSize),
      examineText: 'Open Chest',
      onExamineRequested: onExamine,
      chestStorage: storage,
    );

    await world.add(chest);
    chestPositions.add(GridPos(gridX, gridY));
    _pathfindingGrid.setObstacle(gridX, gridY, true);

    // Consume chest from inventory
    inventoryManager?.removeItem(inventoryManager!.selectedSlotIndex);
  }

  Future<void> _placeGiftAt(int gridX, int gridY, InventoryItem giftItem) async {
    // Avoid placing on occupied seed tile
    final existingPlant = _getPlantedSeedAt(gridX, gridY);
    if (existingPlant != null) return;

    // Prevent multiple gifts on same tile
    for (final gift in world.children.query<GiftObject>()) {
      final gx = (gift.position.x / SimpleEnhancedFarmGame.tileSize).floor();
      final gy = (gift.position.y / SimpleEnhancedFarmGame.tileSize).floor();
      if (gx == gridX && gy == gridY) return;
    }

    final pos = Vector2(gridX * SimpleEnhancedFarmGame.tileSize, gridY * SimpleEnhancedFarmGame.tileSize);
    final size = Vector2.all(SimpleEnhancedFarmGame.tileSize * 1.5);

    final gift = GiftObject(
      giftId: giftItem.id,
      spriteUrl: giftItem.iconPath,
      description: giftItem.name,
      position: pos,
      size: size,
      tileSize: SimpleEnhancedFarmGame.tileSize,
      isPlayerAdjacent: (x, y) => _toolActions.isAdjacent(player.position, x, y),
      onPickUp: (id) async {
        // Only pick up if adjacent
        if (!_toolActions.isAdjacent(player.position, gridX, gridY)) return;
        await inventoryManager?.addItem(InventoryItem(id: giftItem.id, name: giftItem.name, iconPath: giftItem.iconPath, quantity: 1));
        // Find this gift component by tile and remove
        for (final g in world.children.query<GiftObject>()) {
          final gx = (g.position.x / SimpleEnhancedFarmGame.tileSize).floor();
          final gy = (g.position.y / SimpleEnhancedFarmGame.tileSize).floor();
          if (gx == gridX && gy == gridY) {
            g.removeFromParent();
            break;
          }
        }
      },
    );
    await world.add(gift);
    // Persist placement in backend
    await PlacedGiftService.placeGift(
      farmId: farmId,
      gridX: gridX,
      gridY: gridY,
      giftId: giftItem.id,
      spriteUrl: giftItem.iconPath,
      description: giftItem.name,
    );
    // Remove one from inventory when placed
    await inventoryManager?.removeItem(inventoryManager!.selectedSlotIndex);
  }

  bool _isTileTillable(int gridX, int gridY) {
    if (_tileData != null && gridX >= 0 && gridX < _tileData![0].length && gridY >= 0 && gridY < _tileData!.length) {
      final gid = _tileData![gridY][gridX];
      final properties = getTilePropertiesAt(gridX, gridY);
      if (properties != null && properties.containsKey('isTillable')) {
        final isTillable = properties['isTillable'] == true;
        return isTillable;
      }
      if (gid >= 24 && gid <= 30) {
        return true;
      }
    }
    return false;
  }

  bool _isTileTilled(int gridX, int gridY) {
    if (_useVertexTerrainSystem) {
      if (gridX >= 0 && gridX < SimpleEnhancedFarmGame.mapWidth - 1 && gridY >= 0 && gridY < SimpleEnhancedFarmGame.mapHeight - 1) {
        final dirtId = _dirtTerrainId;
        final bool isTilled =
            mapVertexGrid[gridY][gridX] == dirtId &&
            mapVertexGrid[gridY][gridX + 1] == dirtId &&
            mapVertexGrid[gridY + 1][gridX] == dirtId &&
            mapVertexGrid[gridY + 1][gridX + 1] == dirtId;
        return isTilled;
      } else {
        return false;
      }
    } else {
      if (_tileData != null && gridX >= 0 && gridX < _tileData![0].length && gridY >= 0 && gridY < _tileData!.length) {
        final gid = _tileData![gridY][gridX];
        if (gid >= 27 && gid <= 35) {
          return true;
        }
        if (gid == 28) {
          return true;
        }
        final properties = getTilePropertiesAt(gridX, gridY);
        if (properties != null && properties.containsKey('isTilled')) {
          final isTilled = properties['isTilled'] == true;
          return isTilled;
        }
      }
      return false;
    }
  }

  bool _isTileWaterable(int gridX, int gridY) {
    if (_tileData != null && gridX >= 0 && gridX < _tileData![0].length && gridY >= 0 && gridY < _tileData!.length) {
      final gid = _tileData![gridY][gridX];
      final properties = getTilePropertiesAt(gridX, gridY);
      if (gid >= 27 && gid <= 35) {
        return true;
      }
      final tileId = gid - 1;
      for (final wangTile in _autoTiler.wangTiles) {
        final originalTileId = wangTile.tileId % 1000;
        if (originalTileId == tileId) {
          final wangId = wangTile.getWangIdValues();
          if (wangId.contains(1)) {
            return true;
          }
          break;
        }
      }
      if (properties != null && properties.containsKey('isTillable') && properties['isTillable'] == true) {
        return true;
      }
      if (properties != null && properties.containsKey('isWaterable')) {
        final isWaterable = properties['isWaterable'] == true;
        return isWaterable;
      }
    }
    return false;
  }

  Future<bool> _canWaterTile(int gridX, int gridY) async {
    try {
      // Check if there's a planted seed at this location
      final plant = _getPlantedSeedAt(gridX, gridY);
      if (plant == null) {
        // No plant - don't allow watering empty tiles
        debugPrint('[SimpleEnhancedFarmGame] ❌ No plant found at ($gridX, $gridY) - cannot water empty tile');
        return false;
      }
      
      // Check if the plant is already fully grown
      if (plant.growthStage == 'fully_grown') {
        debugPrint('[SimpleEnhancedFarmGame] ❌ Plant at ($gridX, $gridY) is already fully grown - cannot water');
        return false;
      }
      
      // For daily question seeds, check if both partners have answered
      if (plant.seedId.startsWith('daily_question_seed')) {
        // Get the question ID from the seed
        final questionId = plant.seedId.replaceFirst('daily_question_seed_', '');
        
        // Check farm_seed_answers table for this specific seed location
        final answersResponse = await SupabaseConfig.client
            .from('farm_seed_answers')
            .select('user_id')
            .eq('farm_id', farmId)
            .eq('x', gridX)
            .eq('y', gridY)
            .eq('question_id', questionId);
        
        final answeredUserIds = answersResponse.map((row) => row['user_id'] as String).toSet();
        final currentUserId = SupabaseConfig.currentUserId;
        
        if (currentUserId == null) {
          debugPrint('[SimpleEnhancedFarmGame] ❌ No current user ID');
          return false;
        }
        
        // Get the couple to find the partner ID
        final couple = await GardenRepository().getUserCouple();
        if (couple == null) {
          debugPrint('[SimpleEnhancedFarmGame] ❌ No couple found');
          return false;
        }
        
        final partnerId = couple.user1Id == currentUserId ? couple.user2Id : couple.user1Id;
        final hasMine = answeredUserIds.contains(currentUserId);
        final hasPartner = answeredUserIds.contains(partnerId);
        
        debugPrint('[SimpleEnhancedFarmGame] 🔍 Checking answers for question $questionId at ($gridX, $gridY)');
        debugPrint('[SimpleEnhancedFarmGame] 🔍 Current user ($currentUserId): $hasMine');
        debugPrint('[SimpleEnhancedFarmGame] 🔍 Partner ($partnerId): $hasPartner');
        debugPrint('[SimpleEnhancedFarmGame] 🔍 All answered users: $answeredUserIds');
        
        if (!(hasMine && hasPartner)) {
          debugPrint('[SimpleEnhancedFarmGame] ❌ Daily question seed at ($gridX, $gridY) cannot be watered - both partners must answer first');
          return false;
        }
        
        // Check if enough time has passed since last watering (24 hours)
        final seedResponse = await SupabaseConfig.client
            .from('farm_seeds')
            .select('last_watered_at')
            .eq('farm_id', farmId)
            .eq('x', gridX)
            .eq('y', gridY)
            .maybeSingle();
            
        if (seedResponse != null) {
          final lastWateredAt = seedResponse['last_watered_at'] as String?;
          if (lastWateredAt != null) {
            final lastWatered = DateTime.parse(lastWateredAt);
            final now = DateTime.now();
            final hoursSinceLastWater = now.difference(lastWatered).inHours;
            
            // Must wait 24 hours between waterings
            if (hoursSinceLastWater < 24) {
              final remainingHours = 24 - hoursSinceLastWater;
              debugPrint('[SimpleEnhancedFarmGame] ❌ Seed at ($gridX, $gridY) was watered recently - must wait $remainingHours more hours');
              return false;
            }
          }
        }
        
        debugPrint('[SimpleEnhancedFarmGame] ✅ Daily question seed at ($gridX, $gridY) can be watered');
        return true;
      }
      
      // For regular seeds, check if enough time has passed since last watering
      final seedState = await SeedService.getSeedState(plotX: gridX, plotY: gridY, farmId: farmId);
      if (seedState == null) {
        debugPrint('[SimpleEnhancedFarmGame] ❌ No seed state found at ($gridX, $gridY) - cannot water');
        return false;
      }
      
      final lastWateredAt = seedState['last_watered_at'] as String?;
      if (lastWateredAt != null) {
        final lastWatered = DateTime.parse(lastWateredAt);
        final now = DateTime.now();
        final hoursSinceLastWater = now.difference(lastWatered).inHours;
        
        // Must wait 24 hours between waterings
        if (hoursSinceLastWater < 24) {
          final remainingHours = 24 - hoursSinceLastWater;
          debugPrint('[SimpleEnhancedFarmGame] ❌ Seed at ($gridX, $gridY) was watered recently - must wait $remainingHours more hours');
          return false;
        }
      }
      
      debugPrint('[SimpleEnhancedFarmGame] ✅ Seed at ($gridX, $gridY) can be watered');
      return true;
    } catch (e) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Error checking if can water tile: $e');
      return false;
    }
  }

  Map<String, dynamic>? getTilePropertiesAt(int x, int y) {
    if (_tileData != null && x >= 0 && x < _tileData![0].length && y >= 0 && y < _tileData!.length) {
      final gid = _tileData![y][x];
      if (gid >= 1 && gid <= 180) {
        final tileId = gid - 1;
        return _groundTilesetParser.getTileProperties()[tileId];
      } else if (gid >= 181) {
        final tileId = gid - 181;
        return _beachTilesetParser.getTileProperties()[tileId];
      }
    }
    return null;
  }
}


