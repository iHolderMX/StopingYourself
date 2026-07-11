import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/lol_record.dart';

class LoLTrackingScreen extends ConsumerStatefulWidget {
  const LoLTrackingScreen({super.key});

  @override
  ConsumerState<LoLTrackingScreen> createState() => _LoLTrackingScreenState();
}

class _LoLTrackingScreenState extends ConsumerState<LoLTrackingScreen> {
  final _plGainedController = TextEditingController();
  final _plLostController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (date != null) {
      setState(() {
        _selectedDate = DateTime(
          date.year,
          date.month,
          date.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _saveRecord() async {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    if (user == null) return;

    final plGained =
        double.tryParse(_plGainedController.text.replaceAll(',', '.')) ?? 0;
    final plLost =
        double.tryParse(_plLostController.text.replaceAll(',', '.')) ?? 0;

    final record = LolRecord(
      id: const Uuid().v4(),
      userId: user.id,
      plGained: plGained,
      plLost: plLost,
      recordDate: _selectedDate,
    );

    try {
      await ref.read(databaseServiceProvider).insertLolRecord(record);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro guardado correctamente')),
        );
        _plGainedController.clear();
        _plLostController.clear();
        setState(() {
          _selectedDate = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    }
  }

  Future<void> _deleteRecord(String id) async {
    try {
      await ref.read(databaseServiceProvider).deleteLolRecord(id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Registro eliminado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final user = ref.watch(supabaseClientProvider).auth.currentUser;

    AsyncValue<List<LolRecord>> recordsAsync;
    AsyncValue<double> totalNetAsync;

    if (user != null) {
      recordsAsync = ref.watch(_lolRecordsProvider(user.id));
      totalNetAsync = ref.watch(_totalNetPlProvider(user.id));
    } else {
      recordsAsync = const AsyncData([]);
      totalNetAsync = const AsyncData(0.0);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.padHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título y resumen
          Text(
            'Modo Juegos',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: r.cardSpacing),
          Text(
            'League of Legends',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: r.cardSpacing),

          // Tarjeta de resumen
          SizedBox(
            width: double.infinity,
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.borderRadius),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(r.padHorizontal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balance Total',
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 8),
                    totalNetAsync.when(
                      data: (total) {
                        final isPositive = total >= 0;
                        return Text(
                          '${isPositive ? '+' : ''}${total.toStringAsFixed(0)} PL',
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: isPositive ? Colors.green : Colors.red,
                          ),
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text('Error'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: r.cardSpacing + 8),

          // Formulario para agregar registro
          Text(
            'Nuevo Registro',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: r.cardSpacing),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.borderRadius),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 1,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(r.padHorizontal),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _plGainedController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'PL Ganado',
                            prefixIcon: Icon(
                              Icons.arrow_upward,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: r.padHorizontal),
                      Expanded(
                        child: TextFormField(
                          controller: _plLostController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'PL Perdido',
                            prefixIcon: Icon(
                              Icons.arrow_downward,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: r.cardSpacing),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectDate,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          ),
                        ),
                      ),
                      SizedBox(width: r.padHorizontal),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saveRecord,
                          icon: const Icon(Icons.save),
                          label: const Text('Guardar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: r.cardSpacing + 16),

          // Historial de registros
          Text(
            'Historial',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: r.cardSpacing),
          recordsAsync.when(
            data: (records) {
              if (records.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(r.padHorizontal * 2),
                    child: Text(
                      'No hay registros aún. ¡Agrega tu primer registro!',
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: records.length,
                separatorBuilder: (_, __) => SizedBox(height: r.cardSpacing),
                itemBuilder: (ctx, i) {
                  final record = records[i];
                  final net = record.netPl;
                  return Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.borderRadius),
                      side: BorderSide(
                        color: theme.colorScheme.outline,
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: r.padHorizontal,
                        vertical: 8,
                      ),
                      title: Text(
                        '${record.recordDate.day}/${record.recordDate.month}/${record.recordDate.year}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ganado: +${record.plGained.toStringAsFixed(0)} PL',
                          ),
                          Text(
                            'Perdido: -${record.plLost.toStringAsFixed(0)} PL',
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: net >= 0
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${net >= 0 ? '+' : ''}${net.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                color: net >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteRecord(record.id),
                            color: theme.colorScheme.error,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _plGainedController.dispose();
    _plLostController.dispose();
    super.dispose();
  }
}

final _lolRecordsProvider = FutureProvider.family<List<LolRecord>, String>((
  ref,
  userId,
) async {
  final db = ref.watch(databaseServiceProvider);
  return db.getLolRecords(userId);
});

final _totalNetPlProvider = FutureProvider.family<double, String>((
  ref,
  userId,
) async {
  final db = ref.watch(databaseServiceProvider);
  return db.getTotalNetPl(userId);
});
