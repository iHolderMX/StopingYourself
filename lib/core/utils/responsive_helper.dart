import 'package:flutter/material.dart';

enum ScreenSize { mobile, tablet, desktop }

class ResponsiveHelper {
  static const double breakpointTablet = 600;
  static const double breakpointDesktop = 900;

  final BuildContext context;

  ResponsiveHelper(this.context);

  double get width => MediaQuery.of(context).size.width;
  double get height => MediaQuery.of(context).size.height;

  ScreenSize get screenSize {
    if (width >= breakpointDesktop) return ScreenSize.desktop;
    if (width >= breakpointTablet) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }

  bool get isMobile => screenSize == ScreenSize.mobile;
  bool get isTablet => screenSize == ScreenSize.tablet;
  bool get isDesktop => screenSize == ScreenSize.desktop;

  // Pad horizontal responsivo
  double get padHorizontal {
    if (isDesktop) return 40;
    if (isTablet) return 28;
    return 16;
  }

  double get padVertical {
    if (isDesktop) return 32;
    if (isTablet) return 24;
    return 16;
  }

  // Padding uniforme para paginas
  EdgeInsets get pagePadding => EdgeInsets.symmetric(
        horizontal: padHorizontal,
        vertical: padVertical,
      );

  // Ancho maximo del contenido (centrado en desktop)
  double get contentMaxWidth {
    if (isDesktop) return 1200;
    return double.infinity;
  }

  // Numero de columnas en grids
  int get gridColumns {
    if (isDesktop) return 3;
    if (isTablet) return 2;
    return 1;
  }

  // Numero de columnas para stats
  int get statColumns {
    if (isDesktop) return 4;
    if (isTablet) return 3;
    return 3;
  }

  // Espaciado entre cards
  double get cardSpacing {
    if (isDesktop) return 20;
    if (isTablet) return 16;
    return 12;
  }

  // Fuente titulo principal
  double get titleFontSize {
    if (isDesktop) return 36;
    if (isTablet) return 30;
    return 24;
  }

  // Fuente subtitulo
  double get subtitleFontSize {
    if (isDesktop) return 18;
    if (isTablet) return 16;
    return 14;
  }

  // Fuente body
  double get bodyFontSize {
    if (isDesktop) return 16;
    if (isTablet) return 15;
    return 14;
  }

  // Tamaño de iconos grandes
  double get iconSizeLarge {
    if (isDesktop) return 80;
    if (isTablet) return 64;
    return 56;
  }

  // Tamaño de iconos medianos
  double get iconSizeMedium {
    if (isDesktop) return 32;
    if (isTablet) return 28;
    return 24;
  }

  // Altura de botones
  double get buttonHeight {
    if (isDesktop) return 56;
    if (isTablet) return 52;
    return 48;
  }

  // Radio de bordes
  double get borderRadius {
    if (isDesktop) return 20;
    if (isTablet) return 18;
    return 14;
  }

  // Ancho maximo del formulario de login (centrado)
  double get formMaxWidth => 480;
}
