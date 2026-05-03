import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  // Assuming Google Fonts "Inter" or similar professional sans-serif
  static const String fontFamily = 'Inter';

  // Display
  static const TextStyle displayLarge = TextStyle(fontSize: 57, fontWeight: FontWeight.bold, letterSpacing: -0.25);
  static const TextStyle displayMedium = TextStyle(fontSize: 45, fontWeight: FontWeight.bold);
  static const TextStyle displaySmall = TextStyle(fontSize: 36, fontWeight: FontWeight.bold);

  // Headlines
  static const TextStyle headlineLarge = TextStyle(fontSize: 32, fontWeight: FontWeight.w700);
  static const TextStyle headlineMedium = TextStyle(fontSize: 28, fontWeight: FontWeight.w600);
  static const TextStyle headlineSmall = TextStyle(fontSize: 24, fontWeight: FontWeight.w600);

  // Titles
  static const TextStyle titleLarge = TextStyle(fontSize: 22, fontWeight: FontWeight.w600);
  static const TextStyle titleMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.15);
  static const TextStyle titleSmall = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1);

  // Body
  static const TextStyle bodyLarge = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5);
  static const TextStyle bodyMedium = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25);
  static const TextStyle bodySmall = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4);

  // Labels (for buttons, tiny metadata)
  static const TextStyle labelLarge = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1);
  static const TextStyle labelMedium = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5);
  static const TextStyle labelSmall = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5);
}
