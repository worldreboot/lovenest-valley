import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_config.dart';
import '../models/chest_storage.dart';

class ChestStorageService {
  static const String _tableName = 'game_objects';
  static const String _chestType = 'chest';
  
  final SupabaseClient _client = SupabaseConfig.client;
  final _uuid = const Uuid();
  
  // Real-time subscription management
  RealtimeChannel? _chestChannel;
  StreamController<ChestStorage>? _chestUpdatesController;
  String? _activeCoupleId;
  
  // Singleton pattern
  static final ChestStorageService _instance = ChestStorageService._internal();
  factory ChestStorageService() => _instance;
  ChestStorageService._internal();

  /// Initialize real-time subscriptions for chest updates
  Future<void> initializeRealtime(String coupleId) async {
    debugPrint('[ChestStorageService] Initializing real-time for couple: $coupleId');
    // Idempotent: keep a single controller and avoid breaking existing listeners
    _chestUpdatesController ??= StreamController<ChestStorage>.broadcast();

    // If already initialized for this couple, do nothing
    if (_activeCoupleId == coupleId && _chestChannel != null) {
      return;
    }

    // If switching couples, clean up previous channel
    try {
      await _chestChannel?.unsubscribe();
    } catch (_) {}

    _activeCoupleId = coupleId;
    _chestChannel = _client.channel('chest_storage_$coupleId');
    
    _chestChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: _tableName,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'couple_id',
        value: coupleId,
      ),
      callback: _handleChestChange,
    );
    
    await _chestChannel!.subscribe();
    debugPrint('[ChestStorageService] Real-time subscription active for chests');
  }

  /// Handle real-time chest updates
  void _handleChestChange(PostgresChangePayload payload) {
    try {
      debugPrint('[ChestStorageService] Received chest update: ${payload.eventType}');

      if (payload.eventType == PostgresChangeEvent.insert ||
          payload.eventType == PostgresChangeEvent.update) {
        final record = payload.newRecord;
        if (record['type'] == _chestType) {
          final chest = ChestStorage.fromJson(record);
          _chestUpdatesController?.add(chest);
        }
      } else if (payload.eventType == PostgresChangeEvent.delete) {
        debugPrint('[ChestStorageService] Chest deleted');
      }
    } catch (e) {
      debugPrint('[ChestStorageService] Error handling chest change: $e');
    }
  }

  /// Stream of chest updates from other users
  Stream<ChestStorage> get chestUpdates {
    if (_chestUpdatesController == null) {
      throw Exception('ChestStorageService not initialized. Call initializeRealtime() first.');
    }
    return _chestUpdatesController!.stream;
  }

  /// Create a new chest at the specified position
  Future<ChestStorage> createChest({
    required String coupleId,
    required Position position,
    String? name,
    int maxCapacity = 20,
  }) async {
    debugPrint('[ChestStorageService] Creating chest at position: $position');
    
    final chest = ChestStorage(
      id: _uuid.v4(),
      coupleId: coupleId,
      position: position,
      items: [],
      maxCapacity: maxCapacity,
      name: name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      version: 1,
      syncStatus: 'synced',
    );

    final chestData = chest.toJson();
    chestData['last_updated_by'] = SupabaseConfig.currentUserId;

    try {
      final response = await _client
          .from(_tableName)
          .insert(chestData)
          .select()
          .single();

      debugPrint('[ChestStorageService] Chest created successfully');
      return ChestStorage.fromJson(response);
    } catch (e) {
      debugPrint('[ChestStorageService] Error creating chest: $e');
      rethrow;
    }
  }

  /// Get all chests for a couple
  Future<List<ChestStorage>> getChests(String coupleId) async {
    debugPrint('[ChestStorageService] Fetching chests for couple: $coupleId');
    
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('couple_id', coupleId)
          .eq('type', _chestType)
          .order('created_at');

      final chests = response.map<ChestStorage>((json) => ChestStorage.fromJson(json)).toList();
      debugPrint('[ChestStorageService] Found ${chests.length} chests');
      return chests;
    } catch (e) {
      debugPrint('[ChestStorageService] Error fetching chests: $e');
      rethrow;
    }
  }

  /// Get a specific chest by ID
  Future<ChestStorage?> getChest(String chestId) async {
    debugPrint('[ChestStorageService] Fetching chest: $chestId');
    
    try {
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
    } catch (e) {
      debugPrint('[ChestStorageService] Error fetching chest: $e');
      rethrow;
    }
  }

  /// Update chest contents with optimistic locking
  Future<ChestStorage> updateChest(ChestStorage chest) async {
    debugPrint('[ChestStorageService] Updating chest: ${chest.id}');
    
    final updatedChest = chest.copyWith(
      updatedAt: DateTime.now(),
      version: chest.version + 1,
    );

    final chestData = updatedChest.toJson();
    chestData['last_updated_by'] = SupabaseConfig.currentUserId;

    try {
      final response = await _client
          .from(_tableName)
          .update(chestData)
          .eq('id', chest.id)
          .eq('version', chest.version) // Optimistic locking
          .select()
          .maybeSingle();

      if (response == null) {
        // No rows matched: version mismatch or missing row
        throw Exception('Chest was modified by another user or not found. Please refresh and try again.');
      }

      debugPrint('[ChestStorageService] Chest updated successfully');
      final parsed = ChestStorage.fromJson(response);
      // Emit locally so current client UIs update immediately (partner will get realtime)
      try {
        _chestUpdatesController?.add(parsed);
      } catch (_) {}
      return parsed;
    } catch (e) {
      debugPrint('[ChestStorageService] Error updating chest: $e');
      rethrow;
    }
  }

  /// Add an item to a chest
  Future<ChestStorage> addItemToChest(String chestId, ChestItem item) async {
    debugPrint('[ChestStorageService] Adding item to chest: $chestId');
    
    final chest = await getChest(chestId);
    if (chest == null) {
      throw Exception('Chest not found');
    }

    final updatedChest = chest.addItem(item);
    return await updateChest(updatedChest);
  }

  /// Remove an item from a chest
  Future<ChestStorage> removeItemFromChest(String chestId, String itemId, {int quantity = 1}) async {
    debugPrint('[ChestStorageService] Removing item from chest: $chestId');
    
    final chest = await getChest(chestId);
    if (chest == null) {
      throw Exception('Chest not found');
    }

    final updatedChest = chest.removeItem(itemId, quantity: quantity);
    return await updateChest(updatedChest);
  }

  /// Move items between chests
  Future<void> moveItemsBetweenChests({
    required String fromChestId,
    required String toChestId,
    required String itemId,
    required int quantity,
  }) async {
    debugPrint('[ChestStorageService] Moving items between chests: $fromChestId -> $toChestId');
    
    // Use a transaction to ensure atomicity
    await _client.rpc('move_items_between_chests', params: {
      'from_chest_id': fromChestId,
      'to_chest_id': toChestId,
      'item_id': itemId,
      'quantity': quantity,
      'user_id': SupabaseConfig.currentUserId,
    });
  }

  /// Delete a chest
  Future<void> deleteChest(String chestId) async {
    debugPrint('[ChestStorageService] Deleting chest: $chestId');
    
    try {
      await _client
          .from(_tableName)
          .delete()
          .eq('id', chestId)
          .eq('type', _chestType);

      debugPrint('[ChestStorageService] Chest deleted successfully');
    } catch (e) {
      debugPrint('[ChestStorageService] Error deleting chest: $e');
      rethrow;
    }
  }

  /// Find chests near a position (for interaction)
  Future<List<ChestStorage>> findChestsNearPosition(Position position, {double radius = 50.0}) async {
    debugPrint('[ChestStorageService] Finding chests near position: $position');
    
    try {
      // Use a simple distance calculation for now
      // In a real implementation, you might want to use PostGIS for better performance
      final chests = await getChests(SupabaseConfig.currentUserId ?? '');
      
      return chests.where((chest) {
        final distance = _calculateDistance(position, chest.position);
        return distance <= radius;
      }).toList();
    } catch (e) {
      debugPrint('[ChestStorageService] Error finding nearby chests: $e');
      rethrow;
    }
  }

  /// Calculate distance between two points
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