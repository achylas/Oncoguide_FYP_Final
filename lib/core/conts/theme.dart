import 'package:flutter/material.dart';

import 'colors.dart';

class AppTheme {
  // Light Theme (already defined)
  static final lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF7F9FC),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF6A7FDB), // calm medical blue
      brightness: Brightness.light,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2D3436),
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        color: Color(0xFF636E72),
      ),
    ),
  );

  // Dark Theme
  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212), // dark base
    cardColor: const Color(0xFF1E1E2C), // dark card background
    canvasColor: const Color(0xFF1E1E2C),
    dividerColor: const Color(0xFF373737),
    shadowColor: const Color(0xFF000000).withOpacity(0.5),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E2C),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        color: Color(0xFFB0B0B0),
      ),
    ),
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary, // navy
      onPrimary: Colors.white,
      secondary: AppColors.accent, // coral pop
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      background: const Color(0xFF121212),
      onBackground: Colors.white,
      surface: const Color(0xFF1E1E2C),
      onSurface: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.accent),
        foregroundColor: AppColors.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    ),
  );
}
