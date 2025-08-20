
/// Categories for relationship goals
enum RelationshipGoalCategory {
  romantic,
  fun,
  silly,
  serious,
}

/// Relationship goal model
class RelationshipGoal {
  final String id;
  final String text;
  final RelationshipGoalCategory category;
  final DateTime createdAt;
  final bool completed;
  final DateTime? completedAt;

  const RelationshipGoal({
    required this.id,
    required this.text,
    required this.category,
    required this.createdAt,
    this.completed = false,
    this.completedAt,
  });

  RelationshipGoal copyWith({
    String? id,
    String? text,
    RelationshipGoalCategory? category,
    DateTime? createdAt,
    bool? completed,
    DateTime? completedAt,
  }) {
    return RelationshipGoal(
      id: id ?? this.id,
      text: text ?? this.text,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RelationshipGoal && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  static RelationshipGoalCategory _categoryFromString(String value) {
    switch (value.toLowerCase()) {
      case 'romantic':
        return RelationshipGoalCategory.romantic;
      case 'fun':
        return RelationshipGoalCategory.fun;
      case 'silly':
        return RelationshipGoalCategory.silly;
      case 'serious':
        return RelationshipGoalCategory.serious;
      default:
        return RelationshipGoalCategory.fun;
    }
  }

  static String categoryToString(RelationshipGoalCategory c) {
    switch (c) {
      case RelationshipGoalCategory.romantic:
        return 'romantic';
      case RelationshipGoalCategory.fun:
        return 'fun';
      case RelationshipGoalCategory.silly:
        return 'silly';
      case RelationshipGoalCategory.serious:
        return 'serious';
    }
  }

  factory RelationshipGoal.fromJson(Map<String, dynamic> json) {
    return RelationshipGoal(
      id: json['id'] as String,
      text: json['text'] as String,
      category: _categoryFromString(json['category'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      completed: (json['completed'] as bool?) ?? false,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson({required String coupleId}) => {
        'id': id,
        'couple_id': coupleId,
        'text': text,
        'category': categoryToString(category),
        'completed': completed,
        'created_at': createdAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
      };
}


