import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/recovery_service.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';

void main() {
  late Directory tempDir;
  late RecoveryService recoveryService;

  const testStoreId = 'STORE_RECOVERY_01';
  const testItemId = 'ITEM_REC_01';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('repo_recovery_test_');
    final dbPath = p.join(tempDir.path, 'repo_recovery.db');
    DatabaseHelper.setDbName(dbPath);

    recoveryService = RecoveryService(
      dbHelper: DatabaseHelper(),
      movementRepo: InventoryMovementRepository(),
    );

    final db = await DatabaseHelper().database;
    await db.insert('inventory', {
      'id': testItemId,
      'storeId': testStoreId,
      'name': 'Cold Brew Coffee',
      'price': 220.0,
      'cost': 95.0,
      'quantity': 50,
      'category': 'Beverages',
      'status': 'ACTIVE',
      'trackStock': 1,
      'isDeleted': 0,
    });
  });

  tearDown(() async {
    await DatabaseHelper().close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group(
      'Repository Tests: RecoveryService Journal Reconciliation & Crash Recovery',
      () {
    test(
        '1. Fully applied pending transaction is detected and marked COMMITTED',
        () async {
      final db = await DatabaseHelper().database;
      const txId = 'TX_FULLY_COMMITTED_001';
      const orderId = 'ORD_REC_101';

      // Seed all transaction entities in DB
      await db.insert('orders', {
        'id': orderId,
        'storeId': testStoreId,
        'subtotal': 440.0,
        'total': 440.0,
        'status': 'Completed',
        'date': DateTime.now().toIso8601String(),
      });
      await db.insert('order_items', {
        'orderId': orderId,
        'itemId': testItemId,
        'name': 'Cold Brew Coffee',
        'quantity': 2,
        'price': 220.0,
      });
      await db.insert('business_events', {
        'id': 'EVT_REC_101',
        'storeId': testStoreId,
        'entityType': 'ORDER',
        'entityId': orderId,
        'eventType': 'CREATE',
        'amount': 440.0,
        'createdAt': DateTime.now().toIso8601String(),
        'deviceId': 'DEV_REC_1',
      });
      await db.insert('inventory_movements', {
        'id': 'MOV_REC_101',
        'itemId': testItemId,
        'storeId': testStoreId,
        'delta': -2,
        'type': 'SALE',
        'orderId': orderId,
        'operationId': 'op_rec_101',
        'createdAt': DateTime.now().toIso8601String(),
        'deviceId': 'DEV_REC_1',
      });
      await db.insert('monthly_order_counter', {
        'storeId': testStoreId,
        'yearMonth': '2026-09',
        'count': 1,
      });

      // Journal entry left as PENDING due to simulated app kill before step 6
      final payload = jsonEncode({
        'order': {
          'id': orderId,
          'storeId': testStoreId,
          'total': 440.0,
          'status': 'Completed'
        },
        'orderItems': [
          {
            'id': 'ITEM_ROW_1',
            'orderId': orderId,
            'itemId': testItemId,
            'quantity': 2,
            'price': 220.0
          }
        ],
        'event': {
          'id': 'EVT_REC_101',
          'storeId': testStoreId,
          'entityType': 'ORDER',
          'entityId': orderId,
          'eventType': 'CREATE',
          'amount': 440.0
        },
        'movements': [
          {
            'id': 'MOV_REC_101',
            'itemId': testItemId,
            'storeId': testStoreId,
            'delta': -2,
            'type': 'SALE',
            'orderId': orderId,
            'operationId': 'op_rec_101'
          }
        ],
        'yearMonth': '2026-09',
      });

      await db.insert('transaction_journal', {
        'id': txId,
        'storeId': testStoreId,
        'status': 'PENDING',
        'operations': payload,
        'createdAt': DateTime.now().toIso8601String(),
      });

      final reports = await recoveryService.scanAndRecoverReports();
      expect(reports.length, 1);
      expect(reports.first.status, TransactionResolutionStatus.committed);
      expect(reports.first.orderExisted, isTrue);
      expect(reports.first.itemsFound, 1);
      expect(reports.first.movementsFound, 1);

      // Verify journal updated to COMPLETED
      final journal = await db
          .query('transaction_journal', where: 'id = ?', whereArgs: [txId]);
      expect(journal.first['status'], 'COMPLETED');
    });

    test(
        '2. Unapplied transaction with zero writes in DB is marked ROLLED_BACK',
        () async {
      final db = await DatabaseHelper().database;
      const txId = 'TX_ROLLED_BACK_002';
      const orderId = 'ORD_NEVER_APPLIED';

      final payload = jsonEncode({
        'order': {
          'id': orderId,
          'storeId': testStoreId,
          'total': 220.0,
          'status': 'Completed'
        },
        'orderItems': [
          {
            'id': 'ITEM_ROW_2',
            'orderId': orderId,
            'itemId': testItemId,
            'quantity': 1,
            'price': 220.0
          }
        ],
        'event': {
          'id': 'EVT_REC_102',
          'storeId': testStoreId,
          'entityType': 'ORDER',
          'entityId': orderId,
          'eventType': 'CREATE',
          'amount': 220.0
        },
        'movements': [
          {
            'id': 'MOV_REC_102',
            'itemId': testItemId,
            'storeId': testStoreId,
            'delta': -1,
            'type': 'SALE',
            'orderId': orderId,
            'operationId': 'op_rec_102'
          }
        ],
        'yearMonth': '2026-09',
      });

      // Insert PENDING journal with nothing in DB (simulating crash before SQLite transaction started)
      await db.insert('transaction_journal', {
        'id': txId,
        'storeId': testStoreId,
        'status': 'PENDING',
        'operations': payload,
        'createdAt': DateTime.now().toIso8601String(),
      });

      final reports = await recoveryService.scanAndRecoverReports();
      expect(reports.length, 1);
      expect(reports.first.status, TransactionResolutionStatus.rolledBack);

      final journal = await db
          .query('transaction_journal', where: 'id = ?', whereArgs: [txId]);
      expect(journal.first['status'], 'ROLLED_BACK');
    });

    test(
        '3. Corrupted operations JSON payload is safely quarantined and marked FAILED',
        () async {
      final db = await DatabaseHelper().database;
      const txId = 'TX_CORRUPTED_003';

      await db.insert('transaction_journal', {
        'id': txId,
        'storeId': testStoreId,
        'status': 'PENDING',
        'operations': '{{{ INVALID UNPARSEABLE JSON DATA ]]]',
        'createdAt': DateTime.now().toIso8601String(),
      });

      final reports = await recoveryService.scanAndRecoverReports();
      expect(reports.length, 1);
      expect(reports.first.status, TransactionResolutionStatus.failed);
      expect(reports.first.error, contains('Corrupted JSON'));

      final journal = await db
          .query('transaction_journal', where: 'id = ?', whereArgs: [txId]);
      expect(journal.first['status'], 'FAILED');
    });
  });
}
