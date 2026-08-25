import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../models/debt.dart';
import '../../../models/emergency_fund.dart';
import '../../../models/fixed_expense.dart';
import '../../../models/money_record.dart';
import '../../../models/quincena_expense.dart';
import '../../../models/salary_setting.dart';
import '../../../models/saving_goal.dart';
import '../domain/salary_rules.dart';
import '../domain/yield_rules.dart';
import 'debts_repository.dart';
import 'emergency_funds_repository.dart';
import 'finance_reset_repository.dart';
import 'fixed_expenses_repository.dart';
import 'money_records_repository.dart';
import 'quincena_repository.dart';
import 'salary_repository.dart';
import 'saving_goal_images_repository.dart';
import 'saving_goals_repository.dart';

// ═══════════════════════════════════════════════════════════════
// Repositorios
// ═══════════════════════════════════════════════════════════════

final moneyRecordsRepositoryProvider = Provider<MoneyRecordsRepository>(
  (ref) => MoneyRecordsRepository(ref.watch(supabaseClientProvider)),
);

final fixedExpensesRepositoryProvider = Provider<FixedExpensesRepository>(
  (ref) => FixedExpensesRepository(ref.watch(supabaseClientProvider)),
);

final salaryRepositoryProvider = Provider<SalaryRepository>(
  (ref) => SalaryRepository(ref.watch(supabaseClientProvider)),
);

final debtsRepositoryProvider = Provider<DebtsRepository>(
  (ref) => DebtsRepository(ref.watch(supabaseClientProvider)),
);

final savingGoalsRepositoryProvider = Provider<SavingGoalsRepository>(
  (ref) => SavingGoalsRepository(ref.watch(supabaseClientProvider)),
);

final savingGoalImagesRepositoryProvider =
    Provider<SavingGoalImagesRepository>(
      (ref) => SavingGoalImagesRepository(ref.watch(supabaseClientProvider)),
    );

final emergencyFundsRepositoryProvider = Provider<EmergencyFundsRepository>(
  (ref) => EmergencyFundsRepository(ref.watch(supabaseClientProvider)),
);

final quincenaRepositoryProvider = Provider<QuincenaRepository>(
  (ref) => QuincenaRepository(ref.watch(supabaseClientProvider)),
);

final financeResetRepositoryProvider = Provider<FinanceResetRepository>(
  (ref) => FinanceResetRepository(
    client: ref.watch(supabaseClientProvider),
    moneyRecords: ref.watch(moneyRecordsRepositoryProvider),
    fixedExpenses: ref.watch(fixedExpensesRepositoryProvider),
    debts: ref.watch(debtsRepositoryProvider),
    savingGoals: ref.watch(savingGoalsRepositoryProvider),
    savingGoalImages: ref.watch(savingGoalImagesRepositoryProvider),
    emergencyFunds: ref.watch(emergencyFundsRepositoryProvider),
    quincena: ref.watch(quincenaRepositoryProvider),
    salary: ref.watch(salaryRepositoryProvider),
  ),
);

// ═══════════════════════════════════════════════════════════════
// Sesion
// ═══════════════════════════════════════════════════════════════

/// Sesion actual de Supabase, que se reemite en cada cambio de auth.
///
/// Sin esto el id del usuario se calculaba una sola vez y se quedaba
/// cacheado: al cerrar sesion y entrar con otra cuenta, la app seguia
/// escribiendo con el id anterior y la base lo rechazaba por RLS.
final authSessionProvider = StreamProvider<Session?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((event) => event.session);
});

/// Id del usuario en sesion, o `null` si no hay sesion.
///
/// Centraliza el `auth.currentUser` que antes cada widget leia por su cuenta.
/// Se apoya en [authSessionProvider] para reaccionar a login y logout, y cae
/// a `currentUser` mientras el stream no ha emitido su primer evento.
final currentUserIdProvider = Provider<String?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final streamed = ref.watch(authSessionProvider).asData?.value?.user.id;
  return streamed ?? client.auth.currentUser?.id;
});

