import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/debt.dart';
import '../domain/debt_rules.dart';
import 'money_failure.dart';
import 'supabase_guard.dart';

/// Acceso a las deudas y sus pagos.
///
/// Deuda y pagos son un mismo agregado: el saldo de la deuda solo tiene
/// sentido junto a sus pagos, asi que viven en el mismo repositorio para
/// poder mantenerlos consistentes.
class DebtsRepository {
  const DebtsRepository(this._client);

  final SupabaseClient _client;

  static const _debtsTable = 'debts';
  static const _paymentsTable = 'debt_payments';

  Future<List<Debt>> fetchAll(String userId) {
    return guardRead('cargar tus deudas', () async {
      final data = await _client
          .from(_debtsTable)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return data.map(Debt.fromJson).toList();
    });
  }

  Future<Debt?> fetchOne(String debtId) {
    return guardRead('cargar la deuda', () async {
      final data = await _client
          .from(_debtsTable)
          .select()
          .eq('id', debtId)
          .maybeSingle();
      if (data == null) return null;
      return Debt.fromJson(data);
    });
  }

  Future<void> insert(Debt debt) {
    return guardWrite(
      'guardar la deuda',
      () => _client.from(_debtsTable).insert(debt.toJson()),
    );
  }

  Future<void> update(Debt debt) {
    return guardWrite(
      'actualizar la deuda',
      () => _client.from(_debtsTable).update(debt.toJson()).eq('id', debt.id),
    );
  }

  Future<void> delete(String id) {
    return guardWrite('eliminar la deuda', () async {
      // Los pagos primero: si la tabla no tiene ON DELETE CASCADE, borrar la
      // deuda antes reventaria por llave foranea.
      await _client.from(_paymentsTable).delete().eq('debt_id', id);
      await _client.from(_debtsTable).delete().eq('id', id);
    });
  }

  Future<List<DebtPayment>> fetchPayments(String debtId) {
    return guardRead('cargar los pagos de la deuda', () async {
      final data = await _client
          .from(_paymentsTable)
          .select()
          .eq('debt_id', debtId)
          .order('payment_date', ascending: false);
      return data.map(DebtPayment.fromJson).toList();
    });
  }

  /// Registra un pago y actualiza el saldo de la deuda como una sola unidad.
  ///
  /// Supabase no expone transacciones desde el cliente, asi que si el segundo
  /// paso falla se revierte el primero (patron de compensacion). Antes esto
  /// eran dos llamadas sueltas: si la actualizacion del saldo fallaba, el pago
  /// quedaba huerfano y la deuda mostraba un saldo equivocado para siempre.
  ///
  /// TODO(Gus): la solucion definitiva es la funcion `register_debt_payment`
  /// de supabase/migrations/create_register_debt_payment.sql, que hace ambos
  /// pasos en una transaccion real del servidor. Cuando la apliques, esto se
  /// puede cambiar por una sola llamada a `_client.rpc(...)`.
  Future<Debt> registerPayment({
    required Debt debt,
    required DebtPayment payment,
  }) async {
    await guardWrite(
      'registrar el pago',
      () => _client.from(_paymentsTable).insert(payment.toJson()),
    );

    final updated = DebtRules.applyPayment(debt: debt, amount: payment.amount);

    try {
      await update(updated);
      return updated;
    } on MoneyFailure {
      await _compensatePayment(payment.id);
      rethrow;
    }
  }

  /// Deshace un pago cuyo saldo no se pudo actualizar.
  ///
  /// Si la compensacion tambien falla no hay mucho mas que hacer desde el
  /// cliente: se deja pasar para no ocultar el error original, que es el que
  /// de verdad le interesa al usuario.
  Future<void> _compensatePayment(String paymentId) async {
    try {
      await _client.from(_paymentsTable).delete().eq('id', paymentId);
    } catch (_) {
      // Intencional: el error original se propaga en el `rethrow` de arriba.
    }
  }

  Future<void> deletePayment(String id) {
    return guardWrite(
      'eliminar el pago',
      () => _client.from(_paymentsTable).delete().eq('id', id),
    );
  }

  /// Borra las deudas del usuario junto con todos sus pagos.
  ///
  /// Los pagos se filtran por los ids de las deudas del usuario, no por
  /// `user_id`: `debt_payments` no tiene esa columna en el modelo y filtrar
  /// por ella hacia fallar el reinicio completo de finanzas.
  Future<void> deleteAllOf(String userId) {
    return guardWrite('borrar tus deudas', () async {
      final debts = await _client
          .from(_debtsTable)
          .select('id')
          .eq('user_id', userId);

      final debtIds = debts
          .map((row) => row['id'] as String?)
          .whereType<String>()
          .toList();

      if (debtIds.isNotEmpty) {
        await _client.from(_paymentsTable).delete().inFilter('debt_id', debtIds);
      }

      await _client.from(_debtsTable).delete().eq('user_id', userId);
    });
  }
}
