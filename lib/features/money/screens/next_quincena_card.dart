import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/debt.dart';
import '../../../models/fixed_expense.dart';
import '../../../models/salary_setting.dart';
import '../../../models/monthly_payment.dart';
import 'debts_content.dart';
import 'fixed_expenses_content.dart';
import 'salary_summary_card.dart';

final _monthlyPaymentsProvider =
    FutureProvider.family<List<MonthlyPayment>, String>((ref, userId) async {
      final db = ref.watch(databaseServiceProvider);
      return db.getMonthlyPayments(userId);
    });

final _totalDailyEarningsProvider = FutureProvider.family<double, String>(
  (ref, userId) =>
      ref.watch(databaseServiceProvider).getTotalDailyEarnings(userId),
);

class NextQuincenaCard extends ConsumerWidget {
  const NextQuincenaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final debtsAsync = ref.watch(debtsProvider(user.id));
    final fixedAsync = ref.watch(fixedExpensesProvider(user.id));
    final salaryAsync = ref.watch(salarySettingProvider(user.id));
    final monthlyAsync = ref.watch(_monthlyPaymentsProvider(user.id));
    final dailyEarningsAsync = ref.watch(_totalDailyEarningsProvider(user.id));

    final debts = debtsAsync.asData?.value ?? [];
    final fixedExpenses = fixedAsync.asData?.value ?? [];
    final monthlySalary = salaryAsync.asData?.value?.monthlySalary ?? 0;
    final dailyReturn = dailyEarningsAsync.asData?.value ?? 0;
    final monthlyPayments = monthlyAsync.asData?.value ?? [];

    final totalFixed = fixedExpenses.fold<double>(0, (s, e) => s + e.amount);
    final quincenaFixed = totalFixed / 2;

    final now = DateTime.now();
    final quincenaLimit = now.add(const Duration(days: 15));
    double debtPayments = 0;
    for (final debt in debts) {
      final due = debt.nextPaymentDue;
      if (due.isAfter(now) && due.isBefore(quincenaLimit)) {
        debtPayments += debt.minPayment;
      }
      if (due.isBefore(now) && debt.currentBalance > 0) {
        debtPayments += debt.minPayment;
      }
    }

    final totalCreditosMes = monthlyPayments
        .where((p) => p.type == 'credito')
        .fold<double>(0, (s, p) => s + p.amount);
    final totalAhorro = monthlyPayments
        .where((p) => p.type == 'ahorro')
        .fold<double>(0, (s, p) => s + p.amount);

    final totalComprometido =
        quincenaFixed + debtPayments + totalCreditosMes + totalAhorro;
    final quincenaSalary = monthlySalary / 2;
    final disponible = (quincenaSalary - totalComprometido)
        .clamp(0.0, double.infinity)
        .toDouble();

    final libreDonut = (quincenaSalary - totalCreditosMes - totalAhorro)
        .clamp(0.0, double.infinity)
        .toDouble();

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
                  icon: Icons.credit_score_outlined,
                  label: 'Creditos mes',
                  value: '\$${totalCreditosMes.toStringAsFixed(2)}',
                  color: Colors.orange,
                  r: r,
                  onTap: () => _showMonthlyPaymentsDialog(
                    context,
                    ref,
                    user.id,
                    'credito',
                  ),
                ),
              ),
              SizedBox(width: r.cardSpacing - 4),
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
            ],
          ),
          SizedBox(height: r.cardSpacing - 4),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.shield_outlined,
                  label: 'Ahorro Asegurado',
                  value: '\$${totalAhorro.toStringAsFixed(2)}',
                  color: Colors.purple,
                  r: r,
                  onTap: () => _showMonthlyPaymentsDialog(
                    context,
                    ref,
                    user.id,
                    'ahorro',
                  ),
                ),
              ),
              SizedBox(width: r.cardSpacing - 4),
              Expanded(
                child: _MetricTile(
                  icon: Icons.savings_outlined,
                  label: 'Libre',
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
          if (quincenaSalary > 0) ...[
            SizedBox(height: r.cardSpacing),
            const Divider(),
            SizedBox(height: r.cardSpacing),
            _QuincenaDonut(
              quincenaSalary: quincenaSalary,
              creditos: totalCreditosMes,
              ahorro: totalAhorro,
              theme: theme,
              r: r,
            ),
            SizedBox(height: r.cardSpacing),
            const Divider(),
            SizedBox(height: r.cardSpacing - 2),
            _DiasRendimiento(
              creditos: totalCreditosMes,
              ahorro: totalAhorro,
              libre: libreDonut,
              dailyReturn: dailyReturn,
              userId: user.id,
              theme: theme,
              r: r,
            ),
          ],
        ],
      ),
    );
  }
}

