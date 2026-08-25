import 'package:flutter_test/flutter_test.dart';
import 'package:stoping_yourself/features/money/domain/salary_rules.dart';
import 'package:stoping_yourself/models/fixed_expense.dart';
import 'package:stoping_yourself/models/quincena_expense.dart';

FixedExpense _fixed(double amount) => FixedExpense(
  id: 'e',
  userId: 'u',
  category: 'Otros',
  name: 'gasto',
  amount: amount,
);

QuincenaExpense _planned(double amount) =>
    QuincenaExpense(id: 'q', userId: 'u', name: 'plan', amount: amount);

void main() {
  group('SalaryRules.hasSalary', () {
    test('un salario en cero no cuenta como configurado', () {
      expect(SalaryRules.hasSalary(0), isFalse);
      expect(SalaryRules.hasSalary(-100), isFalse);
      expect(SalaryRules.hasSalary(0.01), isTrue);
    });
  });

  group('SalaryRules.quincenaAvailable', () {
    test('la quincena es la mitad del salario mensual', () {
      expect(SalaryRules.quincenaAvailable(20000), closeTo(10000, 0.0001));
    });

    test('sin salario configurado no hay disponible', () {
      expect(SalaryRules.quincenaAvailable(0), 0);
    });
  });

  group('SalaryRules.dailySalary', () {
    test('divide el salario mensual entre 30 dias', () {
      expect(SalaryRules.dailySalary(30000), closeTo(1000, 0.0001));
    });

    test('sin salario devuelve 0 en lugar de dividir entre cero', () {
      expect(SalaryRules.dailySalary(0), 0);
    });
  });

  group('SalaryRules porcentajes', () {
    test('percentOfSalary calcula la proporcion', () {
      expect(
        SalaryRules.percentOfSalary(amount: 5000, monthlySalary: 20000),
        closeTo(25, 0.0001),
      );
    });

    test('percentOfSalary devuelve null sin salario, no NaN', () {
      final result = SalaryRules.percentOfSalary(
        amount: 5000,
        monthlySalary: 0,
      );
      expect(result, isNull);
    });

    test('daysOfSalaryCovered convierte ahorro en dias', () {
      // Ahorrar un salario completo equivale a 30 dias.
      expect(
        SalaryRules.daysOfSalaryCovered(amount: 20000, monthlySalary: 20000),
        closeTo(30, 0.0001),
      );
    });

    test('monthsOfSalaryCovered convierte ahorro en meses', () {
      expect(
        SalaryRules.monthsOfSalaryCovered(amount: 40000, monthlySalary: 20000),
        closeTo(2, 0.0001),
      );
    });

    test('las metricas de cobertura devuelven null sin salario', () {
      expect(
        SalaryRules.daysOfSalaryCovered(amount: 100, monthlySalary: 0),
        isNull,
      );
      expect(
        SalaryRules.monthsOfSalaryCovered(amount: 100, monthlySalary: 0),
        isNull,
      );
    });

    test('dailyEarningsAsPercentOfDailySalary compara contra un dia', () {
      // Salario diario = 1000. Ganar 10 al dia es el 1%.
      expect(
        SalaryRules.dailyEarningsAsPercentOfDailySalary(
          dailyEarnings: 10,
          monthlySalary: 30000,
        ),
        closeTo(1, 0.0001),
      );
    });

    test('dailyEarningsAsPercentOfDailySalary es null sin salario', () {
      expect(
        SalaryRules.dailyEarningsAsPercentOfDailySalary(
          dailyEarnings: 10,
          monthlySalary: 0,
        ),
        isNull,
      );
    });
  });

  group('SalaryRules.salaryAfterFixedExpenses', () {
    test('resta los gastos fijos del salario', () {
      expect(
        SalaryRules.salaryAfterFixedExpenses(
          monthlySalary: 20000,
          totalFixedExpenses: 7500,
        ),
        closeTo(12500, 0.0001),
      );
    });

    test('deja pasar el negativo cuando gastas mas de lo que ganas', () {
      expect(
        SalaryRules.salaryAfterFixedExpenses(
          monthlySalary: 10000,
          totalFixedExpenses: 12000,
        ),
        closeTo(-2000, 0.0001),
      );
    });
  });

  group('SalaryRules totales', () {
    test('suma los gastos fijos', () {
      expect(
        SalaryRules.totalFixedExpenses([_fixed(1200), _fixed(350.5)]),
        closeTo(1550.5, 0.0001),
      );
      expect(SalaryRules.totalFixedExpenses(const []), 0);
    });

    test('suma los gastos planeados de la quincena', () {
      expect(
        SalaryRules.totalQuincenaPlanned([_planned(500), _planned(250)]),
        closeTo(750, 0.0001),
      );
      expect(SalaryRules.totalQuincenaPlanned(const []), 0);
    });
  });

  group('SalaryRules.quincenaRemaining', () {
    test('descuenta lo planeado de lo disponible', () {
      expect(
        SalaryRules.quincenaRemaining(
          monthlySalary: 20000,
          plannedExpenses: [_planned(4000), _planned(1000)],
        ),
        closeTo(5000, 0.0001),
      );
    });

    test('es negativo cuando el plan excede la quincena', () {
      expect(
        SalaryRules.quincenaRemaining(
          monthlySalary: 10000,
          plannedExpenses: [_planned(6000)],
        ),
        closeTo(-1000, 0.0001),
      );
    });

    test('sin salario todo lo planeado queda en rojo', () {
      expect(
        SalaryRules.quincenaRemaining(
          monthlySalary: 0,
          plannedExpenses: [_planned(500)],
        ),
        closeTo(-500, 0.0001),
      );
    });
  });
}
