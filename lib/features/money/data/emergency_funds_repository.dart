import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/emergency_fund.dart';
import 'supabase_guard.dart';

/// Acceso a los fondos de emergencia y sus subdivisiones.
///
/// Fondo y subdivisiones son un mismo agregado: una subdivision no existe
/// sin su fondo.
class EmergencyFundsRepository {
  const EmergencyFundsRepository(this._client);

  final SupabaseClient _client;

  static const _fundsTable = 'emergency_funds';
  static const _entriesTable = 'emergency_fund_entries';

  Future<List<EmergencyFund>> fetchAll(String userId) {
    return guardRead('cargar tus fondos de emergencia', () async {
      final data = await _client
          .from(_fundsTable)
          .select()
          .eq('user_id', userId)
          .order('created_at');
      return data.map(EmergencyFund.fromJson).toList();
    });
  }

  Future<void> insert(EmergencyFund fund) {
    return guardWrite(
      'crear el fondo',
      () => _client.from(_fundsTable).insert(fund.toJson()),
    );
  }

  Future<void> update(EmergencyFund fund) {
    return guardWrite(
      'actualizar el fondo',
      () => _client.from(_fundsTable).update(fund.toJson()).eq('id', fund.id),
    );
  }

  Future<void> delete(String id) {
    return guardWrite('eliminar el fondo', () async {
      // Las subdivisiones primero, por si la llave foranea no borra en cascada.
      await _client.from(_entriesTable).delete().eq('emergency_fund_id', id);
      await _client.from(_fundsTable).delete().eq('id', id);
    });
  }

  Future<List<EmergencyFundEntry>> fetchEntries(String fundId) {
    return guardRead('cargar las divisiones del fondo', () async {
      final data = await _client
          .from(_entriesTable)
          .select()
          .eq('emergency_fund_id', fundId)
          .order('created_at');
      return data.map(EmergencyFundEntry.fromJson).toList();
    });
  }

  Future<void> insertEntry(EmergencyFundEntry entry) {
    return guardWrite(
      'guardar la division del fondo',
      () => _client.from(_entriesTable).insert(entry.toJson()),
    );
  }

  Future<void> updateEntry(EmergencyFundEntry entry) {
    return guardWrite(
      'actualizar la division del fondo',
      () =>
          _client.from(_entriesTable).update(entry.toJson()).eq('id', entry.id),
    );
  }

  Future<void> deleteEntry(String id) {
    return guardWrite(
      'eliminar la division del fondo',
      () => _client.from(_entriesTable).delete().eq('id', id),
    );
  }

  Future<void> deleteAllEntriesOf(String fundId) {
    return guardWrite(
      'borrar las divisiones del fondo',
      () =>
          _client.from(_entriesTable).delete().eq('emergency_fund_id', fundId),
    );
  }

  /// Borra los fondos del usuario junto con todas sus subdivisiones.
  Future<void> deleteAllOf(String userId) {
    return guardWrite('borrar tus fondos de emergencia', () async {
      final funds = await _client
          .from(_fundsTable)
          .select('id')
          .eq('user_id', userId);

      final fundIds = funds
          .map((row) => row['id'] as String?)
          .whereType<String>()
          .toList();

      if (fundIds.isNotEmpty) {
        await _client
            .from(_entriesTable)
            .delete()
            .inFilter('emergency_fund_id', fundIds);
      }

      await _client.from(_fundsTable).delete().eq('user_id', userId);
    });
  }
}
