import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';

class NextQuincenaCard extends ConsumerWidget {
  const NextQuincenaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);

    return Container(
      padding: EdgeInsets.all(r.padHorizontal),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(r.borderRadius - 2),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            color: theme.colorScheme.primary,
            size: r.iconSizeMedium,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Proxima Quincena',
                style: GoogleFonts.outfit(
                  fontSize: r.subtitleFontSize - 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Planifica tus gastos',
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize - 2,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
