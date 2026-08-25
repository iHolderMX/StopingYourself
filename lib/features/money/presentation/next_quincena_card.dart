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
  const NextQuincenaCard({super.key});

  @override
  ConsumerState<NextQuincenaCard> createState() => _NextQuincenaCardState();
}

class _NextQuincenaCardState extends ConsumerState<NextQuincenaCard> {
  bool _editingSalary = false;
  bool _saving = false;
  final _expenseNameController = TextEditingController();
  final _expenseAmountController = TextEditingController();

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

    // Se resuelve el salario primero: sin el no hay quincena que planear.
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
          data: (expenses) => _planning(theme, r, userId, salary, expenses),
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
          _pieChart(theme, r, available, expenses, remaining),
          SizedBox(height: r.cardSpacing + 6),
          _addExpenseForm(theme, r, userId),
          SizedBox(height: r.cardSpacing + 6),
          _expensesList(theme, r, userId, expenses),
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

  Widget _pieChart(
    ThemeData theme,
    ResponsiveHelper r,
    double available,
    List<QuincenaExpense> expenses,
    double remaining,
  ) {
    final sections = <PieChartSectionData>[];
    final ringRadius = r.isDesktop ? 60.0 : 48.0;

    final expensesTotal = SalaryRules.totalQuincenaPlanned(expenses);
    final pieTotal = expensesTotal + (remaining > 0 ? remaining : 0);

    if (expenses.isEmpty && remaining <= 0) {
      sections.add(
        PieChartSectionData(
          color: MoneyColors.positive,
          value: available > 0 ? available : 1,
          radius: ringRadius,
          showTitle: false,
        ),
      );
    } else {
      for (var i = 0; i < expenses.length; i++) {
        final amount = expenses[i].amount;
        final pct = pieTotal > 0 ? amount / pieTotal * 100 : 0.0;
        sections.add(
          PieChartSectionData(
            color: MoneyColors.chartColorAt(i),
            value: amount,
            radius: ringRadius,
            // Debajo del 8% la etiqueta no cabe dentro del anillo.
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
      }

      if (remaining > 0) {
        sections.add(
          PieChartSectionData(
            color: MoneyColors.positive,
            value: remaining,
            radius: ringRadius,
            showTitle: false,
          ),
        );
      }
    }

    final chartSize = r.isDesktop ? 220.0 : 180.0;

    return Center(
      child: SizedBox(
        width: chartSize,
        height: chartSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: r.isDesktop ? 36 : 30,
                sectionsSpace: 3,
                startDegreeOffset: -90,
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
          ],
        ),
      ),
    );
  }
}
