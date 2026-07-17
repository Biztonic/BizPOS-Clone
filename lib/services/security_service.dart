import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  static const _secureStorage = FlutterSecureStorage();
  static const _hiveKeyName = 'hive_encryption_key';
  static const _sqlKeyName = 'sql_encryption_key';

  /// Get or Create 32-byte Hive Encryption Key (as List<int>)
  Future<List<int>> getHiveKey() async {
    try {
      String? keyStr = await _secureStorage.read(key: _hiveKeyName);
      
      if (keyStr == null) {
        final newKey = _generateRandomKey(32);
        await _secureStorage.write(key: _hiveKeyName, value: base64UrlEncode(newKey));
        return newKey;
      } else {
        return base64Url.decode(keyStr);
      }
    } catch (e) {
      debugPrint('⚠️ SecurityService: Secure Storage read failed: $e. Generating fallback ephemeral key.');
      final fallbackKey = _generateRandomKey(32);
      return fallbackKey;
    }
  }

  /// Get or Create SQL Encryption Key (String password)
  Future<String> getSqlKey() async {
    try {
      String? keyStr = await _secureStorage.read(key: _sqlKeyName);
      
      if (keyStr == null) {
        final newKeyBytes = _generateRandomKey(32);
        final newKeyStr = base64UrlEncode(newKeyBytes);
        await _secureStorage.write(key: _sqlKeyName, value: newKeyStr);
        return newKeyStr;
      }
      return keyStr;
    } catch (e) {
      debugPrint('⚠️ SecurityService: Secure Storage read failed: $e. Generating fallback ephemeral SQL key.');
      final newKeyBytes = _generateRandomKey(32);
      return base64UrlEncode(newKeyBytes);
    }
  }

  List<int> _generateRandomKey(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (i) => random.nextInt(256));
  }
}
