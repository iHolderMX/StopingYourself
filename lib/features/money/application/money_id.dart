import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Genera identificadores para los registros de finanzas.
///
/// Antes cada pantalla armaba el id como `'${userId}_$millisecondsSinceEpoch'`.
/// Dos guardadas dentro del mismo milisegundo producian el mismo id y la
/// segunda chocaba con la llave primaria. UUID v4 elimina ese riesgo sin
/// depender del reloj.
///
/// Las tablas usan `id TEXT PRIMARY KEY`, asi que el formato del id es opaco:
/// cambiarlo no rompe los registros que ya existen.
String newMoneyId() => _uuid.v4();
