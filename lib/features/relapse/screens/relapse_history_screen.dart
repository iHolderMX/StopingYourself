import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/relapse_record.dart';
import '../relapse_data.dart';

/// Pantalla aparte para el historial completo de recaidas.
///
/// Los datos completos (incluidas las notas) solo se cargan al abrir esta
/// pantalla, no en el panel principal. Se entra aqui bajo demanda desde el
/// boton "Ver historial completo".
class RelapseHistoryScreen extends ConsumerStatefulWidget {
  const RelapseHistoryScreen({super.key});

  @override
  ConsumerState<RelapseHistoryScreen> createState() =>
      _RelapseHistoryScreenState();
}

class _RelapseHistoryScreenState extends ConsumerState<RelapseHistoryScreen> {
  /// Etiqueta legible del tipo de una recaida (incluye el tipo personalizado).
  String _typeLabel(RelapseRecord r) {
    return r.relapseType == 'Otro' ? (r.customType ?? 'Otro') : r.relapseType;
  }

  /// Duración de la racha que precedió a cada recaida dentro de su mismo tipo.
  /// Se calcula como la diferencia con la recaida anterior de ese tipo.
  Map<String, Duration> _streakBefore(List<RelapseRecord> records) {
    final result = <String, Duration>{};
    final byType = <String, List<RelapseRecord>>{};
    for (final r in records) {
      byType.putIfAbsent(_typeLabel(r), () => []).add(r);
    }
    for (final entry in byType.values) {
      final sorted = [...entry]
        ..sort((a, b) => a.relapseDate.compareTo(b.relapseDate));
      for (int i = 1; i < sorted.length; i++) {
        result[sorted[i].id] = sorted[i].relapseDate.difference(
          sorted[i - 1].relapseDate,
        );
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final neon = theme.colorScheme.primary;

    return SingleChildScrollView(
      padding: r.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                color: neon,
                tooltip: 'Volver',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historial de recaidas',
                      style: GoogleFonts.outfit(
                        fontSize: r.titleFontSize - 4,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Revisa, corrige o elimina recaidas pasadas',
                      style: GoogleFonts.inter(
                        fontSize: r.subtitleFontSize - 2,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Reserva espacio para el boton de menu en movil.
              if (r.isMobile) const SizedBox(width: 48),
            ],
          ),
          SizedBox(height: r.cardSpacing + 4),
          if (user == null)
            _buildEmptyState(theme, r, neon)
          else
            ref
                .watch(relapseHistoryProvider(user.id))
                .when(
                  loading: () => Padding(
                    padding: EdgeInsets.symmetric(vertical: r.padVertical * 3),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (records) => _buildList(records, theme, r, neon),
                ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildList(
    List<RelapseRecord> records,
    ThemeData theme,
    ResponsiveHelper r,
    Color neon,
  ) {
    if (records.isEmpty) return _buildEmptyState(theme, r, neon);

    final streaks = _streakBefore(records);

    // Orden de aparicion de tipos para asignar colores consistentes.
    final typeOrder = <String>[];
    for (final rec in records) {
      final key = _typeLabel(rec);
      if (!typeOrder.contains(key)) typeOrder.add(key);
    }

    Color colorFor(String key) {
      final idx = relapseTypes.contains(key)
          ? relapseTypes.indexOf(key)
          : typeOrder.indexOf(key);
      return relapseTypeColor(idx, neon);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.cardSpacing + 2),
          margin: EdgeInsets.only(bottom: r.cardSpacing + 4),
          decoration: BoxDecoration(
            color: neon.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(r.borderRadius),
          ),
          child: Row(
            children: [
              Icon(Icons.history, color: neon, size: r.iconSizeMedium),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${records.length} recaida${records.length != 1 ? 's' : ''} registrada${records.length != 1 ? 's' : ''}',
                  style: GoogleFonts.outfit(
                    fontSize: r.subtitleFontSize,
                    fontWeight: FontWeight.w600,
                    color: neon,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...records.map(
          (rec) => _buildRecordCard(
            rec,
            streaks[rec.id],
            colorFor(_typeLabel(rec)),
            theme,
            r,
            neon,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordCard(
    RelapseRecord record,
    Duration? streakBefore,
    Color accent,
    ThemeData theme,
    ResponsiveHelper r,
    Color neon,
  ) {
    final label = _typeLabel(record);
    final notes = record.notes?.trim();
    final hasNotes = notes != null && notes.isNotEmpty;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: r.cardSpacing),
      padding: EdgeInsets.all(r.cardSpacing + 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(r.borderRadius),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: r.subtitleFontSize,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: neon, size: 20),
                onPressed: () => context.pop(record),
                tooltip: 'Editar esta recaida',
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
                onPressed: () => _confirmDelete(record, label),
                tooltip: 'Eliminar esta recaida',
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                Icons.event,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 6),
              Text(
                DateFormat('dd/MM/yyyy').format(record.relapseDate),
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize - 2,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(width: 14),
              Icon(
                Icons.access_time,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 6),
              Text(
                DateFormat('HH:mm').format(record.relapseDate),
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize - 2,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          if (streakBefore != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: r.cardSpacing,
                vertical: r.cardSpacing - 4,
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.timelapse, size: 16, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    'Racha previa: ',
                    style: GoogleFonts.inter(
                      fontSize: r.bodyFontSize - 2,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      formatRelapseDuration(streakBefore),
                      style: GoogleFonts.outfit(
                        fontSize: r.bodyFontSize - 1,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (hasNotes) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notes,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notes,
                    style: GoogleFonts.inter(
                      fontSize: r.bodyFontSize - 2,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ResponsiveHelper r, Color neon) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.isDesktop ? 48 : 36),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(r.borderRadius),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.history, size: r.iconSizeLarge, color: neon),
            SizedBox(height: r.cardSpacing),
            Text(
              'Sin historial todavia',
              style: GoogleFonts.inter(
                fontSize: r.bodyFontSize,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Las recaidas que registres apareceran aqui',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: r.bodyFontSize - 2,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(RelapseRecord record, String typeLabel) async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar recaida'),
        content: Text(
          '¿Seguro que quieres eliminar la recaida de "$typeLabel" '
          'del ${DateFormat('dd/MM/yyyy').format(record.relapseDate)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(databaseServiceProvider).deleteRelapse(record.id);
    ref.invalidate(relapseSummaryProvider(user.id));
    ref.invalidate(relapseHistoryProvider(user.id));

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recaida eliminada')));
    }
  }
}
