import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/money_record.dart';

final moneyRecordsProvider = FutureProvider.family<List<MoneyRecord>, String>((ref, userId) {
  return ref.watch(databaseServiceProvider).getMoneyRecords(userId);
});

final totalSavedProvider = FutureProvider.family<double, String>((ref, userId) {
  return ref.watch(databaseServiceProvider).getTotalSaved(userId);
});

final moneyTypes = const ['Ahorro', 'Inversion', 'Meta financiera'];

class MoneyTrackingScreen extends ConsumerStatefulWidget {
  const MoneyTrackingScreen({super.key});
  @override ConsumerState<MoneyTrackingScreen> createState() => _MoneyTrackingScreenState();
}

class _MoneyTrackingScreenState extends ConsumerState<MoneyTrackingScreen> {
  String _selectedType = moneyTypes.first;
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  @override void dispose() { _amountController.dispose(); _descController.dispose(); super.dispose(); }

  Future<void> _save() async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa un monto valido')));
      return;
    }
    setState(() => _saving = true);
    final record = MoneyRecord(
      id: '${user.id}_${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id, type: _selectedType, amount: amount,
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(), date: _selectedDate,
    );
    await ref.read(databaseServiceProvider).insertMoney(record);
    ref.invalidate(moneyRecordsProvider(user.id));
    ref.invalidate(totalSavedProvider(user.id));
    setState(() { _saving = false; _selectedType = moneyTypes.first; _amountController.clear(); _descController.clear(); _selectedDate = DateTime.now(); });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registro guardado')));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now(), helpText: 'Fecha del registro');
    if (picked != null && picked != _selectedDate) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final recordsAsync = user != null ? ref.watch(moneyRecordsProvider(user.id)) : null;
    final totalAsync = user != null ? ref.watch(totalSavedProvider(user.id)) : null;
    final theme = Theme.of(context);
    final userData = user;
    final r = ResponsiveHelper(context);

    return SingleChildScrollView(
      padding: r.pagePadding,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Finanzas Personales', style: GoogleFonts.outfit(fontSize: r.titleFontSize, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        SizedBox(height: 6),
        Text('Lleva el control de tus ahorros e inversiones.', style: GoogleFonts.inter(fontSize: r.subtitleFontSize, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        SizedBox(height: r.cardSpacing + 4),

        if (totalAsync != null) totalAsync.when(
          loading: () => const SizedBox(), error: (_, __) => const SizedBox(),
          data: (total) => Container(
            width: double.infinity,
            padding: EdgeInsets.all(r.isDesktop ? 28 : 24),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF228B22).withValues(alpha: 0.8), const Color(0xFF228B22)]), borderRadius: BorderRadius.circular(r.borderRadius)),
            child: Column(children: [
              Text('Total ahorrado', style: GoogleFonts.inter(fontSize: r.bodyFontSize - 1, color: Colors.white.withValues(alpha: 0.8))),
              SizedBox(height: 6),
              Text('\$${total.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: r.titleFontSize + 10, fontWeight: FontWeight.bold, color: Colors.white)),
            ]),
          ),
        ),

        SizedBox(height: r.cardSpacing + 4),

        Container(
          padding: EdgeInsets.all(r.cardSpacing + 2),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(r.borderRadius), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Nuevo registro', style: GoogleFonts.outfit(fontSize: r.subtitleFontSize, fontWeight: FontWeight.w600)),
            SizedBox(height: r.cardSpacing),
            DropdownButtonFormField<String>(value: _selectedType, decoration: const InputDecoration(labelText: 'Tipo', prefixIcon: Icon(Icons.category_outlined)), items: moneyTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (v) { if (v != null) setState(() => _selectedType = v); }),
            SizedBox(height: r.cardSpacing - 4),
            TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monto (\$)', hintText: '0.00', prefixIcon: Icon(Icons.attach_money))),
            SizedBox(height: r.cardSpacing - 4),
            InkWell(onTap: _pickDate, child: InputDecorator(decoration: const InputDecoration(labelText: 'Fecha', prefixIcon: Icon(Icons.calendar_today)), child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)))),
            SizedBox(height: r.cardSpacing - 4),
            TextField(controller: _descController, maxLines: 2, decoration: const InputDecoration(labelText: 'Descripcion (opcional)', hintText: 'Ej: Ahorro de la quincena', prefixIcon: Icon(Icons.notes))),
            SizedBox(height: r.cardSpacing + 2),
            SizedBox(height: r.buttonHeight, child: ElevatedButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save), label: Text(_saving ? 'Guardando...' : 'Guardar registro'))),
          ]),
        ),

        SizedBox(height: r.cardSpacing + 12),
        Text('Historial', style: GoogleFonts.outfit(fontSize: r.subtitleFontSize + 2, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
        SizedBox(height: r.cardSpacing - 4),

        if (recordsAsync == null) const Center(child: CircularProgressIndicator())
        else recordsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (records) {
            if (records.isEmpty) return Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(r.borderRadius)), child: Center(child: Column(children: [Icon(Icons.savings_outlined, size: r.iconSizeLarge, color: Colors.grey), SizedBox(height: 12), Text('No hay registros de dinero', style: GoogleFonts.inter(fontSize: r.bodyFontSize, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)))])));
            return ListView.separated(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: records.length, separatorBuilder: (_, __) => SizedBox(height: r.cardSpacing - 8),
              itemBuilder: (context, index) {
                final rec = records[index];
                final isPositive = rec.type == 'Ahorro' || rec.type == 'Inversion';
                return Material(color: Colors.white, borderRadius: BorderRadius.circular(r.borderRadius), child: Padding(padding: EdgeInsets.all(r.cardSpacing), child: Row(children: [
                  Container(width: r.isDesktop ? 50 : 44, height: r.isDesktop ? 50 : 44, decoration: BoxDecoration(color: (isPositive ? const Color(0xFF228B22) : Colors.orange).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(isPositive ? Icons.trending_up : Icons.trending_down, color: isPositive ? const Color(0xFF228B22) : Colors.orange, size: r.iconSizeMedium)),
                  SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Text(rec.type, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: r.bodyFontSize)), const Spacer(), Text('\$${rec.amount.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: r.bodyFontSize, color: isPositive ? const Color(0xFF228B22) : Colors.orange))]),
                    Text(DateFormat('dd/MM/yyyy').format(rec.date), style: GoogleFonts.inter(fontSize: r.bodyFontSize - 2, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                    if (rec.description != null && rec.description!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(rec.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: r.bodyFontSize - 2, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)))),
                  ])),
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () async { if (userData == null) return; await ref.read(databaseServiceProvider).deleteMoney(rec.id); ref.invalidate(moneyRecordsProvider(userData.id)); ref.invalidate(totalSavedProvider(userData.id)); }),
                ])));
              },
            );
          },
        ),
        SizedBox(height: 40),
      ]),
    );
  }
}
