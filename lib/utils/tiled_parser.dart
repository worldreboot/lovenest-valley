import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

/// Custom parser for Tiled tileset (.tsx) files
class TilesetParser {
  final String assetPath;
  late XmlDocument _document;
  
  // Getter for debugging
  XmlDocument get document => _document;
  
  TilesetParser(this.assetPath);

  /// Loads and parses the .tsx file using Flutter's asset system
  Future<void> load() async {
    final content = await rootBundle.loadString(assetPath);
    _document = XmlDocument.parse(content);
  }

  /// Gets basic tileset information
  Map<String, dynamic> getTilesetInfo() {
    final tileset = _document.findElements('tileset').first;
    return {
      'name': tileset.getAttribute('name'),
      'tilewidth': int.parse(tileset.getAttribute('tilewidth') ?? '16'),
      'tileheight': int.parse(tileset.getAttribute('tileheight') ?? '16'),
      'tilecount': int.parse(tileset.getAttribute('tilecount') ?? '0'),
      'columns': int.parse(tileset.getAttribute('columns') ?? '0'),
    };
  }

  /// Gets the image source path
  String? getImageSource() {
    final image = _document.findAllElements('image').firstOrNull;
    return image?.getAttribute('source');
  }

  /// For image-collection tilesets (columns == 0), returns a map of tileId -> image tile metadata
  Map<int, TilesetImageTile> getImageCollectionTiles() {
    final result = <int, TilesetImageTile>{};
    for (final tile in _document.findAllElements('tile')) {
      final tileIdStr = tile.getAttribute('id');
      if (tileIdStr == null) continue;
      final tileId = int.tryParse(tileIdStr);
      if (tileId == null) continue;
      final imageEl = tile.findElements('image').firstOrNull;
      if (imageEl == null) continue;
      final src = imageEl.getAttribute('source') ?? '';
      final w = int.tryParse(imageEl.getAttribute('width') ?? '') ?? 0;
      final h = int.tryParse(imageEl.getAttribute('height') ?? '') ?? 0;
      result[tileId] = TilesetImageTile(source: src, width: w, height: h);
    }
    return result;
  }

  /// Gets all wang tiles for auto-tiling
  List<WangTile> getWangTiles() {
    final wangTiles = <WangTile>[];
    
    // Get tileset info to determine the first GID offset
    final tilesetInfo = getTilesetInfo();
    final tilesetName = tilesetInfo['name'] ?? 'unknown';
    
    for (final wangset in _document.findAllElements('wangset')) {
      final wangColors = <WangColor>[];
      
      // Parse wang colors. Tiled assigns an implicit 1-based index.
      int colorIdCounter = 1;
      for (final wangcolor in wangset.findAllElements('wangcolor')) {
        wangColors.add(WangColor(
          id: colorIdCounter++,
          name: wangcolor.getAttribute('name') ?? '',
          color: wangcolor.getAttribute('color') ?? '',
          tile: int.tryParse(wangcolor.getAttribute('tile') ?? '-1') ?? -1,
          probability: double.tryParse(wangcolor.getAttribute('probability') ?? '1.0') ?? 1.0,
        ));
      }
      
      // Parse wang tiles with tileset-specific tile IDs
      // debugPrint('[TilesetParser] 🔍 Parsing wang tiles from $tilesetName:');
      for (final wangtile in wangset.findAllElements('wangtile')) {
        final baseTileId = int.parse(wangtile.getAttribute('tileid') ?? '0');
        final wangId = wangtile.getAttribute('wangid') ?? '';
        
        // Create a unique tile ID by combining tileset name and base tile ID
        // This prevents conflicts between different tilesets
        final uniqueTileId = _createUniqueTileId(tilesetName, baseTileId);
        
        // debugPrint('[TilesetParser]   $tilesetName: Tile ID $baseTileId -> wang ID "$wangId" (Unique ID: $uniqueTileId)');
        
        wangTiles.add(WangTile(
          tileId: uniqueTileId,
          wangId: wangId,
          wangColors: wangColors,
        ));
      }
    }
    
    return wangTiles;
  }
  
  /// Creates a unique tile ID by combining tileset name and base tile ID
  int _createUniqueTileId(String tilesetName, int baseTileId) {
    // Use a simple hash of the tileset name to create a unique namespace
    final tilesetHash = tilesetName.hashCode.abs() % 1000;
    return tilesetHash * 1000 + baseTileId;
  }

