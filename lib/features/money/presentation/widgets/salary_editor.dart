import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/responsive_helper.dart';
import '../../application/money_error_message.dart';
import '../../application/salary_controller.dart';
import '../../data/money_providers.dart';

/// Formulario para capturar el salario mensual.
///
/// Antes este campo, su parseo y su guardado estaban copiados completos en
/// `salary_summary_card` y en `next_quincena_card`. Ahora las dos tarjetas
/// montan este widget, asi que el formulario se ve y se comporta igual en
/// ambas y solo hay un lugar donde arreglarlo.
class SalaryEditor extends ConsumerStatefulWidget {
  const SalaryEditor({
    super.key,
    required this.currentSalary,
    required this.onFinished,
    this.saveLabel = 'Guardar',
  });

  /// Salario ya configurado, para prellenar el campo. 0 si no hay.
  final double currentSalary;

  /// Se llama al guardar con exito o al cancelar, para que el padre cierre
  /// el modo edicion.
  final VoidCallback onFinished;

  final String saveLabel;

  @override
  ConsumerState<SalaryEditor> createState() => _SalaryEditorState();
}

class _SalaryEditorState extends ConsumerState<SalaryEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.currentSalary > 0
        ? widget.currentSalary.toStringAsFixed(0)
        : '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _saving) return;

    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null) {
      _showMessage('Ingresa un salario valido.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(salaryControllerProvider)
          .setMonthlySalary(userId: userId, monthlySalary: parsed);
      if (!mounted) return;
      _showMessage('Salario actualizado');
      widget.onFinished();
    } catch (error) {
      if (!mounted) return;
      _showMessage(describeMoneyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveHelper(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          enabled: !_saving,
          decoration: const InputDecoration(
            labelText: 'Salario mensual (\$)',
            hintText: '0.00',
            prefixIcon: Icon(Icons.attach_money),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _save(),
        ),
        SizedBox(height: r.cardSpacing - 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _saving ? null : widget.onFinished,
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Guardando...' : widget.saveLabel),
            ),
          ],
        ),
      ],
    );
  }
}
