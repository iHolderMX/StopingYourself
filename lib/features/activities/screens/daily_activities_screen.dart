import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/daily_activity.dart';

final dailyActivitiesProvider =
    FutureProvider.family<
      List<DailyActivity>,
      ({String userId, DateTime date})
    >((ref, params) {
      return ref
          .watch(databaseServiceProvider)
          .getDailyActivities(params.userId, date: params.date);
    });

class DailyActivitiesScreen extends ConsumerStatefulWidget {
  const DailyActivitiesScreen({super.key});

  @override
  ConsumerState<DailyActivitiesScreen> createState() =>
      _DailyActivitiesScreenState();
}

class _DailyActivitiesScreenState extends ConsumerState<DailyActivitiesScreen> {
  final _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
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

    setState(() => _saving = true);
    final activity = DailyActivity(
      id: '${user.id}_a_${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      title: title,
      scheduledDate: _selectedDate,
    );

    try {
      await ref.read(databaseServiceProvider).insertDailyActivity(activity);
      ref.invalidate(
        dailyActivitiesProvider((userId: user.id, date: _selectedDate)),
      );
      _titleController.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Actividad agregada')));
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
    );
    try {
      await ref.read(databaseServiceProvider).updateDailyActivity(updated);
      ref.invalidate(
        dailyActivitiesProvider((userId: user.id, date: _selectedDate)),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final activitiesAsync = user != null
        ? ref.watch(
            dailyActivitiesProvider((userId: user.id, date: _selectedDate)),
          )
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
            'Organiza tus tareas importantes y marca las completadas.',
            style: GoogleFonts.inter(
              fontSize: r.subtitleFontSize,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
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

          // --- Formulario rapido ---
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'Nueva actividad...',
                    prefixIcon: Icon(Icons.add_task),
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
              SizedBox(width: 10),
              SizedBox(
                height: r.buttonHeight - 4,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Text('Agregar'),
                ),
              ),
            ],
          ),

          SizedBox(height: r.cardSpacing + 8),

          // --- Lista de actividades ---
          if (activitiesAsync == null)
            const Center(child: CircularProgressIndicator())
          else
            activitiesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
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
                    // Pendientes
                    if (pending.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.pending_actions, color: neon, size: 20),
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
                          r: r,
                          neon: neon,
                          surface: theme.colorScheme.surface,
                          onText: theme.colorScheme.onSurface,
                          onAlpha: (x) =>
                              theme.colorScheme.onSurface.withValues(alpha: x),
                          onToggle: () => _toggleComplete(a),
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

                    // Completadas
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
                          r: r,
                          neon: neon,
                          surface: theme.colorScheme.surface,
                          onText: theme.colorScheme.onSurface,
                          onAlpha: (x) =>
                              theme.colorScheme.onSurface.withValues(alpha: x),
                          onToggle: () => _toggleComplete(a),
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
            ),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final DailyActivity activity;
  final ResponsiveHelper r;
  final Color neon;
  final Color surface;
  final Color onText;
  final Color Function(double) onAlpha;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ActivityTile({
    required this.activity,
    required this.r,
    required this.neon,
    required this.surface,
    required this.onText,
    required this.onAlpha,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final done = activity.isCompleted;
    final timeStr = done && activity.completedAt != null
        ? ' ${DateFormat('HH:mm').format(activity.completedAt!)}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(r.borderRadius - 2),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(r.borderRadius - 2),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: r.isDesktop ? 14 : 12,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? neon : Colors.transparent,
                    border: Border.all(
                      color: done ? neon : onAlpha(0.25),
                      width: 2,
                    ),
                  ),
                  child: done
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: GoogleFonts.inter(
                      fontSize: r.bodyFontSize,
                      fontWeight: done ? FontWeight.w400 : FontWeight.w500,
                      color: done ? onAlpha(0.4) : onText,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                    child: Text(activity.title),
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
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
