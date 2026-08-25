import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/saving_goal.dart';
import 'supabase_guard.dart';

/// Acceso a las metas de ahorro.
class SavingGoalsRepository {
  const SavingGoalsRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'saving_goals';

  Future<List<SavingGoal>> fetchAll(String userId) {
    return guardRead('cargar tus metas de ahorro', () async {
      final data = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return data.map(SavingGoal.fromJson).toList();
    });
  }

  Future<void> insert(SavingGoal goal) {
    return guardWrite(
      'guardar la meta',
      () => _client.from(_table).insert(goal.toJson()),
    );
  }

  Future<void> update(SavingGoal goal) {
    return guardWrite(
      'actualizar la meta',
      () => _client.from(_table).update(goal.toJson()).eq('id', goal.id),
    );
  }

  Future<void> delete(String id) {
    return guardWrite(
      'eliminar la meta',
      () => _client.from(_table).delete().eq('id', id),
    );
  }

  Future<void> deleteAllOf(String userId) {
    return guardWrite(
      'borrar tus metas de ahorro',
      () => _client.from(_table).delete().eq('user_id', userId),
    );
  }
}
