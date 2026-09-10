import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const navy = Color(0xFF16324F);
  static const ink = Color(0xFF1B1F23);
  static const slate = Color(0xFF5B6B7A);
  static const chalk = Color(0xFFF5F4F0);
  static const amber = Color(0xFFE8A33D);
  static const green = Color(0xFF3A7D5C);
  static const rust = Color(0xFFB0492E);
  static const white = Color(0xFFFFFFFF);
  static const line = Color(0x335B6B7A);
}

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final textTheme = GoogleFonts.ibmPlexSansTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.archivo(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.navy),
      displayMedium: GoogleFonts.archivo(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.navy),
      titleLarge: GoogleFonts.archivo(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.navy),
      titleMedium: GoogleFonts.ibmPlexSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
      bodyLarge: GoogleFonts.ibmPlexSans(fontSize: 16, color: AppColors.ink),
      bodyMedium: GoogleFonts.ibmPlexSans(fontSize: 14, color: AppColors.ink),
      labelLarge: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w600),
      labelSmall: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.chalk,
      colorScheme: const ColorScheme.light(
        primary: AppColors.navy,
        onPrimary: AppColors.white,
        secondary: AppColors.slate,
        onSecondary: AppColors.white,
        surface: AppColors.chalk,
        onSurface: AppColors.ink,
        error: AppColors.rust,
        onError: AppColors.white,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.chalk,
        foregroundColor: AppColors.navy,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.archivo(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy),
      ),
      cardTheme: CardThemeData(
        color: AppColors.chalk,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.navy, width: 1.4),
        ),
        labelStyle: GoogleFonts.ibmPlexSans(color: AppColors.slate),
        hintStyle: GoogleFonts.ibmPlexSans(color: AppColors.slate),
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: AppColors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          minimumSize: const Size(0, 46),
          side: const BorderSide(color: AppColors.navy),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.white,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        labelStyle: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.navy.withValues(alpha: 0.12),
        labelTextStyle: WidgetStatePropertyAll(GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  static TextStyle get dataStyle => GoogleFonts.ibmPlexMono(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.navy,
      );

  static TextStyle get eyebrowStyle => GoogleFonts.ibmPlexSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppColors.slate,
      );
}
