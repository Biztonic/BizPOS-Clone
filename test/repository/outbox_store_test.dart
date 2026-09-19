import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/sync/outbox/outbox_store.dart';
import 'package:biztonic_pos/sync/outbox/outbox_operation.dart';

void main() {
  late Directory tempDir;
  late Repository repo;
  late OutboxStore outboxStore;
  late Box queueBox;
  late Box deadLetterBox;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('repo_outbox_test_');
    final dbPath = p.join(tempDir.path, 'repo_outbox.db');
    DatabaseHelper.setDbName(dbPath);

    Hive.init(tempDir.path);
    queueBox = await Hive.openBox(OutboxStore.primaryQueueBox);
    deadLetterBox = await Hive.openBox(OutboxStore.deadLetterBox);

    repo = Repository();
    outboxStore = OutboxStore(
      getQueueBox: () => queueBox,
      getFailedQueueBox: () => deadLetterBox,
      getRepository: () => repo,
    );
  });

  tearDown(() async {
    await Hive.close();
    await DatabaseHelper().close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Repository Tests: Durable Outbox Store Lifecycle & Recovery', () {
    test(
        '1. Enqueue operation writes to both Hive queue and SQLite outbox table',
        () async {
      final op = OutboxOperation(
        operationId: 'OP_OUTBOX_001',
        storeId: 'STORE_OUTBOX_1',
        userId: 'USER_1',
        deviceId: 'DEV_1',
        collection: 'orders',
        entityId: 'ORD_999',
        operation: 'create',
        payload: {'total': 500.0, 'status': 'Completed'},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        state: OutboxState.pending,
      );

      final key = await outboxStore.enqueue(op);
      expect(key, 'OP_OUTBOX_001');

      // Verify in Hive
      expect(queueBox.containsKey('OP_OUTBOX_001'), isTrue);
      final hiveOp = queueBox.get('OP_OUTBOX_001');
      expect(hiveOp['operation'], 'create');
      expect(hiveOp['storeId'], 'STORE_OUTBOX_1');

      // Verify in SQLite
      final db = await DatabaseHelper().database;
      final rows = await db.query('outbox_operations',
          where: 'operationId = ?', whereArgs: ['OP_OUTBOX_001']);
      expect(rows.length, 1);
      expect(rows.first['operation'], 'create');
      expect(rows.first['state'], 'PENDING');
    });

    test(
        '2. Stale in-flight recovery resets orphaned IN_FLIGHT operations back to PENDING',
        () async {
      // Simulate an operation left IN_FLIGHT when the process died abruptly
      final crashedOp = OutboxOperation(
        operationId: 'OP_CRASHED_002',
        storeId: 'STORE_OUTBOX_1',
        userId: 'USER_1',
        deviceId: 'DEV_1',
        collection: 'inventory_movements',
        entityId: 'MOV_888',
        operation: 'create',
        payload: {'delta': -1},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        state: OutboxState.inFlight, // Stuck in-flight!
      );

      await queueBox.put(crashedOp.operationId, crashedOp.toMap());

      final db = await DatabaseHelper().database;
      await db.insert('outbox_operations', crashedOp.toSqlRow());

      // Trigger recovery on app boot
      await outboxStore.recoverStaleInFlight();

      // Verify Hive status recovered to PENDING
      final recoveredHive = queueBox.get('OP_CRASHED_002');
      expect(recoveredHive['state'], 'PENDING');

      // Verify SQLite status recovered to PENDING
      final recoveredDb = await db.query('outbox_operations',
          where: 'operationId = ?', whereArgs: ['OP_CRASHED_002']);
      expect(recoveredDb.first['state'], 'PENDING');
    });

    test(
        '3. Fatal errors (permission-denied, unauthenticated) are detected accurately',
        () {
      expect(
          OutboxStore.isFatalError(
              'FirebaseError: [permission-denied] Missing or insufficient permissions.'),
          isTrue);
      expect(
          OutboxStore.isFatalError(
              'FirebaseError: [unauthenticated] The request does not have valid auth.'),
          isTrue);
      expect(
          OutboxStore.isFatalError(
              'FirebaseError: [not-found] Document not found.'),
          isTrue);
      expect(
          OutboxStore.isFatalError(
              'FirebaseError: [failed-precondition] Target index is missing.'),
          isTrue);

      // Transient network errors are NOT fatal
      expect(OutboxStore.isFatalError('SocketException: Failed host lookup'),
          isFalse);
      expect(OutboxStore.isFatalError('TimeoutException after 0:00:10.000000'),
          isFalse);
      expect(
          OutboxStore.isFatalError(
              'unavailable: Cloud Firestore service temporarily unavailable'),
          isFalse);
    });

    test(
        '4. computeNextRetryAt computes monotonic exponential backoff with jitter',
        () {
      final now = DateTime.now().millisecondsSinceEpoch;

      final retry1 = OutboxStore.computeNextRetryAt(1);
      final retry2 = OutboxStore.computeNextRetryAt(2);
      final retry3 = OutboxStore.computeNextRetryAt(3);
      final retry4 = OutboxStore.computeNextRetryAt(4);

      // Verify future timestamps
      expect(retry1, greaterThanOrEqualTo(now));
      expect(retry2, greaterThan(retry1 - 1000)); // Accounting for 20% jitter
      expect(retry3, greaterThan(retry2 - 1000));
      expect(retry4, greaterThan(retry3 - 1000));

      // Max backoff capped at 300 seconds + jitter
      final retryHigh = OutboxStore.computeNextRetryAt(20);
      expect(retryHigh - now, lessThanOrEqualTo(370000));
    });
  });
}
