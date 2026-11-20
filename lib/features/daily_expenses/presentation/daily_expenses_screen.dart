import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/responsive_helper.dart';
import '../../../models/daily_expense.dart';
import '../../money/application/money_error_message.dart';
import '../../money/data/money_providers.dart';
import '../../money/domain/salary_rules.dart';
import '../../money/presentation/money_colors.dart';
import '../../money/presentation/widgets/money_metric_tile.dart';
import '../application/daily_expenses_controller.dart';
import '../data/daily_expenses_providers.dart';
import '../domain/daily_expense_occurrence.dart';

/// Alcance de una edicion sobre un cargo recurrente.
enum _EditScope { allDays, thisDayOnly }

/// Gasto diario: registra lo que gastas cada dia por categoria.
///
/// Es informativo: por ahora NO descuenta nada de los calculos de finanzas,
/// solo compara el gasto del dia contra tu salario para ayudarte a reflexionar.
/// Un gasto puede marcarse como **cargo recurrente** y entonces se repite
/// todos los dias; su monto puede editarse para un dia puntual.
class DailyExpensesScreen extends ConsumerStatefulWidget {
  const DailyExpensesScreen({super.key});

  @override
  ConsumerState<DailyExpensesScreen> createState() =>
      _DailyExpensesScreenState();
}

class _DailyExpensesScreenState extends ConsumerState<DailyExpensesScreen> {
  late DateTime _selectedDay;
  String _selectedCategory = dailyExpenseCategories.first;
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  bool _recurring = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _dateOnly(DateTime.now());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Mueve el dia seleccionado [days] hacia adelante o atras.
  void _shiftDay(int days) {
    setState(() {
      _selectedDay = DateTime(
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day + days,
      );
    });
  }

