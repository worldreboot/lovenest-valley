import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../services/garden_repository.dart';
import '../services/garden_sync_service.dart';
import '../models/memory_garden/seed.dart';
import '../models/memory_garden/couple.dart';
import '../models/memory_garden/water_reply.dart';

// Enhanced repository with offline support
final enhancedGardenRepositoryProvider = Provider<GardenRepository>((ref) {
  return const GardenRepository();
});

// Sync service provider
final gardenSyncServiceProvider = Provider<GardenSyncService>((ref) {
  return GardenSyncService();
});

// Offline cache provider
final gardenOfflineCacheProvider = Provider<GardenOfflineCache>((ref) {
  return GardenOfflineCache();
});

// Enhanced garden seeds provider with offline support
final enhancedGardenSeedsProvider = StreamProvider<List<Seed>>((ref) {
  final syncService = ref.watch(gardenSyncServiceProvider);
  final offlineCache = ref.watch(gardenOfflineCacheProvider);
  final repository = ref.watch(enhancedGardenRepositoryProvider);
  
  return _createEnhancedSeedsStream(syncService, offlineCache, repository);
});

// Real-time sync events provider
final gardenSyncEventsProvider = StreamProvider<GardenSyncEvent>((ref) {
  final syncService = ref.watch(gardenSyncServiceProvider);
  return syncService.syncEvents;
});

// Conflict resolution provider
final gardenConflictsProvider = StreamProvider<GardenConflict>((ref) {
  final syncService = ref.watch(gardenSyncServiceProvider);
  return syncService.conflicts;
});

// Optimized seed update provider
final seedUpdateProvider = Provider<SeedUpdateManager>((ref) {
  final syncService = ref.watch(gardenSyncServiceProvider);
  return SeedUpdateManager(syncService);
});

// Garden state provider with offline support
final gardenStateProvider = StateNotifierProvider<GardenStateNotifier, GardenState>((ref) {
  final syncService = ref.watch(gardenSyncServiceProvider);
  final offlineCache = ref.watch(gardenOfflineCacheProvider);
  return GardenStateNotifier(syncService, offlineCache);
});

// Network connectivity provider
final networkConnectivityProvider = StreamProvider<bool>((ref) {
  return _createConnectivityStream();
});

// Pending sync actions provider
final pendingSyncActionsProvider = StateNotifierProvider<PendingSyncNotifier, List<SyncAction>>((ref) {
  final offlineCache = ref.watch(gardenOfflineCacheProvider);
  return PendingSyncNotifier(offlineCache);
});

// Helper functions and classes
Stream<List<Seed>> _createEnhancedSeedsStream(
  GardenSyncService syncService,
  GardenOfflineCache offlineCache,
  GardenRepository repository,
) async* {
  // Start with cached data
  final cachedSeeds = await offlineCache.getCachedSeeds();
  yield cachedSeeds;
  
  // Then stream real-time updates
  try {
    await for (final seeds in repository.getGardenStream()) {
      // Update cache
      await offlineCache.cacheSeeds(seeds);
      yield seeds;
    }
  } catch (e) {
    // If streaming fails, yield cached data
    yield cachedSeeds;
  }
}

Stream<bool> _createConnectivityStream() async* {
  // Simple connectivity check - in a real app, use connectivity_plus package
  yield true; // Placeholder
}

// Offline cache implementation
class GardenOfflineCache {
  static const String _seedsCacheKey = 'garden_seeds_cache';
  static const String _pendingActionsKey = 'pending_sync_actions';
  
  Future<List<Seed>> getCachedSeeds() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_seedsCacheKey);
    
    if (cachedJson == null) return [];
    
    try {
      final List<dynamic> seedsJson = jsonDecode(cachedJson);
      return seedsJson.map((json) => Seed.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }
  
  Future<void> cacheSeeds(List<Seed> seeds) async {
    final prefs = await SharedPreferences.getInstance();
    final seedsJson = seeds.map((seed) => seed.toJson()).toList();
    await prefs.setString(_seedsCacheKey, jsonEncode(seedsJson));
  }
  
  Future<void> cachePendingAction(SyncAction action) async {
    final prefs = await SharedPreferences.getInstance();
    final existingJson = prefs.getString(_pendingActionsKey) ?? '[]';
    final List<dynamic> existingActions = jsonDecode(existingJson);
    
    existingActions.add(action.toJson());
    await prefs.setString(_pendingActionsKey, jsonEncode(existingActions));
  }
  
  Future<List<SyncAction>> getPendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    final actionsJson = prefs.getString(_pendingActionsKey) ?? '[]';
    
    try {
      final List<dynamic> actions = jsonDecode(actionsJson);
      return actions.map((json) => SyncAction.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }
  
  Future<void> clearPendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingActionsKey);
  }
}

