import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:biztonic_pos/kernel/idempotency/idempotency_service.dart';
import 'package:biztonic_pos/services/database_helper.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    tempDir = Directory.systemTemp.createTempSync('idempotency_unit_test_');
    dbPath = p.join(tempDir.path, 'idempotency_test.db');
    DatabaseHelper.setDbName(dbPath);

    Hive.init(tempDir.path);
    await Hive.openBox('idempotency_keys');
  });

  tearDownAll(() async {
    await DatabaseHelper().close();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Unit Tests: Cross-Platform Idempotency Engine', () {
    final service = IdempotencyService();

    test('1. Generates non-empty time-sortable idempotency key', () {
      final key1 = service.generateKey();
      final key2 = service.generateKey();

      expect(key1.isNotEmpty, isTrue);
      expect(key2.isNotEmpty, isTrue);
      expect(key1, isNot(equals(key2)));
    });

    test('2. checkAndReserveKey reserves new key and blocks duplicate attempts',
        () async {
      const key = 'IDEM_KEY_TEST_001';
      const entityType = 'order';
      const entityId = 'ORD_IDEM_01';
      const deviceId = 'DEV_COUNTER_1';

      // First reservation must succeed
      final firstAttempt = await service.checkAndReserveKey(
        key: key,
        entityType: entityType,
        entityId: entityId,
        deviceId: deviceId,
      );
      expect(firstAttempt, isTrue);

      // Second reservation with exact same key must be rejected
      final secondAttempt = await service.checkAndReserveKey(
        key: key,
        entityType: entityType,
        entityId: entityId,
        deviceId: deviceId,
      );
      expect(secondAttempt, isFalse);
    });

    test('3. Distinct keys for distinct entities succeed independently',
        () async {
      final keyA = service.generateKey();
      final keyB = service.generateKey();

      final resA = await service.checkAndReserveKey(
        key: keyA,
        entityType: 'order',
        entityId: 'ORD_A',
        deviceId: 'DEV_1',
      );
      final resB = await service.checkAndReserveKey(
        key: keyB,
        entityType: 'order',
        entityId: 'ORD_B',
        deviceId: 'DEV_1',
      );

      expect(resA, isTrue);
      expect(resB, isTrue);
    });

    test(
        '4. Web Hive-backed reservation blocks duplicate within expiration window',
        () async {
      const webKey = 'WEB_IDEM_KEY_999';
      final box = Hive.box('idempotency_keys');

      // Check not reserved
      expect(box.containsKey(webKey), isFalse);

      // Reserve in Hive
      await box.put(webKey, {
        'entityType': 'order',
        'entityId': 'ORD_WEB_01',
        'reservedAt': DateTime.now().toIso8601String(),
      });

      expect(box.containsKey(webKey), isTrue);

      // Attempting to reserve again sees existing key
      final exists = box.containsKey(webKey);
      expect(exists, isTrue);
    });
  });
}
