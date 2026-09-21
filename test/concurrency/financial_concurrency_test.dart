import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';

import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:biztonic_pos/features/billing/domain/entities/order_entity.dart';
import 'package:biztonic_pos/features/billing/application/checkout_orchestrator.dart';
import 'package:biztonic_pos/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:biztonic_pos/services/recovery_service.dart';
import 'package:biztonic_pos/features/inventory/domain/policies/inventory_policy.dart';
import 'package:biztonic_pos/sync/outbox/outbox_operation.dart';
import 'package:biztonic_pos/features/reporting/data/reporting_repository.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Financial Determinism & Concurrency Resilience Test Suite', () {
    late Directory tempDir;
    late String dbPath;
    late Repository repository;
    late BillingRepositoryImpl billingRepository;
    late CheckoutOrchestrator orchestrator;

    const testStoreId = 'STORE_CONCURRENCY_A';
    const testItemId = 'ITEM_BURGER_01';

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('bizpos_concurrency_test_');
      final dbName =
          'test_concurrency_${DateTime.now().microsecondsSinceEpoch}.db';
      dbPath = p.join(tempDir.path, dbName);
      DatabaseHelper.setDbName(dbPath);

      Hive.init(tempDir.path);
      if (Hive.isBoxOpen('cache_orders'))
        await Hive.box('cache_orders').close();
      if (Hive.isBoxOpen('cache_inventory'))
        await Hive.box('cache_inventory').close();
      if (Hive.isBoxOpen('idempotency_keys'))
        await Hive.box('idempotency_keys').close();

      await Hive.openBox('cache_orders');
      await Hive.openBox('cache_inventory');
      await Hive.openBox('idempotency_keys');

      repository = Repository();
      billingRepository = BillingRepositoryImpl(repository: repository);
      orchestrator = CheckoutOrchestrator(billingRepository: billingRepository);

      final db = await DatabaseHelper().database;

      // Seed test item
      await db.insert('inventory', {
        'id': testItemId,
        'storeId': testStoreId,
        'name': 'Gourmet Burger',
        'price': 250.0,
        'cost': 100.0,
        'quantity': 20,
        'category': 'Food',
        'status': 'ACTIVE',
        'trackStock': 1,
        'isDeleted': 0,
      });

      // Seed initial purchase movement
      await db.insert('inventory_movements', {
        'id': 'MOV_INIT_BURGER',
        'itemId': testItemId,
        'storeId': testStoreId,
        'delta': 20,
        'type': 'PURCHASE',
        'cost': 100.0,
        'reason': 'Initial Stock',
        'deviceId': 'DEV_INIT',
        'operationId': 'op_init_burger',
        'createdAt': DateTime.now().toIso8601String(),
        'syncStatus': 'CONFIRMED',
        'isDeleted': 0,
      });
    });

    tearDown(() async {
      await DatabaseHelper().close();
      await Hive.close();
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    OrderItemEntity createOrderItem({int qty = 1}) {
      return OrderItemEntity(
        itemId: testItemId,
        itemName: 'Gourmet Burger',
        price: 250.0,
        cost: 100.0,
        quantity: qty,
        category: 'Food',
      );
    }

    OrderEntity createTestOrder(
        {String? id, int qty = 1, double discount = 0.0}) {
      return OrderEntity(
        id: id ?? '',
        storeId: testStoreId,
        items: [createOrderItem(qty: qty)],
        total: 250.0 * qty - discount,
        subtotal: 250.0 * qty,
        discount: discount,
        date: DateTime.now(),
        status: OrderStatus.newOrder,
        type: OrderType.dineIn,
        paymentMethod: PaymentMethod.cash,
      );
    }

    test(
        '1. Exactly-Once Checkout: 10 simultaneous parallel checkouts with the same key create ONE order',
        () async {
      const stableKey = 'IDEMP_KEY_SIMULTANEOUS_10';
      const orderId = 'ORD_SIMULTANEOUS_01';
      final baseOrder = createTestOrder(id: orderId, qty: 2);

      // Launch 10 parallel checkout attempts simulating high-frequency double/multi-taps
      final futures = List.generate(10, (index) {
        return orchestrator.execute(CheckoutParams(
          order: baseOrder,
          activeStoreId: testStoreId,
          deviceId: 'DEVICE_POS_1',
          idempotencyKey: stableKey,
          taxRate: 5.0,
          trackInventory: true,
        ));
      });

      final results = await Future.wait(futures);

      // Verify that at least one succeeded with order creation, and non-creators were safely intercepted
      final successfulResults = results.where((r) => r.isSuccess).toList();
      expect(successfulResults.isNotEmpty, isTrue);

      final db = await DatabaseHelper().database;

      // Database assertion 1: exactly ONE order in orders table
      final orders =
          await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
      expect(orders.length, 1,
          reason: 'Expected exactly 1 order row in SQLite');
      expect(orders.first['subtotal'], 500.0);
      expect(orders.first['cgst'], 12.5);
      expect(orders.first['sgst'], 12.5);
      expect(orders.first['total'], 525.0);

      // Database assertion 2: exactly items for 1 order
      final items = await db
          .query('order_items', where: 'orderId = ?', whereArgs: [orderId]);
      expect(items.length, 1);
      expect(items.first['quantity'], 2);

      // Database assertion 3: token counter incremented by exactly 1
      final now = DateTime.now();
      final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final counters = await db.query('monthly_order_counter',
          where: 'storeId = ? AND yearMonth = ?',
          whereArgs: [testStoreId, yearMonth]);
      expect(counters.length, 1);
      expect(counters.first['count'], 1,
          reason: 'Counter must be incremented exactly once');

      // Database assertion 4: outbox operation was inserted atomically
      final outboxOps = await db.query('outbox_operations',
          where: 'entityId = ?', whereArgs: [orderId]);
      expect(outboxOps.length, 1,
          reason: 'Outbox operation must exist atomically');
    });

    test(
        '2. Repeated Identical Operations: subsequent call with same key resolves to existing order',
        () async {
      const key = 'IDEMP_KEY_RETRY_01';
      const orderId = 'ORD_RETRY_01';
      final order = createTestOrder(id: orderId, qty: 1);

      // Call 1
      final res1 = await orchestrator.execute(CheckoutParams(
        order: order,
        activeStoreId: testStoreId,
        deviceId: 'DEVICE_POS_1',
        idempotencyKey: key,
        taxRate: 18.0,
      ));
      expect(res1.isSuccess, isTrue);
      expect(res1.order?.id, orderId);

      // Call 2 (Sequential retry after network blip or widget rebuild)
      final res2 = await orchestrator.execute(CheckoutParams(
        order: order,
        activeStoreId: testStoreId,
        deviceId: 'DEVICE_POS_1',
        idempotencyKey: key,
        taxRate: 18.0,
      ));

      // Must resolve to existing order cleanly
      expect(res2.isSuccess, isTrue);
      expect(res2.order?.id, orderId);

      final db = await DatabaseHelper().database;
      final count = Sqflite.firstIntValue(await db
          .rawQuery('SELECT COUNT(*) FROM orders WHERE id = ?', [orderId]));
      expect(count, 1);
    });

    test(
        '3. Two Offline Devices Selling Same Inventory: ledger records both movements deterministically',
        () async {
      final now = DateTime.now();
      final db = await DatabaseHelper().database;

      // Device 1 sells 7 burgers offline
      final mov1 = InventoryMovement(
        id: 'MOV_DEV1_SALE',
        itemId: testItemId,
        storeId: testStoreId,
        type: MovementType.sale,
        delta: -7,
        orderId: 'ORD_DEV1',
        unitCost: 100.0,
        reason: 'Sale Dev 1',
        deviceId: 'DEV_1',
        operationId: 'op_dev1_sale',
        createdAt: now,
      );

      // Device 2 sells 5 burgers offline
      final mov2 = InventoryMovement(
        id: 'MOV_DEV2_SALE',
        itemId: testItemId,
        storeId: testStoreId,
        type: MovementType.sale,
        delta: -5,
        orderId: 'ORD_DEV2',
        unitCost: 100.0,
        reason: 'Sale Dev 2',
        deviceId: 'DEV_2',
        operationId: 'op_dev2_sale',
        createdAt: now.add(const Duration(seconds: 1)),
      );

      final mRepo = repository.movementRepo;
      final res1 = await mRepo.insertMovement(mov1,
          negativeStockPolicy: NegativeStockPolicy.allowWithWarning);
      final res2 = await mRepo.insertMovement(mov2,
          negativeStockPolicy: NegativeStockPolicy.allowWithWarning);

      expect(res1, isTrue);
      expect(res2, isTrue);

      // Both movements are recorded without conflict
      final movRows = await db.query('inventory_movements',
          where: 'storeId = ? AND type = ?', whereArgs: [testStoreId, 'SALE']);
      expect(movRows.length, 2);

      // Total delta sum = -12. Initial was 20 -> Net stock is 8
      final sum = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT SUM(delta) FROM inventory_movements WHERE itemId = ?',
          [testItemId]));
      expect(sum, 8);
    });

    test(
        '4. Reconnect After Crash: RecoveryService reconciles pending transaction and outbox operation',
        () async {
      final db = await DatabaseHelper().database;
      const txId = 'TX_CRASH_SIMULATION_01';
      const orderId = 'ORD_CRASH_01';

      final orderMap = {
        'id': orderId,
        'storeId': testStoreId,
        'total': 262.5,
        'subtotal': 250.0,
        'discount': 0.0,
        'cgst': 6.25,
        'sgst': 6.25,
        'taxRateSnapshot': 5.0,
        'discountSnapshot': 0.0,
        'date': DateTime.now().toIso8601String(),
        'status': 'Completed',
        'type': 'Dine-In',
        'paymentMethod': 'Cash',
        'synced': 0,
        'syncStatus': 'PENDING',
        'version': 1,
      };

      final itemsMap = [
        {
          'orderId': orderId,
          'itemId': testItemId,
          'name': 'Gourmet Burger',
          'price': 250.0,
          'quantity': 1,
          'cost': 100.0,
          'cgst': 6.25,
          'sgst': 6.25,
        }
      ];

      final outboxOpMap = OutboxOperation(
        operationId: 'op_order_$orderId',
        storeId: testStoreId,
        userId: 'system',
        deviceId: 'DEV_CRASH',
        collection: 'orders',
        entityId: orderId,
        operation: 'CREATE',
        payload: orderMap,
      ).toSqlRow();

      final payload = jsonEncode({
        'order': orderMap,
        'orderItems': itemsMap,
        'event': {
          'id': 'EVT_CRASH_01',
          'storeId': testStoreId,
          'entityType': 'ORDER',
          'entityId': orderId,
          'eventType': 'CREATE',
          'amount': 262.5,
          'quantity': 1,
          'createdAt': DateTime.now().toIso8601String(),
          'deviceId': 'DEV_CRASH',
        },
        'movements': [],
        'outboxOperations': [outboxOpMap],
        'yearMonth': '2026-09',
      });

      // Simulate crash after order was inserted but before items, outbox, and journal completion
      await db.insert('orders', orderMap);

      await db.insert('transaction_journal', {
        'id': txId,
        'storeId': testStoreId,
        'status': 'PENDING',
        'operations': payload,
        'createdAt': DateTime.now().toIso8601String(),
      });

      // App restarts and RecoveryService scans
      final recovery = RecoveryService(
          dbHelper: DatabaseHelper(), movementRepo: repository.movementRepo);
      final reports = await recovery.scanAndRecoverReports();

      expect(reports.isNotEmpty, isTrue);
      final report = reports.firstWhere((r) => r.txId == txId);
      expect(
          report.status, TransactionResolutionStatus.partiallyAppliedRecovered);

      // Verify order and outbox row are now present
      final orderRows =
          await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
      expect(orderRows.length, 1);

      final outboxRows = await db.query('outbox_operations',
          where: 'entityId = ?', whereArgs: [orderId]);
      expect(outboxRows.length, 1,
          reason: 'Recovery must reconcile outbox operation');

      // Verify journal is now COMPLETED
      final journalRows = await db
          .query('transaction_journal', where: 'id = ?', whereArgs: [txId]);
      expect(journalRows.first['status'], 'COMPLETED');
    });

    test(
        '5. Refund After Sync: Finalized order is refunded with immutable totals and restock movement',
        () async {
      const orderId = 'ORD_SYNC_REFUND_01';
      final order = createTestOrder(id: orderId, qty: 2);

      // 1. Place order
      final checkRes = await orchestrator.execute(CheckoutParams(
        order: order,
        activeStoreId: testStoreId,
        deviceId: 'DEV_POS_1',
        idempotencyKey: 'IDEMP_REFUND_01',
        taxRate: 5.0,
        trackInventory: true,
      ));
      expect(checkRes.isSuccess, isTrue);

      final db = await DatabaseHelper().database;
      // Mark as synced to simulate cloud sync
      await db.update('orders', {'syncStatus': 'SYNCED', 'synced': 1},
          where: 'id = ?', whereArgs: [orderId]);

      // 2. Perform Refund via repository
      await repository.refundOrder(
        orderId,
        refundedBy: 'manager_alice',
        reason: 'Customer cancelled at table',
        refundAmount: 525.0,
        deviceId: 'DEV_POS_1',
      );

      // 3. Verify order status and financial immutability
      final rows =
          await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
      expect(rows.length, 1);
      final refundedOrder = rows.first;

      expect(refundedOrder['status'], 'Refunded');
      expect(refundedOrder['voidedBy'], 'manager_alice');
      expect(refundedOrder['voidReason'], contains('Refund (525.0)'));
      // Immutability: financial numbers must NOT be zeroed or corrupted
      expect(refundedOrder['total'], 525.0);
      expect(refundedOrder['subtotal'], 500.0);
      expect(refundedOrder['cgst'], 12.5);
      expect(refundedOrder['sgst'], 12.5);

      // Attempting to refund again should be rejected or no-op
      await repository.refundOrder(
        orderId,
        refundedBy: 'manager_bob',
        reason: 'Duplicate refund attempt',
        refundAmount: 525.0,
      );
      final recheckRows =
          await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
      expect(recheckRows.first['voidedBy'], 'manager_alice',
          reason: 'Repeated refund must not overwrite original actor');
    });

    test('6. Duplicate Sync Delivery: OutboxOperation delivery deduplication',
        () async {
      final db = await DatabaseHelper().database;
      final op = OutboxOperation(
        operationId: 'OP_DEDUP_01',
        storeId: testStoreId,
        userId: 'admin',
        deviceId: 'DEV_01',
        collection: 'orders',
        entityId: 'ORD_DEDUP_01',
        operation: 'CREATE',
        payload: {'id': 'ORD_DEDUP_01', 'total': 100.0},
      );

      // Insert once
      await db.insert('outbox_operations', op.toSqlRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);

      // Insert second time (duplicate sync event)
      await db.insert('outbox_operations', op.toSqlRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);

      final rows = await db.query('outbox_operations',
          where: 'operationId = ?', whereArgs: ['OP_DEDUP_01']);
      expect(rows.length, 1,
          reason:
              'Duplicate sync delivery must not duplicate outbox operation');
    });

    test(
        '7. App Restart Halfway Through Checkout: Rolled back transaction leaves no orphaned records',
        () async {
      final db = await DatabaseHelper().database;
      const txId = 'TX_ROLLED_BACK_01';
      const orderId = 'ORD_ORPHAN_TEST_01';

      final payload = jsonEncode({
        'order': {'id': orderId, 'storeId': testStoreId},
        'orderItems': [],
        'event': {'id': 'EVT_ROLLED_BACK'},
        'movements': [],
        'yearMonth': '2026-09',
      });

      // Journal entry was created, but transaction rolled back before writing anything to orders
      await db.insert('transaction_journal', {
        'id': txId,
        'storeId': testStoreId,
        'status': 'PENDING',
        'operations': payload,
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Recovery without auto-reconcile detects clean rollback
      final recovery = RecoveryService(
          dbHelper: DatabaseHelper(), movementRepo: repository.movementRepo);
      final report =
          await recovery.reconcileTransaction(txId, autoReconcile: false);

      expect(report.status, TransactionResolutionStatus.rolledBack);

      final journal = await db
          .query('transaction_journal', where: 'id = ?', whereArgs: [txId]);
      expect(journal.first['status'], 'ROLLED_BACK');

      final orderRows =
          await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
      expect(orderRows.isEmpty, isTrue);
    });

    test(
        '8. Local SQLite Tenant Isolation: Queries with null or empty storeId return 0 results',
        () async {
      final reporting = ReportingRepository(dbHelper: DatabaseHelper());

      // Store A has records seeded
      final countNull = await reporting.getOrderCount(null);
      final countEmpty = await reporting.getOrderCount('');
      expect(countNull, 0, reason: 'null storeId must strictly return 0 count');
      expect(countEmpty, 0,
          reason: 'empty storeId must strictly return 0 count');

      final invNull = await reporting.getInventoryCount(null);
      final invEmpty = await reporting.getInventoryCount('');
      expect(invNull, 0);
      expect(invEmpty, 0);

      final unsyncedNull = await reporting.getUnsyncedEvents(null);
      expect(unsyncedNull.isEmpty, isTrue);

      // With valid storeId, it returns the store-specific count
      final invA = await reporting.getInventoryCount(testStoreId);
      expect(invA, 1);
    });
  });
}
