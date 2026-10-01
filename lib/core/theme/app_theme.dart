import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF6A5AE0); // violet
  static const primaryDark = Color(0xFF4B3FC4);
  static const income = Color(0xFF12B886);
  static const expense = Color(0xFFFF5470);
  static const lending = Color(0xFF3B82F6);
  static const interest = Color(0xFFA855F7);
  static const savings = Color(0xFF14B8A6);
  static const warning = Color(0xFFF59E0B);
  static const transfer = Color(0xFF64748B);
  static const pink = Color(0xFFEC4899);
}

/// Two-stop gradients used across cards, buttons and icons.
class AppGradients {
  static const brand = LinearGradient(colors: [Color(0xFF6A5AE0), Color(0xFF3B82F6)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const sunset = LinearGradient(colors: [Color(0xFFFF6A88), Color(0xFFFF9A44)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const mint = LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const ocean = LinearGradient(colors: [Color(0xFF2193B0), Color(0xFF6DD5ED)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const grape = LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFFDA22FF)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const teal = LinearGradient(colors: [Color(0xFF00B09B), Color(0xFF6EE7B7)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const rose = LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF8A65)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const gold = LinearGradient(colors: [Color(0xFFF7971E), Color(0xFFFFD200)], begin: Alignment.topLeft, end: Alignment.bottomRight);

  /// Soft two-tone gradient built from any single colour.
  static LinearGradient of(Color c) => LinearGradient(
        colors: [c, Color.lerp(c, Colors.white, 0.28)!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isLight = b == Brightness.light;
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: b).copyWith(
      primary: AppColors.primary,
      surface: isLight ? Colors.white : const Color(0xFF1A1B2E),
    );
    final base = ThemeData(brightness: b, useMaterial3: true, colorScheme: scheme);
    final bg = isLight ? const Color(0xFFF4F5FB) : const Color(0xFF0E0F1A);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme),
      primaryTextTheme: GoogleFonts.poppinsTextTheme(base.primaryTextTheme),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: bg,
        foregroundColor: scheme.onSurface,
        titleTextStyle: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: AppColors.primary.withOpacity(0.16),
        checkmarkColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      navigationBarTheme: NavigationBarThemeData(indicatorColor: AppColors.primary.withOpacity(0.15)),
    );
  }
}
