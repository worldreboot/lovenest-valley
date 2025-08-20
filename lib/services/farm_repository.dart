import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../utils/offline_handler.dart';

class FarmRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  /// Returns the user's farm row, or null if none exists
  Future<Map<String, dynamic>?> getCurrentUserFarm() async {
    return OfflineHandler.withOfflineHandling(() async {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return null;
      
      debugPrint('[FarmRepository] Looking for farm for user: $userId');
      
      // First check if user is in a couple
      final couple = await _client
          .from('couples')
          .select()
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .maybeSingle();
      
      if (couple != null) {
        // User is in a couple - get the shared farm (User 1's farm)
        final user1Id = couple['user1_id'] as String;
        final user2Id = couple['user2_id'] as String;
        
        debugPrint('[FarmRepository] User is in a couple - User 1: $user1Id, User 2: $user2Id');
        debugPrint('[FarmRepository] Current user: $userId');
        
        // Always return User 1's farm for couples
        final sharedFarm = await _client
            .from('farms')
            .select()
            .eq('owner_id', user1Id)
            .maybeSingle();
        
        if (sharedFarm != null) {
          final farmId = sharedFarm['id'] as String;
          final ownerId = sharedFarm['owner_id'] as String;
          final partnerId = sharedFarm['partner_id'] as String?;
          
          debugPrint('[FarmRepository] Found shared farm: $farmId (owner: $ownerId, partner: $partnerId)');
          return sharedFarm as Map<String, dynamic>;
        } else {
          debugPrint('[FarmRepository] No shared farm found for User 1: $user1Id');
        }
      }
      
      // If not in a couple or no shared farm found, look for individual farm
      final response = await _client
          .from('farms')
          .select()
          .or('owner_id.eq.$userId,partner_id.eq.$userId')
          .maybeSingle();
      
      if (response != null) {
        final farmId = response['id'] as String;
        final ownerId = response['owner_id'] as String;
        final partnerId = response['partner_id'] as String?;
        
        debugPrint('[FarmRepository] Found individual farm: $farmId (owner: $ownerId, partner: $partnerId)');
        
        if (ownerId == userId) {
          debugPrint('[FarmRepository] User is the owner of this farm');
        } else if (partnerId == userId) {
          debugPrint('[FarmRepository] User is the partner of this farm');
        }
      } else {
        debugPrint('[FarmRepository] No farm found for user: $userId');
      }
      
      return response as Map<String, dynamic>?;
    }, offlineFallback: null);
  }

  /// Creates a new farm for the current user and returns the row
  Future<Map<String, dynamic>?> createFarmForCurrentUser() async {
    return OfflineHandler.withOfflineHandling(() async {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) throw Exception('User not authenticated');
      final response = await _client
          .from('farms')
          .insert({'owner_id': userId})
          .select()
          .single();
      return response as Map<String, dynamic>;
    }, errorMessage: 'Failed to create farm for current user');
  }

  /// Split a shared farm when unlinking: remove partner_id and create new farm for the unlinked user
  Future<void> splitFarmForUser(String userId) async {
    return OfflineHandler.withOfflineHandling(() async {
      try {
        // If the user is currently a partner on someone else's farm, remove partner_id
        final sharedFarm = await _client
            .from('farms')
            .select()
            .eq('partner_id', userId)
            .maybeSingle();

        if (sharedFarm != null) {
          await _client
              .from('farms')
              .update({'partner_id': null})
              .eq('id', sharedFarm['id']);
        }

        // Create a new farm for the user
        await _client
            .from('farms')
            .insert({'owner_id': userId});
      } catch (e) {
        debugPrint('[FarmRepository] Error splitting farm: $e');
        rethrow;
      }
    });
  }

  /// Connect invitee to inviter's farm after a couple is created
  /// Ensures inviter (user1) has a farm, deletes invitee's existing farm, and sets partner_id
  Future<void> connectToPartnerFarm({required String inviterId, required String inviteeId}) async {
    try {
      // 1) Ensure inviter has a farm
      var inviterFarm = await _client
          .from('farms')
          .select('id')
          .eq('owner_id', inviterId)
          .maybeSingle();

      if (inviterFarm == null) {
        final newFarm = await _client
            .from('farms')
            .insert({'owner_id': inviterId})
            .select()
            .single();
        inviterFarm = newFarm;
      }

      final inviterFarmId = inviterFarm['id'] as String;

      // 2) Delete invitee's farm (tiles first), if any
      final inviteeFarm = await _client
          .from('farms')
          .select('id')
          .eq('owner_id', inviteeId)
          .maybeSingle();
      if (inviteeFarm != null) {
        final inviteeFarmId = inviteeFarm['id'] as String;
        await _client.from('farm_tiles').delete().eq('farm_id', inviteeFarmId);
        await _client.from('farms').delete().eq('id', inviteeFarmId);
      }

      // 3) Update inviter's farm to include invitee as partner
      await _client
          .from('farms')
          .update({'partner_id': inviteeId})
          .eq('id', inviterFarmId);
    } catch (e) {
      debugPrint('[FarmRepository] Error connecting partner farm: $e');
    }
  }
} 