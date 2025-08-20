import 'package:meta/meta.dart';

@immutable
class FarmTileModel {
  final String farmId;
  final int x;
  final int y;
  final String tileType;
  final bool watered;
  final DateTime? lastUpdatedAt;
  final DateTime? plantedAt;
  final DateTime? lastWateredAt;
  final int waterCount;
  final String growthStage;
  final String? plantType;

  const FarmTileModel({
    required this.farmId,
    required this.x,
    required this.y,
    required this.tileType,
    required this.watered,
    this.lastUpdatedAt,
    this.plantedAt,
    this.lastWateredAt,
    this.waterCount = 0,
    this.growthStage = 'planted',
    this.plantType,
  });

  factory FarmTileModel.fromJson(Map<String, dynamic> json) => FarmTileModel(
        farmId: json['farm_id'] as String,
        x: json['x'] as int,
        y: json['y'] as int,
        tileType: json['tile_type'] as String,
        watered: json['watered'] as bool? ?? false,
        lastUpdatedAt: json['last_updated_at'] != null
            ? DateTime.parse(json['last_updated_at'] as String)
            : null,
        plantedAt: json['planted_at'] != null
            ? DateTime.parse(json['planted_at'] as String)
            : null,
        lastWateredAt: json['last_watered_at'] != null
            ? DateTime.parse(json['last_watered_at'] as String)
            : null,
        waterCount: json['water_count'] as int? ?? 0,
        growthStage: json['growth_stage']?.toString() ?? 'planted',
        plantType: json['plant_type']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'farm_id': farmId,
        'x': x,
        'y': y,
        'tile_type': tileType,
        'watered': watered,
        'last_updated_at': lastUpdatedAt?.toIso8601String(),
        'planted_at': plantedAt?.toIso8601String(),
        'last_watered_at': lastWateredAt?.toIso8601String(),
        'water_count': waterCount,
        'growth_stage': growthStage,
        'plant_type': plantType,
      };

  /// Check if the plant is fully grown
  bool get isFullyGrown => growthStage == 'fully_grown';

  /// Check if the plant can be watered today
  bool get canBeWateredToday {
    if (lastWateredAt == null) return true;
    final now = DateTime.now();
    final lastWatered = lastWateredAt!;
    return now.year != lastWatered.year || 
           now.month != lastWatered.month || 
           now.day != lastWatered.day;
  }

  /// Get the number of days the plant has been watered consecutively
  int get consecutiveWaterDays {
    if (lastWateredAt == null) return 0;
    // For now, return waterCount as a simple implementation
    // In a more sophisticated system, you'd track actual consecutive days
    return waterCount;
  }

  /// Check if the tile should show as watered based on time since last watering
  bool get shouldShowAsWatered {
    if (lastWateredAt == null) return false;
    
    final now = DateTime.now();
    final lastWatered = lastWateredAt!;
    
    // Calculate the difference in days
    final difference = now.difference(lastWatered).inDays;
    
    // Show as watered if watered within the last day (less than 24 hours)
    return difference < 1;
  }
} 