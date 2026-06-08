class RelapseRecord {
  final String id;
  final String userId;
  final String relapseType;
  final String? customType;
  final DateTime relapseDate;
  final String? notes;
  final DateTime createdAt;

  RelapseRecord({
    required this.id,
    required this.userId,
    required this.relapseType,
    this.customType,
    required this.relapseDate,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RelapseRecord.fromJson(Map<String, dynamic> json) {
    return RelapseRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      relapseType: json['relapse_type'] as String? ?? '',
      customType: json['custom_type'] as String?,
      relapseDate: json['relapse_date'] != null
          ? DateTime.parse(json['relapse_date'] as String).toLocal()
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
      'relapse_type': relapseType,
      'custom_type': customType,
      'relapse_date': relapseDate.toUtc().toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
