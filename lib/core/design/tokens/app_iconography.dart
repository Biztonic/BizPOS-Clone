import 'package:flutter/material.dart';

/// Centralized icon size and styling tokens.
/// Ensures all icons across the application are visually consistent.
///
/// USAGE: Replace hardcoded icon sizes like `size: 24` with `AppIconography.md`.
class AppIconography {
  AppIconography._();

  // --- Standard Icon Sizes ---
  static const double xxs = 12.0;
  static const double xs = 14.0;
  static const double sm = 16.0;
  static const double md = 20.0;
  static const double lg = 24.0;
  static const double xl = 28.0;
  static const double xxl = 32.0;
  static const double hero = 48.0;

  // --- Icon Container Sizes (for icon backgrounds) ---
  static const double containerSm = 32.0;
  static const double containerMd = 40.0;
  static const double containerLg = 48.0;
  static const double containerXl = 56.0;

  // --- Icon Container Padding ---
  static const double containerPaddingSm = 6.0;
  static const double containerPaddingMd = 8.0;
  static const double containerPaddingLg = 12.0;

  /// Builds a standard icon container with a tinted background.
  /// Used for settings items, sidebar items, dashboard cards, etc.
  static Widget iconContainer({
    required IconData icon,
    required Color color,
    double size = md,
    double containerSize = containerMd,
    double padding = containerPaddingMd,
    double borderRadius = 10.0,
  }) {
    return Container(
      width: containerSize,
      height: containerSize,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}
