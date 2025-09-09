import 'package:flutter/material.dart';

class DailyQuestionSeed {
  final String id;
  final String userId;
  final String questionId;
  final String questionText;
  final String userAnswer;
  final Color seedColor;
  final DateTime collectedAt;
  final bool isPlanted;
  final DateTime? plantedAt;
  final int waterCount;
  final DateTime? lastWateredAt;
  final String growthStage;
  final String? generatedSpriteUrl;

  DailyQuestionSeed({
    required this.id,
    required this.userId,
    required this.questionId,
    required this.questionText,
    required this.userAnswer,
    required this.seedColor,
    required this.collectedAt,
    required this.isPlanted,
    this.plantedAt,
    required this.waterCount,
    this.lastWateredAt,
    required this.growthStage,
    this.generatedSpriteUrl,
  });

  factory DailyQuestionSeed.fromMap(Map<String, dynamic> map) {
    return DailyQuestionSeed(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      questionId: map['question_id'] as String,
      questionText: map['question_text'] as String,
      userAnswer: map['user_answer'] as String,
      seedColor: _parseColor(map['seed_color_hex'] as String?),
      collectedAt: DateTime.parse(map['collected_at'] as String),
      isPlanted: map['is_planted'] as bool? ?? false,
      plantedAt: map['planted_at'] != null 
          ? DateTime.parse(map['planted_at'] as String) 
          : null,
      waterCount: map['water_count'] as int? ?? 0,
      lastWateredAt: map['last_watered_at'] != null 
          ? DateTime.parse(map['last_watered_at'] as String) 
          : null,
      growthStage: map['growth_stage'] as String? ?? 'collected',
      generatedSpriteUrl: map['generated_sprite_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'question_id': questionId,
      'question_text': questionText,
      'user_answer': userAnswer,
      'seed_color_hex': '#${seedColor.value.toRadixString(16).padLeft(8, '0')}',
      'collected_at': collectedAt.toIso8601String(),
      'is_planted': isPlanted,
      'planted_at': plantedAt?.toIso8601String(),
      'water_count': waterCount,
      'last_watered_at': lastWateredAt?.toIso8601String(),
      'growth_stage': growthStage,
      'generated_sprite_url': generatedSpriteUrl,
    };
  }

  static Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return Colors.grey; // Default color
    }
    
    // Remove # if present
    final cleanHex = hexColor.startsWith('#') ? hexColor.substring(1) : hexColor;
    
    try {
      return Color(int.parse(cleanHex, radix: 16));
    } catch (e) {
      return Colors.grey; // Fallback color
    }
  }

  DailyQuestionSeed copyWith({
    String? id,
    String? userId,
    String? questionId,
    String? questionText,
    String? userAnswer,
    Color? seedColor,
    DateTime? collectedAt,
    bool? isPlanted,
    DateTime? plantedAt,
    int? waterCount,
    DateTime? lastWateredAt,
    String? growthStage,
    String? generatedSpriteUrl,
  }) {
    return DailyQuestionSeed(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      questionId: questionId ?? this.questionId,
      questionText: questionText ?? this.questionText,
      userAnswer: userAnswer ?? this.userAnswer,
      seedColor: seedColor ?? this.seedColor,
      collectedAt: collectedAt ?? this.collectedAt,
      isPlanted: isPlanted ?? this.isPlanted,
      plantedAt: plantedAt ?? this.plantedAt,
      waterCount: waterCount ?? this.waterCount,
      lastWateredAt: lastWateredAt ?? this.lastWateredAt,
      growthStage: growthStage ?? this.growthStage,
      generatedSpriteUrl: generatedSpriteUrl ?? this.generatedSpriteUrl,
    );
  }
} 
