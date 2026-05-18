import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary brand color - Upgraded to modern sleek Indigo
  static const Color primary = Color(0xFF6366F1); // Modern Indigo 500
  static const Color primaryLight = Color(0xFF818CF8); // Indigo 400
  static const Color primaryDark = Color(0xFF4338CA); // Indigo 700
  
  // Secondary / Accents
  static const Color secondary = Color(0xFF94A3B8); // Slate 400
  
  // Semantic Colors - Softened for a premium feel
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color info = Color(0xFF3B82F6); // Blue 500

  // Backgrounds & Surfaces (Light) - Soft Slate backgrounds
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Color(0xFFFFFFFF);
  
  // Backgrounds & Surfaces (Dark) - Deep Slate
  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800

  // Text
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryLight = Color(0xFF475569); // Slate 600
  static const Color textHintLight = Color(0xFF94A3B8); // Slate 400

  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
  static const Color textHintDark = Color(0xFF475569); // Slate 600

  // Borders
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200
  static const Color borderDark = Color(0xFF334155); // Slate 700

  // Utility
  static const Color primaryLightGrey = Color(0xFFF1F5F9); // Slate 100
  static const Color primaryLightAccent = Color(0xFFE0E7FF); // Indigo 100

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
        ? const Color(0xFFF1F5F9) // Slate 100
        : const Color(0xFF334155); // Slate 700
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
        : const Color(0xFF64748B); // Slate 500 for dark mode
  }

  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
  static Color get transparent => Colors.transparent;

  static LinearGradient authGradient(BuildContext context) {
    final dark = isDark(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? [const Color(0xFF020617), const Color(0xFF0F172A), const Color(0xFF020617)] // Dark slate gradient
          : [const Color(0xFF6366F1), const Color(0xFF818CF8)], // Indigo gradient
    );
  }

  static Color outline(BuildContext context) {
    return isDark(context)
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);
  }
}
