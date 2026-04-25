import 'dart:convert';
import 'package:crypto/crypto.dart';

class PinUtils {
  /// Hashes a 4-digit PIN using SHA-256 with the User ID as a salt.
  /// Format: SHA256(pin + uid)
  static String hashPin(String pin, String uid) {
    if (pin.isEmpty || uid.isEmpty) return '';
    final bytes = utf8.encode(pin + uid);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies if a plain-text PIN matches the stored hash.
  static bool verifyPin(String inputPin, String uid, String storedHash) {
    final computedHash = hashPin(inputPin, uid);
    return computedHash == storedHash;
  }
}
