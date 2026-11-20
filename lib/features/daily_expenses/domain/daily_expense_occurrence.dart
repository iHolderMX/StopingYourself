import '../../../models/daily_expense.dart';

/// Un gasto ya resuelto para un dia concreto.
///
/// Para un gasto suelto, [entry] es el propio gasto y [override] es `null`.
/// Para un cargo recurrente, [entry] es la plantilla y [override] es la
/// excepcion de ese dia, si el usuario cambio el monto solo para esa fecha.
class DailyExpenseOccurrence {
  const DailyExpenseOccurrence({required this.entry, this.override});

  final DailyExpense entry;
  final DailyExpense? override;

  bool get isRecurring => entry.isRecurring;
  bool get isOverridden => override != null;

  double get amount => override?.amount ?? entry.amount;
  String get category => override?.category ?? entry.category;

  /// Detalle a mostrar: el del override si existe, si no el de la plantilla,
  /// y si no hay detalle cae a la categoria.
  String get label {
    final name = override?.name ?? entry.name;
    return name.isNotEmpty ? name : category;
  }
}

/// Resuelve que gastos se ven en [day].
///
/// - Gastos sueltos cuya fecha es [day].
/// - Cargos recurrentes activos: todos los que empezaron en [day] o antes.
/// - Si un cargo recurrente tiene una excepcion para [day], se usa esa.
List<DailyExpenseOccurrence> occurrencesForDay(
  List<DailyExpense> all,
  DateTime day,
) {
  final target = _dateOnly(day);

  final overridesByTemplate = <String, DailyExpense>{};
  for (final expense in all) {
    final templateId = expense.recurringId;
    if (templateId != null && _sameDay(expense.spentOn, target)) {
      overridesByTemplate[templateId] = expense;
    }
  }

  final occurrences = <DailyExpenseOccurrence>[];

  for (final expense in all) {
    if (expense.isRecurring) {
      // El cargo aplica desde el dia en que se creo hacia adelante.
      if (_dateOnly(expense.spentOn).isAfter(target)) continue;
      occurrences.add(
        DailyExpenseOccurrence(
          entry: expense,
          override: overridesByTemplate[expense.id],
        ),
      );
    } else if (expense.recurringId == null &&
        _sameDay(expense.spentOn, target)) {
      occurrences.add(DailyExpenseOccurrence(entry: expense));
    }
  }

  occurrences.sort((a, b) => a.entry.createdAt.compareTo(b.entry.createdAt));
  return occurrences;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
