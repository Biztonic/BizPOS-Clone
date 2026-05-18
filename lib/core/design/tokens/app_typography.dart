import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  // Assuming Google Fonts "Inter" or similar professional sans-serif
  static const String fontFamily = 'Inter';

  // Display - Tighter letter spacing for a premium bold look
  static const TextStyle displayLarge = TextStyle(fontSize: 57, fontWeight: FontWeight.bold, letterSpacing: -1.0);
  static const TextStyle displayMedium = TextStyle(fontSize: 45, fontWeight: FontWeight.bold, letterSpacing: -0.75);
  static const TextStyle displaySmall = TextStyle(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.5);

  // Headlines
  static const TextStyle headlineLarge = TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static const TextStyle headlineMedium = TextStyle(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.25);
  static const TextStyle headlineSmall = TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0);

  // Aliases for easier migration
  static const TextStyle h2 = headlineMedium;
  static const TextStyle h3 = headlineSmall;
  static const TextStyle h4 = titleLarge;

  // Helper Methods for direct Widget creation
  static Text h2Text(String data, {Color? color, TextAlign? textAlign}) => 
      Text(data, style: h2.copyWith(color: color), textAlign: textAlign);
  
  static Text h3Text(String data, {Color? color, TextAlign? textAlign}) => 
      Text(data, style: h3.copyWith(color: color), textAlign: textAlign);

  static Text h4Text(String data, {Color? color, TextAlign? textAlign}) => 
      Text(data, style: h4.copyWith(color: color), textAlign: textAlign);

  // Titles
  static const TextStyle titleLarge = TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 0);
  static const TextStyle titleMedium = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.1);
  static const TextStyle titleSmall = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1);

  // Body - Slightly softened weights, higher readability
  static const TextStyle bodyLarge = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.25);
  static const TextStyle bodyMedium = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.2);
  static const TextStyle bodySmall = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.3);

  // Labels (for buttons, tiny metadata)
  static const TextStyle labelLarge = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1);
  static const TextStyle labelMedium = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2);
  static const TextStyle labelSmall = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3);
}
