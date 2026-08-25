import 'package:supabase_flutter/supabase_flutter.dart';

/// Fallo al hablar con la fuente de datos de finanzas.
///
/// Existe porque antes la capa de datos hacia `catch (_) { return []; }` y la
/// UI pintaba ceros y listas vacias como si fueran datos reales: un problema
/// de red o de permisos se veia igual que "no tienes nada ahorrado".
sealed class MoneyFailure implements Exception {
  const MoneyFailure({
    required this.operation,
    required this.cause,
    this.stackTrace,
  });

  /// Que se estaba intentando hacer, en lenguaje de negocio.
  /// Ej: 'cargar tus movimientos', 'registrar el pago'.
  final String operation;

  /// La excepcion original, para logs y diagnostico.
  final Object cause;

  final StackTrace? stackTrace;

  /// Mensaje listo para mostrarle al usuario.
  String get userMessage {
    final detail = _describeCause(cause);
    return detail == null
        ? 'No se pudo $operation.'
        : 'No se pudo $operation: $detail';
  }

  @override
  String toString() => '$runtimeType($operation): $cause';
}

/// Fallo al leer datos. La UI deberia ofrecer reintentar.
final class MoneyReadFailure extends MoneyFailure {
  const MoneyReadFailure({
    required super.operation,
    required super.cause,
    super.stackTrace,
  });
}

/// Fallo al escribir datos. Lo que el usuario intentaba no se guardo.
final class MoneyWriteFailure extends MoneyFailure {
  const MoneyWriteFailure({
    required super.operation,
    required super.cause,
    super.stackTrace,
  });
}

/// Traduce las excepciones tipicas de Supabase a algo entendible.
///
/// Devuelve `null` cuando no hay nada util que agregar, para no soltarle al
/// usuario un stack trace en la cara.
String? _describeCause(Object cause) {
  if (cause is PostgrestException) {
    final message = cause.message.toLowerCase();

    // Postgres usa 42501 para dos problemas distintos que se arreglan de
    // formas distintas, asi que conviene separarlos:
    //   - falta GRANT: el rol no tiene permiso sobre la tabla.
    //   - falta politica RLS: tiene permiso, pero no sobre esa fila.
    if (message.contains('permission denied')) {
      return 'la tabla no tiene permisos concedidos para tu rol (falta un '
          'GRANT en la base de datos).';
    }
    if (cause.code == '42501' || message.contains('row-level security')) {
      return 'no tienes permiso sobre este registro (politica RLS). Revisa '
          'que tu sesion siga activa.';
    }
    // 42703: columna inexistente. Casi siempre es esquema desalineado.
    if (cause.code == '42703' || cause.code == '42P01') {
      return 'la base de datos no coincide con la app. Avisa que falta una '
          'migracion.';
    }
    if (cause.code == '23505') {
      return 'ese registro ya existe.';
    }
    if (cause.code == '23503') {
      return 'hay datos relacionados que lo impiden.';
    }
    return cause.message;
  }

  if (cause is StorageException) return _describeStorageError(cause);

  if (cause is AuthException) {
    return 'tu sesion expiro, vuelve a entrar.';
  }

  if (_looksLikeNetworkIssue(cause)) {
    return 'revisa tu conexion a internet.';
  }

  return null;
}

/// Traduce los fallos de Supabase Storage.
///
/// Storage lanza [StorageException], que no es un [PostgrestException], asi
/// que sus errores de permisos no los cubre la rama de arriba. Los mensajes
/// apuntan a la causa configurable (bucket, politicas, limites del bucket)
/// porque son los que se rompen al montar la funcionalidad.
String? _describeStorageError(StorageException cause) {
  final message = cause.message.toLowerCase();

  if (message.contains('bucket not found')) {
    return 'falta crear el bucket de imagenes en Supabase.';
  }
  if (cause.statusCode == '403' ||
      message.contains('row-level security') ||
      message.contains('unauthorized')) {
    return 'no tienes permiso para guardar la imagen. Faltan las politicas '
        'del bucket.';
  }
  if (cause.statusCode == '413' ||
      message.contains('exceeded the maximum allowed size')) {
    return 'la imagen excede el tamano permitido por el bucket.';
  }
  if (message.contains('mime type') || message.contains('invalid_mime_type')) {
    return 'el bucket no acepta ese tipo de imagen.';
  }
  // Se incluye el codigo porque los fallos de Storage restantes casi siempre
  // son de configuracion y sin el no hay por donde empezar a buscar.
  return '${cause.message} (codigo ${cause.statusCode ?? 'sin codigo'})';
}

/// Detecta problemas de red sin importar `dart:io`, que no existe en web.
bool _looksLikeNetworkIssue(Object cause) {
  final text = cause.toString().toLowerCase();
  const networkHints = [
    'socketexception',
    'clientexception',
    'failed host lookup',
    'connection refused',
    'connection closed',
    'connection reset',
    'network is unreachable',
    'timeoutexception',
    'timed out',
  ];
  return networkHints.any(text.contains);
}
