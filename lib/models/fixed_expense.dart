class FixedExpense {
  final String id;
  final String userId;
  final String category;
  final String name;
  final double amount;
  final DateTime createdAt;

  FixedExpense({
    required this.id,
    required this.userId,
    required this.category,
    required this.name,
    required this.amount,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory FixedExpense.fromJson(Map<String, dynamic> json) {
    return FixedExpense(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      category: json['category'] as String? ?? 'Otros',
      name: json['name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category': category,
      'name': name,
      'amount': amount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