  /// Gets tile properties for specific tiles
  Map<int, Map<String, dynamic>> getTileProperties() {
    final properties = <int, Map<String, dynamic>>{};
    
    for (final tile in _document.findAllElements('tile')) {
      final tileId = int.parse(tile.getAttribute('id') ?? '0');
      final tileProps = <String, dynamic>{};
      
      // Parse properties
      for (final property in tile.findAllElements('property')) {
        final name = property.getAttribute('name') ?? '';
        final type = property.getAttribute('type') ?? 'string';
        final value = property.getAttribute('value') ?? '';
        
        // Convert value based on type
        dynamic convertedValue = value;
        switch (type) {
          case 'bool':
            convertedValue = value.toLowerCase() == 'true';
            break;
          case 'int':
            convertedValue = int.tryParse(value) ?? 0;
            break;
          case 'float':
            convertedValue = double.tryParse(value) ?? 0.0;
            break;
        }
        
        tileProps[name] = convertedValue;
      }
      
      if (tileProps.isNotEmpty) {
        properties[tileId] = tileProps;
      }
    }
    
    return properties;
  }
  
  /// Gets tile animations. Key is 0-based tile ID within this tileset.
  /// Each value is a list of frames with tileId (0-based) and durationMs.
  Map<int, List<TilesetAnimationFrame>> getTileAnimations() {
    final animations = <int, List<TilesetAnimationFrame>>{};
    for (final tile in _document.findAllElements('tile')) {
      final tileIdAttr = tile.getAttribute('id');
      if (tileIdAttr == null) continue;
      final baseTileId = int.parse(tileIdAttr);
      final animationEl = tile.findElements('animation').firstOrNull;
      if (animationEl == null) continue;
      final frames = <TilesetAnimationFrame>[];
      for (final frameEl in animationEl.findAllElements('frame')) {
        final frameTileId = int.parse(frameEl.getAttribute('tileid') ?? '0');
        final durationMs = int.parse(frameEl.getAttribute('duration') ?? '0');
        frames.add(TilesetAnimationFrame(tileId: frameTileId, durationMs: durationMs));
      }
      if (frames.isNotEmpty) {
        animations[baseTileId] = frames;
      }
    }
    return animations;
  }
}

/// Custom parser for Tiled map (.tmx) files
class MapParser {
  final String assetPath;
  late XmlDocument _document;
  
  MapParser(this.assetPath);

  /// Loads and parses the .tmx file using Flutter's asset system
  Future<void> load() async {
    final content = await rootBundle.loadString(assetPath);
    _document = XmlDocument.parse(content);
  }

  /// Gets basic map information
  Map<String, dynamic> getMapInfo() {
    final map = _document.findAllElements('map').first;
    return {
      'width': int.parse(map.getAttribute('width') ?? '0'),
      'height': int.parse(map.getAttribute('height') ?? '0'),
      'tilewidth': int.parse(map.getAttribute('tilewidth') ?? '16'),
      'tileheight': int.parse(map.getAttribute('tileheight') ?? '16'),
      'orientation': map.getAttribute('orientation') ?? 'orthogonal',
    };
  }

  /// Gets all tilesets referenced in the map
  List<TilesetReference> getTilesets() {
    final tilesets = <TilesetReference>[];
    
    for (final tileset in _document.findAllElements('tileset')) {
      tilesets.add(TilesetReference(
        firstGid: int.parse(tileset.getAttribute('firstgid') ?? '1'),
        source: tileset.getAttribute('source') ?? '',
      ));
    }
    
    return tilesets;
  }

  /// Gets layer data for a specific layer
  LayerData? getLayerData(String layerName) {
    for (final layer in _document.findAllElements('layer')) {
      if (layer.getAttribute('name') == layerName) {
        final width = int.parse(layer.getAttribute('width') ?? '0');
        final height = int.parse(layer.getAttribute('height') ?? '0');
        
        final dataElement = layer.findAllElements('data').firstOrNull;
        if (dataElement != null) {
          final encoding = dataElement.getAttribute('encoding') ?? 'csv';
          final content = dataElement.text;
          
          List<List<int>> tileData;
          if (encoding == 'csv') {
            tileData = _parseCsvData(content, width, height);
          } else {
            throw UnsupportedError('Only CSV encoding is supported');
          }
          
          return LayerData(
            name: layerName,
            width: width,
            height: height,
            data: tileData,
          );
        }
      }
    }
    return null;
  }

