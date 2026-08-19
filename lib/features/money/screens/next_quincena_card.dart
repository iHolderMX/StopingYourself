import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/quincena_expense.dart';
import '../../../models/salary_setting.dart';
import 'salary_summary_card.dart' show salarySettingProvider;

final quincenaExpensesProvider =
    FutureProvider.family<List<QuincenaExpense>, String>(
  (ref, userId) => ref.watch(databaseServiceProvider).getQuincenaExpenses(userId),
);

const _quincenaPalette = <Color>[
  Color(0xFF42A5F5), // azul
  Color(0xFFEF5350), // rojo
  Color(0xFFFFA726), // naranja
  Color(0xFFAB47BC), // púrpura
  Color(0xFF26A69A), // teal
  Color(0xFFEC407A), // rosa
  Color(0xFF7E57C2), // morado
  Color(0xFFFFCA28), // ámbar
  Color(0xFF5C6BC0), // índigo
  Color(0xFF8D6E63), // marrón
];

class NextQuincenaCard extends ConsumerStatefulWidget {
  const NextQuincenaCard({super.key});

  @override
  ConsumerState<NextQuincenaCard> createState() => _NextQuincenaCardState();
}

class _NextQuincenaCardState extends ConsumerState<NextQuincenaCard> {
  bool _editingSalary = false;
  bool _saving = false;
  final _salaryController = TextEditingController();
  final _expenseNameController = TextEditingController();
  final _expenseAmountController = TextEditingController();

