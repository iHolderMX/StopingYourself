class Debt {
  final String id;
  final String userId;
  final String name;
  final String debtType; // prestamo_ahorro, atraso_ahorro, tarjeta, otro
  final String linkedTo; // Ahorro, Tarjeta, Otro
  final double initialAmount;
  final double currentBalance;
  final double interestRate; // % quincenal (ej: 5.0 = 5%)
  final int paymentPeriodDays; // 15 = quincenal, 30 = mensual
  final double minPayment;
  final int gracePeriodDays; // dias maximos de atraso permitido
  final DateTime startDate;
  final DateTime createdAt;

  static const debtTypes = [
    'prestamo_ahorro',
    'atraso_ahorro',
    'tarjeta',
    'otro',
  ];

  static const debtTypeLabels = {
    'prestamo_ahorro': 'Prestamo del ahorro',
    'atraso_ahorro': 'Deuda de atraso al ahorro',
    'tarjeta': 'Tarjeta de credito',
    'otro': 'Otro',
  };

  static String linkedToFor(String debtType) {
    switch (debtType) {
      case 'prestamo_ahorro':
      case 'atraso_ahorro':
        return 'Ahorro';
      case 'tarjeta':
        return 'Tarjeta';
      default:
        return 'Otro';
    }
  }

  /// Si esta deuda afecta directamente al ahorro
  bool get isLinkedToSavings => linkedTo == 'Ahorro';

  Debt({
    required this.id,
    required this.userId,
    required this.name,
    this.debtType = 'otro',
    String? linkedTo,
    required this.initialAmount,
    required this.currentBalance,
    required this.interestRate,
    this.paymentPeriodDays = 15,
    required this.minPayment,
    this.gracePeriodDays = 30,
    required this.startDate,
    DateTime? createdAt,
  }) : linkedTo = linkedTo ?? linkedToFor(debtType),
       createdAt = createdAt ?? DateTime.now();

  /// Total de periodos transcurridos desde el inicio
  int get totalPeriods {
    final days = DateTime.now().difference(startDate).inDays;
    return days ~/ paymentPeriodDays;
  }

  /// Proximo pago programado
  DateTime get nextPaymentDue {
    final total = totalPeriods + 1;
    return startDate.add(Duration(days: total * paymentPeriodDays));
  }

  /// Dias de atraso respecto al proximo pago
  int get daysDelayed {
    final due = nextPaymentDue;
    final now = DateTime.now();
    if (now.isBefore(due)) return 0;
    if (now.isAfter(due.add(Duration(days: gracePeriodDays)))) {
      return now.difference(due).inDays;
    }
    return now.difference(due).inDays;
  }

  /// Dias de atraso reales (ignorando gracia)
  int get actualDaysDelayed {
    final due = nextPaymentDue;
    final now = DateTime.now();
    if (now.isBefore(due)) return 0;
    return now.difference(due).inDays;
  }

  /// Cuotas minimas que deberian haberse pagado hasta hoy
  int get periodsDue {
    final days = DateTime.now().difference(startDate).inDays;
    return (days / paymentPeriodDays).ceil();
  }

  /// Monto minimo total que deberia haberse pagado
  double get totalMinPaymentDue => periodsDue * minPayment;

  /// Interes acumulado por periodo vencido
  double get accruedInterest {
    double interest = 0;
    double balance = initialAmount;
    final periods = periodsDue;
    for (int i = 0; i < periods; i++) {
      final periodInterest = balance * (interestRate / 100);
      interest += periodInterest;
      balance -= minPayment;
      if (balance <= 0) break;
    }
    return interest;
  }

  /// Deuda total (saldo actual + interes acumulado)
  double get totalDebt => currentBalance + accruedInterest;

  /// Esta en periodo de gracia (atrasado pero dentro del limite)
  bool get inGracePeriod {
    final due = nextPaymentDue;
    final now = DateTime.now();
    return now.isAfter(due) &&
        now.isBefore(due.add(Duration(days: gracePeriodDays)));
  }

  /// Esta excedido del periodo de gracia
  bool get exceededGrace => daysDelayed > gracePeriodDays;

  factory Debt.fromJson(Map<String, dynamic> json) {
    final dType = json['debt_type'] as String? ?? 'otro';
    return Debt(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Deuda',
      debtType: dType,
      linkedTo: json['linked_to'] as String? ?? linkedToFor(dType),
      initialAmount: (json['initial_amount'] as num?)?.toDouble() ?? 0,
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0,
      interestRate: (json['interest_rate'] as num?)?.toDouble() ?? 0,
      paymentPeriodDays: (json['payment_period_days'] as int?) ?? 15,
      minPayment: (json['min_payment'] as num?)?.toDouble() ?? 0,
      gracePeriodDays: (json['grace_period_days'] as int?) ?? 30,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
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
      'name': name,
      'debt_type': debtType,
      'linked_to': linkedTo,
      'initial_amount': initialAmount,
      'current_balance': currentBalance,
      'interest_rate': interestRate,
      'payment_period_days': paymentPeriodDays,
      'min_payment': minPayment,
      'grace_period_days': gracePeriodDays,
      'start_date': startDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class DebtPayment {
  final String id;
  final String debtId;
  final String userId;
  final double amount;
  final DateTime paymentDate;
  final DateTime createdAt;

  DebtPayment({
    required this.id,
    required this.debtId,
    required this.userId,
    required this.amount,
    required this.paymentDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory DebtPayment.fromJson(Map<String, dynamic> json) {
    return DebtPayment(
      id: json['id'] as String,
      debtId: json['debt_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paymentDate: json['payment_date'] != null
          ? DateTime.parse(json['payment_date'] as String)
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'debt_id': debtId,
      'user_id': userId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
