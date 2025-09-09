import 'package:lovenest_valley/config/supabase_config.dart';
import 'package:flutter/foundation.dart';

class SeedService {
  /// Plant a regular seed
  static Future<bool> plantRegularSeed({
    required String seedId,
    required String seedName,
    required int plotX,
    required int plotY,
    required String farmId,
  }) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return false;

      // Create a farm tile record for tracking the planted seed
      await SupabaseConfig.client
          .from('farm_tiles')
          .upsert({
            'farm_id': farmId,
            'x': plotX,
            'y': plotY,
            'tile_type': 'crop',
            'plant_type': 'regular_seed',
            'growth_stage': 'planted',
            'watered': false,
            'water_count': 0,
            'planted_at': DateTime.now().toIso8601String(),
            'last_watered_at': null,
            // Store seed info in properties
            'properties': {
              'seed_id': seedId,
              'seed_name': seedName,
            },
          });

      debugPrint('[SeedService] 🌱 Regular seed planted at ($plotX, $plotY)');
      return true;
    } catch (e) {
      debugPrint('[SeedService] ❌ Error planting regular seed: $e');
      return false;
    }
  }

  /// Load all planted seeds for a farm from the backend
  static Future<List<Map<String, dynamic>>> loadPlantedSeeds({
    required String farmId,
  }) async {
    try {
      final response = await SupabaseConfig.client
          .from('farm_tiles')
          .select('*')
          .eq('farm_id', farmId)
          .inFilter('tile_type', ['crop', 'watered']) // Include both crop and watered tiles
          .inFilter('plant_type', ['regular_seed', 'daily_question_seed']);

      debugPrint('[SeedService] 📦 Loaded ${response.length} planted seeds for farm: $farmId');
      
      for (final seed in response) {
        debugPrint('[SeedService]   - ${seed['plant_type']} at (${seed['x']}, ${seed['y']}) - Stage: ${seed['growth_stage']} - Tile type: ${seed['tile_type']}');
      }
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[SeedService] ❌ Error loading planted seeds: $e');
      return [];
    }
  }

  /// Water a regular seed and track progress
  static Future<bool> waterRegularSeed({
    required int plotX,
    required int plotY,
    required String farmId,
  }) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return false;

      debugPrint('[SeedService] 🚰 User $userId attempting to water regular seed at ($plotX, $plotY) on farm $farmId');

      // Get current tile state
      final tileResponse = await SupabaseConfig.client
          .from('farm_tiles')
          .select('water_count, growth_stage, plant_type, last_watered_at')
          .eq('farm_id', farmId)
          .eq('x', plotX)
          .eq('y', plotY)
          .maybeSingle();

      if (tileResponse == null || tileResponse['plant_type'] != 'regular_seed') {
        debugPrint('[SeedService] ❌ No regular seed found at ($plotX, $plotY)');
        return false;
      }

      final currentWaterCount = (tileResponse['water_count'] as int?) ?? 0;
      final currentGrowthStage = tileResponse['growth_stage'] as String? ?? 'planted';
      final lastWateredAt = tileResponse['last_watered_at'] as String?;

      debugPrint('[SeedService] 📊 Current state - Water count: $currentWaterCount, Growth stage: $currentGrowthStage');
      debugPrint('[SeedService] ⏰ Last watered at: ${lastWateredAt ?? 'Never'}');

      // Check if enough time has passed since last watering (24 hours)
      if (lastWateredAt != null) {
        final lastWatered = DateTime.parse(lastWateredAt);
        final now = DateTime.now();
        final hoursSinceLastWater = now.difference(lastWatered).inHours;
        
        debugPrint('[SeedService] ⏱️ Hours since last watering: $hoursSinceLastWater');
        
        if (hoursSinceLastWater < 24) {
          final remainingHours = 24 - hoursSinceLastWater;
          debugPrint('[SeedService] ❌ Must wait $remainingHours more hours before watering again');
          return false;
        }
      } else {
        debugPrint('[SeedService] ✅ First time watering - no time restriction');
      }

      // Update water count and growth stage
      final newWaterCount = currentWaterCount + 1;
      String newGrowthStage = currentGrowthStage;

      // Determine new growth stage based on water count
      if (newWaterCount >= 3) {
        newGrowthStage = 'fully_grown';
      } else if (newWaterCount >= 1) {
        newGrowthStage = 'growing';
      }

      // Update the farm tile
      await SupabaseConfig.client
          .from('farm_tiles')
          .update({
            'water_count': newWaterCount,
            'growth_stage': newGrowthStage,
            'watered': true,
            'last_watered_at': DateTime.now().toIso8601String(),
          })
          .eq('farm_id', farmId)
          .eq('x', plotX)
          .eq('y', plotY);

      // Enhanced success logging
      final now = DateTime.now();
      debugPrint('[SeedService] ✅ SUCCESS: User $userId watered regular seed at ($plotX, $plotY)');
      debugPrint('[SeedService] 📈 Progress: $currentWaterCount → $newWaterCount/3 waters');
      debugPrint('[SeedService] 🌱 Growth: $currentGrowthStage → $newGrowthStage');
      debugPrint('[SeedService] ⏰ Timestamp: ${now.toIso8601String()}');
      debugPrint('[SeedService] 🏁 Status: ${newWaterCount >= 3 ? 'FULLY GROWN!' : 'Still growing...'}');
      
      // Use comprehensive logging
      logSuccessfulWatering(
        userId: userId,
        plotX: plotX,
        plotY: plotY,
        farmId: farmId,
        seedType: 'regular_seed',
        previousWaterCount: currentWaterCount,
        newWaterCount: newWaterCount,
        previousGrowthStage: currentGrowthStage,
        newGrowthStage: newGrowthStage,
        isFullyGrown: newWaterCount >= 3,
      );
      
      return true;
    } catch (e) {
      debugPrint('[SeedService] ❌ Error watering regular seed: $e');
      return false;
    }
  }

  /// Comprehensive logging for successful seed watering
  static void logSuccessfulWatering({
    required String userId,
    required int plotX,
    required int plotY,
    required String farmId,
    required String seedType,
    required int previousWaterCount,
    required int newWaterCount,
    required String previousGrowthStage,
    required String newGrowthStage,
    required bool isFullyGrown,
  }) {
    final now = DateTime.now();
    final timestamp = now.toIso8601String();
    
    debugPrint('🌱 === SEED WATERING SUCCESS LOG ===');
    debugPrint('👤 User ID: $userId');
    debugPrint('📍 Location: ($plotX, $plotY) on farm $farmId');
    debugPrint('🌿 Seed Type: $seedType');
    debugPrint('📊 Water Progress: $previousWaterCount → $newWaterCount/3');
    debugPrint('🌱 Growth Stage: $previousGrowthStage → $newGrowthStage');
    debugPrint('⏰ Timestamp: $timestamp');
    debugPrint('🏁 Status: ${isFullyGrown ? 'FULLY GROWN!' : 'Still growing...'}');
    debugPrint('🌱 === END SUCCESS LOG ===');
  }

  /// Get remaining hours until next watering is allowed
  static Future<int?> getRemainingHoursUntilWatering(int plotX, int plotY, String farmId) async {
    try {
      final tileResponse = await SupabaseConfig.client
          .from('farm_tiles')
          .select('last_watered_at')
          .eq('farm_id', farmId)
          .eq('x', plotX)
          .eq('y', plotY)
          .maybeSingle();

      if (tileResponse == null) {
        return null; // No watering record, can water immediately
      }

      final lastWateredAt = tileResponse['last_watered_at'] as String?;
      if (lastWateredAt == null) {
        return null; // Never watered, can water immediately
      }

      final lastWatered = DateTime.parse(lastWateredAt);
      final now = DateTime.now();
      final hoursSinceLastWater = now.difference(lastWatered).inHours;
      
      if (hoursSinceLastWater >= 24) {
        return 0; // Can water now
      } else {
        return 24 - hoursSinceLastWater; // Hours remaining
      }
    } catch (e) {
      debugPrint('[SeedService] ❌ Error getting remaining hours: $e');
      return null;
    }
  }

  /// Get the current state of a planted seed
  static Future<Map<String, dynamic>?> getSeedState({
    required int plotX,
    required int plotY,
    required String farmId,
  }) async {
    try {
      final tileResponse = await SupabaseConfig.client
          .from('farm_tiles')
          .select('*')
          .eq('farm_id', farmId)
          .eq('x', plotX)
          .eq('y', plotY)
          .maybeSingle();

      if (tileResponse == null) {
        debugPrint('[SeedService] ❌ No seed found at ($plotX, $plotY)');
        return null;
      }

      return tileResponse;
    } catch (e) {
      debugPrint('[SeedService] ❌ Error getting seed state: $e');
      return null;
    }
  }

  /// Remove a planted seed (harvest or clear)
  static Future<bool> removePlantedSeed({
    required int plotX,
    required int plotY,
    required String farmId,
  }) async {
    try {
      await SupabaseConfig.client
          .from('farm_tiles')
          .delete()
          .eq('farm_id', farmId)
          .eq('x', plotX)
          .eq('y', plotY);

      debugPrint('[SeedService] 🗑️ Planted seed removed at ($plotX, $plotY)');
      return true;
    } catch (e) {
      debugPrint('[SeedService] ❌ Error removing planted seed: $e');
      return false;
    }
  }
} 
