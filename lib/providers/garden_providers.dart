import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/garden_repository.dart';
import '../models/memory_garden/seed.dart';
import '../models/memory_garden/couple.dart';
import '../models/memory_garden/water_reply.dart';

// Repository provider
final gardenRepositoryProvider = Provider<GardenRepository>((ref) {
  return const GardenRepository();
});

// Current user's couple provider
final userCoupleProvider = FutureProvider<Couple?>((ref) async {
  final repository = ref.watch(gardenRepositoryProvider);
  return repository.getUserCouple();
});

// Garden seeds stream provider
final gardenSeedsProvider = StreamProvider<List<Seed>>((ref) {
  final repository = ref.watch(gardenRepositoryProvider);
  return repository.getGardenStream();
});

// Provider for finding empty plot positions
final emptyPlotPositionProvider = FutureProvider<PlotPosition?>((ref) async {
  final repository = ref.watch(gardenRepositoryProvider);
  return repository.findEmptyPlotPosition();
});

// Provider for seed interactions
final seedInteractionsProvider = FutureProviderFamily<List<WaterReply>, String>((ref, seedId) async {
  final repository = ref.watch(gardenRepositoryProvider);
  return repository.getSeedInteractions(seedId);
});

// State provider for selected seed (for UI interactions)
final selectedSeedProvider = StateProvider<Seed?>((ref) => null);

// State provider for planting mode
final plantingModeProvider = StateProvider<bool>((ref) => false);

// Provider for checking if both partners watered a seed
final bothPartnersWateredProvider = FutureProviderFamily<bool, String>((ref, seedId) async {
  final repository = ref.watch(gardenRepositoryProvider);
  return repository.hasBeenWateredByBothPartners(seedId);
});

// Provider for media URLs
final mediaUrlProvider = FutureProviderFamily<String?, String>((ref, mediaPath) async {
  final repository = ref.watch(gardenRepositoryProvider);
  return repository.getMediaUrl(mediaPath);
}); 