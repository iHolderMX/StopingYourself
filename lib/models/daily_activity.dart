enum ActivityType { boolean, numeric }

class DailyActivity {
  final String id;
  final String userId;
  final String title;
  final bool isCompleted;
  final DateTime scheduledDate;
  final DateTime? completedAt;
  final DateTime createdAt;
  final ActivityType activityType;
  final num? currentValue;
  final num? targetValue;
  final String? unit;
  final num stepValue;
  final String? templateId;

  DailyActivity({
    required this.id,
    required this.userId,
    required this.title,
    this.isCompleted = false,
    required this.scheduledDate,
    this.completedAt,
    DateTime? createdAt,
    this.activityType = ActivityType.boolean,
    this.currentValue,
    this.targetValue,
    this.unit,
    this.stepValue = 1,
    this.templateId,
  }) : createdAt = createdAt ?? DateTime.now();

  double get progress {
    if (targetValue == null || targetValue == 0) return isCompleted ? 1.0 : 0.0;
    return ((currentValue ?? 0) / targetValue!).clamp(0.0, 1.0);
  }

  DailyActivity copyWith({
    String? id,
    String? userId,
    String? title,
    bool? isCompleted,
    DateTime? scheduledDate,
    DateTime? completedAt,
    ActivityType? activityType,
    num? currentValue,
    num? targetValue,
    String? unit,
    num? stepValue,
    String? templateId,
  }) {
    return DailyActivity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      activityType: activityType ?? this.activityType,
      currentValue: currentValue ?? this.currentValue,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      stepValue: stepValue ?? this.stepValue,
      templateId: templateId ?? this.templateId,
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
      activityType: _parseActivityType(json['activity_type']),
      currentValue: json['current_value'] as num?,
      targetValue: json['target_value'] as num?,
      unit: json['unit'] as String?,
      stepValue: (json['step_value'] as num?) ?? 1,
      templateId: json['template_id'] as String?,
    );
  }

  static ActivityType _parseActivityType(dynamic value) {
    if (value == 'numeric') return ActivityType.numeric;
    return ActivityType.boolean;
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
      'activity_type': activityType.name,
      'current_value': currentValue,
      'target_value': targetValue,
      'unit': unit,
      'step_value': stepValue,
      'template_id': templateId,
    };
  }
}
