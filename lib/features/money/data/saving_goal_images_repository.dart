import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/saving_goal_image_rules.dart';
import 'supabase_guard.dart';

/// Acceso a las imagenes de las metas de ahorro en Supabase Storage.
///
/// El bucket es privado: para mostrar una imagen hay que pedir una URL
/// firmada, que caduca. Las politicas del bucket exigen que el primer
/// segmento de la ruta sea el id del usuario.
class SavingGoalImagesRepository {
  const SavingGoalImagesRepository(this._client);

  final SupabaseClient _client;

  StorageFileApi get _bucket =>
      _client.storage.from(SavingGoalImageRules.bucket);

  /// Sube la imagen y devuelve la ruta guardada.
  ///
  /// Se usa `uploadBinary` con bytes en lugar de `upload` con un `File`
  /// porque la app tambien corre en web, donde `dart:io` no existe.
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) {
    return guardWrite('subir la imagen', () async {
      await _bucket.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );
      return path;
    });
  }

  /// URL temporal para mostrar la imagen.
  Future<String> createSignedUrl(String path) {
    return guardRead(
      'abrir la imagen',
      () => _bucket.createSignedUrl(
        path,
        SavingGoalImageRules.signedUrlTtlSeconds,
      ),
    );
  }

  Future<void> delete(String path) => deleteMany([path]);

  /// Borra varias imagenes de un jalon.
  ///
  /// Se ignora una lista vacia para no mandar una peticion inutil cuando
  /// ninguna meta tenia foto.
  Future<void> deleteMany(List<String> paths) {
    if (paths.isEmpty) return Future.value();
    return guardWrite('eliminar la imagen', () => _bucket.remove(paths));
  }

  /// Borra todas las imagenes de una meta.
  ///
  /// Lista la carpeta de la meta en lugar de confiar en la ruta guardada:
  /// asi tambien se limpian archivos que quedaron sueltos si una subida
  /// alcanzo a completarse pero el registro no.
  Future<void> deleteFolderOfGoal({
    required String userId,
    required String goalId,
  }) {
    final folder = SavingGoalImageRules.folderOfGoal(
      userId: userId,
      goalId: goalId,
    );
    return guardWrite('eliminar las imagenes de la meta', () async {
      final files = await _bucket.list(path: folder);
      if (files.isEmpty) return;
      await _bucket.remove(files.map((f) => '$folder/${f.name}').toList());
    });
  }
}
