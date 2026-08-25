import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/quincena_expense.dart';
import 'supabase_guard.dart';

/// Acceso a los gastos planeados de la proxima quincena.
class QuincenaRepository {
  const QuincenaRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'quincena_expenses';

  Future<List<QuincenaExpense>> fetchAll(String userId) {
    return guardRead('cargar los gastos de tu quincena', () async {
      final data = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return data.map(QuincenaExpense.fromJson).toList();
    });
  }

  Future<void> insert(QuincenaExpense expense) {
    return guardWrite(
      'agregar el gasto a tu quincena',
      () => _client.from(_table).insert(expense.toJson()),
    );
  }

  Future<void> delete(String id) {
    return guardWrite(
      'eliminar el gasto de tu quincena',
      () => _client.from(_table).delete().eq('id', id),
    );
  }

  Future<void> deleteAllOf(String userId) {
    return guardWrite(
      'reiniciar los gastos de tu quincena',
      () => _client.from(_table).delete().eq('user_id', userId),
    );
  }
}
