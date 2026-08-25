import '../../../models/emergency_fund.dart';
import '../../../models/money_record.dart';

/// Reglas de rendimiento de ahorros e inversiones.
///
/// Un unico lugar donde vive la conversion entre rendimiento anual (%),
/// ganancia diaria y ganancia anual. Antes estaba repartida entre
/// `MoneyRecord.dailyEarnings`, `money_tracking_screen` y `finance_charts`.
class YieldRules {
  const YieldRules._();

  /// Dias que se usan para anualizar. Se asume anio comercial simple:
  /// no se ajusta por anios bisiestos porque el rendimiento mostrado
  /// es una estimacion, no un calculo contable.
  static const int daysPerYear = 365;

  /// Ganancia diaria estimada de un capital a una tasa anual dada.
  ///
  /// Devuelve 0 si no hay tasa o no hay capital, para que la UI nunca
  /// tenga que decidir que hacer con un rendimiento negativo o invalido.
  static double dailyEarnings({
    required double amount,
    required double annualYieldPercent,
  }) {
    if (annualYieldPercent <= 0 || amount <= 0) return 0;
    return amount * (annualYieldPercent / 100) / daysPerYear;
  }

  /// Proyeccion anual a partir de la ganancia diaria ya calculada.
  static double annualFromDaily(double dailyEarnings) =>
      dailyEarnings * daysPerYear;

  /// Suma de las ganancias diarias de una coleccion de registros.
  static double totalDailyEarningsOfRecords(Iterable<MoneyRecord> records) =>
      records.fold(0.0, (sum, record) => sum + record.dailyEarnings);

  /// Suma de los montos de una coleccion de registros.
  static double totalAmountOfRecords(Iterable<MoneyRecord> records) =>
      records.fold(0.0, (sum, record) => sum + record.amount);

  /// Suma de las ganancias diarias de los fondos de emergencia.
  static double totalDailyEarningsOfFunds(Iterable<EmergencyFund> funds) =>
      funds.fold(0.0, (sum, fund) => sum + fund.dailyEarnings);
}