  @override
  void dispose() {
    _salaryController.dispose();
    _expenseNameController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  Future<void> _saveSalary() async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;
    final salary = double.tryParse(_salaryController.text.trim());
    if (salary == null || salary <= 0) return;

    final setting = SalarySetting(userId: user.id, monthlySalary: salary);
    await ref.read(databaseServiceProvider).upsertSalary(setting);
    ref.invalidate(salarySettingProvider(user.id));
    if (mounted) {
      setState(() => _editingSalary = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Salario configurado')));
    }
  }

  Future<void> _addExpense() async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;
    final name = _expenseNameController.text.trim();
    final amount = double.tryParse(_expenseAmountController.text.trim());
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Escribe un nombre')));
      return;
    }
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa un monto valido')));
      return;
    }

    setState(() => _saving = true);
    final expense = QuincenaExpense(
      id: '${user.id}_${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      name: name,
      amount: amount,
    );
    await ref.read(databaseServiceProvider).insertQuincenaExpense(expense);
    ref.invalidate(quincenaExpensesProvider(user.id));
    if (mounted) {
      setState(() {
        _saving = false;
        _expenseNameController.clear();
        _expenseAmountController.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gasto agregado')));
    }
  }

  Future<void> _deleteExpense(QuincenaExpense expense) async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;
    await ref.read(databaseServiceProvider).deleteQuincenaExpense(expense.id);
    ref.invalidate(quincenaExpensesProvider(user.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final salaryAsync = user != null
        ? ref.watch(salarySettingProvider(user.id))
        : null;
    final salary = salaryAsync?.asData?.value?.monthlySalary ?? 0;
    final hasSalary = salary > 0;

    if (salaryAsync?.isLoading ?? false) {
      return _buildPlaceholder(theme, r);
    }

    if (!hasSalary) {
      return _buildMissingSalary(theme, r);
    }

    final expensesAsync = user != null
        ? ref.watch(quincenaExpensesProvider(user.id))
        : null;
    final expenses = expensesAsync?.asData?.value ?? [];

    return _buildPlanning(theme, r, salary, expenses);
  }

  Widget _buildMissingSalary(ThemeData theme, ResponsiveHelper r) {
    final warn = Colors.amber.shade700;

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
                      'planificar tu próxima quincena.',
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 2,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_editingSalary) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _salaryController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Salario mensual (\$)',
                hintText: '0.00',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _saveSalary(),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _editingSalary = false),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _saveSalary,
                  icon: const Icon(Icons.check),
                  label: const Text('Guardar salario'),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => setState(() => _editingSalary = true),
              style: FilledButton.styleFrom(backgroundColor: warn),
              icon: const Icon(Icons.attach_money),
              label: const Text('Configurar salario'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanning(
    ThemeData theme,
    ResponsiveHelper r,
    double salary,
    List<QuincenaExpense> expenses,
  ) {
    final neon = theme.colorScheme.primary;
    final available = salary / 2;
    final totalPlanned = expenses.fold<double>(
      0,
      (sum, e) => sum + e.amount,
    );
    final remaining = available - totalPlanned;
    final remainingColor = remaining >= 0
        ? Colors.green.shade400
        : Colors.redAccent;

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
      child: Column(
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
                      'Próxima Quincena',
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

          // Resumen: disponible, planeado, restante
          Wrap(
            spacing: r.cardSpacing - 4,
            runSpacing: r.cardSpacing - 4,
            children: [
              _StatTile(
                label: 'Disponible',
                value: '\$${available.toStringAsFixed(2)}',
                icon: Icons.account_balance_wallet_outlined,
                color: neon,
                r: r,
              ),
              _StatTile(
                label: 'Gastos planeados',
                value: '\$${totalPlanned.toStringAsFixed(2)}',
                icon: Icons.receipt_long_outlined,
                color: theme.colorScheme.secondary,
                r: r,
              ),
              _StatTile(
                label: 'Restante',
                value: '\$${remaining.toStringAsFixed(2)}',
                icon: Icons.savings_outlined,
                color: remainingColor,
                r: r,
              ),
            ],
          ),

          SizedBox(height: r.cardSpacing + 6),

          _buildPieChart(theme, r, available, expenses, remaining),

          SizedBox(height: r.cardSpacing + 6),

          // Formulario para agregar gasto
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
            decoration: const InputDecoration(
              labelText: 'Nombre del gasto',
              hintText: 'Ej: Super, transporte, salidas',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          SizedBox(height: r.cardSpacing - 4),
          TextField(
            controller: _expenseAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monto (\$)',
              hintText: '0.00',
              prefixIcon: Icon(Icons.attach_money),
            ),
            onSubmitted: (_) => _addExpense(),
          ),
          SizedBox(height: r.cardSpacing),
          SizedBox(
            width: double.infinity,
            height: r.buttonHeight,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _addExpense,
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

          SizedBox(height: r.cardSpacing + 6),

          // Lista de gastos planeados
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
                  Text(
                    'Aún no agregas gastos para esta quincena.',
                    style: GoogleFonts.inter(
                      fontSize: r.bodyFontSize - 2,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            )
          else
            ...expenses.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
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
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _quincenaPalette[i % _quincenaPalette.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.name,
                        style: GoogleFonts.inter(
                          fontSize: r.bodyFontSize - 1,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '\$${e.amount.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: r.bodyFontSize,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: Colors.redAccent,
                      onPressed: () => _deleteExpense(e),
                      tooltip: 'Eliminar gasto',
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPieChart(
    ThemeData theme,
    ResponsiveHelper r,
    double available,
    List<QuincenaExpense> expenses,
    double remaining,
  ) {
    final sections = <PieChartSectionData>[];
    final ringRadius = r.isDesktop ? 60.0 : 48.0;

    final expensesTotal = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final pieTotal = expensesTotal + (remaining > 0 ? remaining : 0);

    if (expenses.isEmpty && remaining <= 0) {
      sections.add(
        PieChartSectionData(
          color: Colors.green.shade400,
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
            color: _quincenaPalette[i % _quincenaPalette.length],
            value: amount,
            radius: ringRadius,
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
            color: Colors.green.shade400,
            value: remaining,
            radius: ringRadius,
            showTitle: false,
          ),
        );
      }
    }

    final restanteColor =
        remaining >= 0 ? Colors.green.shade400 : Colors.redAccent;
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
                    color: restanteColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme, ResponsiveHelper r) {
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Próxima Quincena',
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
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final ResponsiveHelper r;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: EdgeInsets.all(r.cardSpacing),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(r.borderRadius - 2),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: r.iconSizeMedium - 4),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: r.isDesktop ? 20 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: r.bodyFontSize - 2,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
