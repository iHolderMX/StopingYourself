class MonthlyPayment {
  final String id;
  final String userId;
  final String name;
  final double amount;
  final String type; // 'credito' o 'ahorro'
  final DateTime createdAt;

  MonthlyPayment({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    this.type = 'credito',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  MonthlyPayment copyWith({
    String? id,
    String? userId,
    String? name,
    double? amount,
    String? type,
  }) {
    return MonthlyPayment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      createdAt: createdAt,
    );
  }

  factory MonthlyPayment.fromJson(Map<String, dynamic> json) {
    return MonthlyPayment(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      type: json['type'] as String? ?? 'credito',
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
      'type': type,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
