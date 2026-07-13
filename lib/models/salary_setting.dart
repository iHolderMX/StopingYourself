class SalarySetting {
  final String userId;
  final double monthlySalary;
  final double dailyReturn;
  final DateTime updatedAt;

  SalarySetting({
    required this.userId,
    required this.monthlySalary,
    this.dailyReturn = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory SalarySetting.fromJson(Map<String, dynamic> json) {
    return SalarySetting(
      userId: json['user_id'] as String? ?? '',
      monthlySalary: (json['monthly_salary'] as num?)?.toDouble() ?? 0,
      dailyReturn: (json['daily_return'] as num?)?.toDouble() ?? 0,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'monthly_salary': monthlySalary,
      'daily_return': dailyReturn,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
