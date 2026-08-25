import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/emergency_fund.dart';
import '../data/money_providers.dart';
import '../domain/emergency_fund_rules.dart';
import 'money_error_message.dart';
import 'money_id.dart';

/// Casos de uso del fondo de emergencia y sus subdivisiones.
class EmergencyFundsController {
  const EmergencyFundsController(this._ref);

  final Ref _ref;

  /// Crea un fondo a partir de un movimiento de ahorro o inversion.
  ///
  /// El rendimiento se hereda del movimiento origen: el dinero sigue siendo
  /// el mismo, solo se etiqueta como fondo de emergencia.
  Future<void> createFund({
    required String userId,
    required String name,
    required String sourceRecordId,
    required double amount,
    double annualYield = 0,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const MoneyValidationException('Ponle nombre al fondo.');
    }
    if (sourceRecordId.trim().isEmpty) {
      throw const MoneyValidationException(
        'Selecciona el ahorro o inversion de origen.',
      );
    }
    if (amount <= 0) {
      throw const MoneyValidationException('Ingresa un monto mayor a cero.');
    }

    await _ref.read(emergencyFundsRepositoryProvider).insert(
      EmergencyFund(
        id: newMoneyId(),
        userId: userId,
        name: trimmedName,
        sourceRecordId: sourceRecordId,
        amount: amount,
        annualYield: annualYield,
      ),
    );
    _invalidateFunds(userId);
  }

  Future<void> deleteFund({
    required String userId,
    required String fundId,
  }) async {
    await _ref.read(emergencyFundsRepositoryProvider).delete(fundId);
    _invalidateFunds(userId);
    _ref.invalidate(emergencyFundEntriesProvider(fundId));
  }

  /// Divide parte de un fondo en una subdivision con nombre propio.
  ///
  /// Se releen las subdivisiones actuales antes de validar para no depender
  /// de lo que la UI tenga en pantalla, que puede estar viejo.
  Future<void> splitFund({
    required String userId,
    required EmergencyFund fund,
    required String name,
    required double amount,
    double annualYield = 0,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const MoneyValidationException('Ponle nombre a la division.');
    }

    final repository = _ref.read(emergencyFundsRepositoryProvider);
    final entries = await repository.fetchEntries(fund.id);

    switch (EmergencyFundRules.validateSplit(
      fund: fund,
      entries: entries,
      amount: amount,
    )) {
      case FundSplitValidation.valid:
        break;
      case FundSplitValidation.notPositive:
        throw const MoneyValidationException('Ingresa un monto mayor a cero.');
      case FundSplitValidation.exceedsAvailable:
        final available = EmergencyFundRules.availableToSplit(
          fund: fund,
          entries: entries,
        );
        throw MoneyValidationException(
          'Solo te quedan \$${available.toStringAsFixed(2)} sin clasificar '
          'en este fondo.',
        );
    }

    await repository.insertEntry(
      EmergencyFundEntry(
        id: newMoneyId(),
        emergencyFundId: fund.id,
        name: trimmedName,
        amount: amount,
        annualYield: annualYield,
      ),
    );
    _invalidateFunds(userId);
    _ref.invalidate(emergencyFundEntriesProvider(fund.id));
  }

  Future<void> deleteEntry({
    required String userId,
    required String fundId,
    required String entryId,
  }) async {
    await _ref.read(emergencyFundsRepositoryProvider).deleteEntry(entryId);
    _invalidateFunds(userId);
    _ref.invalidate(emergencyFundEntriesProvider(fundId));
  }

  void _invalidateFunds(String userId) =>
      _ref.invalidate(emergencyFundsProvider(userId));
}

final emergencyFundsControllerProvider = Provider<EmergencyFundsController>(
  EmergencyFundsController.new,
);
