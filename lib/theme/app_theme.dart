import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const deepPurple = Color(0xFF2A1B3D);
  static const purpleAccent = Color(0xFF3B2755);
  static const beige = Color(0xFFD9CBB0);
  static const offWhite = Color(0xFFF5F3EF);
  static const midGrey = Color(0xFF8A8580);
  static const nearBlack = Color(0xFF161616);
}

class AppTheme {
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.jetBrainsMonoTextTheme(ThemeData.dark().textTheme);
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.deepPurple,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.beige,
        surface: AppColors.purpleAccent,
        onSurface: AppColors.offWhite,
        onPrimary: AppColors.nearBlack,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.offWhite,
      ),
      textTheme: baseTextTheme.copyWith(
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: AppColors.offWhite),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: AppColors.offWhite),
        bodySmall: baseTextTheme.bodySmall?.copyWith(color: AppColors.midGrey),
        titleLarge: baseTextTheme.titleLarge?.copyWith(color: AppColors.offWhite),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.beige,
          foregroundColor: AppColors.nearBlack,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