  /// Gets all object groups
  List<ObjectGroup> getObjectGroups() {
    final objectGroups = <ObjectGroup>[];
    
    for (final objectgroup in _document.findAllElements('objectgroup')) {
      final name = objectgroup.getAttribute('name') ?? '';
      final objects = <MapObject>[];
      
      for (final object in objectgroup.findAllElements('object')) {
        objects.add(MapObject(
          id: int.parse(object.getAttribute('id') ?? '0'),
          name: object.getAttribute('name') ?? '',
          x: double.parse(object.getAttribute('x') ?? '0'),
          y: double.parse(object.getAttribute('y') ?? '0'),
          width: double.tryParse(object.getAttribute('width') ?? '0'),
          height: double.tryParse(object.getAttribute('height') ?? '0'),
        ));
      }
      
      objectGroups.add(ObjectGroup(name: name, objects: objects));
    }
    
    return objectGroups;
  }

  /// Parses CSV data into a 2D array
  List<List<int>> _parseCsvData(String content, int width, int height) {
    // Clean the content - remove newlines and extra whitespace
    final cleanContent = content.replaceAll('\n', '').replaceAll('\r', '').trim();
    
    // Split by comma and parse all numbers
    final numbers = cleanContent.split(',').map((s) => int.parse(s.trim())).toList();
    
    // Convert to 2D array
    final data = <List<int>>[];
    for (int y = 0; y < height; y++) {
      final row = <int>[];
      for (int x = 0; x < width; x++) {
        final index = y * width + x;
        if (index < numbers.length) {
          final tileId = numbers[index];
          // Log when tile ID 55 is found
          if (tileId == 55) {
            print('[MapParser] 🔍 Found tile ID 55 at position ($x, $y)');
          }
          row.add(tileId);
        } else {
          row.add(0); // Default to empty tile
        }
      }
      data.add(row);
    }
    
    return data;
  }
}

/// Data classes for parsed information

class WangTile {
  final int tileId;
  final String wangId;
  final List<WangColor> wangColors;
  
  WangTile({
    required this.tileId,
    required this.wangId,
    required this.wangColors,
  });
  
  /// Parses the wang ID string into individual corner values
  List<int> getWangIdValues() {
    if (wangId.isEmpty) return List.filled(8, 0);
    return wangId.split(',').map((s) => int.parse(s.trim())).toList();
  }
}

class WangColor {
  final int id;
  final String name;
  final String color;
  final int tile;
  final double probability;
  
  WangColor({
    required this.id,
    required this.name,
    required this.color,
    required this.tile,
    required this.probability,
  });
}

class TilesetReference {
  final int firstGid;
  final String source;
  
  TilesetReference({
    required this.firstGid,
    required this.source,
  });
}

class LayerData {
  final String name;
  final int width;
  final int height;
  final List<List<int>> data;
  
  LayerData({
    required this.name,
    required this.width,
    required this.height,
    required this.data,
  });
}

class ObjectGroup {
  final String name;
  final List<MapObject> objects;
  
  ObjectGroup({
    required this.name,
    required this.objects,
  });
}

class MapObject {
  final int id;
  final String name;
  final double x;
  final double y;
  final double? width;
  final double? height;
  
  MapObject({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    this.width,
    this.height,
  });
}

class TilesetAnimationFrame {
  final int tileId;
  final int durationMs;
  TilesetAnimationFrame({required this.tileId, required this.durationMs});
}

/// Metadata for a per-tile image in an image-collection tileset
class TilesetImageTile {
  final String source;
  final int width;
  final int height;
  const TilesetImageTile({required this.source, required this.width, required this.height});
}

/// Auto-tiling utility class that uses a correct Wang tile algorithm.
class AutoTiler {
  final List<WangTile> wangTiles;
  final Map<int, String> gidToTerrain; // e.g. {25: "Grass", 28: "Tilled"}

  late final Map<String, int> _terrainToColorId = {};
  late final Map<int, List<int>> _tileIdToWangId = {};

