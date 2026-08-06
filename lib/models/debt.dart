class Debt {
  final String id;
  final String userId;
  final String name;
  final double totalAmount;
  final double paidAmount;
  final double interestRate;
  final DateTime createdAt;

  Debt({
    required this.id,
    required this.userId,
    required this.name,
    required this.totalAmount,
    this.paidAmount = 0,
    this.interestRate = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      interestRate: (json['interest_rate'] as num?)?.toDouble() ?? 0,
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
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'interest_rate': interestRate,
      'created_at': createdAt.toIso8601String(),
    };
  }

  double get remainingAmount => totalAmount - paidAmount;
  double get progress => totalAmount > 0 ? (paidAmount / totalAmount) : 0;
}

class DebtPayment {
  final String id;
  final String debtId;
  final double amount;
  final DateTime paymentDate;
  final String? note;

  DebtPayment({
    required this.id,
    required this.debtId,
    required this.amount,
    DateTime? paymentDate,
    this.note,
  }) : paymentDate = paymentDate ?? DateTime.now();

  factory DebtPayment.fromJson(Map<String, dynamic> json) {
    return DebtPayment(
      id: json['id'] as String,
      debtId: json['debt_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paymentDate: json['payment_date'] != null
          ? DateTime.parse(json['payment_date'] as String)
          : DateTime.now(),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'debt_id': debtId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'note': note,
    };
  }
}
