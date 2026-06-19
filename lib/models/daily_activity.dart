class DailyActivity {
  final String id;
  final String userId;
  final String title;
  final bool isCompleted;
  final DateTime scheduledDate;
  final DateTime? completedAt;
  final DateTime createdAt;

  DailyActivity({
    required this.id,
    required this.userId,
    required this.title,
    this.isCompleted = false,
    required this.scheduledDate,
    this.completedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  DailyActivity copyWith({
    String? id,
    String? userId,
    String? title,
    bool? isCompleted,
    DateTime? scheduledDate,
    DateTime? completedAt,
  }) {
    return DailyActivity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
    );
  }

  factory DailyActivity.fromJson(Map<String, dynamic> json) {
    return DailyActivity(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      isCompleted: (json['is_completed'] as bool?) ?? false,
      scheduledDate: json['scheduled_date'] != null
          ? DateTime.parse(json['scheduled_date'] as String).toLocal()
          : DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String).toLocal()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'is_completed': isCompleted,
      'scheduled_date': scheduledDate.toUtc().toIso8601String(),
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
