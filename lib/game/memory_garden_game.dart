import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/memory_garden/garden_grid_component.dart';
import '../models/memory_garden/seed.dart';
import '../providers/garden_providers.dart';

class MemoryGardenGame extends FlameGame with HasCollisionDetection, TapCallbacks {
  late GardenGridComponent gardenGrid;
  late CameraComponent cameraComponent;
  final WidgetRef ref;
  final Function(PlotPosition, Seed?) onPlotTapped;
  
  MemoryGardenGame({
    required this.ref,
    required this.onPlotTapped,
  });
  
  @override
  Color backgroundColor() => const Color(0xFF2E7D32); // Dark green background

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Create the garden grid
    gardenGrid = GardenGridComponent(
      ref: ref,
      onPlotTapped: onPlotTapped,
    );
    
    // Center the garden in the world
    gardenGrid.position = Vector2(
      size.x / 2 - gardenGrid.size.x / 2,
      size.y / 2 - gardenGrid.size.y / 2,
    );
    
    world.add(gardenGrid);
    
    // Set up camera
    cameraComponent = CameraComponent(); 
    camera = cameraComponent;
    
    // Set initial zoom to show the entire garden
    final zoomLevel = _calculateOptimalZoom();
    camera.viewfinder.zoom = zoomLevel;
    
    // Add UI elements
    await _addUI();
  }

  double _calculateOptimalZoom() {
    final gardenSize = gardenGrid.size;
    final screenSize = size;
    
    final zoomX = screenSize.x / (gardenSize.x + 100); // 100px padding
    final zoomY = screenSize.y / (gardenSize.y + 100);
    
    return (zoomX < zoomY ? zoomX : zoomY).clamp(0.5, 3.0);
  }

  Future<void> _addUI() async {
    // Add title
    final titleText = TextComponent(
      text: 'Memory Garden',
      position: Vector2(20, 20),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      ),
    );
    
    // Add instructions
    final instructionText = TextComponent(
      text: 'Tap empty plots to plant memories, tap sprouts to nurture them',
      position: Vector2(20, 50),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          shadows: [Shadow(color: Colors.black, blurRadius: 1)],
        ),
      ),
    );
    
    camera.viewport.add(titleText);
    camera.viewport.add(instructionText);
  }

  // Update seeds from external source (called by widget layer)
  void updateSeeds(List<Seed> seeds) {
    gardenGrid.updateSeeds(seeds);
  }

  void enterPlantingMode() {
    ref.read(plantingModeProvider.notifier).state = true;
    gardenGrid.highlightEmptyPlots();
  }

  void exitPlantingMode() {
    ref.read(plantingModeProvider.notifier).state = false;
    gardenGrid.clearHighlights();
  }

  void selectSeed(Seed? seed) {
    ref.read(selectedSeedProvider.notifier).state = seed;
  }

  @override
  void onTapDown(TapDownEvent event) {
    // Handle taps that don't hit specific plots
    final isPlantingMode = ref.read(plantingModeProvider);
    if (isPlantingMode) {
      exitPlantingMode();
    }
  }

  void zoomToGarden() {
    final optimalZoom = _calculateOptimalZoom();
    camera.viewfinder.zoom = optimalZoom;
  }

  void centerOnGarden() {
    camera.viewfinder.position = Vector2.zero();
  }

  Future<void> playWaterEffect(PlotPosition position) async {
    // Create a water splash effect at the given position
    final worldPosition = Vector2(
      position.x * GardenGridComponent.plotSize + gardenGrid.position.x,
      position.y * GardenGridComponent.plotSize + gardenGrid.position.y,
    );
    
    // Simple particle effect (you can enhance this later)
    final waterSplash = CircleComponent(
      radius: 20,
      position: worldPosition,
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.blue.withOpacity(0.7)
        ..style = PaintingStyle.fill,
    );
    
    world.add(waterSplash);
    
    // Remove the effect after a short time
    Future.delayed(const Duration(milliseconds: 500), () {
      waterSplash.removeFromParent();
    });
  }

  Future<void> playBloomEffect(PlotPosition position) async {
    // Create a bloom birth effect at the given position
    final worldPosition = Vector2(
      position.x * GardenGridComponent.plotSize + gardenGrid.position.x,
      position.y * GardenGridComponent.plotSize + gardenGrid.position.y,
    );
    
    // Sparkle effect for blooming
    for (int i = 0; i < 8; i++) {
      final sparkle = CircleComponent(
        radius: 3,
        position: worldPosition + Vector2.random() * 30,
        anchor: Anchor.center,
        paint: Paint()
          ..color = Colors.yellow.withOpacity(0.8)
          ..style = PaintingStyle.fill,
      );
      
      world.add(sparkle);
      
      // Remove sparkles after animation
      Future.delayed(Duration(milliseconds: 200 + i * 100), () {
        sparkle.removeFromParent();
      });
    }
  }
} 