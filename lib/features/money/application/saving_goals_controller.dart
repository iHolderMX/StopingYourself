import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/saving_goal.dart';
import '../data/money_providers.dart';
import '../domain/saving_goal_image_rules.dart';
import '../domain/saving_goal_rules.dart';
import 'money_error_message.dart';
import 'money_id.dart';

/// Que hacer con la imagen de una meta al editarla.
///
/// Existe porque "no tocar la foto" y "quitar la foto" son intenciones
/// distintas que un simple `String?` no puede diferenciar: `null` seria
/// ambiguo entre ambas.
sealed class SavingGoalImageAction {
  const SavingGoalImageAction();

  /// Deja la imagen como esta.
  const factory SavingGoalImageAction.keep() = KeepGoalImage;

  /// Quita la imagen actual.
  const factory SavingGoalImageAction.remove() = RemoveGoalImage;

  /// Reemplaza la imagen por una nueva.
  const factory SavingGoalImageAction.replace(SavingGoalImageUpload image) =
      ReplaceGoalImage;
}

final class KeepGoalImage extends SavingGoalImageAction {
  const KeepGoalImage();
}

final class RemoveGoalImage extends SavingGoalImageAction {
  const RemoveGoalImage();
}

final class ReplaceGoalImage extends SavingGoalImageAction {
  const ReplaceGoalImage(this.image);
  final SavingGoalImageUpload image;
}

/// Casos de uso de las metas de ahorro.
class SavingGoalsController {
  const SavingGoalsController(this._ref);

  final Ref _ref;

  Future<void> add({
    required String userId,
    required String name,
    required double targetAmount,
    double currentAmount = 0,
    String? url,
    SavingGoalImageUpload? image,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const MoneyValidationException('Ponle nombre a la meta.');
    }
    if (targetAmount <= 0) {
      throw const MoneyValidationException(
        'El objetivo debe ser mayor a cero.',
      );
    }
    if (currentAmount < 0) {
      throw const MoneyValidationException(
        'El monto actual no puede ser negativo.',
      );
    }
    if (image != null) _ensureImageIsValid(image);

    final goalId = newMoneyId();
    // La imagen se sube antes de insertar: si la subida falla, no queda una
    // meta apuntando a un archivo que no existe.
    final imagePath = image == null
        ? null
        : await _uploadImage(userId: userId, goalId: goalId, image: image);

    final trimmedUrl = url?.trim();
    try {
      await _ref.read(savingGoalsRepositoryProvider).insert(
        SavingGoal(
          id: goalId,
          userId: userId,
          name: trimmedName,
          targetAmount: targetAmount,
          currentAmount: currentAmount,
          url: (trimmedUrl == null || trimmedUrl.isEmpty) ? null : trimmedUrl,
          imagePath: imagePath,
          isCompleted: SavingGoalRules.isCompleted(
            currentAmount: currentAmount,
            targetAmount: targetAmount,
          ),
        ),
      );
    } catch (_) {
      // Si no se pudo guardar la meta, la imagen recien subida quedaria
      // huerfana en el bucket.
      if (imagePath != null) await _deleteImageQuietly(imagePath);
      rethrow;
    }
    _invalidate(userId);
  }

  /// Edita todos los campos de una meta, incluida la imagen.
  Future<void> edit({
    required String userId,
    required SavingGoal goal,
    required String name,
    required double targetAmount,
    required double currentAmount,
    String? url,
    SavingGoalImageAction imageAction = const SavingGoalImageAction.keep(),
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const MoneyValidationException('Ponle nombre a la meta.');
    }
    if (targetAmount <= 0) {
      throw const MoneyValidationException(
        'El objetivo debe ser mayor a cero.',
      );
    }
    if (currentAmount < 0) {
      throw const MoneyValidationException(
        'El monto actual no puede ser negativo.',
      );
    }

    final previousPath = goal.imagePath;
    final String? nextPath;
    switch (imageAction) {
      case KeepGoalImage():
        nextPath = previousPath;
      case RemoveGoalImage():
        nextPath = null;
      case ReplaceGoalImage(image: final image):
        _ensureImageIsValid(image);
        nextPath = await _uploadImage(
          userId: userId,
          goalId: goal.id,
          image: image,
        );
    }

    final trimmedUrl = url?.trim();
    try {
      await _ref.read(savingGoalsRepositoryProvider).update(
        SavingGoalRules.edited(
          goal: goal,
          name: trimmedName,
          targetAmount: targetAmount,
          currentAmount: currentAmount,
          url: (trimmedUrl == null || trimmedUrl.isEmpty) ? null : trimmedUrl,
          imagePath: nextPath,
        ),
      );
    } catch (_) {
      // La imagen nueva no llego a quedar referenciada por nadie.
      if (nextPath != null && nextPath != previousPath) {
        await _deleteImageQuietly(nextPath);
      }
      rethrow;
    }

    // Recien aqui es seguro tirar la anterior: la meta ya apunta a la nueva.
    if (previousPath != null && previousPath != nextPath) {
      await _deleteImageQuietly(previousPath);
    }

    _invalidateImage(previousPath);
    _invalidateImage(nextPath);
    _invalidate(userId);
  }