  AutoTiler(this.wangTiles, this.gidToTerrain) {
    _buildLookups();
  }

  /// Builds lookup maps for faster auto-tiling.
  void _buildLookups() {
    if (wangTiles.isEmpty) return;

    // 1. Create a map from terrain name (e.g., "Grass") to wang color ID
    for (final color in wangTiles.first.wangColors) {
      _terrainToColorId[color.name] = color.id;
    }

    // 2. Create a map from a tileId to its parsed wangId list
    for (final tile in wangTiles) {
      _tileIdToWangId[tile.tileId] = tile.getWangIdValues();
    }
    
    // Debug logging
    debugPrint('[AutoTiler] 🎨 Wang color mapping:');
    for (final entry in _terrainToColorId.entries) {
      debugPrint('[AutoTiler]   ${entry.key} -> Color ID ${entry.value}');
    }
    
         debugPrint('[AutoTiler] 🧩 Wang tile mapping:');
     for (final entry in _tileIdToWangId.entries) {
       if (entry.key <= 30) { // Show more tiles to debug the issue
         debugPrint('[AutoTiler]   Tile ID ${entry.key} -> [${entry.value.join(', ')}]');
       }
     }
  }

  /// Gets the wang color ID for a given GID.
  int _getWangColorIdForGid(int gid) {
    if (gid == 0) return 0; // "No color"
    final terrain = gidToTerrain[gid];
    if (terrain == null) return 0; // Default if GID has no defined terrain
    // Fix: Wang colors are 1-indexed, so return the color ID directly
    return _terrainToColorId[terrain] ?? 0;
  }

  /// Gets the corner colors of a tile based on its GID.
  List<int> _getCornerColors(int gid) {
    if (gid == 0) return [0, 0, 0, 0];
    final originalTileId = gid - 1; 
    
    // Try to find the wang tile by searching through all unique tile IDs
    // that correspond to this original tile ID
    List<int>? wangId;
    for (final entry in _tileIdToWangId.entries) {
      final uniqueTileId = entry.key;
      final originalFromUnique = uniqueTileId % 1000;
      if (originalFromUnique == originalTileId) {
        wangId = entry.value;
        break;
      }
    }
    
    if (wangId == null) {
      // If a tile is not a wang tile, all its corners have its primary terrain color.
      final colorId = _getWangColorIdForGid(gid);
      debugPrint('[AutoTiler] 🎨 GID $gid (Tile ID $originalTileId): No wang tile, using terrain color $colorId');
      return [colorId, colorId, colorId, colorId];
    }

    // Order: top-left, top-right, bottom-right, bottom-left
    // Wang ID format: [0, top-right, 0, bottom-right, 0, bottom-left, 0, top-left]
    // Fix: Extract corners in correct order: [top-left, top-right, bottom-right, bottom-left]
    final corners = [wangId[7], wangId[1], wangId[3], wangId[5]];
    debugPrint('[AutoTiler] 🎨 GID $gid (Tile ID $originalTileId): Wang ID [${wangId.join(', ')}] -> Corners [${corners.join(', ')}]');
    return corners;
  }
  
