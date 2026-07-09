import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/debt.dart';
import '../../../models/fixed_expense.dart';
import '../../../models/salary_setting.dart';
import 'debts_content.dart';
import 'fixed_expenses_content.dart';
import 'salary_summary_card.dart';

class NextQuincenaCard extends ConsumerWidget {
  const NextQuincenaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final debtsAsync = ref.watch(debtsProvider(user.id));
    final fixedAsync = ref.watch(fixedExpensesProvider(user.id));
    final salaryAsync = ref.watch(salarySettingProvider(user.id));

    final debts = debtsAsync.asData?.value ?? [];
    final fixedExpenses = fixedAsync.asData?.value ?? [];
    final monthlySalary = salaryAsync.asData?.value?.monthlySalary ?? 0;

    // Gastos fijos quincenales (mensuales / 2)
    final totalFixed = fixedExpenses.fold<double>(0, (s, e) => s + e.amount);
    final quincenaFixed = totalFixed / 2;

    // Pagos minimos de deudas con vencimiento en los proximos 15 dias
    final now = DateTime.now();
    final quincenaLimit = now.add(const Duration(days: 15));
    double debtPayments = 0;
    for (final debt in debts) {
      final due = debt.nextPaymentDue;
      if (due.isAfter(now) && due.isBefore(quincenaLimit)) {
        debtPayments += debt.minPayment;
      }
      // Deudas ya vencidas tambien cuentan (hay que pagarlas ya)
      if (due.isBefore(now) && debt.currentBalance > 0) {
        debtPayments += debt.minPayment;
      }
    }

    final totalComprometido = quincenaFixed + debtPayments;
    final quincenaSalary = monthlySalary / 2;
    final disponible = (quincenaSalary - totalComprometido).clamp(0, double.infinity);

    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final neon = theme.colorScheme.primary;
    final neon2 = theme.colorScheme.secondary;

    return Container(
      margin: EdgeInsets.only(bottom: r.cardSpacing + 6),
      padding: EdgeInsets.all(r.cardSpacing + 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [neon2.withValues(alpha: 0.08), neon.withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(r.borderRadius + 4),
        border: Border.all(color: neon2.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.date_range, color: neon2, size: r.iconSizeMedium - 2),
              const SizedBox(width: 10),
              Text(
                'Próxima Quincena',
                style: GoogleFonts.outfit(
                  fontSize: r.subtitleFontSize + 2,
                  fontWeight: FontWeight.w600,
                  color: neon2,
                ),
              ),
            ],
          ),
          SizedBox(height: r.cardSpacing),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Gastos fijos',
                  value: '\$${quincenaFixed.toStringAsFixed(2)}',
                  color: neon2,
                  r: r,
                ),
              ),
              SizedBox(width: r.cardSpacing - 4),
              Expanded(
                child: _MetricTile(
                  icon: Icons.credit_card_outlined,
                  label: 'Pagos deudas',
                  value: '\$${debtPayments.toStringAsFixed(2)}',
                  color: neon2,
                  r: r,
                ),
              ),
            ],
          ),
          SizedBox(height: r.cardSpacing - 4),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.lock_outline,
                  label: 'Comprometido',
                  value: '\$${totalComprometido.toStringAsFixed(2)}',
                  color: totalComprometido > 0 ? neon : neon2,
                  r: r,
                  bold: true,
                ),
              ),
              SizedBox(width: r.cardSpacing - 4),
              Expanded(
                child: _MetricTile(
                  icon: Icons.savings_outlined,
                  label: 'Disponible',
                  value: monthlySalary > 0
                      ? '\$${disponible.toStringAsFixed(2)}'
                      : '-',
                  sub: monthlySalary > 0
                      ? 'Salario qnal: \$${quincenaSalary.toStringAsFixed(0)}'
                      : 'Configura tu salario',
                  color: disponible > 0 ? Colors.green : neon2,
                  r: r,
                  bold: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color color;
  final ResponsiveHelper r;
  final bool bold;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    required this.color,
    required this.r,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(r.cardSpacing - 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(r.borderRadius - 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: r.bodyFontSize + 2, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: r.bodyFontSize - 1,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: r.isDesktop ? 20 : 17,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub!,
              style: GoogleFonts.inter(
                fontSize: r.bodyFontSize - 2,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
