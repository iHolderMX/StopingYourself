/// Gasto del dia, registrado por categoria.
///
/// Es un registro informativo: sirve para reflexionar cuanto se gasta cada
/// dia. `spentOn` guarda solo la fecha (sin hora) porque el gasto se agrupa
/// por dia, mientras que `createdAt` conserva el instante exacto del registro.
///
/// Hay tres tipos de fila:
/// - **Gasto suelto**: `isRecurring == false` y `recurringId == null`.
/// - **Cargo recurrente**: `isRecurring == true`. Es la plantilla que se
///   repite todos los dias a partir de su `spentOn`.
/// - **Excepcion de un dia**: `recurringId != null`. Guarda un monto distinto
///   solo para un dia puntual de un cargo recurrente.
class DailyExpense {
  final String id;
  final String userId;
  final String category;
  final String name;
  final double amount;
  final DateTime spentOn;
  final bool isRecurring;
  final String? recurringId;
  final DateTime createdAt;

  DailyExpense({
    required this.id,
    required this.userId,
    required this.category,
    required this.name,
    required this.amount,
    required this.spentOn,
    this.isRecurring = false,
    this.recurringId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory DailyExpense.fromJson(Map<String, dynamic> json) {
    return DailyExpense(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      category: json['category'] as String? ?? 'Otros',
      name: json['name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      spentOn: json['spent_on'] != null
          ? DateTime.parse(json['spent_on'] as String)
          : DateTime.now(),
      isRecurring: json['is_recurring'] as bool? ?? false,
      recurringId: json['recurring_id'] as String?,
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
      'spent_on': _dateOnly(spentOn),
      'is_recurring': isRecurring,
      'recurring_id': recurringId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  DailyExpense copyWith({
    String? category,
    String? name,
    double? amount,
    DateTime? spentOn,
  }) {
    return DailyExpense(
      id: id,
      userId: userId,
      category: category ?? this.category,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      spentOn: spentOn ?? this.spentOn,
      isRecurring: isRecurring,
      recurringId: recurringId,
      createdAt: createdAt,
    );
  }

  /// Formatea la fecha como `YYYY-MM-DD`, que es lo que espera la columna
  /// `DATE` de Postgres. Mandar la hora completa rompe el tipo.
  static String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
