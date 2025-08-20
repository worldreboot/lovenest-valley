import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lovenest/config/supabase_config.dart';

class CurrencyService {
  static SupabaseClient get _client => SupabaseConfig.client;

  /// Fetch the current user's coin balance from `profiles.coins`.
  static Future<int> getBalance() async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return 0;
      final row = await _client
          .from('profiles')
          .select('coins')
          .eq('id', userId)
          .maybeSingle();
      return (row?['coins'] as int?) ?? 0;
    } catch (e) {
      debugPrint('[CurrencyService] Error fetching balance: $e');
      return 0;
    }
  }

  /// Spend coins via RPC `spend_coins(amount, reason, metadata)`.
  /// Returns the new balance on success, or null on failure.
  static Future<int?> spend({
    required int amount,
    String reason = 'purchase',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _client.rpc('spend_coins', params: {
        'p_amount': amount,
        'p_reason': reason,
        'p_metadata': metadata ?? {},
      });

      if (response is List && response.isNotEmpty) {
        final row = response.first as Map<String, dynamic>;
        final success = row['success'] as bool? ?? false;
        final newBalance = row['new_balance'] as int?;
        if (success) return newBalance;
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('[CurrencyService] Error spending coins: $e');
      return null;
    }
  }
}


