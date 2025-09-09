import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lovenest_valley/config/supabase_config.dart';

class StarterItemsService {
  static SupabaseClient get _client => SupabaseConfig.client;

  /// Check if the current user has already received starter items
  static Future<bool> hasReceivedStarterItems() async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        debugPrint('[StarterItemsService] ❌ No current user ID');
        return false;
      }

      final response = await _client
          .from('profiles')
          .select('has_received_starter_items')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        debugPrint('[StarterItemsService] ❌ No profile found for user');
        return false;
      }

      final hasReceived = response['has_received_starter_items'] as bool? ?? false;
      debugPrint('[StarterItemsService] 📊 User has received starter items: $hasReceived');
      return hasReceived;
    } catch (e) {
      debugPrint('[StarterItemsService] ❌ Error checking starter items status: $e');
      return false;
    }
  }

  /// Mark that the current user has received starter items
  static Future<bool> markStarterItemsReceived() async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        debugPrint('[StarterItemsService] ❌ No current user ID');
        return false;
      }

      await _client
          .from('profiles')
          .update({
            'has_received_starter_items': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      debugPrint('[StarterItemsService] ✅ Marked starter items as received for user');
      return true;
    } catch (e) {
      debugPrint('[StarterItemsService] ❌ Error marking starter items as received: $e');
      return false;
    }
  }

  /// Reset starter items status (useful for testing or admin purposes)
  static Future<bool> resetStarterItemsStatus() async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        debugPrint('[StarterItemsService] ❌ No current user ID');
        return false;
      }

      await _client
          .from('profiles')
          .update({
            'has_received_starter_items': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      debugPrint('[StarterItemsService] ✅ Reset starter items status for user');
      return true;
    } catch (e) {
      debugPrint('[StarterItemsService] ❌ Error resetting starter items status: $e');
      return false;
    }
  }
}
