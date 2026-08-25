import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoping_yourself/features/money/application/debts_controller.dart';
import 'package:stoping_yourself/features/money/application/money_error_message.dart';
import 'package:stoping_yourself/features/money/data/money_providers.dart';
import 'package:stoping_yourself/models/debt.dart';

import 'fakes.dart';

Debt _debt({required double total, double paid = 0}) => Debt(
  id: 'debt-1',
  userId: 'user-1',
  name: 'Tarjeta',
  totalAmount: total,
  paidAmount: paid,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  late FakeDebtsRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeDebtsRepository();
    container = ProviderContainer(
      overrides: [debtsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  DebtsController controller() => container.read(debtsControllerProvider);

  group('DebtsController.add', () {
    test('guarda la deuda con nombre recortado y un id generado', () async {
      await controller().add(
        userId: 'user-1',
        name: '  Tarjeta oro  ',
        totalAmount: 15000,
        interestRate: 36.5,
      );

      expect(repository.inserted, hasLength(1));
      final saved = repository.inserted.single;
      expect(saved.name, 'Tarjeta oro');
      expect(saved.userId, 'user-1');
      expect(saved.totalAmount, closeTo(15000, 0.0001));
      expect(saved.interestRate, closeTo(36.5, 0.0001));
      expect(saved.id, isNotEmpty);
    });

    test('genera ids distintos en llamadas consecutivas', () async {
      await controller().add(userId: 'u', name: 'A', totalAmount: 100);
      await controller().add(userId: 'u', name: 'B', totalAmount: 100);

      expect(repository.inserted[0].id, isNot(repository.inserted[1].id));
    });

    test('rechaza nombre vacio', () async {
      await expectLater(
        controller().add(userId: 'u', name: '   ', totalAmount: 100),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(repository.inserted, isEmpty);
    });

    test('rechaza monto no positivo', () async {
      await expectLater(
        controller().add(userId: 'u', name: 'X', totalAmount: 0),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(repository.inserted, isEmpty);
    });
  });

  group('DebtsController.registerPayment', () {
    test('registra un pago valido', () async {
      await controller().registerPayment(
        userId: 'user-1',
        debt: _debt(total: 1000),
        amount: 250,
        note: '  quincena  ',
      );

      expect(repository.registeredPayments, hasLength(1));
      final payment = repository.registeredPayments.single;
      expect(payment.amount, closeTo(250, 0.0001));
      expect(payment.debtId, 'debt-1');
      expect(payment.note, 'quincena');
      expect(payment.id, isNotEmpty);
    });

    test('una nota vacia se guarda como null', () async {
      await controller().registerPayment(
        userId: 'user-1',
        debt: _debt(total: 1000),
        amount: 100,
        note: '   ',
      );

      expect(repository.registeredPayments.single.note, isNull);
    });

    test('rechaza un pago mayor al saldo y dice cuanto queda', () async {
      await expectLater(
        controller().registerPayment(
          userId: 'user-1',
          debt: _debt(total: 1000, paid: 900),
          amount: 200,
          note: null,
        ),
        throwsA(
          isA<MoneyValidationException>().having(
            (e) => e.userMessage,
            'userMessage',
            contains('100.00'),
          ),
        ),
      );
      expect(repository.registeredPayments, isEmpty);
    });

    test('rechaza un pago no positivo', () async {
      await expectLater(
        controller().registerPayment(
          userId: 'user-1',
          debt: _debt(total: 1000),
          amount: 0,
          note: null,
        ),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(repository.registeredPayments, isEmpty);
    });

    test('rechaza pagar una deuda ya liquidada', () async {
      await expectLater(
        controller().registerPayment(
          userId: 'user-1',
          debt: _debt(total: 1000, paid: 1000),
          amount: 50,
          note: null,
        ),
        throwsA(
          isA<MoneyValidationException>().having(
            (e) => e.userMessage,
            'userMessage',
            contains('liquidada'),
          ),
        ),
      );
      expect(repository.registeredPayments, isEmpty);
    });

    test('acepta el pago que liquida exactamente la deuda', () async {
      await controller().registerPayment(
        userId: 'user-1',
        debt: _debt(total: 1000, paid: 400),
        amount: 600,
        note: null,
      );

      expect(repository.registeredPayments, hasLength(1));
    });
  });

  group('DebtsController.delete', () {
    test('borra la deuda indicada', () async {
      await controller().delete(userId: 'user-1', debtId: 'debt-1');
      expect(repository.deleted, ['debt-1']);
    });
  });

  group('DebtsController.deletePayment', () {
    test('borra el pago indicado', () async {
      await controller().deletePayment(
        userId: 'user-1',
        debtId: 'debt-1',
        paymentId: 'pay-9',
      );
      expect(repository.deletedPayments, ['pay-9']);
    });
  });
}
