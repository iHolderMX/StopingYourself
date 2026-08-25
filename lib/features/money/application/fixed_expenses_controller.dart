import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/fixed_expense.dart';
import '../data/money_providers.dart';
import 'money_error_message.dart';
import 'money_id.dart';

/// Categorias disponibles para un gasto fijo.
const fixedExpenseCategories = [
  'Vivienda',
  'Alimentacion',
  'Transporte',
  'Salud',
  'Entretenimiento',
  'Servicios',
  'Educacion',
  'Otros',
];

/// Casos de uso de los gastos fijos mensuales.
class FixedExpensesController {
  const FixedExpensesController(this._ref);

  final Ref _ref;

  Future<void> add({
    required String userId,
    required String category,
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

    await _ref.read(fixedExpensesRepositoryProvider).insert(
      FixedExpense(
        id: newMoneyId(),
        userId: userId,
        category: category,
        name: trimmedName,
        amount: amount,
      ),
    );
    _invalidate(userId);
  }

  Future<void> delete({
    required String userId,
    required String expenseId,
  }) async {
    await _ref.read(fixedExpensesRepositoryProvider).delete(expenseId);
    _invalidate(userId);
  }

  void _invalidate(String userId) =>
      _ref.invalidate(fixedExpensesProvider(userId));
}

final fixedExpensesControllerProvider = Provider<FixedExpensesController>(
  FixedExpensesController.new,
);
