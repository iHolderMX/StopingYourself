import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ── Sistema de 2 temas intercambiables ──
/// Para cambiar de tema, solo modifica `themeMode` en MaterialApp.router
class AppTheme {
  // ═══════════════════════════════════════════════════════════════
  // Colores base del tema oscuro (azul neon + negro)
  // ═══════════════════════════════════════════════════════════════
  static const _neon = Color(0xFF00D4FF);
  static const _neonBright = Color(0xFF4DE8FF);
  static const _neonDim = Color(0xFF0099BB);
  static const _black = Color(0xFF0A0A0F);
  static const _grey850 = Color(0xFF18181F);
  static const _grey800 = Color(0xFF1E1E26);
  static const _grey700 = Color(0xFF2A2A35);
  static const _grey600 = Color(0xFF3A3A48);
  static const _textLight = Color(0xFFE0E0E0);
  static const _textMuted = Color(0xFF888899);

  // ═══════════════════════════════════════════════════════════════
  // TEMA OSCURO (solo azul neon + negro/grises)
  // ═══════════════════════════════════════════════════════════════
  static ThemeData get darkTheme {
    const menuStyle = MenuStyle(
      backgroundColor: WidgetStatePropertyAll(_grey800),
      elevation: WidgetStatePropertyAll(8),
      shadowColor: WidgetStatePropertyAll(Color(0x3300D4FF)),
      surfaceTintColor: WidgetStatePropertyAll(_grey800),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _black,
      colorScheme: const ColorScheme.dark(
        primary: _neon,
        secondary: _neonBright,
        tertiary: _neonDim,
        surface: _grey850,
        surfaceContainerHighest: _grey800,
        error: _neonBright,
        onPrimary: _black,
        onSecondary: _black,
        onTertiary: _black,
        onSurface: _textLight,
        onError: _black,
        outline: _grey600,
        outlineVariant: _grey700,
      ),
      dividerColor: _grey700,
      shadowColor: _neon.withValues(alpha: 0.10),

      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.outfit(
          color: _textLight,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.outfit(
          color: _textLight,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(color: _textLight),
        bodyMedium: GoogleFonts.inter(color: _textMuted),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _neon,
          foregroundColor: _black,
          elevation: 4,
          shadowColor: _neon.withValues(alpha: 0.25),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: _neon, width: 1),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _grey800,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _grey700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _grey700, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _neon, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _neonBright, width: 1),
        ),
        labelStyle: GoogleFonts.inter(color: _textMuted),
        hintStyle: GoogleFonts.inter(color: _textMuted.withValues(alpha: 0.7)),
      ),

      cardTheme: CardThemeData(
        color: _grey800,
        elevation: 2,
        shadowColor: _neon.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _grey700, width: 0.5),
        ),
      ),

      iconTheme: const IconThemeData(color: _neon),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: GoogleFonts.inter(color: _textLight, fontSize: 15),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        menuStyle: const MenuStyle(
          backgroundColor: WidgetStatePropertyAll(_grey800),
          elevation: WidgetStatePropertyAll(8),
          shadowColor: WidgetStatePropertyAll(Color(0x3300D4FF)),
          surfaceTintColor: WidgetStatePropertyAll(_grey800),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: _grey800,
        elevation: 8,
        shadowColor: _neon.withValues(alpha: 0.2),
        surfaceTintColor: _grey800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(
          color: _textLight,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      menuBarTheme: const MenuBarThemeData(style: menuStyle),
      menuTheme: MenuThemeData(style: menuStyle),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(_textLight),
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? _neon : _grey600,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? _neon.withValues(alpha: 0.4)
              : _grey700,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TEMA CLARO (estandar, listo para futuro)
  // ═══════════════════════════════════════════════════════════════
  static ThemeData get lightTheme {
    const primary = Color(0xFF1A73E8);
    const surface = Color(0xFFF8F9FA);
    const card = Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: Color(0xFF4A90D9),
        surface: surface,
        error: Color(0xFFE53935),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF202124),
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.outfit(
          color: const Color(0xFF202124),
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.outfit(
          color: const Color(0xFF202124),
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(color: const Color(0xFF202124)),
        bodyMedium: GoogleFonts.inter(color: const Color(0xFF5F6368)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1),
        ),
        labelStyle: GoogleFonts.inter(color: const Color(0xFF5F6368)),
        hintStyle: GoogleFonts.inter(
          color: const Color(0xFF5F6368).withValues(alpha: 0.7),
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
