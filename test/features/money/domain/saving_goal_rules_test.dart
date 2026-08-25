import 'package:flutter_test/flutter_test.dart';
import 'package:stoping_yourself/features/money/domain/saving_goal_rules.dart';
import 'package:stoping_yourself/models/saving_goal.dart';

SavingGoal _goal({
  required double target,
  double current = 0,
  String? url,
  bool isCompleted = false,
}) {
  return SavingGoal(
    id: 'g',
    userId: 'u',
    name: 'Laptop',
    targetAmount: target,
    currentAmount: current,
    url: url,
    isCompleted: isCompleted,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('SavingGoalRules.isCompleted', () {
    test('no esta cumplida mientras falte', () {
      expect(
        SavingGoalRules.isCompleted(currentAmount: 999, targetAmount: 1000),
        isFalse,
      );
    });

    test('el monto exacto ya cuenta como cumplida', () {
      expect(
        SavingGoalRules.isCompleted(currentAmount: 1000, targetAmount: 1000),
        isTrue,
      );
    });

    test('pasarse del objetivo tambien cuenta como cumplida', () {
      expect(
        SavingGoalRules.isCompleted(currentAmount: 1200, targetAmount: 1000),
        isTrue,
      );
    });
  });

  group('SavingGoalRules.progressRatio', () {
    test('refleja el avance normal', () {
      expect(
        SavingGoalRules.progressRatio(_goal(target: 1000, current: 300)),
        closeTo(0.3, 0.0001),
      );
    });

    test('se recorta a 1 cuando se ahorro de mas', () {
      expect(
        SavingGoalRules.progressRatio(_goal(target: 1000, current: 5000)),
        1.0,
      );
    });

    test('es 0 con objetivo en 0 y no NaN', () {
      expect(SavingGoalRules.progressRatio(_goal(target: 0)), 0.0);
    });
  });

  group('SavingGoalRules.withAmount', () {
    test('actualiza el monto y conserva el resto de campos', () {
      final goal = _goal(target: 1000, current: 100, url: 'https://ejemplo.mx');
      final updated = SavingGoalRules.withAmount(goal, 400);

      expect(updated.currentAmount, closeTo(400, 0.0001));
      expect(updated.id, goal.id);
      expect(updated.userId, goal.userId);
      expect(updated.name, goal.name);
      expect(updated.targetAmount, goal.targetAmount);
      expect(updated.url, goal.url);
      expect(updated.createdAt, goal.createdAt);
    });

    test('marca como cumplida al alcanzar el objetivo', () {
      final updated = SavingGoalRules.withAmount(_goal(target: 1000), 1000);
      expect(updated.isCompleted, isTrue);
    });

    test('desmarca la bandera si el monto baja del objetivo', () {
      // Corregir un monto capturado de mas debe revertir el cumplimiento.
      final completed = _goal(target: 1000, current: 1000, isCompleted: true);
      final updated = SavingGoalRules.withAmount(completed, 500);
      expect(updated.isCompleted, isFalse);
    });

    test('no muta la meta original', () {
      final goal = _goal(target: 1000, current: 100);
      SavingGoalRules.withAmount(goal, 900);
      expect(goal.currentAmount, closeTo(100, 0.0001));
    });

    test('conserva la ruta de la imagen', () {
      // Si se perdiera, mover el progreso dejaria la foto huerfana.
      final goal = SavingGoal(
        id: 'g',
        userId: 'u',
        name: 'Laptop',
        targetAmount: 1000,
        imagePath: 'u/g/foto.jpg',
      );
      expect(SavingGoalRules.withAmount(goal, 500).imagePath, 'u/g/foto.jpg');
    });
  });

  group('SavingGoalRules.withImagePath', () {
    test('cambia la imagen y conserva el resto', () {
      final goal = _goal(target: 1000, current: 250, url: 'https://ejemplo.mx');
      final updated = SavingGoalRules.withImagePath(goal, 'u/g/nueva.png');

      expect(updated.imagePath, 'u/g/nueva.png');
      expect(updated.currentAmount, closeTo(250, 0.0001));
      expect(updated.url, 'https://ejemplo.mx');
    });

    test('con null quita la imagen', () {
      final goal = SavingGoal(
        id: 'g',
        userId: 'u',
        name: 'Laptop',
        targetAmount: 1000,
        imagePath: 'u/g/foto.jpg',
      );
      final updated = SavingGoalRules.withImagePath(goal, null);

      expect(updated.imagePath, isNull);
      expect(updated.hasImage, isFalse);
    });
  });

  group('SavingGoalRules.edited', () {
    test('reemplaza los campos editables y recalcula el cumplimiento', () {
      final goal = _goal(target: 1000, current: 100);
      final updated = SavingGoalRules.edited(
        goal: goal,
        name: 'Laptop gamer',
        targetAmount: 2000,
        currentAmount: 2000,
        url: 'https://otro.mx',
        imagePath: 'u/g/foto.webp',
      );

      expect(updated.name, 'Laptop gamer');
      expect(updated.targetAmount, closeTo(2000, 0.0001));
      expect(updated.currentAmount, closeTo(2000, 0.0001));
      expect(updated.url, 'https://otro.mx');
      expect(updated.imagePath, 'u/g/foto.webp');
      expect(updated.isCompleted, isTrue);
    });

    test('conserva la identidad y la fecha de creacion', () {
      final goal = _goal(target: 1000);
      final updated = SavingGoalRules.edited(
        goal: goal,
        name: 'Otro',
        targetAmount: 500,
        currentAmount: 0,
        url: null,
        imagePath: null,
      );

      expect(updated.id, goal.id);
      expect(updated.userId, goal.userId);
      expect(updated.createdAt, goal.createdAt);
    });

    test('bajar el objetivo puede marcar la meta como cumplida', () {
      final goal = _goal(target: 1000, current: 300);
      final updated = SavingGoalRules.edited(
        goal: goal,
        name: goal.name,
        targetAmount: 300,
        currentAmount: 300,
        url: null,
        imagePath: null,
      );
      expect(updated.isCompleted, isTrue);
    });
  });

  group('SavingGoalRules.imagePathsOf', () {
    test('solo devuelve las rutas de las metas con foto', () {
      final goals = [
        SavingGoal(
          id: 'a',
          userId: 'u',
          name: 'A',
          targetAmount: 100,
          imagePath: 'u/a/1.jpg',
        ),
        _goal(target: 100),
        SavingGoal(
          id: 'c',
          userId: 'u',
          name: 'C',
          targetAmount: 100,
          imagePath: 'u/c/1.png',
        ),
      ];

      expect(SavingGoalRules.imagePathsOf(goals), [
        'u/a/1.jpg',
        'u/c/1.png',
      ]);
    });

    test('una lista sin fotos devuelve vacio', () {
      expect(SavingGoalRules.imagePathsOf([_goal(target: 100)]), isEmpty);
    });
  });

  group('SavingGoalRules totales', () {
    test('suma objetivos y ahorrado de varias metas', () {
      final goals = [
        _goal(target: 1000, current: 250),
        _goal(target: 4000, current: 1000),
      ];
      expect(SavingGoalRules.totalTarget(goals), closeTo(5000, 0.0001));
      expect(SavingGoalRules.totalSaved(goals), closeTo(1250, 0.0001));
    });

    test('una lista vacia suma 0', () {
      expect(SavingGoalRules.totalTarget(const []), 0);
      expect(SavingGoalRules.totalSaved(const []), 0);
    });
  });
}
