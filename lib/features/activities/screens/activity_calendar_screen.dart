import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/activity_template.dart';
import '../../../models/daily_activity.dart';

final activityCalendarProvider = FutureProvider.family<
  ({ActivityTemplate? template, List<DailyActivity> records}),
  ({String userId, String templateId})
>((ref, params) async {
  final db = ref.watch(databaseServiceProvider);
  final template = await db.getActivityTemplate(params.templateId);
  final records = template == null
      ? <DailyActivity>[]
      : await db.getDailyActivitiesByTemplate(params.userId, params.templateId);
  return (template: template, records: records);
});

enum _DayStatus { complete, partial, missed, empty }

class _HeatmapDay {
  final DateTime date;
  final _DayStatus status;
  const _HeatmapDay(this.date, this.status);
}

({int current, int best}) _computeStreaks(
  ActivityTemplate template,
  List<DailyActivity> records,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final progress = <DateTime, double>{};
  for (final r in records) {
    final d = DateTime(r.scheduledDate.year, r.scheduledDate.month, r.scheduledDate.day);
    final p = r.progress;
    if ((progress[d] ?? 0) < p) progress[d] = p;
  }

  final grace = template.graceDays;

  // Determinar el DÍA MÁS ANTIGUO con registro para NO iterar infinitamente
  // (incluye registros manuales anteriores a createdAt, ya que Gus permite
  //  marcar días pasados aunque la plantilla se creara después).
  DateTime earliest = DateTime(
    template.createdAt.year,
    template.createdAt.month,
    template.createdAt.day,
  );
  for (final r in records) {
    final d = DateTime(r.scheduledDate.year, r.scheduledDate.month, r.scheduledDate.day);
    if (d.isBefore(earliest)) earliest = d;
  }

  // ============================================================
  // 1) Calcular MEJOR RACHA (best) — itera del más viejo a HOY.
  //    Incluye todos los registros (independientemente de createdAt).
  // ============================================================
  int best = 0, running = 0, miss = 0;
  var cursor = earliest;
  while (!cursor.isAfter(today)) {
    final day = DateTime(cursor.year, cursor.month, cursor.day);
    if (template.occursOn(day)) {
      final p = progress[day] ?? 0.0;
      if (p >= 1.0) {
        running++;
        miss = 0;
        if (running > best) best = running;
      } else {
        miss++;
        if (miss > grace) {
          running = 0;
          miss = 0;
        }
      }
    }
    cursor = cursor.add(const Duration(days: 1));
  }

  // ============================================================
  // 2) Calcular RACHA ACTUAL (current) — itera de HOY hacia ATRÁS.
  //    Reglas:
  //    • Días que NO están programados (ej: Domingo para Gym L-S)
  //      -> NO rompen, se saltan (son descanso).
  //    • Día de HOY: si corresponde y aún no se marca, NO rompe aún.
  //    • Se permite hasta `graceDays` faltas consecutivas sin romper.
  // ============================================================
  int current = 0;
  int currentMiss = 0;
  cursor = today;
  bool allowTodaySkip = true;
  while (!cursor.isBefore(earliest)) {
    final day = DateTime(cursor.year, cursor.month, cursor.day);
    if (template.occursOn(day)) {
      final p = progress[day] ?? 0.0;
      if (p >= 1.0) {
        current++;
        currentMiss = 0;
        allowTodaySkip = false;
      } else {
        // Caso especial: HOY, corresponde, aún no se marca -> se salta 1 vez
        final bool isToday = day.isAtSameMomentAs(today);
        if (isToday && allowTodaySkip) {
          allowTodaySkip = false;
          cursor = cursor.subtract(const Duration(days: 1));
          continue;
        }
        currentMiss++;
        if (currentMiss > grace) break;
      }
    }
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return (current: current, best: best);
}

class ActivityCalendarScreen extends ConsumerStatefulWidget {
  final String templateId;

  const ActivityCalendarScreen({super.key, required this.templateId});

  @override
  ConsumerState<ActivityCalendarScreen> createState() =>
      _ActivityCalendarScreenState();
}

class _ActivityCalendarScreenState extends ConsumerState<ActivityCalendarScreen> {
  static const int _weeks = 12;
  static const List<String> _weekdayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  Future<void> _openEditDialog(ActivityTemplate tpl) async {
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final titleCtrl = TextEditingController(text: tpl.title);
    int graceDays = tpl.graceDays;
    final initialFrequency = tpl.frequency;
    final initialDays = <int>[
      ...((tpl.frequencyConfig['days_of_week'] as List?)?.cast<num>() ?? const <num>[])
          .map((e) => e.toInt()),
    ];
    // Si no es weekly pero queremos permitir solo weekly/daily por ahora.
    bool isDaily = initialFrequency == ActivityFrequency.daily;
    final selectedDays = <int>{...initialDays};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -4)),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Editar hábito',
                          style: GoogleFonts.outfit(
                            fontSize: r.titleFontSize - 2,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    SizedBox(height: r.cardSpacing),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del hábito',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.edit_note),
                      ),
                      style: GoogleFonts.inter(fontSize: r.bodyFontSize),
                    ),
                    SizedBox(height: r.cardSpacing + 4),
                    Text(
                      'Días de gracia permitidos (faltas sin romper la racha):',
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 1,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    StatefulBuilder(
                      builder: (_, _) => Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: graceDays.toDouble(),
                              min: 0,
                              max: 7,
                              divisions: 7,
                              label: '$graceDays',
                              onChanged: (v) => setModalState(() => graceDays = v.toInt()),
                            ),
                          ),
                          Container(
                            width: 56,
                            alignment: Alignment.center,
                            child: Text(
                              '$graceDays',
                              style: GoogleFonts.outfit(
                                fontSize: r.bodyFontSize + 2,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: r.cardSpacing),
                    Text(
                      'Periodicidad:',
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 1,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Todos los días'),
                          selected: isDaily,
                          onSelected: (v) =>
                              setModalState(() => isDaily = v),
                        ),
                        ChoiceChip(
                          label: const Text('Días específicos'),
                          selected: !isDaily,
                          onSelected: (v) =>
                              setModalState(() => isDaily = !v),
                        ),
                      ],
                    ),
                    if (!isDaily) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Selecciona los días:',
                        style: GoogleFonts.inter(
                          fontSize: r.bodyFontSize - 1,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(7, (i) {
                          final day = i + 1; // 1..7
                          final isSel = selectedDays.contains(day);
                          return GestureDetector(
                            onTap: () => setModalState(() {
                              isSel ? selectedDays.remove(day) : selectedDays.add(day);
                            }),
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSel
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSel
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                _weekdayLabels[i],
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  color: isSel
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                    SizedBox(height: r.cardSpacing + 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar cambios'),
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Ingresa un nombre')),
                            );
                            return;
                          }
                          if (!isDaily && selectedDays.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Selecciona al menos 1 día')),
                            );
                            return;
                          }

                          final db = ref.read(databaseServiceProvider);
                          final finalFreq = isDaily
                              ? ActivityFrequency.daily
                              : ActivityFrequency.weekly;
                          final Map<String, dynamic> finalConfig = isDaily
                              ? const {}
                              : {
                                  'days_of_week': <int>[...selectedDays]..sort(),
                                };

                          final updated = tpl.copyWith(
                            title: title,
                            graceDays: graceDays,
                            frequency: finalFreq,
                            frequencyConfig: finalConfig,
                          );
                          try {
                            await db.updateActivityTemplate(updated);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              // Forzar recarga del provider actual
                              final user = ref.read(supabaseClientProvider).auth.currentUser;
                              if (user != null) {
                                ref.invalidate(activityCalendarProvider((
                                  userId: user.id,
                                  templateId: widget.templateId,
                                )));
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Cambios guardados ✅')),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Error al guardar: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<List<_HeatmapDay>> _buildWeeks(List<DailyActivity> records) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Lunes de la semana actual.
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    final start = thisMonday.subtract(Duration(days: (_weeks - 1) * 7));

    final progress = <DateTime, double>{};
    for (final r in records) {
      final d = DateTime(r.scheduledDate.year, r.scheduledDate.month, r.scheduledDate.day);
      final p = r.progress;
      if ((progress[d] ?? 0) < p) progress[d] = p;
    }

    final weeks = <List<_HeatmapDay>>[];
    for (int w = 0; w < _weeks; w++) {
      final col = <_HeatmapDay>[];
      for (int d = 0; d < 7; d++) {
        final date = start.add(Duration(days: w * 7 + d));
        final day = DateTime(date.year, date.month, date.day);
        _DayStatus status;
        if (day.isAfter(today)) {
          status = _DayStatus.empty;
        } else {
          final p = progress[day];
          if (p == null) {
            status = _DayStatus.empty;
          } else if (p >= 1.0) {
            status = _DayStatus.complete;
          } else if (p >= 0.5) {
            status = _DayStatus.partial;
          } else {
            status = _DayStatus.missed;
          }
        }
        col.add(_HeatmapDay(day, status));
      }
      weeks.add(col);
    }
    return weeks;
  }

  Color _cellColor(_HeatmapDay day, DateTime today, ThemeData theme) {
    switch (day.status) {
      case _DayStatus.complete:
        return const Color(0xFF2E7D32); // verde
      case _DayStatus.partial:
        return const Color(0xFFF9A825); // amarillo
      case _DayStatus.missed:
        return const Color(0xFFC62828); // rojo
      case _DayStatus.empty:
        return day.date.isAfter(today)
            ? theme.colorScheme.onSurface.withValues(alpha: 0.04)
            : theme.colorScheme.onSurface.withValues(alpha: 0.10);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final dataAsync = user != null
        ? ref.watch(
            activityCalendarProvider((
              userId: user.id,
              templateId: widget.templateId,
            )),
          )
        : null;
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);

    return SingleChildScrollView(
      padding: r.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              Expanded(
                child: Text(
                  dataAsync?.value?.template?.title ?? 'Actividad',
                  style: GoogleFonts.outfit(
                    fontSize: r.titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (dataAsync?.value?.template != null)
                IconButton(
                  tooltip: 'Editar hábito',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _openEditDialog(dataAsync!.value!.template!),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Calendario Memento Mori · últimas 12 semanas',
            style: GoogleFonts.inter(
              fontSize: r.subtitleFontSize,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: r.cardSpacing + 4),

          if (dataAsync == null)
            const Center(child: CircularProgressIndicator())
          else
            dataAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (data) {
                final weeks = _buildWeeks(data.records);
                final template = data.template;
                final streaks = template != null
                    ? _computeStreaks(template, data.records)
                    : (current: 0, best: 0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MementoMoriGrid(
                      weeks: weeks,
                      cellColor: (day, today) => _cellColor(day, today, theme),
                      r: r,
                    ),
                    SizedBox(height: r.cardSpacing + 4),
                    _Legend(r: r),
                    SizedBox(height: r.cardSpacing + 4),
                    _StreakCard(
                      current: streaks.current,
                      best: streaks.best,
                      graceDays: template?.graceDays ?? 0,
                      r: r,
                    ),
                    SizedBox(height: r.cardSpacing + 4),
                    _Summary(weeks: weeks, r: r, theme: theme),
                    SizedBox(height: r.cardSpacing + 4),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.bar_chart),
                        label: const Text('Ver estadísticas'),
                        onPressed: () => context.push(
                          '/activity-statistics/${widget.templateId}',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _MementoMoriGrid extends StatelessWidget {
  final List<List<_HeatmapDay>> weeks;
  final Color Function(_HeatmapDay, DateTime) cellColor;
  final ResponsiveHelper r;

  const _MementoMoriGrid({
    required this.weeks,
    required this.cellColor,
    required this.r,
  });

  static const double _cell = 14;
  static const double _gap = 4;
  static const _labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(r.borderRadius),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                for (int i = 0; i < _labels.length; i++) ...[
                  if (i > 0) const SizedBox(height: _gap),
                  SizedBox(
                    height: _cell,
                    child: Center(
                      child: Text(
                        _labels[i],
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                for (int w = 0; w < weeks.length; w++) ...[
                  if (w > 0) const SizedBox(width: _gap),
                  Column(
                    children: [
                      for (int d = 0; d < weeks[w].length; d++) ...[
                        if (d > 0) const SizedBox(height: _gap),
                        Container(
                          width: _cell,
                          height: _cell,
                          decoration: BoxDecoration(
                            color: cellColor(weeks[w][d], todayDay),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final ResponsiveHelper r;

  const _Legend({required this.r});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      (const Color(0xFF2E7D32), 'Cumplido'),
      (const Color(0xFFF9A825), 'Parcial'),
      (const Color(0xFFC62828), 'No cumplido'),
    ];
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: item.$1,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                item.$2,
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize - 2,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  final List<List<_HeatmapDay>> weeks;
  final ResponsiveHelper r;
  final ThemeData theme;

  const _Summary({required this.weeks, required this.r, required this.theme});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    int complete = 0, partial = 0, missed = 0, total = 0;
    for (final col in weeks) {
      for (final day in col) {
        if (day.date.isAfter(todayDay)) continue;
        switch (day.status) {
          case _DayStatus.complete:
            complete++;
            total++;
            break;
          case _DayStatus.partial:
            partial++;
            total++;
            break;
          case _DayStatus.missed:
            missed++;
            total++;
            break;
          case _DayStatus.empty:
            break;
        }
      }
    }

    final pct = total == 0 ? 0 : ((complete / total) * 100).round();

    return Row(
      children: [
        _StatChip(label: 'Cumplidos', value: '$complete', color: const Color(0xFF2E7D32), r: r),
        const SizedBox(width: 10),
        _StatChip(label: 'Parciales', value: '$partial', color: const Color(0xFFF9A825), r: r),
        const SizedBox(width: 10),
        _StatChip(label: 'Fallados', value: '$missed', color: const Color(0xFFC62828), r: r),
        const SizedBox(width: 10),
        _StatChip(
          label: '% Éxito',
          value: '$pct%',
          color: theme.colorScheme.primary,
          r: r,
        ),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int current;
  final int best;
  final int graceDays;
  final ResponsiveHelper r;

  const _StreakCard({
    required this.current,
    required this.best,
    required this.graceDays,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(r.borderRadius),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department,
            color: Color(0xFFF57C00),
            size: 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Racha actual: $current día(s)',
                  style: GoogleFonts.outfit(
                    fontSize: r.bodyFontSize + 1,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mejor racha: $best día(s)',
                  style: GoogleFonts.inter(
                    fontSize: r.bodyFontSize,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                if (graceDays > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Días de gracia: $graceDays',
                    style: GoogleFonts.inter(
                      fontSize: r.bodyFontSize - 1,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final ResponsiveHelper r;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(r.borderRadius - 2),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: r.bodyFontSize + 2,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
