import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/farm_tile_model.dart';
import 'dart:convert'; // Added for json.decode
import 'package:http/http.dart' as http; // Added for http.MultipartRequest

class FarmTileService {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<FarmTileModel>> fetchFarmTiles(String farmId) async {
    debugPrint('[FarmTileService] Fetching tiles for farm: $farmId');
    try {
      final response = await _client
          .from('farm_tiles')
          .select()
          .eq('farm_id', farmId);
      
      final tiles = (response as List)
          .map((json) => FarmTileModel.fromJson(json))
          .toList();
      
      debugPrint('[FarmTileService] Successfully fetched ${tiles.length} tiles for farm: $farmId');
      return tiles;
    } catch (e) {
      debugPrint('[FarmTileService] ERROR fetching tiles for farm $farmId: $e');
      rethrow;
    }
  }

  /// Check if a farm has any tiles
  Future<bool> farmHasTiles(String farmId) async {
    try {
      final response = await _client
          .from('farm_tiles')
          .select('x')
          .eq('farm_id', farmId)
          .limit(1);
      
      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('[FarmTileService] ERROR checking if farm has tiles: $e');
      return false;
    }
  }

  Future<void> updateTile({
    required String farmId,
    required int x,
    required int y,
    required String tileType,
    bool? watered,
    String? plantType,
    bool isPlanting = false,
    String? userId,
    bool skipBroadcast = false,
  }) async {
    debugPrint('[FarmTileService] Updating tile at ($x, $y) on farm $farmId to type: $tileType, watered: $watered');
    
    final now = DateTime.now();
    final updateData = {
      'farm_id': farmId,
      'x': x,
      'y': y,
      'tile_type': tileType,
      'last_updated_at': now.toIso8601String(),
    };

    // Handle watering logic
    if (watered != null) {
      updateData['watered'] = watered;
      if (watered) {
        updateData['last_watered_at'] = now.toIso8601String();
        // We'll handle water count increment in the growth check below
      }
    }

    // Handle planting logic
    if (isPlanting && plantType != null) {
      updateData['planted_at'] = now.toIso8601String();
      updateData['plant_type'] = plantType;
      updateData['growth_stage'] = 'planted';
      updateData['water_count'] = 0;
    }

    // Check if plant should grow to fully grown (3 days of watering)
    if (watered == true) {
      // Get current tile to check water count
      final currentTile = await _client
          .from('farm_tiles')
          .select('water_count, growth_stage')
          .eq('farm_id', farmId)
          .eq('x', x)
          .eq('y', y)
          .maybeSingle();
      
      if (currentTile != null) {
        final currentWaterCount = (currentTile['water_count'] as int?) ?? 0;
        final currentGrowthStage = (currentTile['growth_stage'] as String?) ?? 'planted';
        
        // Increment water count
        final newWaterCount = currentWaterCount + 1;
        updateData['water_count'] = newWaterCount;
        
        // If plant has been watered 3 times and is still planted, make it fully grown
        if (newWaterCount >= 3 && currentGrowthStage == 'planted') {
          updateData['growth_stage'] = 'fully_grown';
          debugPrint('[FarmTileService] 🌱 Plant at ($x, $y) is now fully grown!');
        }
      }
    }

    try {
      await _client.from('farm_tiles').upsert(updateData);
      debugPrint('[FarmTileService] Successfully updated tile at ($x, $y) on farm $farmId');
      
      // Broadcast the tile change in real-time if not skipping
      if (!skipBroadcast) {
        await broadcastTileChange(
          farmId: farmId,
          x: x,
          y: y,
          tileType: tileType,
          watered: watered,
          plantType: plantType,
          growthStage: updateData['growth_stage'] as String?,
          userId: userId,
        );
      }
    } catch (e) {
      debugPrint('[FarmTileService] ERROR updating tile at ($x, $y) on farm $farmId: $e');
      rethrow;
    }
  }

  Future<void> batchUpdateTiles(String farmId, List<FarmTileModel> updates) async {
    final data = updates.map((tile) => tile.toJson()).toList();
    await _client.from('farm_tiles').upsert(data);
  }

