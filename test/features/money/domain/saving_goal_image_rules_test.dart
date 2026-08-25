import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stoping_yourself/features/money/domain/saving_goal_image_rules.dart';

SavingGoalImageUpload _image({
  String fileName = 'foto.jpg',
  int sizeBytes = 1024,
}) {
  return SavingGoalImageUpload(
    fileName: fileName,
    bytes: Uint8List(sizeBytes),
  );
}

void main() {
  group('SavingGoalImageRules.extensionOf', () {
    test('saca la extension en minusculas', () {
      expect(SavingGoalImageRules.extensionOf('Foto.JPG'), 'jpg');
      expect(SavingGoalImageRules.extensionOf('imagen.png'), 'png');
    });

    test('se queda con la ultima extension', () {
      expect(SavingGoalImageRules.extensionOf('mi.foto.final.webp'), 'webp');
    });

    test('devuelve null si no hay extension', () {
      expect(SavingGoalImageRules.extensionOf('sinextension'), isNull);
      expect(SavingGoalImageRules.extensionOf('termina.'), isNull);
    });
  });

  group('SavingGoalImageRules.mimeTypeOf', () {
    test('mapea los formatos soportados', () {
      expect(SavingGoalImageRules.mimeTypeOf('a.jpg'), 'image/jpeg');
      expect(SavingGoalImageRules.mimeTypeOf('a.jpeg'), 'image/jpeg');
      expect(SavingGoalImageRules.mimeTypeOf('a.png'), 'image/png');
      expect(SavingGoalImageRules.mimeTypeOf('a.webp'), 'image/webp');
    });

    test('devuelve null para formatos no soportados', () {
      expect(SavingGoalImageRules.mimeTypeOf('documento.pdf'), isNull);
      expect(SavingGoalImageRules.mimeTypeOf('animacion.gif'), isNull);
      expect(SavingGoalImageRules.mimeTypeOf('sinextension'), isNull);
    });
  });

  group('SavingGoalImageRules.validate', () {
    test('acepta una imagen soportada dentro del limite', () {
      expect(
        SavingGoalImageRules.validate(_image()),
        SavingGoalImageValidation.valid,
      );
    });

    test('rechaza un archivo vacio', () {
      expect(
        SavingGoalImageRules.validate(_image(sizeBytes: 0)),
        SavingGoalImageValidation.empty,
      );
    });

    test('rechaza un formato no soportado', () {
      expect(
        SavingGoalImageRules.validate(_image(fileName: 'archivo.pdf')),
        SavingGoalImageValidation.unsupportedFormat,
      );
    });

    test('rechaza una imagen mas pesada que el limite', () {
      expect(
        SavingGoalImageRules.validate(
          _image(sizeBytes: SavingGoalImageRules.maxSizeBytes + 1),
        ),
        SavingGoalImageValidation.tooLarge,
      );
    });

    test('acepta una imagen exactamente en el limite', () {
      expect(
        SavingGoalImageRules.validate(
          _image(sizeBytes: SavingGoalImageRules.maxSizeBytes),
        ),
        SavingGoalImageValidation.valid,
      );
    });

    test('el formato se revisa antes del peso', () {
      // Un archivo enorme y no soportado debe reportar el formato, que es lo
      // que el usuario tiene que corregir primero.
      expect(
        SavingGoalImageRules.validate(
          _image(
            fileName: 'archivo.pdf',
            sizeBytes: SavingGoalImageRules.maxSizeBytes + 1,
          ),
        ),
        SavingGoalImageValidation.unsupportedFormat,
      );
    });
  });

  group('SavingGoalImageRules.buildPath', () {
    test('el primer segmento es el usuario, como exige el RLS del bucket', () {
      final path = SavingGoalImageRules.buildPath(
        userId: 'user-1',
        goalId: 'goal-9',
        imageId: 'img-7',
        fileName: 'foto.PNG',
      );
      expect(path, 'user-1/goal-9/img-7.png');
      expect(path.split('/').first, 'user-1');
    });

    test('cae a jpg cuando el nombre no trae extension', () {
      expect(
        SavingGoalImageRules.buildPath(
          userId: 'u',
          goalId: 'g',
          imageId: 'i',
          fileName: 'sinextension',
        ),
        'u/g/i.jpg',
      );
    });

    test('dos imagenes de la misma meta no comparten ruta', () {
      final first = SavingGoalImageRules.buildPath(
        userId: 'u',
        goalId: 'g',
        imageId: 'img-1',
        fileName: 'a.jpg',
      );
      final second = SavingGoalImageRules.buildPath(
        userId: 'u',
        goalId: 'g',
        imageId: 'img-2',
        fileName: 'a.jpg',
      );
      expect(first, isNot(second));
    });
  });

  group('SavingGoalImageRules.folderOfGoal', () {
    test('agrupa por usuario y meta', () {
      expect(
        SavingGoalImageRules.folderOfGoal(userId: 'u', goalId: 'g'),
        'u/g',
      );
    });
  });

  group('SavingGoalImageRules configuracion', () {
    test('el limite en MB coincide con el de bytes', () {
      expect(SavingGoalImageRules.maxSizeMb, closeTo(5, 0.0001));
    });

    test('el bucket es el que crea la migracion', () {
      expect(SavingGoalImageRules.bucket, 'saving-goal-images');
    });
  });
}
