import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_config.dart';
import '../models/chest_storage.dart';
import '../services/garden_repository.dart';

class ChestStorageService {
  static const String _tableName = 'game_objects';
  static const String _chestType = 'chest';
  
  final SupabaseClient _client = SupabaseConfig.client;
  final _uuid = const Uuid();
  
  // Real-time subscription management
  RealtimeChannel? _chestChannel;
  StreamController<ChestStorage>? _chestUpdatesController;
  String? _activeCoupleId;

  /// Initialize real-time subscriptions for chest updates
  Future<void> initializeRealtimeForCurrentUser() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return;
  }

  /// Initialize real-time subscriptions for a specific couple
  Future<void> initializeRealtime(String coupleId) async {
    try {
      // Only initialize if we have a new couple ID
      if (_activeCoupleId == coupleId) return;
      _activeCoupleId = coupleId;

      // Clean up existing subscription
      await _chestChannel?.unsubscribe();
      _chestUpdatesController?.close();

      // Create new stream controller
      _chestUpdatesController = StreamController<ChestStorage>.broadcast();

      // Subscribe to real-time updates for this couple's chests
      _chestChannel = _client
          .channel('chest_updates_$coupleId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: _tableName,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'couple_id',
              value: coupleId,
            ),
            callback: (payload) async {
              debugPrint('[ChestStorageService] Real-time update received: ${payload.eventType}');
              
              if (payload.newRecord != null) {
                try {
                  final chest = ChestStorage.fromJson(payload.newRecord);
                  _chestUpdatesController?.add(chest);
                } catch (e) {
                  debugPrint('[ChestStorageService] Error parsing real-time update: $e');
                }
              }
            },
          );

      await _chestChannel?.subscribe();
      debugPrint('[ChestStorageService] Real-time subscription initialized for couple: $coupleId');
    } catch (e) {
      debugPrint('[ChestStorageService] Error initializing real-time: $e');
    }
  }

  /// Initialize real-time subscriptions for current user (legacy method)
  Future<void> initializeRealtimeForCurrentUserLegacy() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return;

    try {
      // Get user's couple
      final couple = await GardenRepository().getUserCouple();
      if (couple == null) return;

      // Only initialize if we have a new couple ID
      if (_activeCoupleId == couple.id) return;
      _activeCoupleId = couple.id;

      // Clean up existing subscription
      await _chestChannel?.unsubscribe();
      _chestUpdatesController?.close();

      // Create new stream controller
      _chestUpdatesController = StreamController<ChestStorage>.broadcast();

      // Subscribe to real-time updates for this couple's chests
      _chestChannel = _client
          .channel('chest_updates_${couple.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: _tableName,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'couple_id',
              value: couple.id,
            ),
            callback: (payload) async {
              debugPrint('[ChestStorageService] Real-time update received: ${payload.eventType}');
              
              if (payload.newRecord != null) {
                try {
                  final chest = ChestStorage.fromJson(payload.newRecord);
                  _chestUpdatesController?.add(chest);
                } catch (e) {
                  debugPrint('[ChestStorageService] Error parsing real-time update: $e');
                }
              }
            },
          );

      await _chestChannel?.subscribe();
      debugPrint('[ChestStorageService] Real-time subscription initialized for couple: ${couple.id}');
    } catch (e) {
      debugPrint('[ChestStorageService] Error initializing real-time: $e');
    }
  }

  /// Get stream of chest updates
  Stream<ChestStorage>? get chestUpdates => _chestUpdatesController?.stream;
  
  /// Get stream of chest updates (non-nullable for compatibility)
  Stream<ChestStorage> get chestUpdatesStream => _chestUpdatesController?.stream ?? const Stream.empty();

  /// Create a new chest
  Future<ChestStorage> createChest({
    required String userId,
    required Position position,
    String? name,
    int maxCapacity = 20,
    String? coupleId,
  }) async {
    return await SupabaseConfig.safeDbOperation(
      () async {
        final chest = ChestStorage(
          id: _uuid.v4(),
          userId: userId,
          coupleId: coupleId,
          position: position,
          name: name ?? 'Chest',
          maxCapacity: maxCapacity,
          items: <ChestItem>[],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          version: 1,
          syncStatus: 'synced',
        );

        final chestData = chest.toJson();
        chestData['last_updated_by'] = SupabaseConfig.currentUserId;

        final response = await _client
            .from(_tableName)
            .insert(chestData)
            .select()
            .single();

        debugPrint('[ChestStorageService] Chest created successfully');
        return ChestStorage.fromJson(response);
      },
      operationName: 'create chest',
    );
  }

  /// Create a chest for the current user (automatically determines ownership)
  Future<ChestStorage> createChestForCurrentUser({
    required Position position,
    String? name,
    int maxCapacity = 20,
  }) async {
    return await SupabaseConfig.safeDbOperation(
      () async {
        final currentUserId = SupabaseConfig.currentUserId;
        if (currentUserId == null) {
          throw Exception('User not authenticated');
        }

        try {
          // Check if user is in a couple
          final couple = await GardenRepository().getUserCouple();
          if (couple != null) {
            // Create couple chest
            return await createChest(
              userId: currentUserId,
              coupleId: couple.id,
              position: position,
              name: name,
              maxCapacity: maxCapacity,
            );
          } else {
            // Create individual user chest
            return await createChest(
              userId: currentUserId,
              position: position,
              name: name,
              maxCapacity: maxCapacity,
            );
          }
        } catch (e) {
          debugPrint('[ChestStorageService] Error creating chest for current user: $e');
          rethrow;
        }
      },
      operationName: 'create chest for current user',
    );
  }

  /// Get all chests for a couple
  Future<List<ChestStorage>> getChests(String coupleId) async {
    debugPrint('[ChestStorageService] Fetching chests for couple: $coupleId');
    
    return await SupabaseConfig.safeDbOperation(
      () async {
        final response = await _client
            .from(_tableName)
            .select()
            .eq('couple_id', coupleId)
            .eq('type', _chestType)
            .order('created_at');

        final chests = response.map<ChestStorage>((json) => ChestStorage.fromJson(json)).toList();
        debugPrint('[ChestStorageService] Found ${chests.length} chests');
        return chests;
      },
      operationName: 'get chests for couple',
    );
  }

  /// Get all chests for an individual user (when not in a couple)
  Future<List<ChestStorage>> getUserChests(String userId) async {
    debugPrint('[ChestStorageService] Fetching chests for individual user: $userId');
    
    return await SupabaseConfig.safeDbOperation(
      () async {
        final response = await _client
            .from(_tableName)
            .select()
            .eq('user_id', userId)
            .eq('type', _chestType)
            .order('created_at');

        final chests = response.map<ChestStorage>((json) => ChestStorage.fromJson(json)).toList();
        debugPrint('[ChestStorageService] Found ${chests.length} individual user chests');
        return chests;
      },
      operationName: 'get user chests',
    );
  }

  /// Get all chests for the current user (couple or individual)
  Future<List<ChestStorage>> getCurrentUserChests() async {
    return await SupabaseConfig.safeDbOperation(
      () async {
        final userId = SupabaseConfig.currentUserId;
        if (userId == null) return [];

        try {
          // First try to get couple chests
          final couple = await GardenRepository().getUserCouple();
          if (couple != null) {
            return await getChests(couple.id);
          } else {
            // Fallback to individual user chests
            return await getUserChests(userId);
          }
        } catch (e) {
          debugPrint('[ChestStorageService] Error getting current user chests: $e');
          return [];
        }
      },
      operationName: 'get current user chests',
    );
  }

  /// Get a specific chest by ID
  Future<ChestStorage?> getChest(String chestId) async {
    debugPrint('[ChestStorageService] Fetching chest: $chestId');
    
    return await SupabaseConfig.safeDbOperation(
      () async {
        final response = await _client
            .from(_tableName)
            .select()
            .eq('id', chestId)
            .eq('type', _chestType)
            .maybeSingle();

        if (response == null) {
          debugPrint('[ChestStorageService] Chest not found: $chestId');
          return null;
        }

        return ChestStorage.fromJson(response);
      },
      operationName: 'get chest by ID',
    );
  }

  /// Update chest contents with optimistic locking
  Future<ChestStorage> updateChest(ChestStorage chest) async {
    debugPrint('[ChestStorageService] Updating chest: ${chest.id}');
    
    return await SupabaseConfig.safeDbOperation(
      () async {
        final updatedChest = chest.copyWith(
          updatedAt: DateTime.now(),
          version: chest.version + 1,
          syncStatus: 'synced',
        );

        final chestData = updatedChest.toJson();
        chestData['last_updated_by'] = SupabaseConfig.currentUserId;

        final response = await _client
            .from(_tableName)
            .update(chestData)
            .eq('id', chest.id)
            .eq('version', chest.version) // Optimistic locking
            .select()
            .maybeSingle();

        if (response == null) {
          throw Exception('Chest update failed - version conflict or chest not found');
        }

        debugPrint('[ChestStorageService] Chest updated successfully');
        return ChestStorage.fromJson(response);
      },
      operationName: 'update chest',
    );
  }

  /// Delete a chest
  Future<bool> deleteChest(String chestId) async {
    debugPrint('[ChestStorageService] Deleting chest: $chestId');
    
    return await SupabaseConfig.safeDbOperation(
      () async {
        await _client
            .from(_tableName)
            .delete()
            .eq('id', chestId)
            .eq('type', _chestType);

        debugPrint('[ChestStorageService] Chest deleted successfully');
        return true;
      },
      operationName: 'delete chest',
    );
  }

  /// Add item to chest
  Future<bool> addItemToChest(String chestId, String itemId, int quantity) async {
    return await SupabaseConfig.safeDbOperation(
      () async {
        // Get current chest
        final chest = await getChest(chestId);
        if (chest == null) return false;

        // Add item to chest
        final updatedItems = List<ChestItem>.from(chest.items);
        final existingItemIndex = updatedItems.indexWhere((item) => item.id == itemId);
        
        if (existingItemIndex >= 0) {
          // Update existing item quantity
          final existingItem = updatedItems[existingItemIndex];
          updatedItems[existingItemIndex] = existingItem.copyWith(
            quantity: existingItem.quantity + quantity,
          );
        } else {
          // Add new item
          updatedItems.add(ChestItem(
            id: itemId,
            name: itemId, // Use itemId as name for now
            quantity: quantity,
          ));
        }

        final updatedChest = chest.copyWith(
          items: updatedItems,
          updatedAt: DateTime.now(),
          version: chest.version + 1,
        );

        await updateChest(updatedChest);
        return true;
      },
      operationName: 'add item to chest',
    );
  }

  /// Remove item from chest
  Future<bool> removeItemFromChest(String chestId, String itemId, int quantity) async {
    return await SupabaseConfig.safeDbOperation(
      () async {
        // Get current chest
        final chest = await getChest(chestId);
        if (chest == null) return false;

        // Remove item from chest
        final updatedItems = List<ChestItem>.from(chest.items);
        final existingItemIndex = updatedItems.indexWhere((item) => item.id == itemId);
        
        if (existingItemIndex >= 0) {
          final existingItem = updatedItems[existingItemIndex];
          final newQuantity = (existingItem.quantity - quantity).clamp(0, double.infinity).toInt();
          
          if (newQuantity == 0) {
            // Remove item completely
            updatedItems.removeAt(existingItemIndex);
          } else {
            // Update quantity
            updatedItems[existingItemIndex] = existingItem.copyWith(quantity: newQuantity);
          }
        }

        final updatedChest = chest.copyWith(
          items: updatedItems,
          updatedAt: DateTime.now(),
          version: chest.version + 1,
        );

        await updateChest(updatedChest);
        return true;
      },
      operationName: 'remove item from chest',
    );
  }

  /// Get chests near a position
  Future<List<ChestStorage>> getChestsNearPosition(Position position, double radius) async {
    return await SupabaseConfig.safeDbOperation(
      () async {
        final allChests = await getCurrentUserChests();
        final nearbyChests = <ChestStorage>[];

        for (final chest in allChests) {
          final distance = _calculateDistance(position, chest.position);
          if (distance <= radius) {
            nearbyChests.add(chest);
          }
        }

        return nearbyChests;
      },
      operationName: 'get chests near position',
    );
  }

  /// Calculate distance between two positions
  double _calculateDistance(Position a, Position b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  /// Clean up resources
  void dispose() {
    _chestChannel?.unsubscribe();
    _chestUpdatesController?.close();
    debugPrint('[ChestStorageService] Disposed');
  }
}