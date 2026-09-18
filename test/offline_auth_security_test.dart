import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:biztonic_pos/services/offline_service.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('Offline Authentication & Zero Raw Password Security Tests', () {
    late Directory tempDir;
    late OfflineService offlineService;
    const testEmail = 'pos_cashier@store.bizpos';
    const testPassword = 'SecurePassword123!';

    setUp(() async {
      OfflineService.isTesting = true;
      tempDir = Directory.systemTemp.createTempSync();
      Hive.init(tempDir.path);
      await Hive.openBox('auth_cache');
      await Hive.openBox('sync_queue');

      offlineService = OfflineService();
      FlutterSecureStorage.setMockInitialValues({});
    });

    tearDown(() async {
      await Hive.close();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test(
        'cacheCredentials does NOT store plaintext password in secure storage (Principle 9)',
        () async {
      await offlineService.cacheCredentials(testEmail, testPassword,
          uid: 'user_123');

      // Verify that getCachedCredentials returns null (no raw password accessible)
      final cachedCreds =
          await offlineService.getCachedCredentials(email: testEmail);
      expect(cachedCreds, isNull,
          reason: 'Raw passwords must never be stored or retrieved');

      // Verify FlutterSecureStorage does NOT have cred_ key
      const secureStorage = FlutterSecureStorage();
      final storedPassword = await secureStorage.read(
          key: 'cred_${testEmail.toLowerCase().trim()}');
      expect(storedPassword, isNull,
          reason: 'Plaintext password must not exist in secure storage');
    });

    test(
        'verifyOfflinePassword correctly verifies valid password via salted SHA-256 hash',
        () async {
      await offlineService.cacheCredentials(testEmail, testPassword,
          uid: 'user_123');

      // Valid password must succeed
      final isValid =
          offlineService.verifyOfflinePassword(testEmail, testPassword);
      expect(isValid, isTrue);

      // Invalid password must fail
      final isInvalid =
          offlineService.verifyOfflinePassword(testEmail, 'WrongPassword!');
      expect(isInvalid, isFalse);
    });

    test('Failed offline attempts trigger lockout after 5 attempts', () async {
      await offlineService.cacheCredentials(testEmail, testPassword,
          uid: 'user_123');

      expect(offlineService.isOfflineLockedOut(testEmail), isFalse);

      // Attempt 5 wrong passwords
      for (int i = 0; i < 5; i++) {
        offlineService.verifyOfflinePassword(testEmail, 'BadGuess_$i');
      }

      // Must be locked out now
      expect(offlineService.isOfflineLockedOut(testEmail), isTrue);

      // Even correct password should be rejected while locked out
      final attemptDuringLockout =
          offlineService.verifyOfflinePassword(testEmail, testPassword);
      expect(attemptDuringLockout, isFalse);

      // Resetting failed attempts unlocks account
      offlineService.resetFailedAttempts(testEmail);
      expect(offlineService.isOfflineLockedOut(testEmail), isFalse);
      expect(offlineService.verifyOfflinePassword(testEmail, testPassword),
          isTrue);
    });
  });
}
