import 'package:flutter/material.dart';

class JuiceTheme {
  static const Color primaryTangerine = Color(0xFFFF6B35);
  static const Color secondaryCitrus = Color(0xFFFFD23F);
  static const Color accentPeach = Color(0xFFFF6B9D);
  static const Color juiceGreen = Color(0xFF4CAF50);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF2D2D2D);

  static final LinearGradient primaryGradient = const LinearGradient(
    colors: [primaryTangerine, secondaryCitrus],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTangerine,
        primary: primaryTangerine,
        secondary: secondaryCitrus,
        tertiary: accentPeach,
        surface: backgroundWhite,
        onPrimary: Colors.white,
        onSecondary: textDark,
      ),
      scaffoldBackgroundColor: backgroundWhite,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textDark,
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
        headlineMedium: TextStyle(
          color: textDark,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
        bodyLarge: TextStyle(
          color: textDark,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: textDark,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTangerine,
          foregroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        shadowColor: primaryTangerine.withOpacity(0.2),
      ),
    );
  }
}
