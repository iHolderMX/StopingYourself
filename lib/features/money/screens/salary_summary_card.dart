import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/salary_setting.dart';

final salarySettingProvider = FutureProvider.family<SalarySetting?, String>(
  (ref, userId) => ref.watch(databaseServiceProvider).getSalarySetting(userId),
);

class SalarySummaryCard extends ConsumerStatefulWidget {
  final double totalSaved;
  final double totalDailyEarnings;
  final double totalFixedExpenses;

  const SalarySummaryCard({
    super.key,
    required this.totalSaved,
    required this.totalDailyEarnings,
    required this.totalFixedExpenses,
  });

  @override
  ConsumerState<SalarySummaryCard> createState() => _SalarySummaryCardState();
}

class _SalarySummaryCardState extends ConsumerState<SalarySummaryCard> {
  bool _editing = false;
  final _salaryController = TextEditingController();

  @override
  void dispose() {
    _salaryController.dispose();
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
    setState(() => _editing = false);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Salario actualizado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final salaryAsync = user != null
        ? ref.watch(salarySettingProvider(user.id))
        : null;
    final salary = salaryAsync?.asData?.value?.monthlySalary ?? 0;
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final hasSalary = salary > 0;

    final neon = theme.colorScheme.primary;
    final neonDim = theme.colorScheme.tertiary;

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
          Row(
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
              if (_editing) ...[
                TextButton(
                  onPressed: () => setState(() => _editing = false),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveSalary,
                  child: const Text('Guardar'),
                ),
              ] else
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: neon, size: 20),
                  onPressed: () {
                    _salaryController.text = hasSalary
                        ? salary.toStringAsFixed(0)
                        : '';
                    setState(() => _editing = true);
                  },
                  tooltip: 'Editar salario',
                ),
            ],
          ),
          if (_editing) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _salaryController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Salario mensual (\$)',
                hintText: '0.00',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _saveSalary(),
            ),
          ],
          if (!_editing) ...[
            SizedBox(height: r.cardSpacing - 4),
            if (!hasSalary)
              Container(
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
                    Text(
                      'Configura tu salario para ver las metricas',
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 1,
                        color: neon,
                      ),
                    ),
                  ],
                ),
              ),
            if (hasSalary) ...[
              SizedBox(height: r.cardSpacing),
              Wrap(
                spacing: r.cardSpacing - 4,
                runSpacing: r.cardSpacing - 4,
                children: [
                  _MetricTile(
                    icon: Icons.savings_outlined,
                    label: 'Ahorro total',
                    value: '\$${widget.totalSaved.toStringAsFixed(2)}',
                    sub:
                        '${(widget.totalSaved / salary * 100).toStringAsFixed(1)}% de tu salario',
                    color: neon,
                    r: r,
                  ),
                  _MetricTile(
                    icon: Icons.calendar_today,
                    label: 'Dias de salario ahorrados',
                    value: salary > 0
                        ? '${(widget.totalSaved / salary * 30).toStringAsFixed(1)} dias'
                        : '-',
                    sub: salary > 0
                        ? '${(widget.totalSaved / salary).toStringAsFixed(1)} meses de salario'
                        : '-',
                    color: neonDim,
                    r: r,
                  ),
                  _MetricTile(
                    icon: Icons.trending_up,
                    label: 'Rendimiento diario',
                    value: '\$${widget.totalDailyEarnings.toStringAsFixed(4)}',
                    sub: salary > 0
                        ? 'Equivale a ${(widget.totalDailyEarnings / (salary / 30) * 100).toStringAsFixed(2)}% de 1 dia de salario'
                        : '-',
                    color: neon,
                    r: r,
                  ),
                  _MetricTile(
                    icon: Icons.receipt_long_outlined,
                    label: 'Gastos fijos mensuales',
                    value: '\$${widget.totalFixedExpenses.toStringAsFixed(2)}',
                    sub: salary > 0
                        ? '${(widget.totalFixedExpenses / salary * 100).toStringAsFixed(1)}% de tu salario'
                        : '-',
                    color: neonDim,
                    r: r,
                  ),
                  _MetricTile(
                    icon: Icons.account_balance_wallet,
                    label: 'Salario restante',
                    value:
                        '\$${(salary - widget.totalFixedExpenses).toStringAsFixed(2)}',
                    sub: salary > 0 ? 'Despues de gastos fijos' : '-',
                    color: neon,
                    r: r,
                  ),
                  _MetricTile(
                    icon: Icons.pie_chart_outline,
                    label: '% de ahorro vs salario',
                    value:
                        '${(widget.totalSaved / salary * 100).toStringAsFixed(1)}%',
                    sub: 'De tu salario anual',
                    color: neonDim,
                    r: r,
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  final ResponsiveHelper r;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: r.isDesktop ? 200 : (r.isTablet ? 170 : null),
      constraints: const BoxConstraints(minWidth: 140),
      padding: EdgeInsets.all(r.cardSpacing),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(r.borderRadius - 2),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
          const SizedBox(height: 2),
          Text(
            sub,
            style: GoogleFonts.inter(
              fontSize: r.bodyFontSize - 3,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
