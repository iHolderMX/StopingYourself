import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/money_record.dart';
import '../../../models/fixed_expense.dart';

class FinanceCharts extends StatelessWidget {
  final List<MoneyRecord> moneyRecords;
  final List<FixedExpense> fixedExpenses;
  final double totalSaved;
  final double totalFixedExpenses;
  final double totalDailyEarnings;
  final double monthlySalary;

  const FinanceCharts({
    super.key,
    required this.moneyRecords,
    required this.fixedExpenses,
    required this.totalSaved,
    required this.totalFixedExpenses,
    required this.totalDailyEarnings,
    required this.monthlySalary,
  });

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveHelper(context);
    final theme = Theme.of(context);

    // Solo tonos azul neon del tema
    final c1 = theme.colorScheme.primary; // neon
    final c2 = theme.colorScheme.secondary; // neon bright
    final c3 = theme.colorScheme.tertiary; // neon dim
    final c5 = theme.colorScheme.primary.withValues(alpha: 0.3);

    final annualYield = totalDailyEarnings * 365;
    final salary = monthlySalary;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Graficas Comparativas',
            style: GoogleFonts.outfit(
              fontSize: r.titleFontSize,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Visualiza tus finanzas vs tu sueldo.',
            style: GoogleFonts.inter(
              fontSize: r.subtitleFontSize,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: r.cardSpacing + 4),

          LayoutBuilder(
            builder: (context, constraints) {
              final chartH =
                  r.isDesktop ? 280.0 : (r.isTablet ? 260.0 : 220.0);

              return Column(
                children: [
                  // Grafica 1: Sueldo vs Gastos fijos (Donut)
                  SizedBox(
                    width: constraints.maxWidth,
                    height: chartH,
                    child: _ChartCard(
                      title: 'Tu sueldo vs gastos fijos',
                      subtitle: salary > 0
                          ? '${(totalFixedExpenses / salary * 100).toStringAsFixed(1)}% se va en gastos fijos'
                          : null,
                      theme: theme,
                      child: _DonutComparison(
                        labelA: 'Gastos fijos',
                        valueA: totalFixedExpenses,
                        colorA: c1,
                        labelB: 'Disponible',
                        valueB:
                            (salary - totalFixedExpenses).clamp(0, double.infinity),
                        colorB: c5,
                        r: r,
                      ),
                    ),
                  ),
                  SizedBox(height: r.cardSpacing - 4),

                  // Grafica 2: Rendimiento anual vs Sueldo (Barras)
                  SizedBox(
                    width: constraints.maxWidth,
                    height: chartH,
                    child: _ChartCard(
                      title: 'Rendimiento anual vs Sueldo',
                      subtitle: salary > 0
                          ? 'Tu rendimiento anual = ${(annualYield / salary * 100).toStringAsFixed(1)}% de tu sueldo'
                          : null,
                      theme: theme,
                      child: _ComparisonBarChart(
                        items: [
                          ('Sueldo\nmensual', salary, c1),
                          ('Rendimiento\nanual', annualYield, c2),
                          ('Gastos\nfijos', totalFixedExpenses, c3),
                        ],
                        r: r,
                        theme: theme,
                      ),
                    ),
                  ),
                  SizedBox(height: r.cardSpacing - 4),

                  // Grafica 3: Ahorro total vs Sueldo (Donut)
                  SizedBox(
                    width: constraints.maxWidth,
                    height: chartH,
                    child: _ChartCard(
                      title: 'Ahorro total vs sueldo mensual',
                      subtitle: salary > 0
                          ? '${(totalSaved / salary).toStringAsFixed(1)} meses de sueldo ahorrados'
                          : null,
                      theme: theme,
                      child: _DonutComparison(
                        labelA: 'Ahorro total',
                        valueA: totalSaved,
                        colorA: c1,
                        labelB: 'Sueldo mensual',
                        valueB: salary,
                        colorB: c5,
                        r: r,
                        showCenterTotal: true,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
class _DonutComparison extends StatelessWidget {
  final String labelA;
  final double valueA;
  final Color colorA;
  final String labelB;
  final double valueB;
  final Color colorB;
  final ResponsiveHelper r;
  final bool showCenterTotal;

  const _DonutComparison({
    required this.labelA,
    required this.valueA,
    required this.colorA,
    required this.labelB,
    required this.valueB,
    required this.colorB,
    required this.r,
    this.showCenterTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = valueA + valueB;
    final sections = <PieChartSectionData>[];

    if (valueA > 0) {
      final pctA = total > 0 ? (valueA / total * 100) : 0.0;
      sections.add(PieChartSectionData(
        color: colorA,
        value: valueA,
        title: pctA >= 10 ? '${pctA.toStringAsFixed(0)}%' : '',
        radius: r.isDesktop ? 70 : 55,
        titleStyle: TextStyle(
          fontSize: r.bodyFontSize - 3,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onPrimary,
        ),
      ));
    }
    if (valueB > 0) {
      final pctB = total > 0 ? (valueB / total * 100) : 0.0;
      sections.add(PieChartSectionData(
        color: colorB,
        value: valueB,
        title: pctB >= 10 ? '${pctB.toStringAsFixed(0)}%' : '',
        radius: r.isDesktop ? 70 : 55,
        titleStyle: TextStyle(
          fontSize: r.bodyFontSize - 3,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ));
    }

    if (sections.isEmpty) return _EmptyChart(r: r, theme: theme);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(PieChartData(
                  sections: sections,
                  centerSpaceRadius: r.isDesktop ? 34 : 26,
                  sectionsSpace: 2,
                )),
                if (showCenterTotal)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${(valueA / 1000).toStringAsFixed(1)}k',
                        style: GoogleFonts.outfit(
                          fontSize: r.isDesktop ? 16 : 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'ahorrado',
                        style: GoogleFonts.inter(
                          fontSize: r.bodyFontSize - 4,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Legend(color: colorA, label: labelA, amount: valueA, r: r),
                const SizedBox(height: 8),
                _Legend(color: colorB, label: labelB, amount: valueB, r: r),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final double amount;
  final ResponsiveHelper r;

  const _Legend({
    required this.color,
    required this.label,
    required this.amount,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                    fontSize: r.bodyFontSize - 3,
                    fontWeight: FontWeight.w500,
                  )),
              Text(
                '\$${amount.toStringAsFixed(0)}',
                style: GoogleFonts.outfit(
                  fontSize: r.bodyFontSize - 2,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
class _ComparisonBarChart extends StatelessWidget {
  final List<(String, double, Color)> items;
  final ResponsiveHelper r;
  final ThemeData theme;

  const _ComparisonBarChart({
    required this.items,
    required this.r,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final maxY =
        items.map((e) => e.$2).reduce((a, b) => a > b ? a : b) * 1.2;
    if (maxY == 0) return _EmptyChart(r: r, theme: theme);

    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 16, left: 4),
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barGroups: List.generate(items.length, (i) {
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: items[i].$2,
              color: items[i].$3,
              width: r.isDesktop ? 36 : 24,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
          ]);
        }),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= items.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(items[idx].$1,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 3,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      )),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              getTitlesWidget: (value, meta) {
                final v = value.toInt();
                final txt =
                    v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : '$v';
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text('\$$txt',
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 4,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      )),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 5,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '\$${rod.toY.toStringAsFixed(2)}',
                GoogleFonts.inter(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: r.bodyFontSize - 2,
                ),
              );
            },
          ),
        ),
      )),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final ThemeData theme;

  const _ChartCard({
    required this.title,
    this.subtitle,
    required this.child,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              )),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                )),
          ],
          const SizedBox(height: 4),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final ResponsiveHelper r;
  final ThemeData theme;

  const _EmptyChart({required this.r, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined,
              size: r.iconSizeMedium,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
          const SizedBox(height: 6),
          Text('Sin datos',
              style: GoogleFonts.inter(
                fontSize: r.bodyFontSize - 2,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              )),
        ],
      ),
    );
  }
}
