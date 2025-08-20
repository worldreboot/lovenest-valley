import 'package:flutter/material.dart';

class SeedColorGenerator {
  static const List<Color> _seedColors = [
    Color(0xFFFF6B6B), // Coral Red
    Color(0xFF4ECDC4), // Turquoise
    Color(0xFF45B7D1), // Sky Blue
    Color(0xFF96CEB4), // Mint Green
    Color(0xFFFFEAA7), // Warm Yellow
    Color(0xFFDDA0DD), // Plum
    Color(0xFF98D8C8), // Seafoam
    Color(0xFFF7DC6F), // Golden Yellow
    Color(0xFFBB8FCE), // Lavender
    Color(0xFF85C1E9), // Light Blue
    Color(0xFFF8C471), // Orange
    Color(0xFF82E0AA), // Light Green
    Color(0xFFF1948A), // Salmon Pink
    Color(0xFF85C1E9), // Baby Blue
    Color(0xFFFAD7A0), // Peach
    Color(0xFFD7BDE2), // Light Purple
    Color(0xFFA9DFBF), // Mint
    Color(0xFFF9E79F), // Cream Yellow
    Color(0xFFD5A6BD), // Rose Pink
    Color(0xFFA3E4D7), // Aqua
  ];

  /// Generate a unique color for a daily question seed based on the question ID
  static Color generateSeedColor(String questionId) {
    // Deterministic color based on questionId
    // FNV-1a 32-bit hash for stable distribution
    int hash = 0x811C9DC5;
    const int fnvPrime = 0x01000193;
    for (int i = 0; i < questionId.length; i++) {
      hash ^= questionId.codeUnitAt(i);
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }

    // Option A: pick from curated palette for consistent, pleasing colors
    final paletteIndex = hash % _seedColors.length;
    return _seedColors[paletteIndex];
  }



  /// Get a color name for display purposes
  static String getColorName(Color color) {
    if (color == const Color(0xFFFF6B6B)) return 'Coral';
    if (color == const Color(0xFF4ECDC4)) return 'Turquoise';
    if (color == const Color(0xFF45B7D1)) return 'Sky Blue';
    if (color == const Color(0xFF96CEB4)) return 'Mint';
    if (color == const Color(0xFFFFEAA7)) return 'Golden';
    if (color == const Color(0xFFDDA0DD)) return 'Plum';
    if (color == const Color(0xFF98D8C8)) return 'Seafoam';
    if (color == const Color(0xFFF7DC6F)) return 'Sunshine';
    if (color == const Color(0xFFBB8FCE)) return 'Lavender';
    if (color == const Color(0xFF85C1E9)) return 'Ocean';
    if (color == const Color(0xFFF8C471)) return 'Sunset';
    if (color == const Color(0xFF82E0AA)) return 'Spring';
    if (color == const Color(0xFFF1948A)) return 'Salmon';
    if (color == const Color(0xFFFAD7A0)) return 'Peach';
    if (color == const Color(0xFFD7BDE2)) return 'Lilac';
    if (color == const Color(0xFFA9DFBF)) return 'Fresh';
    if (color == const Color(0xFFF9E79F)) return 'Cream';
    if (color == const Color(0xFFD5A6BD)) return 'Rose';
    if (color == const Color(0xFFA3E4D7)) return 'Aqua';
    
    return 'Unique';
  }
} 