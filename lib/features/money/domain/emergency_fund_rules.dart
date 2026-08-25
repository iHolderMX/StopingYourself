import '../../../models/emergency_fund.dart';

/// Resultado de validar una division de un fondo de emergencia.
enum FundSplitValidation {
  valid,

  /// El monto no es un numero positivo.
  notPositive,

  /// El monto excede lo que queda sin clasificar en el fondo.
  exceedsAvailable,
}

/// Reglas del fondo de emergencia y sus subdivisiones.
class EmergencyFundRules {
  const EmergencyFundRules._();

  /// Suma de los montos ya clasificados en subdivisiones.
  static double classifiedAmount(Iterable<EmergencyFundEntry> entries) =>
      entries.fold(0.0, (sum, entry) => sum + entry.amount);

  /// Monto del fondo que todavia no se ha repartido en subdivisiones.
  ///
  /// Nunca devuelve negativo: si por datos inconsistentes lo clasificado
  /// excede el total del fondo, se reporta 0 disponible.
  static double availableToSplit({
    required EmergencyFund fund,
    required Iterable<EmergencyFundEntry> entries,
  }) {
    final available = fund.amount - classifiedAmount(entries);
    return available > 0 ? available : 0;
  }

  /// El fondo esta completamente repartido en subdivisiones.
  static bool isFullyClassified({
    required EmergencyFund fund,
    required Iterable<EmergencyFundEntry> entries,
  }) => availableToSplit(fund: fund, entries: entries) <= 0;

  /// Valida una nueva subdivision contra lo disponible del fondo.
  static FundSplitValidation validateSplit({
    required EmergencyFund fund,
    required Iterable<EmergencyFundEntry> entries,
    required double amount,
  }) {
    if (amount <= 0) return FundSplitValidation.notPositive;
    if (amount > availableToSplit(fund: fund, entries: entries)) {
      return FundSplitValidation.exceedsAvailable;
    }
    return FundSplitValidation.valid;
  }

  /// Suma de los montos de varios fondos.
  static double totalAmount(Iterable<EmergencyFund> funds) =>
      funds.fold(0.0, (sum, fund) => sum + fund.amount);
}
