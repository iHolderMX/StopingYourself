import 'package:flutter_test/flutter_test.dart';
import 'package:stoping_yourself/features/money/domain/yield_rules.dart';
import 'package:stoping_yourself/models/emergency_fund.dart';
import 'package:stoping_yourself/models/money_record.dart';

MoneyRecord _record({required double amount, double annualYield = 0}) {
  return MoneyRecord(
    id: 'r',
    userId: 'u',
    type: 'Ahorro',
    amount: amount,
    annualYield: annualYield,
    date: DateTime(2026, 1, 1),
  );
}

void main() {
  group('YieldRules.dailyEarnings', () {
    test('reparte el rendimiento anual entre 365 dias', () {
      // 10% anual sobre 36,500 => 3,650 al anio => 10 al dia.
      final daily = YieldRules.dailyEarnings(
        amount: 36500,
        annualYieldPercent: 10,
      );
      expect(daily, closeTo(10, 0.0001));
    });

    test('devuelve 0 cuando no hay tasa', () {
      expect(
        YieldRules.dailyEarnings(amount: 10000, annualYieldPercent: 0),
        0,
      );
    });

    test('devuelve 0 con tasa negativa en lugar de una perdida diaria', () {
      expect(
        YieldRules.dailyEarnings(amount: 10000, annualYieldPercent: -5),
        0,
      );
    });

    test('devuelve 0 cuando no hay capital', () {
      expect(YieldRules.dailyEarnings(amount: 0, annualYieldPercent: 10), 0);
    });

    test('coincide con el getter del modelo MoneyRecord', () {
      final record = _record(amount: 25000, annualYield: 7.5);
      expect(
        YieldRules.dailyEarnings(
          amount: record.amount,
          annualYieldPercent: record.annualYield,
        ),
        closeTo(record.dailyEarnings, 0.0000001),
      );
    });
  });

  group('YieldRules.annualFromDaily', () {
    test('anualiza multiplicando por 365', () {
      expect(YieldRules.annualFromDaily(10), closeTo(3650, 0.0001));
    });

    test('ida y vuelta conserva el rendimiento anual', () {
      const capital = 50000.0;
      const rate = 12.0;
      final daily = YieldRules.dailyEarnings(
        amount: capital,
        annualYieldPercent: rate,
      );
      expect(
        YieldRules.annualFromDaily(daily),
        closeTo(capital * rate / 100, 0.0001),
      );
    });
  });

  group('YieldRules totales', () {
    test('suma montos y ganancias diarias de varios registros', () {
      final records = [
        _record(amount: 36500, annualYield: 10),
        _record(amount: 36500, annualYield: 20),
        _record(amount: 1000),
      ];
      expect(YieldRules.totalAmountOfRecords(records), closeTo(74000, 0.0001));
      expect(
        YieldRules.totalDailyEarningsOfRecords(records),
        closeTo(30, 0.0001),
      );
    });

    test('una lista vacia suma 0 y no revienta', () {
      expect(YieldRules.totalAmountOfRecords(const []), 0);
      expect(YieldRules.totalDailyEarningsOfRecords(const []), 0);
      expect(YieldRules.totalDailyEarningsOfFunds(const []), 0);
    });

    test('suma las ganancias diarias de los fondos de emergencia', () {
      final funds = [
        EmergencyFund(
          id: 'f1',
          userId: 'u',
          name: 'Colchon',
          sourceRecordId: 'r1',
          amount: 36500,
          annualYield: 10,
        ),
        EmergencyFund(
          id: 'f2',
          userId: 'u',
          name: 'Sin rendimiento',
          sourceRecordId: 'r2',
          amount: 5000,
        ),
      ];
      expect(YieldRules.totalDailyEarningsOfFunds(funds), closeTo(10, 0.0001));
    });
  });
}
