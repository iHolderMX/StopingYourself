import 'package:supabase_flutter/supabase_flutter.dart';

import '../../money/data/supabase_guard.dart';

/// Categorias personalizadas del gasto diario (ademas de las por defecto).
class DailyExpenseCategoriesRepository {
  const DailyExpenseCategoriesRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'daily_expense_categories';

  /// Devuelve los nombres de las categorias del usuario, ordenadas.
  Future<List<String>> fetchAll(String userId) {
    return guardRead('cargar tus categorias', () async {
      final rows = await _client
          .from(_table)
          .select('name')
          .eq('user_id', userId)
          .order('sort_order')
          .order('name');
      return (rows as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['name'] as String)
          .toList();
    });
  }

  Future<void> insert(String userId, String name) {
    return guardWrite(
      'guardar la categoria',
      () => _client.from(_table).insert({
        'user_id': userId,
        'name': name,
        'sort_order': 0,
      }),
    );
  }

  Future<void> delete(String userId, String name) {
    return guardWrite(
      'eliminar la categoria',
      () =>
          _client.from(_table).delete().eq('user_id', userId).eq('name', name),
    );
  }
}
