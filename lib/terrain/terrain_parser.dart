import 'package:xml/xml.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'terrain_type.dart';

class TerrainParser {
  // Public method to be called during game loading
  static Future<Map<String, int>> parseWangsetToSignatureMap(
    String tsxFilePath,
    int firstGid,
  ) async {
    final Map<String, int> lookupTable = {};
    final fileContent = await rootBundle.loadString(tsxFilePath);
    final document = XmlDocument.parse(fileContent);

    final wangsetNode = document.findAllElements('wangset').firstWhere(
          (node) => node.getAttribute('type') == 'corner',
        );

    for (final wangtile in wangsetNode.findAllElements('wangtile')) {
      final tileId = int.parse(wangtile.getAttribute('tileid')!);
      final wangIdStr = wangtile.getAttribute('wangid')!;
      final wangIds = wangIdStr.split(',').map(int.parse).toList();

      // IMPORTANT: Use the correct indices for corner mapping
      // Tiled format: [N, NE, E, SE, S, SW, W, NW] -> Indices [0,1,2,3,4,5,6,7]
      // Our standard signature: (TL, TR, BL, BR)
      final tl_id = wangIds[7]; // Top-Left is at index 7
      final tr_id = wangIds[1]; // Top-Right is at index 1
      final bl_id = wangIds[5]; // Bottom-Left is at index 5
      final br_id = wangIds[3]; // Bottom-Right is at index 3

      // Create the signature key
      final signatureKey = "$tl_id,$tr_id,$bl_id,$br_id";
      
      final gid = firstGid + tileId;

      lookupTable[signatureKey] = gid;
    }

    return lookupTable;
  }
} 