  /// Generates and saves a complete farm map with the standard layout
  Future<void> generateAndSaveFarmMap(String farmId) async {
    debugPrint('[FarmTileService] Generating and saving complete farm map for farm: $farmId');
    
    const int mapWidth = 32;
    const int mapHeight = 14;
    final List<FarmTileModel> tilesToSave = [];
    
    for (int x = 0; x < mapWidth; x++) {
      for (int y = 0; y < mapHeight; y++) {
        String tileType;
        
        // Place a 2x2 wood floor at the spawn (centered at 9,7)
        if (x >= 9 && x <= 10 && y >= 7 && y <= 8) {
          tileType = 'wood';
        }
        // Border - trees/fence (but not in water area)
        else if ((x < 2 || y < 2 || y >= mapHeight - 2) || (x >= mapWidth - 2 && x < 16)) {
          tileType = 'tree';
        }
        // Beach area (right side)
        else if (x == 16) {
          tileType = 'grassSand';
        } else if (x == 17 || x == 18) {
          tileType = 'sand';
        } else if (x >= 19) {
          tileType = 'water';
        } else {
          // All other tiles are grass
          tileType = 'grass';
        }
        
        tilesToSave.add(FarmTileModel(
          farmId: farmId,
          x: x,
          y: y,
          tileType: tileType,
          watered: false,
        ));
      }
    }
    
    try {
      debugPrint('[FarmTileService] Saving ${tilesToSave.length} tiles for new farm map...');
      await batchUpdateTiles(farmId, tilesToSave);
      debugPrint('[FarmTileService] ✅ Successfully generated and saved farm map');
    } catch (e) {
      debugPrint('[FarmTileService] ❌ ERROR generating farm map: $e');
      rethrow;
    }
  }

  /// Regenerates a farm map by first clearing existing tiles, then generating new ones
  Future<void> regenerateFarmMap(String farmId) async {
    debugPrint('[FarmTileService] Regenerating farm map for farm: $farmId');
    
    try {
      // First, delete all existing tiles for this farm
      await _client
          .from('farm_tiles')
          .delete()
          .eq('farm_id', farmId);
      
      debugPrint('[FarmTileService] Cleared existing tiles for farm: $farmId');
      
      // Then generate and save the new map
      await generateAndSaveFarmMap(farmId);
      
      debugPrint('[FarmTileService] ✅ Successfully regenerated farm map');
    } catch (e) {
      debugPrint('[FarmTileService] ❌ ERROR regenerating farm map: $e');
      rethrow;
    }
  }

