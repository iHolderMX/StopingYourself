import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/daily_expense.dart';
import '../../money/application/fixed_expenses_controller.dart';
import '../../money/application/money_error_message.dart';
import '../../money/application/money_id.dart';
import '../data/daily_expenses_providers.dart';

/// Categorias del gasto diario.
///
/// Se reutilizan las de gastos fijos para que el usuario no tenga que
/// aprenderse dos taxonomias distintas.
const dailyExpenseCategories = fixedExpenseCategories;

/// Casos de uso del gasto diario.
class DailyExpensesController {
  const DailyExpensesController(this._ref);

  final Ref _ref;

  /// Agrega un gasto del dia. Si [isRecurring] es true se convierte en un
  /// cargo que se repite todos los dias a partir de [spentOn].
  Future<void> add({
    required String userId,
    required String category,
    required String name,
    required double amount,
    required DateTime spentOn,
    bool isRecurring = false,
  }) async {
    _validateAmount(amount);

    await _ref.read(dailyExpensesRepositoryProvider).insert(
      DailyExpense(
        id: newMoneyId(),
        userId: userId,
        category: category,
        name: name.trim(),
        amount: amount,
        spentOn: spentOn,
        isRecurring: isRecurring,
      ),
    );
    _ref.invalidate(dailyExpensesProvider(userId));
  }

  /// Edita un gasto existente (suelto o el monto base de un recurrente).
  Future<void> update({
    required String userId,
    required DailyExpense expense,
    required String category,
    required String name,
    required double amount,
  }) async {
    _validateAmount(amount);

    await _ref
        .read(dailyExpensesRepositoryProvider)
        .update(
          expense.copyWith(
            category: category,
            name: name.trim(),
            amount: amount,
          ),
        );
    _ref.invalidate(dailyExpensesProvider(userId));
  }

  /// Guarda un monto distinto solo para [day] de un cargo recurrente.
  ///
  /// Si ya existia una excepcion para ese dia, la actualiza.
  Future<void> setDayOverride({
    required String userId,
    required DailyExpense template,
    required DateTime day,
    required String category,
    required String name,
    required double amount,
    String? existingOverrideId,
  }) async {
    _validateAmount(amount);

    final repository = _ref.read(dailyExpensesRepositoryProvider);
    if (existingOverrideId != null) {
      await repository.update(
        DailyExpense(
          id: existingOverrideId,
          userId: userId,
          category: category,
          name: name.trim(),
          amount: amount,
          spentOn: day,
          recurringId: template.id,
        ),
      );
    } else {
      await repository.insert(
        DailyExpense(
          id: newMoneyId(),
          userId: userId,
          category: category,
          name: name.trim(),
          amount: amount,
          spentOn: day,
          recurringId: template.id,
        ),
      );
    }
    _ref.invalidate(dailyExpensesProvider(userId));
  }

  Future<void> delete({
    required String userId,
    required String expenseId,
  }) async {
    await _ref.read(dailyExpensesRepositoryProvider).delete(expenseId);
    _ref.invalidate(dailyExpensesProvider(userId));
  }

  /// Agrega una categoria personalizada. Si ya existe (por defecto o del
  /// usuario) no hace nada.
  Future<void> addCategory({
    required String userId,
    required String name,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw const MoneyValidationException('Escribe el nombre de la categoría.');
    }
    await _ref
        .read(dailyExpenseCategoriesRepositoryProvider)
        .insert(userId, clean);
    _ref.invalidate(dailyExpenseCategoriesProvider(userId));
  }

  /// Elimina una categoria personalizada del usuario. No toca las por defecto.
  Future<void> deleteCategory({
    required String userId,
    required String name,
  }) async {
    await _ref
        .read(dailyExpenseCategoriesRepositoryProvider)
        .delete(userId, name);
    _ref.invalidate(dailyExpenseCategoriesProvider(userId));
  }

  void _validateAmount(double amount) {
    if (amount <= 0) {
      throw const MoneyValidationException('Ingresa un monto mayor a cero.');
    }
  }
}

final dailyExpensesControllerProvider = Provider<DailyExpensesController>(
  DailyExpensesController.new,
);
