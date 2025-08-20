import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:flame/components.dart';
import '../config/supabase_config.dart';
import '../components/player.dart';

class FarmPlayerService {
  final SupabaseClient _client = SupabaseConfig.client;
  
  // Movement simulation data
  final Map<String, PlayerMovementData> _playerMovementData = {};
  
  // Tile size for different game types
  static const double tiledFarmTileSize = 16.0;
  static const double regularFarmTileSize = 32.0;
  
  // --- Destination-based movement broadcasting ---

  Future<void> broadcastPlayerDestination({
    required String farmId,
    required String userId,
    required int targetGridX,
    required int targetGridY,
    String? animationState,
    double? tileSize, // Add tile size parameter
  }) async {
    final channel = _client.channel('farm_movement_$farmId');
    await channel.sendBroadcastMessage(
      event: 'player_destination',
      payload: {
        'user_id': userId,
        'target_grid_x': targetGridX,
        'target_grid_y': targetGridY,
        'animation_state': animationState,
        'tile_size': tileSize ?? regularFarmTileSize, // Include tile size in payload
        'timestamp': DateTime.now().toIso8601String(),
        'sequence': _getNextSequence(),
      },
    );
  }

  Stream<PlayerDestination> subscribeToPlayerDestinationBroadcast(String farmId) {
    final channel = _client.channel('farm_movement_$farmId');
    final controller = StreamController<PlayerDestination>(onCancel: () {
      channel.unsubscribe();
    });
    
    channel.onBroadcast(
      event: 'player_destination',
      callback: (payload, [ref]) {
        final data = payload['payload'] as Map<String, dynamic>;
        final destination = PlayerDestination(
          userId: data['user_id'] as String,
          targetGridX: data['target_grid_x'] as int,
          targetGridY: data['target_grid_y'] as int,
          animationState: data['animation_state'] as String?,
          tileSize: (data['tile_size'] as num?)?.toDouble() ?? regularFarmTileSize, // Extract tile size
          timestamp: DateTime.parse(data['timestamp'] as String),
          sequence: data['sequence'] as int? ?? 0,
        );
        
        // Store destination data for movement simulation
        _updatePlayerDestinationData(destination);
        
        controller.add(destination);
      },
    );
    channel.subscribe();
    return controller.stream;
  }
  
  // Get simulated position for smooth movement
  Vector2? getSimulatedPosition(String userId, double currentTime) {
    final data = _playerMovementData[userId];
    if (data == null || data.destinations.isEmpty) return null;
    
    final latestDestination = data.destinations.last;
    final startTime = latestDestination.timestamp.millisecondsSinceEpoch / 1000.0;
    final elapsedTime = currentTime - startTime;
    
    // Calculate movement duration based on distance
    final startPos = latestDestination.startPosition;
    if (startPos == null) return null;
    
    // Use the tile size from the destination
    final tileSize = latestDestination.tileSize;
    final targetPos = Vector2(
      latestDestination.targetGridX * tileSize + tileSize / 2, // Center of tile
      latestDestination.targetGridY * tileSize + tileSize / 2,
    );
    final distance = startPos.distanceTo(targetPos);
    final movementDuration = distance / 100.0; // 100 pixels per second
    
    if (elapsedTime >= movementDuration) {
      // Movement complete
      return targetPos;
    } else {
      // Interpolate position
      final progress = elapsedTime / movementDuration;
      final t = _easeOutCubic(progress);
      return startPos + (targetPos - startPos) * t;
    }
  }
  
  // Get movement direction for animation
  PlayerDirection? getMovementDirection(String userId, double currentTime) {
    final data = _playerMovementData[userId];
    if (data == null || data.destinations.isEmpty) return null;
    
    final latestDestination = data.destinations.last;
    final startTime = latestDestination.timestamp.millisecondsSinceEpoch / 1000.0;
    final elapsedTime = currentTime - startTime;
    
    // Calculate movement duration
    final startPos = latestDestination.startPosition;
    if (startPos == null) return PlayerDirection.idle;
    
    // Use the tile size from the destination
    final tileSize = latestDestination.tileSize;
    final targetPos = Vector2(
      latestDestination.targetGridX * tileSize + tileSize / 2,
      latestDestination.targetGridY * tileSize + tileSize / 2,
    );
    final distance = startPos.distanceTo(targetPos);
    final movementDuration = distance / 100.0;
    
    if (elapsedTime >= movementDuration) {
      return PlayerDirection.idle;
    }
    
    // Determine direction based on movement vector
    final direction = (targetPos - startPos).normalized();
    if (direction.y.abs() > direction.x.abs()) {
      return direction.y < 0 ? PlayerDirection.up : PlayerDirection.down;
    } else {
      return direction.x < 0 ? PlayerDirection.left : PlayerDirection.right;
    }
  }
  
