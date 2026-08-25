import 'package:supabase_flutter/supabase_flutter.dart';

import 'debts_repository.dart';
import 'emergency_funds_repository.dart';
import 'fixed_expenses_repository.dart';
import '../domain/saving_goal_rules.dart';
import 'money_failure.dart';
import 'money_records_repository.dart';
import 'quincena_repository.dart';
import 'salary_repository.dart';
import 'saving_goal_images_repository.dart';
import 'saving_goals_repository.dart';

/// Borra todas las finanzas de un usuario.
///
/// Vive aparte porque cruza todos los agregados: es la unica operacion que
/// necesita conocerlos a todos, y meterla en cualquiera de ellos lo acoplaria
/// con los demas.
class FinanceResetRepository {
  const FinanceResetRepository({
    required SupabaseClient client,
    required MoneyRecordsRepository moneyRecords,
    required FixedExpensesRepository fixedExpenses,
    required DebtsRepository debts,
    required SavingGoalsRepository savingGoals,
    required SavingGoalImagesRepository savingGoalImages,
    required EmergencyFundsRepository emergencyFunds,
    required QuincenaRepository quincena,
    required SalaryRepository salary,
  }) : _client = client,
       _moneyRecords = moneyRecords,
       _fixedExpenses = fixedExpenses,
       _debts = debts,
       _savingGoals = savingGoals,
       _savingGoalImages = savingGoalImages,
       _emergencyFunds = emergencyFunds,
       _quincena = quincena,
       _salary = salary;

  final SupabaseClient _client;
  final MoneyRecordsRepository _moneyRecords;
  final FixedExpensesRepository _fixedExpenses;
  final DebtsRepository _debts;
  final SavingGoalsRepository _savingGoals;
  final SavingGoalImagesRepository _savingGoalImages;
  final EmergencyFundsRepository _emergencyFunds;
  final QuincenaRepository _quincena;
  final SalaryRepository _salary;

  /// Reinicia todas las finanzas del usuario.
  ///
  /// Supabase no da transacciones desde el cliente, asi que no se puede
  /// garantizar todo-o-nada. En vez de abortar al primer error se intentan
  /// todos los borrados y se reportan juntos los que fallaron: los deletes son
  /// idempotentes, asi que reintentar es seguro y el usuario queda mas cerca
  /// del estado que pidio.
  Future<void> resetAll(String userId) async {
    final failures = <MoneyFailure>[];

    Future<void> attempt(Future<void> Function() step) async {
      try {
        await step();
      } on MoneyFailure catch (failure) {
        failures.add(failure);
      }
    }

    await attempt(() => _moneyRecords.deleteAllOf(userId));
    await attempt(() => _fixedExpenses.deleteAllOf(userId));
    await attempt(() => _debts.deleteAllOf(userId));
    await attempt(() => _deleteAllSavingGoals(userId));
    await attempt(() => _emergencyFunds.deleteAllOf(userId));
    await attempt(() => _deleteAllMonthlyPayments(userId));
    await attempt(() => _quincena.deleteAllOf(userId));
    await attempt(() => _salary.deleteAllOf(userId));

    if (failures.isEmpty) return;

    throw MoneyWriteFailure(
      operation: 'reiniciar todas tus finanzas',
      cause: _FinanceResetErrors(failures),
    );
  }

  /// Borra las metas del usuario y las imagenes que tuvieran en Storage.
  ///
  /// Las rutas se leen antes de borrar los registros, porque despues ya no
  /// hay forma de saber que archivos limpiar y quedarian ocupando el bucket.
  Future<void> _deleteAllSavingGoals(String userId) async {
    final goals = await _savingGoals.fetchAll(userId);
    await _savingGoals.deleteAllOf(userId);
    await _savingGoalImages.deleteMany(SavingGoalRules.imagePathsOf(goals));
  }

  /// Los pagos mensuales no tienen repositorio propio porque hoy ninguna
  /// pantalla los usa, pero el reinicio si tiene que limpiarlos.
  Future<void> _deleteAllMonthlyPayments(String userId) async {
    try {
      await _client.from('monthly_payments').delete().eq('user_id', userId);
    } catch (error, stackTrace) {
      throw MoneyWriteFailure(
        operation: 'borrar tus pagos mensuales',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Agrupa varios fallos de borrado en una sola causa legible.
class _FinanceResetErrors {
  const _FinanceResetErrors(this.failures);

  final List<MoneyFailure> failures;

  @override
  String toString() {
    final pending = failures.map((f) => f.operation).join(', ');
    return 'quedaron pendientes: $pending';
  }
}
