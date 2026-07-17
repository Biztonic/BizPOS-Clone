import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class BackupEncryption {
  /// Encrypts the [plainText] using a key derived from [password].
  /// Returns a string formatted as "salt_base64.iv_base64.encrypted_base64"
  static String encrypt(String plainText, String password) {
    // 1. Generate a random 16-byte salt
    final rand = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => rand.nextInt(256));
    final saltBase64 = base64UrlEncode(saltBytes);

    // 2. Derive 32-byte key from password + salt using SHA-256
    final keyBytes = sha256.convert(utf8.encode(password + saltBase64)).bytes;
    final key = enc.Key(Uint8List.fromList(keyBytes));

    // 3. Generate a random 16-byte IV
    final iv = enc.IV.fromLength(16);

    // 4. Encrypt using AES-CBC
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    // 5. Combine salt, IV and cipherText
    return "$saltBase64.${iv.base64}.${encrypted.base64}";
  }

  /// Decrypts a backup string formatted as "salt_base64.iv_base64.encrypted_base64" using [password].
  static String decrypt(String cipherTextWithMetadata, String password) {
    final parts = cipherTextWithMetadata.split('.');
    if (parts.length != 3) {
      throw Exception("Invalid backup file format. File may be corrupted or unencrypted.");
    }

    final saltBase64 = parts[0];
    final ivBase64 = parts[1];
    final encryptedBase64 = parts[2];

    // 1. Re-derive the key
    final keyBytes = sha256.convert(utf8.encode(password + saltBase64)).bytes;
    final key = enc.Key(Uint8List.fromList(keyBytes));

    // 2. Re-create IV and decrypt
    final iv = enc.IV.fromBase64(ivBase64);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    
    return encrypter.decrypt64(encryptedBase64, iv: iv);
  }
}
