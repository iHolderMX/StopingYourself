class LolRecord {
  final String id;
  final String userId;
  final double plGained;
  final double plLost;
  final DateTime recordDate;
  final DateTime createdAt;

  LolRecord({
    required this.id,
    required this.userId,
    required this.plGained,
    required this.plLost,
    required this.recordDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  LolRecord copyWith({
    String? id,
    String? userId,
    double? plGained,
    double? plLost,
    DateTime? recordDate,
  }) {
    return LolRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      plGained: plGained ?? this.plGained,
      plLost: plLost ?? this.plLost,
      recordDate: recordDate ?? this.recordDate,
      createdAt: createdAt,
    );
  }

  double get netPl => plGained - plLost;

  factory LolRecord.fromJson(Map<String, dynamic> json) {
    return LolRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      plGained: (json['pl_gained'] as num?)?.toDouble() ?? 0.0,
      plLost: (json['pl_lost'] as num?)?.toDouble() ?? 0.0,
      recordDate: json['record_date'] != null
          ? DateTime.parse(json['record_date'] as String).toLocal()
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'pl_gained': plGained,
      'pl_lost': plLost,
      'record_date': recordDate.toUtc().toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
