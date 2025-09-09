import 'package:lovenest_valley/config/supabase_config.dart';
import 'package:flutter/foundation.dart';

class FarmService {
  /// Get the current user's farm ID
  static Future<String?> getCurrentUserFarmId() async {
    try {
      debugPrint('[FarmService] 🔄 Starting farm ID retrieval...');
      
      final userId = SupabaseConfig.currentUserId;
      debugPrint('[FarmService] 👤 Current user ID: $userId');
      
      if (userId == null) {
        debugPrint('[FarmService] ❌ No current user ID - user not authenticated');
        return null;
      }

      debugPrint('[FarmService] 🔍 Looking for existing farm for user: $userId');
      
      // First try to get existing farm where user is owner
      final existingFarmResponse = await SupabaseConfig.client
          .from('farms')
          .select('id')
          .eq('owner_id', userId)
          .maybeSingle();

      debugPrint('[FarmService] 📊 Existing farm response: $existingFarmResponse');

      if (existingFarmResponse != null) {
        final farmId = existingFarmResponse['id'] as String;
        debugPrint('[FarmService] ✅ Found existing farm: $farmId');
        return farmId;
      }

      debugPrint('[FarmService] ➕ No existing farm found, creating new farm...');
      
      // If no farm exists, create one for the user
      final newFarmResponse = await SupabaseConfig.client
          .from('farms')
          .insert({
            'owner_id': userId,
          })
          .select('id')
          .single();

      debugPrint('[FarmService] 📊 New farm response: $newFarmResponse');

      final newFarmId = newFarmResponse['id'] as String;
      debugPrint('[FarmService] ✅ Created new farm: $newFarmId');
      return newFarmId;
    } catch (e) {
      debugPrint('[FarmService] ❌ Error getting user farm: $e');
      debugPrint('[FarmService] ❌ Error type: ${e.runtimeType}');
      
      // Check for specific error types
      if (e.toString().contains('auth')) {
        debugPrint('[FarmService] ❌ Authentication error detected');
      }
      if (e.toString().contains('Network is unreachable')) {
        debugPrint('[FarmService] ❌ Network connectivity issue detected');
        debugPrint('[FarmService] 💡 Try checking your internet connection');
      }
      if (e.toString().contains('SocketException')) {
        debugPrint('[FarmService] ❌ Socket connection failed');
        debugPrint('[FarmService] 💡 This usually means network connectivity issues');
      }
      
      return null;
    }
  }

  /// Get farm details including owner and partner
  static Future<Map<String, dynamic>?> getFarmDetails(String farmId) async {
    try {
      final response = await SupabaseConfig.client
          .from('farms')
          .select('*')
          .eq('id', farmId)
          .maybeSingle();

      if (response != null) {
        debugPrint('[FarmService] ✅ Found farm details for: $farmId');
        return response;
      } else {
        debugPrint('[FarmService] ❌ No farm found with ID: $farmId');
        return null;
      }
    } catch (e) {
      debugPrint('[FarmService] ❌ Error getting farm details: $e');
      return null;
    }
  }

  /// Check if current user owns the farm
  static Future<bool> isCurrentUserFarmOwner(String farmId) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return false;

      final farmDetails = await getFarmDetails(farmId);
      if (farmDetails == null) return false;

      final ownerId = farmDetails['owner_id'] as String;
      return ownerId == userId;
    } catch (e) {
      debugPrint('[FarmService] ❌ Error checking farm ownership: $e');
      return false;
    }
  }

  /// Get all farms for the current user (as owner or partner)
  static Future<List<Map<String, dynamic>>> getUserFarms() async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return [];

      final response = await SupabaseConfig.client
          .from('farms')
          .select('*')
          .or('owner_id.eq.$userId,partner_id.eq.$userId');

      debugPrint('[FarmService] ✅ Found ${response.length} farms for user');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[FarmService] ❌ Error getting user farms: $e');
      return [];
    }
  }
} 
