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

Color _typeColor(int i, Color neon) {
  // Tonos de azul neon, variando opacidad
  final alphas = [1.0, 0.85, 0.7, 0.55, 0.45, 0.35, 0.25, 0.15];
  return neon.withValues(alpha: alphas[i % alphas.length]);
}

class _Milestone {
  final String label;
  final String emoji;
  final Duration duration;
  const _Milestone(this.label, this.emoji, this.duration);
}

final _milestones = const [
  _Milestone('1 min', '⏱️', Duration(minutes: 1)),
  _Milestone('5 min', '⏲️', Duration(minutes: 5)),
  _Milestone('15 min', '⏲️', Duration(minutes: 15)),
  _Milestone('30 min', '⏳', Duration(minutes: 30)),
  _Milestone('1 hora', '🕐', Duration(hours: 1)),
  _Milestone('2 horas', '🕑', Duration(hours: 2)),
  _Milestone('4 horas', '🕓', Duration(hours: 4)),
  _Milestone('8 horas', '🕗', Duration(hours: 8)),
  _Milestone('12 horas', '🕛', Duration(hours: 12)),
  _Milestone('18 horas', '🌇', Duration(hours: 18)),
  _Milestone('1 dia', '🌅', Duration(days: 1)),
  _Milestone('1.5 dias', '🌃', Duration(hours: 36)),
  _Milestone('2 dias', '⛅', Duration(days: 2)),
  _Milestone('3 dias', '🌤️', Duration(days: 3)),
  _Milestone('4 dias', '🌥️', Duration(days: 4)),
  _Milestone('5 dias', '🌦️', Duration(days: 5)),
  _Milestone('6 dias', '🌦️', Duration(days: 6)),
  _Milestone('1 semana', '📅', Duration(days: 7)),
  _Milestone('10 dias', '📆', Duration(days: 10)),
  _Milestone('2 semanas', '📅', Duration(days: 14)),
  _Milestone('17 dias', '📆', Duration(days: 17)),
  _Milestone('20 dias', '📆', Duration(days: 20)),
  _Milestone('3 semanas', '📅', Duration(days: 21)),
  _Milestone('1 mes', '🌙', Duration(days: 30)),
  _Milestone('45 dias', '🌓', Duration(days: 45)),
  _Milestone('2 meses', '🌕', Duration(days: 60)),
  _Milestone('75 dias', '🌗', Duration(days: 75)),
  _Milestone('3 meses', '🍃', Duration(days: 90)),
  _Milestone('4 meses', '🌿', Duration(days: 120)),
  _Milestone('5 meses', '🌿', Duration(days: 150)),
  _Milestone('6 meses', '🌿', Duration(days: 180)),
  _Milestone('7 meses', '☘️', Duration(days: 210)),
  _Milestone('8 meses', '🍀', Duration(days: 240)),
  _Milestone('9 meses', '🎋', Duration(days: 270)),
  _Milestone('10 meses', '🌳', Duration(days: 300)),
  _Milestone('11 meses', '🌲', Duration(days: 330)),
  _Milestone('1 año', '🌳', Duration(days: 365)),
];

