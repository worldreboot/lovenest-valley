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
    return await SupabaseConfig.safeDbOperation(
      () async {
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
      },
      operationName: 'plant regular seed',
    );
  }

  /// Load all planted seeds for a farm from the backend
  static Future<List<Map<String, dynamic>>> loadPlantedSeeds({
    required String farmId,
  }) async {
    return await SupabaseConfig.safeDbOperation(
      () async {
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
      },
      operationName: 'load planted seeds',
    );
  }

  /// Water a regular seed and track progress
  static Future<bool> waterRegularSeed({
    required int plotX,
    required int plotY,
    required String farmId,
  }) async {
    return await SupabaseConfig.safeDbOperation(
      () async {
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

        // Check if enough time has passed since last watering (24 hours)
        if (lastWateredAt != null) {
          final lastWatered = DateTime.parse(lastWateredAt);
          final now = DateTime.now();
          final hoursSinceLastWatering = now.difference(lastWatered).inHours;
          
          if (hoursSinceLastWatering < 24) {
            debugPrint('[SeedService] ⏰ Cannot water yet. Last watered ${hoursSinceLastWatering}h ago. Need 24h between waterings.');
            return false;
          }
        }

        // Calculate new water count and growth stage
        final newWaterCount = currentWaterCount + 1;
        String newGrowthStage;
        
        if (newWaterCount >= 3) {
          newGrowthStage = 'fully_grown';
        } else if (newWaterCount >= 2) {
          newGrowthStage = 'growing';
        } else {
          newGrowthStage = 'sprouted';
        }

        // Update the farm tile
        await SupabaseConfig.client
            .from('farm_tiles')
            .update({
              'water_count': newWaterCount,
              'growth_stage': newGrowthStage,
              'watered': true,
              'last_watered_at': DateTime.now().toIso8601String(),
              'tile_type': newWaterCount >= 3 ? 'watered' : 'crop', // Change tile type when fully grown
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
      },
      operationName: 'water regular seed',
    );
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
    final timestamp = DateTime.now().toIso8601String();
    
    debugPrint('[SeedService] 📊 WATERING LOG:');
    debugPrint('[SeedService]   User: $userId');
    debugPrint('[SeedService]   Location: ($plotX, $plotY) on farm $farmId');
    debugPrint('[SeedService]   Seed Type: $seedType');
    debugPrint('[SeedService]   Water Count: $previousWaterCount → $newWaterCount');
    debugPrint('[SeedService]   Growth Stage: $previousGrowthStage → $newGrowthStage');
    debugPrint('[SeedService]   Fully Grown: $isFullyGrown');
    debugPrint('[SeedService]   Timestamp: $timestamp');
  }

  /// Check if a seed can be watered (24-hour cooldown)
  static Future<bool> canWaterSeed({
    required int plotX,
    required int plotY,
    required String farmId,
  }) async {
    return await SupabaseConfig.safeDbOperation(
      () async {
        try {
          final tileResponse = await SupabaseConfig.client
              .from('farm_tiles')
              .select('last_watered_at')
              .eq('farm_id', farmId)
              .eq('x', plotX)
              .eq('y', plotY)
              .maybeSingle();

          if (tileResponse == null) {
            return false; // No seed at this location
          }

          final lastWateredAt = tileResponse['last_watered_at'] as String?;
          if (lastWateredAt == null) {
            return true; // Never watered, can water now
          }

          final lastWatered = DateTime.parse(lastWateredAt);
          final now = DateTime.now();
          final hoursSinceLastWatering = now.difference(lastWatered).inHours;
          
          return hoursSinceLastWatering >= 24;
        } catch (e) {
          debugPrint('[SeedService] ❌ Error checking if seed can be watered: $e');
          return false;
        }
      },
      operationName: 'check if seed can be watered',
    );
  }

  /// Get seed information at a specific location
  static Future<Map<String, dynamic>?> getSeedInfo({
    required int plotX,
    required int plotY,
    required String farmId,
  }) async {
    return await SupabaseConfig.safeDbOperation(
      () async {
        try {
          final tileResponse = await SupabaseConfig.client
              .from('farm_tiles')
              .select('*')
              .eq('farm_id', farmId)
              .eq('x', plotX)
              .eq('y', plotY)
              .maybeSingle();

          return tileResponse;
        } catch (e) {
          debugPrint('[SeedService] ❌ Error getting seed info: $e');
          return null;
        }
      },
      operationName: 'get seed info',
    );
  }

  /// Remove a planted seed
  static Future<bool> removePlantedSeed({
    required int plotX,
    required int plotY,
    required String farmId,
  }) async {
    return await SupabaseConfig.safeDbOperation(
      () async {
        try {
          await SupabaseConfig.client
              .from('farm_tiles')
              .delete()
              .eq('farm_id', farmId)
              .eq('x', plotX)
              .eq('y', plotY);

          debugPrint('[SeedService] 🗑️ Removed seed at ($plotX, $plotY)');
          return true;
        } catch (e) {
          debugPrint('[SeedService] ❌ Error removing planted seed: $e');
          return false;
        }
      },
      operationName: 'remove planted seed',
    );
  }

  /// Get seed state at a specific location
  static Future<Map<String, dynamic>?> getSeedState({
    required int plotX,
    required int plotY,
    required String farmId,
  }) async {
    return await SupabaseConfig.safeDbOperation(
      () async {
        try {
          final response = await SupabaseConfig.client
              .from('farm_tiles')
              .select('*')
              .eq('farm_id', farmId)
              .eq('x', plotX)
              .eq('y', plotY)
              .maybeSingle();

          if (response != null) {
            return {
              'exists': true,
              'plant_type': response['plant_type'],
              'growth_stage': response['growth_stage'],
              'water_count': response['water_count'] ?? 0,
              'watered': response['watered'] ?? false,
              'planted_at': response['planted_at'],
              'last_watered_at': response['last_watered_at'],
              'properties': response['properties'],
            };
          } else {
            return {
              'exists': false,
              'plant_type': null,
              'growth_stage': null,
              'water_count': 0,
              'watered': false,
              'planted_at': null,
              'last_watered_at': null,
              'properties': null,
            };
          }
        } catch (e) {
          debugPrint('[SeedService] ❌ Error getting seed state: $e');
          return {
            'exists': false,
            'plant_type': null,
            'growth_stage': null,
            'water_count': 0,
            'watered': false,
            'planted_at': null,
            'last_watered_at': null,
            'properties': null,
          };
        }
      },
      operationName: 'get seed state',
    );
  }
}