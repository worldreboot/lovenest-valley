import '../config/supabase_config.dart';
import 'dart:math';

class Seashell {
  final String id;
  final String coupleId;
  final String userId;
  final String audioUrl;
  final Point position;
  final DateTime createdAt;
  final bool heardByCurrentUser;

  Seashell({
    required this.id,
    required this.coupleId,
    required this.userId,
    required this.audioUrl,
    required this.position,
    required this.createdAt,
    this.heardByCurrentUser = false,
  });

  factory Seashell.fromJson(Map<String, dynamic> json) {
    return Seashell(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String,
      userId: json['user_id'] as String,
      audioUrl: json['audio_url'] as String,
      position: _parsePoint(json['position'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static Point _parsePoint(String pointString) {
    // Parse PostgreSQL POINT format "(x, y)"
    final match = RegExp(r'\(([^,]+),\s*([^)]+)\)').firstMatch(pointString);
    if (match != null) {
      final x = double.parse(match.group(1)!.trim());
      final y = double.parse(match.group(2)!.trim());
      return Point(x, y);
    }
    throw FormatException('Invalid point format: $pointString');
  }
}

class Point {
  final double x;
  final double y;

  Point(this.x, this.y);
}

class SeashellService {
  static const String _seashellsTable = 'seashells';
  static const String _seashellHeardTable = 'seashell_heard';

  /// Fetch the 5 most recent seashells for the current user's couple
  static Future<List<Seashell>> fetchRecentSeashells({int limit = 5}) async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // First, get the couple ID for the current user
      final coupleResponse = await SupabaseConfig.client
          .from('couples')
          .select('id')
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .maybeSingle();

      if (coupleResponse == null) {
        // User is not in a couple, return empty list
        return [];
      }

      final coupleId = coupleResponse['id'] as String;

      // Fetch the most recent seashells for this couple
      final response = await SupabaseConfig.client
          .from(_seashellsTable)
          .select()
          .eq('couple_id', coupleId)
          .order('created_at', ascending: false)
          .limit(limit);

      final shells = (response as List)
          .map((json) => Seashell.fromJson(json))
          .toList();

      if (shells.isEmpty) {
        return shells;
      }

      // Fetch heard receipts for current user for these shells
      final shellIds = shells.map((s) => s.id).toList();
      List heardRows = [];
      if (shellIds.isNotEmpty) {
        final orFilter = shellIds.map((id) => 'seashell_id.eq.$id').join(',');
        heardRows = await SupabaseConfig.client
            .from(_seashellHeardTable)
            .select('seashell_id')
            .eq('user_id', userId)
            .or(orFilter);
      }

      final heardSet = {for (final row in heardRows) row['seashell_id'] as String};

      // Return new list with heardByCurrentUser annotated
      return shells
          .map((s) => Seashell(
                id: s.id,
                coupleId: s.coupleId,
                userId: s.userId,
                audioUrl: s.audioUrl,
                position: s.position,
                createdAt: s.createdAt,
                heardByCurrentUser: heardSet.contains(s.id),
              ))
          .toList();
    } catch (e) {
      print('Error fetching seashells: $e');
      return [];
    }
  }

  /// Mark a seashell as heard by the current user (idempotent)
  static Future<void> markSeashellHeard(String seashellId) async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    try {
      await SupabaseConfig.client.from(_seashellHeardTable).upsert({
        'seashell_id': seashellId,
        'user_id': userId,
        'heard_at': DateTime.now().toIso8601String(),
      }, onConflict: 'seashell_id,user_id');
    } catch (e) {
      print('Error marking seashell heard: $e');
    }
  }

  /// Get valid beach tile positions on the map
  /// Beach tiles are defined as tiles with x >= beachStartX (based on the farm map layout)
  static List<Point> getValidBeachPositions({
    int mapWidth = 32,
    int mapHeight = 14,
    int beachStartX = 16,
    int waterStartX = 19,
  }) {
    final beachPositions = <Point>[];
    
    for (int x = beachStartX; x < mapWidth; x++) {
      for (int y = 0; y < mapHeight; y++) {
        // Skip water tiles and edge tiles
        if (x < waterStartX && y >= 2 && y < mapHeight - 2) {
          beachPositions.add(Point(x.toDouble(), y.toDouble()));
        }
      }
    }
    
    return beachPositions;
  }

  /// Generate random positions for seashells on the beach
  static List<Point> generateSeashellPositions(
    List<Seashell> seashells, {
    int mapWidth = 32,
    int mapHeight = 14,
    int beachStartX = 16,
    int waterStartX = 19,
  }) {
    final validPositions = getValidBeachPositions(
      mapWidth: mapWidth,
      mapHeight: mapHeight,
      beachStartX: beachStartX,
      waterStartX: waterStartX,
    );
    
    print('[SeashellService] 🏖️ Found ${validPositions.length} valid beach positions');
    print('[SeashellService] 🏖️ Beach area: x=$beachStartX to $waterStartX, y=2 to ${mapHeight-2}');
    
    if (validPositions.isEmpty) {
      print('[SeashellService] ⚠️ No valid beach positions found!');
      return [];
    }

    final random = Random();
    final positions = <Point>[];
    final usedPositions = <Point>{};

    for (int i = 0; i < seashells.length && i < validPositions.length; i++) {
      Point position;
      int attempts = 0;
      
      // Try to find a unique position (avoid overlapping)
      do {
        position = validPositions[random.nextInt(validPositions.length)];
        attempts++;
      } while (usedPositions.contains(position) && attempts < 50);
      
      positions.add(position);
      usedPositions.add(position);
    }

    return positions;
  }
} 
