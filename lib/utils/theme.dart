// ignore_for_file: deprecated_member_use, constant_identifier_names
import 'package:flutter/material.dart';
import '../core/design/tokens/app_colors.dart';
import '../core/design/tokens/app_radius.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';

class AppTheme {
  static ThemeData getTheme(AppColorTheme theme, bool isDark, {Color? customSeed}) {
    final seedColor = customSeed ?? themeColors[theme]!;
    
    if (isDark) {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.backgroundDark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          primary: seedColor,
          secondary: seedColor.withOpacity(0.8),
          surface: AppColors.surfaceDark,
          error: AppColors.error,
          brightness: Brightness.dark,
        ),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: AppTypography.fontFamily),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.surfaceDark,
          foregroundColor: AppColors.textPrimaryDark,
          elevation: 0,
          centerTitle: false,
        ),
        drawerTheme: DrawerThemeData(
          backgroundColor: AppColors.surfaceDark,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surfaceDark,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: seedColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceDark,
          border: OutlineInputBorder(
            borderRadius: AppRadius.borderMd,
            borderSide: const BorderSide(color: AppColors.borderDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.borderMd,
            borderSide: const BorderSide(color: AppColors.borderDark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.borderMd,
            borderSide: BorderSide(color: seedColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.borderMd,
            borderSide: const BorderSide(color: AppColors.error),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      );
    } else {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.backgroundLight,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          primary: seedColor,
          secondary: seedColor.withOpacity(0.8),
          surface: AppColors.surfaceLight,
          error: AppColors.error,
          brightness: Brightness.light,
        ),
        textTheme: ThemeData.light().textTheme.apply(fontFamily: AppTypography.fontFamily),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.surfaceLight,
          foregroundColor: AppColors.textPrimaryLight,
          elevation: 0,
          centerTitle: false,
        ),
        drawerTheme: DrawerThemeData(
          backgroundColor: AppColors.surfaceLight,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surfaceLight,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: seedColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceLight,
          border: OutlineInputBorder(
            borderRadius: AppRadius.borderMd,
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.borderMd,
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.borderMd,
            borderSide: BorderSide(color: seedColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.borderMd,
            borderSide: const BorderSide(color: AppColors.error),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      );
    }
  }

  static ThemeData get lightTheme => getTheme(AppColorTheme.blue, false);
  static ThemeData get darkTheme => getTheme(AppColorTheme.blue, true);
}

enum AppColorTheme {
  blue,
  green,
  red,
  purple,
  orange,
}

const Map<AppColorTheme, Color> themeColors = {
  AppColorTheme.blue: Color(0xFF0F62FE), // Updated to Enterprise Blue
  AppColorTheme.green: Color(0xFF24A148),
  AppColorTheme.red: Color(0xFFDA1E28),
  AppColorTheme.purple: Color(0xFF8A3FFC),
  AppColorTheme.orange: Color(0xFFFF832B),
};

enum UIStyle {
  standard,
  car_dashboard,
}

