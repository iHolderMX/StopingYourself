import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/money_providers.dart';

/// Reinicio total de las finanzas del usuario.
class FinanceResetController {
  const FinanceResetController(this._ref);

  final Ref _ref;

  /// Borra todo y refresca las lecturas del modulo.
  ///
  /// El refresco ocurre incluso si el borrado falla a medias: parte de los
  /// datos si pudo desaparecer y dejar la pantalla con informacion vieja
  /// seria peor que mostrar el error junto al estado real.
  Future<void> resetAll(String userId) async {
    try {
      await _ref.read(financeResetRepositoryProvider).resetAll(userId);
    } finally {
      _invalidateAll(userId);
    }
  }

  /// Un solo lugar que sabe que hay que refrescar tras un reinicio.
  ///
  /// Antes eran nueve `ref.invalidate` escritos a mano en la pantalla del hub,
  /// importando providers de cinco archivos distintos.
  void _invalidateAll(String userId) {
    _ref.invalidate(moneyRecordsProvider(userId));
    _ref.invalidate(fixedExpensesProvider(userId));
    _ref.invalidate(salarySettingProvider(userId));
    _ref.invalidate(debtsProvider(userId));
    _ref.invalidate(savingGoalsProvider(userId));
    _ref.invalidate(emergencyFundsProvider(userId));
    _ref.invalidate(quincenaExpensesProvider(userId));
  }
}

final financeResetControllerProvider = Provider<FinanceResetController>(
  FinanceResetController.new,
);
