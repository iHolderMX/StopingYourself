import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';
import '../../../models/daily_expense.dart';
import 'daily_expense_categories_repository.dart';
import 'daily_expenses_repository.dart';

final dailyExpensesRepositoryProvider = Provider<DailyExpensesRepository>(
  (ref) => DailyExpensesRepository(ref.watch(supabaseClientProvider)),
);

final dailyExpenseCategoriesRepositoryProvider =
    Provider<DailyExpenseCategoriesRepository>(
  (ref) => DailyExpenseCategoriesRepository(
    ref.watch(supabaseClientProvider),
  ),
);

/// Todos los gastos diarios del usuario.
///
/// Se traen completos y la pantalla filtra por dia: el volumen es bajo y
/// asi el resumen y el listado del dia salen de la misma lista ya cargada,
/// en lugar de pedirle al servidor una suma aparte que podria desincronizarse.
final dailyExpensesProvider = FutureProvider.family<List<DailyExpense>, String>(
  (ref, userId) => ref.watch(dailyExpensesRepositoryProvider).fetchAll(userId),
);

/// Categorias personalizadas del usuario (ademas de las por defecto).
final dailyExpenseCategoriesProvider =
    FutureProvider.family<List<String>, String>(
  (ref, userId) =>
      ref.watch(dailyExpenseCategoriesRepositoryProvider).fetchAll(userId),
);