class _DiasRendimiento extends StatelessWidget {
  final double creditos;
  final double ahorro;
  final double libre;
  final double dailyReturn;
  final String userId;
  final ThemeData theme;
  final ResponsiveHelper r;

  const _DiasRendimiento({
    required this.creditos,
    required this.ahorro,
    required this.libre,
    required this.dailyReturn,
    required this.userId,
    required this.theme,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final diario = dailyReturn;

    String fmtDays(double amount) {
      if (diario <= 0) return '-';
      final d = amount / diario;
      if (d < 1) return '${(d * 24).toStringAsFixed(0)} h';
      return '${d.toStringAsFixed(0)} d';
    }

    final credDias = fmtDays(creditos);
    final ahorroDias = fmtDays(ahorro);
    final libreDias = fmtDays(libre);

    return Row(
      children: [
        _DayChip(
          color: Colors.orange,
          label: 'Creditos',
          dias: credDias,
          theme: theme,
          r: r,
        ),
        const SizedBox(width: 8),
        _DayChip(
          color: Colors.purple,
          label: 'Ahorro',
          dias: ahorroDias,
          theme: theme,
          r: r,
        ),
        const SizedBox(width: 8),
        _DayChip(
          color: Colors.green,
          label: 'Libre',
          dias: libreDias,
          theme: theme,
          r: r,
          bold: true,
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  final Color color;
  final String label;
  final String dias;
  final ThemeData theme;
  final ResponsiveHelper r;
  final bool bold;

  const _DayChip({
    required this.color,
    required this.label,
    required this.dias,
    required this.theme,
    required this.r,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              dias,
              style: GoogleFonts.outfit(
                fontSize: r.isDesktop ? 18 : 15,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: r.bodyFontSize - 3,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
  final VoidCallback? onTap;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    required this.color,
    required this.r,
    this.onTap,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
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
              if (onTap != null)
                Icon(Icons.edit, size: r.bodyFontSize - 2, color: color),
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

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.borderRadius - 4),
        child: card,
      );
    }
    return card;
  }
}

class _QuincenaDonut extends StatelessWidget {
  final double quincenaSalary;
  final double creditos;
  final double ahorro;
  final ThemeData theme;
  final ResponsiveHelper r;

  const _QuincenaDonut({
    required this.quincenaSalary,
    required this.creditos,
    required this.ahorro,
    required this.theme,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final libre = (quincenaSalary - creditos - ahorro)
        .clamp(0.0, double.infinity)
        .toDouble();
    final credPct =
        (quincenaSalary > 0
                ? (creditos / quincenaSalary * 100).clamp(0.0, 100.0)
                : 0.0)
            .toDouble();
    final ahorroPct =
        (quincenaSalary > 0
                ? (ahorro / quincenaSalary * 100).clamp(0.0, 100.0)
                : 0.0)
            .toDouble();
    final librePct = (100.0 - credPct - ahorroPct).clamp(0.0, 100.0).toDouble();

    return Row(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CustomPaint(
            painter: _DonutPainter(
              credPct: credPct,
              ahorroPct: ahorroPct,
              librePct: librePct,
            ),
            child: Center(
              child: Text(
                '${librePct.toStringAsFixed(0)}%',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quincena: \$${quincenaSalary.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize - 1,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              _Legend(
                color: Colors.orange,
                label: 'Creditos',
                amount: creditos,
                pct: credPct,
                r: r,
              ),
              _Legend(
                color: Colors.purple,
                label: 'Ahorro Asegurado',
                amount: ahorro,
                pct: ahorroPct,
                r: r,
              ),
              _Legend(
                color: Colors.green,
                label: 'Libre',
                amount: libre,
                pct: librePct,
                r: r,
                bold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final double amount;
  final double pct;
  final ResponsiveHelper r;
  final bool bold;

  const _Legend({
    required this.color,
    required this.label,
    required this.amount,
    required this.pct,
    required this.r,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: \$${amount.toStringAsFixed(0)} (${pct.toStringAsFixed(0)}%)',
            style: GoogleFonts.inter(
              fontSize: r.bodyFontSize - 2,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double credPct;
  final double ahorroPct;
  final double librePct;

  _DonutPainter({
    required this.credPct,
    required this.ahorroPct,
    required this.librePct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 12.0;

    Paint makePaint(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final slices = [
      (credPct, makePaint(Colors.orange)),
      (ahorroPct, makePaint(Colors.purple)),
      (librePct, makePaint(Colors.green)),
    ];

    double startAngle = -3.14159 / 2; // top
    for (final (pct, paint) in slices) {
      final sweep = (pct / 100) * 2 * 3.14159;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      credPct != old.credPct ||
      ahorroPct != old.ahorroPct ||
      librePct != old.librePct;
}

void _showMonthlyPaymentsDialog(
  BuildContext context,
  WidgetRef ref,
  String userId,
  String type,
) {
  final title = type == 'ahorro' ? 'Ahorro Asegurado' : 'Creditos Mensuales';
  final color = type == 'ahorro' ? Colors.purple : Colors.orange;
  final icon = type == 'ahorro'
      ? Icons.shield_outlined
      : Icons.credit_score_outlined;

  showDialog(
    context: context,
    builder: (ctx) {
      final paymentsAsync = ref.watch(_monthlyPaymentsProvider(userId));
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(icon, color: color),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: paymentsAsync.when(
                  data: (payments) {
                    final filtered = payments
                        .where((p) => p.type == type)
                        .toList();
                    if (filtered.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No hay registros todavia.'),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final p = filtered[i];
                        return ListTile(
                          title: Text(p.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${p.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  await ref
                                      .read(databaseServiceProvider)
                                      .deleteMonthlyPayment(p.id);
                                  ref.invalidate(
                                    _monthlyPaymentsProvider(userId),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                ),
              ),
              const Divider(height: 1),
              _AddMonthlyPaymentRow(userId: userId, type: type),
            ],
          ),
        ),
      );
    },
  );
}

class _AddMonthlyPaymentRow extends ConsumerStatefulWidget {
  final String userId;
  final String type;
  const _AddMonthlyPaymentRow({required this.userId, required this.type});

  @override
  ConsumerState<_AddMonthlyPaymentRow> createState() =>
      _AddMonthlyPaymentRowState();
}

class _AddMonthlyPaymentRowState extends ConsumerState<_AddMonthlyPaymentRow> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (name.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa nombre y monto')));
      return;
    }

    // Validacion: ahorro no puede superar (quincena - creditos)
    if (widget.type == 'ahorro') {
      final paymentsAsync = ref.read(_monthlyPaymentsProvider(widget.userId));
      final payments = paymentsAsync.asData?.value ?? [];
      final totalCreditos = payments
          .where((p) => p.type == 'credito')
          .fold<double>(0, (s, p) => s + p.amount);
      final totalAhorroExistente = payments
          .where((p) => p.type == 'ahorro')
          .fold<double>(0, (s, p) => s + p.amount);
      final salaryAsync = ref.read(salarySettingProvider(widget.userId));
      final quincenaSalary =
          (salaryAsync.asData?.value?.monthlySalary ?? 0) / 2;
      final disponible = quincenaSalary - totalCreditos - totalAhorroExistente;

      if (amount > disponible) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No puedes ahorrar mas de lo disponible (\$${disponible.toStringAsFixed(0)})',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    setState(() => _saving = true);

    final payment = MonthlyPayment(
      id: const Uuid().v4(),
      userId: widget.userId,
      name: name,
      amount: amount,
      type: widget.type,
    );

    try {
      await ref.read(databaseServiceProvider).insertMonthlyPayment(payment);
      ref.invalidate(_monthlyPaymentsProvider(widget.userId));
      _nameCtrl.clear();
      _amountCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Agregado correctamente')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: widget.type == 'ahorro'
                    ? 'Nombre del ahorro'
                    : 'Nombre (ej: Tarjeta X)',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monto',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _saving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: _save,
                ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }
}
