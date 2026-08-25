import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoping_yourself/features/money/application/fixed_expenses_controller.dart';
import 'package:stoping_yourself/features/money/application/money_error_message.dart';
import 'package:stoping_yourself/features/money/application/money_records_controller.dart';
import 'package:stoping_yourself/features/money/application/quincena_controller.dart';
import 'package:stoping_yourself/features/money/application/salary_controller.dart';
import 'package:stoping_yourself/features/money/application/saving_goals_controller.dart';
import 'package:stoping_yourself/features/money/data/money_providers.dart';
import 'package:stoping_yourself/models/saving_goal.dart';

import 'fakes.dart';

void main() {
  group('MoneyRecordsController', () {
    late FakeMoneyRecordsRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeMoneyRecordsRepository();
      container = ProviderContainer(
        overrides: [
          moneyRecordsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
    });

    MoneyRecordsController controller() =>
        container.read(moneyRecordsControllerProvider);

    test('sin recordId inserta un movimiento nuevo', () async {
      await controller().save(
        userId: 'user-1',
        type: 'Ahorro',
        amount: 5000,
        date: DateTime(2026, 3, 1),
        annualYield: 10,
        description: '  cetes  ',
      );

      expect(repository.inserted, hasLength(1));
      expect(repository.updated, isEmpty);
      final record = repository.inserted.single;
      expect(record.description, 'cetes');
      expect(record.annualYield, closeTo(10, 0.0001));
      expect(record.id, isNotEmpty);
    });

    test('con recordId actualiza y conserva el id', () async {
      await controller().save(
        userId: 'user-1',
        type: 'Ahorro',
        amount: 5000,
        date: DateTime(2026, 3, 1),
        recordId: 'existente-7',
      );

      expect(repository.inserted, isEmpty);
      expect(repository.updated, hasLength(1));
      expect(repository.updated.single.id, 'existente-7');
    });

    test('una descripcion vacia se guarda como null', () async {
      await controller().save(
        userId: 'user-1',
        type: 'Ahorro',
        amount: 100,
        date: DateTime(2026, 3, 1),
        description: '   ',
      );

      expect(repository.inserted.single.description, isNull);
    });

    test('rechaza monto no positivo', () async {
      await expectLater(
        controller().save(
          userId: 'u',
          type: 'Ahorro',
          amount: 0,
          date: DateTime(2026, 3, 1),
        ),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(repository.inserted, isEmpty);
    });

    test('rechaza rendimiento negativo', () async {
      await expectLater(
        controller().save(
          userId: 'u',
          type: 'Ahorro',
          amount: 100,
          date: DateTime(2026, 3, 1),
          annualYield: -1,
        ),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(repository.inserted, isEmpty);
    });

    test('borra el movimiento indicado', () async {
      await controller().delete(userId: 'u', recordId: 'rec-3');
      expect(repository.deleted, ['rec-3']);
    });
  });

  group('SalaryController', () {
    late FakeSalaryRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeSalaryRepository();
      container = ProviderContainer(
        overrides: [salaryRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
    });

    SalaryController controller() => container.read(salaryControllerProvider);

    test('guarda el salario del usuario', () async {
      await controller().setMonthlySalary(
        userId: 'user-1',
        monthlySalary: 18500,
      );

      expect(repository.upserted, hasLength(1));
      expect(repository.upserted.single.userId, 'user-1');
      expect(repository.upserted.single.monthlySalary, closeTo(18500, 0.0001));
    });

    test('rechaza salario no positivo', () async {
      await expectLater(
        controller().setMonthlySalary(userId: 'u', monthlySalary: 0),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(repository.upserted, isEmpty);
    });
  });

  group('FixedExpensesController', () {
    late FakeFixedExpensesRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeFixedExpensesRepository();
      container = ProviderContainer(
        overrides: [
          fixedExpensesRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
    });

    FixedExpensesController controller() =>
        container.read(fixedExpensesControllerProvider);

    test('guarda el gasto fijo con nombre recortado', () async {
      await controller().add(
        userId: 'user-1',
        category: 'Vivienda',
        name: '  Renta  ',
        amount: 7000,
      );

      expect(repository.inserted, hasLength(1));
      expect(repository.inserted.single.name, 'Renta');
      expect(repository.inserted.single.category, 'Vivienda');
    });

    test('rechaza nombre vacio', () async {
      await expectLater(
        controller().add(
          userId: 'u',
          category: 'Otros',
          name: '  ',
          amount: 100,
        ),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(repository.inserted, isEmpty);
    });

    test('rechaza monto no positivo', () async {
      await expectLater(
        controller().add(
          userId: 'u',
          category: 'Otros',
          name: 'Luz',
          amount: -5,
        ),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(repository.inserted, isEmpty);
    });

    test('las categorias declaradas son las que la UI espera', () {
      expect(fixedExpenseCategories.first, 'Vivienda');
      expect(fixedExpenseCategories, contains('Alimentacion'));
      expect(fixedExpenseCategories, contains('Educacion'));
      expect(fixedExpenseCategories.last, 'Otros');
    });
  });

  group('QuincenaController', () {
    late FakeQuincenaRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeQuincenaRepository();
      container = ProviderContainer(
        overrides: [quincenaRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
    });

    QuincenaController controller() =>
        container.read(quincenaControllerProvider);

    test('agrega el gasto planeado', () async {
      await controller().addExpense(
        userId: 'user-1',
        name: '  Despensa  ',
        amount: 1800,
      );

      expect(repository.inserted, hasLength(1));
      expect(repository.inserted.single.name, 'Despensa');
      expect(repository.inserted.single.amount, closeTo(1800, 0.0001));
    });

    test('rechaza nombre vacio', () async {
      await expectLater(
        controller().addExpense(userId: 'u', name: '   ', amount: 100),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(repository.inserted, isEmpty);
    });

    test('rechaza monto no positivo', () async {
      await expectLater(
        controller().addExpense(userId: 'u', name: 'Despensa', amount: 0),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(repository.inserted, isEmpty);
    });

    test('reiniciar borra todos los gastos del usuario', () async {
      await controller().resetExpenses('user-1');
      expect(repository.deletedAll, isTrue);
    });
  });

  group('SavingGoalsController', () {
    late FakeSavingGoalsRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakeSavingGoalsRepository();
      container = ProviderContainer(
        overrides: [
          savingGoalsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
    });

    SavingGoalsController controller() =>
        container.read(savingGoalsControllerProvider);

    test('crea la meta y marca cumplimiento segun el monto inicial', () async {
      await controller().add(
        userId: 'user-1',
        name: '  Laptop  ',
        targetAmount: 30000,
        currentAmount: 30000,
        url: '  https://ejemplo.mx  ',
      );

      final goal = repository.inserted.single;
      expect(goal.name, 'Laptop');
      expect(goal.url, 'https://ejemplo.mx');
      expect(goal.isCompleted, isTrue);
    });

    test('una url vacia se guarda como null', () async {
      await controller().add(
        userId: 'user-1',
        name: 'Laptop',
        targetAmount: 100,
        url: '   ',
      );

      expect(repository.inserted.single.url, isNull);
    });

    test('rechaza objetivo no positivo', () async {
      await expectLater(
        controller().add(userId: 'u', name: 'X', targetAmount: 0),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(repository.inserted, isEmpty);
    });

    test('rechaza monto inicial negativo', () async {
      await expectLater(
        controller().add(
          userId: 'u',
          name: 'X',
          targetAmount: 100,
          currentAmount: -1,
        ),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(repository.inserted, isEmpty);
    });

    test('actualizar el monto recalcula el cumplimiento', () async {
      final goal = SavingGoal(
        id: 'goal-1',
        userId: 'user-1',
        name: 'Laptop',
        targetAmount: 1000,
        currentAmount: 100,
        createdAt: DateTime(2026, 1, 1),
      );

      await controller().updateAmount(
        userId: 'user-1',
        goal: goal,
        currentAmount: 1000,
      );

      final updated = repository.updated.single;
      expect(updated.id, 'goal-1');
      expect(updated.currentAmount, closeTo(1000, 0.0001));
      expect(updated.isCompleted, isTrue);
    });

    test('rechaza monto negativo al actualizar', () async {
      final goal = SavingGoal(
        id: 'goal-1',
        userId: 'user-1',
        name: 'Laptop',
        targetAmount: 1000,
      );

      await expectLater(
        controller().updateAmount(
          userId: 'user-1',
          goal: goal,
          currentAmount: -5,
        ),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(repository.updated, isEmpty);
    });
  });
}
