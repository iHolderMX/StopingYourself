import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/activity_template.dart';
import '../../../models/daily_activity.dart';
import 'activity_templates_screen.dart' show activityTemplatesProvider;

class _Preset {
  final String title;
  final String? category;
  final ActivityType activityType;
  final num? targetValue;
  final String? unit;
  final num stepValue;
  final ActivityFrequency frequency;

  const _Preset({
    required this.title,
    this.category,
    required this.activityType,
    this.targetValue,
    this.unit,
    this.stepValue = 1,
    this.frequency = ActivityFrequency.daily,
  });
}

const _presets = <_Preset>[
  _Preset(
    title: 'Hablar con mis papás',
    category: 'Relaciones',
    activityType: ActivityType.boolean,
  ),
  _Preset(
    title: 'Hacer ejercicio',
    category: 'Salud',
    activityType: ActivityType.numeric,
    targetValue: 25,
    unit: 'min',
  ),
  _Preset(
    title: 'Leer',
    category: 'Crecimiento',
    activityType: ActivityType.numeric,
    targetValue: 20,
    unit: 'páginas',
  ),
  _Preset(
    title: 'Beber agua',
    category: 'Salud',
    activityType: ActivityType.numeric,
    targetValue: 8,
    unit: 'vasos',
  ),
  _Preset(
    title: 'Meditar',
    category: 'Bienestar',
    activityType: ActivityType.numeric,
    targetValue: 10,
    unit: 'min',
  ),
  _Preset(
    title: 'Dormir temprano',
    category: 'Salud',
    activityType: ActivityType.boolean,
  ),
  _Preset(
    title: 'Escribir en mi diario',
    category: 'Bienestar',
    activityType: ActivityType.boolean,
  ),
  _Preset(
    title: 'Estirar / movilidad',
    category: 'Salud',
    activityType: ActivityType.boolean,
  ),
  _Preset(
    title: 'Estudiar',
    category: 'Crecimiento',
    activityType: ActivityType.numeric,
    targetValue: 60,
    unit: 'min',
  ),
  _Preset(
    title: 'Caminar',
    category: 'Salud',
    activityType: ActivityType.numeric,
    targetValue: 8000,
    unit: 'pasos',
  ),
  _Preset(
    title: 'Agradecer',
    category: 'Bienestar',
    activityType: ActivityType.boolean,
  ),
  _Preset(
    title: 'No comprar por impulso',
    category: 'Finanzas',
    activityType: ActivityType.boolean,
  ),
];

class ActivityPresetsScreen extends ConsumerStatefulWidget {
  const ActivityPresetsScreen({super.key});

  @override
  ConsumerState<ActivityPresetsScreen> createState() =>
      _ActivityPresetsScreenState();
}

class _ActivityPresetsScreenState extends ConsumerState<ActivityPresetsScreen> {
  final Set<String> _adding = {};

  Future<void> _addPreset(_Preset preset) async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;

    setState(() => _adding.add(preset.title));
    try {
      final existing =
          ref.read(activityTemplatesProvider(user.id)).value ??
          const <ActivityTemplate>[];
      final maxPosition = existing.isEmpty
          ? -1
          : existing.map((t) => t.position).reduce((a, b) => a > b ? a : b);

      final template = ActivityTemplate(
        id: '${user.id}_t_${DateTime.now().millisecondsSinceEpoch}',
        userId: user.id,
        title: preset.title,
        activityType: preset.activityType,
        targetValue: preset.targetValue,
        unit: preset.unit,
        stepValue: preset.stepValue,
        category: preset.category,
        frequency: preset.frequency,
        position: maxPosition + 1,
      );
      await ref.read(databaseServiceProvider).insertActivityTemplate(template);
      ref.invalidate(activityTemplatesProvider(user.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hábito "${preset.title}" agregado')),
        );
      }
    } finally {
      if (mounted) setState(() => _adding.remove(preset.title));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  'Presets sugeridos',
                  style: GoogleFonts.outfit(
                    fontSize: r.titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Agrega un hábito con un solo toque y adáptalo después.',
            style: GoogleFonts.inter(
              fontSize: r.subtitleFontSize,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: r.cardSpacing + 4),
          for (final preset in _presets)
            _PresetCard(
              preset: preset,
              r: r,
              adding: _adding.contains(preset.title),
              onAdd: () => _addPreset(preset),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final _Preset preset;
  final ResponsiveHelper r;
  final bool adding;
  final VoidCallback onAdd;

  const _PresetCard({
    required this.preset,
    required this.r,
    required this.adding,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neon = theme.colorScheme.primary;

    final subtitle = preset.activityType == ActivityType.numeric
        ? 'Cantidad · ${preset.targetValue} ${preset.unit ?? ''}'.trim()
        : 'Si / No';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(r.borderRadius - 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(_categoryIcon(preset.category), size: 22, color: neon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.title,
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        subtitle,
                        if (preset.category != null) preset.category!,
                      ].join(' · '),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              adding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : OutlinedButton(
                      onPressed: onAdd,
                      child: const Text('Agregar'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _categoryIcon(String? category) {
  switch (category) {
    case 'Relaciones':
      return Icons.people_outline;
    case 'Salud':
      return Icons.favorite_outline;
    case 'Crecimiento':
      return Icons.trending_up;
    case 'Bienestar':
      return Icons.spa_outlined;
    case 'Finanzas':
      return Icons.savings_outlined;
    default:
      return Icons.auto_awesome;
  }
}