// ═══════════════════════════════════════════════════════════════
// Lecturas
// ═══════════════════════════════════════════════════════════════
// Viven aqui, no dentro de los widgets: antes cada pantalla declaraba sus
// providers y las demas la importaban con alias solo para robarselos, lo que
// acoplaba widgets hermanos entre si.

final moneyRecordsProvider = FutureProvider.family<List<MoneyRecord>, String>(
  (ref, userId) => ref.watch(moneyRecordsRepositoryProvider).fetchAll(userId),
);

final fixedExpensesProvider = FutureProvider.family<List<FixedExpense>, String>(
  (ref, userId) => ref.watch(fixedExpensesRepositoryProvider).fetchAll(userId),
);

final salarySettingProvider = FutureProvider.family<SalarySetting?, String>(
  (ref, userId) => ref.watch(salaryRepositoryProvider).fetch(userId),
);

final debtsProvider = FutureProvider.family<List<Debt>, String>(
  (ref, userId) => ref.watch(debtsRepositoryProvider).fetchAll(userId),
);

final debtPaymentsProvider = FutureProvider.family<List<DebtPayment>, String>(
  (ref, debtId) => ref.watch(debtsRepositoryProvider).fetchPayments(debtId),
);

final savingGoalsProvider = FutureProvider.family<List<SavingGoal>, String>(
  (ref, userId) => ref.watch(savingGoalsRepositoryProvider).fetchAll(userId),
);

final emergencyFundsProvider =
    FutureProvider.family<List<EmergencyFund>, String>(
      (ref, userId) =>
          ref.watch(emergencyFundsRepositoryProvider).fetchAll(userId),
    );

final emergencyFundEntriesProvider =
    FutureProvider.family<List<EmergencyFundEntry>, String>(
      (ref, fundId) =>
          ref.watch(emergencyFundsRepositoryProvider).fetchEntries(fundId),
    );

final quincenaExpensesProvider =
    FutureProvider.family<List<QuincenaExpense>, String>(
      (ref, userId) => ref.watch(quincenaRepositoryProvider).fetchAll(userId),
    );

/// URL temporal para mostrar la imagen de una meta, a partir de su ruta.
///
/// El bucket es privado, asi que la URL se firma y caduca. Al ser un provider
/// queda cacheada mientras la pantalla siga viva, en lugar de pedir una URL
/// nueva en cada rebuild.
final savingGoalImageUrlProvider = FutureProvider.family<String, String>(
  (ref, imagePath) =>
      ref.watch(savingGoalImagesRepositoryProvider).createSignedUrl(imagePath),
);

// ═══════════════════════════════════════════════════════════════
// Derivados
// ═══════════════════════════════════════════════════════════════
// Se calculan desde las listas ya cargadas en lugar de pedirle al servidor
// una suma aparte. Antes eran consultas independientes que podian quedar
// desincronizadas con la lista que la UI mostraba al mismo tiempo.

final totalSavedProvider = Provider.family<AsyncValue<double>, String>(
  (ref, userId) => ref
      .watch(moneyRecordsProvider(userId))
      .whenData(YieldRules.totalAmountOfRecords),
);

final totalDailyEarningsProvider = Provider.family<AsyncValue<double>, String>(
  (ref, userId) => ref
      .watch(moneyRecordsProvider(userId))
      .whenData(YieldRules.totalDailyEarningsOfRecords),
);

final totalFixedExpensesProvider = Provider.family<AsyncValue<double>, String>(
  (ref, userId) => ref
      .watch(fixedExpensesProvider(userId))
      .whenData(SalaryRules.totalFixedExpenses),
);

/// Salario mensual configurado, o 0 si no hay.
final monthlySalaryProvider = Provider.family<AsyncValue<double>, String>(
  (ref, userId) => ref
      .watch(salarySettingProvider(userId))
      .whenData((setting) => setting?.monthlySalary ?? 0),
);
