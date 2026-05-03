import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  // Keys for storage
  static const _hiveKeyName = 'hive_encryption_key';
  static const _sqlKeyName = 'sql_encryption_key';

  /// Get or Create 32-byte Hive Encryption Key (as List<int>)
  Future<List<int>> getHiveKey() async {
    final prefs = await SharedPreferences.getInstance();
    String? keyStr = prefs.getString(_hiveKeyName);
    
    if (keyStr == null) {

      // Use local random generation instead of Hive.generateSecureKey() to avoid dependency
      final newKey = _generateRandomKey(32);
      await prefs.setString(_hiveKeyName, base64UrlEncode(newKey));
      return newKey;
    } else {
      return base64Url.decode(keyStr);
    }
  }

  /// Get or Create SQL Encryption Key (String password)
  Future<String> getSqlKey() async {
    final prefs = await SharedPreferences.getInstance();
    String? keyStr = prefs.getString(_sqlKeyName);
    
    if (keyStr == null) {

      // Generate a strong random password
      final newKeyBytes = _generateRandomKey(32);
      final newKeyStr = base64UrlEncode(newKeyBytes);
      await prefs.setString(_sqlKeyName, newKeyStr);
      return newKeyStr;
    }
    return keyStr;
  }

  List<int> _generateRandomKey(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (i) => random.nextInt(256));
  }
}
