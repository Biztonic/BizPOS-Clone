// ignore_for_file: deprecated_member_use, constant_identifier_names
import 'package:flutter/material.dart';
import '../core/design/tokens/app_colors.dart';
import '../core/design/tokens/app_radius.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';

class AppTheme {
  static ThemeData getTheme(AppColorTheme theme, bool isDark, {Color? customSeed}) {
    final seedColor = customSeed ?? themeColors[theme]!;
    final brightness = isDark ? Brightness.dark : Brightness.light;
    
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      primary: seedColor,
      onPrimary: Colors.white,
      secondary: seedColor.withValues(alpha: 0.8),
      onSecondary: Colors.white,
      surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      onSurface: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      error: AppColors.error,
      onError: Colors.white,
      brightness: brightness,
    );

    final baseTextTheme = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final textTheme = baseTextTheme.copyWith(
      displayLarge: AppTypography.displayLarge,
      displayMedium: AppTypography.displayMedium,
      displaySmall: AppTypography.displaySmall,
      headlineLarge: AppTypography.headlineLarge,
      headlineMedium: AppTypography.headlineMedium,
      headlineSmall: AppTypography.headlineSmall,
      titleLarge: AppTypography.titleLarge,
      titleMedium: AppTypography.titleMedium,
      titleSmall: AppTypography.titleSmall,
      bodyLarge: AppTypography.bodyLarge,
      bodyMedium: AppTypography.bodyMedium,
      bodySmall: AppTypography.bodySmall,
      labelLarge: AppTypography.labelLarge,
      labelMedium: AppTypography.labelMedium,
      labelSmall: AppTypography.labelSmall,
    ).apply(
      fontFamily: AppTypography.fontFamily,
      displayColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      bodyColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      colorScheme: colorScheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 1,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seedColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: seedColor,
          side: BorderSide(color: seedColor),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceDark : Colors.white,
        border: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: seedColor, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        labelStyle: AppTypography.bodyMedium,
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: isDark ? AppColors.textHintDark : AppColors.textHintLight,
        ),
      ),
      iconTheme: IconThemeData(
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        size: 24,
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.borderDark : AppColors.borderLight,
        thickness: 1,
        space: AppSpacing.lg,
      ),
    );
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

