class MoneyRecord {
  final String id;
  final String userId;
  final String type;
  final double amount;
  final double annualYield; // rendimiento anual en % (ej: 10.5 = 10.5%)
  final String? description;
  final DateTime date;
  final DateTime createdAt;

  MoneyRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    this.annualYield = 0,
    this.description,
    required this.date,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Ganancia diaria estimada basada en el rendimiento anual
  double get dailyEarnings {
    if (annualYield <= 0) return 0;
    return amount * (annualYield / 100) / 365;
  }

  factory MoneyRecord.fromJson(Map<String, dynamic> json) {
    return MoneyRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      annualYield: (json['annual_yield'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String?,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
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
      'type': type,
      'amount': amount,
      'annual_yield': annualYield,
      'description': description,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
