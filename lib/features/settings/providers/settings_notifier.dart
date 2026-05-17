import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:biztonic_pos/utils/theme.dart';
import 'package:biztonic_pos/features/settings/data/settings_repository.dart';

part 'settings_notifier.g.dart';

class SettingsState {
  final bool isDarkMode;
  final AppColorTheme currentTheme;
  final UIStyle uiStyle;
  final bool kioskMode;
  final bool autoBackupEnabled;
  final String backupFrequency;
  final int backupTimeHour;
  final int backupTimeMinute;

  SettingsState({
    required this.isDarkMode,
    required this.currentTheme,
    required this.uiStyle,
    this.kioskMode = false,
    this.autoBackupEnabled = false,
    this.backupFrequency = 'Weekly',
    this.backupTimeHour = 2,
    this.backupTimeMinute = 0,
  });

  SettingsState copyWith({
    bool? isDarkMode,
    AppColorTheme? currentTheme,
    UIStyle? uiStyle,
    bool? kioskMode,
    bool? autoBackupEnabled,
    String? backupFrequency,
    int? backupTimeHour,
    int? backupTimeMinute,
  }) {
    return SettingsState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      currentTheme: currentTheme ?? this.currentTheme,
      uiStyle: uiStyle ?? this.uiStyle,
      kioskMode: kioskMode ?? this.kioskMode,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      backupFrequency: backupFrequency ?? this.backupFrequency,
      backupTimeHour: backupTimeHour ?? this.backupTimeHour,
      backupTimeMinute: backupTimeMinute ?? this.backupTimeMinute,
    );
  }
}

@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  final SettingsRepository _repository = SettingsRepository();

  @override
  SettingsState build() {
    // Start with defaults, will be updated by loadSettings
    return SettingsState(
      isDarkMode: false,
      currentTheme: AppColorTheme.blue,
      uiStyle: UIStyle.standard,
    );
  }

  Future<void> loadSettings() async {
    final settings = await _repository.loadSettings();
    
    final themeIdx = settings['theme'] as int;
    final styleIdx = settings['uiStyle'] as int;
    
    state = state.copyWith(
      isDarkMode: settings['darkMode'] as bool,
      currentTheme: themeIdx < AppColorTheme.values.length 
          ? AppColorTheme.values[themeIdx] 
          : AppColorTheme.blue,
      uiStyle: styleIdx < UIStyle.values.length
          ? UIStyle.values[styleIdx]
          : UIStyle.standard,
      kioskMode: settings['kiosk_mode'] as bool,
      autoBackupEnabled: settings['autoBackupEnabled'] as bool,
      backupFrequency: settings['backupFrequency'] as String,
      backupTimeHour: settings['backupTimeHour'] as int,
      backupTimeMinute: settings['backupTimeMinute'] as int,
    );
  }

  Future<void> toggleDarkMode() async {
    final newValue = !state.isDarkMode;
    state = state.copyWith(isDarkMode: newValue);
    await _repository.saveDarkMode(newValue);
  }

  Future<void> setTheme(AppColorTheme theme) async {
    state = state.copyWith(currentTheme: theme);
    await _repository.saveTheme(theme.index);
  }

  Future<void> setUIStyle(UIStyle style) async {
    state = state.copyWith(uiStyle: style);
    await _repository.saveUIStyle(style.index);
  }

  Future<void> toggleKioskMode() async {
    final newValue = !state.kioskMode;
    state = state.copyWith(kioskMode: newValue);
    await _repository.saveKioskMode(newValue);
  }

  Future<void> toggleAutoBackup(bool enabled) async {
    state = state.copyWith(autoBackupEnabled: enabled);
    await _repository.saveAutoBackup(enabled);
  }

  Future<void> setBackupFrequency(String frequency) async {
    state = state.copyWith(backupFrequency: frequency);
    await _repository.saveBackupFrequency(frequency);
  }

  Future<void> setBackupTime(int hour, int minute) async {
    state = state.copyWith(backupTimeHour: hour, backupTimeMinute: minute);
    await _repository.saveBackupTime(hour, minute);
  }
}