  /// Determines the appropriate tile ID based on surrounding tiles using a scoring mechanism.
  int getTileForSurroundings(List<List<int>> surroundingTiles) {
    if (surroundingTiles.length != 3 || surroundingTiles.any((row) => row.length != 3)) {
      throw ArgumentError('surroundingTiles must be a 3x3 grid');
    }

    final centerGid = surroundingTiles[1][1];
    if (centerGid == 0) return -1; // Don't tile empty space

    final centerTerrainColor = _getWangColorIdForGid(centerGid);
    
    // Fix: Early exit if center tile is beach/water (GIDs 181-200) to prevent affecting beach tiles
    if (centerGid >= 181 && centerGid <= 200) {
      debugPrint('[AutoTiler] 🏖️ Skipping auto-tiling for beach/water tile (GID: $centerGid)');
      return -1; // Don't auto-tile beach tiles
    }
    
    // Fix: Check if center tile is surrounded by beach tiles and skip auto-tiling
    final surroundingGids = [
      surroundingTiles[0][0], surroundingTiles[0][1], surroundingTiles[0][2],
      surroundingTiles[1][0], surroundingTiles[1][2],
      surroundingTiles[2][0], surroundingTiles[2][1], surroundingTiles[2][2],
    ];
    
    final beachTileCount = surroundingGids.where((gid) => gid >= 181 && gid <= 200).length;
    if (beachTileCount >= 4) {
      debugPrint('[AutoTiler] 🏖️ Skipping auto-tiling for tile surrounded by $beachTileCount beach tiles');
      return -1; // Don't auto-tile tiles surrounded by beach
    }

    // Get corners of all 8 neighbors
    final tl_n_corners = _getCornerColors(surroundingTiles[0][0]); // Top-Left Neighbor
    final t_n_corners  = _getCornerColors(surroundingTiles[0][1]); // Top Neighbor
    final tr_n_corners = _getCornerColors(surroundingTiles[0][2]); // Top-Right Neighbor
    final l_n_corners  = _getCornerColors(surroundingTiles[1][0]); // Left Neighbor
    final r_n_corners  = _getCornerColors(surroundingTiles[1][2]); // Right Neighbor
    final bl_n_corners = _getCornerColors(surroundingTiles[2][0]); // Bottom-Left Neighbor
    final b_n_corners  = _getCornerColors(surroundingTiles[2][1]); // Bottom Neighbor
    final br_n_corners = _getCornerColors(surroundingTiles[2][2]); // Bottom-Right Neighbor

    // A helper to determine the dominant color for a corner based on its 3 influential neighbors
    int getDominantColor(List<int> colors, String cornerName) {
      debugPrint('[AutoTiler]   - $cornerName corner influencers: $colors');
      final validColors = colors.where((c) => c > 0).toList();
      if (validColors.isEmpty) return 0;
      
      // Fix: Improved intruder detection - prioritize the most common intruder
      final intruders = validColors.where((c) => c != centerTerrainColor).toList();
      if (intruders.isNotEmpty) {
        // If there are multiple different intruders, find the most common one
        final counts = <int, int>{};
        for (final color in intruders) {
          counts[color] = (counts[color] ?? 0) + 1;
        }
        int mostCommonIntruder = intruders.first;
        int maxCount = 0;
        counts.forEach((color, count) {
          if (count > maxCount) {
            maxCount = count;
            mostCommonIntruder = color;
          }
        });
        debugPrint('[AutoTiler]     -> Intruder wins: $mostCommonIntruder');
        return mostCommonIntruder;
      }
      
      // If no intruders, all neighbors match the center terrain, so the corner is that terrain
      debugPrint('[AutoTiler]     -> No intruders, result: $centerTerrainColor');
      return centerTerrainColor;
    }

    // Fix: Add terrain compatibility check to prevent cross-terrain auto-tiling
    bool areTerrainsCompatible(int terrain1, int terrain2) {
      // Define compatible terrain pairs
      final compatiblePairs = [
        [1, 4], // Tilled and Grass can blend
        [4, 1], // Grass and Tilled can blend
        [1, 1], // Tilled with Tilled
        [4, 4], // Grass with Grass
        [2, 2], // Pond with Pond
        [5, 5], // HighGround with HighGround
        [6, 6], // HighGroundMid with HighGroundMid
      ];
      
      // Check if this pair is compatible
      for (final pair in compatiblePairs) {
        if ((pair[0] == terrain1 && pair[1] == terrain2) ||
            (pair[0] == terrain2 && pair[1] == terrain1)) {
          return true;
        }
      }
      
      // Beach tiles (terrain 2 = Pond) should not blend with other terrains
      if (terrain1 == 2 || terrain2 == 2) {
        return terrain1 == terrain2; // Only beach with beach
      }
      
      return false;
    }

    // Each corner of the center tile is influenced by the 3 neighbors that touch it.
    final requiredTopLeft = getDominantColor([
      tl_n_corners[2], // BR corner of Top-Left neighbor
      t_n_corners[3],  // BL corner of Top neighbor
      l_n_corners[1]   // TR corner of Left neighbor
    ], 'Top-Left');

    final requiredTopRight = getDominantColor([
      tr_n_corners[3], // BL corner of Top-Right neighbor
      t_n_corners[2],  // BR corner of Top neighbor
      r_n_corners[0]   // TL corner of Right neighbor
    ], 'Top-Right');
    
    final requiredBottomRight = getDominantColor([
      br_n_corners[0], // TL corner of Bottom-Right neighbor
      b_n_corners[1],  // TR corner of Bottom neighbor
      r_n_corners[3]   // BL corner of Right neighbor
    ], 'Bottom-Right');

    final requiredBottomLeft = getDominantColor([
      bl_n_corners[1], // TR corner of Bottom-Left neighbor
      b_n_corners[0],  // TL corner of Bottom neighbor
      l_n_corners[2]   // BR corner of Left neighbor
    ], 'Bottom-Left');

    final requiredCorners = [requiredTopLeft, requiredTopRight, requiredBottomRight, requiredBottomLeft];

    debugPrint('[AutoTiled] 📐 Required corners: TL=${requiredCorners[0]}, TR=${requiredCorners[1]}, BR=${requiredCorners[2]}, BL=${requiredCorners[3]}');
    debugPrint('[AutoTiled] 🎯 Center terrain: $centerTerrainColor, Center GID: $centerGid');
    

    




    int bestScore = -1;
    int bestTileId = centerGid - 1; // Fallback to the original tile
    String? bestWangId;

    // Fix: Improved tile selection logic that considers terrain transitions
    for (final entry in _tileIdToWangId.entries) {
      final tileId = entry.key;
      final wangId = entry.value;

      // Extract the original tile ID from the unique tile ID
      final originalTileId = tileId % 1000;
      
      final tileCorners = [wangId[7], wangId[1], wangId[3], wangId[5]]; // tl, tr, br, bl

      // Fix: Check terrain compatibility before scoring
      final centerTerrainColor = _getWangColorIdForGid(centerGid);
      final tileCenterColor = wangId[7]; // Use top-left as center color indicator
      
      // Skip tiles that would create incompatible terrain transitions
      bool hasIncompatibleTransition = false;
      for (int i = 0; i < 4; i++) {
        if (tileCorners[i] > 0 && !areTerrainsCompatible(tileCorners[i], centerTerrainColor)) {
          hasIncompatibleTransition = true;
          break;
        }
      }
      
      if (hasIncompatibleTransition) {
        // debugPrint('[AutoTiler] ⚠️ Skipping tile $originalTileId due to incompatible terrain transitions');
        continue; // Skip this tile
      }

      int currentScore = 0;
      for (int i = 0; i < 4; i++) {
        if (tileCorners[i] == requiredCorners[i]) {
          currentScore += 2; // A perfect match is worth more.
        } else if (tileCorners[i] == 0) {
          currentScore += 1; // A wildcard match is worth something.
        }
      }

      // Bonus score for tiles that match the center terrain type
      if (tileCenterColor == centerTerrainColor) {
        currentScore += 1; // Slight preference for tiles matching center terrain
      }

      // Fix: Bonus for transition tiles when surrounded by different terrain
      final surroundingTerrainColors = [
        _getWangColorIdForGid(surroundingTiles[0][0]), // top-left
        _getWangColorIdForGid(surroundingTiles[0][1]), // top
        _getWangColorIdForGid(surroundingTiles[0][2]), // top-right
        _getWangColorIdForGid(surroundingTiles[1][0]), // left
        _getWangColorIdForGid(surroundingTiles[1][2]), // right
        _getWangColorIdForGid(surroundingTiles[2][0]), // bottom-left
        _getWangColorIdForGid(surroundingTiles[2][1]), // bottom
        _getWangColorIdForGid(surroundingTiles[2][2]), // bottom-right
      ];
      
      final differentTerrainCount = surroundingTerrainColors.where((c) => c > 0 && c != centerTerrainColor).length;
      if (differentTerrainCount >= 4) {
        // If surrounded by mostly different terrain, prefer transition tiles
        final hasMixedCorners = tileCorners.any((c) => c > 0 && c != tileCenterColor);
        if (hasMixedCorners) {
          currentScore += 2; // Bonus for transition tiles
        }
      }

      if (currentScore > bestScore) {
        bestScore = currentScore;
        bestTileId = originalTileId; // Return the original tile ID, not the unique one
        bestWangId = wangId.join(',');
      }
    }
    
    debugPrint('[AutoTiler] ✅ Selected Tile ID $bestTileId (GID ${bestTileId + 1}) with wang ID "$bestWangId" (score: $bestScore)');
    return bestTileId;
  }
}
