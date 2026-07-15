import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/openai_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/money_record.dart';

final moneyRecordsProvider = FutureProvider.family<List<MoneyRecord>, String>(
  (ref, userId) => ref.watch(databaseServiceProvider).getMoneyRecords(userId),
);

final totalSavedProvider = FutureProvider.family<double, String>(
  (ref, userId) => ref.watch(databaseServiceProvider).getTotalSaved(userId),
);

final totalDailyEarningsProvider = FutureProvider.family<double, String>(
  (ref, userId) =>
      ref.watch(databaseServiceProvider).getTotalDailyEarnings(userId),
);

const moneyTypes = ['Ahorro', 'Inversion', 'Meta financiera'];

class MoneyTrackingScreen extends ConsumerStatefulWidget {
  final bool compact;
  const MoneyTrackingScreen({super.key, this.compact = true});
  @override
  ConsumerState<MoneyTrackingScreen> createState() =>
      _MoneyTrackingScreenState();
}

class _MoneyTrackingScreenState extends ConsumerState<MoneyTrackingScreen> {
  String _selectedType = moneyTypes.first;
  final _amountController = TextEditingController();
  final _yieldController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;
  bool _scanning = false;
  String? _editingRecordId;

  @override
  void dispose() {
    _amountController.dispose();
    _yieldController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _scanReceipt() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() => _scanning = true);
    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final openAI = OpenAIService();
      final items = await openAI.extractReceiptData(base64Image);

