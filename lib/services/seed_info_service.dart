import 'package:flutter/foundation.dart';
import 'package:lovenest_valley/config/supabase_config.dart';

class SeedInfoService {
  static final _client = SupabaseConfig.client;

  /// Get watering and planting information for a seed at specific coordinates
  static Future<Map<String, dynamic>?> getSeedInfo(int plotX, int plotY, String farmId) async {
    try {
      debugPrint('[SeedInfoService] 🔍 Fetching seed info for ($plotX, $plotY) on farm $farmId');

      // Try to get info from farm_tiles first
      final farmTileInfo = await _client
          .from('farm_tiles')
          .select('watered, water_count, last_watered_at, planted_at, growth_stage, plant_type')
          .eq('farm_id', farmId)
          .eq('x', plotX)
          .eq('y', plotY)
          .maybeSingle();

      // Try to get info from farm_seeds as well
      final farmSeedInfo = await _client
          .from('farm_seeds')
          .select('water_count, last_watered_at, planted_at, growth_stage, plant_type')
          .eq('farm_id', farmId)
          .eq('x', plotX)
          .eq('y', plotY)
          .maybeSingle();

      // Try to get info from seeds table (for memory garden seeds)
      final seedInfo = await _client
          .from('seeds')
          .select('state, growth_score, created_at, last_updated_at, text_content, media_type')
          .eq('plot_x', plotX.toDouble())
          .eq('plot_y', plotY.toDouble())
          .maybeSingle();

      // Combine the information, prioritizing farm_seeds over farm_tiles
      final Map<String, dynamic> combinedInfo = {};

      if (farmSeedInfo != null) {
        combinedInfo.addAll({
          'water_count': farmSeedInfo['water_count'] ?? 0,
          'last_watered_at': farmSeedInfo['last_watered_at'],
          'planted_at': farmSeedInfo['planted_at'],
          'growth_stage': farmSeedInfo['growth_stage'] ?? 'planted',
          'plant_type': farmSeedInfo['plant_type'],
          'source': 'farm_seeds',
        });
      } else if (farmTileInfo != null) {
        combinedInfo.addAll({
          'water_count': farmTileInfo['water_count'] ?? 0,
          'last_watered_at': farmTileInfo['last_watered_at'],
          'planted_at': farmTileInfo['planted_at'],
          'growth_stage': farmTileInfo['growth_stage'] ?? 'planted',
          'plant_type': farmTileInfo['plant_type'],
          'watered': farmTileInfo['watered'] ?? false,
          'source': 'farm_tiles',
        });
      } else if (seedInfo != null) {
        combinedInfo.addAll({
          'state': seedInfo['state'] ?? 'unknown',
          'growth_score': seedInfo['growth_score'] ?? 0,
          'created_at': seedInfo['created_at'],
          'last_updated_at': seedInfo['last_updated_at'],
          'text_content': seedInfo['text_content'],
          'media_type': seedInfo['media_type'],
          'source': 'seeds',
        });
      }

      if (combinedInfo.isNotEmpty) {
        debugPrint('[SeedInfoService] ✅ Found seed info: $combinedInfo');
        return combinedInfo;
      } else {
        debugPrint('[SeedInfoService] ❌ No seed found at ($plotX, $plotY)');
        return null;
      }
    } catch (e) {
      debugPrint('[SeedInfoService] ❌ Error fetching seed info: $e');
      return null;
    }
  }

  /// Format timestamp for display
  static String formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Never';
    
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
