import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/relapse_record.dart';

final relapseRecordsProvider =
    FutureProvider.family<List<RelapseRecord>, String>((ref, userId) {
      return ref.watch(databaseServiceProvider).getRelapseRecords(userId);
    });

final relapseTypes = const [
  'Cero',
  'Alcohol',
  'Tabaco',
  'Drogas',
  'Juego',
  'Comida',
  'Tecnologia / Redes',
  'Otro',
];

final _typeColors = [
  Colors.indigo.shade400,
  Colors.red.shade400,
  Colors.orange.shade400,
  Colors.purple.shade400,
  Colors.blue.shade400,
  Colors.teal.shade400,
  Colors.pink.shade400,
  Colors.grey.shade500,
];

final _pieColors = _typeColors;

class _Milestone {
  final String label;
  final String emoji;
  final Duration duration;

  const _Milestone(this.label, this.emoji, this.duration);
}

final _milestones = const [
  _Milestone('1 min', '⏱️', Duration(minutes: 1)),
  _Milestone('1 hora', '🕐', Duration(hours: 1)),
  _Milestone('1 dia', '🌅', Duration(days: 1)),
  _Milestone('1 semana', '📅', Duration(days: 7)),
  _Milestone('1 mes', '🌙', Duration(days: 30)),
  _Milestone('3 meses', '🍃', Duration(days: 90)),
  _Milestone('6 meses', '🌿', Duration(days: 180)),
  _Milestone('1 año', '🌳', Duration(days: 365)),
];

String _formatDuration(Duration d) {
  if (d.inDays >= 365) {
    final years = d.inDays ~/ 365;
    final months = (d.inDays % 365) ~/ 30;
    return '$years a${years > 1 ? 'ños' : 'ño'}${months > 0 ? ' $months m' : ''}';
  }
  if (d.inDays >= 30) {
    final months = d.inDays ~/ 30;
    final days = d.inDays % 30;
    return '$months m${months > 1 ? 'eses' : 'es'}${days > 0 ? ' $days d' : ''}';
  }
  if (d.inDays >= 1) return '${d.inDays} d ${d.inHours % 24} h';
  if (d.inHours >= 1) return '${d.inHours} h ${d.inMinutes % 60} min';
  if (d.inMinutes >= 1) return '${d.inMinutes} min ${d.inSeconds % 60} s';
  return '${d.inSeconds} s';
}

class RelapseTrackingScreen extends ConsumerStatefulWidget {
  const RelapseTrackingScreen({super.key});

  @override
  ConsumerState<RelapseTrackingScreen> createState() =>
      _RelapseTrackingScreenState();
}

