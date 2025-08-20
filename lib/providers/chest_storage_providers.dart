import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chest_storage.dart';
import '../models/memory_garden/couple.dart';
import '../services/chest_storage_service.dart';
import '../services/garden_repository.dart';

// Service provider
final chestStorageServiceProvider = Provider<ChestStorageService>((ref) {
  return ChestStorageService();
});

// Repository provider for getting couple info
final gardenRepositoryProvider = Provider<GardenRepository>((ref) {
  return GardenRepository();
});

// User couple provider
final userCoupleProvider = FutureProvider<Couple?>((ref) async {
  final repository = ref.read(gardenRepositoryProvider);
  return await repository.getUserCouple();
});

// Chests provider - fetches all chests for the current couple
final chestsProvider = FutureProvider<List<ChestStorage>>((ref) async {
  final couple = await ref.read(userCoupleProvider.future);
  if (couple == null) return [];
  
  final service = ref.read(chestStorageServiceProvider);
  return await service.getChests(couple.id);
});

// Real-time chest updates provider
final chestUpdatesProvider = StreamProvider<List<ChestStorage>>((ref) async* {
  final couple = await ref.read(userCoupleProvider.future);
  if (couple == null) {
    yield [];
    return;
  }
  
  final service = ref.read(chestStorageServiceProvider);
  
  // Initialize real-time
  await service.initializeRealtime(couple.id);
  
  // Start with current chests
  final initialChests = await service.getChests(couple.id);
  yield initialChests;
  
  // Listen for updates
  await for (final updatedChest in service.chestUpdates) {
    // Update the specific chest in our list
    final currentChests = await ref.read(chestsProvider.future);
    final updatedChests = currentChests.map((chest) {
      return chest.id == updatedChest.id ? updatedChest : chest;
    }).toList();
    
    yield updatedChests;
  }
});

// Specific chest provider
final chestProvider = FutureProvider.family<ChestStorage?, String>((ref, chestId) async {
  final service = ref.read(chestStorageServiceProvider);
  return await service.getChest(chestId);
});

// Chest creation provider
final createChestProvider = FutureProvider.family<ChestStorage, Map<String, dynamic>>((ref, params) async {
  final couple = await ref.read(userCoupleProvider.future);
  if (couple == null) throw Exception('No couple found');
  
  final service = ref.read(chestStorageServiceProvider);
  return await service.createChest(
    coupleId: couple.id,
    position: params['position'] as Position,
    name: params['name'] as String?,
    maxCapacity: params['maxCapacity'] as int? ?? 20,
  );
});

// Add item to chest provider
final addItemToChestProvider = FutureProvider.family<ChestStorage, Map<String, dynamic>>((ref, params) async {
  final service = ref.read(chestStorageServiceProvider);
  return await service.addItemToChest(
    params['chestId'] as String,
    params['item'] as ChestItem,
  );
});

// Remove item from chest provider
final removeItemFromChestProvider = FutureProvider.family<ChestStorage, Map<String, dynamic>>((ref, params) async {
  final service = ref.read(chestStorageServiceProvider);
  return await service.removeItemFromChest(
    params['chestId'] as String,
    params['itemId'] as String,
    quantity: params['quantity'] as int? ?? 1,
  );
});

// Nearby chests provider
final nearbyChestsProvider = FutureProvider.family<List<ChestStorage>, Position>((ref, position) async {
  final couple = await ref.read(userCoupleProvider.future);
  if (couple == null) return [];
  
  final service = ref.read(chestStorageServiceProvider);
  return await service.findChestsNearPosition(position);
});

// Chest storage state notifier for managing local state
class ChestStorageNotifier extends StateNotifier<AsyncValue<List<ChestStorage>>> {
  final ChestStorageService _service;
  final Ref _ref;
  
  ChestStorageNotifier(this._service, this._ref) : super(const AsyncValue.loading()) {
    _initialize();
  }
  
  Future<void> _initialize() async {
    try {
      final couple = await _ref.read(userCoupleProvider.future);
      if (couple == null) {
        state = const AsyncValue.data([]);
        return;
      }
      
      await _service.initializeRealtime(couple.id);
      final chests = await _service.getChests(couple.id);
      state = AsyncValue.data(chests);
      
      // Listen for real-time updates
      _service.chestUpdates.listen((updatedChest) {
        state.whenData((currentChests) {
          final updatedChests = currentChests.map((chest) {
            return chest.id == updatedChest.id ? updatedChest : chest;
          }).toList();
          state = AsyncValue.data(updatedChests);
        });
      });
      
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
  
  Future<void> createChest({
    required Position position,
    String? name,
    int maxCapacity = 20,
  }) async {
    try {
      final couple = await _ref.read(userCoupleProvider.future);
      if (couple == null) throw Exception('No couple found');
      
      final newChest = await _service.createChest(
        coupleId: couple.id,
        position: position,
        name: name,
        maxCapacity: maxCapacity,
      );
      
      state.whenData((chests) {
        state = AsyncValue.data([...chests, newChest]);
      });
      
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
  
  Future<void> addItemToChest(String chestId, ChestItem item) async {
    try {
      final updatedChest = await _service.addItemToChest(chestId, item);
      
      state.whenData((chests) {
        final updatedChests = chests.map((chest) {
          return chest.id == chestId ? updatedChest : chest;
        }).toList();
        state = AsyncValue.data(updatedChests);
      });
      
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
  
  Future<void> removeItemFromChest(String chestId, String itemId, {int quantity = 1}) async {
    try {
      final updatedChest = await _service.removeItemFromChest(chestId, itemId, quantity: quantity);
      
      state.whenData((chests) {
        final updatedChests = chests.map((chest) {
          return chest.id == chestId ? updatedChest : chest;
        }).toList();
        state = AsyncValue.data(updatedChests);
      });
      
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
  
  Future<void> deleteChest(String chestId) async {
    try {
      await _service.deleteChest(chestId);
      
      state.whenData((chests) {
        final updatedChests = chests.where((chest) => chest.id != chestId).toList();
        state = AsyncValue.data(updatedChests);
      });
      
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

// Chest storage state notifier provider
final chestStorageNotifierProvider = StateNotifierProvider<ChestStorageNotifier, AsyncValue<List<ChestStorage>>>((ref) {
  final service = ref.read(chestStorageServiceProvider);
  return ChestStorageNotifier(service, ref);
});

// Convenience providers for common operations
final chestsStateProvider = Provider<AsyncValue<List<ChestStorage>>>((ref) {
  return ref.watch(chestStorageNotifierProvider);
});

final isLoadingChestsProvider = Provider<bool>((ref) {
  return ref.watch(chestsStateProvider).isLoading;
});

final chestsErrorProvider = Provider<String?>((ref) {
  return ref.watch(chestsStateProvider).error?.toString();
}); 