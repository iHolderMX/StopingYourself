import '../data/money_failure.dart';

/// Error de validacion de negocio, con el mensaje ya listo para el usuario.
///
/// Se distingue de [MoneyFailure] a proposito: aqui no fallo nada tecnico,
/// simplemente lo que se pidio no cumple las reglas.
class MoneyValidationException implements Exception {
  const MoneyValidationException(this.userMessage);

  final String userMessage;

  @override
  String toString() => 'MoneyValidationException: $userMessage';
}

/// Traduce cualquier error del modulo de finanzas a un mensaje mostrable.
///
/// Un unico lugar para esto evita que cada `catch` de la UI improvise su
/// propio `'Error: $e'`, que era lo que soltaba excepciones crudas en pantalla.
String describeMoneyError(Object error) {
  if (error is MoneyValidationException) return error.userMessage;
  if (error is MoneyFailure) return error.userMessage;
  return 'Algo salio mal. Intenta de nuevo.';
}
