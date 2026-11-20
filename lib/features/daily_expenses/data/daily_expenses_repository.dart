import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/daily_expense.dart';
import '../../money/data/supabase_guard.dart';

/// Acceso a los gastos diarios del usuario.
class DailyExpensesRepository {
  const DailyExpensesRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'daily_expenses';

  Future<List<DailyExpense>> fetchAll(String userId) {
    return guardRead('cargar tus gastos diarios', () async {
      final data = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('spent_on', ascending: false)
          .order('created_at', ascending: false);
      return data.map(DailyExpense.fromJson).toList();
    });
  }

  Future<void> insert(DailyExpense expense) {
    return guardWrite(
      'guardar el gasto del dia',
      () => _client.from(_table).insert(expense.toJson()),
    );
  }

  Future<void> update(DailyExpense expense) {
    return guardWrite(
      'actualizar el gasto del dia',
      () => _client.from(_table).update(expense.toJson()).eq('id', expense.id),
    );
  }

  Future<void> delete(String id) {
    return guardWrite(
      'eliminar el gasto del dia',
      () => _client.from(_table).delete().eq('id', id),
    );
  }

  Future<void> deleteAllOf(String userId) {
    return guardWrite(
      'borrar tus gastos diarios',
      () => _client.from(_table).delete().eq('user_id', userId),
    );
  }
}
