import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/activity_template.dart';
import '../../../models/daily_activity.dart' show ActivityType;

final activityTemplatesProvider =
    FutureProvider.family<List<ActivityTemplate>, String>((ref, userId) {
      return ref.watch(databaseServiceProvider).getActivityTemplates(userId);
    });

class ActivityTemplatesScreen extends ConsumerStatefulWidget {
  const ActivityTemplatesScreen({super.key});

  @override
  ConsumerState<ActivityTemplatesScreen> createState() =>
      _ActivityTemplatesScreenState();
}

class _ActivityTemplatesScreenState
    extends ConsumerState<ActivityTemplatesScreen> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _unitController = TextEditingController();
  final _stepController = TextEditingController();
  final _categoryController = TextEditingController();
  final _monthDaysController = TextEditingController();
  final _intervalDaysController = TextEditingController();
  final _graceController = TextEditingController();

  ActivityType _activityType = ActivityType.boolean;
  ActivityFrequency _frequency = ActivityFrequency.daily;
  final Set<int> _selectedWeekdays = <int>{};
  int _priority = 0;
  bool _reminderEnabled = false;
  String? _reminderTime;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    _stepController.dispose();
    _categoryController.dispose();
    _monthDaysController.dispose();
    _intervalDaysController.dispose();
    _graceController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildFrequencyConfig() {
    switch (_frequency) {
      case ActivityFrequency.weekly:
        return {'days_of_week': _selectedWeekdays.toList()..sort()};
      case ActivityFrequency.monthly:
        final days = _monthDaysController.text
            .split(',')
            .map((e) => int.tryParse(e.trim()))
            .whereType<int>()
            .toList();
        return {'days_of_month': days};
      case ActivityFrequency.custom:
        final interval = int.tryParse(_intervalDaysController.text.trim()) ?? 1;
        return {'interval_days': interval <= 0 ? 1 : interval};
      case ActivityFrequency.daily:
        return const {};
    }
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _reminderTime = _formatTime(picked));
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _save() async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa un nombre')));
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
    final category = _categoryController.text.trim();

    num stepValue = 1;
    if (_activityType == ActivityType.numeric) {
      final rawStep = _stepController.text.trim();
      if (rawStep.isNotEmpty) {
        final s = num.tryParse(rawStep);
        if (s != null && s > 0) stepValue = s;
      }
    }

    int graceDays = 0;
    final rawGrace = _graceController.text.trim();
    if (rawGrace.isNotEmpty) {
      final g = int.tryParse(rawGrace);
      if (g != null && g > 0) graceDays = g;
    }

    final existing =
        ref.read(activityTemplatesProvider(user.id)).value ??
        const <ActivityTemplate>[];
    final maxPosition = existing.isEmpty
        ? -1
        : existing.map((t) => t.position).reduce((a, b) => a > b ? a : b);

    final template = ActivityTemplate(
      id: '${user.id}_t_${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      title: title,
      activityType: _activityType,
      targetValue: targetValue,
      unit: unit.isNotEmpty ? unit : null,
      stepValue: stepValue,
      category: category.isNotEmpty ? category : null,
      frequency: _frequency,
      frequencyConfig: _buildFrequencyConfig(),
      position: maxPosition + 1,
      priority: _priority,
      graceDays: graceDays,
      reminderEnabled: _reminderEnabled,
      reminderTime: _reminderEnabled ? _reminderTime : null,
    );

    setState(() => _saving = true);
    try {
      await ref.read(databaseServiceProvider).insertActivityTemplate(template);
      ref.invalidate(activityTemplatesProvider(user.id));
      _titleController.clear();
      _targetController.clear();
      _unitController.clear();
      _stepController.clear();
      _categoryController.clear();
      _monthDaysController.clear();
      _intervalDaysController.clear();
      _graceController.clear();
      setState(() {
        _activityType = ActivityType.boolean;
        _frequency = ActivityFrequency.daily;
        _selectedWeekdays.clear();
        _priority = 0;
        _reminderEnabled = false;
        _reminderTime = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Hábito creado')));
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

  Future<void> _reorder(List<ActivityTemplate> templates, int from, int to) async {
    if (to < 0 || to >= templates.length || from == to) return;
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;

    final list = [...templates];
    final item = list.removeAt(from);
    list.insert(to, item);

    final db = ref.read(databaseServiceProvider);
    for (int i = 0; i < list.length; i++) {
      if (list[i].position != i) {
        await db.updateActivityTemplate(list[i].copyWith(position: i));
      }
    }
    ref.invalidate(activityTemplatesProvider(user.id));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final templatesAsync = user != null
        ? ref.watch(activityTemplatesProvider(user.id))
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
                  'Hábitos recurrentes',
                  style: GoogleFonts.outfit(
                    fontSize: r.titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.auto_awesome_outlined),
                tooltip: 'Presets sugeridos',
                onPressed: () => context.push('/activity-presets'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Define actividades que se repiten cada día, semana o mes.',
            style: GoogleFonts.inter(
              fontSize: r.subtitleFontSize,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'Nombre del hábito...',
                    prefixIcon: Icon(Icons.repeat),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    hintText: 'Categoría (opcional)',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _TypeChip(
                      label: 'Si / No',
                      selected: _activityType == ActivityType.boolean,
                      onTap: () => setState(
                        () => _activityType = ActivityType.boolean,
                      ),
                      r: r,
                    ),
                    const SizedBox(width: 10),
                    _TypeChip(
                      label: 'Cantidad',
                      selected: _activityType == ActivityType.numeric,
                      onTap: () => setState(
                        () => _activityType = ActivityType.numeric,
                      ),
                      r: r,
                    ),
                  ],
                ),
                if (_activityType == ActivityType.numeric) ...[
                  const SizedBox(height: 12),
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
                      const SizedBox(width: 10),
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: _stepController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Paso (incremento)',
                      helperText: 'Cuánto suma o resta cada toque. Por defecto 1.',
                      prefixIcon: Icon(Icons.exposure_plus_1),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _FrequencyDropdown(
                  frequency: _frequency,
                  onChanged: (f) => setState(() => _frequency = f),
                ),
                if (_frequency == ActivityFrequency.weekly) ...[
                  const SizedBox(height: 12),
                  _WeekdaySelector(
                    selected: _selectedWeekdays,
                    onToggle: (day) => setState(() {
                      if (!_selectedWeekdays.add(day)) {
                        _selectedWeekdays.remove(day);
                      }
                    }),
                    r: r,
                  ),
                ],
                if (_frequency == ActivityFrequency.monthly) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _monthDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Días del mes (ej: 1,15)',
                      prefixIcon: Icon(Icons.calendar_month),
                    ),
                  ),
                ],
                if (_frequency == ActivityFrequency.custom) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _intervalDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Cada N días (ej: 2)',
                      prefixIcon: Icon(Icons.timelapse),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Prioridad',
                  style: GoogleFonts.inter(
                    fontSize: r.bodyFontSize - 1,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final p in const [0, 1, 2])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _PriorityChip(
                          label: _priorityLabel(p),
                          color: _priorityColor(p),
                          selected: _priority == p,
                          onTap: () => setState(() => _priority = p),
                          r: r,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _graceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Días de gracia',
                    helperText:
                        'Cuántos días puedes fallar sin perder la racha. Por defecto 0.',
                    prefixIcon: Icon(Icons.local_fire_department_outlined),
                  ),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Recordatorio'),
                  subtitle: Text(
                    _reminderEnabled
                        ? (_reminderTime != null
                              ? 'A las $_reminderTime'
                              : 'Sin hora definida')
                        : 'Aviso para no olvidar este hábito',
                  ),
                  value: _reminderEnabled,
                  onChanged: (v) => setState(() => _reminderEnabled = v),
                ),
                if (_reminderEnabled) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(_reminderTime ?? 'Elegir hora'),
                      onPressed: _pickReminderTime,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
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
                    label: Text(_saving ? 'Guardando...' : 'Crear hábito'),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: r.cardSpacing + 8),

          // --- Lista de hábitos ---
          if (templatesAsync == null)
            const Center(child: CircularProgressIndicator())
          else
            templatesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (templates) {
                if (templates.isEmpty) {
                  return Center(
                    child: Text(
                      'Aún no tienes hábitos recurrentes',
                      style: GoogleFonts.inter(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < templates.length; i++)
                      _TemplateTile(
                        template: templates[i],
                        r: r,
                        onMoveUp: i > 0
                            ? () => _reorder(templates, i, i - 1)
                            : null,
                        onMoveDown: i < templates.length - 1
                            ? () => _reorder(templates, i, i + 1)
                            : null,
                        onOpen: () =>
                            context.push('/activity-calendar/${templates[i].id}'),
                        onDelete: () async {
                          await ref
                              .read(databaseServiceProvider)
                              .deleteActivityTemplate(templates[i].id);
                          if (user != null) {
                            ref.invalidate(activityTemplatesProvider(user.id));
                          }
                        },
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

String _frequencyLabel(ActivityFrequency f) {
  switch (f) {
    case ActivityFrequency.daily:
      return 'Diario';
    case ActivityFrequency.weekly:
      return 'Semanal';
    case ActivityFrequency.monthly:
      return 'Mensual';
    case ActivityFrequency.custom:
      return 'Personalizado';
  }
}

String _priorityLabel(int p) {
  switch (p) {
    case 2:
      return 'Alta';
    case 1:
      return 'Media';
    default:
      return 'Baja';
  }
}

Color _priorityColor(int p) {
  switch (p) {
    case 2:
      return Colors.redAccent;
    case 1:
      return Colors.orange;
    default:
      return Colors.grey;
  }
}

class _TemplateTile extends StatelessWidget {
  final ActivityTemplate template;
  final ResponsiveHelper r;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _TemplateTile({
    required this.template,
    required this.r,
    this.onMoveUp,
    this.onMoveDown,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neon = theme.colorScheme.primary;
    final category = template.category;
    final subtitle = [
      _frequencyLabel(template.frequency),
      template.activityType == ActivityType.numeric ? 'Cantidad' : 'Si / No',
      if (category != null && category.isNotEmpty) category,
      if (template.reminderEnabled && template.reminderTime != null)
        'Recordatorio ${template.reminderTime}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(r.borderRadius - 2),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(r.borderRadius - 2),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.repeat, size: 20, color: neon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              template.title,
                              style: GoogleFonts.inter(
                                fontSize: r.bodyFontSize,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          _PriorityBadge(priority: template.priority),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _OrderButton(icon: Icons.keyboard_arrow_up, onTap: onMoveUp),
                    _OrderButton(icon: Icons.keyboard_arrow_down, onTap: onMoveDown),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final int priority;

  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _priorityLabel(priority),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _OrderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _OrderButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
              : theme.colorScheme.onSurface.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}

class _FrequencyDropdown extends StatelessWidget {
  final ActivityFrequency frequency;
  final void Function(ActivityFrequency) onChanged;

  const _FrequencyDropdown({required this.frequency, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ActivityFrequency>(
      initialValue: frequency,
      decoration: const InputDecoration(
        labelText: 'Frecuencia',
        prefixIcon: Icon(Icons.event_repeat),
      ),
      items: ActivityFrequency.values
          .map(
            (f) => DropdownMenuItem(
              value: f,
              child: Text(_frequencyLabel(f)),
            ),
          )
          .toList(),
      onChanged: (f) {
        if (f != null) onChanged(f);
      },
    );
  }
}

class _WeekdaySelector extends StatelessWidget {
  final Set<int> selected;
  final void Function(int) onToggle;
  final ResponsiveHelper r;

  const _WeekdaySelector({
    required this.selected,
    required this.onToggle,
    required this.r,
  });

  static const _labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (int i = 1; i <= 7; i++)
          FilterChip(
            label: Text(_labels[i - 1]),
            selected: selected.contains(i),
            onSelected: (_) => onToggle(i),
            showCheckmark: false,
          ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ResponsiveHelper r;

  const _TypeChip({
    required this.label,
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
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: r.bodyFontSize - 1,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? neon
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final ResponsiveHelper r;

  const _PriorityChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
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
                  ? color
                  : theme.colorScheme.onSurface.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: r.bodyFontSize - 1,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? color
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
