import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/debt.dart';
import '../data/money_providers.dart';
import '../domain/debt_rules.dart';
import 'money_error_message.dart';
import 'money_id.dart';

/// Casos de uso de deudas.
///
/// Concentra tres cosas que antes vivian dentro de los `AlertDialog`:
/// validar con las reglas de dominio, escribir en el repositorio y refrescar
/// las lecturas afectadas. La UI ya solo llama metodos y muestra errores.
class DebtsController {
  const DebtsController(this._ref);

  final Ref _ref;

  Future<void> add({
    required String userId,
    required String name,
    required double totalAmount,
    double interestRate = 0,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const MoneyValidationException('Ponle nombre a la deuda.');
    }
    if (totalAmount <= 0) {
      throw const MoneyValidationException(
        'El monto de la deuda debe ser mayor a cero.',
      );
    }

    await _ref.read(debtsRepositoryProvider).insert(
      Debt(
        id: newMoneyId(),
        userId: userId,
        name: trimmedName,
        totalAmount: totalAmount,
        interestRate: interestRate,
      ),
    );
    _invalidateDebts(userId);
  }

  /// Registra un pago y deja el saldo de la deuda actualizado.
  Future<void> registerPayment({
    required String userId,
    required Debt debt,
    required double amount,
    String? note,
  }) async {
    switch (DebtRules.validatePayment(debt: debt, amount: amount)) {
      case DebtPaymentValidation.valid:
        break;
      case DebtPaymentValidation.notPositive:
        throw const MoneyValidationException(
          'El monto del pago debe ser mayor a cero.',
        );
      case DebtPaymentValidation.exceedsRemaining:
        throw MoneyValidationException(
          'El pago no puede exceder lo restante '
          '(\$${debt.remainingAmount.toStringAsFixed(2)}).',
        );
      case DebtPaymentValidation.alreadySettled:
        throw const MoneyValidationException('Esa deuda ya esta liquidada.');
    }

    final trimmedNote = note?.trim();
    await _ref.read(debtsRepositoryProvider).registerPayment(
      debt: debt,
      payment: DebtPayment(
        id: newMoneyId(),
        debtId: debt.id,
        amount: amount,
        note: (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote,
      ),
    );

    _invalidateDebts(userId);
    _ref.invalidate(debtPaymentsProvider(debt.id));
  }

  Future<void> delete({required String userId, required String debtId}) async {
    await _ref.read(debtsRepositoryProvider).delete(debtId);
    _invalidateDebts(userId);
    _ref.invalidate(debtPaymentsProvider(debtId));
  }

  Future<void> deletePayment({
    required String userId,
    required String debtId,
    required String paymentId,
  }) async {
    await _ref.read(debtsRepositoryProvider).deletePayment(paymentId);
    _invalidateDebts(userId);
    _ref.invalidate(debtPaymentsProvider(debtId));
  }

  void _invalidateDebts(String userId) =>
      _ref.invalidate(debtsProvider(userId));
}

final debtsControllerProvider = Provider<DebtsController>(
  DebtsController.new,
);
