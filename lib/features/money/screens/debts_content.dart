import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/debt.dart';

final debtsProvider = FutureProvider.family<List<Debt>, String>(
  (ref, userId) => ref.watch(databaseServiceProvider).getDebts(userId),
);

class DebtsContent extends ConsumerWidget {
  final bool compact;
  final double totalSaved;

  const DebtsContent({super.key, this.compact = true, required this.totalSaved});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final userId = user?.id;

    final debtsAsync = userId != null ? ref.watch(debtsProvider(userId)) : null;
    final debts = debtsAsync?.asData?.value ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Deudas',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (debts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No tienes deudas registradas',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ...debts.map((debt) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(debt.name),
                      Text('\$${debt.remainingAmount.toStringAsFixed(2)}'),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
