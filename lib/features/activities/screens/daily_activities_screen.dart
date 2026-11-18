import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/activity_template.dart'
    show ActivityFrequency, ActivityTemplate;
import '../../../models/daily_activity.dart';
import 'activity_templates_screen.dart' show activityTemplatesProvider;

String _buildFrequencyLabel(
  DailyActivity activity,
  Map<String, ActivityTemplate> templatesMap,
) {
  final tpl = templatesMap[activity.templateId];
  if (tpl == null) return 'Solo hoy';

  switch (tpl.frequency) {
    case ActivityFrequency.daily:
      return 'Todos los días';
    case ActivityFrequency.weekly:
      final days =
          (tpl.frequencyConfig['days_of_week'] as List?)?.cast<int>() ??
          const <int>[];
      if (days.isEmpty) return 'Semanal';
      if (days.length == 7) return 'Todos los días';
      if (_sameList(days, [1, 2, 3, 4, 5])) return 'Lun-Vie';
      final sb = <String>[];
      for (final d in days..sort()) {
        if (d >= 1 && d <= 7) sb.add(_weekdayLabels[d - 1]);
      }
      return sb.isNotEmpty ? sb.join(', ') : 'Semanal';
    case ActivityFrequency.monthly:
      final days =
          (tpl.frequencyConfig['days_of_month'] as List?)?.cast<int>() ??
          const <int>[];
      if (days.isEmpty) return 'Mensual';
      return 'Días ${days.join(', ')}';
    case ActivityFrequency.custom:
      final n = (tpl.frequencyConfig['interval_days'] as num?)?.toInt() ?? 1;
      return 'Cada $n día${n == 1 ? '' : 's'}';
  }
}

bool _sameList(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  final as = [...a]..sort();
  final bs = [...b]..sort();
  for (int i = 0; i < as.length; i++) {
    if (as[i] != bs[i]) return false;
  }
  return true;
}

enum _FrequencyShortcut { today, weekdays, allDays, custom }

const _weekdayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

final dailyActivitiesProvider =
    FutureProvider.family<
      List<DailyActivity>,
      ({String userId, DateTime date})
    >((ref, params) async {
      final db = ref.watch(databaseServiceProvider);
      await db.ensureDailyActivities(params.userId, params.date);
      return db.getDailyActivities(params.userId, date: params.date);
    });

class _AggregatedActivity {
  final String title;
  final int count;
  final DateTime lastDate;
  final DailyActivity sample;
  final bool isHabit;

  const _AggregatedActivity({
    required this.title,
    required this.count,
    required this.lastDate,
    required this.sample,
    required this.isHabit,
  });
}

final activityHistoryProvider =
    FutureProvider.family<List<_AggregatedActivity>, String>((
      ref,
      userId,
    ) async {
      final db = ref.watch(databaseServiceProvider);
      final all = await db.getDailyActivities(userId);
      final map = <String, List<DailyActivity>>{};
      for (final a in all) {
        // Los hábitos se agrupan por su plantilla; las puntuales, por título.
        final key = a.templateId != null
            ? 'tpl:${a.templateId}'
            : 'man:${a.title}';
        map.putIfAbsent(key, () => []).add(a);
      }
      final result = <_AggregatedActivity>[];
      for (final entry in map.entries) {
        final list = entry.value;
        list.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
        result.add(
          _AggregatedActivity(
            title: list.first.title,
            count: list.length,
            lastDate: list.first.scheduledDate,
            sample: list.first,
            isHabit: list.first.templateId != null,
          ),
        );
      }
      result.sort((a, b) => b.count.compareTo(a.count));
      return result;
    });

final _completedCountProvider =
    FutureProvider.family<
      int,
      ({String userId, String? templateId, String title})
    >((ref, params) async {
      final db = ref.watch(databaseServiceProvider);
      final all = await db.getDailyActivities(params.userId);
      return all.where((a) {
        if (params.templateId != null) {
          return a.templateId == params.templateId && a.isCompleted;
        }
        return a.templateId == null && a.title == params.title && a.isCompleted;
      }).length;
    });

class DailyActivitiesScreen extends ConsumerStatefulWidget {
  const DailyActivitiesScreen({super.key});

  @override
  ConsumerState<DailyActivitiesScreen> createState() =>
      _DailyActivitiesScreenState();
}

