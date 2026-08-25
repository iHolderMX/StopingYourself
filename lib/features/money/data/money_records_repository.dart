import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/money_record.dart';
import 'supabase_guard.dart';

/// Acceso a los movimientos de ahorro e inversion.
///
/// No expone totales: se derivan de la lista con `YieldRules` para evitar
/// una segunda consulta que pueda quedar desincronizada con los registros.
class MoneyRecordsRepository {
  const MoneyRecordsRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'money_records';

  Future<List<MoneyRecord>> fetchAll(String userId) {
    return guardRead('cargar tus movimientos', () async {
      final data = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);
      return data.map(MoneyRecord.fromJson).toList();
    });
  }

  Future<void> insert(MoneyRecord record) {
    return guardWrite(
      'guardar el movimiento',
      () => _client.from(_table).insert(record.toJson()),
    );
  }

  Future<void> update(MoneyRecord record) {
    return guardWrite(
      'actualizar el movimiento',
      () => _client.from(_table).update(record.toJson()).eq('id', record.id),
    );
  }

  Future<void> delete(String id) {
    return guardWrite(
      'eliminar el movimiento',
      () => _client.from(_table).delete().eq('id', id),
    );
  }

  Future<void> deleteAllOf(String userId) {
    return guardWrite(
      'borrar tus movimientos',
      () => _client.from(_table).delete().eq('user_id', userId),
    );
  }
}
