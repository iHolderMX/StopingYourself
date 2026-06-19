class SavingGoal {
  final String id;
  final String userId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String? url;
  final DateTime createdAt;
  final bool isCompleted;

  SavingGoal({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.url,
    DateTime? createdAt,
    this.isCompleted = false,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SavingGoal.fromJson(Map<String, dynamic> json) {
    return SavingGoal(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      targetAmount: (json['target_amount'] as num?)?.toDouble() ?? 0,
      currentAmount: (json['current_amount'] as num?)?.toDouble() ?? 0,
      url: json['url'] as String?,
      isCompleted: json['is_completed'] as bool? ?? false,
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
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'url': url,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
    };
  }

  double get progress => targetAmount > 0 ? (currentAmount / targetAmount) : 0;
  double get remainingAmount => targetAmount - currentAmount;
}