  // Check if player is currently moving
  bool isPlayerMoving(String userId, double currentTime) {
    final data = _playerMovementData[userId];
    if (data == null || data.destinations.isEmpty) return false;
    
    final latestDestination = data.destinations.last;
    final startTime = latestDestination.timestamp.millisecondsSinceEpoch / 1000.0;
    final elapsedTime = currentTime - startTime;
    
    final startPos = latestDestination.startPosition;
    if (startPos == null) return false;
    
    // Use the tile size from the destination
    final tileSize = latestDestination.tileSize;
    final targetPos = Vector2(
      latestDestination.targetGridX * tileSize + tileSize / 2,
      latestDestination.targetGridY * tileSize + tileSize / 2,
    );
    final distance = startPos.distanceTo(targetPos);
    final movementDuration = distance / 100.0;
    
    return elapsedTime < movementDuration;
  }
  
  // Clean up old destination data
  void cleanupOldDestinationData() {
    final now = DateTime.now();
    final cutoffTime = now.subtract(const Duration(seconds: 5)); // Keep 5 seconds of data
    
    for (final entry in _playerMovementData.entries) {
      entry.value.destinations.removeWhere((destination) => 
        destination.timestamp.isBefore(cutoffTime)
      );
      
      // Remove empty entries
      if (entry.value.destinations.isEmpty) {
        _playerMovementData.remove(entry.key);
      }
    }
  }
  
  void _updatePlayerDestinationData(PlayerDestination destination) {
    if (!_playerMovementData.containsKey(destination.userId)) {
      _playerMovementData[destination.userId] = PlayerMovementData();
    }
    
    final data = _playerMovementData[destination.userId]!;
    
    // Calculate start position from previous destination or use current
    Vector2 startPosition;
    if (data.destinations.isNotEmpty) {
      final lastDestination = data.destinations.last;
      startPosition = Vector2(
        lastDestination.targetGridX * lastDestination.tileSize + lastDestination.tileSize / 2,
        lastDestination.targetGridY * lastDestination.tileSize + lastDestination.tileSize / 2,
      );
    } else {
      // First movement - use a default position
      startPosition = Vector2(
        destination.targetGridX * destination.tileSize + destination.tileSize / 2,
        destination.targetGridY * destination.tileSize + destination.tileSize / 2,
      );
    }
    
    // Create destination with start position
    final destinationWithStart = destination.copyWith(startPosition: startPosition);
    data.destinations.add(destinationWithStart);
    
    // Keep only the last 5 destinations
    if (data.destinations.length > 5) {
      data.destinations.removeAt(0);
    }
    
    // Clean up old data periodically
    if (data.destinations.length % 3 == 0) {
      cleanupOldDestinationData();
    }
  }
  
  int _sequenceCounter = 0;
  int _getNextSequence() {
    return ++_sequenceCounter;
  }
  
  // Easing function for smooth movement
  double _easeOutCubic(double t) {
    return 1 - (1 - t) * (1 - t) * (1 - t);
  }
}

class PlayerDestination {
  final String userId;
  final int targetGridX;
  final int targetGridY;
  final String? animationState;
  final DateTime timestamp;
  final int sequence;
  final Vector2? startPosition;
  final double tileSize; // Add tileSize to PlayerDestination

  PlayerDestination({
    required this.userId,
    required this.targetGridX,
    required this.targetGridY,
    this.animationState,
    required this.timestamp,
    this.sequence = 0,
    this.startPosition,
    this.tileSize = FarmPlayerService.regularFarmTileSize, // Default to regularFarmTileSize
  });
  
  PlayerDestination copyWith({Vector2? startPosition}) {
    return PlayerDestination(
      userId: userId,
      targetGridX: targetGridX,
      targetGridY: targetGridY,
      animationState: animationState,
      timestamp: timestamp,
      sequence: sequence,
      startPosition: startPosition ?? this.startPosition,
      tileSize: tileSize, // Include tileSize in copyWith
    );
  }
}

class PlayerMovementData {
  final List<PlayerDestination> destinations = [];
}

// Remove this enum since it's already defined in player.dart 