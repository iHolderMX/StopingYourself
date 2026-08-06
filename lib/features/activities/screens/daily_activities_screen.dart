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
  final _targetController = TextEditingController();
  final _unitController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  ActivityType _activityType = ActivityType.boolean;
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

    num? targetValue;
    if (_activityType == ActivityType.numeric) {
      final raw = _targetController.text.trim();
      if (raw.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ingresa un valor objetivo')));
        return;
      }
      targetValue = num.tryParse(raw);
      if (targetValue == null || targetValue <= 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('El valor debe ser mayor a 0')));
        return;
      }
    }

    final unit = _unitController.text.trim();

    setState(() => _saving = true);
    final activity = DailyActivity(
      id: '${user.id}_a_${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      title: title,
      scheduledDate: _selectedDate,
      activityType: _activityType,
      targetValue: targetValue,
      currentValue: _activityType == ActivityType.numeric ? 0 : null,
      unit: unit.isNotEmpty ? unit : null,
    );

    try {
      await ref.read(databaseServiceProvider).insertDailyActivity(activity);
      ref.invalidate(
        dailyActivitiesProvider((userId: user.id, date: _selectedDate)),
      );
      _titleController.clear();
      _targetController.clear();
      _unitController.clear();
      setState(() => _activityType = ActivityType.boolean);
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
    final newValue = ((activity.currentValue ?? 0) + delta).clamp(0, activity.targetValue ?? 999999);
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
            'Organiza tus tareas importantes y haz seguimiento de tus habitos.',
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
                      onTap: () => setState(() => _activityType = ActivityType.boolean),
                      r: r,
                    ),
                    SizedBox(width: 10),
                    _TypeChip(
                      label: 'Cantidad',
                      icon: Icons.numbers,
                      selected: _activityType == ActivityType.numeric,
                      onTap: () => setState(() => _activityType = ActivityType.numeric),
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
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                          onUpdateProgress: (delta) => _updateProgress(a, delta),
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
                          r: r,
                          neon: neon,
                          surface: theme.colorScheme.surface,
                          onText: theme.colorScheme.onSurface,
                          onAlpha: (x) =>
                              theme.colorScheme.onSurface.withValues(alpha: x),
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
            ),
          SizedBox(height: 40),
        ],
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
              color: selected ? neon : theme.colorScheme.onSurface.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? neon : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize - 1,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? neon : theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
            border: Border.all(
              color: done ? neon : onAlpha(0.25),
              width: 2,
            ),
          ),
          child:
              done ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titulo y botones +/- y eliminar
        Row(
          children: [
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize,
                  fontWeight: FontWeight.w500,
                  color: done ? onAlpha(0.4) : onText,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
                child: Text(activity.title),
              ),
            ),
            if (!done) ...[
              // Boton restar
              _MiniButton(
                icon: Icons.remove,
                onTap: () => onUpdateProgress(-1),
                neon: neon,
              ),
              SizedBox(width: 6),
              // Boton sumar
              _MiniButton(
                icon: Icons.add,
                onTap: () => onUpdateProgress(1),
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
