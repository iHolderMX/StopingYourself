import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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

const paymentPeriodOptions = [15, 30];

class DebtsContent extends ConsumerStatefulWidget {
  final bool compact;
  final double totalSaved;
  const DebtsContent({super.key, this.compact = true, this.totalSaved = 0});

  @override
  ConsumerState<DebtsContent> createState() => _DebtsContentState();
}

class _DebtsContentState extends ConsumerState<DebtsContent> {
  String _selectedDebtType = Debt.debtTypes.last;
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _rateController = TextEditingController();
  final _minPaymentController = TextEditingController();
  final _graceController = TextEditingController();
  int _periodDays = 15;
  DateTime _startDate = DateTime.now();
  bool _saving = false;
  String? _expandedDebtId;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _rateController.dispose();
    _minPaymentController.dispose();
    _graceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;
    final amount = double.tryParse(_amountController.text.trim());
    final rate = double.tryParse(
      _rateController.text.trim().isEmpty ? '0' : _rateController.text.trim(),
    );
    final minPay = double.tryParse(_minPaymentController.text.trim());
    final grace = int.tryParse(
      _graceController.text.trim().isEmpty
          ? '30'
          : _graceController.text.trim(),
    );

    if (amount == null || amount <= 0 || minPay == null || minPay <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa monto y pago minimo validos')),
      );
      return;
    }

    setState(() => _saving = true);
    final debt = Debt(
      id: '${user.id}_d_${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      name: _nameController.text.trim().isEmpty
          ? 'Deuda'
          : _nameController.text.trim(),
      debtType: _selectedDebtType,
      initialAmount: amount,
      currentBalance: amount,
      interestRate: rate ?? 0,
      paymentPeriodDays: _periodDays,
      minPayment: minPay,
      gracePeriodDays: grace ?? 30,
      startDate: _startDate,
    );

    try {
      await ref.read(databaseServiceProvider).insertDebt(debt);
      ref.invalidate(debtsProvider(user.id));
      setState(() {
        _saving = false;
        _selectedDebtType = Debt.debtTypes.last;
        _nameController.clear();
        _amountController.clear();
        _rateController.clear();
        _minPaymentController.clear();
        _graceController.clear();
        _periodDays = 15;
        _startDate = DateTime.now();
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Deuda registrada')));
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    }
  }

  Future<void> _addPayment(Debt debt) async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;
    final theme = Theme.of(context);

    final controller = TextEditingController(
      text: debt.minPayment.toStringAsFixed(2),
    );
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Registrar pago - ${debt.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monto (\$)',
                prefixIcon: Icon(Icons.attach_money),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Text(
              'Pago minimo sugerido: \$${debt.minPayment.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                Navigator.of(ctx).pop({'amount': val});
              }
            },
            child: const Text('Pagar'),
          ),
        ],
      ),
    );

    if (result == null) return;
    final payAmount = result['amount'] as double;

    final payment = DebtPayment(
      id: '${debt.id}_p_${DateTime.now().millisecondsSinceEpoch}',
      debtId: debt.id,
      userId: user.id,
      amount: payAmount,
      paymentDate: DateTime.now(),
    );

    try {
      await ref.read(databaseServiceProvider).insertDebtPayment(payment);
      final newBalance = (debt.currentBalance - payAmount)
          .clamp(0, double.infinity)
          .toDouble();
      final updated = Debt(
        id: debt.id,
        userId: debt.userId,
        name: debt.name,
        initialAmount: debt.initialAmount,
        currentBalance: newBalance,
        interestRate: debt.interestRate,
        paymentPeriodDays: debt.paymentPeriodDays,
        minPayment: debt.minPayment,
        gracePeriodDays: debt.gracePeriodDays,
        startDate: debt.startDate,
      );
      await ref.read(databaseServiceProvider).updateDebt(updated);
      ref.invalidate(debtsProvider(user.id));
      ref.invalidate(debtPaymentsProvider(debt.id));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pago registrado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al pagar: $e')));
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Fecha de inicio',
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final debtsAsync = user != null ? ref.watch(debtsProvider(user.id)) : null;
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final neon = theme.colorScheme.primary;
    final neon2 = theme.colorScheme.secondary;
    final neon3 = theme.colorScheme.tertiary;
    final surface = theme.colorScheme.surface;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Deudas',
          style: GoogleFonts.outfit(
            fontSize: r.titleFontSize,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Gestiona prestamos, tarjetas y deudas personales.',
          style: GoogleFonts.inter(
            fontSize: r.subtitleFontSize,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        SizedBox(height: r.cardSpacing + 4),

        // --- Total Deudas (resumen) ---
        if (debtsAsync != null)
          Builder(
            builder: (_) {
              final debts = debtsAsync.asData?.value ?? [];
              if (debts.isEmpty) return const SizedBox.shrink();
              double totalAll = 0;
              double totalAhorro = 0;
              double prestamoAhorro = 0;
              double atrasoAhorro = 0;
              double tarjeta = 0;
              double otro = 0;
              for (final d in debts) {
                final td = d.totalDebt;
                totalAll += td;
                if (d.isLinkedToSavings) {
                  totalAhorro += td;
                  if (d.debtType == 'prestamo_ahorro') {
                    prestamoAhorro += td;
                  } else if (d.debtType == 'atraso_ahorro') {
                    atrasoAhorro += td;
                  }
                } else if (d.debtType == 'tarjeta') {
                  tarjeta += td;
                } else {
                  otro += td;
                }
              }
              return Container(
                width: double.infinity,
                padding: EdgeInsets.all(r.cardSpacing + 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [neon.withValues(alpha: 0.9), neon2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(r.borderRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.summarize, color: Colors.white, size: r.iconSizeMedium),
                        const SizedBox(width: 8),
                        Text(
                          'Total Deudas',
                          style: GoogleFonts.outfit(
                            fontSize: r.subtitleFontSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: r.cardSpacing - 2),
                    Text(
                      '\$${totalAll.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: r.isDesktop ? 28 : 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (totalAhorro > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Deuda al ahorro: \$${totalAhorro.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: r.bodyFontSize,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                      if (prestamoAhorro > 0)
                        Text(
                          '  Prestamo del ahorro: \$${prestamoAhorro.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: r.bodyFontSize - 1,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      if (atrasoAhorro > 0)
                        Text(
                          '  Atraso al ahorro: \$${atrasoAhorro.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: r.bodyFontSize - 1,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                    ],
                    if (tarjeta > 0 || otro > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Otras deudas:',
                        style: GoogleFonts.inter(
                          fontSize: r.bodyFontSize - 1,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      if (tarjeta > 0)
                        Text(
                          '  Tarjeta de credito: \$${tarjeta.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: r.bodyFontSize - 2,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      if (otro > 0)
                        Text(
                          '  Otros: \$${otro.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: r.bodyFontSize - 2,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                    if (widget.totalSaved > 0 && totalAhorro > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Ahorro real disponible: \$${(widget.totalSaved - totalAhorro).clamp(0, double.infinity).toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: r.bodyFontSize - 1,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

        if (debtsAsync != null &&
            (debtsAsync.asData?.value ?? []).isNotEmpty)
          SizedBox(height: r.cardSpacing + 12),

        // --- Formulario ---
        Container(
          padding: EdgeInsets.all(r.cardSpacing + 2),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(r.borderRadius),
            boxShadow: [
              BoxShadow(
                color: neon.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nueva deuda',
                style: GoogleFonts.outfit(
                  fontSize: r.subtitleFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: r.cardSpacing),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej: Prestamo ahorro, Tarjeta X',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              SizedBox(height: r.cardSpacing - 4),
              Builder(
                builder: (ctx) {
                  final tt = Theme.of(ctx);
                  final label =
                      Debt.debtTypeLabels[_selectedDebtType] ??
                      _selectedDebtType;
                  return InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tipo de deuda',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    child: PopupMenuButton<String>(
                      initialValue: _selectedDebtType,
                      onSelected: (v) => setState(() => _selectedDebtType = v),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: tt.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: tt.colorScheme.primary,
                          ),
                        ],
                      ),
                      itemBuilder: (_) => Debt.debtTypes
                          .map(
                            (t) => PopupMenuItem(
                              value: t,
                              child: Row(
                                children: [
                                  if (t == _selectedDebtType)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Icon(
                                        Icons.check,
                                        size: 18,
                                        color: tt.colorScheme.primary,
                                      ),
                                    )
                                  else
                                    const SizedBox(width: 26),
                                  Text(
                                    Debt.debtTypeLabels[t] ?? t,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: t == _selectedDebtType
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: tt.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  );
                },
              ),
              SizedBox(height: r.cardSpacing - 4),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monto total (\$)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              SizedBox(height: r.cardSpacing - 4),
              TextField(
                controller: _rateController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Interes quincenal (%)',
                  hintText: 'Ej: 5 para 5% quincenal',
                  prefixIcon: Icon(Icons.percent),
                ),
              ),
              SizedBox(height: r.cardSpacing - 4),
              Builder(
                builder: (ctx) {
                  final tt = Theme.of(ctx);
                  final label = _periodDays == 15
                      ? 'Quincenal (15 dias)'
                      : 'Mensual (30 dias)';
                  return InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Periodo de pago',
                      prefixIcon: Icon(Icons.calendar_month),
                    ),
                    child: PopupMenuButton<int>(
                      initialValue: _periodDays,
                      onSelected: (v) => setState(() => _periodDays = v),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: tt.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: tt.colorScheme.primary,
                          ),
                        ],
                      ),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 15,
                          child: Text(
                            'Quincenal (15 dias)',
                            style: TextStyle(
                              color: Color(0xFFE0E0E0),
                              fontSize: 15,
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: 30,
                          child: Text(
                            'Mensual (30 dias)',
                            style: TextStyle(
                              color: Color(0xFFE0E0E0),
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              SizedBox(height: r.cardSpacing - 4),
              TextField(
                controller: _minPaymentController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Pago minimo por periodo (\$)',
                  prefixIcon: Icon(Icons.price_check),
                ),
              ),
              SizedBox(height: r.cardSpacing - 4),
              TextField(
                controller: _graceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Dias maximo de atraso',
                  hintText: '30',
                  prefixIcon: Icon(Icons.timer),
                ),
              ),
              SizedBox(height: r.cardSpacing - 4),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha de inicio',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                ),
              ),
              SizedBox(height: r.cardSpacing + 2),
              SizedBox(
                height: r.buttonHeight,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
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
                  label: Text(_saving ? 'Guardando...' : 'Registrar deuda'),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: r.cardSpacing + 12),

        // --- Ahorro real ---
        if (widget.totalSaved > 0 && debtsAsync != null)
          Builder(
            builder: (_) {
              final debts = debtsAsync.asData?.value ?? [];
              double blocked = 0;
              double prestamoAhorro = 0;
              double atrasoAhorro = 0;
              for (final d in debts) {
                if (d.isLinkedToSavings) {
                  blocked += d.totalDebt;
                  if (d.debtType == 'prestamo_ahorro') {
                    prestamoAhorro += d.totalDebt;
                  } else if (d.debtType == 'atraso_ahorro') {
                    atrasoAhorro += d.totalDebt;
                  }
                }
              }
              final real = (widget.totalSaved - blocked).clamp(
                0,
                double.infinity,
              );
              return Container(
                width: double.infinity,
                padding: EdgeInsets.all(r.cardSpacing + 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [neon.withValues(alpha: 0.85), neon2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(r.borderRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: r.iconSizeMedium,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ahorro real',
                          style: GoogleFonts.outfit(
                            fontSize: r.subtitleFontSize,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: r.cardSpacing - 2),
                    Text(
                      '\$${real.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: r.isDesktop ? 28 : 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Ahorro total: \$${widget.totalSaved.toStringAsFixed(2)}${blocked > 0 ? ' | Bloqueado: \$${blocked.toStringAsFixed(2)}' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 1,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    if (prestamoAhorro > 0 || atrasoAhorro > 0) ...[
                      SizedBox(height: 6),
                      if (prestamoAhorro > 0)
                        Text(
                          '  - Prestamo ahorro: \$${prestamoAhorro.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: r.bodyFontSize - 2,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      if (atrasoAhorro > 0)
                        Text(
                          '  - Atraso ahorro: \$${atrasoAhorro.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: r.bodyFontSize - 2,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),

        SizedBox(height: r.cardSpacing + 12),

        // --- Lista de deudas ---
        Text(
          'Mis deudas',
          style: GoogleFonts.outfit(
            fontSize: r.subtitleFontSize + 2,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: r.cardSpacing - 4),

        if (debtsAsync == null)
          const Center(child: CircularProgressIndicator())
        else
          debtsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (debts) {
              if (debts.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(r.borderRadius),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.account_balance_outlined,
                          size: r.iconSizeLarge,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No hay deudas registradas',
                          style: GoogleFonts.inter(
                            fontSize: r.bodyFontSize,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: debts.length,
                separatorBuilder: (_, i) => SizedBox(height: r.cardSpacing - 8),
                itemBuilder: (context, index) {
                  final debt = debts[index];
                  final isExpanded = _expandedDebtId == debt.id;
                  final totalDebt = debt.totalDebt;
                  final daysDelayed = debt.actualDaysDelayed;
                  final isLate = daysDelayed > 0;
                  final isCritical = debt.exceededGrace;
                  // Solo azul: variamos intensidad
                  final borderColor = isCritical
                      ? neon
                      : isLate
                      ? neon2
                      : neon3;

                  return Material(
                    color: surface,
                    borderRadius: BorderRadius.circular(r.borderRadius),
                    child: Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(r.borderRadius),
                          onTap: () => setState(() {
                            _expandedDebtId = isExpanded ? null : debt.id;
                          }),
                          child: Padding(
                            padding: EdgeInsets.all(r.cardSpacing),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: r.isDesktop ? 50 : 44,
                                      height: r.isDesktop ? 50 : 44,
                                      decoration: BoxDecoration(
                                        color: borderColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        isCritical
                                            ? Icons.warning_amber_rounded
                                            : Icons.account_balance_outlined,
                                        color: borderColor,
                                        size: r.iconSizeMedium - 4,
                                      ),
                                    ),
                                    SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  debt.name,
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: r.bodyFontSize,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '\$${totalDebt.toStringAsFixed(2)}',
                                                style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: r.bodyFontSize,
                                                  color: borderColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              _StatusChip(
                                                label:
                                                    Debt.debtTypeLabels[debt
                                                        .debtType] ??
                                                    debt.debtType,
                                                color: neon,
                                              ),
                                              _StatusChip(
                                                label:
                                                    'Saldo: \$${debt.currentBalance.toStringAsFixed(0)}',
                                                color: neon2,
                                              ),
                                              if (debt.interestRate > 0)
                                                _StatusChip(
                                                  label:
                                                      'Int: ${debt.interestRate.toStringAsFixed(1)}% /qna',
                                                  color: neon,
                                                ),
                                              _StatusChip(
                                                label:
                                                    'Pago min: \$${debt.minPayment.toStringAsFixed(0)}',
                                                color: neon3,
                                              ),
                                              if (isCritical)
                                                _StatusChip(
                                                  label:
                                                      'Excedido! ${daysDelayed}d',
                                                  color: neon,
                                                )
                                              else if (isLate)
                                                _StatusChip(
                                                  label:
                                                      'Atraso: ${daysDelayed}d',
                                                  color: neon2,
                                                )
                                              else
                                                _StatusChip(
                                                  label: 'Al dia',
                                                  color: neon3,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded) _PaymentsSection(debt: debt, r: r),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        SizedBox(height: 40),
      ],
    );

    if (widget.compact) {
      return SingleChildScrollView(padding: EdgeInsets.zero, child: content);
    }
    return content;
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _PaymentsSection extends ConsumerWidget {
  final Debt debt;
  final ResponsiveHelper r;

  const _PaymentsSection({required this.debt, required this.r});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(debtPaymentsProvider(debt.id));
    final theme = Theme.of(context);
    final neon = theme.colorScheme.primary;
    final neon3 = theme.colorScheme.tertiary;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return Container(
      padding: EdgeInsets.fromLTRB(
        r.cardSpacing,
        0,
        r.cardSpacing,
        r.cardSpacing,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: theme.dividerColor),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Detalle de la deuda',
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize - 2,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
              Text(
                'Prox pago: ${DateFormat('dd/MM').format(debt.nextPaymentDue)}',
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize - 2,
                  color: muted,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          _InfoRow(
            'Deuda original',
            '\$${debt.initialAmount.toStringAsFixed(2)}',
          ),
          _InfoRow(
            'Saldo actual',
            '\$${debt.currentBalance.toStringAsFixed(2)}',
          ),
          if (debt.interestRate > 0) ...[
            _InfoRow(
              'Interes quincenal',
              '${debt.interestRate.toStringAsFixed(1)}%',
            ),
            _InfoRow(
              'Interes acumulado',
              '\$${debt.accruedInterest.toStringAsFixed(2)}',
            ),
          ],
          _InfoRow('Cuotas minimas debidas', '${debt.periodsDue}'),
          _InfoRow(
            'Pago minimo por periodo',
            '\$${debt.minPayment.toStringAsFixed(2)}',
          ),
          _InfoRow(
            'Total minimo adeudado',
            '\$${debt.totalMinPaymentDue.toStringAsFixed(2)}',
          ),
          SizedBox(height: 8),
          Text(
            'Historial de pagos',
            style: GoogleFonts.inter(
              fontSize: r.bodyFontSize - 2,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
          SizedBox(height: 4),
          paymentsAsync.when(
            loading: () => const SizedBox(
              height: 30,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text('Error: $e'),
            data: (payments) {
              if (payments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Sin pagos registrados',
                    style: GoogleFonts.inter(fontSize: 11, color: muted),
                  ),
                );
              }
              return Column(
                children: payments.take(5).map((p) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: neon3,
                        ),
                        SizedBox(width: 8),
                        Text(
                          DateFormat('dd/MM/yyyy').format(p.paymentDate),
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                        Spacer(),
                        Text(
                          '-\$${p.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: neon,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () {
                final state = context
                    .findAncestorStateOfType<_DebtsContentState>();
                state?._addPayment(debt);
              },
              icon: const Icon(Icons.payment, size: 16),
              label: Text(
                'Registrar pago',
                style: GoogleFonts.inter(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: muted)),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