String _formatDuration(Duration d) {
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  final seconds = d.inSeconds % 60;

  final parts = <String>[];
  if (days >= 365) {
    final years = days ~/ 365;
    final months = (days % 365) ~/ 30;
    parts.add('$years a${years > 1 ? 'ños' : 'ño'}');
    if (months > 0) parts.add('$months m');
  } else if (days >= 30) {
    final months = days ~/ 30;
    final remaining = days % 30;
    parts.add('$months m${months > 1 ? 'eses' : 'es'}');
    if (remaining > 0) parts.add('$remaining d');
  } else if (days >= 1) {
    parts.add('$days d');
  }

  if (hours > 0) parts.add('$hours h');
  parts.add('$minutes min');
  parts.add('$seconds s');

  return parts.join(' ');
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

  List<RelapseRecord> _recordsForType(String typeKey, List<RelapseRecord> all) {
    return all
        .where(
          (r) =>
              (r.relapseType == typeKey ||
              (r.relapseType == 'Otro' && r.customType == typeKey)),
        )
        .toList();
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
    final neon = theme.colorScheme.primary;

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
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(r.borderRadius),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: r.iconSizeLarge,
                            color: neon,
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

                final totalRelapses = records.length;
                final neonBg = neon.withValues(alpha: 0.9);

                return Column(
                  children: [
                    // --- Resumen global ---
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(r.cardSpacing + 4),
                      margin: EdgeInsets.only(bottom: r.cardSpacing + 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [neonBg, neon]),
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

                    // --- Trackers por tipo ---
                    ...typeKeys.map((type) {
                      final summary = grouped[type]!;
                      final elapsed = _now.difference(summary.lastDate);
                      final colorIdx = relapseTypes.contains(type)
                          ? relapseTypes.indexOf(type)
                          : typeKeys.indexOf(type);
                      final accentColor = _typeColor(colorIdx, neon);
                      final typeRecords = _recordsForType(type, records);
                      final streakInfo = _calculateStreakInfo(
                        typeRecords,
                        _now,
                      );

                      return _TypeTrackerCard(
                        typeName: type,
                        lastDate: summary.lastDate,
                        elapsed: elapsed,
                        totalCount: summary.totalCount,
                        accentColor: accentColor,
                        now: _now,
                        neon: neon,
                        streakInfo: streakInfo,
                        onRelapse: () => _relapseNow(type),
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
                                        color: _typeColor(i, neon),
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
                                            color: _typeColor(idx, neon),
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
            onTap: () => setState(() {
              _showForm = !_showForm;
              if (_showForm) {
                _selectedDate = DateTime.now();
                _selectedTime = TimeOfDay.now();
              }
            }),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: r.isDesktop ? 14 : 12,
                horizontal: r.isDesktop ? 20 : 16,
              ),
              decoration: BoxDecoration(
                color: neon.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(r.borderRadius - 2),
              ),
              child: Row(
                children: [
                  Icon(
                    _showForm ? Icons.expand_less : Icons.expand_more,
                    color: neon,
                    size: r.iconSizeMedium,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _showForm ? 'Ocultar formulario' : 'Nueva recaida',
                    style: GoogleFonts.inter(
                      fontSize: r.bodyFontSize,
                      fontWeight: FontWeight.w600,
                      color: neon,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showForm) ...[
            SizedBox(height: r.cardSpacing),
            _buildForm(theme, r, neon),
          ],

          const SizedBox(height: 28),

          if (recordsAsync != null)
            recordsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (records) =>
                  _buildHistory(theme, userData, records, r, neon),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _relapseNow(String type) async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Recaíste en $type?'),
        content: const Text(
          'Se registrará una nueva recaída ahora mismo.\n'
          'Tu racha volverá a 0 y la meta será +10% de tu última racha completada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, recaí'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final isCustomType = !relapseTypes.contains(type);

    final record = RelapseRecord(
      id: '${user.id}_${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      relapseType: isCustomType ? 'Otro' : type,
      customType: isCustomType ? type : null,
      relapseDate: DateTime.now(),
    );

    try {
      await ref.read(databaseServiceProvider).insertRelapse(record);
      ref.invalidate(relapseRecordsProvider(user.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildForm(ThemeData theme, ResponsiveHelper r, Color neon) {
    return Container(
      padding: EdgeInsets.all(r.cardSpacing + 4),
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
          Text(
            'Nueva recaida',
            style: GoogleFonts.outfit(
              fontSize: r.subtitleFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: r.cardSpacing),
          Builder(
            builder: (ctx) {
              final tt = Theme.of(ctx);
              return InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Tipo de recaida',
                  prefixIcon: const Icon(Icons.warning_amber_rounded),
                  labelStyle: GoogleFonts.inter(fontSize: r.bodyFontSize - 2),
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
                  itemBuilder: (_) => relapseTypes
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
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
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
    Color neon,
  ) {
    // Pre-calcular rachas completadas para cada registro por tipo
    final streakMap = <String, Duration?>{};
    final byType = <String, List<RelapseRecord>>{};
    for (final rec in records) {
      final key = rec.relapseType == 'Otro'
          ? (rec.customType ?? 'Otro')
          : rec.relapseType;
      (byType[key] ??= []).add(rec);
    }
    for (final entries in byType.values) {
      entries.sort((a, b) => a.relapseDate.compareTo(b.relapseDate));
      for (int i = 0; i < entries.length; i++) {
        final streak = i == 0
            ? null
            : entries[i].relapseDate.difference(entries[i - 1].relapseDate);
        streakMap[entries[i].id] = streak;
      }
    }

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
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(r.borderRadius),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: r.iconSizeLarge,
                    color: neon,
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
              final prevStreak = streakMap[rec.id];
              return Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(r.borderRadius - 2),
                child: Padding(
                  padding: EdgeInsets.all(r.cardSpacing),
                  child: Row(
                    children: [
                      Container(
                        width: r.isDesktop ? 52 : 48,
                        height: r.isDesktop ? 52 : 48,
                        decoration: BoxDecoration(
                          color: neon.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.warning_rounded,
                          color: neon,
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
                              '${DateFormat('dd/MM/yyyy').format(rec.relapseDate)}  ${DateFormat('HH:mm:ss').format(rec.relapseDate)}',
                              style: GoogleFonts.inter(
                                fontSize: r.bodyFontSize - 2,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                            if (prevStreak != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      size: 12,
                                      color: neon.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Racha anterior: ${_formatDuration(prevStreak)}',
                                      style: GoogleFonts.inter(
                                        fontSize: r.bodyFontSize - 3,
                                        color: neon.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
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
                          color: neon,
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
class _TypeTrackerCard extends StatefulWidget {
  final String typeName;
  final DateTime lastDate;
  final Duration elapsed;
  final int totalCount;
  final Color accentColor;
  final Color neon;
  final DateTime now;
  final _StreakInfo streakInfo;
  final VoidCallback onRelapse;

  const _TypeTrackerCard({
    required this.typeName,
    required this.lastDate,
    required this.elapsed,
    required this.totalCount,
    required this.accentColor,
    required this.neon,
    required this.now,
    required this.streakInfo,
    required this.onRelapse,
  });

  @override
  State<_TypeTrackerCard> createState() => _TypeTrackerCardState();
}

class _TypeTrackerCardState extends State<_TypeTrackerCard> {
  bool _showAllMilestones = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final daysSince = widget.elapsed.inDays;

    // Lógica para mostrar solo hitos relevantes
    List<_Milestone> visibleMilestones;
    if (_showAllMilestones) {
      visibleMilestones = _milestones;
    } else {
      final firstNotCompletedIdx = _milestones.indexWhere(
        (m) => widget.elapsed.inMilliseconds < m.duration.inMilliseconds,
      );

      if (firstNotCompletedIdx == -1) {
        // Todos completados, mostrar los últimos 5
        visibleMilestones = _milestones.sublist(
          (_milestones.length - 5).clamp(0, _milestones.length),
        );
      } else {
        // Mostrar 2 anteriores, el actual y 3 siguientes
        final start = (firstNotCompletedIdx - 2).clamp(0, _milestones.length);
        final end = (firstNotCompletedIdx + 4).clamp(0, _milestones.length);
        visibleMilestones = _milestones.sublist(start, end);
      }
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: r.cardSpacing),
      padding: EdgeInsets.all(r.cardSpacing + 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(r.borderRadius),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: r.isDesktop ? 50 : 42,
                height: r.isDesktop ? 50 : 42,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.warning_rounded,
                    color: widget.accentColor,
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
                      widget.typeName,
                      style: GoogleFonts.outfit(
                        fontSize: r.subtitleFontSize + 2,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${widget.totalCount} recaida${widget.totalCount > 1 ? 's' : ''} total${widget.totalCount > 1 ? 'es' : ''}',
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
                icon: Icon(Icons.restart_alt, color: widget.neon, size: 20),
                onPressed: widget.onRelapse,
                tooltip: 'Recaí en ${widget.typeName}',
              ),
            ],
          ),
          SizedBox(height: r.cardSpacing),
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
                      _formatDuration(widget.elapsed),
                      style: GoogleFonts.outfit(
                        fontSize: r.isDesktop ? 32 : 26,
                        fontWeight: FontWeight.bold,
                        color: widget.accentColor,
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
                            color: widget.accentColor.withValues(alpha: 0.7),
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
                    DateFormat('dd/MM/yy').format(widget.lastDate),
                    style: GoogleFonts.outfit(
                      fontSize: r.bodyFontSize - 1,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    DateFormat('HH:mm').format(widget.lastDate),
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
          // --- Record historico y Meta siguiente ---
          Row(
            children: [
              // Record historico
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(r.cardSpacing - 2),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events, size: 18, color: widget.neon),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Record',
                              style: GoogleFonts.inter(
                                fontSize: r.bodyFontSize - 3,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            Text(
                              widget.streakInfo.bestStreakLabel,
                              style: GoogleFonts.outfit(
                                fontSize: r.bodyFontSize - 2,
                                fontWeight: FontWeight.w700,
                                color: widget.neon,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Meta siguiente
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(r.cardSpacing - 2),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Proxima meta (+10%)',
                        style: GoogleFonts.inter(
                          fontSize: r.bodyFontSize - 4,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.streakInfo.nextGoalLabel,
                        style: GoogleFonts.outfit(
                          fontSize: r.bodyFontSize - 2,
                          fontWeight: FontWeight.w700,
                          color: widget.accentColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 5,
                          child: Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                color: widget.accentColor.withValues(
                                  alpha: 0.12,
                                ),
                              ),
                              AnimatedFractionallySizedBox(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutCubic,
                                widthFactor: widget.streakInfo.goalProgress,
                                child: Container(color: widget.accentColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(widget.streakInfo.goalProgress * 100).toInt()}%',
                        style: GoogleFonts.inter(
                          fontSize: r.bodyFontSize - 4,
                          color: widget.accentColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.cardSpacing),
          ...visibleMilestones.map((m) {
            final progress =
                (widget.elapsed.inMilliseconds / m.duration.inMilliseconds)
                    .clamp(0.0, 1.0);
            final completed = progress >= 1.0;
            final barColor = completed ? widget.neon : widget.accentColor;

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
                                  ? widget.neon
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
                                      ? [widget.neon, widget.neon]
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
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => _showAllMilestones = !_showAllMilestones),
              icon: Icon(
                _showAllMilestones ? Icons.expand_less : Icons.expand_more,
                size: 16,
              ),
              label: Text(
                _showAllMilestones
                    ? 'Ver menos logros'
                    : 'Ver todos los logros',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: widget.accentColor.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

class _StreakInfo {
  final Duration currentStreak;
  final Duration? bestStreak;
  final Duration? lastCompletedStreak;
  final Duration nextGoal;

  const _StreakInfo({
    required this.currentStreak,
    this.bestStreak,
    this.lastCompletedStreak,
    required this.nextGoal,
  });

  String get bestStreakLabel =>
      bestStreak != null ? _formatDuration(bestStreak!) : '--';

  String get nextGoalLabel => _formatDuration(nextGoal);

  double get goalProgress => nextGoal.inMilliseconds > 0
      ? (currentStreak.inMilliseconds / nextGoal.inMilliseconds).clamp(0.0, 1.0)
      : 0.0;
}

_StreakInfo _calculateStreakInfo(
  List<RelapseRecord> recordsForType,
  DateTime now,
) {
  // Ordenar cronologicamente (mas antiguo primero)
  final sorted = [...recordsForType]
    ..sort((a, b) => a.relapseDate.compareTo(b.relapseDate));

  final currentStreak = now.difference(sorted.last.relapseDate);

  // Si solo hay 1 recaida, no hay racha completada historica
  if (sorted.length < 2) {
    const minGoal = Duration(hours: 1);
    final rawGoal = Duration(
      milliseconds: (currentStreak.inMilliseconds * 1.1).round(),
    );
    return _StreakInfo(
      currentStreak: currentStreak,
      bestStreak: null,
      lastCompletedStreak: null,
      nextGoal: rawGoal > minGoal ? rawGoal : minGoal,
    );
  }

  // Calcular rachas completadas (gaps entre recaidas consecutivas)
  final List<Duration> completedStreaks = [];
  for (int i = 1; i < sorted.length; i++) {
    completedStreaks.add(
      sorted[i].relapseDate.difference(sorted[i - 1].relapseDate),
    );
  }

  final lastCompleted = completedStreaks.last;
  final best = completedStreaks.reduce(
    (a, b) => a.inMilliseconds > b.inMilliseconds ? a : b,
  );

  // Meta: ultima racha completada + 10%
  final nextMs = (lastCompleted.inMilliseconds * 1.1).round();

  return _StreakInfo(
    currentStreak: currentStreak,
    bestStreak: best,
    lastCompletedStreak: lastCompleted,
    nextGoal: Duration(milliseconds: nextMs),
  );
}
