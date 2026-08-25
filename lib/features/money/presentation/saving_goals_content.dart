import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/responsive_helper.dart';
import '../../../models/saving_goal.dart';
import '../application/money_error_message.dart';
import '../application/saving_goals_controller.dart';
import '../data/money_providers.dart';
import '../domain/saving_goal_image_rules.dart';
import '../domain/saving_goal_rules.dart';
import 'money_colors.dart';
import 'widgets/goal_image_picker_field.dart';
import 'widgets/saving_goal_image.dart';

/// Metas de ahorro: alta, edicion completa, progreso y listado.
class SavingGoalsContent extends ConsumerStatefulWidget {
  const SavingGoalsContent({super.key, this.compact = true});

  final bool compact;

  @override
  ConsumerState<SavingGoalsContent> createState() => _SavingGoalsContentState();
}

class _SavingGoalsContentState extends ConsumerState<SavingGoalsContent> {
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _currentAmountController = TextEditingController();
  final _urlController = TextEditingController();
  bool _saving = false;

  /// Foto elegida para la meta que se esta creando, aun sin subir.
  SavingGoalImageUpload? _newGoalImage;

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImageForNewGoal() async {
    try {
      final image = await pickSavingGoalImage();
      if (image == null || !mounted) return;
      setState(() => _newGoalImage = image);
    } catch (error) {
      if (mounted) _showMessage('No se pudo abrir la galeria: $error');
    }
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _saving) return;

    final target = double.tryParse(_targetAmountController.text.trim());
    if (target == null) {
      _showMessage('Ingresa un monto meta valido');
      return;
    }
    final current = double.tryParse(_currentAmountController.text.trim()) ?? 0;

