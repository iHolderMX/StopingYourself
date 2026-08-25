import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/responsive_helper.dart';
import '../data/money_providers.dart';
import '../domain/salary_rules.dart';
import 'widgets/money_metric_tile.dart';
import 'widgets/salary_editor.dart';

/// Tarjeta de resumen del salario y las metricas que se derivan de el.
///
/// Solo presenta: los porcentajes y equivalencias los calcula `SalaryRules`,
/// asi que aqui no hay ninguna division que pueda producir `NaN`.
class SalarySummaryCard extends ConsumerStatefulWidget {
  const SalarySummaryCard({
    super.key,
    required this.totalSaved,
    required this.totalDailyEarnings,
    required this.totalFixedExpenses,
  });

  final double totalSaved;
  final double totalDailyEarnings;
  final double totalFixedExpenses;

  @override
  ConsumerState<SalarySummaryCard> createState() => _SalarySummaryCardState();
}

class _SalarySummaryCardState extends ConsumerState<SalarySummaryCard> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final userId = ref.watch(currentUserIdProvider);

    final salary = userId == null
        ? 0.0
        : ref.watch(monthlySalaryProvider(userId)).asData?.value ?? 0.0;
    final hasSalary = SalaryRules.hasSalary(salary);

    final neon = theme.colorScheme.primary;

    return Container(
      margin: EdgeInsets.only(bottom: r.cardSpacing + 6),
      padding: EdgeInsets.all(r.cardSpacing + 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [neon.withValues(alpha: 0.06), neon.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(r.borderRadius + 4),
        border: Border.all(color: neon.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(theme, r, neon, hasSalary),
          if (_editing) ...[
            SizedBox(height: r.cardSpacing - 4),
            SalaryEditor(
              currentSalary: salary,
              onFinished: () => setState(() => _editing = false),
            ),
          ] else ...[
            SizedBox(height: r.cardSpacing - 4),
            if (!hasSalary)
              _missingSalaryHint(r, neon)
            else
              _metrics(theme, r, salary),
          ],
        ],
      ),
    );
  }

  Widget _header(
    ThemeData theme,
    ResponsiveHelper r,
    Color neon,
    bool hasSalary,
  ) {
    return Row(
      children: [
        Icon(Icons.work_outline, color: neon, size: r.iconSizeMedium - 2),
        const SizedBox(width: 10),
        Text(
          'Salario Mensual',
          style: GoogleFonts.outfit(
            fontSize: r.subtitleFontSize + 2,
            fontWeight: FontWeight.w600,
            color: neon,
          ),
        ),
        const Spacer(),
        if (!_editing)
          IconButton(
            icon: Icon(Icons.edit_outlined, color: neon, size: 20),
            onPressed: () => setState(() => _editing = true),
            tooltip: hasSalary ? 'Editar salario' : 'Configurar salario',
          ),
      ],
    );
  }

  Widget _missingSalaryHint(ResponsiveHelper r, Color neon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: neon.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.info_outline, color: neon, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Configura tu salario para ver las metricas',
              style: GoogleFonts.inter(
                fontSize: r.bodyFontSize - 1,
                color: neon,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metrics(ThemeData theme, ResponsiveHelper r, double salary) {
    final neon = theme.colorScheme.primary;
    final neonDim = theme.colorScheme.tertiary;

    final savedPercent = SalaryRules.percentOfSalary(
      amount: widget.totalSaved,
      monthlySalary: salary,
    );
    final savedDays = SalaryRules.daysOfSalaryCovered(
      amount: widget.totalSaved,
      monthlySalary: salary,
    );
    final savedMonths = SalaryRules.monthsOfSalaryCovered(
      amount: widget.totalSaved,
      monthlySalary: salary,
    );
    final earningsPercent = SalaryRules.dailyEarningsAsPercentOfDailySalary(
      dailyEarnings: widget.totalDailyEarnings,
      monthlySalary: salary,
    );
    final fixedPercent = SalaryRules.percentOfSalary(
      amount: widget.totalFixedExpenses,
      monthlySalary: salary,
    );
    final remaining = SalaryRules.salaryAfterFixedExpenses(
      monthlySalary: salary,
      totalFixedExpenses: widget.totalFixedExpenses,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.cardSpacing),
        Wrap(
          spacing: r.cardSpacing - 4,
          runSpacing: r.cardSpacing - 4,
          children: [
            MoneyMetricTile(
              icon: Icons.savings_outlined,
              label: 'Ahorro total',
              value: '\$${widget.totalSaved.toStringAsFixed(2)}',
              subtitle: _percentText(savedPercent, 'de tu salario'),
              color: neon,
              responsive: r,
            ),
            MoneyMetricTile(
              icon: Icons.calendar_today,
              label: 'Dias de salario ahorrados',
              value: savedDays == null
                  ? '-'
                  : '${savedDays.toStringAsFixed(1)} dias',
              subtitle: savedMonths == null
                  ? '-'
                  : '${savedMonths.toStringAsFixed(1)} meses de salario',
              color: neonDim,
              responsive: r,
            ),
            MoneyMetricTile(
              icon: Icons.trending_up,
              label: 'Rendimiento diario',
              value: '\$${widget.totalDailyEarnings.toStringAsFixed(4)}',
              subtitle: earningsPercent == null
                  ? '-'
                  : 'Equivale a ${earningsPercent.toStringAsFixed(2)}% '
                        'de 1 dia de salario',
              color: neon,
              responsive: r,
            ),
            MoneyMetricTile(
              icon: Icons.receipt_long_outlined,
              label: 'Gastos fijos mensuales',
              value: '\$${widget.totalFixedExpenses.toStringAsFixed(2)}',
              subtitle: _percentText(fixedPercent, 'de tu salario'),
              color: neonDim,
              responsive: r,
            ),
            MoneyMetricTile(
              icon: Icons.account_balance_wallet,
              label: 'Salario restante',
              value: '\$${remaining.toStringAsFixed(2)}',
              subtitle: 'Despues de gastos fijos',
              color: remaining < 0 ? theme.colorScheme.error : neon,
              responsive: r,
            ),
            MoneyMetricTile(
              icon: Icons.pie_chart_outline,
              label: '% de ahorro vs salario',
              value: savedPercent == null
                  ? '-'
                  : '${savedPercent.toStringAsFixed(1)}%',
              subtitle: 'De tu salario mensual',
              color: neonDim,
              responsive: r,
            ),
          ],
        ),
      ],
    );
  }

  String _percentText(double? percent, String suffix) =>
      percent == null ? '-' : '${percent.toStringAsFixed(1)}% $suffix';
}
