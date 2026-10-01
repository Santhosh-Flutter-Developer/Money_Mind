import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF1B7F4B);
  static const primaryDark = Color(0xFF0E5C34);
  static const income = Color(0xFF1B9E5A);
  static const expense = Color(0xFFE5484D);
  static const lending = Color(0xFF3E63DD);
  static const interest = Color(0xFF8E4EC6);
  static const savings = Color(0xFF12A594);
  static const warning = Color(0xFFF5A524);
  static const transfer = Color(0xFF6B7280);
}

class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: b);
    final isLight = b == Brightness.light;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight ? const Color(0xFFF4F7F5) : const Color(0xFF0F1512),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isLight ? const Color(0xFFF4F7F5) : const Color(0xFF0F1512),
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: AppColors.primary.withOpacity(0.15),
      ),
    );
  }
}
