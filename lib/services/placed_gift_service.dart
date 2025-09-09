import 'package:lovenest_valley/config/supabase_config.dart';

class PlacedGiftService {
  static Future<bool> placeGift({
    required String farmId,
    required int gridX,
    required int gridY,
    required String giftId,
    String? spriteUrl,
    String? description,
  }) async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return false;
    try {
      await SupabaseConfig.client.from('placed_gifts').insert({
        'farm_id': farmId,
        'user_id': userId,
        'grid_x': gridX,
        'grid_y': gridY,
        'gift_id': giftId,
        'sprite_url': spriteUrl,
        'description': description,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> removeGift({
    required String farmId,
    required int gridX,
    required int gridY,
  }) async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return false;
    try {
      await SupabaseConfig.client
          .from('placed_gifts')
          .delete()
          .match({'farm_id': farmId, 'grid_x': gridX, 'grid_y': gridY, 'user_id': userId});
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> listPlacedGifts(String farmId) async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return [];
    try {
      final rows = await SupabaseConfig.client
          .from('placed_gifts')
          .select('grid_x, grid_y, gift_id, sprite_url, description')
          .eq('farm_id', farmId)
          .eq('user_id', userId);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      return [];
    }
  }
}


