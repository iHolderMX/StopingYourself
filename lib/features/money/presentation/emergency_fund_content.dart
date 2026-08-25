import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/emergency_fund.dart';
import '../application/emergency_funds_controller.dart';
import '../application/money_error_message.dart';
import '../data/money_providers.dart';
import '../domain/emergency_fund_rules.dart';
import '../domain/yield_rules.dart';

class EmergencyFundContent extends ConsumerStatefulWidget {
  final bool compact;
  const EmergencyFundContent({super.key, this.compact = true});

  @override
  ConsumerState<EmergencyFundContent> createState() =>
      _EmergencyFundContentState();
}

class _EmergencyFundContentState extends ConsumerState<EmergencyFundContent> {
  String? _expandedFundId;

  // ── Crear fondo ──
  Future<void> _showCreateDialog() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final moneyRecordsAsync = ref.read(moneyRecordsProvider(userId));
    final records = moneyRecordsAsync.asData?.value ?? [];
    final noRecords = records.isEmpty;

    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String? selectedRecordId;
    double selectedYield = 0;
    final formKey = GlobalKey<FormState>();

    await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialog) {
            return AlertDialog(
              title: Text(
                'Nuevo Fondo de Emergencia',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (noRecords)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: Colors.amber,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Primero crea un ahorro o inversion en '
                                  'Finanzas Personales para usarlo como origen.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRecordId,
                        decoration: const InputDecoration(
                          labelText: 'Ahorro / Inversion origen',
                          prefixIcon: Icon(Icons.savings_outlined),
                        ),
                        items: records.map((r) {
                          return DropdownMenuItem(
                            value: r.id,
                            child: Text(
                              '${r.type}: ${r.description ?? ''} '
                              '(\$${r.amount.toStringAsFixed(0)})',
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setDialog(() => selectedRecordId = v);
                          if (v != null) {
                            final rec = records
                                .where((r) => r.id == v)
                                .firstOrNull;
                            selectedYield = rec?.annualYield ?? 0;
                          }
                        },
                        validator: (v) =>
                            v == null ? 'Selecciona un origen' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del fondo',
                          prefixIcon: Icon(Icons.emergency_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                        autofocus: true,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: amountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Monto',
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
                      // Mostrar rendimiento del ahorro origen
                      if (selectedRecordId != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.trending_up,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                selectedYield > 0
                                    ? 'Rendimiento: ${selectedYield.toStringAsFixed(1)}% anual'
                                    : 'Sin rendimiento registrado',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: selectedYield > 0
                                      ? Colors.green
                                      : Theme.of(
                                          ctx,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                  label: const Text('Crear'),
                  onPressed: noRecords
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await ref
                                .read(emergencyFundsControllerProvider)
                                .createFund(
                                  userId: userId,
                                  name: nameCtrl.text,
                                  sourceRecordId: selectedRecordId!,
                                  amount: double.parse(amountCtrl.text.trim()),
                                  annualYield: selectedYield,
                                );
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (error) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(describeMoneyError(error)),
                              ),
                            );
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
    // El controller refresco los fondos al crear.
  }

  // ── Dividir / Reclasificar fondo en entries ──
  Future<void> _showSplitDialog(EmergencyFund fund) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    // Cargar entries existentes (solo para mostrar disponible en el dialogo;
    // el controller vuelve a leerlas y valida antes de guardar).
    final existing = await ref
        .read(emergencyFundsRepositoryProvider)
        .fetchEntries(fund.id);
    if (!mounted) return;

    final usedAmount = EmergencyFundRules.classifiedAmount(existing);
    final available = EmergencyFundRules.availableToSplit(
      fund: fund,
      entries: existing,
    );

    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final yieldCtrl = TextEditingController(text: fund.annualYield.toString());
    final formKey = GlobalKey<FormState>();

    await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'Dividir: ${fund.name}',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total del fondo: \$${fund.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (existing.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Ya clasificado: \$${usedAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  Text(
                    'Disponible: \$${available.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.green),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la division',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Monto',
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
                      if (n > available) {
                        return 'Excede disponible (\$${available.toStringAsFixed(2)})';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: yieldCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Rendimiento anual (%)',
                      prefixIcon: Icon(Icons.trending_up),
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
              icon: const Icon(Icons.call_split, size: 18),
              label: const Text('Dividir'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref
                      .read(emergencyFundsControllerProvider)
                      .splitFund(
                        userId: userId,
                        fund: fund,
                        name: nameCtrl.text,
                        amount: double.parse(amountCtrl.text.trim()),
                        annualYield: double.tryParse(yieldCtrl.text.trim()) ?? 0,
                      );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (error) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(describeMoneyError(error))),
                  );
                }
              },
            ),
          ],
        );
      },
    );
    // El controller refresco fondos y divisiones al dividir.
  }

  // ── Eliminar entry ──
  Future<void> _deleteEntry(
    EmergencyFund fund,
    EmergencyFundEntry entry,
  ) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      await ref.read(emergencyFundsControllerProvider).deleteEntry(
        userId: userId,
        fundId: fund.id,
        entryId: entry.id,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeMoneyError(error))));
      }
    }
  }

  // ── Eliminar fondo ──
  Future<void> _deleteFund(EmergencyFund fund) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar fondo'),
        content: Text(
          'Seguro que quieres eliminar "${fund.name}" y todas sus divisiones?',
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
    if (confirm != true) return;
    try {
      await ref
          .read(emergencyFundsControllerProvider)
          .deleteFund(userId: userId, fundId: fund.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeMoneyError(error))));
      }
    }
  }

  // ──────────────────────────────────────────────
  // UI
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final userId = ref.watch(currentUserIdProvider);

    final fundsAsync = userId != null
        ? ref.watch(emergencyFundsProvider(userId))
        : null;
    final funds = fundsAsync?.asData?.value ?? const <EmergencyFund>[];
    final isLoading = fundsAsync?.isLoading == true;
    final hasError = fundsAsync?.hasError == true;

    final totalAmount = EmergencyFundRules.totalAmount(funds);
    final dailyEarnings = YieldRules.totalDailyEarningsOfFunds(funds);

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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.emergency_rounded,
                  color: Colors.amber,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Fondo de Emergencia',
                style: GoogleFonts.outfit(
                  fontSize: r.subtitleFontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  'Crear fondo',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _showCreateDialog,
              ),
            ],
          ),
          SizedBox(height: r.cardSpacing),

          // Resumen
          if (funds.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(r.cardSpacing - 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _miniStat(
                      'Total fondos',
                      '\$${totalAmount.toStringAsFixed(0)}',
                      theme,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.2,
                    ),
                  ),
                  Expanded(
                    child: _miniStat(
                      'Rendimiento diario',
                      '\$${dailyEarnings.toStringAsFixed(2)}',
                      theme,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.cardSpacing),
          ],

          // Lista
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (hasError)
            _buildErrorState(theme, userId!)
          else if (funds.isEmpty)
            _buildEmptyState(theme, r)
          else
            ...funds.map((f) => _buildFundCard(theme, r, f)),
        ],
      ),
    );
  }

  Widget _miniStat(
    String label,
    String value,
    ThemeData theme, {
    Color? color,
  }) {
    return Column(
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
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, ResponsiveHelper r) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: r.padVertical),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.emergency_outlined, size: 40, color: Colors.amber),
          const SizedBox(height: 8),
          Text(
            'Sin fondos de emergencia',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Crear primer fondo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber.shade700,
            ),
            onPressed: _showCreateDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String userId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 32, color: theme.colorScheme.error),
          const SizedBox(height: 8),
          Text(
            'Error de conexion con la BD',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 4),
          Text(
            'Verifica los permisos RLS en Supabase.',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reintentar'),
            onPressed: () => ref.invalidate(emergencyFundsProvider(userId)),
          ),
        ],
      ),
    );
  }

  Widget _buildFundCard(
    ThemeData theme,
    ResponsiveHelper r,
    EmergencyFund fund,
  ) {
    final isExpanded = _expandedFundId == fund.id;
    final entriesAsync = ref.watch(emergencyFundEntriesProvider(fund.id));
    final entries = entriesAsync.asData?.value ?? const <EmergencyFundEntry>[];
    final entriesTotal = entries.fold(0.0, (s, e) => s + e.amount);

    return Container(
      margin: EdgeInsets.only(bottom: r.cardSpacing - 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isExpanded
              ? Colors.amber.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            onTap: () =>
                setState(() => _expandedFundId = isExpanded ? null : fund.id),
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
                            Text(
                              fund.name,
                              style: GoogleFonts.inter(
                                fontSize: r.bodyFontSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\$${fund.amount.toStringAsFixed(2)} | '
                              '${fund.annualYield > 0 ? '${fund.annualYield.toStringAsFixed(1)}% rend.' : 'sin rendimiento'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_horiz,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (v) async {
                          if (v == 'split') _showSplitDialog(fund);
                          if (v == 'delete') _deleteFund(fund);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'split',
                            child: Row(
                              children: [
                                Icon(Icons.call_split, size: 18),
                                SizedBox(width: 8),
                                Text('Dividir'),
                              ],
                            ),
                          ),
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
                  if (fund.dailyEarnings > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.trending_up,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '\$${fund.dailyEarnings.toStringAsFixed(2)}/dia',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (entries.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fund.amount > 0 ? entriesTotal / fund.amount : 0,
                        minHeight: 4,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: const AlwaysStoppedAnimation(Colors.amber),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entries.length} divisiones (\$${entriesTotal.toStringAsFixed(0)} de \$${fund.amount.toStringAsFixed(0)})',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
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

          // Entries expandibles
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildEntriesList(theme, r, fund, entries),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList(
    ThemeData theme,
    ResponsiveHelper r,
    EmergencyFund fund,
    List<EmergencyFundEntry> entries,
  ) {
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
          Row(
            children: [
              Text(
                'Divisiones',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Nueva', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                ),
                onPressed: () => _showSplitDialog(fund),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Text(
              'Sin divisiones. Divide tu fondo en partes mas pequenas.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (e.annualYield > 0)
                            Text(
                              '${e.annualYield.toStringAsFixed(1)}% rend.',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '\$${e.amount.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _deleteEntry(fund, e),
                      child: Icon(
                        Icons.close,
                        size: 16,
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
}
