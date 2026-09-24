import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/activity_template.dart';
import '../../../models/daily_activity.dart';

final activityStatsProvider = FutureProvider.family<
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

class _ActivityStats {
  final int scheduled;
  final int completed;
  final double pctAll;
  final double pct7;
  final double pct30;
  final int bestStreak;
  final List<({DateTime start, double pct})> weekly;

  const _ActivityStats({
    required this.scheduled,
    required this.completed,
    required this.pctAll,
    required this.pct7,
    required this.pct30,
    required this.bestStreak,
    required this.weekly,
  });
}

_ActivityStats _computeStats(
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

  final start = DateTime(
    template.createdAt.year,
    template.createdAt.month,
    template.createdAt.day,
  );

  // Días programados desde la creación hasta hoy.
  final scheduledDays = <DateTime>[];
  var cursor = start;
  while (!cursor.isAfter(today)) {
    final day = DateTime(cursor.year, cursor.month, cursor.day);
    if (template.occursOn(day)) scheduledDays.add(day);
    cursor = cursor.add(const Duration(days: 1));
  }

  int completedCount = 0;
  for (final d in scheduledDays) {
    if ((progress[d] ?? 0) >= 1.0) completedCount++;
  }

  double pctOf(List<DateTime> days) {
    if (days.isEmpty) return 0;
    int c = 0;
    for (final d in days) {
      if ((progress[d] ?? 0) >= 1.0) c++;
    }
    return c / days.length * 100;
  }

  final today7 = today.subtract(const Duration(days: 6));
  final today30 = today.subtract(const Duration(days: 29));
  final last7 = scheduledDays.where((d) => !d.isBefore(today7)).toList();
  final last30 = scheduledDays.where((d) => !d.isBefore(today30)).toList();

  // Tendencia semanal: últimas 8 semanas (Lun..Dom).
  final thisMonday = today.subtract(Duration(days: today.weekday - 1));
  final weekly = <({DateTime start, double pct})>[];
  for (int w = 7; w >= 0; w--) {
    final weekStart = thisMonday.subtract(Duration(days: w * 7));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final daysInWeek = scheduledDays
        .where((d) => !d.isBefore(weekStart) && !d.isAfter(weekEnd))
        .toList();
    weekly.add((start: weekStart, pct: pctOf(daysInWeek)));
  }

  // Mejor racha (con días de gracia).
  int bestStreak = _bestStreak(template, progress, scheduledDays);

  return _ActivityStats(
    scheduled: scheduledDays.length,
    completed: completedCount,
    pctAll: scheduledDays.isEmpty ? 0 : completedCount / scheduledDays.length * 100,
    pct7: pctOf(last7),
    pct30: pctOf(last30),
    bestStreak: bestStreak,
    weekly: weekly,
  );
}

int _bestStreak(
  ActivityTemplate template,
  Map<DateTime, double> progress,
  List<DateTime> scheduledDays,
) {
  final grace = template.graceDays;
  int streak = 0, best = 0, miss = 0;
  for (final d in scheduledDays) {
    final p = progress[d] ?? 0.0;
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
  return best;
}

class ActivityStatisticsScreen extends ConsumerStatefulWidget {
  final String templateId;

  const ActivityStatisticsScreen({super.key, required this.templateId});

  @override
  ConsumerState<ActivityStatisticsScreen> createState() =>
      _ActivityStatisticsScreenState();
}

class _ActivityStatisticsScreenState
    extends ConsumerState<ActivityStatisticsScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final statsAsync = user != null
        ? ref.watch(
            activityStatsProvider((
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
                  statsAsync?.value?.template?.title ?? 'Estadísticas',
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
            'Estadísticas del hábito',
            style: GoogleFonts.inter(
              fontSize: r.subtitleFontSize,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: r.cardSpacing + 4),

          if (statsAsync == null)
            const Center(child: CircularProgressIndicator())
          else
            statsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (data) {
                final template = data.template;
                if (template == null) {
                  return const Center(child: Text('Hábito no encontrado'));
                }
                final stats = _computeStats(template, data.records);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetricsGrid(stats: stats, r: r, theme: theme),
                    SizedBox(height: r.cardSpacing + 4),
                    _WeeklyTrend(stats: stats, r: r),
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

class _MetricsGrid extends StatelessWidget {
  final _ActivityStats stats;
  final ResponsiveHelper r;
  final ThemeData theme;

  const _MetricsGrid({
    required this.stats,
    required this.r,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ('% Cumplimiento', '${stats.pctAll.round()}%', theme.colorScheme.primary),
      ('% 7 días', '${stats.pct7.round()}%', theme.colorScheme.primary),
      ('% 30 días', '${stats.pct30.round()}%', theme.colorScheme.primary),
      ('Mejor racha', '${stats.bestStreak}', const Color(0xFFF57C00)),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in items)
          SizedBox(
            width: (r.isDesktop ? 220 : 160),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(r.borderRadius - 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.$2,
                    style: GoogleFonts.outfit(
                      fontSize: r.bodyFontSize + 6,
                      fontWeight: FontWeight.bold,
                      color: item.$3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.$1,
                    style: GoogleFonts.inter(
                      fontSize: r.bodyFontSize - 2,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _WeeklyTrend extends StatelessWidget {
  final _ActivityStats stats;
  final ResponsiveHelper r;

  const _WeeklyTrend({required this.stats, required this.r});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(r.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tendencia semanal (% cumplimiento)',
            style: GoogleFonts.inter(
              fontSize: r.bodyFontSize,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final w in stats.weekly)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${w.pct.round()}%',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: _barHeight(w.pct),
                          decoration: BoxDecoration(
                            color: _barColor(w.pct),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${w.start.day}/${w.start.month}',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  double _barHeight(double pct) {
    final h = (pct / 100) * 80;
    return h < 2 ? 2 : h;
  }

  Color _barColor(double pct) {
    if (pct <= 0) return const Color(0xFF9E9E9E);
    if (pct >= 100) return const Color(0xFF2E7D32);
    if (pct >= 50) return const Color(0xFFF9A825);
    return const Color(0xFFC62828);
  }
}
