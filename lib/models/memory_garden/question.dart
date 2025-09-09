class Question {
  final String id;
  final String text;
  final DateTime createdAt;

  Question({
    required this.id,
    required this.text,
    required this.createdAt,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
} 
