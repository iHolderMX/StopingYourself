import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stoping_yourself/features/money/application/money_error_message.dart';
import 'package:stoping_yourself/features/money/application/saving_goals_controller.dart';
import 'package:stoping_yourself/features/money/data/money_providers.dart';
import 'package:stoping_yourself/features/money/domain/saving_goal_image_rules.dart';
import 'package:stoping_yourself/models/saving_goal.dart';

import 'fakes.dart';

SavingGoalImageUpload _image({
  String fileName = 'foto.jpg',
  int sizeBytes = 2048,
}) {
  return SavingGoalImageUpload(
    fileName: fileName,
    bytes: Uint8List(sizeBytes),
  );
}

SavingGoal _goal({String? imagePath}) => SavingGoal(
  id: 'goal-1',
  userId: 'user-1',
  name: 'Laptop',
  targetAmount: 30000,
  currentAmount: 5000,
  url: 'https://ejemplo.mx',
  imagePath: imagePath,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  late FakeSavingGoalsRepository goals;
  late FakeSavingGoalImagesRepository images;
  late ProviderContainer container;

  setUp(() {
    goals = FakeSavingGoalsRepository();
    images = FakeSavingGoalImagesRepository();
    container = ProviderContainer(
      overrides: [
        savingGoalsRepositoryProvider.overrideWithValue(goals),
        savingGoalImagesRepositoryProvider.overrideWithValue(images),
      ],
    );
    addTearDown(container.dispose);
  });

  SavingGoalsController controller() =>
      container.read(savingGoalsControllerProvider);

  group('add con imagen', () {
    test('sube la foto y guarda su ruta en la meta', () async {
      await controller().add(
        userId: 'user-1',
        name: 'Laptop',
        targetAmount: 30000,
        image: _image(fileName: 'laptop.png'),
      );

      expect(images.uploadedPaths, hasLength(1));
      expect(images.uploadedContentTypes.single, 'image/png');

      final saved = goals.inserted.single;
      expect(saved.imagePath, images.uploadedPaths.single);
      expect(saved.hasImage, isTrue);
      // La ruta debe empezar con el usuario por las politicas del bucket.
      expect(saved.imagePath!.startsWith('user-1/'), isTrue);
      // Y agruparse bajo la meta recien creada.
      expect(saved.imagePath!.contains('/${saved.id}/'), isTrue);
    });

    test('sin imagen no toca Storage', () async {
      await controller().add(
        userId: 'user-1',
        name: 'Laptop',
        targetAmount: 30000,
      );

      expect(images.uploadedPaths, isEmpty);
      expect(goals.inserted.single.imagePath, isNull);
    });

    test('rechaza un formato no soportado sin subir nada', () async {
      await expectLater(
        controller().add(
          userId: 'user-1',
          name: 'Laptop',
          targetAmount: 30000,
          image: _image(fileName: 'archivo.pdf'),
        ),
        throwsA(
          isA<MoneyValidationException>().having(
            (e) => e.userMessage,
            'userMessage',
            contains('Formato'),
          ),
        ),
      );
      expect(images.uploadedPaths, isEmpty);
      expect(goals.inserted, isEmpty);
    });

    test('rechaza una imagen demasiado pesada sin subir nada', () async {
      await expectLater(
        controller().add(
          userId: 'user-1',
          name: 'Laptop',
          targetAmount: 30000,
          image: _image(sizeBytes: SavingGoalImageRules.maxSizeBytes + 1),
        ),
        throwsA(
          isA<MoneyValidationException>().having(
            (e) => e.userMessage,
            'userMessage',
            contains('MB'),
          ),
        ),
      );
      expect(images.uploadedPaths, isEmpty);
    });

    test('si falla guardar la meta, borra la imagen ya subida', () async {
      goals.failWrites = true;

      await expectLater(
        controller().add(
          userId: 'user-1',
          name: 'Laptop',
          targetAmount: 30000,
          image: _image(),
        ),
        throwsA(isA<Exception>()),
      );

      // No debe quedar un archivo huerfano en el bucket.
      expect(images.deletedPaths, equals(images.uploadedPaths));
    });
  });

  group('edit con imagen', () {
    test('keep no toca Storage ni cambia la ruta', () async {
      final goal = _goal(imagePath: 'user-1/goal-1/vieja.jpg');

      await controller().edit(
        userId: 'user-1',
        goal: goal,
        name: 'Laptop nueva',
        targetAmount: 32000,
        currentAmount: 6000,
        url: 'https://ejemplo.mx',
      );

      expect(images.uploadedPaths, isEmpty);
      expect(images.deletedPaths, isEmpty);
      expect(goals.updated.single.imagePath, 'user-1/goal-1/vieja.jpg');
      expect(goals.updated.single.name, 'Laptop nueva');
    });

    test('replace sube la nueva y borra la anterior', () async {
      final goal = _goal(imagePath: 'user-1/goal-1/vieja.jpg');

      await controller().edit(
        userId: 'user-1',
        goal: goal,
        name: 'Laptop',
        targetAmount: 30000,
        currentAmount: 5000,
        imageAction: SavingGoalImageAction.replace(_image(fileName: 'n.webp')),
      );

      expect(images.uploadedPaths, hasLength(1));
      expect(images.uploadedContentTypes.single, 'image/webp');
      expect(goals.updated.single.imagePath, images.uploadedPaths.single);
      // La anterior se borra solo despues de que la meta ya apunta a la nueva.
      expect(images.deletedPaths, ['user-1/goal-1/vieja.jpg']);
    });

    test('remove quita la ruta y borra el archivo', () async {
      final goal = _goal(imagePath: 'user-1/goal-1/vieja.jpg');

      await controller().edit(
        userId: 'user-1',
        goal: goal,
        name: 'Laptop',
        targetAmount: 30000,
        currentAmount: 5000,
        imageAction: const SavingGoalImageAction.remove(),
      );

      expect(goals.updated.single.imagePath, isNull);
      expect(goals.updated.single.hasImage, isFalse);
      expect(images.deletedPaths, ['user-1/goal-1/vieja.jpg']);
      expect(images.uploadedPaths, isEmpty);
    });

    test('replace en una meta sin foto previa no borra nada', () async {
      await controller().edit(
        userId: 'user-1',
        goal: _goal(),
        name: 'Laptop',
        targetAmount: 30000,
        currentAmount: 5000,
        imageAction: SavingGoalImageAction.replace(_image()),
      );

      expect(images.uploadedPaths, hasLength(1));
      expect(images.deletedPaths, isEmpty);
    });

    test('si falla guardar, borra la imagen nueva y conserva la anterior',
        () async {
      goals.failWrites = true;
      final goal = _goal(imagePath: 'user-1/goal-1/vieja.jpg');

      await expectLater(
        controller().edit(
          userId: 'user-1',
          goal: goal,
          name: 'Laptop',
          targetAmount: 30000,
          currentAmount: 5000,
          imageAction: SavingGoalImageAction.replace(_image()),
        ),
        throwsA(isA<Exception>()),
      );

      // Se limpia la subida fallida, pero la foto original sigue viva.
      expect(images.deletedPaths, equals(images.uploadedPaths));
      expect(images.deletedPaths, isNot(contains('user-1/goal-1/vieja.jpg')));
    });

    test('recalcula el cumplimiento con los montos editados', () async {
      await controller().edit(
        userId: 'user-1',
        goal: _goal(),
        name: 'Laptop',
        targetAmount: 1000,
        currentAmount: 1000,
      );

      expect(goals.updated.single.isCompleted, isTrue);
    });

    test('rechaza nombre vacio sin escribir', () async {
      await expectLater(
        controller().edit(
          userId: 'user-1',
          goal: _goal(),
          name: '   ',
          targetAmount: 1000,
          currentAmount: 0,
        ),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(goals.updated, isEmpty);
    });

    test('rechaza objetivo no positivo sin escribir', () async {
      await expectLater(
        controller().edit(
          userId: 'user-1',
          goal: _goal(),
          name: 'Laptop',
          targetAmount: 0,
          currentAmount: 0,
        ),
        throwsA(isA<MoneyValidationException>()),
      );
      expect(goals.updated, isEmpty);
    });

    test('una url vacia se guarda como null', () async {
      await controller().edit(
        userId: 'user-1',
        goal: _goal(),
        name: 'Laptop',
        targetAmount: 1000,
        currentAmount: 0,
        url: '   ',
      );

      expect(goals.updated.single.url, isNull);
    });
  });

  group('updateAmount', () {
    test('conserva la foto al mover solo el progreso', () async {
      final goal = _goal(imagePath: 'user-1/goal-1/foto.jpg');

      await controller().updateAmount(
        userId: 'user-1',
        goal: goal,
        currentAmount: 9000,
      );

      expect(goals.updated.single.imagePath, 'user-1/goal-1/foto.jpg');
      expect(goals.updated.single.currentAmount, closeTo(9000, 0.0001));
    });
  });

  group('delete', () {
    test('borra la meta y limpia su carpeta de imagenes', () async {
      await controller().delete(
        userId: 'user-1',
        goal: _goal(imagePath: 'user-1/goal-1/foto.jpg'),
      );

      expect(goals.deleted, ['goal-1']);
      expect(images.deletedFolders, ['user-1/goal-1']);
    });

    test('una meta sin foto igual se borra', () async {
      await controller().delete(userId: 'user-1', goal: _goal());
      expect(goals.deleted, ['goal-1']);
    });
  });
}
