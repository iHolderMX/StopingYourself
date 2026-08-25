import '../../../models/debt.dart';

/// Resultado de validar un pago contra una deuda.
enum DebtPaymentValidation {
  valid,

  /// El monto no es un numero positivo.
  notPositive,

  /// El monto excede lo que falta por pagar.
  exceedsRemaining,

  /// La deuda ya esta liquidada, no admite mas pagos.
  alreadySettled,
}

/// Reglas de deudas y sus pagos.
class DebtRules {
  const DebtRules._();

  /// Fraccion del total que se sugiere como pago minimo mensual.
  ///
  /// TODO(Gus): confirmar de donde sale el 6%. Se conserva el valor que
  /// ya usaba la UI. Si viene del contrato de una tarjeta concreta,
  /// deberia ser un campo de la deuda y no una constante global.
  static const double minimumPaymentRate = 0.06;

  /// Pago minimo sugerido para una deuda.
  ///
  /// Se acota a lo que falta por pagar: no tiene sentido sugerir un
  /// minimo mayor al saldo. Si la deuda ya esta liquidada devuelve 0
  /// en lugar de reventar, que es lo que pasaba al hacer `clamp` con
  /// un limite superior negativo.
  static double minimumPayment(Debt debt) {
    final remaining = debt.remainingAmount;
    if (remaining <= 0) return 0;
    final suggested = debt.totalAmount * minimumPaymentRate;
    return suggested > remaining ? remaining : suggested;
  }

  /// Valida un pago antes de registrarlo.
  static DebtPaymentValidation validatePayment({
    required Debt debt,
    required double amount,
  }) {
    if (debt.remainingAmount <= 0) return DebtPaymentValidation.alreadySettled;
    if (amount <= 0) return DebtPaymentValidation.notPositive;
    if (amount > debt.remainingAmount) {
      return DebtPaymentValidation.exceedsRemaining;
    }
    return DebtPaymentValidation.valid;
  }

  /// La deuda con el pago ya aplicado al saldo.
  ///
  /// Centraliza la reconstruccion del modelo que antes se hacia a mano
  /// campo por campo dentro de un `AlertDialog`.
  static Debt applyPayment({required Debt debt, required double amount}) {
    return Debt(
      id: debt.id,
      userId: debt.userId,
      name: debt.name,
      totalAmount: debt.totalAmount,
      paidAmount: debt.paidAmount + amount,
      interestRate: debt.interestRate,
      createdAt: debt.createdAt,
    );
  }

  /// Progreso de pago acotado a [0, 1] para barras y graficas.
  static double progressRatio(Debt debt) => debt.progress.clamp(0.0, 1.0);

  /// La deuda esta liquidada.
  static bool isSettled(Debt debt) => debt.remainingAmount <= 0;

  /// Suma de los saldos pendientes de varias deudas.
  static double totalRemaining(Iterable<Debt> debts) =>
      debts.fold(0.0, (sum, debt) => sum + debt.remainingAmount);

  /// Suma de los montos totales de varias deudas.
  static double totalAmount(Iterable<Debt> debts) =>
      debts.fold(0.0, (sum, debt) => sum + debt.totalAmount);

  /// Suma de lo ya pagado en varias deudas.
  static double totalPaid(Iterable<Debt> debts) =>
      debts.fold(0.0, (sum, debt) => sum + debt.paidAmount);

  /// Suma de una lista de pagos.
  static double totalOfPayments(Iterable<DebtPayment> payments) =>
      payments.fold(0.0, (sum, payment) => sum + payment.amount);
}