  /// Actualiza solo el progreso de una meta.
  ///
  /// La bandera de cumplimiento se recalcula en el dominio, asi que ya no
  /// depende de que quien llame se acuerde de hacerlo.
  Future<void> updateAmount({
    required String userId,
    required SavingGoal goal,
    required double currentAmount,
  }) async {
    if (currentAmount < 0) {
      throw const MoneyValidationException('El monto no puede ser negativo.');
    }

    await _ref
        .read(savingGoalsRepositoryProvider)
        .update(SavingGoalRules.withAmount(goal, currentAmount));
    _invalidate(userId);
  }

  Future<void> delete({
    required String userId,
    required SavingGoal goal,
  }) async {
    await _ref.read(savingGoalsRepositoryProvider).delete(goal.id);

    // La meta ya no existe: si limpiar el bucket falla solo quedan archivos
    // sueltos, y eso no debe presentarse al usuario como que fallo el borrado.
    try {
      await _ref
          .read(savingGoalImagesRepositoryProvider)
          .deleteFolderOfGoal(userId: userId, goalId: goal.id);
    } catch (_) {}

    _invalidateImage(goal.imagePath);
    _invalidate(userId);
  }

  void _ensureImageIsValid(SavingGoalImageUpload image) {
    switch (SavingGoalImageRules.validate(image)) {
      case SavingGoalImageValidation.valid:
        return;
      case SavingGoalImageValidation.empty:
        throw const MoneyValidationException(
          'La imagen llego vacia, intenta elegirla de nuevo.',
        );
      case SavingGoalImageValidation.unsupportedFormat:
        throw MoneyValidationException(
          'Formato no soportado. Usa '
          '${SavingGoalImageRules.allowedExtensions.join(', ')}.',
        );
      case SavingGoalImageValidation.tooLarge:
        throw MoneyValidationException(
          'La imagen pesa mas de '
          '${SavingGoalImageRules.maxSizeMb.toStringAsFixed(0)} MB. '
          'Elige una mas ligera.',
        );
    }
  }

  Future<String> _uploadImage({
    required String userId,
    required String goalId,
    required SavingGoalImageUpload image,
  }) {
    final path = SavingGoalImageRules.buildPath(
      userId: userId,
      goalId: goalId,
      imageId: newMoneyId(),
      fileName: image.fileName,
    );
    return _ref.read(savingGoalImagesRepositoryProvider).upload(
      path: path,
      bytes: image.bytes,
      contentType: SavingGoalImageRules.mimeTypeOf(image.fileName)!,
    );
  }

  /// Borra una imagen sin propagar el error.
  ///
  /// Se usa en limpiezas donde el fallo no debe tapar el resultado real de
  /// la operacion: como mucho queda un archivo sin usar en el bucket.
  Future<void> _deleteImageQuietly(String path) async {
    try {
      await _ref.read(savingGoalImagesRepositoryProvider).delete(path);
    } catch (_) {}
  }

  void _invalidateImage(String? path) {
    if (path == null) return;
    _ref.invalidate(savingGoalImageUrlProvider(path));
  }

  void _invalidate(String userId) =>
      _ref.invalidate(savingGoalsProvider(userId));
}

final savingGoalsControllerProvider = Provider<SavingGoalsController>(
  SavingGoalsController.new,
);
