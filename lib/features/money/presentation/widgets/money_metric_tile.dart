import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/responsive_helper.dart';

/// Tarjeta de una metrica financiera.
///
/// Reemplaza a `_SummaryCard`, `_MetricTile`, `_StatTile` y `_miniStat`, que
/// eran cuatro variantes privadas del mismo componente repartidas en cuatro
/// archivos. [subtitle] es opcional: las que antes eran `_StatTile` no lo usan.
class MoneyMetricTile extends StatelessWidget {
  const MoneyMetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.responsive,
    this.subtitle,
    this.width,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ResponsiveHelper responsive;

  /// Detalle bajo la etiqueta. Si es `null` no se reserva espacio.
  final String? subtitle;

  /// Ancho fijo. Si es `null` se usa el ancho segun el tamano de pantalla.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = responsive;
    final resolvedWidth =
        width ?? (r.isDesktop ? 200 : (r.isTablet ? 170 : null));

    return Container(
      width: resolvedWidth,
      constraints: const BoxConstraints(minWidth: 140),
      padding: EdgeInsets.all(r.cardSpacing),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(r.borderRadius - 2),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: r.iconSizeMedium - 4),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: r.isDesktop ? 20 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: r.bodyFontSize - 2,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: r.bodyFontSize - 3,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
