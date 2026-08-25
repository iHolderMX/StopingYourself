import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoping_yourself/features/money/application/emergency_funds_controller.dart';
import 'package:stoping_yourself/features/money/application/money_error_message.dart';
import 'package:stoping_yourself/features/money/data/money_providers.dart';
import 'package:stoping_yourself/models/emergency_fund.dart';

import 'fakes.dart';

EmergencyFund _fund({required double amount, double annualYield = 0}) =>
    EmergencyFund(
      id: 'fund-1',
      userId: 'user-1',
      name: 'Colchon',
      sourceRecordId: 'rec-1',
      amount: amount,
      annualYield: annualYield,
    );

EmergencyFundEntry _entry(double amount) => EmergencyFundEntry(
  id: 'entry',
  emergencyFundId: 'fund-1',
  name: 'algo',
  amount: amount,
);

void main() {
  late FakeEmergencyFundsRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeEmergencyFundsRepository();
    container = ProviderContainer(
      overrides: [
        emergencyFundsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  EmergencyFundsController controller() =>
      container.read(emergencyFundsControllerProvider);

  group('EmergencyFundsController.createFund', () {
    test('crea el fondo heredando el rendimiento del origen', () async {
      await controller().createFund(
        userId: 'user-1',
        name: '  Colchon  ',
        sourceRecordId: 'rec-1',
        amount: 25000,
        annualYield: 11.5,
      );

      expect(repository.inserted, hasLength(1));
      final fund = repository.inserted.single;
      expect(fund.name, 'Colchon');
      expect(fund.sourceRecordId, 'rec-1');
      expect(fund.amount, closeTo(25000, 0.0001));
      expect(fund.annualYield, closeTo(11.5, 0.0001));
      expect(fund.id, isNotEmpty);
    });

    test('rechaza nombre vacio', () async {
      await expectLater(
        controller().createFund(
          userId: 'u',
          name: '  ',
          sourceRecordId: 'rec-1',
          amount: 100,
        ),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(repository.inserted, isEmpty);
    });

    test('rechaza fondo sin movimiento de origen', () async {
      await expectLater(
        controller().createFund(
          userId: 'u',
          name: 'Colchon',
          sourceRecordId: '   ',
          amount: 100,
        ),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(repository.inserted, isEmpty);
    });

    test('rechaza monto no positivo', () async {
      await expectLater(
        controller().createFund(
          userId: 'u',
          name: 'Colchon',
          sourceRecordId: 'rec-1',
          amount: 0,
        ),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(repository.inserted, isEmpty);
    });
  });

  group('EmergencyFundsController.splitFund', () {
    test('guarda la division cuando cabe en lo disponible', () async {
      repository.entries = [_entry(400)];

      await controller().splitFund(
        userId: 'user-1',
        fund: _fund(amount: 1000),
        name: '  Salud  ',
        amount: 600,
        annualYield: 9,
      );

      expect(repository.insertedEntries, hasLength(1));
      final entry = repository.insertedEntries.single;
      expect(entry.name, 'Salud');
      expect(entry.emergencyFundId, 'fund-1');
      expect(entry.amount, closeTo(600, 0.0001));
      expect(entry.annualYield, closeTo(9, 0.0001));
    });

    test('rechaza pasarse de lo disponible y dice cuanto queda', () async {
      repository.entries = [_entry(800)];

      await expectLater(
        controller().splitFund(
          userId: 'user-1',
          fund: _fund(amount: 1000),
          name: 'Salud',
          amount: 300,
        ),
        throwsA(
          isA<MoneyValidationException>().having(
            (e) => e.userMessage,
            'userMessage',
            contains('200.00'),
          ),
        ),
      );
      expect(repository.insertedEntries, isEmpty);
    });

    test('valida contra las divisiones frescas, no contra las de pantalla',
        () async {
      // La UI podria creer que el fondo esta vacio; el controller relee.
      repository.entries = [_entry(1000)];

      await expectLater(
        controller().splitFund(
          userId: 'user-1',
          fund: _fund(amount: 1000),
          name: 'Salud',
          amount: 1,
        ),
        throwsA(isA<MoneyValidationException>()),
      );
    });

    test('rechaza nombre vacio antes de consultar el repositorio', () async {
      await expectLater(
        controller().splitFund(
          userId: 'user-1',
          fund: _fund(amount: 1000),
          name: '   ',
          amount: 100,
        ),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(repository.insertedEntries, isEmpty);
    });

    test('rechaza monto no positivo', () async {
      await expectLater(
        controller().splitFund(
          userId: 'user-1',
          fund: _fund(amount: 1000),
          name: 'Salud',
          amount: 0,
        ),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(repository.insertedEntries, isEmpty);
    });
  });

  group('EmergencyFundsController borrado', () {
    test('borra el fondo indicado', () async {
      await controller().deleteFund(userId: 'user-1', fundId: 'fund-1');
      expect(repository.deleted, ['fund-1']);
    });

    test('borra la division indicada', () async {
      await controller().deleteEntry(
        userId: 'user-1',
        fundId: 'fund-1',
        entryId: 'entry-3',
      );
      expect(repository.deletedEntries, ['entry-3']);
    });
  });
}
