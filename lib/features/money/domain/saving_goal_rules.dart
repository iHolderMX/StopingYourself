import '../../../models/saving_goal.dart';

/// Reglas de metas de ahorro.
class SavingGoalRules {
  const SavingGoalRules._();

  /// La meta se considera cumplida cuando el monto actual alcanza o
  /// supera el objetivo.
  static bool isCompleted({
    required double currentAmount,
    required double targetAmount,
  }) => currentAmount >= targetAmount;

  /// Progreso acotado a [0, 1] para barras y graficas.
  ///
  /// El getter `SavingGoal.progress` puede pasar de 1 cuando se ahorra
  /// mas de lo planeado; aqui se recorta para pintar.
  static double progressRatio(SavingGoal goal) => goal.progress.clamp(0.0, 1.0);

  /// Meta con el nuevo monto y su bandera de cumplimiento recalculada.
  ///
  /// Existe porque `SavingGoal` no tiene `copyWith` y la UI reconstruia
  /// el modelo campo por campo en dos lugares distintos, con el riesgo
  /// de olvidar recalcular `isCompleted`.
  static SavingGoal withAmount(SavingGoal goal, double currentAmount) {
    return SavingGoal(
      id: goal.id,
      userId: goal.userId,
      name: goal.name,
      targetAmount: goal.targetAmount,
      currentAmount: currentAmount,
      url: goal.url,
      imagePath: goal.imagePath,
      createdAt: goal.createdAt,
      isCompleted: isCompleted(
        currentAmount: currentAmount,
        targetAmount: goal.targetAmount,
      ),
    );
  }

  /// Meta con la imagen cambiada. Pasar `null` en [imagePath] la quita.
  static SavingGoal withImagePath(SavingGoal goal, String? imagePath) {
    return SavingGoal(
      id: goal.id,
      userId: goal.userId,
      name: goal.name,
      targetAmount: goal.targetAmount,
      currentAmount: goal.currentAmount,
      url: goal.url,
      imagePath: imagePath,
      createdAt: goal.createdAt,
      isCompleted: goal.isCompleted,
    );
  }

  /// Meta con todos sus campos editables reemplazados.
  ///
  /// Todos los parametros son obligatorios a proposito: al ser una edicion
  /// completa, un campo que se olvide seria un dato borrado en silencio.
  /// `isCompleted` no se recibe, se recalcula.
  static SavingGoal edited({
    required SavingGoal goal,
    required String name,
    required double targetAmount,
    required double currentAmount,
    required String? url,
    required String? imagePath,
  }) {
    return SavingGoal(
      id: goal.id,
      userId: goal.userId,
      name: name,
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      url: url,
      imagePath: imagePath,
      createdAt: goal.createdAt,
      isCompleted: isCompleted(
        currentAmount: currentAmount,
        targetAmount: targetAmount,
      ),
    );
  }

  /// Suma de los objetivos de varias metas.
  static double totalTarget(Iterable<SavingGoal> goals) =>
      goals.fold(0.0, (sum, goal) => sum + goal.targetAmount);

  /// Suma de lo ya ahorrado en varias metas.
  static double totalSaved(Iterable<SavingGoal> goals) =>
      goals.fold(0.0, (sum, goal) => sum + goal.currentAmount);

  /// Rutas de imagen de las metas que tienen foto.
  ///
  /// Sirve para limpiar Storage cuando se borran metas en bloque.
  static List<String> imagePathsOf(Iterable<SavingGoal> goals) => goals
      .where((goal) => goal.hasImage)
      .map((goal) => goal.imagePath!)
      .toList();
}
