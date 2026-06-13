import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import 'money_tracking_screen.dart';
import 'fixed_expenses_content.dart';
import 'salary_summary_card.dart';
import 'finance_charts.dart';

// Aliases para providers de otras pantallas
import 'money_tracking_screen.dart' as money;
import 'fixed_expenses_content.dart' as expenses;
import 'salary_summary_card.dart' as salary;

class FinanceHubScreen extends ConsumerStatefulWidget {
  const FinanceHubScreen({super.key});

  @override
  ConsumerState<FinanceHubScreen> createState() => _FinanceHubScreenState();
}

class _FinanceHubScreenState extends ConsumerState<FinanceHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveHelper(context);
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final userId = user?.id;

    // ── Providers compartidos ──
    final totalSaved = userId != null
        ? ref.watch(money.totalSavedProvider(userId))
        : null;
    final totalDaily = userId != null
        ? ref.watch(money.totalDailyEarningsProvider(userId))
        : null;
    final totalFixed = userId != null
        ? ref.watch(expenses.totalFixedExpensesProvider(userId))
        : null;

    // Listas completas para las graficas
    final moneyRecords = userId != null
        ? ref.watch(money.moneyRecordsProvider(userId))
        : null;
    final fixedExpenses = userId != null
        ? ref.watch(expenses.fixedExpensesProvider(userId))
        : null;

    final saved = totalSaved?.asData?.value ?? 0;
    final daily = totalDaily?.asData?.value ?? 0;
    final fixed = totalFixed?.asData?.value ?? 0;
    final monthlySalary =
        (userId != null
                ? ref.watch(salary.salarySettingProvider(userId))
                : null)
            ?.asData
            ?.value
            ?.monthlySalary ??
        0;

    final salaryCard = SalarySummaryCard(
      totalSaved: saved,
      totalDailyEarnings: daily,
      totalFixedExpenses: fixed,
    );

    final charts = FinanceCharts(
      moneyRecords: moneyRecords?.asData?.value ?? [],
      fixedExpenses: fixedExpenses?.asData?.value ?? [],
      totalSaved: saved,
      totalFixedExpenses: fixed,
      totalDailyEarnings: daily,
      monthlySalary: monthlySalary,
    );

    if (r.isDesktop) {
      // 3 columnas usando todo el viewport disponible
      return Column(
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: r.padHorizontal,
              right: r.padHorizontal,
              top: r.padVertical,
            ),
            child: salaryCard,
          ),
          SizedBox(height: r.cardSpacing),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.padHorizontal),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(child: MoneyTrackingScreen()),
                  SizedBox(width: r.cardSpacing),
                  const Expanded(child: FixedExpensesContent()),
                  SizedBox(width: r.cardSpacing),
                  Expanded(child: charts),
                ],
              ),
            ),
          ),
          SizedBox(height: r.padVertical),
        ],
      );
    }

    // Mobile / Tablet: 3 tabs (Ahorros | Gastos | Graficas)
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: r.padHorizontal,
            right: r.padHorizontal,
            top: r.padVertical,
          ),
          child: salaryCard,
        ),
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelStyle: GoogleFonts.inter(
              fontSize: r.bodyFontSize,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: r.bodyFontSize),
            tabs: const [
              Tab(icon: Icon(Icons.savings_outlined), text: 'Ahorros'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Gastos'),
              Tab(icon: Icon(Icons.bar_chart_outlined), text: 'Graficas'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              const MoneyTrackingScreen(),
              const FixedExpensesContent(),
              SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: r.padHorizontal,
                  vertical: r.padVertical / 2,
                ),
                child: charts,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
