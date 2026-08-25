import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/money_record.dart';
import '../data/money_providers.dart';
import 'money_error_message.dart';
import 'money_id.dart';

/// Tipos de movimiento que acepta el modulo.
const moneyTypes = ['Ahorro', 'Inversion', 'Meta financiera'];

/// Casos de uso de los movimientos de ahorro e inversion.
class MoneyRecordsController {
  const MoneyRecordsController(this._ref);

  final Ref _ref;

  /// Guarda un movimiento nuevo o actualiza uno existente.
  ///
  /// Si viene [recordId] se actualiza; si no, se crea. Antes esta decision
  /// estaba desperdigada entre `_editingRecordId` y dos ramas de `_save`.
  Future<void> save({
    required String userId,
    required String type,
    required double amount,
    required DateTime date,
    double annualYield = 0,
    String? description,
    String? recordId,
  }) async {
    if (amount <= 0) {
      throw const MoneyValidationException('Ingresa un monto mayor a cero.');
    }
    if (annualYield < 0) {
      throw const MoneyValidationException(
        'El rendimiento no puede ser negativo.',
      );
    }

    final trimmedDescription = description?.trim();
    final record = MoneyRecord(
      id: recordId ?? newMoneyId(),
      userId: userId,
      type: type,
      amount: amount,
      annualYield: annualYield,
      description: (trimmedDescription == null || trimmedDescription.isEmpty)
          ? null
          : trimmedDescription,
      date: date,
    );

    final repository = _ref.read(moneyRecordsRepositoryProvider);
    if (recordId == null) {
      await repository.insert(record);
    } else {
      await repository.update(record);
    }
    _invalidate(userId);
  }

  Future<void> delete({required String userId, required String recordId}) async {
    await _ref.read(moneyRecordsRepositoryProvider).delete(recordId);
    _invalidate(userId);
  }

  /// Refresca la lista. Los totales derivan de ella, asi que se recalculan
  /// solos: ya no hay que acordarse de invalidar tres providers a mano.
  void _invalidate(String userId) =>
      _ref.invalidate(moneyRecordsProvider(userId));
}

final moneyRecordsControllerProvider = Provider<MoneyRecordsController>(
  MoneyRecordsController.new,
);
