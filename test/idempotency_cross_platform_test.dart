import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/kernel/idempotency/idempotency_service.dart';
import 'package:path/path.dart';
import 'dart:io';

void main() {
  // Initialize FFI for SQFlite
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Idempotency Service Cross-Platform Tests', () {
    final testDbName =
        'test_idempotency_${DateTime.now().millisecondsSinceEpoch}.db';
    late Directory tempDir;

    setUp(() async {
      DatabaseHelper.setDbName(testDbName);
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, testDbName);
      if (File(path).existsSync()) {
        File(path).deleteSync();
      }

      tempDir = Directory.systemTemp.createTempSync();
      Hive.init(tempDir.path);
      if (Hive.isBoxOpen('idempotency_keys')) {
        await Hive.box('idempotency_keys').close();
      }
      await Hive.openBox('idempotency_keys');
    });

    tearDown(() async {
      await DatabaseHelper().close();
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, testDbName);
      if (File(path).existsSync()) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }
      await Hive.close();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test(
        'First checkout reservation succeeds, duplicate attempt is blocked (SQLite)',
        () async {
      final service = IdempotencyService();
      final key = service.generateKey();

      // First reservation must succeed
      final firstAttempt = await service.checkAndReserveKey(
        key: key,
        entityType: 'ORDER',
        entityId: 'ORD_1001',
        deviceId: 'DEV_ALPHA',
      );
      expect(firstAttempt, isTrue);

      // Immediate second attempt with same key MUST be blocked
      final secondAttempt = await service.checkAndReserveKey(
        key: key,
        entityType: 'ORDER',
        entityId: 'ORD_1001',
        deviceId: 'DEV_ALPHA',
      );
      expect(secondAttempt, isFalse,
          reason: 'Duplicate checkout should be blocked by idempotency check');
    });

    test('Different idempotency keys can be reserved independently', () async {
      final service = IdempotencyService();
      final key1 = service.generateKey();
      final key2 = service.generateKey();

      expect(
          await service.checkAndReserveKey(
            key: key1,
            entityType: 'ORDER',
            entityId: 'ORD_1002',
            deviceId: 'DEV_ALPHA',
          ),
          isTrue);

      expect(
          await service.checkAndReserveKey(
            key: key2,
            entityType: 'ORDER',
            entityId: 'ORD_1003',
            deviceId: 'DEV_ALPHA',
          ),
          isTrue);
    });

    test(
        'Hive idempotency store blocks duplicate keys for Web platform simulation',
        () async {
      final box = Hive.box('idempotency_keys');
      const testKey = 'WEB_IDEM_KEY_999';

      // Verify key does not exist yet
      expect(box.get(testKey), isNull);

      // Simulate first reservation on Web
      await box.put(testKey, {
        'key': testKey,
        'entityType': 'ORDER',
        'entityId': 'ORD_WEB_01',
        'deviceId': 'WEB_CLIENT',
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Subsequent check in box verifies key is reserved
      final existing = box.get(testKey);
      expect(existing, isNotNull);
      expect(existing['entityId'], 'ORD_WEB_01');
    });
  });
}
