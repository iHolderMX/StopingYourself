import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import 'money_tracking_screen.dart';
import 'fixed_expenses_content.dart';
import 'salary_summary_card.dart';
import 'finance_charts.dart';
import 'debts_content.dart';
import 'saving_goals_content.dart';
import 'emergency_fund_content.dart';
import 'next_quincena_card.dart';

// Aliases para providers de otras pantallas
import 'money_tracking_screen.dart' as money;
import 'fixed_expenses_content.dart' as expenses;
import 'salary_summary_card.dart' as salary;
import 'debts_content.dart' as debts;
import 'saving_goals_content.dart' as goals;

class FinanceHubScreen extends ConsumerStatefulWidget {
  const FinanceHubScreen({super.key});

  @override
  ConsumerState<FinanceHubScreen> createState() => _FinanceHubScreenState();
}

class _FinanceHubScreenState extends ConsumerState<FinanceHubScreen> {
  bool _compactMode = false;
  bool _summaryExpanded = false;
  bool _resetting = false;
  final GlobalKey _quincenaKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _resetAllFinances() async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reiniciar finanzas'),
        content: const Text(
          'Esto eliminara todas tus inversiones, deudas, gastos fijos, '
          'metas de ahorro, pagos mensuales y configuracion de salario. '
          'Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Reiniciar todo'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _resetting = true);
    try {
      await ref.read(databaseServiceProvider).resetAllFinances(user.id);
      // Invalidar providers para refrescar la UI
      ref.invalidate(money.totalSavedProvider(user.id));
      ref.invalidate(money.totalDailyEarningsProvider(user.id));
      ref.invalidate(money.moneyRecordsProvider(user.id));
      ref.invalidate(expenses.totalFixedExpensesProvider(user.id));
      ref.invalidate(expenses.fixedExpensesProvider(user.id));
      ref.invalidate(salary.salarySettingProvider(user.id));
      ref.invalidate(debts.debtsProvider(user.id));
      ref.invalidate(goals.savingGoalsProvider(user.id));
      ref.invalidate(quincenaExpensesProvider(user.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Finanzas reiniciadas correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  Future<void> _goToQuincena() async {
    final r = ResponsiveHelper(context);
    if (!r.isDesktop && !_summaryExpanded) {
      setState(() => _summaryExpanded = true);
      // Espera a que AnimatedSize expanda y monte la tarjeta.
      await Future.delayed(const Duration(milliseconds: 350));
    }
    final ctx = _quincenaKey.currentContext;
    if (ctx == null || !mounted) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.08,
    );
  }

  Widget _floatingButton({
    required VoidCallback? onTap,
    required bool loading,
    required IconData icon,
    required String label,
    required Color background,
    required Color foreground,
    required double iconSize,
    required double fontSize,
    required double radius,
  }) {
    final big = iconSize > 22;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(radius),
      color: loading ? background.withValues(alpha: 0.6) : background,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: loading ? null : onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: big ? 18 : 14,
            vertical: big ? 12 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: loading
              ? SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: foreground,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: foreground, size: iconSize),
                    SizedBox(width: big ? 6 : 5),
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      return Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(bottom: r.padVertical),
            child: Column(
              children: [
                // Header: salary card + toggle flotante
                Padding(
                  padding: EdgeInsets.only(
                    left: r.padHorizontal,
                    right: r.padHorizontal,
                    top: r.padVertical,
                  ),
                  child: Stack(
                    children: [
                      salaryCard,
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(
                              r.borderRadius - 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.08,
                                ),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              _compactMode
                                  ? Icons.fullscreen
                                  : Icons.fullscreen_exit,
                              size: 22,
                            ),
                            tooltip: _compactMode
                                ? 'Ver todo expandido'
                                : 'Ver columnas compactas',
                            onPressed: () =>
                                setState(() => _compactMode = !_compactMode),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r.cardSpacing),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.padHorizontal),
                  child: NextQuincenaCard(key: _quincenaKey),
                ),
                SizedBox(height: r.cardSpacing),
                if (_compactMode)
                  // Modo compacto: columnas responsivas con Wrap
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.padHorizontal),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxW = constraints.maxWidth;
                        // En pantallas anchas: 5 columnas expandidas
                        // En pantallas angostas: Wrap con columnas de ancho fijo
                        final useWrap = maxW < 1300;
                        const colMinWidth = 300.0;

                        if (useWrap) {
                          return Wrap(
                            spacing: r.cardSpacing,
                            runSpacing: r.cardSpacing,
                            children: [
                              const SizedBox(
                                width: colMinWidth,
                                child: MoneyTrackingScreen(),
                              ),
                              const SizedBox(
                                width: colMinWidth,
                                child: FixedExpensesContent(),
                              ),
                              SizedBox(
                                width: colMinWidth,
                                child: DebtsContent(totalSaved: saved),
                              ),
                              const SizedBox(
                                width: colMinWidth,
                                child: SavingGoalsContent(),
                              ),
                              const SizedBox(
                                width: colMinWidth,
                                child: EmergencyFundContent(),
                              ),
                              SizedBox(width: colMinWidth, child: charts),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(child: MoneyTrackingScreen()),
                            SizedBox(width: r.cardSpacing),
                            const Expanded(child: FixedExpensesContent()),
                            SizedBox(width: r.cardSpacing),
                            Expanded(child: DebtsContent(totalSaved: saved)),
                            SizedBox(width: r.cardSpacing),
                            const Expanded(child: SavingGoalsContent()),
                            SizedBox(width: r.cardSpacing),
                            const Expanded(child: EmergencyFundContent()),
                            SizedBox(width: r.cardSpacing),
                            Expanded(child: charts),
                          ],
                        );
                      },
                    ),
                  )
                else
                  // Modo expandido: todo vertical, dentro del scroll principal
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.padHorizontal),
                    child: Column(
                      children: [
                        const MoneyTrackingScreen(compact: false),
                        SizedBox(height: r.cardSpacing + 12),
                        const FixedExpensesContent(compact: false),
                        SizedBox(height: r.cardSpacing + 12),
                        DebtsContent(compact: false, totalSaved: saved),
                        SizedBox(height: r.cardSpacing + 12),
                        const SavingGoalsContent(compact: false),
                        SizedBox(height: r.cardSpacing + 12),
                        const EmergencyFundContent(compact: false),
                        SizedBox(height: r.cardSpacing + 12),
                        charts,
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Botones flotantes - siempre visibles top-left
          Positioned(
            top: r.padVertical + 4,
            left: r.padHorizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _floatingButton(
                  onTap: _resetting ? null : _resetAllFinances,
                  loading: _resetting,
                  icon: Icons.restart_alt,
                  label: 'Reiniciar',
                  background: Colors.red.withValues(alpha: 0.9),
                  foreground: Colors.white,
                  iconSize: 24,
                  fontSize: 14,
                  radius: 16,
                ),
                const SizedBox(height: 8),
                _floatingButton(
                  onTap: _goToQuincena,
                  loading: false,
                  icon: Icons.event_available,
                  label: 'Planear quincena',
                  background: theme.colorScheme.primary,
                  foreground: theme.colorScheme.onPrimary,
                  iconSize: 24,
                  fontSize: 14,
                  radius: 16,
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Mobile / Tablet: todo en scroll simple, sin headers fijos
    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.only(
            left: r.padHorizontal,
            right: r.padHorizontal,
            top: r.padVertical + 8,
            bottom: r.padVertical + 24,
          ),
          child: Column(
            children: [
              // Barra colapsable para el resumen financiero
              GestureDetector(
                onTap: () =>
                    setState(() => _summaryExpanded = !_summaryExpanded),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.cardSpacing - 4,
                    vertical: r.cardSpacing - 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(r.borderRadius - 2),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: theme.colorScheme.primary,
                        size: r.iconSizeMedium - 2,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Resumen Financiero',
                        style: GoogleFonts.outfit(
                          fontSize: r.subtitleFontSize,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      if (!_summaryExpanded && monthlySalary > 0)
                        Text(
                          '\$${(monthlySalary / 2).toStringAsFixed(0)} libres',
                          style: GoogleFonts.inter(
                            fontSize: r.bodyFontSize - 2,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _summaryExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: theme.colorScheme.primary,
                          size: r.iconSizeMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Contenido colapsable
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _summaryExpanded
                    ? Column(
                        children: [
                          SizedBox(height: r.cardSpacing - 2),
                          salaryCard,
                          SizedBox(height: r.cardSpacing - 4),
                          NextQuincenaCard(key: _quincenaKey),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              SizedBox(height: r.cardSpacing + 4),
              // Secciones de contenido, todas scrolleables
              const MoneyTrackingScreen(compact: false),
              SizedBox(height: r.cardSpacing + 8),
              const FixedExpensesContent(compact: false),
              SizedBox(height: r.cardSpacing + 8),
              DebtsContent(compact: false, totalSaved: saved),
              SizedBox(height: r.cardSpacing + 8),
              const SavingGoalsContent(compact: false),
              SizedBox(height: r.cardSpacing + 8),
              const EmergencyFundContent(compact: false),
              SizedBox(height: r.cardSpacing + 8),
              charts,
            ],
          ),
        ),
        // Botones flotantes - siempre visibles top-left
        Positioned(
          top: r.padVertical + 4,
          left: r.padHorizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _floatingButton(
                onTap: _resetting ? null : _resetAllFinances,
                loading: _resetting,
                icon: Icons.restart_alt,
                label: 'Reiniciar',
                background: Colors.red.withValues(alpha: 0.9),
                foreground: Colors.white,
                iconSize: 22,
                fontSize: 13,
                radius: 14,
              ),
              const SizedBox(height: 8),
              _floatingButton(
                onTap: _goToQuincena,
                loading: false,
                icon: Icons.event_available,
                label: 'Planear quincena',
                background: theme.colorScheme.primary,
                foreground: theme.colorScheme.onPrimary,
                iconSize: 22,
                fontSize: 13,
                radius: 14,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
