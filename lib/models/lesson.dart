class Lesson {
  final String id;
  final String categoryId;
  final String title;
  final String description;
  final int difficultyLevel;
  final int sortOrder;
  final Map<String, dynamic>? content;

  Lesson({
    required this.id,
    required this.categoryId,
    required this.title,
    this.description = '',
    this.difficultyLevel = 1,
    this.sortOrder = 0,
    this.content,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      categoryId: json['category_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      difficultyLevel: json['difficulty_level'] as int? ?? 1,
      sortOrder: json['sort_order'] as int? ?? 0,
      content: json['content'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'title': title,
      'description': description,
      'difficulty_level': difficultyLevel,
      'sort_order': sortOrder,
      'content': content,
    };
  }
}
