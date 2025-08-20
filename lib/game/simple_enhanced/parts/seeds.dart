part of '../../simple_enhanced_farm_game.dart';

extension SeedsExtension on SimpleEnhancedFarmGame {
  // Toggle for bypassing sprite loads (should be false in normal flow)
  static const bool kDisablePlantedSeedSprite = false;
  Future<void> _loadPlantedSeedsFromBackend() async {
    try {
      debugPrint('[SimpleEnhancedFarmGame] 🔄 Loading planted seeds from backend...');
      if (_isUsingFreshTMXMap) {
        debugPrint('[SimpleEnhancedFarmGame] ℹ️ Using fresh TMX-based map, skipping seed loading');
        return;
      }
      final farmTileService = FarmTileService();
      final plantedSeeds = await farmTileService.loadPlantedSeeds(farmId);
      debugPrint('[SimpleEnhancedFarmGame] 📦 Found ${plantedSeeds.length} planted seeds in backend');
      for (final seedData in plantedSeeds) {
        final x = seedData['x'] as int;
        final y = seedData['y'] as int;
        final plantType = seedData['plant_type'] as String;
        final growthStage = seedData['growth_stage'] as String;
        final properties = seedData['properties'] as Map<String, dynamic>?;
        debugPrint('[SimpleEnhancedFarmGame] 🔍 Processing seed at ($x, $y):');
        debugPrint('[SimpleEnhancedFarmGame]   - Plant type: $plantType');
        debugPrint('[SimpleEnhancedFarmGame]   - Growth stage: $growthStage');
        debugPrint('[SimpleEnhancedFarmGame]   - Properties: $properties');
        String seedId;
        Color? seedColor;
        if (plantType == 'daily_question_seed') {
          final questionId = properties?['question_id'] as String?;
          seedId = 'daily_question_seed_${questionId ?? 'unknown'}';
          if (questionId != null) {
            seedColor = SeedColorGenerator.generateSeedColor(questionId);
          }
          debugPrint('[SimpleEnhancedFarmGame] 🌱 Daily question seed ID: $seedId, Color: $seedColor');
        } else {
          seedId = properties?['seed_id'] as String? ?? 'unknown_seed';
          debugPrint('[SimpleEnhancedFarmGame] 🌱 Regular seed ID: $seedId');
        }
        debugPrint('[SimpleEnhancedFarmGame] 🌱 Restoring ${plantType} at ($x, $y) - Stage: $growthStage');
        await addPlantedSeed(x, y, seedId, growthStage, seedColor: seedColor);
        debugPrint('[SimpleEnhancedFarmGame] ✅ Added visual component for seed at ($x, $y)');
      }
      debugPrint('[SimpleEnhancedFarmGame] ✅ Restored ${plantedSeeds.length} planted seeds from backend');
    } catch (e) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Error loading planted seeds from backend: $e');
    }
  }

  Future<void> addPlantedSeed(int gridX, int gridY, String seedId, String growthStage, {Color? seedColor}) async {
    try {
      debugPrint('[SimpleEnhancedFarmGame] 🌱 Adding planted seed at ($gridX, $gridY):');
      debugPrint('[SimpleEnhancedFarmGame]   - Seed ID: $seedId');
      debugPrint('[SimpleEnhancedFarmGame]   - Growth stage: $growthStage');
      debugPrint('[SimpleEnhancedFarmGame]   - Seed color: $seedColor');
      if (!kDisablePlantedSeedSprite) {
        debugPrint('[SimpleEnhancedFarmGame] 🔍 Requesting plant sprite...');
        final plantSprite = await _getPlantSprite(seedId, growthStage, seedColor);
        debugPrint('[SimpleEnhancedFarmGame] ✅ Plant sprite acquired');
        final position = Vector2(gridX * SimpleEnhancedFarmGame.tileSize, gridY * SimpleEnhancedFarmGame.tileSize);
        final plantedSeedComponent = PlantedSeedComponent(
          seedId: seedId,
          gridX: gridX,
          gridY: gridY,
          growthStage: growthStage,
          sprite: plantSprite,
          position: position,
          seedColor: seedColor,
          farmId: farmId,
        );
        world.add(plantedSeedComponent);
        // If this is a daily question seed and the CURRENT user still needs to answer, show indicator
        if (seedId.startsWith('daily_question_seed_')) {
          // Check tile-specific answer state from farm_seed_answers using farm/tile
          () async {
            try {
              final res = await SupabaseConfig.client
                  .from('farm_seed_answers')
                  .select('user_id')
                  .eq('farm_id', farmId)
                  .eq('x', gridX)
                  .eq('y', gridY);
              final me = SupabaseConfig.currentUserId;
              final answeredUserIds = (res as List).map((r) => r['user_id'] as String).toSet();
              final bothAnswered = answeredUserIds.length >= 2; // both partners
              final hasMine = me != null && answeredUserIds.contains(me);
              if (!bothAnswered && !hasMine) {
                plantedSeedComponent.setPartnerNeeded(true);
              }
            } catch (_) {}
          }();
        }
        // Track for later updates
        _plantedSeeds['$gridX,$gridY'] = plantedSeedComponent;
        if (growthStage == 'fully_grown') {
          await plantedSeedComponent.checkAndLoadGeneratedSprite();
        }
      } else {
        debugPrint('[SimpleEnhancedFarmGame] 🧪 DEBUG: Sprite loading disabled; using placeholder rect component');
        final position = Vector2(gridX * SimpleEnhancedFarmGame.tileSize, gridY * SimpleEnhancedFarmGame.tileSize);
        final plantedSeedComponent = PlantedSeedComponent(
          seedId: seedId,
          gridX: gridX,
          gridY: gridY,
          growthStage: growthStage,
          sprite: Sprite(await images.load('items/seeds.png')), // not used when placeholder is on
          position: position,
          seedColor: seedColor,
          farmId: farmId,
          usePlaceholderRect: true,
        );
        world.add(plantedSeedComponent);
        _plantedSeeds['$gridX,$gridY'] = plantedSeedComponent;
      }
      debugPrint('[SimpleEnhancedFarmGame] 🌱 Added planted seed at ($gridX, $gridY): $seedId');
    } catch (e) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Error adding planted seed: $e');
      debugPrint('[SimpleEnhancedFarmGame] ⚠️ Context: seedId=$seedId stage=$growthStage at=($gridX,$gridY)');
    }
  }

  Future<void> updatePlantGrowth(int gridX, int gridY, String newGrowthStage) async {
    final key = '$gridX,$gridY';
    final existingPlant = _plantedSeeds[key];
    if (existingPlant != null) {
      final newSprite = await _getPlantSprite(existingPlant.seedId, newGrowthStage, existingPlant.seedColor);
      existingPlant.updateGrowth(newGrowthStage, newSprite);
      if (newGrowthStage == 'fully_grown') {
        await existingPlant.checkAndLoadGeneratedSprite();
      }
      debugPrint('[SimpleEnhancedFarmGame] 🌱 Updated plant growth at ($gridX, $gridY): $newGrowthStage');
    }
  }

  Future<void> waterPlant(int gridX, int gridY) async {
    final key = '$gridX,$gridY';
    final existingPlant = _plantedSeeds[key];
    if (existingPlant != null) {
      await updatePlantGrowth(gridX, gridY, 'growing');
      debugPrint('[SimpleEnhancedFarmGame] 💧 Watered plant at ($gridX, $gridY)');
    }
  }

  Future<Sprite> _getPlantSprite(String seedId, String growthStage, Color? seedColor) async {
    return _seedSprites.getPlantSprite(images, seedId, growthStage, seedColor);
  }

  bool _checkForPlantedSeed(int tileX, int tileY) {
    for (final component in world.children.query<PlantedSeedComponent>()) {
      final position = component.position;
      final gridX = (position.x / SimpleEnhancedFarmGame.tileSize).floor();
      final gridY = (position.y / SimpleEnhancedFarmGame.tileSize).floor();
      if (gridX == tileX && gridY == tileY) {
        return true;
      }
    }
    return false;
  }

  PlantedSeedComponent? _getPlantedSeedAt(int tileX, int tileY) {
    for (final component in world.children.query<PlantedSeedComponent>()) {
      if (component.gridX == tileX && component.gridY == tileY) {
        return component;
      }
    }
    return null;
  }

  Future<bool> _waterPlantedSeedAt(int tileX, int tileY) async {
    try {
      for (final component in world.children.query<PlantedSeedComponent>()) {
        final gridX = component.gridX;
        final gridY = component.gridY;
        if (gridX == tileX && gridY == tileY) {
          final seedId = component.seedId;
          debugPrint('[SimpleEnhancedFarmGame] 💧 Watering planted seed at ($gridX, $gridY): $seedId');
          if (seedId.startsWith('daily_question_seed')) {
            final success = await DailyQuestionSeedService.waterDailyQuestionSeed(
              plotX: gridX,
              plotY: gridY,
              farmId: farmId,
            );
            if (success) {
              debugPrint('[SimpleEnhancedFarmGame] ✅ Daily question seed watered successfully');
              if (component.sprite != null) {
                component.updateGrowth('watered', component.sprite!);
              }
              return true;
            } else {
              debugPrint('[SimpleEnhancedFarmGame] ❌ Failed to water daily question seed');
              return false;
            }
          } else {
            final farmTileService = FarmTileService();
            await farmTileService.waterSeed(farmId, gridX, gridY);
            debugPrint('[SimpleEnhancedFarmGame] ✅ Regular seed watered successfully');
            final seedData = await farmTileService.loadPlantedSeeds(farmId);
            final currentSeed = seedData.firstWhere(
              (seed) => seed['x'] == gridX && seed['y'] == gridY,
              orElse: () => <String, dynamic>{},
            );
            if (currentSeed.isNotEmpty && currentSeed['growth_stage'] == 'fully_grown') {
              debugPrint('[SimpleEnhancedFarmGame] 🌸 Seed is now fully grown - sprite generation triggered');
            }
            if (component.sprite != null) {
              component.updateGrowth('watered', component.sprite!);
            }
            return true;
          }
        }
      }
      debugPrint('[SimpleEnhancedFarmGame] ⚠️ No planted seed found at ($tileX, $tileY)');
      return false;
    } catch (e) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Error watering planted seed: $e');
      return false;
    }
  }

  Future<void> forceRefreshPlantedSeeds() async {
    try {
      debugPrint('[SimpleEnhancedFarmGame] 🔄 Force refreshing all planted seed components...');
      for (final component in world.children.query<PlantedSeedComponent>()) {
        debugPrint('[SimpleEnhancedFarmGame] 🔄 Checking component at (${component.gridX}, ${component.gridY})');
        await component.checkAndLoadGeneratedSprite();
      }
      debugPrint('[SimpleEnhancedFarmGame] ✅ Force refresh completed');
    } catch (e) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Error during force refresh: $e');
    }
  }

  Future<void> _checkAndRevertOldWateredTiles() async {
    try {
      debugPrint('[SimpleEnhancedFarmGame] 🔄 Checking for old watered tiles that need reverting...');
      final farmTileService = FarmTileService();
      final plantedSeeds = await farmTileService.loadPlantedSeeds(farmId);
      bool hasChanges = false;
      for (final seedData in plantedSeeds) {
        final x = seedData['x'] as int;
        final y = seedData['y'] as int;
        final lastWateredAt = seedData['last_watered_at'] as String?;
        if (lastWateredAt != null) {
          final lastWatered = DateTime.parse(lastWateredAt);
          final now = DateTime.now();
          final hoursSinceLastWater = now.difference(lastWatered).inHours;
          if (hoursSinceLastWater >= 24) {
            debugPrint('[SimpleEnhancedFarmGame] ⏰ Tile at ($x, $y) was watered $hoursSinceLastWater hours ago - reverting to dirt');
            _writeTileVertices(x, y, _dirtTerrainId);
            hasChanges = true;
          }
        }
      }
      if (hasChanges) {
        debugPrint('[SimpleEnhancedFarmGame] 🔄 Reverting old watered tiles to dirt...');
        await _persistVertexGridState();
        _updateEntireMapVisual();
        debugPrint('[SimpleEnhancedFarmGame] ✅ Old watered tiles reverted to dirt');
      } else {
        debugPrint('[SimpleEnhancedFarmGame] ℹ️ No old watered tiles found');
      }
    } catch (e) {
      debugPrint('[SimpleEnhancedFarmGame] ❌ Error checking for old watered tiles: $e');
    }
  }
}


