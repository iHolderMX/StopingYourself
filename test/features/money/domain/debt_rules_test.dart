import 'package:flutter_test/flutter_test.dart';
import 'package:stoping_yourself/features/money/domain/debt_rules.dart';
import 'package:stoping_yourself/models/debt.dart';

Debt _debt({required double total, double paid = 0, double interest = 0}) {
  return Debt(
    id: 'd',
    userId: 'u',
    name: 'Tarjeta',
    totalAmount: total,
    paidAmount: paid,
    interestRate: interest,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('DebtRules.minimumPayment', () {
    test('sugiere el 6% del total', () {
      expect(
        DebtRules.minimumPayment(_debt(total: 10000)),
        closeTo(600, 0.0001),
      );
    });

    test('se acota al saldo cuando el 6% ya es mas de lo que falta', () {
      // 6% de 10,000 = 600, pero solo faltan 100.
      expect(
        DebtRules.minimumPayment(_debt(total: 10000, paid: 9900)),
        closeTo(100, 0.0001),
      );
    });

    test('una deuda liquidada no tiene minimo', () {
      expect(DebtRules.minimumPayment(_debt(total: 5000, paid: 5000)), 0);
    });

    test('no revienta cuando se pago de mas', () {
      // Antes esto hacia clamp(0.0, negativo) y lanzaba ArgumentError.
      expect(
        () => DebtRules.minimumPayment(_debt(total: 5000, paid: 6000)),
        returnsNormally,
      );
      expect(DebtRules.minimumPayment(_debt(total: 5000, paid: 6000)), 0);
    });
  });

  group('DebtRules.validatePayment', () {
    test('acepta un pago dentro del saldo', () {
      expect(
        DebtRules.validatePayment(debt: _debt(total: 1000), amount: 500),
        DebtPaymentValidation.valid,
      );
    });

    test('acepta un pago que liquida exactamente la deuda', () {
      expect(
        DebtRules.validatePayment(debt: _debt(total: 1000), amount: 1000),
        DebtPaymentValidation.valid,
      );
    });

    test('rechaza cero y negativos', () {
      expect(
        DebtRules.validatePayment(debt: _debt(total: 1000), amount: 0),
        DebtPaymentValidation.notPositive,
      );
      expect(
        DebtRules.validatePayment(debt: _debt(total: 1000), amount: -50),
        DebtPaymentValidation.notPositive,
      );
    });

    test('rechaza un pago mayor al saldo', () {
      expect(
        DebtRules.validatePayment(
          debt: _debt(total: 1000, paid: 900),
          amount: 200,
        ),
        DebtPaymentValidation.exceedsRemaining,
      );
    });

    test('rechaza cualquier pago si ya esta liquidada', () {
      expect(
        DebtRules.validatePayment(
          debt: _debt(total: 1000, paid: 1000),
          amount: 1,
        ),
        DebtPaymentValidation.alreadySettled,
      );
    });
  });

  group('DebtRules.applyPayment', () {
    test('suma el pago al monto pagado y conserva el resto de campos', () {
      final debt = _debt(total: 1000, paid: 200, interest: 36.5);
      final updated = DebtRules.applyPayment(debt: debt, amount: 300);

      expect(updated.paidAmount, closeTo(500, 0.0001));
      expect(updated.remainingAmount, closeTo(500, 0.0001));
      expect(updated.id, debt.id);
      expect(updated.userId, debt.userId);
      expect(updated.name, debt.name);
      expect(updated.totalAmount, debt.totalAmount);
      expect(updated.interestRate, debt.interestRate);
      expect(updated.createdAt, debt.createdAt);
    });

    test('no muta la deuda original', () {
      final debt = _debt(total: 1000, paid: 200);
      DebtRules.applyPayment(debt: debt, amount: 300);
      expect(debt.paidAmount, closeTo(200, 0.0001));
    });

    test('un pago que liquida la deja marcada como liquidada', () {
      final debt = _debt(total: 1000, paid: 700);
      final updated = DebtRules.applyPayment(debt: debt, amount: 300);
      expect(DebtRules.isSettled(updated), isTrue);
    });
  });

  group('DebtRules.progressRatio', () {
    test('refleja el avance normal', () {
      expect(
        DebtRules.progressRatio(_debt(total: 1000, paid: 250)),
        closeTo(0.25, 0.0001),
      );
    });

    test('se recorta a 1 cuando se pago de mas', () {
      expect(DebtRules.progressRatio(_debt(total: 1000, paid: 1500)), 1.0);
    });

    test('es 0 cuando el total es 0 y no NaN', () {
      expect(DebtRules.progressRatio(_debt(total: 0)), 0.0);
    });
  });

  group('DebtRules totales', () {
    test('suma totales, pagado y saldo de varias deudas', () {
      final debts = [
        _debt(total: 1000, paid: 400),
        _debt(total: 2500, paid: 500),
      ];
      expect(DebtRules.totalAmount(debts), closeTo(3500, 0.0001));
      expect(DebtRules.totalPaid(debts), closeTo(900, 0.0001));
      expect(DebtRules.totalRemaining(debts), closeTo(2600, 0.0001));
    });

    test('una lista vacia suma 0', () {
      expect(DebtRules.totalAmount(const []), 0);
      expect(DebtRules.totalPaid(const []), 0);
      expect(DebtRules.totalRemaining(const []), 0);
      expect(DebtRules.totalOfPayments(const []), 0);
    });

    test('suma una lista de pagos', () {
      final payments = [
        DebtPayment(id: 'p1', debtId: 'd', amount: 100),
        DebtPayment(id: 'p2', debtId: 'd', amount: 250.5),
      ];
      expect(DebtRules.totalOfPayments(payments), closeTo(350.5, 0.0001));
    });
  });
}
