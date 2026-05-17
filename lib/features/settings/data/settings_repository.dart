import 'package:hive_flutter/hive_flutter.dart';

class SettingsRepository {
  static const String _settingsBoxName = 'settings';

  Future<Box> _getBox() async {
    if (!Hive.isBoxOpen(_settingsBoxName)) {
      return await Hive.openBox(_settingsBoxName);
    }
    return Hive.box(_settingsBoxName);
  }

  Future<void> saveDarkMode(bool isDarkMode) async {
    final box = await _getBox();
    await box.put('darkMode', isDarkMode);
  }

  Future<void> saveTheme(int themeIndex) async {
    final box = await _getBox();
    await box.put('theme', themeIndex);
  }

  Future<void> saveUIStyle(int styleIndex) async {
    final box = await _getBox();
    await box.put('uiStyle', styleIndex);
  }

  Future<void> saveKioskMode(bool enabled) async {
    final box = await _getBox();
    await box.put('kiosk_mode', enabled);
  }

  Future<void> saveAutoBackup(bool enabled) async {
    final box = await _getBox();
    await box.put('autoBackupEnabled', enabled);
  }

  Future<void> saveBackupFrequency(String frequency) async {
    final box = await _getBox();
    await box.put('backupFrequency', frequency);
  }

  Future<void> saveBackupTime(int hour, int minute) async {
    final box = await _getBox();
    await box.put('backupTimeHour', hour);
    await box.put('backupTimeMinute', minute);
  }

  Future<Map<String, dynamic>> loadSettings() async {
    final box = await _getBox();
    return {
      'darkMode': box.get('darkMode', defaultValue: false),
      'theme': box.get('theme', defaultValue: 0),
      'uiStyle': box.get('uiStyle', defaultValue: 0),
      'kiosk_mode': box.get('kiosk_mode', defaultValue: false),
      'autoBackupEnabled': box.get('autoBackupEnabled', defaultValue: false),
      'backupFrequency': box.get('backupFrequency', defaultValue: 'Weekly'),
      'backupTimeHour': box.get('backupTimeHour', defaultValue: 2),
      'backupTimeMinute': box.get('backupTimeMinute', defaultValue: 0),
    };
  }
}
