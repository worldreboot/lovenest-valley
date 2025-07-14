import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/memory_garden/seed.dart';
import '../models/memory_garden/couple.dart';
import '../models/memory_garden/water_reply.dart';

class GardenSyncService {
  static const String _seedsTable = 'seeds';
  static const String _syncEventsTable = 'garden_sync_events';
  static const String _conflictResolutionTable = 'garden_conflicts';
  
  final _syncController = StreamController<GardenSyncEvent>.broadcast();
  final _conflictController = StreamController<GardenConflict>.broadcast();
  
  late RealtimeChannel _seedsChannel;
  late RealtimeChannel _syncEventsChannel;
  
  Timer? _batchUpdateTimer;
  final Map<String, SeedUpdate> _pendingUpdates = {};
  
  // Singleton pattern
  static final GardenSyncService _instance = GardenSyncService._internal();
  factory GardenSyncService() => _instance;
  GardenSyncService._internal();
  
  Stream<GardenSyncEvent> get syncEvents => _syncController.stream;
  Stream<GardenConflict> get conflicts => _conflictController.stream;
  
  Future<void> initialize(String coupleId) async {
    await _setupRealtimeChannels(coupleId);
    await _setupConflictResolution(coupleId);
  }
  
  Future<void> _setupRealtimeChannels(String coupleId) async {
    // Enhanced seeds channel with change tracking
    _seedsChannel = SupabaseConfig.client
        .channel('garden_seeds_$coupleId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _seedsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'couple_id',
            value: coupleId,
          ),
          callback: _handleSeedChange,
        );
    