  void _goToday() {
    setState(() => _selectedDay = _dateOnly(DateTime.now()));
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _saving) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null) {
      _showMessage('Ingresa un monto válido.');
      return;
    }

    final isRecurring = _recurring;
    setState(() => _saving = true);
    try {
      await ref
          .read(dailyExpensesControllerProvider)
          .add(
            userId: userId,
            category: _selectedCategory,
            name: _nameController.text,
            amount: amount,
            spentOn: _selectedDay,
            isRecurring: isRecurring,
          );
      if (!mounted) return;
      _nameController.clear();
      _amountController.clear();
      setState(() => _recurring = false);
      _showMessage(
        isRecurring ? 'Cargo recurrente guardado' : 'Gasto del día guardado',
      );
    } catch (error) {
      if (mounted) _showMessage(describeMoneyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Elimina el gasto mostrado: la fila suelta, o el cargo recurrente completo
  /// (en cuyo caso pide confirmacion porque afecta todos los dias).
  Future<void> _deleteOccurrence(
    String userId,
    DailyExpenseOccurrence occurrence,
  ) async {
    if (occurrence.isRecurring) {
      final confirmed = await _confirm(
        title: 'Eliminar cargo recurrente',
        message:
            'Se eliminará de todos los días. ¿Quieres continuar?',
      );
      if (confirmed != true) return;
    }

    try {
      await ref
          .read(dailyExpensesControllerProvider)
          .delete(userId: userId, expenseId: occurrence.entry.id);
      if (mounted) _showMessage('Gasto eliminado');
    } catch (error) {
      if (mounted) _showMessage(describeMoneyError(error));
    }
  }

  /// Quita el cambio hecho solo para este dia y deja el monto base.
  Future<void> _clearOverride(
    String userId,
    DailyExpenseOccurrence occurrence,
  ) async {
    final override = occurrence.override;
    if (override == null) return;
    try {
      await ref
          .read(dailyExpensesControllerProvider)
          .delete(userId: userId, expenseId: override.id);
      if (mounted) _showMessage('Se quitó el cambio de este día');
    } catch (error) {
      if (mounted) _showMessage(describeMoneyError(error));
    }
  }

  /// Copia al portapapeles la lista de gastos del dia que se esta viendo.
  Future<void> _copyDayList(List<DailyExpenseOccurrence> occurrences) async {
    final total = occurrences.fold<double>(0, (sum, o) => sum + o.amount);
    final buffer = StringBuffer()
      ..writeln('Gasto Diario — ${_dayLabel(_selectedDay)}')
      ..writeln('Total del día: \$${total.toStringAsFixed(2)}')
      ..writeln();
    for (final occurrence in occurrences) {
      final detail = occurrence.label == occurrence.category
          ? ''
          : ' · ${occurrence.label}';
      final tags = [
        if (occurrence.isRecurring) 'recurrente',
        if (occurrence.isOverridden) 'cambiado este día',
      ];
      final suffix = tags.isEmpty ? '' : ' (${tags.join(', ')})';
      buffer.writeln(
        '• ${occurrence.category}$detail — '
        '\$${occurrence.amount.toStringAsFixed(2)}$suffix',
      );
    }
    await Clipboard.setData(
      ClipboardData(text: buffer.toString().trimRight()),
    );
    if (mounted) _showMessage('Lista de gastos copiada al portapapeles');
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);
    final userId = ref.watch(currentUserIdProvider);
    final isToday = _sameDay(_selectedDay, DateTime.now());

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: r.padHorizontal,
        right: r.padHorizontal,
        top: r.padVertical + 8,
        bottom: r.padVertical + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(theme, r),
          SizedBox(height: r.cardSpacing + 4),
          _dayNavigator(theme, r, isToday),
          SizedBox(height: r.cardSpacing + 4),
          if (userId == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else
            _body(theme, r, userId),
        ],
      ),
    );
  }

  /// Junta la carga de gastos y categorias personalizadas.
  Widget _body(ThemeData theme, ResponsiveHelper r, String userId) {
    final expensesAsync = ref.watch(dailyExpensesProvider(userId));
    final categoriesAsync = ref.watch(dailyExpenseCategoriesProvider(userId));

    // Si falla la carga de categorias personalizadas, avisamos en lugar de
    // silenciarlo: asi el usuario entiende por que no aparecen las suyas.
    ref.listen(dailyExpenseCategoriesProvider(userId), (_, next) {
      next.whenOrNull(
        error: (error, _) => _showMessage(describeMoneyError(error)),
      );
    });

    return expensesAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => _errorBox(theme, r, describeMoneyError(error)),
      data: (all) {
        // Categorias por defecto + las del usuario, sin duplicados.
        final customCats = categoriesAsync.asData?.value ?? const <String>[];
        final categories = _mergeCategories(customCats);
        return _dayContent(theme, r, userId, all, categories);
      },
    );
  }

  /// Combina las categorias por defecto con las personalizadas del usuario.
  List<String> _mergeCategories(List<String> custom) {
    final seen = <String>{};
    final result = <String>[];
    for (final c in [...dailyExpenseCategories, ...custom]) {
      if (seen.add(c)) result.add(c);
    }
    return result;
  }

  Widget _header(ThemeData theme, ResponsiveHelper r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.payments_outlined,
              color: theme.colorScheme.primary,
              size: r.iconSizeMedium,
            ),
            const SizedBox(width: 10),
            Text(
              'Gasto Diario',
              style: GoogleFonts.outfit(
                fontSize: r.titleFontSize,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Registra lo que gastas cada día para tomar conciencia de tus hábitos.',
          style: GoogleFonts.inter(
            fontSize: r.subtitleFontSize,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _dayNavigator(ThemeData theme, ResponsiveHelper r, bool isToday) {
    final neon = theme.colorScheme.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.cardSpacing - 6,
        vertical: r.cardSpacing - 8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(r.borderRadius - 2),
        border: Border.all(color: neon.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _shiftDay(-1),
            icon: const Icon(Icons.chevron_left),
            color: neon,
            tooltip: 'Día anterior',
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _dayLabel(_selectedDay),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: r.subtitleFontSize,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (isToday)
                  Text(
                    'Hoy',
                    style: GoogleFonts.inter(
                      fontSize: r.bodyFontSize - 3,
                      fontWeight: FontWeight.w600,
                      color: MoneyColors.positive,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _shiftDay(1),
            icon: const Icon(Icons.chevron_right),
            color: neon,
            tooltip: 'Día siguiente',
          ),
          if (!isToday)
            TextButton(
              onPressed: _goToday,
              child: Text(
                'Hoy',
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize - 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayContent(
    ThemeData theme,
    ResponsiveHelper r,
    String userId,
    List<DailyExpense> all,
    List<String> categories,
  ) {
    final occurrences = occurrencesForDay(all, _selectedDay);
    final dayTotal = occurrences.fold<double>(
      0,
      (sum, occurrence) => sum + occurrence.amount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryCard(theme, r, userId, dayTotal),
        SizedBox(height: r.cardSpacing + 8),
        // El formulario va antes de la grafica para que registrar un gasto
        // quede a la vista sin tanto scroll, sobre todo en el telefono.
        _form(theme, r, userId, categories),
        SizedBox(height: r.cardSpacing + 8),
        _categoryChart(theme, r, userId, occurrences),
        SizedBox(height: r.cardSpacing + 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Gastos del día (${occurrences.length})',
                style: GoogleFonts.outfit(
                  fontSize: r.subtitleFontSize + 2,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (occurrences.isNotEmpty)
              TextButton.icon(
                onPressed: () => _copyDayList(occurrences),
                icon: const Icon(Icons.content_copy, size: 18),
                label: const Text('Copiar lista'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        ),
        SizedBox(height: r.cardSpacing - 4),
        _list(theme, r, userId, occurrences, categories),
      ],
    );
  }

  Widget _summaryCard(
    ThemeData theme,
    ResponsiveHelper r,
    String userId,
    double dayTotal,
  ) {
    final neon = theme.colorScheme.primary;
    final neon2 = theme.colorScheme.secondary;
    final salary = ref.watch(monthlySalaryProvider(userId)).asData?.value ?? 0.0;

    // El salario diario usa los dias reales del mes del dia que se esta viendo.
    final dailySalary = SalaryRules.dailySalary(salary, on: _selectedDay);
    final quincenaAvailable = SalaryRules.quincenaAvailable(salary);

    final pctOfDailySalary = dailySalary > 0
        ? dayTotal / dailySalary * 100
        : null;
    final pctOfQuincena = quincenaAvailable > 0
        ? dayTotal / quincenaAvailable * 100
        : null;

    // Verde por debajo del salario de un dia, ambar hasta el doble, rojo si lo
    // supera con creces. Es solo una guia visual para reflexionar.
    final comparisonColor = pctOfDailySalary == null
        ? MoneyColors.positive
        : pctOfDailySalary <= 100
        ? MoneyColors.positive
        : pctOfDailySalary <= 200
        ? MoneyColors.warning
        : MoneyColors.negative;

    // En movil las dos metricas comparten el ancho de la fila; en pantallas
    // grandes mantienen su tamano y fluyen con Wrap.
    final tileWidth = r.isMobile ? null : 180.0;
    final dailyTile = MoneyMetricTile(
      icon: Icons.trending_up,
      label: 'De un día de salario',
      value: pctOfDailySalary == null
          ? 'Sin salario'
          : '${pctOfDailySalary.toStringAsFixed(0)}%',
      color: comparisonColor,
      responsive: r,
      width: tileWidth,
    );
    final quincenaTile = MoneyMetricTile(
      icon: Icons.account_balance_wallet_outlined,
      label: 'De tu quincena',
      value: pctOfQuincena == null
          ? 'Sin salario'
          : '${pctOfQuincena.toStringAsFixed(0)}%',
      color: neon,
      responsive: r,
      width: tileWidth,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
                Icons.calendar_today_outlined,
                color: Colors.white,
                size: r.iconSizeMedium,
              ),
              SizedBox(height: r.cardSpacing - 4),
              Text(
                '\$${dayTotal.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(
                  fontSize: r.isDesktop ? 28 : 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Gastado este día',
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize - 1,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: r.cardSpacing),
        if (r.isMobile)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: dailyTile),
                SizedBox(width: r.cardSpacing - 4),
                Expanded(child: quincenaTile),
              ],
            ),
          )
        else
          Wrap(
            spacing: r.cardSpacing - 4,
            runSpacing: r.cardSpacing - 4,
            children: [dailyTile, quincenaTile],
          ),
        SizedBox(height: r.cardSpacing - 4),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.cardSpacing - 4,
            vertical: r.cardSpacing - 6,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(r.borderRadius - 2),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Informativo: por ahora este gasto no se descuenta de tus '
                  'finanzas, solo te sirve para comparar y reflexionar.',
                  style: GoogleFonts.inter(
                    fontSize: r.bodyFontSize - 3,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Grafica de dona con el gasto del dia por categoria y lo que queda
  /// disponible del salario diario.
  ///
  /// La dona representa tu dia completo: las rebanadas de color son el gasto
  /// por categoria y la rebanada verde es el dinero que aun te queda del
  /// salario de ese dia. Si no hay salario configurado solo se muestran las
  /// categorias.
  Widget _categoryChart(
    ThemeData theme,
    ResponsiveHelper r,
    String userId,
    List<DailyExpenseOccurrence> occurrences,
  ) {
    final neon = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    // Agrupa por categoria (usa la categoria efectiva del override si existe).
    final totals = <String, double>{};
    for (final occurrence in occurrences) {
      totals[occurrence.category] =
          (totals[occurrence.category] ?? 0) + occurrence.amount;
    }

    // Solo categorias con monto > 0: una categoria con $0 no aporta nada a la
    // grafica y confunde al aparecer con 0%.
    final entries = totals.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final spent = entries.fold<double>(0, (s, e) => s + e.value);

    // Salario de un dia del mes que se esta viendo, para saber cuanto queda.
    final salary = ref.watch(monthlySalaryProvider(userId)).asData?.value ?? 0.0;
    final dailySalary = SalaryRules.dailySalary(salary, on: _selectedDay);
    final hasSalary = dailySalary > 0;
    final available = hasSalary ? dailySalary - spent : 0.0;

    // La dona abarca todo el dia: si hay salario, se dibuja sobre el salario
    // diario; si ya se gasto mas que eso, se dibuja sobre lo gastado para que
    // las rebanadas no se desborden. La rebanada "Disponible" solo aparece
    // cuando sobra algo.
    final base = hasSalary && dailySalary > spent ? dailySalary : spent;
    final showAvailable = hasSalary && available > 0;
    final availableColor = MoneyColors.positive;

    // Paleta diversa: los colores del tema son todos cian, asi que usamos una
    // gama mas amplia para que cada categoria se distinga bien.
    final palette = [
      const Color(0xFF00D4FF), // cian
      const Color(0xFFFF6B6B), // rojo coral
      const Color(0xFFFFD93D), // amarillo
      const Color(0xFFB983FF), // violeta
      const Color(0xFFFF9F43), // naranja
      const Color(0xFF4ECDC4), // turquesa
      const Color(0xFFFF6B9D), // rosa
      const Color(0xFF845EC2), // morado
      const Color(0xFFF9F871), // amarillo claro
      const Color(0xFF5C6BC0), // indigo
    ];

    /// Texto del porcentaje dentro de la rebanada, o vacio si es muy pequeno.
    String sliceTitle(double value) {
      if (base <= 0) return '';
      // Con muchas rebanadas el texto se encima, asi que solo se anota cuando
      // hay pocas y el trozo es lo bastante ancho.
      final sectionCount = entries.length + (showAvailable ? 1 : 0);
      final pct = value / base * 100;
      return sectionCount <= 6 && pct >= 8
          ? '${pct.toStringAsFixed(0)}%'
          : '';
    }

    // Tamano de la dona segun pantalla.
    final donutHeight = r.isMobile ? 190.0 : (r.isDesktop ? 240.0 : 210.0);
    final sectionRadius = r.isMobile ? 70.0 : (r.isDesktop ? 80.0 : 74.0);
    final centerRadius = r.isMobile ? 36.0 : (r.isDesktop ? 44.0 : 40.0);

    // Dona con el total del dia al centro.
    final donut = Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sections: [
              for (var i = 0; i < entries.length; i++)
                PieChartSectionData(
                  color: palette[i % palette.length],
                  value: entries[i].value,
                  title: sliceTitle(entries[i].value),
                  radius: sectionRadius,
                  titleStyle: GoogleFonts.inter(
                    fontSize: r.bodyFontSize - 2,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              if (showAvailable)
                PieChartSectionData(
                  color: availableColor,
                  value: available,
                  title: sliceTitle(available),
                  radius: sectionRadius,
                  titleStyle: GoogleFonts.inter(
                    fontSize: r.bodyFontSize - 2,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
            ],
            centerSpaceRadius: centerRadius,
            sectionsSpace: 2,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${spent.toStringAsFixed(0)}',
              style: GoogleFonts.outfit(
                fontSize: r.isDesktop ? 20 : 17,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            Text(
              hasSalary ? 'de \$${dailySalary.toStringAsFixed(0)}' : 'total',
              style: GoogleFonts.inter(
                fontSize: r.bodyFontSize - 4,
                color: onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );

    // Leyenda: categoria + % (o el monto, en el caso de "Disponible").
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: palette[i % palette.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entries[i].key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: r.bodyFontSize - 2,
                      fontWeight: FontWeight.w500,
                      color: onSurface,
                    ),
                  ),
                ),
                Text(
                  '${(entries[i].value / base * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.outfit(
                    fontSize: r.bodyFontSize - 2,
                    fontWeight: FontWeight.bold,
                    color: palette[i % palette.length],
                  ),
                ),
              ],
            ),
          ),
        if (showAvailable)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: availableColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Disponible',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: r.bodyFontSize - 2,
                      fontWeight: FontWeight.w700,
                      color: onSurface,
                    ),
                  ),
                ),
                Text(
                  '\$${available.toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    fontSize: r.bodyFontSize - 2,
                    fontWeight: FontWeight.bold,
                    color: availableColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.cardSpacing),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline, color: neon, size: 20),
              const SizedBox(width: 8),
              Text(
                'Gasto por categoría',
                style: GoogleFonts.outfit(
                  fontSize: r.subtitleFontSize,
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: r.cardSpacing - 4),
          if (entries.isEmpty)
            SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pie_chart_outline,
                      size: 44,
                      color: onSurface.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sin gastos para este día',
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 1,
                        color: onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (r.isMobile)
            // En movil la dona va arriba centrada y la leyenda debajo a todo lo
            // ancho: lado a lado queda demasiado apretado en telefonos.
            Column(
              children: [
                SizedBox(height: donutHeight, child: donut),
                const SizedBox(height: 4),
                legend,
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(height: donutHeight, child: donut),
                ),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: legend),
              ],
            ),
        ],
      ),
    );
  }

  Widget _form(
    ThemeData theme,
    ResponsiveHelper r,
    String userId,
    List<String> categories,
  ) {
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
            'Agregar gasto del día',
            style: GoogleFonts.outfit(
              fontSize: r.subtitleFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: r.cardSpacing),
          _categorySelector(theme, userId, categories),
          SizedBox(height: r.cardSpacing - 4),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Detalle (opcional)',
              hintText: 'Ej: Desayuno, comida corrida, café',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          SizedBox(height: r.cardSpacing - 4),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Costo (\$)',
              hintText: '0.00',
              prefixIcon: Icon(Icons.attach_money),
            ),
            onSubmitted: (_) => _save(),
          ),
          SizedBox(height: r.cardSpacing - 6),
          Container(
            decoration: BoxDecoration(
              color: _recurring
                  ? neon.withValues(alpha: 0.08)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(r.borderRadius - 4),
            ),
            child: SwitchListTile(
              value: _recurring,
              onChanged: (value) => setState(() => _recurring = value),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              secondary: Icon(
                Icons.autorenew,
                color: _recurring
                    ? neon
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              title: Text(
                'Cargo recurrente',
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Se repite todos los días',
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize - 3,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          SizedBox(height: r.cardSpacing),
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
                  : const Icon(Icons.add),
              label: Text(_saving ? 'Guardando...' : 'Agregar gasto'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categorySelector(
    ThemeData theme,
    String userId,
    List<String> categories,
  ) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Categoria',
        prefixIcon: const Icon(Icons.category_outlined),
        suffixIcon: IconButton(
          icon: const Icon(Icons.add_circle_outline),
          color: theme.colorScheme.primary,
          tooltip: 'Agregar categoría',
          onPressed: () => _showAddCategoryDialog(userId, categories),
        ),
      ),
      child: PopupMenuButton<String>(
        initialValue: categories.contains(_selectedCategory)
            ? _selectedCategory
            : null,
        onSelected: (v) {
          if (v == '__add__') {
            _showAddCategoryDialog(userId, categories);
          } else {
            setState(() => _selectedCategory = v);
          }
        },
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
        itemBuilder: (_) => [
          ...categories.map(
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
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: '__add__',
            child: Row(
              children: [
                Icon(Icons.add, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Agregar categoría...',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: theme.colorScheme.primary,
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

  /// Dialogo para agregar una categoria personalizada.
  Future<void> _showAddCategoryDialog(
    String userId,
    List<String> existing,
  ) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var saving = false;

    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (!formKey.currentState!.validate()) return;
              final name = controller.text.trim();
              setDialogState(() => saving = true);
              try {
                await ref
                    .read(dailyExpensesControllerProvider)
                    .addCategory(userId: userId, name: name);
                if (context.mounted) Navigator.of(context).pop(name);
              } catch (error) {
                if (context.mounted) {
                  _showMessage(describeMoneyError(error));
                }
              } finally {
                if (context.mounted) {
                  setDialogState(() => saving = false);
                }
              }
            }

            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              title: Text(
                'Nueva categoría',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    labelStyle:
                        TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  validator: (value) {
                    final name = (value ?? '').trim();
                    if (name.isEmpty) {
                      return 'Escribe un nombre.';
                    }
                    if (existing.any(
                      (c) => c.toLowerCase() == name.toLowerCase(),
                    )) {
                      return 'Ya existe una categoría con ese nombre.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => save(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? 'Guardando...' : 'Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();

    // Si se creo la categoria, se selecciona automaticamente.
    if (result != null) {
      setState(() => _selectedCategory = result);
    }
  }


  Widget _list(
    ThemeData theme,
    ResponsiveHelper r,
    String userId,
    List<DailyExpenseOccurrence> occurrences,
    List<String> categories,
  ) {
    if (occurrences.isEmpty) {
      return _emptyBox(theme, r);
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: occurrences.length,
      separatorBuilder: (_, _) => SizedBox(height: r.cardSpacing - 8),
      itemBuilder: (context, index) =>
          _expenseTile(theme, r, userId, occurrences[index], categories),
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
              Icons.payments_outlined,
              size: r.iconSizeLarge,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'No hay gastos registrados para este día',
              textAlign: TextAlign.center,
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
    DailyExpenseOccurrence occurrence,
    List<String> categories,
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
              child: Icon(
                occurrence.isRecurring
                    ? Icons.autorenew
                    : Icons.payments_outlined,
                color: neon,
                size: 24,
              ),
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
                          occurrence.label,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: r.bodyFontSize,
                          ),
                        ),
                      ),
                      Text(
                        '\$${occurrence.amount.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: r.bodyFontSize,
                          color: neon,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _chip(
                        theme,
                        r,
                        icon: Icons.category_outlined,
                        label: occurrence.category,
                      ),
                      if (occurrence.isRecurring)
                        _chip(
                          theme,
                          r,
                          icon: Icons.autorenew,
                          label: 'Recurrente',
                          color: neon,
                        ),
                      if (occurrence.isOverridden)
                        _chip(
                          theme,
                          r,
                          icon: Icons.edit_calendar_outlined,
                          label: 'Cambiado este día',
                          color: MoneyColors.warning,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            _tileActions(theme, r, userId, occurrence, categories),
          ],
        ),
      ),
    );
  }

  /// Acciones de un gasto: en movil un menu de tres puntos para no estirar la
  /// tarjeta en alto; en pantallas grandes los botones a la vista.
  Widget _tileActions(
    ThemeData theme,
    ResponsiveHelper r,
    String userId,
    DailyExpenseOccurrence occurrence,
    List<String> categories,
  ) {
    final neon = theme.colorScheme.primary;

    if (r.isMobile) {
      return PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: neon),
        tooltip: 'Acciones',
        onSelected: (value) {
          if (value == 'edit') {
            _openEditSheet(userId, occurrence, categories);
          } else if (value == 'reset') {
            _clearOverride(userId, occurrence);
          } else if (value == 'delete') {
            _deleteOccurrence(userId, occurrence);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'edit',
            child: _menuRow(Icons.edit_outlined, 'Editar'),
          ),
          if (occurrence.isOverridden)
            PopupMenuItem(
              value: 'reset',
              child: _menuRow(Icons.restart_alt, 'Quitar cambio de este día'),
            ),
          if (!occurrence.isOverridden)
            PopupMenuItem(
              value: 'delete',
              child: _menuRow(Icons.delete_outline, 'Eliminar'),
            ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.edit_outlined, color: neon, size: 20),
          onPressed: () => _openEditSheet(userId, occurrence, categories),
          tooltip: 'Editar',
          visualDensity: VisualDensity.compact,
        ),
        if (occurrence.isOverridden)
          IconButton(
            icon: const Icon(Icons.restart_alt, size: 20),
            color: MoneyColors.warning,
            onPressed: () => _clearOverride(userId, occurrence),
            tooltip: 'Quitar cambio de este día',
            visualDensity: VisualDensity.compact,
          )
        else
          IconButton(
            icon: Icon(Icons.delete_outline, color: neon, size: 20),
            onPressed: () => _deleteOccurrence(userId, occurrence),
            tooltip: 'Eliminar',
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _menuRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }

  Widget _chip(
    ThemeData theme,
    ResponsiveHelper r, {
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final base = color ?? theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: r.bodyFontSize - 4, color: base),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: r.bodyFontSize - 3,
              fontWeight: FontWeight.w500,
              color: base,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditSheet(
    String userId,
    DailyExpenseOccurrence occurrence,
    List<String> categories,
  ) async {
    final isRecurring = occurrence.isRecurring;
    var category = occurrence.category;
    var scope = occurrence.isOverridden
        ? _EditScope.thisDayOnly
        : _EditScope.allDays;
    var saving = false;
    final nameController = TextEditingController(
      text: occurrence.override?.name ?? occurrence.entry.name,
    );
    final amountController = TextEditingController(
      text: occurrence.amount.toStringAsFixed(2),
    );

    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> save() async {
              final amount = double.tryParse(amountController.text.trim());
              if (amount == null) {
                _showMessage('Ingresa un monto válido.');
                return;
              }
              setSheetState(() => saving = true);
              try {
                final controller = ref.read(dailyExpensesControllerProvider);
                if (isRecurring && scope == _EditScope.thisDayOnly) {
                  await controller.setDayOverride(
                    userId: userId,
                    template: occurrence.entry,
                    day: _selectedDay,
                    category: category,
                    name: nameController.text,
                    amount: amount,
                    existingOverrideId: occurrence.override?.id,
                  );
                } else {
                  await controller.update(
                    userId: userId,
                    expense: occurrence.entry,
                    category: category,
                    name: nameController.text,
                    amount: amount,
                  );
                  // Si este dia tenia un cambio propio, se quita para que
                  // muestre el nuevo monto base.
                  final overrideId = occurrence.override?.id;
                  if (overrideId != null) {
                    await controller.delete(
                      userId: userId,
                      expenseId: overrideId,
                    );
                  }
                }
                if (!mounted) return;
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                _showMessage('Cambio guardado');
              } catch (error) {
                if (mounted) _showMessage(describeMoneyError(error));
              } finally {
                if (mounted) setSheetState(() => saving = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isRecurring ? 'Editar cargo recurrente' : 'Editar gasto',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Categoria',
                      labelStyle: TextStyle(color: onSurface),
                      prefixIcon: Icon(
                        Icons.category_outlined,
                        color: onSurface,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: categories.contains(category) ? category : null,
                        dropdownColor: surface,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: onSurface,
                        ),
                        iconEnabledColor: onSurface,
                        onChanged: (v) =>
                            setSheetState(() => category = v ?? category),
                        items: categories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    color: onSurface,
                                    fontWeight: c == category
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: onSurface),
                    decoration: InputDecoration(
                      labelText: 'Detalle (opcional)',
                      labelStyle: TextStyle(color: onSurface),
                      prefixIcon: Icon(
                        Icons.label_outline,
                        color: onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(color: onSurface),
                    decoration: InputDecoration(
                      labelText: 'Costo (\$)',
                      labelStyle: TextStyle(color: onSurface),
                      prefixIcon: Icon(
                        Icons.attach_money,
                        color: onSurface,
                      ),
                    ),
                  ),
                  if (isRecurring) ...[
                    const SizedBox(height: 16),
                    Text(
                      '¿Dónde aplicar el cambio?',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(
                            'Solo este día',
                            style: TextStyle(
                              color: scope == _EditScope.thisDayOnly
                                  ? Colors.black
                                  : onSurface,
                              fontWeight: scope == _EditScope.thisDayOnly
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: scope == _EditScope.thisDayOnly,
                          selectedColor: theme.colorScheme.primary,
                          checkmarkColor: Colors.black,
                          onSelected: (_) => setSheetState(
                            () => scope = _EditScope.thisDayOnly,
                          ),
                        ),
                        ChoiceChip(
                          label: Text(
                            'Todos los días',
                            style: TextStyle(
                              color: scope == _EditScope.allDays
                                  ? Colors.black
                                  : onSurface,
                              fontWeight: scope == _EditScope.allDays
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: scope == _EditScope.allDays,
                          selectedColor: theme.colorScheme.primary,
                          checkmarkColor: Colors.black,
                          onSelected: (_) =>
                              setSheetState(() => scope = _EditScope.allDays),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      scope == _EditScope.allDays
                          ? 'Se actualizará el monto base en todos los días.'
                          : 'Solo cambiará el monto de este día.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: saving ? null : save,
                      child: Text(saving ? 'Guardando...' : 'Guardar'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    amountController.dispose();
  }
}

const _monthNames = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

const _weekdayNames = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

/// Etiqueta legible del dia, sin depender de datos de locale.
String _dayLabel(DateTime date) {
  final weekday = _weekdayNames[date.weekday - 1];
  final month = _monthNames[date.month - 1];
  return '$weekday ${date.day} de $month';
}
