import 'money_failure.dart';

/// Envuelve una lectura y convierte cualquier excepcion en [MoneyReadFailure].
///
/// El error se propaga a proposito: los `FutureProvider` de Riverpod lo
/// capturan en `AsyncValue.error` y la UI decide que mostrar. Nunca se
/// devuelve un valor vacio para disfrazar un fallo.
Future<T> guardRead<T>(String operation, Future<T> Function() body) async {
  try {
    return await body();
  } on MoneyFailure {
    rethrow;
  } catch (error, stackTrace) {
    throw MoneyReadFailure(
      operation: operation,
      cause: error,
      stackTrace: stackTrace,
    );
  }
}

/// Envuelve una escritura y convierte cualquier excepcion en
/// [MoneyWriteFailure].
Future<T> guardWrite<T>(String operation, Future<T> Function() body) async {
  try {
    return await body();
  } on MoneyFailure {
    rethrow;
  } catch (error, stackTrace) {
    throw MoneyWriteFailure(
      operation: operation,
      cause: error,
      stackTrace: stackTrace,
    );
  }
}
