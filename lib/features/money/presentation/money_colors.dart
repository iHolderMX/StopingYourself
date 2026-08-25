import 'package:flutter/material.dart';

/// Colores semanticos del modulo de finanzas.
///
/// Antes estaban como `Colors.green`, `Colors.redAccent` y `Colors.amber`
/// sueltos dentro de los widgets, mas una paleta de graficas declarada como
/// `const` privada en un archivo de UI. Aqui hay un solo lugar donde
/// cambiarlos.
///
/// No es una `ThemeExtension` a proposito: el proyecto tiene un tema claro y
/// uno oscuro que comparten estos significados. Si algun dia necesitan variar
/// por tema, esto se convierte en extension sin tocar a quien lo consume.
class MoneyColors {
  const MoneyColors._();

  /// Saldo a favor, meta cumplida, dinero disponible.
  static final Color positive = Colors.green.shade400;

  /// Saldo en rojo, deuda, accion destructiva.
  static const Color negative = Colors.redAccent;

  /// Falta configurar algo para poder continuar.
  static final Color warning = Colors.amber.shade700;

  /// Acento del fondo de emergencia.
  static const Color emergency = Colors.amber;

  /// Colores para distinguir categorias en graficas.
  ///
  /// Se recorre con modulo, asi que aguanta cualquier cantidad de elementos.
  static const List<Color> chartPalette = [
    Color(0xFF42A5F5), // azul
    Color(0xFFEF5350), // rojo
    Color(0xFFFFA726), // naranja
    Color(0xFFAB47BC), // purpura
    Color(0xFF26A69A), // teal
    Color(0xFFEC407A), // rosa
    Color(0xFF7E57C2), // morado
    Color(0xFFFFCA28), // ambar
    Color(0xFF5C6BC0), // indigo
    Color(0xFF8D6E63), // marron
  ];

  /// Color de la categoria en la posicion [index].
  static Color chartColorAt(int index) =>
      chartPalette[index % chartPalette.length];

  /// Verde si el monto no es negativo, rojo si lo es.
  static Color forBalance(double amount) => amount >= 0 ? positive : negative;
}