  Stream<FarmTileModel> subscribeToTileChanges(String farmId) {
    debugPrint('[FarmTileService] 🚀 Setting up real-time subscription for farm: $farmId');
    
    // Check if client is properly initialized
    debugPrint('[FarmTileService] 🔍 Current user: ${_client.auth.currentUser?.id}');
    debugPrint('[FarmTileService] 🔍 Auth session: ${_client.auth.currentSession != null ? 'Active' : 'None'}');
    
    final channelName = 'farm_tiles_changes_$farmId';
    debugPrint('[FarmTileService] 📡 Channel name: $channelName');
    
    final channel = _client.channel(channelName);
    final controller = StreamController<FarmTileModel>(onCancel: () {
      debugPrint('[FarmTileService] 🛑 Cancelling real-time subscription for farm: $farmId');
      channel.unsubscribe();
    });
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'farm_tiles',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'farm_id',
        value: farmId,
      ),
      callback: (payload) {
        debugPrint('[FarmTileService] 📨 Received real-time update for farm: $farmId');
        debugPrint('[FarmTileService] 📨 Event type: ${payload.eventType}');
        debugPrint('[FarmTileService] 📨 New record: ${payload.newRecord}');
        debugPrint('[FarmTileService] 📨 Old record: ${payload.oldRecord}');
        
        try {
          final tile = FarmTileModel.fromJson(payload.newRecord);
          debugPrint('[FarmTileService] ✅ Parsed tile: (${tile.x}, ${tile.y}) -> ${tile.tileType}');

          // Add specific logging for watering updates
          try {
            final oldTile = FarmTileModel.fromJson(payload.oldRecord);
            if (oldTile.lastWateredAt != tile.lastWateredAt) {
              debugPrint('[FarmTileService] 💧 Watering update detected: (${tile.x}, ${tile.y})');
              debugPrint('[FarmTileService] 💧 Old watered: ${oldTile.lastWateredAt}');
              debugPrint('[FarmTileService] 💧 New watered: ${tile.lastWateredAt}');
            }
          } catch (_) {
            // oldRecord may be null or not parsable; ignore
          }

          controller.add(tile);
        } catch (e) {
          debugPrint('[FarmTileService] ⚠️ No new record in payload or parse failed: $e');
          debugPrint('[FarmTileService] ❌ Raw payload: ${payload.newRecord}');
        }
      },
    );
    
    channel.subscribe((status, [error]) {
      debugPrint('[FarmTileService] 📡 Channel subscription status: $status');
      if (status == 'SUBSCRIBED') {
        debugPrint('[FarmTileService] ✅ Successfully subscribed to real-time updates for farm: $farmId');
      } else if (status == 'CHANNEL_ERROR') {
        debugPrint('[FarmTileService] ❌ ERROR subscribing to real-time updates for farm: $farmId');
        debugPrint('[FarmTileService] ❌ Error details: $error');
      } else if (status == 'TIMED_OUT') {
        debugPrint('[FarmTileService] ⏰ Subscription timed out for farm: $farmId');
      } else if (status == 'CLOSED') {
        debugPrint('[FarmTileService] 🔒 Channel closed for farm: $farmId');
      } else {
        debugPrint('[FarmTileService] 📡 Subscription status for farm $farmId: $status');
      }
    });
    
    debugPrint('[FarmTileService] 🚀 Real-time subscription setup completed for farm: $farmId');
    return controller.stream;
  }

  /// Broadcast tile changes in real-time to all connected users
  Future<void> broadcastTileChange({
    required String farmId,
    required int x,
    required int y,
    required String tileType,
    bool? watered,
    String? plantType,
    String? growthStage,
    String? userId,
  }) async {
    debugPrint('[FarmTileService] 📡 Broadcasting tile change: ($x, $y) -> $tileType');
    
    final channel = _client.channel('farm_tile_broadcast_$farmId');
    await channel.sendBroadcastMessage(
      event: 'tile_change',
      payload: {
        'farm_id': farmId,
        'x': x,
        'y': y,
        'tile_type': tileType,
        'watered': watered,
        'plant_type': plantType,
        'growth_stage': growthStage,
        'user_id': userId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    debugPrint('[FarmTileService] ✅ Tile change broadcasted successfully');
  }

  /// Subscribe to real-time tile change broadcasts
  Stream<Map<String, dynamic>> subscribeToTileChangeBroadcasts(String farmId) {
    final channel = _client.channel('farm_tile_broadcast_$farmId');
    final controller = StreamController<Map<String, dynamic>>(onCancel: () {
      channel.unsubscribe();
    });
    
    channel.onBroadcast(
      event: 'tile_change',
      callback: (payload, [ref]) {
        final data = payload['payload'] as Map<String, dynamic>;
        debugPrint('[FarmTileService] 📨 Received tile change broadcast: (${data['x']}, ${data['y']}) -> ${data['tile_type']}');
        controller.add(data);
      },
    );
    
    channel.subscribe();
    return controller.stream;
  }

  /// Till a tile at the specified position and save to backend


  /// Till a tile at the specified position and save to backend
  Future<void> tillTile(String farmId, int gridX, int gridY) async {
    try {
      debugPrint('[FarmTileService] 🚜 Tilling tile at ($gridX, $gridY) for farm $farmId');
      
      // Check if tile already exists
      final existingTile = await _client
          .from('farm_tiles')
          .select()
          .eq('farm_id', farmId)
          .eq('x', gridX)
          .eq('y', gridY)
          .maybeSingle();

      if (existingTile != null) {
        // Update existing tile
        await _client
            .from('farm_tiles')
            .update({
              'tile_type': 'tilled',
              'last_updated_at': DateTime.now().toIso8601String(),
            })
            .eq('farm_id', farmId)
            .eq('x', gridX)
            .eq('y', gridY);
        
        debugPrint('[FarmTileService] ✅ Updated existing tile at ($gridX, $gridY)');
      } else {
        // Insert new tile
        await _client
            .from('farm_tiles')
            .insert({
              'farm_id': farmId,
              'x': gridX,
              'y': gridY,
              'tile_type': 'tilled',
              'watered': false,
              'last_updated_at': DateTime.now().toIso8601String(),
            });
        
        debugPrint('[FarmTileService] ✅ Created new tilled tile at ($gridX, $gridY)');
      }
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Error tilling tile: $e');
      rethrow;
    }
  }

  /// Load all tilled tiles for a farm
  Future<List<Map<String, dynamic>>> loadTilledTiles(String farmId) async {
    try {
      debugPrint('[FarmTileService] 📁 Loading tilled tiles for farm $farmId');
      
      final response = await _client
          .from('farm_tiles')
          .select()
          .eq('farm_id', farmId)
          .eq('tile_type', 'tilled');
      
      debugPrint('[FarmTileService] ✅ Loaded ${response.length} tilled tiles');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Error loading tilled tiles: $e');
      rethrow;
    }
  }

  /// Check if a tile is tilled
  Future<bool> isTileTilled(String farmId, int gridX, int gridY) async {
    try {
      final response = await _client
          .from('farm_tiles')
          .select()
          .eq('farm_id', farmId)
          .eq('x', gridX)
          .eq('y', gridY)
          .eq('tile_type', 'tilled')
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Error checking if tile is tilled: $e');
      return false;
    }
  }

  /// Remove a tilled tile (for untilling)
  Future<void> removeTilledTile(String farmId, int gridX, int gridY) async {
    try {
      debugPrint('[FarmTileService] 🗑️ Removing tilled tile at ($gridX, $gridY)');
      
      await _client
          .from('farm_tiles')
          .delete()
          .eq('farm_id', farmId)
          .eq('x', gridX)
          .eq('y', gridY)
          .eq('tile_type', 'tilled');
      
      debugPrint('[FarmTileService] ✅ Removed tilled tile at ($gridX, $gridY)');
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Error removing tilled tile: $e');
      rethrow;
    }
  }

  /// Water a tile and save to backend
  Future<bool> waterTile(String farmId, int x, int y) async {
    try {
      final now = DateTime.now().toIso8601String();
      
      await _client
          .from('farm_tiles')
          .upsert({
            'farm_id': farmId,
            'x': x,
            'y': y,
            'tile_type': 'watered',
            'watered': true,
            'last_watered_at': now,
            'last_updated_at': now,
          });

      debugPrint('[FarmTileService] 💧 Watered tile at ($x, $y) on farm $farmId');
      return true;
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Error watering tile: $e');
      return false;
    }
  }

  /// Load watered tiles from backend
  Future<List<Map<String, dynamic>>> loadWateredTiles(String farmId) async {
    try {
      final response = await _client
          .from('farm_tiles')
          .select('*')
          .eq('farm_id', farmId)
          .eq('tile_type', 'watered');

      debugPrint('[FarmTileService] 📦 Loaded ${response.length} watered tiles for farm: $farmId');
      
      for (final tile in response) {
        debugPrint('[FarmTileService]   - Watered tile at (${tile['x']}, ${tile['y']})');
      }
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Error loading watered tiles: $e');
      return [];
    }
  }

  /// Check if a tile is watered in the backend
  Future<bool> isTileWatered(String farmId, int x, int y) async {
    try {
      final response = await _client
          .from('farm_tiles')
          .select('tile_type')
          .eq('farm_id', farmId)
          .eq('x', x)
          .eq('y', y)
          .maybeSingle();

      return response != null && response['tile_type'] == 'watered';
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Error checking if tile is watered: $e');
      return false;
    }
  }

  /// Remove a watered tile from the backend
  Future<bool> removeWateredTile(String farmId, int x, int y) async {
    try {
      await _client
          .from('farm_tiles')
          .delete()
          .eq('farm_id', farmId)
          .eq('x', x)
          .eq('y', y)
          .eq('tile_type', 'watered');

      debugPrint('[FarmTileService] 🗑️ Removed watered tile at ($x, $y) from farm $farmId');
      return true;
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Error removing watered tile: $e');
      return false;
    }
  }

  /// Save the vertex grid state to the database with real-time broadcasting
  Future<void> saveVertexGridState(String farmId, List<List<int>> vertexGrid) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        debugPrint('[FarmTileService] ❌ No user ID available for saving vertex grid state');
        return;
      }
      
      debugPrint('[FarmTileService] 💾 Saving vertex grid state to database for farm $farmId by user $userId');
      
      // Convert vertex grid to a compact representation
      final vertexData = {
        'farm_id': farmId,
        'user_id': userId,
        'vertex_grid': vertexGrid,
        'last_updated_at': DateTime.now().toIso8601String(),
      };
      
      // Use upsert with onConflict parameter to handle existing records
      await _client
          .from('farm_vertex_states')
          .upsert(
            vertexData,
            onConflict: 'farm_id',
          );
      
      debugPrint('[FarmTileService] ✅ Vertex grid state saved successfully with real-time broadcasting');
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Error saving vertex grid state: $e');
      rethrow;
    }
  }

  /// Load the vertex grid state from the database (user-specific)
  Future<List<List<int>>?> loadVertexGridState(String farmId) async {
    try {
      debugPrint('[FarmTileService] 📁 Loading vertex grid state (shared) from database for farm $farmId');
      
      // Load the most recent vertex grid for this farm, regardless of which user saved it
      final responseList = await _client
          .from('farm_vertex_states')
          .select('vertex_grid, last_updated_at')
          .eq('farm_id', farmId)
          .order('last_updated_at', ascending: false)
          .limit(1);
      
      final response = responseList.isNotEmpty ? responseList.first : null;
      
      if (response != null) {
        final vertexGrid = List<List<int>>.from(
          (response['vertex_grid'] as List).map((row) => List<int>.from(row))
        );
        debugPrint('[FarmTileService] ✅ Vertex grid state loaded successfully');
        return vertexGrid;
      } else {
        debugPrint('[FarmTileService] ℹ️ No vertex grid state found for farm $farmId');
        return null;
      }
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Error loading vertex grid state: $e');
      return null;
    }
  }

  /// Subscribe to real-time vertex grid changes
  RealtimeChannel subscribeToVertexGridChanges(String farmId, Function(PostgresChangePayload) onVertexGridChange) {
    debugPrint('[FarmTileService] 📡 Subscribing to real-time vertex grid changes for farm $farmId');
    
    return _client
        .channel('vertex_grid_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'farm_vertex_states',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'farm_id',
            value: farmId,
          ),
          callback: (payload) {
            debugPrint('[FarmTileService] 📡 Received vertex grid change: $payload');
            onVertexGridChange(payload);
          },
        );
  }

  /// Merge vertex grid changes from partner
  Future<void> mergePartnerVertexGridChanges(String farmId, List<List<int>> partnerVertexGrid) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return;
      
      debugPrint('[FarmTileService] 🔄 Merging partner vertex grid changes for farm $farmId');
      
      // For now, we'll use the partner's vertex grid as the source of truth
      // In a more sophisticated system, you might want to merge specific changes
      await saveVertexGridState(farmId, partnerVertexGrid);
      
      debugPrint('[FarmTileService] ✅ Partner vertex grid changes merged successfully');
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Error merging partner vertex grid changes: $e');
    }
  }

  /// Create a fresh vertex grid state for a farm based on TMX data
  Future<void> createFreshVertexGridState(String farmId, int mapWidth, int mapHeight) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        debugPrint('[FarmTileService] ❌ No user ID available for creating vertex grid state');
        return;
      }
      
      debugPrint('[FarmTileService] 🌱 Creating fresh vertex grid state for farm $farmId based on TMX data');
      
      // Note: The actual TMX data conversion happens in the game initialization
      // This method creates a basic grass terrain as fallback
      // The game will override this with TMX data during initialization
      final vertexGrid = List.generate(
        mapHeight + 1,
        (_) => List.generate(mapWidth + 1, (_) => 4), // Terrain.GRASS.id = 4
      );
      
      // Save the fresh vertex grid state
      await saveVertexGridState(farmId, vertexGrid);
      
      debugPrint('[FarmTileService] ✅ Fresh vertex grid state created successfully');
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Error creating fresh vertex grid state: $e');
    }
  }

  /// Save planted seeds to the new seed storage system
  Future<void> savePlantedSeeds(String farmId, List<Map<String, dynamic>> seeds) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        debugPrint('[FarmTileService] ❌ No user ID available for saving planted seeds');
        return;
      }
      
      debugPrint('[FarmTileService] 🌱 Saving ${seeds.length} planted seeds for farm $farmId');
      
      // Clear existing seeds for this farm/user
      await _client
          .from('farm_seeds')
          .delete()
          .eq('farm_id', farmId)
          .eq('user_id', userId);
      
      // Insert new seeds
      if (seeds.isNotEmpty) {
        final seedData = seeds.map((seed) => {
          'farm_id': farmId,
          'user_id': userId,
          'x': seed['x'],
          'y': seed['y'],
          'plant_type': seed['plant_type'],
          'growth_stage': seed['growth_stage'],
          'water_count': seed['water_count'] ?? 0,
          'planted_at': seed['planted_at'],
          'last_watered_at': seed['last_watered_at'],
          'properties': seed['properties'] ?? {},
        }).toList();
        
        await _client.from('farm_seeds').insert(seedData);
      }
      
      debugPrint('[FarmTileService] ✅ Planted seeds saved successfully');
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Error saving planted seeds: $e');
    }
  }

  /// Load planted seeds from the new seed storage system
  Future<List<Map<String, dynamic>>> loadPlantedSeeds(String farmId) async {
    try {
      debugPrint('[FarmTileService] 🌱 Loading planted seeds for farm $farmId (shared)');
      final response = await _client
          .from('farm_seeds')
          .select('*')
          .eq('farm_id', farmId);
      
      final seeds = List<Map<String, dynamic>>.from(response);
      debugPrint('[FarmTileService] ✅ Loaded ${seeds.length} planted seeds');
      
      return seeds;
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Error loading planted seeds: $e');
      return [];
    }
  }

  /// Plant a seed in the new system
  Future<void> plantSeed(String farmId, int x, int y, String plantType, {Map<String, dynamic>? properties}) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        debugPrint('[FarmTileService] ❌ No user ID available for planting seed');
        return;
      }
      
      debugPrint('[FarmTileService] 🌱 Planting $plantType at ($x, $y) on farm $farmId');
      
      final seedData = {
        'farm_id': farmId,
        'user_id': userId,
        'x': x,
        'y': y,
        'plant_type': plantType,
        'growth_stage': 'planted',
        'water_count': 0,
        'planted_at': DateTime.now().toIso8601String(),
        'properties': properties ?? {},
      };
      
      await _client.from('farm_seeds').insert(seedData);
      debugPrint('[FarmTileService] ✅ Seed planted successfully');
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Error planting seed: $e');
    }
  }

  /// Water a seed in the new system
  Future<void> waterSeed(String farmId, int x, int y) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        debugPrint('[FarmTileService] ❌ No user ID available for watering seed');
        return;
      }
      debugPrint('[FarmTileService] 💧 Watering seed at ($x, $y) on farm $farmId (shared)');
      
      // Get current seed data
      final currentSeed = await _client
          .from('farm_seeds')
          .select('*')
          .eq('farm_id', farmId)
          .eq('x', x)
          .eq('y', y)
          .maybeSingle();
      
      if (currentSeed != null) {
        final currentWaterCount = (currentSeed['water_count'] as int?) ?? 0;
        final newWaterCount = currentWaterCount + 1;
        
        final updateData = {
          'water_count': newWaterCount,
          'last_watered_at': DateTime.now().toIso8601String(),
        };
        
        // Check if plant should grow to fully grown (3 days of watering)
        if (newWaterCount >= 3 && currentSeed['growth_stage'] == 'planted') {
          updateData['growth_stage'] = 'fully_grown';
          debugPrint('[FarmTileService] 🌱 Plant at ($x, $y) is now fully grown!');
          
          // Generate unique sprite for the bloomed seed
          await _generateUniqueSpriteForSeed(farmId, x, y, currentSeed);
        }
        
        await _client
            .from('farm_seeds')
            .update(updateData)
            .eq('farm_id', farmId)
            .eq('x', x)
            .eq('y', y);
        
        debugPrint('[FarmTileService] ✅ Seed watered successfully');
      } else {
        debugPrint('[FarmTileService] ⚠️ No seed found at ($x, $y)');
      }
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Error watering seed: $e');
    }
  }

  /// Generate a unique sprite for a bloomed seed
  Future<void> _generateUniqueSpriteForSeed(String farmId, int x, int y, Map<String, dynamic> seedData) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return;
      
      final plantType = seedData['plant_type'] as String;
      final properties = seedData['properties'] as Map<String, dynamic>? ?? {};
      
      debugPrint('[FarmTileService] 🎨 Generating unique sprite for $plantType at ($x, $y)');
      
      String userDescription;
      switch (plantType) {
        case 'daily_question_seed':
          userDescription = _createDailyQuestionPrompt(properties);
          break;
        case 'memory_seed':
          userDescription = _createMemorySeedPrompt(properties);
          break;
        default:
          userDescription = _createGenericSeedPrompt(plantType, properties);
      }
      
      // Call the initiate-generation Edge Function
      final session = _client.auth.currentSession;
      if (session == null) {
        debugPrint('[FarmTileService] ❌ User not authenticated');
        return;
      }

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${SupabaseConfig.supabaseUrl}/functions/v1/initiate-generation'),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Bearer ${session.accessToken}';
      request.headers['apikey'] = SupabaseConfig.supabaseAnonKey;

      // Add form fields
      request.fields['preset_name'] = 'seed_bloom_sprite';
      request.fields['user_description'] = userDescription;

      // Send the request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = json.decode(responseBody);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final jobId = responseData['jobId'];
        
        // Update farm_seeds with generation job reference
        await _client
            .from('farm_seeds')
            .update({
              'properties': {
                ...properties,
                'generation_job_id': jobId,
              },
            })
            .eq('farm_id', farmId)
            .eq('user_id', userId)
            .eq('x', x)
            .eq('y', y);
        
        debugPrint('[FarmTileService] 🌸 Generation job created: $jobId');
      } else {
        debugPrint('[FarmTileService] ❌ Failed to create generation job: ${responseData['error']}');
      }
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Error generating sprite: $e');
    }
  }

  /// Create prompt for daily question seeds
  String _createDailyQuestionPrompt(Map<String, dynamic> properties) {
    final questionId = properties['question_id'] as String?;
    final answer = properties['answer'] as String?;
    
    if (questionId != null && answer != null) {
      return 'Generate a beautiful, colorful flower sprite that represents the answer to this daily question. The answer was: "$answer". Make it a vibrant, blooming flower with petals in warm colors like pink, orange, yellow, or purple. The flower should look happy and full of life, reflecting the personal meaning of the answer.';
    }
    
    return 'Generate a beautiful, meaningful flower sprite for a daily question seed. Make it vibrant and full of life with warm, personal colors.';
  }

  /// Create prompt for memory seeds
  String _createMemorySeedPrompt(Map<String, dynamic> properties) {
    final seedId = properties['seed_id'] as String?;
    
    if (seedId != null) {
      return 'Generate a unique, personal flower sprite representing a cherished memory. The flower should reflect the emotional significance of the memory with warm, meaningful colors and a design that feels personal and special. Make it vibrant and full of life.';
    }
    
    return 'Generate a beautiful flower sprite representing a personal memory. Make it warm, meaningful, and full of life with colors that reflect the emotional significance.';
  }

  /// Create prompt for generic seeds
  String _createGenericSeedPrompt(String plantType, Map<String, dynamic> properties) {
    return 'Generate a beautiful, unique flower sprite for a $plantType seed. Make it vibrant and full of life with warm colors like pink, orange, yellow, or purple. The flower should look happy and blooming, representing the growth and care that went into nurturing this seed.';
  }

  /// Get the sprite URL for a bloomed seed
  Future<String?> getSeedSpriteUrl(String farmId, int x, int y) async {
    try {
      debugPrint('[FarmTileService] 🔍 Getting sprite URL for seed at ($x, $y) on farm $farmId');
      final seedData = await _client
          .from('farm_seeds')
          .select('*')
          .eq('farm_id', farmId)
          .eq('x', x)
          .eq('y', y)
          .maybeSingle();
      
      debugPrint('[FarmTileService] 📊 Farm seed data: ${seedData != null ? 'EXISTS' : 'MISSING'}');
      if (seedData != null) {
        debugPrint('[FarmTileService] 📊 Growth stage: ${seedData['growth_stage']}');
        debugPrint('[FarmTileService] 📊 Properties: ${seedData['properties']}');
      }
      
      if (seedData == null || seedData['growth_stage'] != 'fully_grown') {
        debugPrint('[FarmTileService] ❌ Seed not found or not fully grown');
        return null;
      }
      
      final properties = seedData['properties'] as Map<String, dynamic>? ?? {};
      
      // First check if we already have a sprite URL cached
      final cachedSpriteUrl = properties['sprite_url'] as String?;
      if (cachedSpriteUrl != null) {
        debugPrint('[FarmTileService] ✅ Found cached sprite URL: $cachedSpriteUrl');
        return cachedSpriteUrl;
      }
      
      debugPrint('[FarmTileService] 🔄 No cached URL, checking seeds table...');
      
      // Check the seeds table for the generation job ID
      final seedRecord = await _client
          .from('seeds')
          .select('bloom_variant_seed, state')
          .eq('plot_x', x.toDouble())
          .eq('plot_y', y.toDouble())
          .maybeSingle();
      
      debugPrint('[FarmTileService] 📊 Seeds table record: ${seedRecord != null ? 'EXISTS' : 'MISSING'}');
      if (seedRecord != null) {
        debugPrint('[FarmTileService] 📊 bloom_variant_seed: ${seedRecord['bloom_variant_seed']}');
        debugPrint('[FarmTileService] 📊 state: ${seedRecord['state']}');
      }
      
      if (seedRecord != null && seedRecord['bloom_variant_seed'] != null) {
        final jobId = seedRecord['bloom_variant_seed'] as String;
        debugPrint('[FarmTileService] 🎨 Found generation job ID: $jobId');
        
        // Check the generation job status
        final jobResponse = await _client
            .from('generation_jobs')
            .select('status, final_image_url, error_message')
            .eq('id', jobId)
            .maybeSingle();
        
        debugPrint('[FarmTileService] 🎨 Generation job: ${jobResponse != null ? 'EXISTS' : 'MISSING'}');
        if (jobResponse != null) {
          debugPrint('[FarmTileService] 🎨 Job status: ${jobResponse['status']}');
          debugPrint('[FarmTileService] 🎨 Final image URL: ${jobResponse['final_image_url']}');
        }
        
        if (jobResponse != null && jobResponse['status'] == 'completed') {
          final imageUrl = jobResponse['final_image_url'] as String?;
          if (imageUrl != null) {
            debugPrint('[FarmTileService] ✅ Found completed generation job with URL: $imageUrl');
            return imageUrl;
          }
        }
      }
      
      debugPrint('[FarmTileService] ❌ No sprite URL found');
      return null;
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Error getting sprite URL: $e');
      return null;
    }
  }

  /// Poll for job completion and update sprite URL when done
  Future<String?> pollJobCompletionAndUpdateSprite(String farmId, int x, int y) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return null;
      
      final seedData = await _client
          .from('farm_seeds')
          .select('*')
          .eq('farm_id', farmId)
          .eq('user_id', userId)
          .eq('x', x)
          .eq('y', y)
          .maybeSingle();
      
      if (seedData == null) return null;
      
      final properties = seedData['properties'] as Map<String, dynamic>? ?? {};
      final generationJobId = properties['generation_job_id'] as String?;
      
      if (generationJobId == null) return null;
      
      // Check the generation job status
      final jobResponse = await _client
          .from('generation_jobs')
          .select('status, final_image_url, error_message')
          .eq('id', generationJobId)
          .maybeSingle();
      
      if (jobResponse == null) return null;
      
      final status = jobResponse['status'] as String?;
      
      if (status == 'completed') {
        final imageUrl = jobResponse['final_image_url'] as String?;
        
        if (imageUrl != null) {
          // Update farm_seeds with the sprite URL
          await _client
              .from('farm_seeds')
              .update({
                'properties': {
                  ...properties,
                  'sprite_url': imageUrl,
                  'generation_completed': true,
                },
              })
              .eq('farm_id', farmId)
              .eq('user_id', userId)
              .eq('x', x)
              .eq('y', y);
          
          debugPrint('[FarmTileService] ✅ Sprite URL updated: $imageUrl');
          return imageUrl;
        }
      } else if (status == 'failed') {
        final errorMessage = jobResponse['error_message'] as String?;
        debugPrint('[FarmTileService] ❌ Generation failed: $errorMessage');
        
        // Update farm_seeds to mark generation as failed
        await _client
            .from('farm_seeds')
            .update({
              'properties': {
                ...properties,
                'generation_failed': true,
                'generation_error': errorMessage,
              },
            })
            .eq('farm_id', farmId)
            .eq('user_id', userId)
            .eq('x', x)
            .eq('y', y);
      }
      
      return null;
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Error polling job completion: $e');
      return null;
    }
  }

  /// Test method to verify sprite generation flow
  Future<void> testSpriteGeneration(String farmId, int x, int y) async {
    try {
      debugPrint('[FarmTileService] 🧪 Testing sprite generation for position ($x, $y)');
      
      // Create a test seed data
      final testSeedData = {
        'plant_type': 'daily_question_seed',
        'properties': {
          'question_text': 'What is your favorite color?',
          'answer': 'Blue',
        },
      };
      
      // Trigger sprite generation
      await _generateUniqueSpriteForSeed(farmId, x, y, testSeedData);
      
      debugPrint('[FarmTileService] ✅ Test sprite generation completed');
    } catch (e) {
      debugPrint('[FarmTileService] ❌ Test sprite generation failed: $e');
    }
  }

  /// Test method to immediately generate sprite for any seed type
  Future<void> testImmediateSpriteGeneration(String farmId, int x, int y, String plantType, Map<String, dynamic> properties) async {
    try {
      debugPrint('[FarmTileService] 🧪 TESTING: Immediate sprite generation for $plantType at ($x, $y)');
      
      // Create seed data with the provided properties
      final seedData = {
        'plant_type': plantType,
        'properties': properties,
      };
      
      // Trigger sprite generation immediately
      await _generateUniqueSpriteForSeed(farmId, x, y, seedData);
      
      debugPrint('[FarmTileService] ✅ TESTING: Immediate sprite generation completed!');
    } catch (e) {
      debugPrint('[FarmTileService] ❌ TESTING: Immediate sprite generation failed: $e');
    }
  }

  /// Comprehensive test method for immediate sprite generation
  Future<void> runSpriteGenerationTests(String farmId) async {
    try {
      debugPrint('[FarmTileService] 🧪 === STARTING SPRITE GENERATION TESTS ===');
      
      // Test 1: Daily Question Seed
      await testImmediateSpriteGeneration(
        farmId, 
        1, 1, 
        'daily_question_seed',
        {
          'question_text': 'What is your favorite color?',
          'answer': 'Blue',
        },
      );
      
      // Test 2: Memory Seed
      await testImmediateSpriteGeneration(
        farmId, 
        2, 2, 
        'memory_seed',
        {
          'text_content': 'Our first date at the beach',
        },
      );
      
      // Test 3: Generic Seed
      await testImmediateSpriteGeneration(
        farmId, 
        3, 3, 
        'love_seed',
        {
          'message': 'I love you more each day',
        },
      );
      
      debugPrint('[FarmTileService] ✅ === SPRITE GENERATION TESTS COMPLETED ===');
    } catch (e) {
      debugPrint('[FarmTileService] ❌ === SPRITE GENERATION TESTS FAILED: $e ===');
    }
  }
} 
