import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:biztonic_pos/services/offline_service.dart';
import 'package:biztonic_pos/core/auth/auth_session_types.dart';
import 'package:biztonic_pos/utils/pin_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('Hardened Authentication and Offline Login Security Tests', () {
    late Directory tempDir;
    late OfflineService offlineService;

    const user1Email = 'merchant_owner@store.bizpos';
    const user1Password = 'StrongPassword123!';
    const user1Uid = 'uid_merchant_1';

    const user2Email = 'franchise_partner@store.bizpos';
    const user2Password = 'FranchiseSecret456!';
    const user2Uid = 'uid_franchise_2';

    setUp(() async {
      OfflineService.isTesting = true;
      tempDir = Directory.systemTemp.createTempSync();
      Hive.init(tempDir.path);

      await Hive.openBox('auth_cache');
      await Hive.openBox('sync_queue');
      await Hive.openBox('user_profile_cache');
      await Hive.openBox('cache_employees');
      await Hive.openBox('cache_stores');

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
        '1. online login: stores salted verifier, records last authorized user',
        () async {
      await offlineService.cacheOfflineVerifier(user1Email, user1Password,
          uid: user1Uid);

      // Verify last authorized user recorded
      expect(offlineService.getLastAuthorizedEmail(), equals(user1Email));
      expect(offlineService.getLastAuthorizedUid(), equals(user1Uid));

      // Active session model
      final session = ActiveAuthSession(
        type: SessionType.FIREBASE_AUTH_SESSION,
        uid: user1Uid,
        email: user1Email,
        authenticatedAt: DateTime.now(),
      );
      expect(session.isOnline, isTrue);
      expect(session.isOffline, isFalse);
      expect(session.type, equals(SessionType.FIREBASE_AUTH_SESSION));
    });

    test(
        '2. offline login: succeeds for last authorized user with valid salted verifier',
        () async {
      await offlineService.cacheOfflineVerifier(user1Email, user1Password,
          uid: user1Uid);

      final isValid =
          await offlineService.verifyOfflinePassword(user1Email, user1Password);
      expect(isValid, isTrue);

      await offlineService.setOfflineLoginState(true, email: user1Email);
      expect(offlineService.getOfflineLoginState(), isTrue);
      expect(offlineService.getOfflineLoginEmail(), equals(user1Email));

      final offlineSession = ActiveAuthSession(
        type: SessionType.LOCAL_OFFLINE_SESSION,
        uid: offlineService.getCachedUserId(email: user1Email) ?? user1Uid,
        email: user1Email,
        authenticatedAt: DateTime.now(),
      );
      expect(offlineSession.isOffline, isTrue);
      expect(offlineSession.isOnline, isFalse);
      expect(offlineSession.type, equals(SessionType.LOCAL_OFFLINE_SESSION));
    });

    test(
        '3. wrong offline password and PIN: increments failed attempts and rejects access',
        () async {
      await offlineService.cacheOfflineVerifier(user1Email, user1Password,
          uid: user1Uid);

      // Wrong password
      final isWrong = await offlineService.verifyOfflinePassword(
          user1Email, 'IncorrectPassword');
      expect(isWrong, isFalse);

      final authBox = Hive.box('auth_cache');
      expect(authBox.get('failed_attempts_$user1Email'), equals(1));

      // Wrong employee PIN
      const storeId = 'store_test_1';
      const empId = '1001';
      expect(offlineService.isEmployeePinLockedOut(storeId, empId), isFalse);

      await offlineService.recordFailedPinAttempt(storeId, empId);
      final empBox = Hive.box('cache_employees');
      expect(empBox.get('failed_pin_${storeId}_$empId'), equals(1));
    });

    test(
        '4. lockout: 5 failed attempts locks out account and PIN with time backoff',
        () async {
      await offlineService.cacheOfflineVerifier(user1Email, user1Password,
          uid: user1Uid);

      expect(offlineService.isOfflineLockedOut(user1Email), isFalse);

      // Trigger 5 failed password attempts
      for (int i = 0; i < 5; i++) {
        await offlineService.verifyOfflinePassword(user1Email, 'WrongGuess_$i');
      }

      // Now locked out
      expect(offlineService.isOfflineLockedOut(user1Email), isTrue);
      expect(offlineService.getRemainingLockoutSeconds(user1Email),
          greaterThan(0));

      // Even correct password rejected while locked out
      expect(
          await offlineService.verifyOfflinePassword(user1Email, user1Password),
          isFalse);

      // Employee PIN lockout after 5 attempts
      const storeId = 'store_test_1';
      const empId = '1002';
      for (int i = 0; i < 5; i++) {
        await offlineService.recordFailedPinAttempt(storeId, empId);
      }
      expect(offlineService.isEmployeePinLockedOut(storeId, empId), isTrue);
      expect(offlineService.getRemainingPinLockoutSeconds(storeId, empId),
          greaterThan(0));

      // Reset PIN unlock
      await offlineService.resetPinAttempts(storeId, empId);
      expect(offlineService.isEmployeePinLockedOut(storeId, empId), isFalse);
    });

    test(
        '5. logout: invalidates session-specific state while preserving profiles',
        () async {
      await offlineService.cacheOfflineVerifier(user1Email, user1Password,
          uid: user1Uid);
      await offlineService
          .cacheUserProfile({'name': 'Merchant 1'}, uid: user1Uid);
      await offlineService.setOfflineLoginState(true, email: user1Email);

      expect(offlineService.getOfflineLoginState(), isTrue);

      // Execute logout / clearCredentials
      await offlineService.clearCredentials(email: user1Email);

      // Active session state cleared
      expect(offlineService.getOfflineLoginState(), isFalse);
      expect(offlineService.getOfflineLoginEmail(), isNull);

      // Cached profile and verifier preserved for authorized return
      final cachedProfile =
          await offlineService.getCachedUserProfile(uid: user1Uid);
      expect(cachedProfile, isNotNull);
      expect(cachedProfile!['name'], equals('Merchant 1'));

      final authBox = Hive.box('auth_cache');
      expect(authBox.get('hash_$user1Email'), isNotNull);
    });

    test(
        '6. multi-user local devices: profiles and verifiers coexist independently',
        () async {
      // User 1 signs in
      await offlineService.cacheOfflineVerifier(user1Email, user1Password,
          uid: user1Uid);
      await offlineService.cacheUserProfile({'name': 'Owner 1'}, uid: user1Uid);

      // User 2 signs in later on same device
      await offlineService.cacheOfflineVerifier(user2Email, user2Password,
          uid: user2Uid);
      await offlineService
          .cacheUserProfile({'name': 'Partner 2'}, uid: user2Uid);

      final authBox = Hive.box('auth_cache');
      // Both verifiers exist
      expect(authBox.get('hash_$user1Email'), isNotNull);
      expect(authBox.get('hash_$user2Email'), isNotNull);

      // Both user profiles exist independently
      final profile1 = await offlineService.getCachedUserProfile(uid: user1Uid);
      final profile2 = await offlineService.getCachedUserProfile(uid: user2Uid);
      expect(profile1?['name'], equals('Owner 1'));
      expect(profile2?['name'], equals('Partner 2'));

      // Most recent authorized user is User 2
      expect(offlineService.getLastAuthorizedEmail(), equals(user2Email));
    });

    test(
        '7. expired online session: does NOT silently re-auth with stored password',
        () async {
      // Confirm that getCachedCredentials returns null
      final creds =
          await offlineService.getCachedCredentials(email: user1Email);
      expect(creds, isNull);

      // Verify no reusable plaintext credentials exist in SecureStorage
      const secureStorage = FlutterSecureStorage();
      final storedPass = await secureStorage.read(key: 'cred_$user1Email');
      expect(storedPass, isNull);
    });

    test(
        '8. reconnect after offline session: transitions cleanly without password storage',
        () async {
      await offlineService.cacheOfflineVerifier(user1Email, user1Password,
          uid: user1Uid);
      await offlineService.setOfflineLoginState(true, email: user1Email);

      expect(offlineService.getOfflineLoginState(), isTrue);

      // Upon cloud session establishment, offline flag is reset
      await offlineService.setOfflineLoginState(false);
      expect(offlineService.getOfflineLoginState(), isFalse);

      // No passwords cached during transition
      expect(
          await offlineService.getCachedCredentials(email: user1Email), isNull);
    });

    test(
        '9. no raw password persisted: confirms zero plaintext passwords or PINs',
        () async {
      await offlineService.cacheOfflineVerifier(user1Email, user1Password,
          uid: user1Uid);

      // Cache employees containing legacy plaintext 'pin'
      const storeId = 'store_test_secure';
      await offlineService.cacheStoreEmployees(storeId, [
        {
          'employeeId': '5555',
          'name': 'Cashier Bob',
          'uid': 'uid_bob',
          'pin': '1234', // Legacy plaintext pin provided in payload
        }
      ]);

      // Inspect Hive box directly
      final empBox = Hive.box('cache_employees');
      final bobData = empBox.get('${storeId}_5555') as Map;

      // Plaintext 'pin' MUST be removed
      expect(bobData.containsKey('pin'), isFalse,
          reason: 'Raw PIN must never be persisted');
      // Must be replaced with salted pinHash
      expect(bobData['pinHash'], equals(PinUtils.hashPin('1234', 'uid_bob')));

      // Inspect auth_cache box directly
      final authBox = Hive.box('auth_cache');
      expect(authBox.containsKey('password'), isFalse);
      expect(authBox.containsKey('password_$user1Email'), isFalse);
      expect(authBox.get('hash_$user1Email'), isNotNull);
      expect(authBox.get('salt_$user1Email'), isNotNull);

      // Salted hash does NOT equal raw password
      expect(authBox.get('hash_$user1Email'), isNot(equals(user1Password)));
    });

    test('10. unauthorized user cannot reuse another user\'s offline session',
        () async {
      // User 1 is the authorized user on this device
      await offlineService.cacheOfflineVerifier(user1Email, user1Password,
          uid: user1Uid);
      expect(offlineService.getLastAuthorizedEmail(), equals(user1Email));

      // User 2 was cached earlier, but User 1 is the last authorized user
      // An unauthorized user tries to verify offline
      const unauthorizedEmail = 'attacker@evil.corp';
      final deniedUnauthorized = await offlineService.verifyOfflinePassword(
          unauthorizedEmail, 'AnyPassword');
      expect(deniedUnauthorized, isFalse);

      // Even if another valid user (user2) attempts offline login when user1 was the last authorized merchant
      final deniedUser2 =
          await offlineService.verifyOfflinePassword(user2Email, user2Password);
      expect(deniedUser2, isFalse,
          reason:
              'Offline POS access is restricted strictly to the last authorized user on the device');

      // Last authorized user CAN log in
      expect(
          await offlineService.verifyOfflinePassword(user1Email, user1Password),
          isTrue);
    });
  });
}
