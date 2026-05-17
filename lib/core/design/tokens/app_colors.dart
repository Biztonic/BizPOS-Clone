import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary brand color
  static const Color primary = Color(0xFF0F62FE); // Modern Enterprise Blue
  static const Color primaryLight = Color(0xFF4589FF);
  static const Color primaryDark = Color(0xFF0043CE);
  
  // Secondary / Accents
  static const Color secondary = Color(0xFF6F6F6F);
  
  // Semantic Colors
  static const Color success = Color(0xFF24A148);
  static const Color warning = Color(0xFFF1C21B);
  static const Color error = Color(0xFFDA1E28);
  static const Color info = Color(0xFF0043CE);

  // Backgrounds & Surfaces (Light)
  static const Color backgroundLight = Color(0xFFF4F4F4);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  
  // Backgrounds & Surfaces (Dark)
  static const Color backgroundDark = Color(0xFF161616);
  static const Color surfaceDark = Color(0xFF262626);

  // Text
  static const Color textPrimaryLight = Color(0xFF161616);
  static const Color textSecondaryLight = Color(0xFF525252);
  static const Color textHintLight = Color(0xFFA8A8A8);

  static const Color textPrimaryDark = Color(0xFFF4F4F4);
  static const Color textSecondaryDark = Color(0xFFC6C6C6);
  static const Color textHintDark = Color(0xFF6F6F6F);

  // Borders
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFF393939);

  // Utility
  static const Color primaryLightGrey = Color(0xFFF4F4F4);
  static const Color primaryLightAccent = Color(0xFFD0E2FF); // Light accent for highlights

  /// Adaptive background based on current theme brightness
  static Color background(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? backgroundLight
        : backgroundDark;
  }

  /// Adaptive surface based on current theme brightness
  static Color surface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? surfaceLight
        : surfaceDark;
  }

  static Color surfaceVariant(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFF1F1F1)
        : const Color(0xFF323232);
  }

  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? textPrimaryLight
        : textPrimaryDark;
  }

  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? textSecondaryLight
        : textSecondaryDark;
  }

  static Color textHint(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? textHintLight
        : textHintDark;
  }

  static Color border(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? borderLight
        : borderDark;
  }

  static Color adaptivePrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? primary
        : primaryLight;
  }

  static Color adaptiveSuccess(BuildContext context) {
    return success;
  }

  static Color adaptiveWarning(BuildContext context) {
    return warning;
  }

  static Color adaptiveError(BuildContext context) {
    return error;
  }

  static Color adaptiveInfo(BuildContext context) {
    return info;
  }

  static Color adaptiveSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? secondary
        : const Color(0xFFA8A8A8); // Lighter grey for dark mode
  }

  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
  static Color get transparent => Colors.transparent;

  static LinearGradient authGradient(BuildContext context) {
    final dark = isDark(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? [const Color(0xFF0D1B2A), const Color(0xFF1B2838), const Color(0xFF0D1B2A)]
          : [const Color(0xFF0F62FE), const Color(0xFF4589FF)],
    );
  }

  static Color outline(BuildContext context) {
    return isDark(context)
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);
  }
}
