import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/health_record.dart';

final healthRecordsProvider =
    FutureProvider.family<List<HealthRecord>, String>((ref, userId) {
  return ref.watch(databaseServiceProvider).getHealthRecords(userId);
});

final totalStepsProvider =
    FutureProvider.family<int, String>((ref, userId) {
  return ref.watch(databaseServiceProvider).getTotalSteps(userId);
});

final avgStepsProvider =
    FutureProvider.family<double, String>((ref, userId) {
  return ref.watch(databaseServiceProvider).getAvgSteps(userId, days: 7);
});

class HealthTrackingScreen extends ConsumerStatefulWidget {
  const HealthTrackingScreen({super.key});

  @override
  ConsumerState<HealthTrackingScreen> createState() =>
      _HealthTrackingScreenState();
}

class _HealthTrackingScreenState extends ConsumerState<HealthTrackingScreen> {
  final _stepsController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _stepsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;
    final steps = int.tryParse(_stepsController.text.trim());
    if (steps == null || steps <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ingresa un numero valido de pasos')));
      return;
    }

    setState(() => _saving = true);
    final record = HealthRecord(
      id: '${user.id}_h_${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      steps: steps,
      recordDate: _selectedDate,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    try {
      await ref.read(databaseServiceProvider).insertHealthRecord(record);
      ref.invalidate(healthRecordsProvider(user.id));
      ref.invalidate(totalStepsProvider(user.id));
      ref.invalidate(avgStepsProvider(user.id));
      setState(() {
        _saving = false;
        _stepsController.clear();
        _notesController.clear();
        _selectedDate = DateTime.now();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pasos registrados')));
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
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
    final recordsAsync =
        user != null ? ref.watch(healthRecordsProvider(user.id)) : null;
    final totalAsync =
        user != null ? ref.watch(totalStepsProvider(user.id)) : null;
    final avgAsync =
        user != null ? ref.watch(avgStepsProvider(user.id)) : null;
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final neon = theme.colorScheme.primary;

    return SingleChildScrollView(
      padding: r.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Salud y Deporte',
              style: GoogleFonts.outfit(
                fontSize: r.titleFontSize,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              )),
          SizedBox(height: 6),
          Text('Registra tus pasos diarios y monitorea tu actividad.',
              style: GoogleFonts.inter(
                fontSize: r.subtitleFontSize,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              )),
          SizedBox(height: r.cardSpacing + 4),

          // --- Cards resumen ---
          if (totalAsync != null && avgAsync != null)
            Builder(builder: (_) {
              final total = totalAsync.asData?.value ?? 0;
              final avg = avgAsync.asData?.value ?? 0;
              final cols = r.statColumns;
              return Wrap(
                spacing: r.cardSpacing - 4,
                runSpacing: r.cardSpacing - 4,
                children: [
                  SizedBox(
                    width: _cardWidth(context, cols),
                    child: _SummaryCard(
                      r: r,
                      title: 'Total pasos',
                      value: NumberFormat.compact().format(total),
                      icon: Icons.directions_walk,
                      color: neon,
                    ),
                  ),
                  SizedBox(
                    width: _cardWidth(context, cols),
                    child: _SummaryCard(
                      r: r,
                      title: 'Promedio diario',
                      value: NumberFormat.compact().format(avg.toInt()),
                      subtitle: 'ultimos 7 dias',
                      icon: Icons.trending_up,
                      color: neon.withValues(alpha: 0.8),
                    ),
                  ),
                  SizedBox(
                    width: _cardWidth(context, cols),
                    child: _SummaryCard(
                      r: r,
                      title: 'Distancia total',
                      value: '${(total * 0.00075).toStringAsFixed(1)} km',
                      subtitle: 'estimado',
                      icon: Icons.map,
                      color: neon.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              );
            }),

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
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Registrar pasos',
                    style: GoogleFonts.outfit(
                      fontSize: r.subtitleFontSize,
                      fontWeight: FontWeight.w600,
                    )),
                SizedBox(height: r.cardSpacing),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child:
                        Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                  ),
                ),
                SizedBox(height: r.cardSpacing - 4),
                TextField(
                  controller: _stepsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Numero de pasos',
                    hintText: 'Ej: 8500',
                    prefixIcon: Icon(Icons.directions_walk),
                  ),
                ),
                SizedBox(height: r.cardSpacing - 4),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    hintText: 'Ej: Caminata en el parque',
                    prefixIcon: Icon(Icons.notes),
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
                        : const Icon(Icons.save),
                    label:
                        Text(_saving ? 'Guardando...' : 'Guardar registro'),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: r.cardSpacing + 12),

          // --- Historial ---
          Text('Historial',
              style: GoogleFonts.outfit(
                fontSize: r.subtitleFontSize + 2,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              )),
          SizedBox(height: r.cardSpacing - 4),

          if (recordsAsync == null)
            const Center(child: CircularProgressIndicator())
          else
            recordsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
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
                      child: Column(children: [
                        Icon(Icons.fitness_center,
                            size: r.iconSizeLarge,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.2)),
                        SizedBox(height: 12),
                        Text('No hay registros de pasos',
                            style: GoogleFonts.inter(
                              fontSize: r.bodyFontSize,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            )),
                      ]),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: records.length,
                  separatorBuilder: (_, i) =>
                      SizedBox(height: r.cardSpacing - 8),
                  itemBuilder: (context, index) {
                    final rec = records[index];
                    final km = rec.km;
                    final cal = rec.calories;

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
                              child: Icon(Icons.directions_walk,
                                  color: neon, size: r.iconSizeMedium),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text(
                                      '${NumberFormat.decimalPattern().format(rec.steps)} pasos',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: r.bodyFontSize,
                                        color: neon,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      DateFormat('dd/MM/yyyy')
                                          .format(rec.recordDate),
                                      style: GoogleFonts.inter(
                                        fontSize: r.bodyFontSize - 2,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.45),
                                      ),
                                    ),
                                  ]),
                                  SizedBox(height: 2),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      Text(
                                        '${km.toStringAsFixed(2)} km',
                                        style: GoogleFonts.inter(
                                          fontSize: r.bodyFontSize - 2,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      Text(
                                        '~${cal.toStringAsFixed(0)} cal',
                                        style: GoogleFonts.inter(
                                          fontSize: r.bodyFontSize - 2,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (rec.notes != null &&
                                      rec.notes!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(rec.notes!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: r.bodyFontSize - 2,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.5),
                                          )),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: neon, size: 20),
                              onPressed: () async {
                                if (user == null) return;
                                await ref
                                    .read(databaseServiceProvider)
                                    .deleteHealthRecord(rec.id);
                                ref.invalidate(
                                    healthRecordsProvider(user.id));
                                ref.invalidate(totalStepsProvider(user.id));
                                ref.invalidate(avgStepsProvider(user.id));
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
          SizedBox(height: 40),
        ],
      ),
    );
  }

  double _cardWidth(BuildContext context, int cols) {
    final screenW = MediaQuery.of(context).size.width;
    final padding = ResponsiveHelper(context).pagePadding;
    final padTotal = padding.left + padding.right;
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
          Text(value,
              style: GoogleFonts.outfit(
                fontSize: r.isDesktop ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              )),
          SizedBox(height: 2),
          Text(subtitle != null ? '$title ($subtitle)' : title,
              style: GoogleFonts.inter(
                fontSize: r.bodyFontSize - 1,
                color: Colors.white.withValues(alpha: 0.8),
              )),
        ],
      ),
    );
  }
}
