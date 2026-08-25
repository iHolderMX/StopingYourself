import 'package:flutter_test/flutter_test.dart';
import 'package:stoping_yourself/features/money/domain/emergency_fund_rules.dart';
import 'package:stoping_yourself/models/emergency_fund.dart';

EmergencyFund _fund({required double amount, double annualYield = 0}) {
  return EmergencyFund(
    id: 'f',
    userId: 'u',
    name: 'Colchon',
    sourceRecordId: 'r',
    amount: amount,
    annualYield: annualYield,
  );
}

EmergencyFundEntry _entry(double amount) => EmergencyFundEntry(
  id: 'e',
  emergencyFundId: 'f',
  name: 'division',
  amount: amount,
);

void main() {
  group('EmergencyFundRules.classifiedAmount', () {
    test('suma las subdivisiones', () {
      expect(
        EmergencyFundRules.classifiedAmount([_entry(1000), _entry(2500)]),
        closeTo(3500, 0.0001),
      );
    });

    test('sin subdivisiones no hay nada clasificado', () {
      expect(EmergencyFundRules.classifiedAmount(const []), 0);
    });
  });

  group('EmergencyFundRules.availableToSplit', () {
    test('descuenta lo ya clasificado del total del fondo', () {
      expect(
        EmergencyFundRules.availableToSplit(
          fund: _fund(amount: 10000),
          entries: [_entry(3000), _entry(2000)],
        ),
        closeTo(5000, 0.0001),
      );
    });

    test('un fondo sin subdivisiones esta todo disponible', () {
      expect(
        EmergencyFundRules.availableToSplit(
          fund: _fund(amount: 10000),
          entries: const [],
        ),
        closeTo(10000, 0.0001),
      );
    });

    test('nunca reporta disponible negativo con datos inconsistentes', () {
      expect(
        EmergencyFundRules.availableToSplit(
          fund: _fund(amount: 1000),
          entries: [_entry(5000)],
        ),
        0,
      );
    });
  });

  group('EmergencyFundRules.isFullyClassified', () {
    test('un fondo repartido al 100% ya no admite mas', () {
      expect(
        EmergencyFundRules.isFullyClassified(
          fund: _fund(amount: 1000),
          entries: [_entry(1000)],
        ),
        isTrue,
      );
    });

    test('un fondo a medias sigue admitiendo divisiones', () {
      expect(
        EmergencyFundRules.isFullyClassified(
          fund: _fund(amount: 1000),
          entries: [_entry(400)],
        ),
        isFalse,
      );
    });
  });

  group('EmergencyFundRules.validateSplit', () {
    test('acepta un monto dentro de lo disponible', () {
      expect(
        EmergencyFundRules.validateSplit(
          fund: _fund(amount: 1000),
          entries: const [],
          amount: 600,
        ),
        FundSplitValidation.valid,
      );
    });

    test('acepta un monto que agota exactamente lo disponible', () {
      expect(
        EmergencyFundRules.validateSplit(
          fund: _fund(amount: 1000),
          entries: [_entry(400)],
          amount: 600,
        ),
        FundSplitValidation.valid,
      );
    });

    test('rechaza cero y negativos', () {
      expect(
        EmergencyFundRules.validateSplit(
          fund: _fund(amount: 1000),
          entries: const [],
          amount: 0,
        ),
        FundSplitValidation.notPositive,
      );
      expect(
        EmergencyFundRules.validateSplit(
          fund: _fund(amount: 1000),
          entries: const [],
          amount: -10,
        ),
        FundSplitValidation.notPositive,
      );
    });

    test('rechaza un monto que excede lo disponible', () {
      expect(
        EmergencyFundRules.validateSplit(
          fund: _fund(amount: 1000),
          entries: [_entry(800)],
          amount: 300,
        ),
        FundSplitValidation.exceedsAvailable,
      );
    });
  });

  group('EmergencyFundRules.totalAmount', () {
    test('suma los montos de varios fondos', () {
      expect(
        EmergencyFundRules.totalAmount([
          _fund(amount: 1000),
          _fund(amount: 2500),
        ]),
        closeTo(3500, 0.0001),
      );
    });

    test('una lista vacia suma 0', () {
      expect(EmergencyFundRules.totalAmount(const []), 0);
    });
  });
}
