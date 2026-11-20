import 'package:flutter_test/flutter_test.dart';
import 'package:stoping_yourself/features/daily_expenses/domain/daily_expense_occurrence.dart';
import 'package:stoping_yourself/models/daily_expense.dart';

DailyExpense _expense({
  required String id,
  required DateTime spentOn,
  double amount = 100,
  String category = 'Otros',
  String name = '',
  bool isRecurring = false,
  String? recurringId,
}) {
  return DailyExpense(
    id: id,
    userId: 'u',
    category: category,
    name: name,
    amount: amount,
    spentOn: spentOn,
    isRecurring: isRecurring,
    recurringId: recurringId,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('occurrencesForDay', () {
    test('solo trae los gastos sueltos del dia pedido', () {
      final all = [
        _expense(id: 'a', spentOn: DateTime(2026, 5, 10), amount: 50),
        _expense(id: 'b', spentOn: DateTime(2026, 5, 11), amount: 70),
      ];

      final result = occurrencesForDay(all, DateTime(2026, 5, 10));

      expect(result, hasLength(1));
      expect(result.single.amount, 50);
    });

    test('un cargo recurrente aparece desde su fecha en adelante', () {
      final all = [
        _expense(
          id: 'r',
          spentOn: DateTime(2026, 5, 10),
          amount: 80,
          isRecurring: true,
        ),
      ];

      expect(occurrencesForDay(all, DateTime(2026, 5, 9)), isEmpty);
      expect(occurrencesForDay(all, DateTime(2026, 5, 10)), hasLength(1));
      expect(occurrencesForDay(all, DateTime(2026, 6, 1)), hasLength(1));
    });

    test('una excepcion reemplaza el monto solo de ese dia', () {
      final recurring = _expense(
        id: 'r',
        spentOn: DateTime(2026, 5, 1),
        amount: 80,
        isRecurring: true,
      );
      final override = _expense(
        id: 'o',
        spentOn: DateTime(2026, 5, 12),
        amount: 120,
        recurringId: 'r',
      );

      final changed = occurrencesForDay(
        [recurring, override],
        DateTime(2026, 5, 12),
      );
      expect(changed, hasLength(1));
      expect(changed.single.amount, 120);
      expect(changed.single.isOverridden, isTrue);

      // Otro dia conserva el monto base.
      final normal = occurrencesForDay(
        [recurring, override],
        DateTime(2026, 5, 13),
      );
      expect(normal.single.amount, 80);
      expect(normal.single.isOverridden, isFalse);
    });

    test('el cargo recurrente no se duplica con su excepcion', () {
      final recurring = _expense(
        id: 'r',
        spentOn: DateTime(2026, 5, 1),
        isRecurring: true,
      );
      final override = _expense(
        id: 'o',
        spentOn: DateTime(2026, 5, 12),
        recurringId: 'r',
      );
      final suelto = _expense(id: 's', spentOn: DateTime(2026, 5, 12));

      final result = occurrencesForDay(
        [recurring, override, suelto],
        DateTime(2026, 5, 12),
      );

      expect(result, hasLength(2));
    });
  });
}
