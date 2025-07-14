enum InteractionType { water, replyVoice, replyText, reaction }

class WaterReply {
  final String id;
  final String seedId;
  final String userId;
  final InteractionType type;
  final String? contentUrl;
  final String? textContent;
  final DateTime createdAt;

  const WaterReply({
    required this.id,
    required this.seedId,
    required this.userId,
    required this.type,
    this.contentUrl,
    this.textContent,
    required this.createdAt,
  });

  factory WaterReply.fromJson(Map<String, dynamic> json) {
    return WaterReply(
      id: json['id'] as String,
      seedId: json['seed_id'] as String,
      userId: json['user_id'] as String,
      type: _parseType(json['type'] as String),
      contentUrl: json['content_url'] as String?,
      textContent: json['text_content'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seed_id': seedId,
      'user_id': userId,
      'type': _typeToString(type),
      'content_url': contentUrl,
      'text_content': textContent,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static InteractionType _parseType(String type) {
    switch (type) {
      case 'water':
        return InteractionType.water;
      case 'reply_voice':
        return InteractionType.replyVoice;
      case 'reply_text':
        return InteractionType.replyText;
      case 'reaction':
        return InteractionType.reaction;
      default:
        return InteractionType.water;
    }
  }

  static String _typeToString(InteractionType type) {
    switch (type) {
      case InteractionType.water:
        return 'water';
      case InteractionType.replyVoice:
        return 'reply_voice';
      case InteractionType.replyText:
        return 'reply_text';
      case InteractionType.reaction:
        return 'reaction';
    }
  }

  WaterReply copyWith({
    String? id,
    String? seedId,
    String? userId,
    InteractionType? type,
    String? contentUrl,
    String? textContent,
    DateTime? createdAt,
  }) {
    return WaterReply(
      id: id ?? this.id,
      seedId: seedId ?? this.seedId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      contentUrl: contentUrl ?? this.contentUrl,
      textContent: textContent ?? this.textContent,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WaterReply &&
        other.id == id &&
        other.seedId == seedId &&
        other.userId == userId &&
        other.type == type &&
        other.contentUrl == contentUrl &&
        other.textContent == textContent &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        seedId.hashCode ^
        userId.hashCode ^
        type.hashCode ^
        contentUrl.hashCode ^
        textContent.hashCode ^
        createdAt.hashCode;
  }

  @override
  String toString() {
    return 'WaterReply(id: $id, seedId: $seedId, userId: $userId, '
        'type: $type, createdAt: $createdAt)';
  }
} 