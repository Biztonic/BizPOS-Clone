import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../utils/theme.dart';

class ThemeState {
  final UIStyle uiStyle;
  final bool isDarkMode;
  final AppColorTheme currentTheme;
  final int? customThemeColor;

  ThemeState({
    required this.uiStyle,
    required this.isDarkMode,
    required this.currentTheme,
    this.customThemeColor,
  });

  ThemeState copyWith({
    UIStyle? uiStyle,
    bool? isDarkMode,
    AppColorTheme? currentTheme,
    int? customThemeColor,
  }) {
    return ThemeState(
      uiStyle: uiStyle ?? this.uiStyle,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      currentTheme: currentTheme ?? this.currentTheme,
      customThemeColor: customThemeColor ?? this.customThemeColor,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(ThemeState(
    uiStyle: UIStyle.standard,
    isDarkMode: false,
    currentTheme: AppColorTheme.biztonicBlue,
  )) {
    _loadFromHive();
  }

  void _loadFromHive() {
    final box = Hive.box('settings');
    final uiStyleIndex = box.get('uiStyle', defaultValue: UIStyle.standard.index);
    final isDarkMode = box.get('isDarkMode', defaultValue: false);
    final currentThemeIndex = box.get('currentTheme', defaultValue: AppColorTheme.biztonicBlue.index);
    final customColor = box.get('customThemeColor');

    state = state.copyWith(
      uiStyle: UIStyle.values[uiStyleIndex],
      isDarkMode: isDarkMode,
      currentTheme: AppColorTheme.values[currentThemeIndex],
      customThemeColor: customColor,
    );
  }

  void setUIStyle(UIStyle style) {
    state = state.copyWith(uiStyle: style);
    Hive.box('settings').put('uiStyle', style.index);
  }

  void setAppTheme(AppColorTheme theme) {
    state = state.copyWith(currentTheme: theme);
    Hive.box('settings').put('currentTheme', theme.index);
  }

  void toggleTheme() {
    final newMode = !state.isDarkMode;
    state = state.copyWith(isDarkMode: newMode);
    Hive.box('settings').put('isDarkMode', newMode);
  }

  void setCustomThemeColor(Color color) {
    state = state.copyWith(customThemeColor: color.value);
    Hive.box('settings').put('customThemeColor', color.value);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});
