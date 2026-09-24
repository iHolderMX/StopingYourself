import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/responsive_helper.dart';
import '../../../models/quincena_expense.dart';
import '../application/money_error_message.dart';
import '../application/quincena_controller.dart';
import '../data/money_providers.dart';
import '../domain/salary_rules.dart';
import 'money_colors.dart';
import 'widgets/money_metric_tile.dart';
import 'widgets/salary_editor.dart';

/// Planificacion de los gastos de la proxima quincena.
class NextQuincenaCard extends ConsumerStatefulWidget {
  final bool summaryOnly;

  const NextQuincenaCard({
    super.key,
    this.summaryOnly = false,
  });

  @override
  ConsumerState<NextQuincenaCard> createState() => _NextQuincenaCardState();
}

class _NextQuincenaCardState extends ConsumerState<NextQuincenaCard> {
  bool _editingSalary = false;
  bool _saving = false;
  final _expenseNameController = TextEditingController();
  final _expenseAmountController = TextEditingController();
  int? _hoveredSectionIndex;

  @override
  void dispose() {
    _expenseNameController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addExpense(String userId) async {
    if (_saving) return;
    final amount = double.tryParse(_expenseAmountController.text.trim());
    if (amount == null) {
      _showMessage('Ingresa un monto valido.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(quincenaControllerProvider).addExpense(
        userId: userId,
        name: _expenseNameController.text,
        amount: amount,
      );
      if (!mounted) return;
      _expenseNameController.clear();
      _expenseAmountController.clear();
      _showMessage('Gasto agregado');
    } catch (error) {
      if (mounted) _showMessage(describeMoneyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteExpense(String userId, QuincenaExpense expense) async {
    try {
      await ref
          .read(quincenaControllerProvider)
          .deleteExpense(userId: userId, expenseId: expense.id);
    } catch (error) {
      if (mounted) _showMessage(describeMoneyError(error));
    }
  }

  Future<void> _resetExpenses(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reiniciar proxima quincena'),
        content: const Text(
          'Se borraran todos los gastos planeados de esta quincena. '
          'Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(quincenaControllerProvider).resetExpenses(userId);
      if (mounted) _showMessage('Gastos de la quincena reiniciados');
    } catch (error) {
      if (mounted) _showMessage(describeMoneyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final userId = ref.watch(currentUserIdProvider);

    if (userId == null) return const SizedBox.shrink();

    final totalDailyEarnings =
        ref.watch(totalDailyEarningsProvider(userId)).asData?.value ?? 0.0;

    return ref.watch(monthlySalaryProvider(userId)).when(
      loading: () => _placeholder(theme, r),
      error: (error, _) => _errorCard(theme, r, describeMoneyError(error)),
      data: (salary) {
        if (!SalaryRules.hasSalary(salary)) {
          return _missingSalary(theme, r, salary);
        }
        return ref.watch(quincenaExpensesProvider(userId)).when(
          loading: () => _placeholder(theme, r),
          error: (error, _) => _errorCard(theme, r, describeMoneyError(error)),
          data: (expenses) => _planning(
            theme,
            r,
            userId,
            salary,
            expenses,
            totalDailyEarnings,
          ),
        );
      },
    );
  }

  // ── Estados sin datos ──

  Widget _shell(ThemeData theme, ResponsiveHelper r, Widget child) {
    final neon = theme.colorScheme.primary;
    return Container(
      padding: EdgeInsets.all(r.padHorizontal),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [neon.withValues(alpha: 0.06), neon.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(r.borderRadius - 2),
        border: Border.all(color: neon.withValues(alpha: 0.15)),
      ),
      child: child,
    );
  }

  Widget _placeholder(ThemeData theme, ResponsiveHelper r) {
    return Container(
      padding: EdgeInsets.all(r.padHorizontal),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(r.borderRadius - 2),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            color: theme.colorScheme.primary,
            size: r.iconSizeMedium,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Proxima Quincena',
                  style: GoogleFonts.outfit(
                    fontSize: r.subtitleFontSize - 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Planifica tus gastos',
                  style: GoogleFonts.inter(
                    fontSize: r.bodyFontSize - 2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(ThemeData theme, ResponsiveHelper r, String message) {
    return Container(
      padding: EdgeInsets.all(r.padHorizontal),
      decoration: BoxDecoration(
        color: MoneyColors.negative.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(r.borderRadius - 2),
        border: Border.all(color: MoneyColors.negative.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: MoneyColors.negative,
            size: r.iconSizeMedium,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(fontSize: r.bodyFontSize - 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _missingSalary(ThemeData theme, ResponsiveHelper r, double salary) {
    final warn = MoneyColors.warning;

    return Container(
      padding: EdgeInsets.all(r.padHorizontal),
      decoration: BoxDecoration(
        color: warn.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(r.borderRadius - 2),
        border: Border.all(color: warn, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: warn,
                size: r.iconSizeMedium,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configura tu salario primero',
                      style: GoogleFonts.outfit(
                        fontSize: r.subtitleFontSize - 1,
                        fontWeight: FontWeight.w700,
                        color: warn,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Necesitas registrar tu salario mensual para poder '
                      'planificar tu proxima quincena.',
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 2,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: r.cardSpacing),
          if (_editingSalary)
            SalaryEditor(
              currentSalary: salary,
              saveLabel: 'Guardar salario',
              onFinished: () => setState(() => _editingSalary = false),
            )
          else
            FilledButton.icon(
              onPressed: () => setState(() => _editingSalary = true),
              style: FilledButton.styleFrom(backgroundColor: warn),
              icon: const Icon(Icons.attach_money),
              label: const Text('Configurar salario'),
            ),
        ],
      ),
    );
  }

  // ── Planificacion ──

  Widget _planning(
    ThemeData theme,
    ResponsiveHelper r,
    String userId,
    double salary,
    List<QuincenaExpense> expenses,
    double totalDailyEarnings,
  ) {
    final neon = theme.colorScheme.primary;
    final available = SalaryRules.quincenaAvailable(salary);
    final totalPlanned = SalaryRules.totalQuincenaPlanned(expenses);
    final remaining = available - totalPlanned;

    return _shell(
      theme,
      r,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available, color: neon, size: r.iconSizeMedium),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proxima Quincena',
                      style: GoogleFonts.outfit(
                        fontSize: r.subtitleFontSize,
                        fontWeight: FontWeight.w700,
                        color: neon,
                      ),
                    ),
                    Text(
                      'Organiza tus gastos de esta quincena',
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 2,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: r.cardSpacing),
          Wrap(
            spacing: r.cardSpacing - 4,
            runSpacing: r.cardSpacing - 4,
            children: [
              MoneyMetricTile(
                label: 'Disponible',
                value: '\$${available.toStringAsFixed(2)}',
                icon: Icons.account_balance_wallet_outlined,
                color: neon,
                responsive: r,
                width: 150,
              ),
              MoneyMetricTile(
                label: 'Gastos planeados',
                value: '\$${totalPlanned.toStringAsFixed(2)}',
                icon: Icons.receipt_long_outlined,
                color: theme.colorScheme.secondary,
                responsive: r,
                width: 150,
              ),
              MoneyMetricTile(
                label: 'Restante',
                value: '\$${remaining.toStringAsFixed(2)}',
                icon: Icons.savings_outlined,
                color: MoneyColors.forBalance(remaining),
                responsive: r,
                width: 150,
              ),
            ],
          ),
          SizedBox(height: r.cardSpacing + 6),
          _pieChart(theme, r, available, expenses, remaining, totalDailyEarnings),
          if (!widget.summaryOnly) ...[
            SizedBox(height: r.cardSpacing + 2),
            _chartLegend(theme, r, expenses, remaining, totalDailyEarnings, pieTotal: (SalaryRules.totalQuincenaPlanned(expenses) + (remaining > 0 ? remaining : 0))),
            SizedBox(height: r.cardSpacing + 6),
            _addExpenseForm(theme, r, userId),
            SizedBox(height: r.cardSpacing + 6),
            _expensesList(theme, r, userId, expenses),
          ],
        ],
      ),
    );
  }

  Widget _addExpenseForm(ThemeData theme, ResponsiveHelper r, String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Agregar gasto',
          style: GoogleFonts.outfit(
            fontSize: r.subtitleFontSize - 1,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: r.cardSpacing - 4),
        TextField(
          controller: _expenseNameController,
          enabled: !_saving,
          decoration: const InputDecoration(
            labelText: 'Nombre del gasto',
            hintText: 'Ej: Super, transporte, salidas',
            prefixIcon: Icon(Icons.label_outline),
          ),
        ),
        SizedBox(height: r.cardSpacing - 4),
        TextField(
          controller: _expenseAmountController,
          enabled: !_saving,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monto (\$)',
            hintText: '0.00',
            prefixIcon: Icon(Icons.attach_money),
          ),
          onSubmitted: (_) => _addExpense(userId),
        ),
        SizedBox(height: r.cardSpacing),
        SizedBox(
          height: r.buttonHeight,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : () => _addExpense(userId),
            icon: _saving
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.add),
            label: Text(_saving ? 'Agregando...' : 'Agregar gasto'),
          ),
        ),
      ],
    );
  }

  Widget _expensesList(
    ThemeData theme,
    ResponsiveHelper r,
    String userId,
    List<QuincenaExpense> expenses,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tus gastos (${expenses.length})',
          style: GoogleFonts.outfit(
            fontSize: r.subtitleFontSize - 1,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: r.cardSpacing - 4),
        if (expenses.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(r.borderRadius - 2),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Aun no agregas gastos para esta quincena.',
                    style: GoogleFonts.inter(
                      fontSize: r.bodyFontSize - 2,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          ...expenses.asMap().entries.map(
            (entry) => _expenseRow(theme, r, userId, entry.key, entry.value),
          ),
          SizedBox(height: r.cardSpacing),
          SizedBox(
            height: r.buttonHeight,
            child: OutlinedButton.icon(
              onPressed: () => _resetExpenses(userId),
              style: OutlinedButton.styleFrom(
                foregroundColor: MoneyColors.negative,
                side: BorderSide(
                  color: MoneyColors.negative.withValues(alpha: 0.5),
                ),
              ),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Reiniciar gastos de la quincena'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _expenseRow(
    ThemeData theme,
    ResponsiveHelper r,
    String userId,
    int index,
    QuincenaExpense expense,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: r.cardSpacing - 6),
      padding: EdgeInsets.symmetric(
        horizontal: r.cardSpacing - 2,
        vertical: r.cardSpacing - 6,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(r.borderRadius - 2),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: MoneyColors.chartColorAt(index),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              expense.name,
              style: GoogleFonts.inter(
                fontSize: r.bodyFontSize - 1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '\$${expense.amount.toStringAsFixed(2)}',
            style: GoogleFonts.outfit(
              fontSize: r.bodyFontSize,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: MoneyColors.negative,
            onPressed: () => _deleteExpense(userId, expense),
            tooltip: 'Eliminar gasto',
          ),
        ],
      ),
    );
  }

  String _yieldDaysLabel(double amount, double totalDailyEarnings) {
    if (totalDailyEarnings <= 0) return 'Sin rendimiento configurado';
    final days = amount / totalDailyEarnings;
    if (days >= 1) {
      return '${days.toStringAsFixed(1)} dias de rendimiento';
    }
    final hours = days * 24;
    if (hours >= 1) {
      return '${hours.toStringAsFixed(1)} horas de rendimiento';
    }
    final minutes = hours * 60;
    return '${minutes.toStringAsFixed(0)} min de rendimiento';
  }

  Widget _tooltipWidget(
    ThemeData theme,
    ResponsiveHelper r,
    String label,
    double amount,
    double pct,
    double totalDailyEarnings,
  ) {
    final yieldDays = _yieldDaysLabel(amount, totalDailyEarnings);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: r.bodyFontSize - 2,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${amount.toStringAsFixed(2)} (${pct.toStringAsFixed(1)}%)',
            style: GoogleFonts.inter(
              fontSize: r.bodyFontSize - 2,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 6),
          Text(
            'Equivale a:',
            style: GoogleFonts.inter(
              fontSize: r.bodyFontSize - 4,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            yieldDays,
            style: GoogleFonts.outfit(
              fontSize: r.bodyFontSize - 2,
              fontWeight: FontWeight.w700,
              color: MoneyColors.positive,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartLegend(
    ThemeData theme,
    ResponsiveHelper r,
    List<QuincenaExpense> expenses,
    double remaining,
    double totalDailyEarnings, {
    required double pieTotal,
  }) {
    if (expenses.isEmpty && remaining <= 0) {
      return const SizedBox.shrink();
    }
    final List<_LegendItem> items = [];
    for (var i = 0; i < expenses.length; i++) {
      items.add(_LegendItem(
        label: expenses[i].name,
        amount: expenses[i].amount,
        color: MoneyColors.chartColorAt(i),
        isRemaining: false,
      ));
    }
    if (remaining > 0) {
      items.add(_LegendItem(
        label: 'Restante',
        amount: remaining,
        color: MoneyColors.positive,
        isRemaining: true,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Desglose: toca un elemento para ver mas',
          style: GoogleFonts.inter(
            fontSize: r.bodyFontSize - 3,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: r.cardSpacing - 6),
        ...items.asMap().entries.map((entry) {
          final e = entry.value;
          final pct = pieTotal > 0 ? e.amount / pieTotal * 100 : 0.0;
          final yieldDays = _yieldDaysLabel(e.amount, totalDailyEarnings);
          final backgroundColor = e.isRemaining
              ? theme.colorScheme.primary.withValues(alpha: 0.06)
              : theme.colorScheme.surface;
          final borderColor = e.isRemaining
              ? MoneyColors.positive.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3);
          return Padding(
            padding: EdgeInsets.only(bottom: r.cardSpacing - 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showExpenseDetailSheet(
                  theme,
                  r,
                  e.label,
                  e.amount,
                  pct,
                  totalDailyEarnings,
                  e.color,
                ),
                borderRadius: BorderRadius.circular(r.borderRadius - 2),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.cardSpacing - 4,
                    vertical: r.cardSpacing - 6,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(r.borderRadius - 2),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: e.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e.label,
                              style: GoogleFonts.inter(
                                fontSize: r.bodyFontSize - 2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${e.amount.toStringAsFixed(2)}',
                                style: GoogleFonts.outfit(
                                  fontSize: r.bodyFontSize - 2,
                                  fontWeight: FontWeight.bold,
                                  color: e.color,
                                ),
                              ),
                              Text(
                                '${pct.toStringAsFixed(1)}%',
                                style: GoogleFonts.inter(
                                  fontSize: r.bodyFontSize - 4,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: r.cardSpacing - 8),
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 14,
                            color: MoneyColors.positive,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              yieldDays,
                              style: GoogleFonts.outfit(
                                fontSize: r.bodyFontSize - 3,
                                fontWeight: FontWeight.w600,
                                color: MoneyColors.positive,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _showExpenseDetailSheet(
    ThemeData theme,
    ResponsiveHelper r,
    String label,
    double amount,
    double pct,
    double totalDailyEarnings,
    Color accentColor,
  ) async {
    final yieldDays = _yieldDaysLabel(amount, totalDailyEarnings);
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(r.borderRadius),
            ),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          margin: EdgeInsets.only(
            top: 40,
            left: 8,
            right: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          padding: EdgeInsets.all(r.padHorizontal),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: r.cardSpacing),
              Container(
                padding: EdgeInsets.all(r.cardSpacing - 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(r.borderRadius - 2),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.outfit(
                          fontSize: r.titleFontSize - 2,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.cardSpacing + 4),
              Row(
                children: [
                  Expanded(
                    child: _metricBox(
                      theme,
                      r,
                      icon: Icons.attach_money,
                      label: 'Monto',
                      value: '\$${amount.toStringAsFixed(2)}',
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(width: r.cardSpacing - 4),
                  Expanded(
                    child: _metricBox(
                      theme,
                      r,
                      icon: Icons.pie_chart_outline,
                      label: 'Del total',
                      value: '${pct.toStringAsFixed(1)}%',
                      color: accentColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.cardSpacing + 2),
              Container(
                padding: EdgeInsets.all(r.cardSpacing),
                decoration: BoxDecoration(
                  color: MoneyColors.positive.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(r.borderRadius - 2),
                  border: Border.all(color: MoneyColors.positive.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          size: 18,
                          color: MoneyColors.positive,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Equivalencia en rendimiento',
                            style: GoogleFonts.inter(
                              fontSize: r.bodyFontSize - 1,
                              fontWeight: FontWeight.w600,
                              color: MoneyColors.positive,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: r.cardSpacing - 4),
                    Text(
                      'Gastar \$${amount.toStringAsFixed(2)} equivale a perder el rendimiento de:',
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 2,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    SizedBox(height: r.cardSpacing - 6),
                    Text(
                      yieldDays,
                      style: GoogleFonts.outfit(
                        fontSize: r.titleFontSize - 2,
                        fontWeight: FontWeight.bold,
                        color: MoneyColors.positive,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.cardSpacing + 4),
              SizedBox(
                height: r.buttonHeight,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check),
                  label: const Text('Entendido'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metricBox(
    ThemeData theme,
    ResponsiveHelper r, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.cardSpacing - 4,
        vertical: r.cardSpacing - 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(r.borderRadius - 2),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize - 3,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: r.cardSpacing - 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: r.bodyFontSize,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pieChart(
    ThemeData theme,
    ResponsiveHelper r,
    double available,
    List<QuincenaExpense> expenses,
    double remaining,
    double totalDailyEarnings,
  ) {
    final sections = <PieChartSectionData>[];
    final ringRadius = r.isDesktop ? 60.0 : 48.0;

    final expensesTotal = SalaryRules.totalQuincenaPlanned(expenses);
    final pieTotal = expensesTotal + (remaining > 0 ? remaining : 0);

    final sectionLabels = <String>[];
    final sectionAmounts = <double>[];
    final sectionColors = <Color>[];

    if (expenses.isEmpty && remaining <= 0) {
      sections.add(
        PieChartSectionData(
          color: MoneyColors.positive,
          value: available > 0 ? available : 1,
          radius: ringRadius,
          showTitle: false,
        ),
      );
      sectionLabels.add('Disponible');
      sectionAmounts.add(available > 0 ? available : 1);
      sectionColors.add(MoneyColors.positive);
    } else {
      for (var i = 0; i < expenses.length; i++) {
        final expense = expenses[i];
        final amount = expense.amount;
        final pct = pieTotal > 0 ? amount / pieTotal * 100 : 0.0;
        final color = MoneyColors.chartColorAt(i);
        final isHovered = _hoveredSectionIndex == i;
        sections.add(
          PieChartSectionData(
            color: color,
            value: amount,
            radius: ringRadius + (isHovered ? 6 : 0),
            showTitle: pct >= 8,
            title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
            titlePositionPercentageOffset: 0.6,
            titleStyle: TextStyle(
              fontSize: r.bodyFontSize - 3,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
        sectionLabels.add(expense.name);
        sectionAmounts.add(amount);
        sectionColors.add(color);
      }

      if (remaining > 0) {
        final remainingIdx = expenses.length;
        final isHovered = _hoveredSectionIndex == remainingIdx;
        sections.add(
          PieChartSectionData(
            color: MoneyColors.positive,
            value: remaining,
            radius: ringRadius + (isHovered ? 6 : 0),
            showTitle: false,
          ),
        );
        sectionLabels.add('Restante');
        sectionAmounts.add(remaining);
        sectionColors.add(MoneyColors.positive);
      }
    }

    final chartSize = r.isDesktop ? 220.0 : 180.0;
    final hoveredIdx = _hoveredSectionIndex;
    final isTouchDevice = !r.isDesktop;

    void onSectionTapped(int idx) {
      if (idx < 0 || idx >= sectionLabels.length) return;
      _showExpenseDetailSheet(
        theme,
        r,
        sectionLabels[idx],
        sectionAmounts[idx],
        pieTotal > 0 ? sectionAmounts[idx] / pieTotal * 100 : 0,
        totalDailyEarnings,
        sectionColors[idx],
      );
    }

    return Center(
      child: SizedBox(
        width: chartSize,
        height: chartSize,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: r.isDesktop ? 36 : 30,
                sectionsSpace: 3,
                startDegreeOffset: -90,
                pieTouchData: PieTouchData(
                  enabled: true,
                  touchCallback: (event, response) {
                    final idx = response?.touchedSection?.touchedSectionIndex;
                    if (event is FlPointerHoverEvent) {
                      if (idx != null && idx >= 0 && idx < sectionLabels.length) {
                        if (_hoveredSectionIndex != idx) {
                          setState(() => _hoveredSectionIndex = idx);
                        }
                      } else {
                        if (_hoveredSectionIndex != null) {
                          setState(() => _hoveredSectionIndex = null);
                        }
                      }
                    } else if (event is FlPointerExitEvent) {
                      if (_hoveredSectionIndex != null) {
                        setState(() => _hoveredSectionIndex = null);
                      }
                    } else if (event is FlTapUpEvent) {
                      if (idx != null && idx >= 0 && idx < sectionLabels.length) {
                        if (isTouchDevice) {
                          onSectionTapped(idx);
                        } else {
                          setState(() => _hoveredSectionIndex = idx);
                          onSectionTapped(idx);
                        }
                      }
                    }
                  },
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Restante',
                  style: GoogleFonts.inter(
                    fontSize: r.bodyFontSize - 2,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  '\$${remaining.toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    fontSize: r.isDesktop ? 22 : 16,
                    fontWeight: FontWeight.bold,
                    color: MoneyColors.forBalance(remaining),
                  ),
                ),
              ],
            ),
            if (!isTouchDevice &&
                hoveredIdx != null &&
                hoveredIdx >= 0 &&
                hoveredIdx < sectionLabels.length)
              Positioned(
                top: -8,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Transform.translate(
                      offset: const Offset(0, -100),
                      child: _tooltipWidget(
                        theme,
                        r,
                        sectionLabels[hoveredIdx],
                        sectionAmounts[hoveredIdx],
                        pieTotal > 0
                            ? sectionAmounts[hoveredIdx] / pieTotal * 100
                            : 0,
                        totalDailyEarnings,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem {
  final String label;
  final double amount;
  final Color color;
  final bool isRemaining;

  _LegendItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.isRemaining,
  });
}
