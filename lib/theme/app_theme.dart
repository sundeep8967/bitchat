import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Instagram-style Clean Colors
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF0095F6); // Instagram Blue
  static const Color secondary = Color(0xFF262626); // Dark text
  static const Color accent = Color(0xFFED4956); // Instagram Pink/Red (like)
  static const Color textPrimary = Color(0xFF262626);
  static const Color textSecondary = Color(0xFF8E8E8E);
  static const Color divider = Color(0xFFDBDBDB);
  static const Color online = Color(0xFF00C853); // Green for online status

  // Gradients (Instagram-style gradient)
  static const LinearGradient instagramGradient = LinearGradient(
    colors: [
      Color(0xFFF58529), // Orange
      Color(0xFFDD2A7B), // Pink
      Color(0xFF8134AF), // Purple
      Color(0xFF515BD4), // Blue
    ],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient subtleGradient = LinearGradient(
    colors: [
      Color(0xFFF8F8F8),
      Color(0xFFFFFFFF),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: accent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: secondary),
        titleTextStyle: GoogleFonts.inter(
          color: secondary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelSmall: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      iconTheme: const IconThemeData(
        color: secondary,
      ),
      dividerColor: divider,
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: divider, width: 0.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: secondary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
  
  // Keep dark theme for reference/toggle
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF000000),
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: Colors.white,
        surface: Color(0xFF121212),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 16,
        ),
        bodyMedium: GoogleFonts.inter(
          color: Colors.white70,
          fontSize: 14,
        ),
      ),
    );
  }
}
