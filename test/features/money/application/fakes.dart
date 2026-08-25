import 'dart:typed_data';

import 'package:stoping_yourself/features/money/data/debts_repository.dart';
import 'package:stoping_yourself/features/money/data/emergency_funds_repository.dart';
import 'package:stoping_yourself/features/money/data/fixed_expenses_repository.dart';
import 'package:stoping_yourself/features/money/data/money_records_repository.dart';
import 'package:stoping_yourself/features/money/data/quincena_repository.dart';
import 'package:stoping_yourself/features/money/data/salary_repository.dart';
import 'package:stoping_yourself/features/money/data/saving_goal_images_repository.dart';
import 'package:stoping_yourself/features/money/data/saving_goals_repository.dart';
import 'package:stoping_yourself/models/debt.dart';
import 'package:stoping_yourself/models/emergency_fund.dart';
import 'package:stoping_yourself/models/fixed_expense.dart';
import 'package:stoping_yourself/models/money_record.dart';
import 'package:stoping_yourself/models/quincena_expense.dart';
import 'package:stoping_yourself/models/salary_setting.dart';
import 'package:stoping_yourself/models/saving_goal.dart';

/// Dobles de prueba de los repositorios.
///
/// Se usa `implements` sobre las clases concretas: en Dart toda clase define
/// una interfaz implicita, asi que no hace falta agregar abstracciones al
/// codigo de produccion solo para poder testear.

class FakeMoneyRecordsRepository implements MoneyRecordsRepository {
  final List<MoneyRecord> inserted = [];
  final List<MoneyRecord> updated = [];
  final List<String> deleted = [];
  bool deletedAll = false;

  @override
  Future<List<MoneyRecord>> fetchAll(String userId) async => const [];

  @override
  Future<void> insert(MoneyRecord record) async => inserted.add(record);

  @override
  Future<void> update(MoneyRecord record) async => updated.add(record);

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  Future<void> deleteAllOf(String userId) async => deletedAll = true;
}

class FakeDebtsRepository implements DebtsRepository {
  final List<Debt> inserted = [];
  final List<Debt> updated = [];
  final List<String> deleted = [];
  final List<DebtPayment> registeredPayments = [];
  final List<String> deletedPayments = [];
  bool deletedAll = false;

  @override
  Future<List<Debt>> fetchAll(String userId) async => const [];

  @override
  Future<Debt?> fetchOne(String debtId) async => null;

  @override
  Future<void> insert(Debt debt) async => inserted.add(debt);

  @override
  Future<void> update(Debt debt) async => updated.add(debt);

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  Future<List<DebtPayment>> fetchPayments(String debtId) async => const [];

  @override
  Future<Debt> registerPayment({
    required Debt debt,
    required DebtPayment payment,
  }) async {
    registeredPayments.add(payment);
    return Debt(
      id: debt.id,
      userId: debt.userId,
      name: debt.name,
      totalAmount: debt.totalAmount,
      paidAmount: debt.paidAmount + payment.amount,
      interestRate: debt.interestRate,
      createdAt: debt.createdAt,
    );
  }

  @override
  Future<void> deletePayment(String id) async => deletedPayments.add(id);

  @override
  Future<void> deleteAllOf(String userId) async => deletedAll = true;
}

class FakeSavingGoalsRepository implements SavingGoalsRepository {
  FakeSavingGoalsRepository({this.goals = const []});

  /// Metas que devuelve [fetchAll].
  List<SavingGoal> goals;

  final List<SavingGoal> inserted = [];
  final List<SavingGoal> updated = [];
  final List<String> deleted = [];
  bool deletedAll = false;

  /// Cuando es true, [insert] y [update] fallan para probar la limpieza de
  /// imagenes huerfanas.
  bool failWrites = false;

  @override
  Future<List<SavingGoal>> fetchAll(String userId) async => goals;

  @override
  Future<void> insert(SavingGoal goal) async {
    if (failWrites) throw Exception('insert fallo');
    inserted.add(goal);
  }

  @override
  Future<void> update(SavingGoal goal) async {
    if (failWrites) throw Exception('update fallo');
    updated.add(goal);
  }

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  Future<void> deleteAllOf(String userId) async => deletedAll = true;
}

class FakeSavingGoalImagesRepository implements SavingGoalImagesRepository {
  final List<String> uploadedPaths = [];
  final List<Uint8List> uploadedBytes = [];
  final List<String> uploadedContentTypes = [];
  final List<String> deletedPaths = [];
  final List<String> deletedFolders = [];

  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    uploadedPaths.add(path);
    uploadedBytes.add(bytes);
    uploadedContentTypes.add(contentType);
    return path;
  }

  @override
  Future<String> createSignedUrl(String path) async => 'https://fake/$path';

  @override
  Future<void> delete(String path) async => deletedPaths.add(path);

  @override
  Future<void> deleteMany(List<String> paths) async =>
      deletedPaths.addAll(paths);

  @override
  Future<void> deleteFolderOfGoal({
    required String userId,
    required String goalId,
  }) async => deletedFolders.add('$userId/$goalId');
}

class FakeSalaryRepository implements SalaryRepository {
  final List<SalarySetting> upserted = [];
  bool deletedAll = false;

  @override
  Future<SalarySetting?> fetch(String userId) async => null;

  @override
  Future<void> upsert(SalarySetting salary) async => upserted.add(salary);

  @override
  Future<void> deleteAllOf(String userId) async => deletedAll = true;
}

class FakeFixedExpensesRepository implements FixedExpensesRepository {
  final List<FixedExpense> inserted = [];
  final List<String> deleted = [];
  bool deletedAll = false;

  @override
  Future<List<FixedExpense>> fetchAll(String userId) async => const [];

  @override
  Future<void> insert(FixedExpense expense) async => inserted.add(expense);

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  Future<void> deleteAllOf(String userId) async => deletedAll = true;
}

class FakeQuincenaRepository implements QuincenaRepository {
  final List<QuincenaExpense> inserted = [];
  final List<String> deleted = [];
  bool deletedAll = false;

  @override
  Future<List<QuincenaExpense>> fetchAll(String userId) async => const [];

  @override
  Future<void> insert(QuincenaExpense expense) async => inserted.add(expense);

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  Future<void> deleteAllOf(String userId) async => deletedAll = true;
}

class FakeEmergencyFundsRepository implements EmergencyFundsRepository {
  FakeEmergencyFundsRepository({this.entries = const []});

  /// Subdivisiones que devuelve [fetchEntries], para probar la validacion
  /// de lo disponible.
  List<EmergencyFundEntry> entries;

  final List<EmergencyFund> inserted = [];
  final List<EmergencyFund> updated = [];
  final List<String> deleted = [];
  final List<EmergencyFundEntry> insertedEntries = [];
  final List<String> deletedEntries = [];
  bool deletedAll = false;

  @override
  Future<List<EmergencyFund>> fetchAll(String userId) async => const [];

  @override
  Future<void> insert(EmergencyFund fund) async => inserted.add(fund);

  @override
  Future<void> update(EmergencyFund fund) async => updated.add(fund);

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  Future<List<EmergencyFundEntry>> fetchEntries(String fundId) async => entries;

  @override
  Future<void> insertEntry(EmergencyFundEntry entry) async =>
      insertedEntries.add(entry);

  @override
  Future<void> updateEntry(EmergencyFundEntry entry) async {}

  @override
  Future<void> deleteEntry(String id) async => deletedEntries.add(id);

  @override
  Future<void> deleteAllEntriesOf(String fundId) async {}

  @override
  Future<void> deleteAllOf(String userId) async => deletedAll = true;
}