    // Sync events channel for coordination
    _syncEventsChannel = SupabaseConfig.client
        .channel('garden_sync_$coupleId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _syncEventsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'couple_id',
            value: coupleId,
          ),
          callback: _handleSyncEvent,
        );
        
    await _seedsChannel.subscribe();
    await _syncEventsChannel.subscribe();
  }
  
  void _handleSeedChange(PostgresChangePayload payload) {
    try {
      final eventType = _mapChangeEventType(payload.eventType);
      final seedData = payload.newRecord ?? payload.oldRecord;
      
      if (seedData == null) return;
      
      final seed = Seed.fromJson(seedData);
      final event = GardenSyncEvent(
        type: eventType,
        seed: seed,
        timestamp: DateTime.now(),
        userId: seedData['last_updated_by'] as String?,
      );
      
      _syncController.add(event);
      
      // Check for conflicts
      _checkForConflicts(seed, eventType);
      
    } catch (e) {
      debugPrint('Error handling seed change: $e');
    }
  }
  
  void _handleSyncEvent(PostgresChangePayload payload) {
    // Handle coordination events between partners
    final eventData = payload.newRecord;
    if (eventData == null) return;
    
    final eventType = eventData['event_type'] as String;
    
    switch (eventType) {
      case 'batch_update_start':
        _handleBatchUpdateStart(eventData);
        break;
      case 'batch_update_end':
        _handleBatchUpdateEnd(eventData);
        break;
      case 'conflict_resolution':
        _handleConflictResolution(eventData);
        break;
    }
  }
  
  Future<void> _checkForConflicts(Seed seed, GardenSyncEventType eventType) async {
    if (eventType != GardenSyncEventType.created) return;
    
    // Check if another seed was planted at the same position recently
    final conflictingSeeds = await SupabaseConfig.client
        .from(_seedsTable)
        .select()
        .eq('couple_id', seed.coupleId)
        .eq('plot_position', '(${seed.plotPosition.x},${seed.plotPosition.y})')
        .neq('id', seed.id)
        .gte('created_at', DateTime.now().subtract(const Duration(seconds: 30)).toIso8601String());
    
    if (conflictingSeeds.isNotEmpty) {
      final conflict = GardenConflict(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        coupleId: seed.coupleId,
        plotPosition: seed.plotPosition,
        conflictingSeeds: [seed, ...conflictingSeeds.map((s) => Seed.fromJson(s))],
        timestamp: DateTime.now(),
      );
      
      _conflictController.add(conflict);
      await _storeConflict(conflict);
    }
  }
  
  // Optimized batch updates
  Future<void> scheduleSeedUpdate(String seedId, Map<String, dynamic> updates) async {
    _pendingUpdates[seedId] = SeedUpdate(
      seedId: seedId,
      updates: updates,
      timestamp: DateTime.now(),
    );
    
    // Batch updates every 500ms
    _batchUpdateTimer?.cancel();
    _batchUpdateTimer = Timer(const Duration(milliseconds: 500), _processBatchUpdates);
  }
  
  Future<void> _processBatchUpdates() async {
    if (_pendingUpdates.isEmpty) return;
    
    final updates = Map<String, SeedUpdate>.from(_pendingUpdates);
    _pendingUpdates.clear();
    
    try {
      // Signal start of batch update
      await _broadcastSyncEvent('batch_update_start', {
        'update_count': updates.length,
        'update_ids': updates.keys.toList(),
      });
      
      // Process updates efficiently
      for (final update in updates.values) {
        await SupabaseConfig.client
            .from(_seedsTable)
            .update({
              ...update.updates,
              'last_updated_at': DateTime.now().toIso8601String(),
              'last_updated_by': SupabaseConfig.currentUserId,
            })
            .eq('id', update.seedId);
      }
      
      // Signal end of batch update
      await _broadcastSyncEvent('batch_update_end', {
        'update_count': updates.length,
      });
      
    } catch (e) {
      debugPrint('Error processing batch updates: $e');
      // Re-queue failed updates
      _pendingUpdates.addAll(updates);
    }
  }
  
  // Conflict resolution strategies
  Future<void> resolveConflict(GardenConflict conflict, ConflictResolutionStrategy strategy) async {
    switch (strategy) {
      case ConflictResolutionStrategy.firstWins:
        await _resolveFirstWins(conflict);
        break;
      case ConflictResolutionStrategy.merge:
        await _resolveMerge(conflict);
        break;
      case ConflictResolutionStrategy.relocate:
        await _resolveRelocate(conflict);
        break;
    }
  }
  
  Future<void> _resolveFirstWins(GardenConflict conflict) async {
    // Keep the earliest seed, move others to nearby positions
    final sortedSeeds = conflict.conflictingSeeds..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final winner = sortedSeeds.first;
    final losers = sortedSeeds.skip(1).toList();
    
    for (final loser in losers) {
      final newPosition = await _findNearbyEmptyPosition(conflict.plotPosition, conflict.coupleId);
      if (newPosition != null) {
        await SupabaseConfig.client
            .from(_seedsTable)
            .update({
              'plot_position': '(${newPosition.x},${newPosition.y})',
              'last_updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', loser.id);
      }
    }
    
    await _markConflictResolved(conflict.id);
  }
  
  Future<void> _resolveMerge(GardenConflict conflict) async {
    // Combine seeds into a special "merged" seed
    final seeds = conflict.conflictingSeeds;
    final mergedSeed = await _createMergedSeed(seeds, conflict.plotPosition);
    
    // Remove original conflicting seeds
    for (final seed in seeds) {
      await SupabaseConfig.client
          .from(_seedsTable)
          .delete()
          .eq('id', seed.id);
    }
    
    await _markConflictResolved(conflict.id);
  }
  
  Future<void> _resolveRelocate(GardenConflict conflict) async {
    // Move all conflicting seeds to nearby positions
    for (final seed in conflict.conflictingSeeds) {
      final newPosition = await _findNearbyEmptyPosition(conflict.plotPosition, conflict.coupleId);
      if (newPosition != null) {
        await SupabaseConfig.client
            .from(_seedsTable)
            .update({
              'plot_position': '(${newPosition.x},${newPosition.y})',
              'last_updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', seed.id);
      }
    }
    
    await _markConflictResolved(conflict.id);
  }
  
  Future<PlotPosition?> _findNearbyEmptyPosition(PlotPosition center, String coupleId) async {
    // Find nearest empty position in expanding spiral
    for (int radius = 1; radius <= 5; radius++) {
      for (int x = -radius; x <= radius; x++) {
        for (int y = -radius; y <= radius; y++) {
          if (x.abs() != radius && y.abs() != radius) continue;
          
          final newX = center.x + x;
          final newY = center.y + y;
          
          if (newX < 0 || newX >= 10 || newY < 0 || newY >= 10) continue;
          
          final existingSeeds = await SupabaseConfig.client
              .from(_seedsTable)
              .select('id')
              .eq('couple_id', coupleId)
              .eq('plot_position', '($newX,$newY)')
              .limit(1);
          
          if (existingSeeds.isEmpty) {
            return PlotPosition(newX, newY);
          }
        }
      }
    }
    
    return null;
  }
  
  Future<void> _broadcastSyncEvent(String eventType, Map<String, dynamic> data) async {
    await SupabaseConfig.client.from(_syncEventsTable).insert({
      'couple_id': data['couple_id'],
      'event_type': eventType,
      'event_data': jsonEncode(data),
      'created_at': DateTime.now().toIso8601String(),
      'created_by': SupabaseConfig.currentUserId,
    });
  }
  
  GardenSyncEventType _mapChangeEventType(PostgresChangeEvent event) {
    switch (event) {
      case PostgresChangeEvent.insert:
        return GardenSyncEventType.created;
      case PostgresChangeEvent.update:
        return GardenSyncEventType.updated;
      case PostgresChangeEvent.delete:
        return GardenSyncEventType.deleted;
      default:
        return GardenSyncEventType.updated;
    }
  }
  
  Future<void> _setupConflictResolution(String coupleId) async {
    // Implementation for conflict resolution setup
  }
  
  void _handleBatchUpdateStart(Map<String, dynamic> eventData) {
    // Handle batch update coordination
  }
  
  void _handleBatchUpdateEnd(Map<String, dynamic> eventData) {
    // Handle batch update completion
  }
  
  void _handleConflictResolution(Map<String, dynamic> eventData) {
    // Handle conflict resolution events
  }
  
  Future<void> _storeConflict(GardenConflict conflict) async {
    // Store conflict in database
  }
  
  Future<Seed> _createMergedSeed(List<Seed> seeds, PlotPosition position) async {
    // Create a merged seed from multiple conflicting seeds
    throw UnimplementedError();
  }
  
  Future<void> _markConflictResolved(String conflictId) async {
    // Mark conflict as resolved
  }
  
  void dispose() {
    _syncController.close();
    _conflictController.close();
    _batchUpdateTimer?.cancel();
    _seedsChannel.unsubscribe();
    _syncEventsChannel.unsubscribe();
  }
}

// Data classes
class GardenSyncEvent {
  final GardenSyncEventType type;
  final Seed seed;
  final DateTime timestamp;
  final String? userId;
  
  GardenSyncEvent({
    required this.type,
    required this.seed,
    required this.timestamp,
    this.userId,
  });
}

enum GardenSyncEventType { created, updated, deleted }

class GardenConflict {
  final String id;
  final String coupleId;
  final PlotPosition plotPosition;
  final List<Seed> conflictingSeeds;
  final DateTime timestamp;
  
  GardenConflict({
    required this.id,
    required this.coupleId,
    required this.plotPosition,
    required this.conflictingSeeds,
    required this.timestamp,
  });
}

enum ConflictResolutionStrategy { firstWins, merge, relocate }

class SeedUpdate {
  final String seedId;
  final Map<String, dynamic> updates;
  final DateTime timestamp;
  
  SeedUpdate({
    required this.seedId,
    required this.updates,
    required this.timestamp,
  });
} 