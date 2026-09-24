import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../application/finance_reset_controller.dart';
import '../application/money_error_message.dart';
import '../data/money_providers.dart';
import '../domain/salary_rules.dart';
import 'debts_content.dart';
import 'emergency_fund_content.dart';
import 'finance_charts.dart';
import 'fixed_expenses_content.dart';
import 'money_colors.dart';
import 'money_tracking_screen.dart';
import 'next_quincena_card.dart';
import 'salary_summary_card.dart';
import 'saving_goals_content.dart';

class FinanceHubScreen extends ConsumerStatefulWidget {
  const FinanceHubScreen({super.key});

  @override
  ConsumerState<FinanceHubScreen> createState() => _FinanceHubScreenState();
}

class _FinanceHubScreenState extends ConsumerState<FinanceHubScreen> {
  bool _compactMode = false;
  bool _summaryExpanded = false;
  bool _resetting = false;
  bool _isDetailedView = true;

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
            style: FilledButton.styleFrom(
              backgroundColor: MoneyColors.negative,
            ),
            child: const Text('Reiniciar todo'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _resetting = true);
    try {
      // El controller sabe que refrescar: antes eran nueve ref.invalidate
      // escritos a mano aqui, con providers de cinco archivos distintos.
      await ref.read(financeResetControllerProvider).resetAll(user.id);
      // Estas pantallas aun declaran sus propios providers locales; hasta que
      // se migren hay que refrescarlos a mano. El controller ya refresco los
      // providers centrales (movimientos, salario, quincena, fondos).
      ref.invalidate(debtsProvider(user.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Finanzas reiniciadas correctamente')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeMoneyError(error))));
      }
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  /// Boton para reiniciar todas las finanzas.
  ///
  /// Vive dentro del flujo de la pagina, no superpuesto: como boton flotante
  /// tapaba las tarjetas al hacer scroll y competia con el menu de la barra
  /// lateral. Conserva el estado de carga para que no se pueda disparar dos
  /// veces mientras corre el borrado.
  Widget _resetButton(ResponsiveHelper r) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: _resetting ? null : _resetAllFinances,
        style: OutlinedButton.styleFrom(
          foregroundColor: MoneyColors.negative,
          side: BorderSide(
            color: MoneyColors.negative.withValues(alpha: 0.5),
            width: 1.5,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: r.cardSpacing,
            vertical: r.cardSpacing - 6,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.borderRadius - 2),
          ),
        ),
        icon: _resetting
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: MoneyColors.negative,
                ),
              )
            : const Icon(Icons.restart_alt, size: 20),
        label: Text(
          _resetting ? 'Reiniciando...' : 'Reiniciar finanzas',
          style: GoogleFonts.inter(
            fontSize: r.bodyFontSize - 1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Boton toggle para cambiar entre vista detallada y resumida.
  Widget _viewToggleButton(ThemeData theme, ResponsiveHelper r) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(r.borderRadius - 2),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(r.borderRadius - 2),
          onTap: () => setState(() => _isDetailedView = !_isDetailedView),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: r.cardSpacing - 4,
              vertical: r.cardSpacing - 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isDetailedView
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _isDetailedView ? 'Vista detallada' : 'Vista resumida',
                  style: GoogleFonts.inter(
                    fontSize: r.bodyFontSize - 1,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
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
        ? ref.watch(totalSavedProvider(userId))
        : null;
    final totalDaily = userId != null
        ? ref.watch(totalDailyEarningsProvider(userId))
        : null;
    final totalFixed = userId != null
        ? ref.watch(totalFixedExpensesProvider(userId))
        : null;

    final saved = totalSaved?.asData?.value ?? 0;
    final daily = totalDaily?.asData?.value ?? 0;
    final fixed = totalFixed?.asData?.value ?? 0;
    final monthlySalary = userId != null
        ? ref.watch(monthlySalaryProvider(userId)).asData?.value ?? 0
        : 0.0;

    final salaryCard = SalarySummaryCard(
      totalSaved: saved,
      totalDailyEarnings: daily,
      totalFixedExpenses: fixed,
    );

    final charts = FinanceCharts(
      totalSaved: saved,
      totalFixedExpenses: fixed,
      totalDailyEarnings: daily,
      monthlySalary: monthlySalary,
    );

    if (r.isDesktop) {
      return SingleChildScrollView(
        padding: EdgeInsets.only(bottom: r.padVertical),
        child: Column(
          children: [
            // Fila con botones de accion
            Padding(
              padding: EdgeInsets.only(
                left: r.padHorizontal,
                right: r.padHorizontal,
                top: r.padVertical,
              ),
              child: Row(
                children: [
                  _resetButton(r),
                  const Spacer(),
                  _viewToggleButton(theme, r),
                ],
              ),
            ),
            SizedBox(height: r.cardSpacing),
            // Header: salary card + toggle de modo compacto
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.padHorizontal),
              child: Stack(
                children: [
                  salaryCard,
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(r.borderRadius - 2),
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
                        onPressed: _isDetailedView
                            ? () => setState(() => _compactMode = !_compactMode)
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.cardSpacing),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.padHorizontal),
              child: NextQuincenaCard(summaryOnly: !_isDetailedView),
            ),
            if (_isDetailedView) ...[
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
            ] else ...[
              // Vista resumida: Fondo de emergencia + graficas comparativas
              SizedBox(height: r.cardSpacing),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.padHorizontal),
                child: const EmergencyFundContent(compact: false),
              ),
              SizedBox(height: r.cardSpacing),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.padHorizontal),
                child: charts,
              ),
            ],
          ],
        ),
      );
    }

    // Mobile / Tablet: todo en scroll simple, sin headers fijos
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: r.padHorizontal,
        right: r.padHorizontal,
        top: r.padVertical + 8,
        bottom: r.padVertical + 24,
      ),
      child: Column(
        children: [
          // Acciones: reinicio + toggle de vista
          Row(
            children: [
              Expanded(child: _resetButton(r)),
              SizedBox(width: r.cardSpacing - 4),
              _viewToggleButton(theme, r),
            ],
          ),
          SizedBox(height: r.cardSpacing),
          // Barra colapsable para el resumen financiero
          GestureDetector(
            onTap: () => setState(() => _summaryExpanded = !_summaryExpanded),
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
                      '\$${SalaryRules.quincenaAvailable(monthlySalary).toStringAsFixed(0)} '
                      'libres',
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 2,
                        color: MoneyColors.positive,
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
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          SizedBox(height: r.cardSpacing + 4),
          NextQuincenaCard(summaryOnly: !_isDetailedView),
          if (_isDetailedView) ...[
            SizedBox(height: r.cardSpacing + 8),
            // Secciones de contenido, todas scrolleables
            const MoneyTrackingScreen(compact: false),
            SizedBox(height: r.cardSpacing + 8),
            const FixedExpensesContent(compact: false),
            SizedBox(height: r.cardSpacing + 8),
            DebtsContent(compact: false, totalSaved: saved),
            SizedBox(height: r.cardSpacing + 8),
            const SavingGoalsContent(compact: false),
          ],
          SizedBox(height: r.cardSpacing + 8),
          // Fondo de emergencia: visible en AMBAS vistas
          const EmergencyFundContent(compact: false),
          SizedBox(height: r.cardSpacing + 8),
          charts,
        ],
      ),
    );
  }
}
