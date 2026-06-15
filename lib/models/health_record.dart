class HealthRecord {
  final String id;
  final String userId;
  final int steps;
  final DateTime recordDate;
  final String? notes;
  final DateTime createdAt;

  HealthRecord({
    required this.id,
    required this.userId,
    required this.steps,
    required this.recordDate,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    return HealthRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      recordDate: json['record_date'] != null
          ? DateTime.parse(json['record_date'] as String).toLocal()
          : DateTime.now(),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'steps': steps,
      'record_date': recordDate.toUtc().toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Kilometros estimados (promedio ~0.75m por paso)
  double get km => steps * 0.00075;

  /// Calorias estimadas (~0.04 por paso)
  double get calories => steps * 0.04;
}
