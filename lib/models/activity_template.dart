import 'daily_activity.dart' show ActivityType;

/// Frecuencia con la que se repite un hábito.
enum ActivityFrequency { daily, weekly, monthly, custom }

/// Definición de un hábito/actividad recurrente.
/// Es la "plantilla" que luego genera registros diarios en `daily_activities`.
class ActivityTemplate {
  final String id;
  final String userId;
  final String title;
  final ActivityType activityType;
  final num? targetValue;
  final String? unit;
  final num stepValue;
  final String? category;
  final ActivityFrequency frequency;
  final Map<String, dynamic> frequencyConfig;
  final int position;
  final int priority;
  final int graceDays;
  final bool reminderEnabled;
  final String? reminderTime;
  final bool isArchived;
  final DateTime createdAt;

  ActivityTemplate({
    required this.id,
    required this.userId,
    required this.title,
    this.activityType = ActivityType.boolean,
    this.targetValue,
    this.unit,
    this.stepValue = 1,
    this.category,
    this.frequency = ActivityFrequency.daily,
    this.frequencyConfig = const {},
    this.position = 0,
    this.priority = 0,
    this.graceDays = 0,
    this.reminderEnabled = false,
    this.reminderTime,
    this.isArchived = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  ActivityTemplate copyWith({
    String? id,
    String? userId,
    String? title,
    ActivityType? activityType,
    num? targetValue,
    String? unit,
    num? stepValue,
    String? category,
    ActivityFrequency? frequency,
    Map<String, dynamic>? frequencyConfig,
    int? position,
    int? priority,
    int? graceDays,
    bool? reminderEnabled,
    String? reminderTime,
    bool? isArchived,
  }) {
    return ActivityTemplate(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      activityType: activityType ?? this.activityType,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      stepValue: stepValue ?? this.stepValue,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      frequencyConfig: frequencyConfig ?? this.frequencyConfig,
      position: position ?? this.position,
      priority: priority ?? this.priority,
      graceDays: graceDays ?? this.graceDays,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
    );
  }

  factory ActivityTemplate.fromJson(Map<String, dynamic> json) {
    return ActivityTemplate(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      activityType: _parseActivityType(json['activity_type']),
      targetValue: json['target_value'] as num?,
      unit: json['unit'] as String?,
      stepValue: (json['step_value'] as num?) ?? 1,
      category: json['category'] as String?,
      frequency: _parseFrequency(json['frequency_type']),
      frequencyConfig:
          (json['frequency_config'] as Map?)?.cast<String, dynamic>() ?? {},
      position: (json['position'] as num?)?.toInt() ?? 0,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      graceDays: (json['grace_days'] as num?)?.toInt() ?? 0,
      reminderEnabled: (json['reminder_enabled'] as bool?) ?? false,
      reminderTime: json['reminder_time'] as String?,
      isArchived: (json['is_archived'] as bool?) ?? false,
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
      'activity_type': activityType.name,
      'target_value': targetValue,
      'unit': unit,
      'step_value': stepValue,
      'category': category,
      'frequency_type': frequency.name,
      'frequency_config': frequencyConfig,
      'position': position,
      'priority': priority,
      'grace_days': graceDays,
      'reminder_enabled': reminderEnabled,
      'reminder_time': reminderTime,
      'is_archived': isArchived,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Indica si esta plantilla corresponde al día [date].
  bool occursOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    switch (frequency) {
      case ActivityFrequency.daily:
        return true;
      case ActivityFrequency.weekly:
        final days = _intList(frequencyConfig['days_of_week']);
        if (days.isEmpty) return true;
        return days.contains(day.weekday); // 1=lun .. 7=dom
      case ActivityFrequency.monthly:
        final days = _intList(frequencyConfig['days_of_month']);
        if (days.isEmpty) return day.day == 1;
        return days.contains(day.day);
      case ActivityFrequency.custom:
        final interval = (frequencyConfig['interval_days'] as num?)?.toInt() ?? 1;
        if (interval <= 0) return true;
        final start = DateTime(createdAt.year, createdAt.month, createdAt.day);
        final diff = day.difference(start).inDays;
        return diff >= 0 && diff % interval == 0;
    }
  }

  static List<int> _intList(dynamic value) {
    if (value is List) {
      return value.whereType<num>().map((e) => e.toInt()).toList();
    }
    return const [];
  }

  static ActivityType _parseActivityType(dynamic value) {
    if (value == 'numeric') return ActivityType.numeric;
    return ActivityType.boolean;
  }

  static ActivityFrequency _parseFrequency(dynamic value) {
    switch (value) {
      case 'weekly':
        return ActivityFrequency.weekly;
      case 'monthly':
        return ActivityFrequency.monthly;
      case 'custom':
        return ActivityFrequency.custom;
      default:
        return ActivityFrequency.daily;
    }
  }
}
