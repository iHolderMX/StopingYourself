import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/quincena_expense.dart';
import '../data/money_providers.dart';
import 'money_error_message.dart';
import 'money_id.dart';

/// Casos de uso de los gastos planeados de la proxima quincena.
class QuincenaController {
  const QuincenaController(this._ref);

  final Ref _ref;

  Future<void> addExpense({
    required String userId,
    required String name,
    required double amount,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const MoneyValidationException('Ponle nombre al gasto.');
    }
    if (amount <= 0) {
      throw const MoneyValidationException('Ingresa un monto mayor a cero.');
    }

    await _ref.read(quincenaRepositoryProvider).insert(
      QuincenaExpense(
        id: newMoneyId(),
        userId: userId,
        name: trimmedName,
        amount: amount,
      ),
    );
    _invalidate(userId);
  }

  Future<void> deleteExpense({
    required String userId,
    required String expenseId,
  }) async {
    await _ref.read(quincenaRepositoryProvider).delete(expenseId);
    _invalidate(userId);
  }

  Future<void> resetExpenses(String userId) async {
    await _ref.read(quincenaRepositoryProvider).deleteAllOf(userId);
    _invalidate(userId);
  }

  void _invalidate(String userId) =>
      _ref.invalidate(quincenaExpensesProvider(userId));
}

final quincenaControllerProvider = Provider<QuincenaController>(
  QuincenaController.new,
);
