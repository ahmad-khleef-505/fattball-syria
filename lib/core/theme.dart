import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const TextDirection textDirection = TextDirection.rtl;
  static const Color pitchGreen = Color(0xFF1B5E20);
  static const Color neonGreen = Color(0xFF00E676);
  static const Color sportsOrange = Color(0xFFFF9800);
  static const Color _lightSurface = Color(0xFFF4F7F2);

  static final ThemeData lightTheme = _theme(Brightness.light);

  static final ThemeData darkTheme = _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final colors = ColorScheme.fromSeed(
      seedColor: pitchGreen,
      brightness: brightness,
    ).copyWith(
      primary: pitchGreen,
      secondary: neonGreen,
      tertiary: sportsOrange,
      surface: isLight ? Colors.white : const Color(0xFF171D18),
    );
    final baseTextTheme = ThemeData(brightness: brightness).textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: isLight ? _lightSurface : const Color(0xFF101511),
      textTheme: GoogleFonts.tajawalTextTheme(baseTextTheme).copyWith(
        headlineLarge: GoogleFonts.tajawal(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.tajawal(fontWeight: FontWeight.w800),
        titleLarge: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
        titleMedium: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: isLight ? _lightSurface : const Color(0xFF101511),
        foregroundColor: colors.onSurface,
        titleTextStyle: GoogleFonts.tajawal(
          color: colors.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: isLight ? 1 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: pitchGreen, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: pitchGreen,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: neonGreen.withValues(alpha: 0.28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: pitchGreen,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: neonGreen.withValues(alpha: 0.28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight
            ? const Color(0xE61B2A1D)
            : const Color(0xE6F3F7F2),
        contentTextStyle: GoogleFonts.tajawal(
          color: isLight ? Colors.white : const Color(0xFF172019),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: pitchGreen,
        unselectedItemColor: colors.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
        selectedLabelStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
      ),
    );
  }
}
