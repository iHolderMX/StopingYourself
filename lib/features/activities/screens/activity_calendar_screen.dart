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
  final yesterday = today.subtract(const Duration(days: 1));

  final progress = <DateTime, double>{};
  for (final r in records) {
    final d = DateTime(r.scheduledDate.year, r.scheduledDate.month, r.scheduledDate.day);
    final p = r.progress;
    if ((progress[d] ?? 0) < p) progress[d] = p;
  }

  final start = DateTime(
    template.createdAt.year,
    template.createdAt.month,
    template.createdAt.day,
  );
  final grace = template.graceDays;

  int streak = 0, best = 0, miss = 0;
  var cursor = start;
  while (!cursor.isAfter(yesterday)) {
    final day = DateTime(cursor.year, cursor.month, cursor.day);
    if (template.occursOn(day)) {
      final p = progress[day] ?? 0.0;
      if (p >= 1.0) {
        streak++;
        miss = 0;
        if (streak > best) best = streak;
      } else {
        miss++;
        if (miss > grace) {
          streak = 0;
          miss = 0;
        }
      }
    }
    cursor = cursor.add(const Duration(days: 1));
  }

  // Hoy: si corresponde y ya se cumplió, se suma; si aún no, la racha sigue viva.
  if (template.occursOn(today)) {
    final p = progress[today] ?? 0.0;
    if (p >= 1.0) {
      streak++;
      if (streak > best) best = streak;
    }
  }

  return (current: streak, best: best);
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
