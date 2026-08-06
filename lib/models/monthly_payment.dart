class MonthlyPayment {
  final String id;
  final String userId;
  final String name;
  final double amount;
  final int dayOfMonth;
  final DateTime createdAt;

  MonthlyPayment({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    this.dayOfMonth = 1,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MonthlyPayment.fromJson(Map<String, dynamic> json) {
    return MonthlyPayment(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      dayOfMonth: (json['day_of_month'] as num?)?.toInt() ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'amount': amount,
      'day_of_month': dayOfMonth,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
