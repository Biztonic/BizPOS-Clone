// ignore_for_file: deprecated_member_use, constant_identifier_names
import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF29ABE2); // Vibrant Blue
  static const Color secondaryColor = Color(0xFFF5F5F5); // Light Gray
  static const Color accentColor = Color(0xFF90EE90); // Soft Green
  static const Color errorColor = Color(0xFFFF4C4C); // Red

  static ThemeData getTheme(AppColorTheme theme, bool isDark, {Color? customSeed}) {
    final seedColor = customSeed ?? themeColors[theme]!;
    
    if (isDark) {
      return ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          primary: seedColor,
          secondary: seedColor.withValues(alpha: 0.8),
          background: const Color(0xFF1E1E1E),
          error: errorColor,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Roboto'),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF1E1E1E),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF2C2C2C),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: seedColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: seedColor, width: 2),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      );
    } else {
      return ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          primary: seedColor,
          secondary: seedColor.withValues(alpha: 0.8),
          background: secondaryColor,
          error: errorColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: secondaryColor,
        textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Roboto'),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: false,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: seedColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: seedColor, width: 2),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      );
    }
  }

  // Deprecated: Use getTheme instead
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
  AppColorTheme.blue: Color(0xFF29ABE2),
  AppColorTheme.green: Color(0xFF2E7D32),
  AppColorTheme.red: Color(0xFFD32F2F),
  AppColorTheme.purple: Color(0xFF7B1FA2),
  AppColorTheme.orange: Color(0xFFF57C00),
};

enum UIStyle {
  standard,
  car_dashboard,
}
