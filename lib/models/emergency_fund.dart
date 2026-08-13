class EmergencyFund {
  final String id;
  final String userId;
  final String name;
  final String sourceRecordId; // money_record del cual proviene
  final double amount;
  final double annualYield; // rendimiento anual en %
  final DateTime createdAt;

  EmergencyFund({
    required this.id,
    required this.userId,
    required this.name,
    required this.sourceRecordId,
    required this.amount,
    this.annualYield = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get dailyEarnings {
    if (annualYield <= 0 || amount <= 0) return 0;
    return amount * (annualYield / 100) / 365;
  }

  factory EmergencyFund.fromJson(Map<String, dynamic> json) {
    return EmergencyFund(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sourceRecordId: json['source_record_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      annualYield: (json['annual_yield'] as num?)?.toDouble() ?? 0,
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
      'source_record_id': sourceRecordId,
      'amount': amount,
      'annual_yield': annualYield,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class EmergencyFundEntry {
  final String id;
  final String emergencyFundId;
  final String name;
  final double amount;
  final double annualYield;
  final DateTime createdAt;

  EmergencyFundEntry({
    required this.id,
    required this.emergencyFundId,
    required this.name,
    required this.amount,
    this.annualYield = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get dailyEarnings {
    if (annualYield <= 0 || amount <= 0) return 0;
    return amount * (annualYield / 100) / 365;
  }

  factory EmergencyFundEntry.fromJson(Map<String, dynamic> json) {
    return EmergencyFundEntry(
      id: json['id'] as String,
      emergencyFundId: json['emergency_fund_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      annualYield: (json['annual_yield'] as num?)?.toDouble() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'emergency_fund_id': emergencyFundId,
      'name': name,
      'amount': amount,
      'annual_yield': annualYield,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