// Seed update manager for batching
class SeedUpdateManager {
  final GardenSyncService _syncService;
  final Map<String, Timer> _debounceTimers = {};
  
  SeedUpdateManager(this._syncService);
  
  void updateSeed(String seedId, Map<String, dynamic> updates) {
    // Debounce updates to prevent excessive API calls
    _debounceTimers[seedId]?.cancel();
    _debounceTimers[seedId] = Timer(const Duration(milliseconds: 300), () {
      _syncService.scheduleSeedUpdate(seedId, updates);
      _debounceTimers.remove(seedId);
    });
  }
  
  void updateSeedImmediately(String seedId, Map<String, dynamic> updates) {
    _debounceTimers[seedId]?.cancel();
    _debounceTimers.remove(seedId);
    _syncService.scheduleSeedUpdate(seedId, updates);
  }
  
  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
  }
}

// Garden state notifier
class GardenStateNotifier extends StateNotifier<GardenState> {
  final GardenSyncService _syncService;
  final GardenOfflineCache _offlineCache;
  late StreamSubscription _syncSubscription;
  
  GardenStateNotifier(this._syncService, this._offlineCache)
      : super(GardenState.initial()) {
    _initializeState();
  }
  
  void _initializeState() {
    _syncSubscription = _syncService.syncEvents.listen(
      (event) => _handleSyncEvent(event),
      onError: (error) => _handleSyncError(error),
    );
  }
  
  void _handleSyncEvent(GardenSyncEvent event) {
    switch (event.type) {
      case GardenSyncEventType.created:
        state = state.copyWith(
          lastSyncTime: event.timestamp,
          isSyncing: false,
        );
        break;
      case GardenSyncEventType.updated:
        state = state.copyWith(
          lastSyncTime: event.timestamp,
          isSyncing: false,
        );
        break;
      case GardenSyncEventType.deleted:
        state = state.copyWith(
          lastSyncTime: event.timestamp,
          isSyncing: false,
        );
        break;
    }
  }
  
  void _handleSyncError(dynamic error) {
    state = state.copyWith(
      isSyncing: false,
      syncError: error.toString(),
    );
  }
  
  void startSync() {
    state = state.copyWith(isSyncing: true, syncError: null);
  }
  
  void stopSync() {
    state = state.copyWith(isSyncing: false);
  }
  
  @override
  void dispose() {
    _syncSubscription.cancel();
    super.dispose();
  }
}

// Pending sync actions notifier
class PendingSyncNotifier extends StateNotifier<List<SyncAction>> {
  final GardenOfflineCache _offlineCache;
  
  PendingSyncNotifier(this._offlineCache) : super([]) {
    _loadPendingActions();
  }
  
  void _loadPendingActions() async {
    final actions = await _offlineCache.getPendingActions();
    state = actions;
  }
  
  void addPendingAction(SyncAction action) async {
    await _offlineCache.cachePendingAction(action);
    state = [...state, action];
  }
  
  void removePendingAction(String actionId) async {
    state = state.where((action) => action.id != actionId).toList();
    // Update cache
    await _offlineCache.clearPendingActions();
    for (final action in state) {
      await _offlineCache.cachePendingAction(action);
    }
  }
  
  void clearAllPendingActions() async {
    await _offlineCache.clearPendingActions();
    state = [];
  }
}

// Data classes
class GardenState {
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final String? syncError;
  final bool isOnline;
  
  GardenState({
    required this.isSyncing,
    this.lastSyncTime,
    this.syncError,
    required this.isOnline,
  });
  
  factory GardenState.initial() {
    return GardenState(
      isSyncing: false,
      isOnline: true,
    );
  }
  
  GardenState copyWith({
    bool? isSyncing,
    DateTime? lastSyncTime,
    String? syncError,
    bool? isOnline,
  }) {
    return GardenState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      syncError: syncError ?? this.syncError,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

class SyncAction {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retryCount;
  
  SyncAction({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
  });
  
  factory SyncAction.fromJson(Map<String, dynamic> json) {
    return SyncAction(
      id: json['id'],
      type: json['type'],
      data: json['data'],
      timestamp: DateTime.parse(json['timestamp']),
      retryCount: json['retryCount'] ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'retryCount': retryCount,
    };
  }
  
  SyncAction copyWith({
    String? id,
    String? type,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    int? retryCount,
  }) {
    return SyncAction(
      id: id ?? this.id,
      type: type ?? this.type,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
    );
  }
} 
