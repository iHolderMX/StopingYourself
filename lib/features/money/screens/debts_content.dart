import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/debt.dart';

final debtsProvider = FutureProvider.family<List<Debt>, String>(
  (ref, userId) => ref.watch(databaseServiceProvider).getDebts(userId),
);

final debtPaymentsProvider = FutureProvider.family<List<DebtPayment>, String>(
  (ref, debtId) => ref.watch(databaseServiceProvider).getDebtPayments(debtId),
);

class DebtsContent extends ConsumerStatefulWidget {
  final bool compact;
  final double totalSaved;

  const DebtsContent({
    super.key,
    this.compact = true,
    required this.totalSaved,
  });

  @override
  ConsumerState<DebtsContent> createState() => _DebtsContentState();
}

class _DebtsContentState extends ConsumerState<DebtsContent> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _interestCtrl = TextEditingController();
  final _paymentCtrl = TextEditingController();
  final _paymentNoteCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _paymentFormKey = GlobalKey<FormState>();
  String? _expandedDebtId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _interestCtrl.dispose();
    _paymentCtrl.dispose();
    _paymentNoteCtrl.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────
  // Dialogo: Agregar deuda
  // ──────────────────────────────────────────────
  Future<void> _showAddDebtDialog() async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;

    _nameCtrl.clear();
    _amountCtrl.clear();
    _interestCtrl.clear();
    _formKey.currentState?.reset();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text(
            'Nueva deuda',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la deuda',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Monto total',
                      prefixIcon: Icon(Icons.attach_money),
                      prefixText: '\$ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Monto invalido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _interestCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Interes anual (%)',
                      prefixIcon: Icon(Icons.percent),
                      suffixText: '%',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar'),
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final db = ref.read(databaseServiceProvider);
                final debt = Debt(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  userId: user.id,
                  name: _nameCtrl.text.trim(),
                  totalAmount: double.parse(_amountCtrl.text.trim()),
                  interestRate:
                      double.tryParse(
                        _interestCtrl.text.trim().isEmpty
                            ? '0'
                            : _interestCtrl.text.trim(),
                      ) ??
                      0,
                );
                await db.insertDebt(debt);
                ref.invalidate(debtsProvider(user.id));
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
            ),
          ],
        );
      },
    );
    if (ok == true) {
      ref.invalidate(debtsProvider(user.id));
    }
  }

  // ──────────────────────────────────────────────
  // Dialogo: Agregar pago
  // ──────────────────────────────────────────────
  Future<void> _showAddPaymentDialog(Debt debt) async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;

    _paymentCtrl.clear();
    _paymentNoteCtrl.clear();
    _paymentFormKey.currentState?.reset();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final minPayment = (debt.totalAmount * 0.06).clamp(
          0.0,
          debt.remainingAmount,
        );
        return AlertDialog(
          title: Text(
            'Pago a: ${debt.name}',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: Form(
            key: _paymentFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Restante: \$${debt.remainingAmount.toStringAsFixed(2)}',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Minimo sugerido (6%): \$${minPayment.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _paymentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Monto del pago',
                      prefixIcon: Icon(Icons.payments_outlined),
                      prefixText: '\$ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autofocus: true,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Monto invalido';
                      if (n > debt.remainingAmount) {
                        return 'No puede exceder lo restante (${debt.remainingAmount.toStringAsFixed(2)})';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _paymentNoteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nota (opcional)',
                      prefixIcon: Icon(Icons.note_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Registrar pago'),
              onPressed: () async {
                if (!_paymentFormKey.currentState!.validate()) return;
                final db = ref.read(databaseServiceProvider);
                final payment = DebtPayment(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  debtId: debt.id,
                  amount: double.parse(_paymentCtrl.text.trim()),
                  note: _paymentNoteCtrl.text.trim().isEmpty
                      ? null
                      : _paymentNoteCtrl.text.trim(),
                );
                await db.insertDebtPayment(payment);
                await db.updateDebt(
                  Debt(
                    id: debt.id,
                    userId: debt.userId,
                    name: debt.name,
                    totalAmount: debt.totalAmount,
                    paidAmount: debt.paidAmount + payment.amount,
                    interestRate: debt.interestRate,
                    createdAt: debt.createdAt,
                  ),
                );
                ref.invalidate(debtsProvider(user.id));
                ref.invalidate(debtPaymentsProvider(debt.id));
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
            ),
          ],
        );
      },
    );
    if (ok == true) {
      ref.invalidate(debtsProvider(user.id));
      ref.invalidate(debtPaymentsProvider(debt.id));
    }
  }

  // ──────────────────────────────────────────────
  // Confirmacion: Eliminar deuda
  // ──────────────────────────────────────────────
  Future<void> _confirmDeleteDebt(Debt debt) async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar deuda'),
        content: Text(
          'Seguro que quieres eliminar "${debt.name}"?\nEsta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final db = ref.read(databaseServiceProvider);
      await db.deleteDebt(debt.id);
      ref.invalidate(debtsProvider(user.id));
    }
  }

  // ──────────────────────────────────────────────
  // UI
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final userId = user?.id;

    final debtsAsync = userId != null ? ref.watch(debtsProvider(userId)) : null;
    final debts = debtsAsync?.asData?.value ?? [];
    final isLoading = debtsAsync?.isLoading == true;

    final totalDebt = debts.fold(0.0, (sum, d) => sum + d.totalAmount);
    final totalPaid = debts.fold(0.0, (sum, d) => sum + d.paidAmount);
    final totalRemaining = totalDebt - totalPaid;
    final globalProgress = totalDebt > 0 ? totalPaid / totalDebt : 0.0;

    return Container(
      padding: EdgeInsets.all(r.cardSpacing),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.all(Radius.circular(r.borderRadius)),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.credit_card_rounded,
                  color: theme.colorScheme.error,
                  size: r.iconSizeMedium,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Deudas',
                style: GoogleFonts.outfit(
                  fontSize: r.subtitleFontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  'Agregar',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _showAddDebtDialog,
              ),
            ],
          ),
          SizedBox(height: r.cardSpacing),

          // ── Resumen global ──
          if (debts.isNotEmpty) ...[
            _buildSummaryBar(
              theme,
              r,
              totalDebt,
              totalPaid,
              totalRemaining,
              globalProgress,
            ),
            SizedBox(height: r.cardSpacing),
          ],

          // ── Lista de deudas ──
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (debts.isEmpty)
            _buildEmptyState(theme, r)
          else
            ...debts.map((debt) => _buildDebtCard(theme, r, debt)),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Barra de resumen global
  // ──────────────────────────────────────────────
  Widget _buildSummaryBar(
    ThemeData theme,
    ResponsiveHelper r,
    double totalDebt,
    double totalPaid,
    double totalRemaining,
    double progress,
  ) {
    return Container(
      padding: EdgeInsets.all(r.cardSpacing - 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _summaryChip(
                'Total',
                '\$${totalDebt.toStringAsFixed(0)}',
                theme,
                r,
              ),
              const SizedBox(width: 8),
              _summaryChip(
                'Pagado',
                '\$${totalPaid.toStringAsFixed(0)}',
                theme,
                r,
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              _summaryChip(
                'Restante',
                '\$${totalRemaining.toStringAsFixed(0)}',
                theme,
                r,
                color: theme.colorScheme.error,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.error),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% pagado',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(
    String label,
    String value,
    ThemeData theme,
    ResponsiveHelper r, {
    Color? color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color ?? theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Estado vacio
  // ──────────────────────────────────────────────
  Widget _buildEmptyState(ThemeData theme, ResponsiveHelper r) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: r.padVertical),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.credit_card_off_rounded,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'Sin deudas registradas',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Agregar primera deuda'),
            onPressed: _showAddDebtDialog,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Card de deuda individual
  // ──────────────────────────────────────────────
  Widget _buildDebtCard(ThemeData theme, ResponsiveHelper r, Debt debt) {
    final isExpanded = _expandedDebtId == debt.id;
    final progress = debt.progress;
    final progressColor = progress >= 1
        ? Colors.green
        : progress > 0.5
        ? Colors.orange
        : theme.colorScheme.error;

    return Container(
      margin: EdgeInsets.only(bottom: r.cardSpacing - 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isExpanded
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          // ── Header de la deuda ──
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            onTap: () {
              setState(() {
                _expandedDebtId = isExpanded ? null : debt.id;
              });
            },
            child: Padding(
              padding: EdgeInsets.all(r.cardSpacing - 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    debt.name,
                                    style: GoogleFonts.inter(
                                      fontSize: r.bodyFontSize,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (debt.interestRate > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.tertiary
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${debt.interestRate.toStringAsFixed(0)}% int.',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: theme.colorScheme.tertiary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${debt.remainingAmount.toStringAsFixed(2)} restante de \$${debt.totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Acciones rapidas
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_horiz,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (v) async {
                          if (v == 'delete') _confirmDeleteDebt(debt);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Eliminar',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(progressColor),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'Pagado: \$${debt.paidAmount.toStringAsFixed(2)} (${(progress * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      if (debt.remainingAmount > 0)
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text(
                            'Pago',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _showAddPaymentDialog(debt),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Colors.green,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Pagado',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  // Indicador expandir
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Historial de pagos expandible ──
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildPaymentHistory(theme, r, debt),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Historial de pagos de una deuda
  // ──────────────────────────────────────────────
  Widget _buildPaymentHistory(ThemeData theme, ResponsiveHelper r, Debt debt) {
    final paymentsAsync = ref.watch(debtPaymentsProvider(debt.id));
    final payments = paymentsAsync?.asData?.value ?? [];
    final isLoading = paymentsAsync?.isLoading == true;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.cardSpacing - 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historial de pagos',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (payments.isEmpty)
            Text(
              'Sin pagos registrados aun.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...payments.reversed.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.note ?? 'Pago',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '\$${p.amount.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(p.paymentDate),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
