import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta de colores Premium definida en AI_CONTEXT.md
  static const Color marbleWhite = Color(0xFFF0F0F0);
  static const Color marbleLight = Color(0xFFE8E8E8);
  static const Color goldAccent = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFFC5A059);
  static const Color grayNeutral = Color(0xFF808080);
  static const Color grayDark = Color(0xFF4A4A4A);
  static const Color woodWarm = Color(0xFF8B5A2B);
  static const Color woodDark = Color(0xFFA0522D);
  static const Color forestGreen = Color(0xFF228B22);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: marbleWhite,
      colorScheme: ColorScheme.light(
        primary: goldAccent,
        secondary: woodWarm,
        surface: marbleLight,
        error: Colors.redAccent,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: grayDark,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.outfit(
          color: grayDark,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: GoogleFonts.outfit(
          color: grayDark,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(
          color: grayDark,
        ),
        bodyMedium: GoogleFonts.inter(
          color: grayNeutral,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: goldAccent,
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
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: marbleLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: goldAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.redAccent, width: 1),
        ),
        labelStyle: GoogleFonts.inter(color: grayNeutral),
        hintStyle: GoogleFonts.inter(color: grayNeutral.withValues(alpha: 0.7)),
      ),
    );
  }
}