      if (items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontraron productos en el ticket'),
            ),
          );
        }
        return;
      }

      if (mounted) {
        _showScannedItemsDialog(items);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al escanear: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  void _showScannedItemsDialog(List<Map<String, dynamic>> items) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Productos detectados'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(item['name'] ?? 'Desconocido'),
                  trailing: Text('\$${item['price']}'),
                  onTap: () {
                    setState(() {
                      _descController.text = item['name'];
                      _amountController.text = item['price'].toString();
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _save() async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa un monto valido')));
      return;
    }
    final yieldVal = double.tryParse(_yieldController.text.trim()) ?? 0;

    setState(() => _saving = true);
    final record = MoneyRecord(
      id:
          _editingRecordId ??
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      type: _selectedType,
      amount: amount,
      annualYield: yieldVal,
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      date: _selectedDate,
    );

    if (_editingRecordId != null) {
      await ref.read(databaseServiceProvider).updateMoney(record);
    } else {
      await ref.read(databaseServiceProvider).insertMoney(record);
    }

    ref.invalidate(moneyRecordsProvider(user.id));
    ref.invalidate(totalSavedProvider(user.id));
    ref.invalidate(totalDailyEarningsProvider(user.id));
    setState(() {
      _saving = false;
      _editingRecordId = null;
      _selectedType = moneyTypes.first;
      _amountController.clear();
      _yieldController.clear();
      _descController.clear();
      _selectedDate = DateTime.now();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editingRecordId != null
                ? 'Registro actualizado'
                : 'Registro guardado',
          ),
        ),
      );
    }
  }

  void _editRecord(MoneyRecord record) {
    setState(() {
      _editingRecordId = record.id;
      _selectedType = record.type;
      _amountController.text = record.amount.toString();
      _yieldController.text = record.annualYield.toString();
      _descController.text = record.description ?? '';
      _selectedDate = record.date;
    });

    // Hacer scroll hacia arriba para ver el formulario
    Scrollable.ensureVisible(
      context,
      alignment: 0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _cancelEdit() {
    setState(() {
      _editingRecordId = null;
      _selectedType = moneyTypes.first;
      _amountController.clear();
      _yieldController.clear();
      _descController.clear();
      _selectedDate = DateTime.now();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Fecha del registro',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final recordsAsync = user != null
        ? ref.watch(moneyRecordsProvider(user.id))
        : null;
    final totalAsync = user != null
        ? ref.watch(totalSavedProvider(user.id))
        : null;
    final dailyEarningsAsync = user != null
        ? ref.watch(totalDailyEarningsProvider(user.id))
        : null;
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final neon = theme.colorScheme.primary;
    final neon2 = theme.colorScheme.secondary;
    final neon3 = theme.colorScheme.tertiary;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Finanzas Personales',
          style: GoogleFonts.outfit(
            fontSize: r.titleFontSize,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Controla tus ahorros, inversiones y rendimientos.',
          style: GoogleFonts.inter(
            fontSize: r.subtitleFontSize,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        SizedBox(height: r.cardSpacing + 4),

        // --- Cards de resumen ---
        if (totalAsync != null && dailyEarningsAsync != null)
          Builder(
            builder: (_) {
              final total = totalAsync.asData?.value ?? 0;
              final daily = dailyEarningsAsync.asData?.value ?? 0;
              final cols = r.statColumns;
              return Wrap(
                spacing: r.cardSpacing - 4,
                runSpacing: r.cardSpacing - 4,
                children: [
                  SizedBox(
                    width: _cardWidth(context, cols),
                    child: _SummaryCard(
                      r: r,
                      title: 'Total ahorrado',
                      value: '\$${total.toStringAsFixed(2)}',
                      icon: Icons.account_balance_wallet,
                      color: neon,
                    ),
                  ),
                  SizedBox(
                    width: _cardWidth(context, cols),
                    child: _SummaryCard(
                      r: r,
                      title: 'Ganancia diaria',
                      value: '\$${daily.toStringAsFixed(4)}',
                      subtitle: '/ dia',
                      icon: Icons.trending_up,
                      color: neon2,
                    ),
                  ),
                  SizedBox(
                    width: _cardWidth(context, cols),
                    child: _SummaryCard(
                      r: r,
                      title: 'Rendimiento anual',
                      value: '\$${(daily * 365).toStringAsFixed(2)}',
                      subtitle: 'estimado',
                      icon: Icons.show_chart,
                      color: neon3,
                    ),
                  ),
                ],
              );
            },
          ),

        SizedBox(height: r.cardSpacing + 6),

        // --- Formulario ---
        Container(
          padding: EdgeInsets.all(r.cardSpacing + 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nuevo registro',
                    style: GoogleFonts.outfit(
                      fontSize: r.subtitleFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_scanning)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.document_scanner_outlined),
                      color: neon,
                      tooltip: 'Escanear ticket',
                      onPressed: _scanReceipt,
                    ),
                ],
              ),
              SizedBox(height: r.cardSpacing),
              Builder(
                builder: (ctx) {
                  final tt = Theme.of(ctx);
                  return InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    child: PopupMenuButton<String>(
                      initialValue: _selectedType,
                      onSelected: (v) => setState(() => _selectedType = v),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedType,
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
                      itemBuilder: (_) => moneyTypes
                          .map(
                            (t) => PopupMenuItem(
                              value: t,
                              child: Row(
                                children: [
                                  if (t == _selectedType)
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
                                    t,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: t == _selectedType
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
                  labelText: 'Monto (\$)',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              SizedBox(height: r.cardSpacing - 4),
              TextField(
                controller: _yieldController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Rendimiento anual (%)',
                  hintText: 'Ej: 10.5 para 10.5%',
                  prefixIcon: Icon(Icons.percent),
                ),
              ),
              SizedBox(height: r.cardSpacing - 4),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                ),
              ),
              SizedBox(height: r.cardSpacing - 4),
              TextField(
                controller: _descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripcion (opcional)',
                  hintText: 'Ej: Ahorro de la quincena',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              SizedBox(height: r.cardSpacing + 2),
              Row(
                children: [
                  if (_editingRecordId != null) ...[
                    Expanded(
                      child: SizedBox(
                        height: r.buttonHeight,
                        child: OutlinedButton(
                          onPressed: _cancelEdit,
                          child: const Text('Cancelar'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    flex: 2,
                    child: SizedBox(
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
                            : Icon(
                                _editingRecordId != null
                                    ? Icons.save_as
                                    : Icons.save,
                              ),
                        label: Text(
                          _saving
                              ? 'Guardando...'
                              : (_editingRecordId != null
                                    ? 'Actualizar'
                                    : 'Guardar registro'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: r.cardSpacing + 12),

        // --- Historial ---
        Text(
          'Historial',
          style: GoogleFonts.outfit(
            fontSize: r.subtitleFontSize + 2,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: r.cardSpacing - 4),

        if (recordsAsync == null)
          const Center(child: CircularProgressIndicator())
        else
          recordsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (records) {
              if (records.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(r.borderRadius),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.savings_outlined,
                          size: r.iconSizeLarge,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No hay registros de dinero',
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
                itemCount: records.length,
                separatorBuilder: (_, i) => SizedBox(height: r.cardSpacing - 8),
                itemBuilder: (context, index) {
                  final rec = records[index];
                  return Material(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(r.borderRadius),
                    child: Padding(
                      padding: EdgeInsets.all(r.cardSpacing),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: r.isDesktop ? 50 : 44,
                            height: r.isDesktop ? 50 : 44,
                            decoration: BoxDecoration(
                              color: neon.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.trending_up,
                              color: neon,
                              size: r.iconSizeMedium,
                            ),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      rec.type,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: r.bodyFontSize,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '\$${rec.amount.toStringAsFixed(2)}',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: r.bodyFontSize,
                                        color: neon,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 2,
                                  children: [
                                    Text(
                                      DateFormat('dd/MM/yyyy').format(rec.date),
                                      style: GoogleFonts.inter(
                                        fontSize: r.bodyFontSize - 2,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    if (rec.annualYield > 0) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: neon2.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '${rec.annualYield.toStringAsFixed(1)}%',
                                          style: GoogleFonts.inter(
                                            fontSize: r.bodyFontSize - 3,
                                            fontWeight: FontWeight.w600,
                                            color: neon2,
                                          ),
                                        ),
                                      ),
                                      if (rec.dailyEarnings > 0)
                                        Text(
                                          '+\$${rec.dailyEarnings.toStringAsFixed(4)}/dia',
                                          style: GoogleFonts.inter(
                                            fontSize: r.bodyFontSize - 3,
                                            color: neon2.withValues(alpha: 0.7),
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                                if (rec.description != null &&
                                    rec.description!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      rec.description!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: r.bodyFontSize - 2,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  color: neon2,
                                  size: 20,
                                ),
                                onPressed: () => _editRecord(rec),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: neon,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  if (user == null) return;
                                  await ref
                                      .read(databaseServiceProvider)
                                      .deleteMoney(rec.id);
                                  ref.invalidate(moneyRecordsProvider(user.id));
                                  ref.invalidate(totalSavedProvider(user.id));
                                  ref.invalidate(
                                    totalDailyEarningsProvider(user.id),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        const SizedBox(height: 40),
      ],
    );

    if (widget.compact) {
      return SingleChildScrollView(padding: r.pagePadding, child: content);
    }
    return Padding(padding: r.pagePadding, child: content);
  }

  double _cardWidth(BuildContext context, int cols) {
    final screenW = MediaQuery.of(context).size.width;
    final padding = ResponsiveHelper(context).pagePadding;
    final padTotal = (padding.left + padding.right);
    final gaps = (cols - 1) * (ResponsiveHelper(context).cardSpacing - 4);
    return (screenW - padTotal - gaps) / cols;
  }
}

class _SummaryCard extends StatelessWidget {
  final ResponsiveHelper r;
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.r,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(r.cardSpacing + 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(r.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: r.iconSizeMedium),
          SizedBox(height: r.cardSpacing - 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: r.isDesktop ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 2),
          Text(
            subtitle != null ? '$title $subtitle' : title,
            style: GoogleFonts.inter(
              fontSize: r.bodyFontSize - 1,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