class _RelapseTrackingScreenState extends ConsumerState<RelapseTrackingScreen> {
  String _selectedType = relapseTypes.first;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final _customController = TextEditingController();
  final _notesController = TextEditingController();
  bool _saving = false;
  bool _showForm = false;
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _customController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    final combinedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final record = RelapseRecord(
      id: '${user.id}_${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      relapseType: _selectedType,
      customType: _selectedType == 'Otro'
          ? _customController.text.trim()
          : null,
      relapseDate: combinedDate,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    try {
      await ref.read(databaseServiceProvider).insertRelapse(record);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    ref.invalidate(relapseRecordsProvider(user.id));

    setState(() {
      _saving = false;
      _selectedType = relapseTypes.first;
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
      _customController.clear();
      _notesController.clear();
      _showForm = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recaida registrada')));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Fecha de la recaida',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      helpText: 'Hora de la recaida',
    );
    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
    }
  }

  /// Agrupa registros por tipo y devuelve para cada tipo su ultima recaida
  Map<String, _TypeSummary> _groupByType(List<RelapseRecord> records) {
    final map = <String, _TypeSummary>{};
    for (final r in records) {
      final key = r.relapseType == 'Otro'
          ? (r.customType ?? 'Otro')
          : r.relapseType;
      final existing = map[key];
      if (existing == null || r.relapseDate.isAfter(existing.lastDate)) {
        map[key] = _TypeSummary(
          key: key,
          lastDate: r.relapseDate,
          totalCount: (existing?.totalCount ?? 0) + 1,
        );
      } else {
        map[key] = _TypeSummary(
          key: existing.key,
          lastDate: existing.lastDate,
          totalCount: existing.totalCount + 1,
        );
      }
    }
    return map;
  }

  Map<String, int> _countByType(List<RelapseRecord> records) {
    final map = <String, int>{};
    for (final r in records) {
      final key = r.relapseType == 'Otro'
          ? (r.customType ?? 'Otro')
          : r.relapseType;
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final recordsAsync = user != null
        ? ref.watch(relapseRecordsProvider(user.id))
        : null;
    final theme = Theme.of(context);
    final userData = user;
    final r = ResponsiveHelper(context);

    return SingleChildScrollView(
      padding: r.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seguimiento de Recaidas',
            style: GoogleFonts.outfit(
              fontSize: r.titleFontSize,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cada segundo sin recaer es una victoria.',
            style: GoogleFonts.inter(
              fontSize: r.subtitleFontSize,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: r.cardSpacing + 4),

          if (recordsAsync != null)
            recordsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (records) {
                final grouped = _groupByType(records);
                final typeKeys = grouped.keys.toList();

                if (typeKeys.isEmpty) {
                  return Container(
                    padding: EdgeInsets.all(r.isDesktop ? 48 : 36),
                    margin: EdgeInsets.only(bottom: r.cardSpacing + 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(r.borderRadius),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: r.iconSizeLarge,
                            color: Colors.green,
                          ),
                          SizedBox(height: r.cardSpacing),
                          Text(
                            'No hay recaidas registradas',
                            style: GoogleFonts.inter(
                              fontSize: r.bodyFontSize,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Registra tu primera recaida para empezar',
                            style: GoogleFonts.inter(
                              fontSize: r.bodyFontSize - 2,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Total global
                final totalRelapses = records.length;

                return Column(
                  children: [
                    // --- Resumen global ---
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(r.cardSpacing + 4),
                      margin: EdgeInsets.only(bottom: r.cardSpacing + 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withValues(alpha: 0.9),
                            theme.colorScheme.primary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(r.borderRadius),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Total de recaidas registradas',
                            style: GoogleFonts.inter(
                              fontSize: r.bodyFontSize - 2,
                              color: Colors.white.withValues(alpha: 0.85),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$totalRelapses',
                            style: GoogleFonts.outfit(
                              fontSize: r.isDesktop ? 52 : 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'en ${typeKeys.length} tipo${typeKeys.length > 1 ? 's' : ''}',
                            style: GoogleFonts.inter(
                              fontSize: r.bodyFontSize - 1,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- Trackers por tipo de adiccion ---
                    ...typeKeys.map((type) {
                      final summary = grouped[type]!;
                      final elapsed = _now.difference(summary.lastDate);
                      final colorIdx = relapseTypes.contains(type)
                          ? relapseTypes.indexOf(type)
                          : typeKeys.indexOf(type);
                      final accentColor =
                          _typeColors[colorIdx % _typeColors.length];

                      return _TypeTrackerCard(
                        typeName: type,
                        lastDate: summary.lastDate,
                        elapsed: elapsed,
                        totalCount: summary.totalCount,
                        accentColor: accentColor,
                        now: _now,
                        onDelete: () => _deleteRecords(userData, type, records),
                      );
                    }),
                  ],
                );
              },
            ),

          const SizedBox(height: 20),

          // --- Grafica de pastel ---
          if (recordsAsync != null)
            recordsAsync.when(
              loading: () => const SizedBox(),
              error: (e, st) => const SizedBox(),
              data: (records) {
                final countByType = _countByType(records);
                if (records.isEmpty) return const SizedBox();
                return Container(
                  padding: EdgeInsets.all(r.cardSpacing + 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(r.borderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Distribucion de recaidas',
                        style: GoogleFonts.outfit(
                          fontSize: r.subtitleFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: r.cardSpacing),
                      SizedBox(
                        height: r.isDesktop ? 240 : 200,
                        child: Row(
                          children: [
                            Expanded(
                              child: PieChart(
                                PieChartData(
                                  sections: List.generate(
                                    countByType.keys.length,
                                    (i) {
                                      final key = countByType.keys.toList()[i];
                                      final value = countByType[key]!
                                          .toDouble();
                                      return PieChartSectionData(
                                        value: value,
                                        color:
                                            _pieColors[i % _pieColors.length],
                                        radius: 55,
                                        titleStyle: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        title: value > 0
                                            ? '${value.toInt()}'
                                            : '',
                                      );
                                    },
                                  ),
                                  centerSpaceRadius: 40,
                                  sectionsSpace: 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: countByType.entries.map((e) {
                                  final idx = countByType.keys.toList().indexOf(
                                    e.key,
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color:
                                                _pieColors[idx %
                                                    _pieColors.length],
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            e.key,
                                            style: GoogleFonts.inter(
                                              fontSize: r.bodyFontSize - 3,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${e.value}',
                                          style: GoogleFonts.outfit(
                                            fontSize: r.bodyFontSize - 2,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 20),

          // --- Toggle formulario ---
          InkWell(
            onTap: () => setState(() => _showForm = !_showForm),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: r.isDesktop ? 14 : 12,
                horizontal: r.isDesktop ? 20 : 16,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(r.borderRadius - 2),
              ),
              child: Row(
                children: [
                  Icon(
                    _showForm ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.primary,
                    size: r.iconSizeMedium,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _showForm ? 'Ocultar formulario' : 'Nueva recaida',
                    style: GoogleFonts.inter(
                      fontSize: r.bodyFontSize,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showForm) ...[
            SizedBox(height: r.cardSpacing),
            _buildForm(theme, r),
          ],

          const SizedBox(height: 28),

          // --- Historial ---
          if (recordsAsync != null)
            recordsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (records) => _buildHistory(theme, userData, records, r),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _deleteRecords(
    dynamic userData,
    String type,
    List<RelapseRecord> all,
  ) async {
    if (userData == null) return;
    final toDelete = all
        .where(
          (r) =>
              (r.relapseType == type ||
              (r.relapseType == 'Otro' && r.customType == type)),
        )
        .toList();
    for (final r in toDelete) {
      await ref.read(databaseServiceProvider).deleteRelapse(r.id);
    }
    ref.invalidate(relapseRecordsProvider(userData.id));
  }

  Widget _buildForm(ThemeData theme, ResponsiveHelper r) {
    return Container(
      padding: EdgeInsets.all(r.cardSpacing + 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.borderRadius),
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
            'Nueva recaida',
            style: GoogleFonts.outfit(
              fontSize: r.subtitleFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: r.cardSpacing),
          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            decoration: InputDecoration(
              labelText: 'Tipo de recaida',
              prefixIcon: const Icon(Icons.warning_amber_rounded),
              labelStyle: GoogleFonts.inter(fontSize: r.bodyFontSize - 2),
            ),
            items: relapseTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedType = v);
            },
          ),
          if (_selectedType == 'Otro') ...[
            SizedBox(height: r.cardSpacing - 4),
            TextField(
              controller: _customController,
              decoration: InputDecoration(
                labelText: 'Especifica el tipo',
                hintText: 'Ej: Apuestas deportivas',
                prefixIcon: const Icon(Icons.edit),
                labelStyle: GoogleFonts.inter(fontSize: r.bodyFontSize - 2),
              ),
            ),
          ],
          SizedBox(height: r.cardSpacing - 4),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Fecha',
                      prefixIcon: const Icon(Icons.calendar_today),
                      labelStyle: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 2,
                      ),
                    ),
                    child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _pickTime,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Hora',
                      prefixIcon: const Icon(Icons.access_time),
                      labelStyle: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 2,
                      ),
                    ),
                    child: Text(_selectedTime.format(context)),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.cardSpacing - 4),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Notas (opcional)',
              hintText: 'Que paso antes de la recaida...',
              prefixIcon: const Icon(Icons.notes),
              labelStyle: GoogleFonts.inter(fontSize: r.bodyFontSize - 2),
            ),
          ),
          SizedBox(height: r.cardSpacing + 4),
          SizedBox(
            height: r.buttonHeight,
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
              label: Text(_saving ? 'Guardando...' : 'Registrar recaida'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(
    ThemeData theme,
    dynamic userData,
    List<RelapseRecord> records,
    ResponsiveHelper r,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Historial',
              style: GoogleFonts.outfit(
                fontSize: r.subtitleFontSize + 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${records.length} registros',
              style: GoogleFonts.inter(
                fontSize: r.bodyFontSize - 2,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        SizedBox(height: r.cardSpacing - 4),
        if (records.isEmpty)
          Container(
            padding: EdgeInsets.all(r.isDesktop ? 48 : 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(r.borderRadius),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: r.iconSizeLarge,
                    color: Colors.green,
                  ),
                  SizedBox(height: r.cardSpacing),
                  Text(
                    'No hay recaidas registradas',
                    style: GoogleFonts.inter(
                      fontSize: r.bodyFontSize,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: records.length,
            separatorBuilder: (_, i) => SizedBox(height: r.cardSpacing - 4),
            itemBuilder: (context, index) {
              final rec = records[index];
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(r.borderRadius - 2),
                child: Padding(
                  padding: EdgeInsets.all(r.cardSpacing),
                  child: Row(
                    children: [
                      Container(
                        width: r.isDesktop ? 52 : 48,
                        height: r.isDesktop ? 52 : 48,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.warning_rounded,
                          color: Colors.red,
                          size: r.iconSizeMedium,
                        ),
                      ),
                      SizedBox(width: r.cardSpacing - 2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec.relapseType == 'Otro'
                                  ? (rec.customType ?? 'Otro')
                                  : rec.relapseType,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: r.bodyFontSize,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${DateFormat('dd/MM/yyyy').format(rec.relapseDate)}  ${DateFormat('HH:mm').format(rec.relapseDate)}',
                              style: GoogleFonts.inter(
                                fontSize: r.bodyFontSize - 2,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                            if (rec.notes != null && rec.notes!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  rec.notes!,
                                  maxLines: 2,
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
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: r.iconSizeMedium - 2,
                        ),
                        onPressed: () async {
                          if (userData == null) return;
                          await ref
                              .read(databaseServiceProvider)
                              .deleteRelapse(rec.id);
                          ref.invalidate(relapseRecordsProvider(userData.id));
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ============================================================
// Widget: Tarjeta de tracker por tipo de adiccion
// ============================================================
class _TypeTrackerCard extends StatelessWidget {
  final String typeName;
  final DateTime lastDate;
  final Duration elapsed;
  final int totalCount;
  final Color accentColor;
  final DateTime now;
  final VoidCallback onDelete;

  const _TypeTrackerCard({
    required this.typeName,
    required this.lastDate,
    required this.elapsed,
    required this.totalCount,
    required this.accentColor,
    required this.now,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final daysSince = elapsed.inDays;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: r.cardSpacing),
      padding: EdgeInsets.all(r.cardSpacing + 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.borderRadius),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Cabecera del tipo ---
          Row(
            children: [
              Container(
                width: r.isDesktop ? 50 : 42,
                height: r.isDesktop ? 50 : 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.warning_rounded,
                    color: accentColor,
                    size: r.iconSizeMedium,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeName,
                      style: GoogleFonts.outfit(
                        fontSize: r.subtitleFontSize + 2,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '$totalCount recaida${totalCount > 1 ? 's' : ''} total${totalCount > 1 ? 'es' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 2,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.red.shade300,
                  size: 20,
                ),
                onPressed: onDelete,
                tooltip: 'Eliminar historial de $typeName',
              ),
            ],
          ),

          SizedBox(height: r.cardSpacing),

          // --- Contador de tiempo sin recaer ---
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tiempo sin recaer',
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 3,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDuration(elapsed),
                      style: GoogleFonts.outfit(
                        fontSize: r.isDesktop ? 32 : 26,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                        height: 1.1,
                      ),
                    ),
                    if (daysSince >= 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '$daysSince dias limpio',
                          style: GoogleFonts.inter(
                            fontSize: r.bodyFontSize - 2,
                            color: accentColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    'Ultima:',
                    style: GoogleFonts.inter(
                      fontSize: r.bodyFontSize - 4,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd/MM/yy').format(lastDate),
                    style: GoogleFonts.outfit(
                      fontSize: r.bodyFontSize - 1,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    DateFormat('HH:mm').format(lastDate),
                    style: GoogleFonts.inter(
                      fontSize: r.bodyFontSize - 3,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: r.cardSpacing),

          // --- Barras de milestones para este tipo ---
          ..._milestones.map((m) {
            final progress =
                (elapsed.inMilliseconds / m.duration.inMilliseconds).clamp(
                  0.0,
                  1.0,
                );
            final completed = progress >= 1.0;
            final barColor = completed ? const Color(0xFF228B22) : accentColor;

            return Padding(
              padding: EdgeInsets.only(bottom: r.cardSpacing - 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            m.emoji,
                            style: TextStyle(fontSize: r.bodyFontSize - 1),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            m.label,
                            style: GoogleFonts.outfit(
                              fontSize: r.bodyFontSize - 2,
                              fontWeight: completed
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: completed
                                  ? const Color(0xFF228B22)
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.7,
                                    ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        completed ? 'Hecho' : '${(progress * 100).toInt()}%',
                        style: GoogleFonts.inter(
                          fontSize: r.bodyFontSize - 3,
                          fontWeight: FontWeight.w600,
                          color: barColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: r.isDesktop ? 10 : 8,
                      child: Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            color: barColor.withValues(alpha: 0.12),
                          ),
                          AnimatedFractionallySizedBox(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            widthFactor: progress,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: completed
                                      ? [
                                          const Color(0xFF228B22),
                                          const Color(0xFF2E7D32),
                                        ]
                                      : [barColor, barColor],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ============================================================
// Modelo interno para agrupar
// ============================================================
class _TypeSummary {
  final String key;
  final DateTime lastDate;
  final int totalCount;

  const _TypeSummary({
    required this.key,
    required this.lastDate,
    required this.totalCount,
  });
}
