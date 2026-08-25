import 'dart:typed_data';

/// Imagen elegida por el usuario, lista para subirse.
///
/// Es solo datos: no depende de Flutter ni del selector de archivos, asi que
/// las reglas de abajo se pueden probar sin montar un widget.
class SavingGoalImageUpload {
  const SavingGoalImageUpload({required this.fileName, required this.bytes});

  /// Nombre original del archivo. Solo se usa para sacar la extension.
  final String fileName;

  final Uint8List bytes;

  int get sizeBytes => bytes.length;
}

/// Resultado de validar una imagen antes de subirla.
enum SavingGoalImageValidation {
  valid,

  /// El archivo llego vacio.
  empty,

  /// Pesa mas de lo permitido.
  tooLarge,

  /// La extension no es de un formato de imagen soportado.
  unsupportedFormat,
}

/// Reglas de las imagenes de las metas de ahorro.
class SavingGoalImageRules {
  const SavingGoalImageRules._();

  /// Nombre del bucket de Storage.
  static const String bucket = 'saving-goal-images';

  /// Peso maximo permitido. Debe coincidir con `file_size_limit` del bucket
  /// para que el rechazo ocurra en la app y no despues de gastar la subida.
  static const int maxSizeBytes = 5 * 1024 * 1024;

  /// Cuanto vive una URL firmada, en segundos.
  static const int signedUrlTtlSeconds = 3600;

  /// Extensiones aceptadas, mapeadas a su tipo MIME.
  ///
  /// Los MIME deben ser un subconjunto de `allowed_mime_types` del bucket.
  static const Map<String, String> _mimeByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static Iterable<String> get allowedExtensions => _mimeByExtension.keys;

  /// Peso maximo en MB, para armar mensajes al usuario.
  static double get maxSizeMb => maxSizeBytes / (1024 * 1024);

  /// Extension en minusculas y sin punto, o `null` si el nombre no la trae.
  static String? extensionOf(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == fileName.length - 1) return null;
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  /// Tipo MIME que corresponde al archivo, o `null` si no es soportado.
  static String? mimeTypeOf(String fileName) {
    final extension = extensionOf(fileName);
    if (extension == null) return null;
    return _mimeByExtension[extension];
  }

  static bool isSupported(String fileName) => mimeTypeOf(fileName) != null;

  /// Valida una imagen antes de subirla.
  static SavingGoalImageValidation validate(SavingGoalImageUpload image) {
    if (image.sizeBytes <= 0) return SavingGoalImageValidation.empty;
    if (!isSupported(image.fileName)) {
      return SavingGoalImageValidation.unsupportedFormat;
    }
    if (image.sizeBytes > maxSizeBytes) {
      return SavingGoalImageValidation.tooLarge;
    }
    return SavingGoalImageValidation.valid;
  }

  /// Ruta destino dentro del bucket.
  ///
  /// El primer segmento es el id del usuario porque las politicas RLS del
  /// bucket comparan `(storage.foldername(name))[1]` contra `auth.uid()`.
  ///
  /// Se incluye un [imageId] unico en lugar de reusar la ruta al reemplazar
  /// la foto: si se sobreescribiera el mismo nombre, el CDN podria seguir
  /// sirviendo la imagen anterior desde cache.
  static String buildPath({
    required String userId,
    required String goalId,
    required String imageId,
    required String fileName,
  }) {
    final extension = extensionOf(fileName) ?? 'jpg';
    return '$userId/$goalId/$imageId.$extension';
  }

  /// Carpeta que agrupa las imagenes de una meta.
  static String folderOfGoal({required String userId, required String goalId}) =>
      '$userId/$goalId';
}
