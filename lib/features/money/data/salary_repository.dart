import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/salary_setting.dart';
import 'supabase_guard.dart';

/// Acceso a la configuracion de salario del usuario.
class SalaryRepository {
  const SalaryRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'salary_settings';

  /// `null` cuando el usuario todavia no configuro su salario.
  ///
  /// Ojo: `null` significa "no configurado", no "fallo la consulta". Un fallo
  /// se propaga como excepcion.
  Future<SalarySetting?> fetch(String userId) {
    return guardRead('cargar tu salario', () async {
      final data = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (data == null) return null;
      return SalarySetting.fromJson(data);
    });
  }

  Future<void> upsert(SalarySetting salary) {
    return guardWrite(
      'guardar tu salario',
      () => _client.from(_table).upsert(salary.toJson()),
    );
  }

  Future<void> deleteAllOf(String userId) {
    return guardWrite(
      'borrar tu configuracion de salario',
      () => _client.from(_table).delete().eq('user_id', userId),
    );
  }
}