    setState(() => _saving = true);
    try {
      await ref.read(savingGoalsControllerProvider).add(
        userId: userId,
        name: _nameController.text,
        targetAmount: target,
        currentAmount: current,
        url: _urlController.text,
        image: _newGoalImage,
      );
      if (!mounted) return;
      setState(() {
        _nameController.clear();
        _targetAmountController.clear();
        _currentAmountController.clear();
        _urlController.clear();
        _newGoalImage = null;
      });
      _showMessage('Meta de ahorro guardada');
    } catch (error) {
      if (mounted) _showMessage(describeMoneyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Abre el editor completo de la meta.
  Future<void> _editGoal(String userId, SavingGoal goal) async {
    final result = await showDialog<_GoalEditResult>(
      context: context,
      builder: (ctx) => _EditGoalDialog(goal: goal),
    );
    if (result == null || !mounted) return;

    try {
      await ref.read(savingGoalsControllerProvider).edit(
        userId: userId,
        goal: goal,
        name: result.name,
        targetAmount: result.targetAmount,
        currentAmount: result.currentAmount,
        url: result.url,
        imageAction: result.imageAction,
      );
      if (mounted) _showMessage('Meta actualizada');
    } catch (error) {
      if (mounted) _showMessage(describeMoneyError(error));
    }
  }

  Future<void> _deleteGoal(String userId, SavingGoal goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar meta?'),
        content: Text(
          goal.hasImage
              ? 'Se borrara la meta y su foto. Esta accion no se puede '
                    'deshacer.'
              : 'Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar',
              style: TextStyle(color: MoneyColors.negative),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await ref
          .read(savingGoalsControllerProvider)
          .delete(userId: userId, goal: goal);
    } catch (error) {
      if (mounted) _showMessage(describeMoneyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final userId = ref.watch(currentUserIdProvider);

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
        const SizedBox(height: 6),
        Text(
          'Ahorra para lo que mas quieres.',
          style: GoogleFonts.inter(
            fontSize: r.subtitleFontSize,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        SizedBox(height: r.cardSpacing + 4),
        _form(theme, r),
        SizedBox(height: r.cardSpacing + 8),
        _list(theme, r, userId),
      ],
    );

    if (widget.compact) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: content,
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(r.padHorizontal),
      child: content,
    );
  }

  Widget _form(ThemeData theme, ResponsiveHelper r) {
    final neon = theme.colorScheme.primary;

    return Container(
      padding: EdgeInsets.all(widget.compact ? 12 : r.cardSpacing + 2),
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
          if (widget.compact)
            Column(
              children: [
                _targetField(),
                SizedBox(height: r.cardSpacing - 4),
                _currentField(),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: _targetField()),
                const SizedBox(width: 12),
                Expanded(child: _currentField()),
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
          GoalImagePickerField(
            currentImagePath: null,
            pickedImage: _newGoalImage,
            imageRemoved: false,
            enabled: !_saving,
            onPick: _pickImageForNewGoal,
            onRemove: () => setState(() => _newGoalImage = null),
          ),
          SizedBox(height: r.cardSpacing),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_task),
            label: Text(_saving ? 'Guardando...' : 'Crear Meta'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: neon.withValues(alpha: 0.1),
              foregroundColor: neon,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _targetField() => TextField(
    controller: _targetAmountController,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: const InputDecoration(
      labelText: 'Meta (\$)',
      prefixIcon: Icon(Icons.flag_outlined),
    ),
  );

  Widget _currentField() => TextField(
    controller: _currentAmountController,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: const InputDecoration(
      labelText: 'Ya tengo (\$)',
      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
    ),
  );

  Widget _list(ThemeData theme, ResponsiveHelper r, String? userId) {
    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ref.watch(savingGoalsProvider(userId)).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Text(describeMoneyError(error)),
      data: (goals) {
        if (goals.isEmpty) return _emptyBox(theme);
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: goals.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              _goalCard(theme, r, userId, goals[index]),
        );
      },
    );
  }

  Widget _emptyBox(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.auto_graph,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 12),
            Text(
              'Aun no tienes metas',
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalCard(
    ThemeData theme,
    ResponsiveHelper r,
    String userId,
    SavingGoal goal,
  ) {
    final neon = theme.colorScheme.primary;
    final progress = SavingGoalRules.progressRatio(goal);

    return Container(
      padding: EdgeInsets.all(widget.compact ? 12 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: neon.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (goal.hasImage) ...[
            // Toda la imagen es tocable para abrir el visor.
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => showSavingGoalImageViewer(
                context,
                imagePath: goal.imagePath!,
                goalName: goal.name,
              ),
              child: Stack(
                children: [
                  SavingGoalImage(
                    imagePath: goal.imagePath!,
                    height: widget.compact ? 110 : 160,
                    width: double.infinity,
                    borderRadius: 10,
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.zoom_in,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: widget.compact ? 8 : 12),
          ],
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: GoogleFonts.outfit(
                        fontSize: widget.compact ? 14 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (goal.url != null)
                      GestureDetector(
                        onTap: () => _openUrl(goal.url!),
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
                icon: Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                tooltip: 'Editar meta',
                onPressed: () => _editGoal(userId, goal),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: MoneyColors.negative.withValues(alpha: 0.6),
                ),
                tooltip: 'Eliminar meta',
                onPressed: () => _deleteGoal(userId, goal),
              ),
            ],
          ),
          SizedBox(height: widget.compact ? 8 : 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.inter(
                  fontSize: widget.compact ? 12 : 14,
                  fontWeight: FontWeight.bold,
                  color: neon,
                ),
              ),
              Text(
                '\$${goal.currentAmount.toStringAsFixed(0)} / '
                '\$${goal.targetAmount.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: widget.compact ? 11 : 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: MoneyColors.positive,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Meta alcanzada!',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MoneyColors.positive,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      _showMessage('No se pudo abrir el enlace');
    }
  }
}

/// Lo que el editor devuelve cuando el usuario guarda.
class _GoalEditResult {
  const _GoalEditResult({
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.url,
    required this.imageAction,
  });

  final String name;
  final double targetAmount;
  final double currentAmount;
  final String? url;
  final SavingGoalImageAction imageAction;
}

/// Editor de todos los campos de una meta, foto incluida.
///
/// Solo recolecta y valida el formato de los datos; guardar es tarea del
/// controller, por eso devuelve un [_GoalEditResult] en lugar de escribir.
class _EditGoalDialog extends StatefulWidget {
  const _EditGoalDialog({required this.goal});

  final SavingGoal goal;

  @override
  State<_EditGoalDialog> createState() => _EditGoalDialogState();
}

class _EditGoalDialogState extends State<_EditGoalDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _currentCtrl;
  late final TextEditingController _urlCtrl;
  final _formKey = GlobalKey<FormState>();

  SavingGoalImageUpload? _pickedImage;
  bool _imageRemoved = false;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _nameCtrl = TextEditingController(text: goal.name);
    _targetCtrl = TextEditingController(
      text: goal.targetAmount.toStringAsFixed(2),
    );
    _currentCtrl = TextEditingController(
      text: goal.currentAmount.toStringAsFixed(2),
    );
    _urlCtrl = TextEditingController(text: goal.url ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _currentCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final image = await pickSavingGoalImage();
      if (image == null || !mounted) return;
      setState(() {
        _pickedImage = image;
        _imageRemoved = false;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir la galeria: $error')),
      );
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final picked = _pickedImage;
    final SavingGoalImageAction action;
    if (picked != null) {
      action = SavingGoalImageAction.replace(picked);
    } else if (_imageRemoved) {
      action = const SavingGoalImageAction.remove();
    } else {
      action = const SavingGoalImageAction.keep();
    }

    Navigator.pop(
      context,
      _GoalEditResult(
        name: _nameCtrl.text,
        targetAmount: double.parse(_targetCtrl.text.trim()),
        currentAmount: double.parse(_currentCtrl.text.trim()),
        url: _urlCtrl.text,
        imageAction: action,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Editar meta',
        style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la meta',
                    prefixIcon: Icon(Icons.star_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _targetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Meta (\$)',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido';
                    final n = double.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Monto invalido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _currentCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Ya tengo (\$)',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido';
                    final n = double.tryParse(v.trim());
                    if (n == null || n < 0) return 'Monto invalido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL (opcional)',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 20),
                GoalImagePickerField(
                  currentImagePath: widget.goal.imagePath,
                  pickedImage: _pickedImage,
                  imageRemoved: _imageRemoved,
                  onPick: _pick,
                  onRemove: () => setState(() {
                    _pickedImage = null;
                    _imageRemoved = true;
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}
