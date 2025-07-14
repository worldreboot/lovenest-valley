class Couple {
  final String id;
  final String user1Id;
  final String user2Id;
  final DateTime createdAt;

  const Couple({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.createdAt,
  });

  factory Couple.fromJson(Map<String, dynamic> json) {
    return Couple(
      id: json['id'] as String,
      user1Id: json['user1_id'] as String,
      user2Id: json['user2_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user1_id': user1Id,
      'user2_id': user2Id,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Couple copyWith({
    String? id,
    String? user1Id,
    String? user2Id,
    DateTime? createdAt,
  }) {
    return Couple(
      id: id ?? this.id,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Couple &&
        other.id == id &&
        other.user1Id == user1Id &&
        other.user2Id == user2Id &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        user1Id.hashCode ^
        user2Id.hashCode ^
        createdAt.hashCode;
  }

  @override
  String toString() {
    return 'Couple(id: $id, user1Id: $user1Id, user2Id: $user2Id, createdAt: $createdAt)';
  }
} 