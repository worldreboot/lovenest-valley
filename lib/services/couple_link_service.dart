import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:lovenest_valley/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoupleLinkService {
  CoupleLinkService();

  SupabaseClient get _client => SupabaseConfig.client;

  Future<Map<String, dynamic>> createInvite() async {
    try {
      final res = await _client.rpc('create_couple_invite');
      if (res is List && res.isNotEmpty) {
        final row = res.first as Map<String, dynamic>;
        return row;
      }
      throw Exception('Failed to create invite');
    } catch (e) {
      debugPrint('[CoupleLinkService] createInvite error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getInviteByCode(String code) async {
    try {
      final row = await _client
          .from('couple_invites')
          .select('*')
          .eq('invite_code', code)
          .maybeSingle();
      return row;
    } catch (e) {
      debugPrint('[CoupleLinkService] getInviteByCode error: $e');
      return null;
    }
  }

  Future<String> redeem(String code) async {
    try {
      // Get the invite details first to validate it's not the user's own invite
      final invite = await getInviteByCode(code);
      if (invite != null) {
        final inviterId = invite['inviter_id'] as String?;
        final currentUserId = SupabaseConfig.currentUserId;
        
        // Critical validation: Prevent users from accepting their own invites
        if (inviterId == currentUserId) {
          throw Exception('Cannot accept your own invite - you cannot be a couple with yourself');
        }
      }

      final res = await _client.rpc('redeem_couple_invite', params: {
        'p_code': code,
      });
      if (res is List && res.isNotEmpty) {
        final row = res.first as Map<String, dynamic>;
        final coupleId = row['couple_id'] as String?;
        if (coupleId != null) return coupleId;
      }
      throw Exception('Failed to redeem invite');
    } catch (e) {
      debugPrint('[CoupleLinkService] redeem error: $e');
      rethrow;
    }
  }

  Future<void> decline(String code) async {
    try {
      await _client.rpc('decline_couple_invite', params: {
        'p_code': code,
      });
    } catch (e) {
      debugPrint('[CoupleLinkService] decline error: $e');
      rethrow;
    }
  }

  Future<void> cancelInvite() async {
    try {
      await _client.rpc('cancel_couple_invite');
    } catch (e) {
      debugPrint('[CoupleLinkService] cancelInvite error: $e');
      rethrow;
    }
  }

  Future<void> unlink() async {
    try {
      await _client.rpc('unlink_couple');
    } catch (e) {
      debugPrint('[CoupleLinkService] unlink error: $e');
      rethrow;
    }
  }

  /// Utility to check if current user is in a couple and return the row
  Future<Map<String, dynamic>?> getCurrentUserCouple() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return null;
    try {
      final couple = await _client
          .from('couples')
          .select()
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .maybeSingle();
      return couple;
    } catch (e) {
      debugPrint('[CoupleLinkService] getCurrentUserCouple error: $e');
      return null;
    }
  }
}


