class UserProgress {
  final String id;
  final String userId;
  final String lessonId;
  final bool completed;
  final int score;
  final DateTime? completedAt;

  UserProgress({
    required this.id,
    required this.userId,
    required this.lessonId,
    this.completed = false,
    this.score = 0,
    this.completedAt,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      lessonId: json['lesson_id'] as String? ?? '',
      completed: json['completed'] as bool? ?? false,
      score: json['score'] as int? ?? 0,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'lesson_id': lessonId,
      'completed': completed,
      'score': score,
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}
