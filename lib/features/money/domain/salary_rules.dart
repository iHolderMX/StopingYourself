import '../../../models/fixed_expense.dart';
import '../../../models/quincena_expense.dart';

/// Reglas derivadas del salario mensual.
///
/// Toda metrica que divida entre el salario vive aqui para que la UI no
/// tenga que acordarse de proteger la division por cero. Cuando no hay
/// salario configurado los porcentajes devuelven `null` en lugar de
/// `NaN` o `Infinity`, para que quien renderiza decida que mostrar.
class SalaryRules {
  const SalaryRules._();

  /// Dias que se usan para pasar de salario mensual a salario diario.
  static const int daysPerMonth = 30;

  /// Numero de quincenas por mes.
  ///
  /// TODO(Gus): confirmar la regla real. Hoy se asume que la quincena es
  /// medio salario mensual, que es lo que ya hacia la UI. Si tu quincena
  /// depende de dias trabajados o de fechas de pago, este es el unico
  /// lugar que hay que cambiar.
  static const int quincenasPerMonth = 2;

  /// Hay salario configurado y utilizable para calcular metricas.
  static bool hasSalary(double monthlySalary) => monthlySalary > 0;

  /// Dinero disponible para una quincena.
  static double quincenaAvailable(double monthlySalary) {
    if (!hasSalary(monthlySalary)) return 0;
    return monthlySalary / quincenasPerMonth;
  }

  /// Salario equivalente a un dia.
  static double dailySalary(double monthlySalary) {
    if (!hasSalary(monthlySalary)) return 0;
    return monthlySalary / daysPerMonth;
  }

  /// Que porcentaje del salario representa [amount].
  ///
  /// `null` cuando no hay salario configurado.
  static double? percentOfSalary({
    required double amount,
    required double monthlySalary,
  }) {
    if (!hasSalary(monthlySalary)) return null;
    return amount / monthlySalary * 100;
  }

  /// Cuantos dias de salario cubre [amount].
  static double? daysOfSalaryCovered({
    required double amount,
    required double monthlySalary,
  }) {
    if (!hasSalary(monthlySalary)) return null;
    return amount / monthlySalary * daysPerMonth;
  }

  /// Cuantos meses de salario cubre [amount].
  static double? monthsOfSalaryCovered({
    required double amount,
    required double monthlySalary,
  }) {
    if (!hasSalary(monthlySalary)) return null;
    return amount / monthlySalary;
  }

  /// Que porcentaje de un dia de salario representa la ganancia diaria.
  static double? dailyEarningsAsPercentOfDailySalary({
    required double dailyEarnings,
    required double monthlySalary,
  }) {
    final perDay = dailySalary(monthlySalary);
    if (perDay <= 0) return null;
    return dailyEarnings / perDay * 100;
  }

  /// Lo que queda del salario despues de los gastos fijos.
  ///
  /// Puede ser negativo a proposito: si gastas mas de lo que ganas,
  /// esconderlo seria mentirle al usuario.
  static double salaryAfterFixedExpenses({
    required double monthlySalary,
    required double totalFixedExpenses,
  }) => monthlySalary - totalFixedExpenses;

  /// Suma de gastos fijos mensuales.
  static double totalFixedExpenses(Iterable<FixedExpense> expenses) =>
      expenses.fold(0.0, (sum, expense) => sum + expense.amount);

  /// Suma de los gastos planeados de la quincena.
  static double totalQuincenaPlanned(Iterable<QuincenaExpense> expenses) =>
      expenses.fold(0.0, (sum, expense) => sum + expense.amount);

  /// Lo que sobra de la quincena despues de los gastos planeados.
  ///
  /// Puede ser negativo cuando el plan excede lo disponible.
  static double quincenaRemaining({
    required double monthlySalary,
    required Iterable<QuincenaExpense> plannedExpenses,
  }) =>
      quincenaAvailable(monthlySalary) - totalQuincenaPlanned(plannedExpenses);
}
