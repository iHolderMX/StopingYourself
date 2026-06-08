import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../models/money_record.dart';

final moneyRecordsProvider = FutureProvider.family<List<MoneyRecord>, String>((
  ref,
  userId,
) {
  return ref.watch(databaseServiceProvider).getMoneyRecords(userId);
});

final totalSavedProvider = FutureProvider.family<double, String>((ref, userId) {
  return ref.watch(databaseServiceProvider).getTotalSaved(userId);
});

final moneyTypes = const ['Ahorro', 'Inversion', 'Meta financiera'];

class MoneyTrackingScreen extends ConsumerStatefulWidget {
  const MoneyTrackingScreen({super.key});

  @override
  ConsumerState<MoneyTrackingScreen> createState() =>
      _MoneyTrackingScreenState();
}

class _MoneyTrackingScreenState extends ConsumerState<MoneyTrackingScreen> {
  String _selectedType = moneyTypes.first;
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
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

    setState(() => _saving = true);

    final record = MoneyRecord(
      id: '${user.id}_${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      type: _selectedType,
      amount: amount,
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      date: _selectedDate,
    );

    await ref.read(databaseServiceProvider).insertMoney(record);
    ref.invalidate(moneyRecordsProvider(user.id));
    ref.invalidate(totalSavedProvider(user.id));

    setState(() {
      _saving = false;
      _selectedType = moneyTypes.first;
      _amountController.clear();
      _descController.clear();
      _selectedDate = DateTime.now();
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registro guardado')));
    }
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
    final theme = Theme.of(context);
    final userData = user;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Finanzas Personales',
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lleva el control de tus ahorros e inversiones.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),

          // --- Total ahorrado ---
          if (totalAsync != null)
            totalAsync.when(
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
              data: (total) => Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF228B22).withValues(alpha: 0.8),
                      const Color(0xFF228B22),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Total ahorrado',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '\$${total.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),

          // --- Formulario ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nuevo registro',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: moneyTypes.map((t) {
                    return DropdownMenuItem(value: t, child: Text(t));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedType = v);
                  },
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descripcion (opcional)',
                    hintText: 'Ej: Ahorro de la quincena',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'Guardando...' : 'Guardar registro'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // --- Historial ---
          Text(
            'Historial',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.savings_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No hay registros de dinero',
                            style: GoogleFonts.inter(
                              fontSize: 14,
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
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final r = records[index];
                    final isPositive =
                        r.type == 'Ahorro' || r.type == 'Inversion';
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color:
                                    (isPositive
                                            ? const Color(0xFF228B22)
                                            : Colors.orange)
                                        .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isPositive
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                color: isPositive
                                    ? const Color(0xFF228B22)
                                    : Colors.orange,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        r.type,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '\$${r.amount.toStringAsFixed(2)}',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isPositive
                                              ? const Color(0xFF228B22)
                                              : Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    DateFormat('dd/MM/yyyy').format(r.date),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  if (r.description != null &&
                                      r.description!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        r.description!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () async {
                                if (userData == null) return;
                                await ref
                                    .read(databaseServiceProvider)
                                    .deleteMoney(r.id);
                                ref.invalidate(
                                  moneyRecordsProvider(userData.id),
                                );
                                ref.invalidate(totalSavedProvider(userData.id));
                              },
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
      ),
    );
  }
}
