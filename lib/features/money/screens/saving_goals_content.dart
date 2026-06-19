import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/saving_goal.dart';

final savingGoalsProvider = FutureProvider.family<List<SavingGoal>, String>(
  (ref, userId) => ref.watch(databaseServiceProvider).getSavingGoals(userId),
);

class SavingGoalsContent extends ConsumerStatefulWidget {
  final bool compact;
  const SavingGoalsContent({super.key, this.compact = true});

  @override
  ConsumerState<SavingGoalsContent> createState() => _SavingGoalsContentState();
}

class _SavingGoalsContentState extends ConsumerState<SavingGoalsContent> {
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _currentAmountController = TextEditingController();
  final _urlController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;
    
    final name = _nameController.text.trim();
    final target = double.tryParse(_targetAmountController.text.trim());
    final current = double.tryParse(_currentAmountController.text.trim()) ?? 0;
    final url = _urlController.text.trim();

    if (name.isEmpty || target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un nombre y monto meta válido')),
      );
      return;
    }

    setState(() => _saving = true);
    final goal = SavingGoal(
      id: '${user.id}_sg_${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      name: name,
      targetAmount: target,
      currentAmount: current,
      url: url.isEmpty ? null : url,
      isCompleted: current >= target,
    );

    try {
      await ref.read(databaseServiceProvider).insertSavingGoal(goal);
      ref.invalidate(savingGoalsProvider(user.id));
      setState(() {
        _saving = false;
        _nameController.clear();
        _targetAmountController.clear();
        _currentAmountController.clear();
        _urlController.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meta de ahorro guardada')),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  Future<void> _updateAmount(SavingGoal goal) async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;

    final controller = TextEditingController(text: goal.currentAmount.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Actualizar progreso'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Monto actual (\$)',
            prefixIcon: Icon(Icons.attach_money),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null) Navigator.pop(ctx, val);
            },
            child: Text('Actualizar'),
          ),
        ],
      ),
    );

    if (result != null) {
      final updatedGoal = SavingGoal(
        id: goal.id,
        userId: goal.userId,
        name: goal.name,
        targetAmount: goal.targetAmount,
        currentAmount: result,
        url: goal.url,
        isCompleted: result >= goal.targetAmount,
        createdAt: goal.createdAt,
      );
      try {
        await ref.read(databaseServiceProvider).updateSavingGoal(updatedGoal);
        ref.invalidate(savingGoalsProvider(user.id));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al actualizar: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteGoal(SavingGoal goal) async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar meta?'),
        content: Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(databaseServiceProvider).deleteSavingGoal(goal.id);
        ref.invalidate(savingGoalsProvider(user.id));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final goalsAsync = user != null ? ref.watch(savingGoalsProvider(user.id)) : null;
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final neon = theme.colorScheme.primary;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Metas de Ahorro',
          style: GoogleFonts.outfit(
            fontSize: r.titleFontSize,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Ahorra para lo que más quieres.',
          style: GoogleFonts.inter(
            fontSize: r.subtitleFontSize,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        SizedBox(height: r.cardSpacing + 4),

        // --- Formulario ---
        Container(
          padding: EdgeInsets.all(r.cardSpacing + 2),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nueva meta',
                style: GoogleFonts.outfit(
                  fontSize: r.subtitleFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: r.cardSpacing),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la meta',
                  hintText: 'Ej: Nuevo Celular, Viaje, etc.',
                  prefixIcon: Icon(Icons.star_outline),
                ),
              ),
              SizedBox(height: r.cardSpacing - 4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _targetAmountController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Meta (\$)',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _currentAmountController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Ya tengo (\$)',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.cardSpacing - 4),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'URL (opcional)',
                  hintText: 'Link de Mercado Libre, Amazon, etc.',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              SizedBox(height: r.cardSpacing),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_task),
                label: const Text('Crear Meta'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: neon.withValues(alpha: 0.1),
                  foregroundColor: neon,
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: r.cardSpacing + 8),

        // --- Lista de metas ---
        goalsAsync?.when(
          data: (goals) {
            if (goals.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.auto_graph, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
                      SizedBox(height: 12),
                      Text(
                        'Aún no tienes metas',
                        style: GoogleFonts.inter(color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: goals.length,
              separatorBuilder: (_, __) => SizedBox(height: 12),
              itemBuilder: (context, index) {
                final goal = goals[index];
                final progress = goal.progress.clamp(0.0, 1.0);
                final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
                
                return Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: neon.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  goal.name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (goal.url != null)
                                  GestureDetector(
                                    onTap: () async {
                                      final uri = Uri.tryParse(goal.url!);
                                      if (uri != null && await canLaunchUrl(uri)) {
                                        await launchUrl(uri);
                                      }
                                    },
                                    child: Text(
                                      'Ver producto',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: neon,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit_outlined, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                            onPressed: () => _updateAmount(goal),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.withValues(alpha: 0.5)),
                            onPressed: () => _deleteGoal(goal),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: neon,
                            ),
                          ),
                          Text(
                            '${currencyFormat.format(goal.currentAmount)} / ${currencyFormat.format(goal.targetAmount)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: neon.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(neon),
                        ),
                      ),
                      if (goal.isCompleted)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 16, color: Colors.green),
                              SizedBox(width: 4),
                              Text(
                                '¡Meta alcanzada!',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => Center(child: CircularProgressIndicator()),
          error: (e, __) => Text('Error: $e'),
        ),
      ],
    );

    if (widget.compact) {
      return content;
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.padHorizontal),
      child: content,
    );
  }
}