class _DailyActivitiesScreenState extends ConsumerState<DailyActivitiesScreen> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _unitController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  ActivityType _activityType = ActivityType.boolean;
  _FrequencyShortcut _frequencyShortcut = _FrequencyShortcut.today;
  final Set<int> _selectedWeekdays = <int>{};
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _prevDay() => setState(
    () => _selectedDate = _selectedDate.subtract(const Duration(days: 1)),
  );
  void _nextDay() => setState(
    () => _selectedDate = _selectedDate.add(const Duration(days: 1)),
  );

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  ActivityFrequency _getFrequency() {
    switch (_frequencyShortcut) {
      case _FrequencyShortcut.today:
        return ActivityFrequency.daily;
      case _FrequencyShortcut.weekdays:
      case _FrequencyShortcut.allDays:
      case _FrequencyShortcut.custom:
        return ActivityFrequency.weekly;
    }
  }

  Map<String, dynamic> _getFrequencyConfig() {
    final days = <int>[..._selectedWeekdays]..sort();
    switch (_frequencyShortcut) {
      case _FrequencyShortcut.today:
        return const {};
      case _FrequencyShortcut.weekdays:
      case _FrequencyShortcut.allDays:
      case _FrequencyShortcut.custom:
        return {'days_of_week': days};
    }
  }

  bool get _isTemplate => _frequencyShortcut != _FrequencyShortcut.today;

  Future<void> _save() async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa una actividad')));
      return;
    }

    if (_isTemplate &&
        _frequencyShortcut == _FrequencyShortcut.custom &&
        _selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un día')),
      );
      return;
    }

    num? targetValue;
    if (_activityType == ActivityType.numeric) {
      final raw = _targetController.text.trim();
      if (raw.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa un valor objetivo')),
        );
        return;
      }
      targetValue = num.tryParse(raw);
      if (targetValue == null || targetValue <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El valor debe ser mayor a 0')),
        );
        return;
      }
    }

    final unit = _unitController.text.trim();

    setState(() => _saving = true);
    final db = ref.read(databaseServiceProvider);
    String? templateId;

    try {
      if (_isTemplate) {
        final template = ActivityTemplate(
          id: '${user.id}_t_${DateTime.now().millisecondsSinceEpoch}',
          userId: user.id,
          title: title,
          activityType: _activityType,
          targetValue: targetValue,
          unit: unit.isNotEmpty ? unit : null,
          stepValue: 1,
          frequency: _getFrequency(),
          frequencyConfig: _getFrequencyConfig(),
        );
        templateId = template.id;
        await db.insertActivityTemplate(template);
      }

      final activity = DailyActivity(
        id: '${user.id}_a_${DateTime.now().millisecondsSinceEpoch}',
        userId: user.id,
        title: title,
        scheduledDate: _selectedDate,
        activityType: _activityType,
        targetValue: targetValue,
        currentValue: _activityType == ActivityType.numeric ? 0 : null,
        unit: unit.isNotEmpty ? unit : null,
        templateId: templateId,
      );

      await db.insertDailyActivity(activity);
      ref.invalidate(
        dailyActivitiesProvider((userId: user.id, date: _selectedDate)),
      );
      _titleController.clear();
      _targetController.clear();
      _unitController.clear();
      setState(() {
        _activityType = ActivityType.boolean;
        _frequencyShortcut = _FrequencyShortcut.today;
        _selectedWeekdays.clear();
      });
      if (mounted) {
        final msg = _isTemplate
            ? 'Hábito recurrente creado'
            : 'Actividad agregada';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _toggleComplete(DailyActivity activity) async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;
    final updated = activity.copyWith(
      isCompleted: !activity.isCompleted,
      completedAt: activity.isCompleted ? null : DateTime.now(),
      currentValue: activity.isCompleted
          ? activity.currentValue
          : (activity.targetValue ?? activity.currentValue),
    );
    try {
      await ref.read(databaseServiceProvider).updateDailyActivity(updated);
      ref.invalidate(
        dailyActivitiesProvider((userId: user.id, date: _selectedDate)),
      );
    } catch (_) {}
  }

  Future<void> _updateProgress(DailyActivity activity, num delta) async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;
    final newValue = ((activity.currentValue ?? 0) + delta).clamp(
      0,
      activity.targetValue ?? 999999,
    );
    final isNowComplete = newValue >= (activity.targetValue ?? 1);
    final updated = activity.copyWith(
      currentValue: newValue,
      isCompleted: isNowComplete,
      completedAt: isNowComplete ? DateTime.now() : null,
    );
    try {
      await ref.read(databaseServiceProvider).updateDailyActivity(updated);
      ref.invalidate(
        dailyActivitiesProvider((userId: user.id, date: _selectedDate)),
      );
    } catch (_) {}
  }

  void _openHistoryModal() {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      showDragHandle: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxWidth: r.isDesktop ? 700 : double.infinity,
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (_) {
        final theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.manage_history,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Historial de actividades',
                    style: GoogleFonts.outfit(
                      fontSize: r.titleFontSize - 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                'Todas tus actividades, hábitos y puntuales. Toca una puntual para convertirla en recurrente.',
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize - 2,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              SizedBox(height: 14),
              Flexible(
                child: Consumer(
                  builder: (_, ref, child) {
                    final async = ref.watch(activityHistoryProvider(user.id));
                    return async.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Center(child: Text('Error: $e')),
                      data: (list) {
                        if (list.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  size: 40,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Aun no hay actividades manuales guardadas.',
                                  style: GoogleFonts.inter(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          itemCount: list.length,
                          separatorBuilder: (_, s) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final item = list[i];
                            final completedCount =
                                ref
                                    .watch(
                                      _completedCountProvider((
                                        userId: user.id,
                                        templateId: item.sample.templateId,
                                        title: item.title,
                                      )),
                                    )
                                    .value ??
                                0;
                            return _HistoryTile(
                              item: item,
                              completedCount: completedCount,
                              r: r,
                              neon: theme.colorScheme.primary,
                              onSurface: theme.colorScheme.onSurface,
                              onConvert: item.isHabit
                                  ? null
                                  : () {
                                      Navigator.of(context).pop();
                                      _openConvertDialog(item);
                                    },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openConvertDialog(_AggregatedActivity item) {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;
    var shortcut = _FrequencyShortcut.weekdays;
    final weekdays = <int>{1, 2, 3, 4, 5};
    var isSaving = false;

    ActivityFrequency getFrequency() {
      switch (shortcut) {
        case _FrequencyShortcut.today:
        case _FrequencyShortcut.weekdays:
        case _FrequencyShortcut.allDays:
        case _FrequencyShortcut.custom:
          return shortcut == _FrequencyShortcut.allDays
              ? ActivityFrequency.daily
              : ActivityFrequency.weekly;
      }
    }

    Map<String, dynamic> getConfig() {
      if (shortcut == _FrequencyShortcut.allDays) return const {};
      final days = <int>[...weekdays]..sort();
      return {'days_of_week': days};
    }

    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final neon = theme.colorScheme.primary;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.repeat, color: neon, size: 22),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Convertir "${item.title}"',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿En qué días debe aparecer?',
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 1,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _ShortcutChip(
                          label: 'L-V',
                          icon: Icons.calendar_view_week,
                          selected: shortcut == _FrequencyShortcut.weekdays,
                          onTap: () => setDialogState(() {
                            shortcut = _FrequencyShortcut.weekdays;
                            weekdays
                              ..clear()
                              ..addAll([1, 2, 3, 4, 5]);
                          }),
                          r: r,
                        ),
                        _ShortcutChip(
                          label: 'Todos los días',
                          icon: Icons.autorenew,
                          selected: shortcut == _FrequencyShortcut.allDays,
                          onTap: () => setDialogState(() {
                            shortcut = _FrequencyShortcut.allDays;
                            weekdays
                              ..clear()
                              ..addAll([1, 2, 3, 4, 5, 6, 7]);
                          }),
                          r: r,
                        ),
                        _ShortcutChip(
                          label: 'Personalizar',
                          icon: Icons.tune,
                          selected: shortcut == _FrequencyShortcut.custom,
                          onTap: () => setDialogState(() {
                            shortcut = _FrequencyShortcut.custom;
                          }),
                          r: r,
                        ),
                      ],
                    ),
                    if (shortcut == _FrequencyShortcut.custom) ...[
                      SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (int i = 1; i <= 7; i++)
                            FilterChip(
                              label: Text(_weekdayLabels[i - 1]),
                              selected: weekdays.contains(i),
                              onSelected: (_) => setDialogState(() {
                                if (!weekdays.add(i)) weekdays.remove(i);
                              }),
                              showCheckmark: false,
                            ),
                        ],
                      ),
                    ],
                    SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: neon.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: neon),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Se creará desde HOY. Aparecerá desmarcada los días asignados y marcarla confirmará que ya la hiciste.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (shortcut == _FrequencyShortcut.custom &&
                              weekdays.isEmpty) {
                            ScaffoldMessenger.of(dialogCtx).showSnackBar(
                              const SnackBar(
                                content: Text('Selecciona al menos un día'),
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          final db = ref.read(databaseServiceProvider);
                          final now = DateTime.now();
                          final tpl = ActivityTemplate(
                            id: '${user.id}_t_${now.millisecondsSinceEpoch}',
                            userId: user.id,
                            title: item.title,
                            activityType: item.sample.activityType,
                            targetValue: item.sample.targetValue,
                            unit: item.sample.unit,
                            stepValue: item.sample.stepValue > 0
                                ? item.sample.stepValue
                                : 1,
                            frequency: getFrequency(),
                            frequencyConfig: getConfig(),
                          );
                          try {
                            await db.insertActivityTemplate(tpl);
                            await db.ensureDailyActivities(
                              user.id,
                              DateTime.now(),
                            );
                            if (ctx.mounted) Navigator.of(dialogCtx).pop();
                            ref.invalidate(activityTemplatesProvider(user.id));
                            ref.invalidate(
                              dailyActivitiesProvider((
                                userId: user.id,
                                date: _selectedDate,
                              )),
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '"${item.title}" ahora es recurrente',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (dialogCtx.mounted) {
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          } finally {
                            if (dialogCtx.mounted) {
                              setDialogState(() => isSaving = false);
                            }
                          }
                        },
                  icon: isSaving
                      ? SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.done),
                  label: Text(isSaving ? 'Guardando...' : 'Hacer recurrente'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final activitiesAsync = user != null
        ? ref.watch(
            dailyActivitiesProvider((userId: user.id, date: _selectedDate)),
          )
        : null;
    final templatesAsync = user != null
        ? ref.watch(activityTemplatesProvider(user.id))
        : null;
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final neon = theme.colorScheme.primary;
    final dateLabel = _isToday
        ? 'Hoy'
        : DateFormat('EEEE d MMM', 'es').format(_selectedDate);

    return SingleChildScrollView(
      padding: r.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actividades del dia',
            style: GoogleFonts.outfit(
              fontSize: r.titleFontSize,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Organiza tus tareas importantes y haz seguimiento de tus habitos.',
            style: GoogleFonts.inter(
              fontSize: r.subtitleFontSize,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: r.cardSpacing + 4),

          // --- Acceso a hábitos recurrentes ---
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.repeat, size: 18),
                  label: const Text('Hábitos'),
                  onPressed: () => context.push('/activity-templates'),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.manage_history, size: 18),
                  label: const Text('Historial'),
                  onPressed: _openHistoryModal,
                ),
              ),
            ],
          ),
          SizedBox(height: r.cardSpacing + 4),

          // --- Selector de fecha ---
          Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _prevDay,
                  tooltip: 'Dia anterior',
                ),
                Column(
                  children: [
                    Text(
                      dateLabel,
                      style: GoogleFonts.outfit(
                        fontSize: r.subtitleFontSize + 2,
                        fontWeight: FontWeight.bold,
                        color: _isToday ? neon : theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(_selectedDate),
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 2,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isToday)
                      IconButton(
                        icon: Icon(Icons.today, color: neon),
                        onPressed: () =>
                            setState(() => _selectedDate = DateTime.now()),
                        tooltip: 'Ir a hoy',
                      ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _nextDay,
                      tooltip: 'Dia siguiente',
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: r.cardSpacing + 4),

          // --- Formulario ---
          Container(
            padding: EdgeInsets.all(r.cardSpacing + 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(r.borderRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Campo titulo
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'Nueva actividad...',
                    prefixIcon: Icon(Icons.add_task),
                  ),
                  onSubmitted: (_) => _save(),
                ),
                SizedBox(height: 12),

                // Selector de tipo
                Row(
                  children: [
                    _TypeChip(
                      label: 'Si / No',
                      icon: Icons.check_circle_outline,
                      selected: _activityType == ActivityType.boolean,
                      onTap: () =>
                          setState(() => _activityType = ActivityType.boolean),
                      r: r,
                    ),
                    SizedBox(width: 10),
                    _TypeChip(
                      label: 'Cantidad',
                      icon: Icons.numbers,
                      selected: _activityType == ActivityType.numeric,
                      onTap: () =>
                          setState(() => _activityType = ActivityType.numeric),
                      r: r,
                    ),
                  ],
                ),

                // Campos extra para tipo numerico
                if (_activityType == ActivityType.numeric) ...[
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _targetController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Valor objetivo',
                            prefixIcon: Icon(Icons.flag_outlined),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _unitController,
                          decoration: const InputDecoration(
                            hintText: 'Unidad',
                            prefixIcon: Icon(Icons.straighten),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                SizedBox(height: 16),
                Text(
                  'Periodo',
                  style: GoogleFonts.inter(
                    fontSize: r.bodyFontSize - 1,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _ShortcutChip(
                      label: 'Solo hoy',
                      icon: Icons.today,
                      selected: _frequencyShortcut == _FrequencyShortcut.today,
                      onTap: () => setState(() {
                        _frequencyShortcut = _FrequencyShortcut.today;
                        _selectedWeekdays.clear();
                      }),
                      r: r,
                    ),
                    _ShortcutChip(
                      label: 'L-V',
                      icon: Icons.calendar_view_week,
                      selected:
                          _frequencyShortcut == _FrequencyShortcut.weekdays,
                      onTap: () => setState(() {
                        _frequencyShortcut = _FrequencyShortcut.weekdays;
                        _selectedWeekdays
                          ..clear()
                          ..addAll([1, 2, 3, 4, 5]);
                      }),
                      r: r,
                    ),
                    _ShortcutChip(
                      label: 'Todos los días',
                      icon: Icons.autorenew,
                      selected:
                          _frequencyShortcut == _FrequencyShortcut.allDays,
                      onTap: () => setState(() {
                        _frequencyShortcut = _FrequencyShortcut.allDays;
                        _selectedWeekdays
                          ..clear()
                          ..addAll([1, 2, 3, 4, 5, 6, 7]);
                      }),
                      r: r,
                    ),
                    _ShortcutChip(
                      label: 'Personalizar',
                      icon: Icons.tune,
                      selected: _frequencyShortcut == _FrequencyShortcut.custom,
                      onTap: () => setState(() {
                        _frequencyShortcut = _FrequencyShortcut.custom;
                      }),
                      r: r,
                    ),
                  ],
                ),
                if (_frequencyShortcut == _FrequencyShortcut.custom) ...[
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (int i = 1; i <= 7; i++)
                        FilterChip(
                          label: Text(_weekdayLabels[i - 1]),
                          selected: _selectedWeekdays.contains(i),
                          onSelected: (_) => setState(() {
                            if (!_selectedWeekdays.add(i)) {
                              _selectedWeekdays.remove(i);
                            }
                          }),
                          showCheckmark: false,
                        ),
                    ],
                  ),
                ],

                SizedBox(height: 12),
                // Boton guardar
                SizedBox(
                  width: double.infinity,
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
                        : const Icon(Icons.add),
                    label: Text(_saving ? 'Guardando...' : 'Agregar'),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: r.cardSpacing + 8),

          // --- Lista de actividades ---
          if (activitiesAsync == null || templatesAsync == null)
            const Center(child: CircularProgressIndicator())
          else
            templatesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (templates) {
                final templatesMap = <String, ActivityTemplate>{
                  for (final t in templates) t.id: t,
                };
                return activitiesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (activities) {
                    if (activities.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(r.borderRadius),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.event_note,
                                size: r.iconSizeLarge,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Sin actividades para este dia',
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

                    final pending = activities
                        .where((a) => !a.isCompleted)
                        .toList();
                    final completed = activities
                        .where((a) => a.isCompleted)
                        .toList();

                    return Column(
                      children: [
                        if (pending.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.pending_actions,
                                color: neon,
                                size: 20,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Pendientes (${pending.length})',
                                style: GoogleFonts.inter(
                                  fontSize: r.bodyFontSize - 1,
                                  fontWeight: FontWeight.w600,
                                  color: neon,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          ...pending.map(
                            (a) => _ActivityTile(
                              activity: a,
                              frequencyLabel: _buildFrequencyLabel(
                                a,
                                templatesMap,
                              ),
                              r: r,
                              neon: neon,
                              surface: theme.colorScheme.surface,
                              onText: theme.colorScheme.onSurface,
                              onAlpha: (x) => theme.colorScheme.onSurface
                                  .withValues(alpha: x),
                              onToggle: () => _toggleComplete(a),
                              onUpdateProgress: (delta) =>
                                  _updateProgress(a, delta),
                              onDelete: () async {
                                if (user == null) return;
                                await ref
                                    .read(databaseServiceProvider)
                                    .deleteDailyActivity(a.id);
                                ref.invalidate(
                                  dailyActivitiesProvider((
                                    userId: user.id,
                                    date: _selectedDate,
                                  )),
                                );
                              },
                            ),
                          ),
                          if (completed.isNotEmpty)
                            SizedBox(height: r.cardSpacing + 4),
                        ],

                        if (completed.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: neon.withValues(alpha: 0.5),
                                size: 20,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Completadas (${completed.length})',
                                style: GoogleFonts.inter(
                                  fontSize: r.bodyFontSize - 1,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          ...completed.map(
                            (a) => _ActivityTile(
                              activity: a,
                              frequencyLabel: _buildFrequencyLabel(
                                a,
                                templatesMap,
                              ),
                              r: r,
                              neon: neon,
                              surface: theme.colorScheme.surface,
                              onText: theme.colorScheme.onSurface,
                              onAlpha: (x) => theme.colorScheme.onSurface
                                  .withValues(alpha: x),
                              onToggle: () => _toggleComplete(a),
                              onUpdateProgress: (delta) {},
                              onDelete: () async {
                                if (user == null) return;
                                await ref
                                    .read(databaseServiceProvider)
                                    .deleteDailyActivity(a.id);
                                ref.invalidate(
                                  dailyActivitiesProvider((
                                    userId: user.id,
                                    date: _selectedDate,
                                  )),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
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
}

class _HistoryTile extends StatelessWidget {
  final _AggregatedActivity item;
  final int completedCount;
  final ResponsiveHelper r;
  final Color neon;
  final Color onSurface;
  final VoidCallback? onConvert;

  const _HistoryTile({
    required this.item,
    required this.completedCount,
    required this.r,
    required this.neon,
    required this.onSurface,
    required this.onConvert,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastDateStr = DateFormat('d/MM/yyyy').format(item.lastDate);
    final completionPct = item.count == 0
        ? 0.0
        : (completedCount / item.count).clamp(0.0, 1.0);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onConvert,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: onSurface.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.label_outline,
                          size: 16,
                          color: neon.withValues(alpha: 0.8),
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            item.title,
                            style: GoogleFonts.inter(
                              fontSize: r.bodyFontSize,
                              fontWeight: FontWeight.w600,
                              color: onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 5),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _MiniTag(
                          icon: Icons.repeat,
                          text: '${item.count} veces',
                          color: onSurface.withValues(alpha: 0.6),
                        ),
                        _MiniTag(
                          icon: Icons.check_circle_outline,
                          text: '$completedCount hechas',
                          color: neon,
                        ),
                        _MiniTag(
                          icon: Icons.history,
                          text: 'Última: $lastDateStr',
                          color: onSurface.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                    SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: completionPct,
                        minHeight: 3,
                        backgroundColor: onSurface.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation(neon),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              if (item.isHabit)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: neon.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: neon.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.repeat, size: 12, color: neon),
                      SizedBox(width: 4),
                      Text(
                        'Hábito',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: neon,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    Icon(
                      Icons.chevron_right,
                      color: onSurface.withValues(alpha: 0.35),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Convertir',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: neon,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MiniTag({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        SizedBox(width: 3),
        Text(text, style: GoogleFonts.inter(fontSize: 11, color: color)),
      ],
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final ResponsiveHelper r;

  const _ShortcutChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neon = theme.colorScheme.primary;
    return Material(
      color: selected ? neon.withValues(alpha: 0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.isDesktop ? 14 : 12,
            vertical: r.isDesktop ? 8 : 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? neon
                  : theme.colorScheme.onSurface.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected
                    ? neon
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize - 2,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? neon
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final ResponsiveHelper r;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neon = theme.colorScheme.primary;
    return Material(
      color: selected ? neon.withValues(alpha: 0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.isDesktop ? 16 : 14,
            vertical: r.isDesktop ? 10 : 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? neon
                  : theme.colorScheme.onSurface.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? neon
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize - 1,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? neon
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final DailyActivity activity;
  final String frequencyLabel;
  final ResponsiveHelper r;
  final Color neon;
  final Color surface;
  final Color onText;
  final Color Function(double) onAlpha;
  final VoidCallback onToggle;
  final void Function(num delta) onUpdateProgress;
  final VoidCallback onDelete;

  const _ActivityTile({
    required this.activity,
    required this.frequencyLabel,
    required this.r,
    required this.neon,
    required this.surface,
    required this.onText,
    required this.onAlpha,
    required this.onToggle,
    required this.onUpdateProgress,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final done = activity.isCompleted;
    final isNumeric = activity.activityType == ActivityType.numeric;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(r.borderRadius - 2),
        child: InkWell(
          onTap: isNumeric ? null : onToggle,
          borderRadius: BorderRadius.circular(r.borderRadius - 2),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: r.isDesktop ? 14 : 12,
            ),
            child: isNumeric
                ? _buildNumericContent(context, done)
                : _buildBooleanContent(context, done),
          ),
        ),
      ),
    );
  }

  Widget _buildBooleanContent(BuildContext context, bool done) {
    final timeStr = done && activity.completedAt != null
        ? ' ${DateFormat('HH:mm').format(activity.completedAt!)}'
        : '';

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? neon : Colors.transparent,
            border: Border.all(color: done ? neon : onAlpha(0.25), width: 2),
          ),
          child: done
              ? const Icon(Icons.check, color: Colors.white, size: 14)
              : null,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize,
                  fontWeight: done ? FontWeight.w400 : FontWeight.w500,
                  color: done ? onAlpha(0.4) : onText,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
                child: Text(activity.title),
              ),
              SizedBox(height: 2),
              Text(
                frequencyLabel,
                style: GoogleFonts.inter(fontSize: 11, color: onAlpha(0.4)),
              ),
            ],
          ),
        ),
        if (done)
          Text(
            timeStr,
            style: GoogleFonts.inter(fontSize: 11, color: onAlpha(0.3)),
          ),
        SizedBox(width: 4),
        IconButton(
          icon: Icon(Icons.close, size: 18, color: onAlpha(0.25)),
          onPressed: onDelete,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _buildNumericContent(BuildContext context, bool done) {
    final current = activity.currentValue ?? 0;
    final target = activity.targetValue ?? 0;
    final unitStr = activity.unit ?? '';
    final progress = activity.progress;
    final step = activity.stepValue > 0 ? activity.stepValue : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titulo y botones +/- y eliminar
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: GoogleFonts.inter(
                      fontSize: r.bodyFontSize,
                      fontWeight: FontWeight.w500,
                      color: done ? onAlpha(0.4) : onText,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                    child: Text(activity.title),
                  ),
                  SizedBox(height: 2),
                  Text(
                    frequencyLabel,
                    style: GoogleFonts.inter(fontSize: 11, color: onAlpha(0.4)),
                  ),
                ],
              ),
            ),
            if (!done) ...[
              // Boton restar
              _MiniButton(
                icon: Icons.remove,
                onTap: () => onUpdateProgress(-step),
                neon: neon,
              ),
              SizedBox(width: 6),
              // Boton sumar
              _MiniButton(
                icon: Icons.add,
                onTap: () => onUpdateProgress(step),
                neon: neon,
              ),
            ],
            SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: onAlpha(0.25)),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        SizedBox(height: 6),

        // Barra de progreso
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: onAlpha(0.1),
                  valueColor: AlwaysStoppedAnimation(
                    done ? neon.withValues(alpha: 0.5) : neon,
                  ),
                ),
              ),
            ),
            SizedBox(width: 10),
            Text(
              '$current / $target${unitStr.isNotEmpty ? ' $unitStr' : ''}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: done ? FontWeight.w600 : FontWeight.w500,
                color: done ? neon : onAlpha(0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color neon;

  const _MiniButton({
    required this.icon,
    required this.onTap,
    required this.neon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: neon.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: neon),
        ),
      ),
    );
  }
}
