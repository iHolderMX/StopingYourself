import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/fixed_expense.dart';

final fixedExpensesProvider = FutureProvider.family<List<FixedExpense>, String>(
  (ref, userId) => ref.watch(databaseServiceProvider).getFixedExpenses(userId),
);

final totalFixedExpensesProvider = FutureProvider.family<double, String>(
  (ref, userId) =>
      ref.watch(databaseServiceProvider).getTotalFixedExpenses(userId),
);

const fixedExpenseCategories = [
  'Vivienda',
  'Alimentacion',
  'Transporte',
  'Salud',
  'Entretenimiento',
  'Servicios',
  'Educacion',
  'Otros',
];

class FixedExpensesContent extends ConsumerStatefulWidget {
  final bool compact;
  const FixedExpensesContent({super.key, this.compact = true});

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

  Future<void> _save() async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;
    final amount = double.tryParse(_amountController.text.trim());
    final name = _nameController.text.trim();
    if (amount == null || amount <= 0 || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un nombre y monto valido')),
      );
      return;
    }

    setState(() => _saving = true);
    final expense = FixedExpense(
      id: '${user.id}_${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      category: _selectedCategory,
      name: name,
      amount: amount,
    );
    try {
      await ref.read(databaseServiceProvider).insertFixedExpense(expense);
      ref.invalidate(fixedExpensesProvider(user.id));
      ref.invalidate(totalFixedExpensesProvider(user.id));
      setState(() {
        _saving = false;
        _selectedCategory = fixedExpenseCategories.first;
        _nameController.clear();
        _amountController.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gasto fijo guardado')));
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final expensesAsync = user != null
        ? ref.watch(fixedExpensesProvider(user.id))
        : null;
    final totalAsync = user != null
        ? ref.watch(totalFixedExpensesProvider(user.id))
        : null;
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final neon = theme.colorScheme.primary;
    final neon2 = theme.colorScheme.secondary;

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
        SizedBox(height: 6),
        Text(
          'Controla tus gastos recurrentes cada mes.',
          style: GoogleFonts.inter(
            fontSize: r.subtitleFontSize,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        SizedBox(height: r.cardSpacing + 4),

        // --- Card de total mensual ---
        if (totalAsync != null)
          Builder(
            builder: (_) {
              final total = totalAsync.asData?.value ?? 0;
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
                    Icon(
                      Icons.receipt_long,
                      color: Colors.white,
                      size: r.iconSizeMedium,
                    ),
                    SizedBox(height: r.cardSpacing - 4),
                    Text(
                      '\$${total.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: r.isDesktop ? 28 : 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
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
            },
          ),

        SizedBox(height: r.cardSpacing + 6),

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
                'Nuevo gasto fijo',
                style: GoogleFonts.outfit(
                  fontSize: r.subtitleFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: r.cardSpacing),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: fixedExpenseCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedCategory = v);
                },
              ),
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
        ),

        SizedBox(height: r.cardSpacing + 12),

        // --- Lista de gastos ---
        Text(
          'Mis gastos fijos',
          style: GoogleFonts.outfit(
            fontSize: r.subtitleFontSize + 2,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: r.cardSpacing - 4),

        if (expensesAsync == null)
          const Center(child: CircularProgressIndicator())
        else
          expensesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (expenses) {
              if (expenses.isEmpty) {
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
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No hay gastos fijos registrados',
                          style: GoogleFonts.inter(
                            fontSize: r.bodyFontSize,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: expenses.length,
                separatorBuilder: (_, i) => SizedBox(height: r.cardSpacing - 8),
                itemBuilder: (context, index) {
                  final exp = expenses[index];
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
                            child: Icon(
                              Icons.receipt_outlined,
                              color: neon,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 14),
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
                                SizedBox(height: 2),
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    exp.category,
                                    style: GoogleFonts.inter(
                                      fontSize: r.bodyFontSize - 3,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: neon,
                              size: 20,
                            ),
                            onPressed: () async {
                              if (user == null) return;
                              await ref
                                  .read(databaseServiceProvider)
                                  .deleteFixedExpense(exp.id);
                              ref.invalidate(fixedExpensesProvider(user.id));
                              ref.invalidate(
                                totalFixedExpensesProvider(user.id),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        SizedBox(height: 40),
      ],
    );

    if (widget.compact) {
      return SingleChildScrollView(padding: EdgeInsets.zero, child: content);
    }
    return content;
  }
}
