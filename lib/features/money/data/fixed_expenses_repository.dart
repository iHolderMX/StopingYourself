import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/fixed_expense.dart';
import 'supabase_guard.dart';

/// Acceso a los gastos fijos mensuales.
class FixedExpensesRepository {
  const FixedExpensesRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'fixed_expenses';

  Future<List<FixedExpense>> fetchAll(String userId) {
    return guardRead('cargar tus gastos fijos', () async {
      final data = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return data.map(FixedExpense.fromJson).toList();
    });
  }

  Future<void> insert(FixedExpense expense) {
    return guardWrite(
      'guardar el gasto fijo',
      () => _client.from(_table).insert(expense.toJson()),
    );
  }

  Future<void> delete(String id) {
    return guardWrite(
      'eliminar el gasto fijo',
      () => _client.from(_table).delete().eq('id', id),
    );
  }

  Future<void> deleteAllOf(String userId) {
    return guardWrite(
      'borrar tus gastos fijos',
      () => _client.from(_table).delete().eq('user_id', userId),
    );
  }
}
