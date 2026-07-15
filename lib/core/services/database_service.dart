import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/profile.dart';
import '../../models/category.dart';
import '../../models/lesson.dart';
import '../../models/user_progress.dart';
import '../../models/relapse_record.dart';
import '../../models/money_record.dart';
import '../../models/fixed_expense.dart';
import '../../models/salary_setting.dart';
import '../../models/debt.dart';
import '../../models/health_record.dart';
import '../../models/daily_activity.dart';
import '../../models/saving_goal.dart';
import '../../models/lol_record.dart';
import '../../models/monthly_payment.dart';
import 'supabase_service.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService(ref.watch(supabaseClientProvider));
});

class DatabaseService {
  final SupabaseClient _client;

  DatabaseService(this._client);

  Future<Profile> getOrCreateProfile(String userId, String email) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data != null) return Profile.fromJson(data);
    } catch (_) {
      // Tabla profiles no existe o error RLS
    }

    // Si no hay perfil (trigger no configurado o tabla no existe),
    // devolvemos un perfil por defecto
    final fallback = Profile(
      id: userId,
      email: email,
      displayName: email.split('@').first,
    );

    // Intentamos guardarlo para la proxima
    try {
      await _client.from('profiles').upsert(fallback.toJson());
    } catch (_) {}

    return fallback;
  }

  Future<void> upsertProfile(Profile profile) async {
    try {
      await _client.from('profiles').upsert(profile.toJson());
    } catch (_) {}
  }

  Future<List<Category>> getCategories() async {
    try {
      final data = await _client
          .from('categories')
          .select()
          .order('sort_order');
      return data.map((e) => Category.fromJson(e)).toList();
    } catch (_) {
      return _defaultCategories();
    }
  }

  Future<List<Lesson>> getLessonsByCategory(String categoryId) async {
    try {
      final data = await _client
          .from('lessons')
          .select()
          .eq('category_id', categoryId)
          .order('sort_order');
      return data.map((e) => Lesson.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Lesson?> getLesson(String lessonId) async {
    final data = await _client
        .from('lessons')
        .select()
        .eq('id', lessonId)
        .maybeSingle();
    if (data == null) return null;
    return Lesson.fromJson(data);
  }

  Future<List<UserProgress>> getUserProgress(String userId) async {
    try {
      final data = await _client
          .from('user_progress')
          .select()
          .eq('user_id', userId);
      return data.map((e) => UserProgress.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> upsertProgress(UserProgress progress) async {
    try {
      await _client.from('user_progress').upsert(progress.toJson());
    } catch (_) {}
  }

  Future<int> getCompletedLessonsCount(String userId) async {
    try {
      final data = await _client
          .from('user_progress')
          .select()
          .eq('user_id', userId)
          .eq('completed', true);
      return data.length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getTotalXp(String userId) async {
    try {
      final data = await _client
          .from('user_progress')
          .select('score')
          .eq('user_id', userId);
      int total = 0;
      for (final item in data) {
        total += (item['score'] as int?) ?? 0;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  List<Category> _defaultCategories() {
    return [
      Category(
        id: '1',
        name: 'Ansiedad',
        emoji: '🧠',
        colorHex: '#8B5A2B',
        sortOrder: 1,
      ),
      Category(
        id: '2',
        name: 'Autoestima',
        emoji: '💪',
        colorHex: '#D4AF37',
        sortOrder: 2,
      ),
      Category(
        id: '3',
        name: 'Habitos',
        emoji: '🌱',
        colorHex: '#228B22',
        sortOrder: 3,
      ),
      Category(
        id: '4',
        name: 'Mindfulness',
        emoji: '🧘',
        colorHex: '#808080',
        sortOrder: 4,
      ),
    ];
  }

  // ============================================================
  // Recaidas
  // ============================================================
  Future<List<RelapseRecord>> getRelapseRecords(String userId) async {
    try {
      final data = await _client
          .from('relapse_records')
          .select()
          .eq('user_id', userId)
          .order('relapse_date', ascending: false);
      return data.map((e) => RelapseRecord.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> insertRelapse(RelapseRecord record) async {
    await _client.from('relapse_records').insert(record.toJson());
  }

  Future<void> deleteRelapse(String id) async {
    try {
      await _client.from('relapse_records').delete().eq('id', id);
    } catch (_) {}
  }

  // ============================================================
  // Dinero / Ahorros
  // ============================================================
  Future<List<MoneyRecord>> getMoneyRecords(String userId) async {
    try {
      final data = await _client
          .from('money_records')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);
      return data.map((e) => MoneyRecord.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> insertMoney(MoneyRecord record) async {
    try {
      await _client.from('money_records').insert(record.toJson());
    } catch (_) {}
  }

  Future<void> updateMoney(MoneyRecord record) async {
    try {
      await _client.from('money_records').update(record.toJson()).eq('id', record.id);
    } catch (_) {}
  }

  Future<void> deleteMoney(String id) async {
    try {
      await _client.from('money_records').delete().eq('id', id);
    } catch (_) {}
  }

  Future<double> getTotalSaved(String userId) async {
    try {
      final data = await _client
          .from('money_records')
          .select('amount')
          .eq('user_id', userId);
      double total = 0;
      for (final item in data) {
        total += (item['amount'] as num?)?.toDouble() ?? 0;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Suma total de ganancias diarias de todos los registros
  Future<double> getTotalDailyEarnings(String userId) async {
    try {
      final data = await _client
          .from('money_records')
          .select('amount, annual_yield')
          .eq('user_id', userId);
      double total = 0;
      for (final item in data) {
        final amount = (item['amount'] as num?)?.toDouble() ?? 0;
        final yieldVal = (item['annual_yield'] as num?)?.toDouble() ?? 0;
        if (yieldVal > 0) {
          total += amount * (yieldVal / 100) / 365;
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  // ============================================================
  // Gastos fijos mensuales
  // ============================================================
  Future<List<FixedExpense>> getFixedExpenses(String userId) async {
    try {
      final data = await _client
          .from('fixed_expenses')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return data.map((e) => FixedExpense.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> insertFixedExpense(FixedExpense expense) async {
    await _client.from('fixed_expenses').insert(expense.toJson());
  }

  Future<void> deleteFixedExpense(String id) async {
    await _client.from('fixed_expenses').delete().eq('id', id);
  }

  Future<double> getTotalFixedExpenses(String userId) async {
    try {
      final data = await _client
          .from('fixed_expenses')
          .select('amount')
          .eq('user_id', userId);
      double total = 0;
      for (final item in data) {
        total += (item['amount'] as num?)?.toDouble() ?? 0;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  // ============================================================
  // Salario
  // ============================================================
  Future<SalarySetting?> getSalarySetting(String userId) async {
    try {
      final data = await _client
          .from('salary_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (data == null) return null;
      return SalarySetting.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertSalary(SalarySetting salary) async {
    await _client.from('salary_settings').upsert(salary.toJson());
  }

  // ============================================================
  // Deudas y pagos
  // ============================================================
  Future<List<Debt>> getDebts(String userId) async {
    try {
      final data = await _client
          .from('debts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return data.map((e) => Debt.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Debt?> getDebt(String debtId) async {
    try {
      final data = await _client
          .from('debts')
          .select()
          .eq('id', debtId)
          .maybeSingle();
      if (data == null) return null;
      return Debt.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> insertDebt(Debt debt) async {
    await _client.from('debts').insert(debt.toJson());
  }

  Future<void> updateDebt(Debt debt) async {
    await _client.from('debts').update(debt.toJson()).eq('id', debt.id);
  }

  Future<void> deleteDebt(String id) async {
    await _client.from('debts').delete().eq('id', id);
  }

  Future<List<DebtPayment>> getDebtPayments(String debtId) async {
    try {
      final data = await _client
          .from('debt_payments')
          .select()
          .eq('debt_id', debtId)
          .order('payment_date', ascending: false);
      return data.map((e) => DebtPayment.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> insertDebtPayment(DebtPayment payment) async {
    await _client.from('debt_payments').insert(payment.toJson());
  }

  Future<void> deleteDebtPayment(String id) async {
    await _client.from('debt_payments').delete().eq('id', id);
  }

  // ============================================================
  // Salud / Deporte
  // ============================================================
  Future<List<HealthRecord>> getHealthRecords(String userId) async {
    try {
      final data = await _client
          .from('health_records')
          .select()
          .eq('user_id', userId)
          .order('record_date', ascending: false);
      return data.map((e) => HealthRecord.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> insertHealthRecord(HealthRecord record) async {
    await _client.from('health_records').insert(record.toJson());
  }

  Future<void> deleteHealthRecord(String id) async {
    await _client.from('health_records').delete().eq('id', id);
  }

  Future<int> getTotalSteps(String userId) async {
    try {
      final data = await _client
          .from('health_records')
          .select('steps')
          .eq('user_id', userId);
      int total = 0;
      for (final item in data) {
        total += (item['steps'] as num?)?.toInt() ?? 0;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<double> getAvgSteps(String userId, {int days = 7}) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      final data = await _client
          .from('health_records')
          .select('steps')
          .eq('user_id', userId)
          .gte('record_date', cutoff.toUtc().toIso8601String());
      if (data.isEmpty) return 0;
      int total = 0;
      for (final item in data) {
        total += (item['steps'] as num?)?.toInt() ?? 0;
      }
      return total / data.length;
    } catch (_) {
      return 0;
    }
  }

  // ============================================================
  // Actividades diarias
  // ============================================================
  Future<List<DailyActivity>> getDailyActivities(
    String userId, {
    DateTime? date,
  }) async {
    try {
      var query = _client
          .from('daily_activities')
          .select()
          .eq('user_id', userId);
      if (date != null) {
        final start = DateTime(date.year, date.month, date.day);
        final end = start.add(const Duration(days: 1));
        query = query
            .gte('scheduled_date', start.toUtc().toIso8601String())
            .lt('scheduled_date', end.toUtc().toIso8601String());
      }
      final data = await query.order('created_at', ascending: true);
      return data.map((e) => DailyActivity.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> insertDailyActivity(DailyActivity activity) async {
    await _client.from('daily_activities').insert(activity.toJson());
  }

  Future<void> updateDailyActivity(DailyActivity activity) async {
    await _client
        .from('daily_activities')
        .update(activity.toJson())
        .eq('id', activity.id);
  }

  Future<void> deleteDailyActivity(String id) async {
    await _client.from('daily_activities').delete().eq('id', id);
  }

  // ============================================================
  // Metas de ahorro
  // ============================================================
  Future<List<SavingGoal>> getSavingGoals(String userId) async {
    try {
      final data = await _client
          .from('saving_goals')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return data.map((e) => SavingGoal.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> insertSavingGoal(SavingGoal goal) async {
    await _client.from('saving_goals').insert(goal.toJson());
  }

  Future<void> updateSavingGoal(SavingGoal goal) async {
    await _client.from('saving_goals').update(goal.toJson()).eq('id', goal.id);
  }

  Future<void> deleteSavingGoal(String id) async {
    await _client.from('saving_goals').delete().eq('id', id);
  }

  // ============================================================
  // LoL (Registros de PL ganado/perdido)
  // ============================================================
  Future<List<LolRecord>> getLolRecords(String userId) async {
    try {
      final data = await _client
          .from('lol_records')
          .select()
          .eq('user_id', userId)
          .order('record_date', ascending: false);
      return data.map((e) => LolRecord.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> insertLolRecord(LolRecord record) async {
    await _client.from('lol_records').insert(record.toJson());
  }

  Future<void> updateLolRecord(LolRecord record) async {
    await _client
        .from('lol_records')
        .update(record.toJson())
        .eq('id', record.id);
  }

  Future<void> deleteLolRecord(String id) async {
    await _client.from('lol_records').delete().eq('id', id);
  }

  Future<double> getTotalNetPl(String userId) async {
    try {
      final data = await _client
          .from('lol_records')
          .select('pl_gained, pl_lost')
          .eq('user_id', userId);
      double net = 0;
      for (final item in data) {
        final gained = (item['pl_gained'] as num?)?.toDouble() ?? 0;
        final lost = (item['pl_lost'] as num?)?.toDouble() ?? 0;
        net += (gained - lost);
      }
      return net;
    } catch (_) {
      return 0;
    }
  }

  // ============================================================
  // Pagos mensuales (creditos corto plazo / tarjetas)
  // ============================================================
  Future<List<MonthlyPayment>> getMonthlyPayments(String userId) async {
    try {
      final data = await _client
          .from('monthly_payments')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return data.map((e) => MonthlyPayment.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> insertMonthlyPayment(MonthlyPayment payment) async {
    await _client.from('monthly_payments').insert(payment.toJson());
  }

  Future<void> updateMonthlyPayment(MonthlyPayment payment) async {
    await _client
        .from('monthly_payments')
        .update(payment.toJson())
        .eq('id', payment.id);
  }

  Future<void> deleteMonthlyPayment(String id) async {
    await _client.from('monthly_payments').delete().eq('id', id);
  }

  Future<double> getTotalMonthlyPayments(String userId) async {
    try {
      final data = await _client
          .from('monthly_payments')
          .select('amount')
          .eq('user_id', userId);
      double total = 0;
      for (final item in data) {
        total += (item['amount'] as num?)?.toDouble() ?? 0;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
