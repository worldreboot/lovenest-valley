import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/memory_garden/seed.dart';
import '../../providers/garden_providers.dart';
import 'plot_component.dart';

class GardenGridComponent extends PositionComponent {
  static const int gridWidth = 10;
  static const int gridHeight = 10;
  static const double plotSize = PlotComponent.plotSize;
  
  final WidgetRef ref;
  final Function(PlotPosition, Seed?) onPlotTapped;
  
  final Map<String, PlotComponent> _plots = {};
  List<Seed> _currentSeeds = [];

  GardenGridComponent({
    required this.ref,
    required this.onPlotTapped,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    size = Vector2(
      gridWidth * plotSize + 20, // 10px margin on each side
      gridHeight * plotSize + 20,
    );
    
    // Create the garden background
    add(RectangleComponent(
      size: size,
      paint: Paint()..color = const Color(0xFF228B22), // Forest green background
    ));
    
    // Initialize empty plots
    await _initializePlots();
    
    // Listen to seed changes
    _listenToSeedChanges();
  }

  Future<void> _initializePlots() async {
    for (int x = 0; x < gridWidth; x++) {
      for (int y = 0; y < gridHeight; y++) {
        final plotPosition = PlotPosition(x.toDouble(), y.toDouble());
        final plotKey = '${x}_$y';
        
        final plot = PlotComponent(
          plotPosition: plotPosition,
          seed: null,
          onTap: () => onPlotTapped(plotPosition, null),
        );
        
        _plots[plotKey] = plot;
        add(plot);
      }
    }
  }

  void _listenToSeedChanges() {
    // This would be called from the parent component when seeds change
    // For now, we'll implement the update method that can be called externally
  }

  void updateSeeds(List<Seed> seeds) {
    _currentSeeds = seeds;
    
    // Create a map of position to seed for quick lookup
    final seedMap = <String, Seed>{};
    for (final seed in seeds) {
      final key = '${seed.plotPosition.x.toInt()}_${seed.plotPosition.y.toInt()}';
      seedMap[key] = seed;
    }
    
    // Update all plots
    for (final entry in _plots.entries) {
      final plotKey = entry.key;
      final plot = entry.value;
      final seed = seedMap[plotKey];
      
      // Update the plot if the seed has changed
      plot.updateSeed(seed);
      
      // Update the onTap callback to pass the current seed
      plot.removeFromParent();
      final plotPosition = PlotPosition(
        double.parse(plotKey.split('_')[0]),
        double.parse(plotKey.split('_')[1]),
      );
      
      final newPlot = PlotComponent(
        plotPosition: plotPosition,
        seed: seed,
        onTap: () => onPlotTapped(plotPosition, seed),
      );
      
      _plots[plotKey] = newPlot;
      add(newPlot);
    }
  }

  Seed? getSeedAtPosition(PlotPosition position) {
    try {
      return _currentSeeds.firstWhere(
        (seed) => seed.plotPosition == position,
      );
    } catch (e) {
      return null;
    }
  }

  bool isPositionOccupied(PlotPosition position) {
    return getSeedAtPosition(position) != null;
  }

  List<PlotPosition> getEmptyPositions() {
    final emptyPositions = <PlotPosition>[];
    for (int x = 0; x < gridWidth; x++) {
      for (int y = 0; y < gridHeight; y++) {
        final position = PlotPosition(x.toDouble(), y.toDouble());
        if (!isPositionOccupied(position)) {
          emptyPositions.add(position);
        }
      }
    }
    return emptyPositions;
  }

  PlotPosition? findNearestEmptyPosition(PlotPosition target) {
    final emptyPositions = getEmptyPositions();
    if (emptyPositions.isEmpty) return null;
    
    // Find the closest empty position using Manhattan distance
    PlotPosition? closest;
    double minDistance = double.infinity;
    
    for (final position in emptyPositions) {
      final distance = (position.x - target.x).abs() + (position.y - target.y).abs();
      if (distance < minDistance) {
        minDistance = distance;
        closest = position;
      }
    }
    
    return closest;
  }

  void highlightEmptyPlots() {
    for (final entry in _plots.entries) {
      final plot = entry.value;
      final plotKey = entry.key;
      final position = PlotPosition(
        double.parse(plotKey.split('_')[0]),
        double.parse(plotKey.split('_')[1]),
      );
      
      if (!isPositionOccupied(position)) {
        // Add a subtle highlight effect to empty plots
        plot.add(RectangleComponent(
          size: Vector2.all(plotSize),
          paint: Paint()
            ..color = Colors.lightGreen.withOpacity(0.3)
            ..style = PaintingStyle.fill,
        ));
      }
    }
  }

  void clearHighlights() {
    for (final plot in _plots.values) {
      // Remove highlight effects
      plot.removeWhere((component) => 
        component is RectangleComponent && 
        component.paint.color == Colors.lightGreen.withOpacity(0.3)
      );
    }
  }
} 
