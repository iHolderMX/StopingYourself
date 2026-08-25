import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/responsive_helper.dart';
import '../../../models/fixed_expense.dart';
import '../application/fixed_expenses_controller.dart';
import '../application/money_error_message.dart';
import '../data/money_providers.dart';

/// Gastos fijos mensuales: alta, total y listado.
class FixedExpensesContent extends ConsumerStatefulWidget {
  const FixedExpensesContent({super.key, this.compact = true});

  final bool compact;

  @override
  ConsumerState<FixedExpensesContent> createState() =>
      _FixedExpensesContentState();
}

class _FixedExpensesContentState extends ConsumerState<FixedExpensesContent> {
  String _selectedCategory = fixedExpenseCategories.first;
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _saving) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null) {
      _showMessage('Ingresa un monto valido');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(fixedExpensesControllerProvider).add(
        userId: userId,
        category: _selectedCategory,
        name: _nameController.text,
        amount: amount,
      );
      if (!mounted) return;
      setState(() {
        _selectedCategory = fixedExpenseCategories.first;
        _nameController.clear();
        _amountController.clear();
      });
      _showMessage('Gasto fijo guardado');
    } catch (error) {
      if (mounted) _showMessage(describeMoneyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(String userId, FixedExpense expense) async {
    try {
      await ref
          .read(fixedExpensesControllerProvider)
          .delete(userId: userId, expenseId: expense.id);
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
          'Gastos Fijos Mensuales',
          style: GoogleFonts.outfit(
            fontSize: r.titleFontSize,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Controla tus gastos recurrentes cada mes.',
          style: GoogleFonts.inter(
            fontSize: r.subtitleFontSize,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        SizedBox(height: r.cardSpacing + 4),
        if (userId != null) _totalCard(theme, r, userId),
        SizedBox(height: r.cardSpacing + 6),
        _form(theme, r),
        SizedBox(height: r.cardSpacing + 12),
        Text(
          'Mis gastos fijos',
          style: GoogleFonts.outfit(
            fontSize: r.subtitleFontSize + 2,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: r.cardSpacing - 4),
        _list(theme, r, userId),
        const SizedBox(height: 40),
      ],
    );

    if (widget.compact) {
      return SingleChildScrollView(padding: EdgeInsets.zero, child: content);
    }
    return content;
  }

  Widget _totalCard(ThemeData theme, ResponsiveHelper r, String userId) {
    final neon = theme.colorScheme.primary;
    final neon2 = theme.colorScheme.secondary;
    final total =
        ref.watch(totalFixedExpensesProvider(userId)).asData?.value ?? 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.cardSpacing + 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [neon, neon2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(r.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.receipt_long, color: Colors.white, size: r.iconSizeMedium),
          SizedBox(height: r.cardSpacing - 4),
          Text(
            '\$${total.toStringAsFixed(2)}',
            style: GoogleFonts.outfit(
              fontSize: r.isDesktop ? 28 : 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Total gasto fijo mensual',
            style: GoogleFonts.inter(
              fontSize: r.bodyFontSize - 1,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _form(ThemeData theme, ResponsiveHelper r) {
    final neon = theme.colorScheme.primary;

    return Container(
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
            'Nuevo gasto fijo',
            style: GoogleFonts.outfit(
              fontSize: r.subtitleFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: r.cardSpacing),
          _categorySelector(theme),
          SizedBox(height: r.cardSpacing - 4),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre del gasto',
              hintText: 'Ej: Renta, Netflix, Luz',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          SizedBox(height: r.cardSpacing - 4),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monto mensual (\$)',
              hintText: '0.00',
              prefixIcon: Icon(Icons.attach_money),
            ),
          ),
          SizedBox(height: r.cardSpacing + 2),
          SizedBox(
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
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Guardando...' : 'Guardar gasto'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categorySelector(ThemeData theme) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Categoria',
        prefixIcon: Icon(Icons.category_outlined),
      ),
      child: PopupMenuButton<String>(
        initialValue: _selectedCategory,
        onSelected: (v) => setState(() => _selectedCategory = v),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedCategory,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
          ],
        ),
        itemBuilder: (_) => fixedExpenseCategories
            .map(
              (c) => PopupMenuItem(
                value: c,
                child: Row(
                  children: [
                    if (c == _selectedCategory)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.check,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    else
                      const SizedBox(width: 26),
                    Text(
                      c,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: c == _selectedCategory
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _list(ThemeData theme, ResponsiveHelper r, String? userId) {
    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ref.watch(fixedExpensesProvider(userId)).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _errorBox(theme, r, describeMoneyError(error)),
      data: (expenses) {
        if (expenses.isEmpty) return _emptyBox(theme, r);
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: expenses.length,
          separatorBuilder: (_, _) => SizedBox(height: r.cardSpacing - 8),
          itemBuilder: (context, index) =>
              _expenseTile(theme, r, userId, expenses[index]),
        );
      },
    );
  }

  Widget _errorBox(ThemeData theme, ResponsiveHelper r, String message) {
    return Container(
      padding: EdgeInsets.all(r.cardSpacing),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(r.borderRadius),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(fontSize: r.bodyFontSize - 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(ThemeData theme, ResponsiveHelper r) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(r.borderRadius),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: r.iconSizeLarge,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'No hay gastos fijos registrados',
              style: GoogleFonts.inter(
                fontSize: r.bodyFontSize,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expenseTile(
    ThemeData theme,
    ResponsiveHelper r,
    String userId,
    FixedExpense exp,
  ) {
    final neon = theme.colorScheme.primary;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(r.borderRadius),
      child: Padding(
        padding: EdgeInsets.all(r.cardSpacing),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: r.isDesktop ? 50 : 44,
              height: r.isDesktop ? 50 : 44,
              decoration: BoxDecoration(
                color: neon.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.receipt_outlined, color: neon, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          exp.name,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: r.bodyFontSize,
                          ),
                        ),
                      ),
                      Text(
                        '\$${exp.amount.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: r.bodyFontSize,
                          color: neon,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      exp.category,
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 3,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: neon, size: 20),
              onPressed: () => _delete(userId, exp),
            ),
          ],
        ),
      ),
    );
  }
}
