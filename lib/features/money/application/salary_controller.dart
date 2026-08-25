import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/salary_setting.dart';
import '../data/money_providers.dart';
import 'money_error_message.dart';

/// Casos de uso de la configuracion de salario.
///
/// Existe un solo controller para que las dos tarjetas que permiten editar el
/// salario (resumen y proxima quincena) compartan la misma logica. Antes cada
/// una tenia su propia copia de `_saveSalary`.
class SalaryController {
  const SalaryController(this._ref);

  final Ref _ref;

  Future<void> setMonthlySalary({
    required String userId,
    required double monthlySalary,
  }) async {
    if (monthlySalary <= 0) {
      throw const MoneyValidationException(
        'Ingresa un salario mayor a cero.',
      );
    }

    await _ref
        .read(salaryRepositoryProvider)
        .upsert(SalarySetting(userId: userId, monthlySalary: monthlySalary));
    _ref.invalidate(salarySettingProvider(userId));
  }
}

final salaryControllerProvider = Provider<SalaryController>(
  SalaryController.new,
);
