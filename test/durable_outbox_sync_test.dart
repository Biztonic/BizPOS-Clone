import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';
import 'package:biztonic_pos/sync/outbox/outbox_operation.dart';
import 'package:biztonic_pos/sync/outbox/outbox_store.dart';
import 'package:biztonic_pos/sync/inbound/inbox_store.dart';
import 'package:biztonic_pos/sync/conflict/conflict_engine.dart';
import 'package:biztonic_pos/sync/registry/sync_collection_registry.dart';
import 'package:biztonic_pos/features/inventory/domain/entities/inventory_movement.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Durable OUTBOX + INBOX Synchronization Hardening Tests', () {
    final testDbName =
        'test_durable_outbox_${DateTime.now().millisecondsSinceEpoch}.db';
    late Directory tempDir;
    late Repository repo;
    late Database db;
    late OutboxStore outboxStore;
    late InboxStore inboxStore;
    late ConflictEngine conflictEngine;
    late InventoryMovementRepository movementRepo;

    const testStoreId = 'STORE_ALPHA';
    const testUserId = 'USER_ALICE';
    const testDeviceId = 'DEV_TABLET_01';

    setUp(() async {
      DatabaseHelper.setDbName(testDbName);
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, testDbName);
      if (File(path).existsSync()) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }

      tempDir = Directory.systemTemp.createTempSync('hive_outbox_test_');
      Hive.init(tempDir.path);

      await Hive.openBox(OutboxStore.primaryQueueBox);
      await Hive.openBox(OutboxStore.deadLetterBox);

      repo = Repository();
      movementRepo = InventoryMovementRepository();
      db = await DatabaseHelper().database;

      outboxStore = OutboxStore(
        getQueueBox: () => Hive.box(OutboxStore.primaryQueueBox),
        getFailedQueueBox: () => Hive.box(OutboxStore.deadLetterBox),
        getRepository: () => repo,
      );

      inboxStore = InboxStore();
      await inboxStore.init();

      conflictEngine = ConflictEngine();

      // Clean tables
      await db.delete('outbox_operations');
      await db.delete('conflict_records');
      await db.delete('inventory_movements');
      await db.delete('cache_inventory_quantities');
      await db.delete('inventory');
      await db.delete('customers');
      await db.delete('orders');

      // Seed baseline product
      await db.insert(
        'inventory',
        {
          'id': 'PROD_100',
          'storeId': testStoreId,
          'name': 'Espresso Blend',
          'category': 'Beverages',
          'price': 4.50,
          'quantity': 0,
          'trackStock': 1,
          'status': 'Active',
          'version': 1,
          'syncStatus': 'CONFIRMED',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Seed initial stock of 20 via purchase movement
      await movementRepo.insertMovement(
        InventoryMovement(
          id: const Uuid().v4(),
          storeId: testStoreId,
          itemId: 'PROD_100',
          type: MovementType.purchase,
          delta: 20,
          reason: 'Initial Batch',
          operationId: 'init_batch_prod_100',
          deviceId: testDeviceId,
          createdAt: DateTime.now(),
        ),
      );
    });

    tearDown(() async {
      await DatabaseHelper().close();
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, testDbName);
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

    // ─────────────────────────────────────────────────────────────
    // SCENARIO 1: Application killed while queueing (Persisted in Hive & SQLite)
    // ─────────────────────────────────────────────────────────────
    test(
        'Scenario 1: Application killed while queueing survives in dual persistence',
        () async {
      final op = OutboxOperation(
        operationId: 'op_queue_crash_01',
        storeId: testStoreId,
        userId: testUserId,
        deviceId: testDeviceId,
        collection: 'orders',
        entityId: 'ORD_CRASH_01',
        operation: 'create',
        payload: {'id': 'ORD_CRASH_01', 'total': 45.0, 'items': []},
        baseVersion: 1,
        newVersion: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        attemptCount: 0,
        nextRetryAt: DateTime.now().millisecondsSinceEpoch,
        state: OutboxState.pending,
      );

      await outboxStore.enqueue(op);

      // Verify Hive
      final hiveBox = Hive.box(OutboxStore.primaryQueueBox);
      expect(hiveBox.containsKey('op_queue_crash_01'), isTrue);
      final hiveOp = OutboxOperation.fromMap(
          hiveBox.get('op_queue_crash_01'), 'op_queue_crash_01');
      expect(hiveOp.state, equals(OutboxState.pending));
      expect(hiveOp.entityId, equals('ORD_CRASH_01'));
      expect(hiveOp.baseVersion, equals(1));
      expect(hiveOp.newVersion, equals(2));

      // Verify SQLite
      final sqliteOps = await repo.getOutboxOperations(storeId: testStoreId);
      expect(sqliteOps.length, equals(1));
      expect(sqliteOps.first.operationId, equals('op_queue_crash_01'));
      expect(sqliteOps.first.state, equals(OutboxState.pending));
      expect(sqliteOps.first.deviceId, equals(testDeviceId));
    });

    // ─────────────────────────────────────────────────────────────
    // SCENARIO 2: Killed during upload (Recovers IN_FLIGHT to PENDING)
    // ─────────────────────────────────────────────────────────────
    test(
        'Scenario 2: Killed during upload recovers stale IN_FLIGHT items to PENDING on startup',
        () async {
      final op = OutboxOperation(
        operationId: 'op_inflight_crash_02',
        storeId: testStoreId,
        userId: testUserId,
        deviceId: testDeviceId,
        collection: 'orders',
        entityId: 'ORD_INFLIGHT_01',
        operation: 'create',
        payload: {'id': 'ORD_INFLIGHT_01', 'total': 90.0},
        baseVersion: 1,
        newVersion: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        attemptCount: 1,
        nextRetryAt: DateTime.now().millisecondsSinceEpoch,
        state: OutboxState.pending,
      );

      await outboxStore.enqueue(op);
      await outboxStore.markInFlight(['op_inflight_crash_02']);

      // Confirm it transitioned to IN_FLIGHT
      final inFlightOps = await repo.getOutboxOperations(
          storeId: testStoreId, state: OutboxState.inFlight);
      expect(inFlightOps.length, equals(1));
      expect(inFlightOps.first.state, equals(OutboxState.inFlight));

      // Simulate process death & reboot: recoverStaleInFlight()
      await outboxStore.recoverStaleInFlight();

      // Verify it was reset to PENDING
      final recoveredOps = await repo.getOutboxOperations(
          storeId: testStoreId, state: OutboxState.pending);
      expect(recoveredOps.length, equals(1));
      expect(recoveredOps.first.operationId, equals('op_inflight_crash_02'));
      expect(recoveredOps.first.state, equals(OutboxState.pending));
    });

    // ─────────────────────────────────────────────────────────────
    // SCENARIO 3: Network drops after server commit / client retry is handled idempotently
    // ─────────────────────────────────────────────────────────────
    test(
        'Scenario 3: Network drops after server commit - client retry is idempotent',
        () async {
      final op = OutboxOperation(
        operationId: 'op_retry_netdrop_03',
        storeId: testStoreId,
        userId: testUserId,
        deviceId: testDeviceId,
        collection: 'inventory',
        entityId: 'PROD_100',
        operation: 'update',
        payload: {'id': 'PROD_100', 'price': 5.50},
        baseVersion: 1,
        newVersion: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        attemptCount: 0,
        nextRetryAt: DateTime.now().millisecondsSinceEpoch,
        state: OutboxState.pending,
      );

      await outboxStore.enqueue(op);
      // Simulate successful push on server
      await outboxStore.markPushed('op_retry_netdrop_03');

      // Client didn't receive ACK before socket closed, retries same operationId
      await outboxStore.enqueue(op);

      // Verify that outbox does not create duplicate entries for same operationId
      final ops = await repo.getOutboxOperations(storeId: testStoreId);
      final matching =
          ops.where((o) => o.operationId == 'op_retry_netdrop_03').toList();
      expect(matching.length, equals(1));
    });

    // ─────────────────────────────────────────────────────────────
    // SCENARIO 4: Inbound deduplication via InboxStore
    // ─────────────────────────────────────────────────────────────
    test(
        'Scenario 4: Timeout after successful Firestore write - duplicate operationId ignored by InboxStore',
        () async {
      const opId = 'inbound_op_timeout_444';
      const docId = 'ORD_INBOUND_99';

      // First delivery: not yet processed
      expect(
          inboxStore.isAlreadyProcessed('orders', docId,
              operationId: opId, version: 1),
          isFalse);

      // Record processing
      await inboxStore.recordProcessed('orders', docId,
          operationId: opId, version: 1);

      // Re-delivery of same message/operationId
      expect(
          inboxStore.isAlreadyProcessed('orders', docId,
              operationId: opId, version: 1),
          isTrue);

      // Higher version of doc should be allowed, but same or lower version blocked
      expect(
          inboxStore.isAlreadyProcessed('orders', docId, version: 1), isTrue);
      expect(
          inboxStore.isAlreadyProcessed('orders', docId, version: 2), isFalse);
    });

    // ─────────────────────────────────────────────────────────────
    // SCENARIO 5: Duplicate retry idempotency guard prevents duplicate stock movement
    // ─────────────────────────────────────────────────────────────
    test(
        'Scenario 5: Duplicate retry idempotency guard prevents duplicate stock movement',
        () async {
      const mvtOpId = 'sale_mvt_tx_unique_555';

      final movement = InventoryMovement(
        id: const Uuid().v4(),
        storeId: testStoreId,
        itemId: 'PROD_100',
        orderId: 'ORD_SALE_555',
        type: MovementType.sale,
        delta: -3,
        reason: 'POS Sale',
        operationId: mvtOpId,
        deviceId: testDeviceId,
        createdAt: DateTime.now(),
        version: 1,
      );

      // Initial execution
      final firstResult = await movementRepo.insertMovement(movement);
      expect(firstResult, isTrue);

      // Derived projection should be 20 - 3 = 17
      var currentStock =
          await movementRepo.getItemQuantity('PROD_100', storeId: testStoreId);
      expect(currentStock, equals(17));

      // Network retry executes with identical operationId
      final duplicateMovement = movement.copyWith(id: const Uuid().v4());
      final retryResult = await movementRepo.insertMovement(duplicateMovement);
      expect(
          retryResult, isFalse); // Successfully suppressed duplicate deduction

      // Derived projection must STILL be 17, NEVER 14!
      currentStock =
          await movementRepo.getItemQuantity('PROD_100', storeId: testStoreId);
      expect(currentStock, equals(17));
    });

    // ─────────────────────────────────────────────────────────────
    // SCENARIO 6: Device restart reloads outbox queue from disk
    // ─────────────────────────────────────────────────────────────
    test(
        'Scenario 6: Device restart reloads outbox queue from disk with all 14 fields',
        () async {
      final op = OutboxOperation(
        operationId: 'op_persist_restart_06',
        storeId: testStoreId,
        userId: testUserId,
        deviceId: testDeviceId,
        collection: 'inventory',
        entityId: 'PROD_100',
        operation: 'update',
        payload: {'price': 6.00},
        baseVersion: 2,
        newVersion: 3,
        createdAt: 1710000000000,
        attemptCount: 2,
        nextRetryAt: 1710000005000,
        state: OutboxState.failed,
        lastError: 'socket timeout',
      );

      await outboxStore.enqueue(op);

      // Simulate device restart: close and reopen database & Hive
      await DatabaseHelper().close();
      await Hive.box(OutboxStore.primaryQueueBox).close();

      final reopenedBox = await Hive.openBox(OutboxStore.primaryQueueBox);
      final reloadedOp = OutboxOperation.fromMap(
          reopenedBox.get('op_persist_restart_06'), 'op_persist_restart_06');

      expect(reloadedOp.operationId, equals('op_persist_restart_06'));
      expect(reloadedOp.storeId, equals(testStoreId));
      expect(reloadedOp.userId, equals(testUserId));
      expect(reloadedOp.deviceId, equals(testDeviceId));
      expect(reloadedOp.collection, equals('inventory'));
      expect(reloadedOp.entityId, equals('PROD_100'));
      expect(reloadedOp.operation, equals('UPDATE'));
      expect(reloadedOp.payload['price'], equals(6.00));
      expect(reloadedOp.baseVersion, equals(2));
      expect(reloadedOp.newVersion, equals(3));
      expect(reloadedOp.createdAt, equals(1710000000000));
      expect(reloadedOp.attemptCount, equals(2));
      expect(reloadedOp.nextRetryAt, equals(1710000005000));
      expect(reloadedOp.state, equals(OutboxState.failed));
      expect(reloadedOp.lastError, equals('socket timeout'));
    });

    // ─────────────────────────────────────────────────────────────
    // SCENARIO 7: Clock changes / skew survives backoff calculation
    // ─────────────────────────────────────────────────────────────
    test(
        'Scenario 7: Backoff calculation with randomized jitter produces bounded intervals',
        () {
      final now = DateTime.now().millisecondsSinceEpoch;

      final retry1 = OutboxStore.computeNextRetryAt(1);
      final retry2 = OutboxStore.computeNextRetryAt(2);
      final retry3 = OutboxStore.computeNextRetryAt(3);
      final retry6 = OutboxStore.computeNextRetryAt(6);

      // All future timestamps
      expect(retry1, greaterThanOrEqualTo(now));
      expect(retry2, greaterThan(now));
      expect(retry3, greaterThan(now));
      expect(retry6, greaterThan(now));

      // Higher attempts produce strictly larger or equal backoff bounds
      expect(retry6 - now, greaterThan(retry1 - now));
    });

    // ─────────────────────────────────────────────────────────────
    // SCENARIO 8: Two devices modifying same customer/product (Conflict Engine merges)
    // ─────────────────────────────────────────────────────────────
    test(
        'Scenario 8: Two devices modifying customer merges loyalty points; settings flags tax conflict',
        () {
      // Customer conflict: Local earned 30 points (total 130), Cloud earned 50 points (total 150)
      final localCust = {
        'id': 'CUST_01',
        'storeId': testStoreId,
        'name': 'Bob Smith',
        'loyaltyPoints': 130,
        'version': 2,
        'syncStatus': 'PENDING',
      };
      final cloudCust = {
        'id': 'CUST_01',
        'storeId': testStoreId,
        'name': 'Bob Smith',
        'loyaltyPoints': 150,
        'version': 2,
        'syncStatus': 'CONFIRMED',
      };

      final custResult = conflictEngine.resolve(
        collection: SyncCollectionRegistry.customers,
        cloudData: cloudCust,
        localData: localCust,
        storeId: testStoreId,
      );

      expect(custResult.action, equals(ResolutionAction.mergeApplied));
      expect(custResult.mergedData!['loyaltyPoints'], equals(150));

      // Settings conflict: Divergent tax rates generate ConflictRecord
      final localSettings = {
        'id': 'store_settings',
        'storeId': testStoreId,
        'taxRate': 8.25,
        'syncStatus': 'PENDING',
      };
      final cloudSettings = {
        'id': 'store_settings',
        'storeId': testStoreId,
        'taxRate': 9.00,
        'syncStatus': 'CONFIRMED',
      };

      final settingsResult = conflictEngine.resolve(
        collection: SyncCollectionRegistry.settings,
        cloudData: cloudSettings,
        localData: localSettings,
        storeId: testStoreId,
      );

      expect(settingsResult.action, equals(ResolutionAction.recordConflict));
      expect(settingsResult.conflictRecord, isNotNull);
      expect(settingsResult.conflictRecord!.conflictType,
          equals('TAX_RATE_DIVERGENCE'));
    });

    // ─────────────────────────────────────────────────────────────
    // SCENARIO 9: Two devices selling same inventory: authoritative ledger preserves both deductions
    // ─────────────────────────────────────────────────────────────
    test(
        'Scenario 9: Two devices selling same inventory - authoritative ledger records both deductions',
        () async {
      // Device 1 sells 4 units
      final mvtDev1 = InventoryMovement(
        id: 'MVT_DEV1_SALE',
        storeId: testStoreId,
        itemId: 'PROD_100',
        orderId: 'ORD_DEV1',
        type: MovementType.sale,
        delta: -4,
        operationId: 'op_sale_dev1',
        deviceId: testDeviceId,
        createdAt: DateTime.now(),
        version: 1,
      );

      // Device 2 sells 6 units
      final mvtDev2 = InventoryMovement(
        id: 'MVT_DEV2_SALE',
        storeId: testStoreId,
        itemId: 'PROD_100',
        orderId: 'ORD_DEV2',
        type: MovementType.sale,
        delta: -6,
        operationId: 'op_sale_dev2',
        deviceId: 'DEV_TABLET_02',
        createdAt: DateTime.now(),
        version: 1,
      );

      await movementRepo.insertMovement(mvtDev1);
      await movementRepo.insertMovement(mvtDev2);

      // Starting stock was 20. Net deductions: -4 and -6 = 10 remaining.
      final remainingStock =
          await movementRepo.getItemQuantity('PROD_100', storeId: testStoreId);
      expect(remainingStock, equals(10));

      // ConflictEngine strictly rejects LWW quantity overwrite
      final inventoryConflict = conflictEngine.resolve(
        collection: SyncCollectionRegistry.inventory,
        cloudData: {'id': 'PROD_100', 'quantity': 16, 'version': 2},
        localData: {
          'id': 'PROD_100',
          'quantity': 10,
          'version': 1,
          'syncStatus': 'PENDING'
        },
        storeId: testStoreId,
      );

      // Conflict is recorded and local stock quantity is preserved
      expect(inventoryConflict.action, equals(ResolutionAction.recordConflict));
      expect(inventoryConflict.conflictRecord!.conflictType,
          equals('INVENTORY_STOCK_DIVERGENCE'));
    });

    // ─────────────────────────────────────────────────────────────
    // SCENARIO 10: Reconnect after offline / verified orphan reconciliation safety
    // ─────────────────────────────────────────────────────────────
    test(
        'Scenario 10: Verified orphan reconciliation - skips cleanup for pending offline items',
        () async {
      // Seed an item that was created offline
      await db.insert(
        'orders',
        {
          'id': 'ORD_OFFLINE_ORPHAN',
          'storeId': testStoreId,
          'total': 25.0,
          'status': 'COMPLETED',
          'syncStatus': 'PENDING',
          'isDeleted': 0,
          'date': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Has pending outbox operation
      final op = OutboxOperation(
        operationId: 'op_order_pending_10',
        storeId: testStoreId,
        userId: testUserId,
        deviceId: testDeviceId,
        collection: 'orders',
        entityId: 'ORD_OFFLINE_ORPHAN',
        operation: 'create',
        payload: {'id': 'ORD_OFFLINE_ORPHAN'},
        baseVersion: 1,
        newVersion: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        attemptCount: 0,
        nextRetryAt: DateTime.now().millisecondsSinceEpoch,
        state: OutboxState.pending,
      );
      await outboxStore.enqueue(op);

      // Reconcile with cloud having 0 orders
      await repo.deleteOrphans('orders', testStoreId, []);

      // Even after deleteOrphans runs, ORD_OFFLINE_ORPHAN must survive because syncStatus is PENDING
      final order = await repo.getOrder('ORD_OFFLINE_ORPHAN');
      expect(order, isNotNull);
      expect(order!.syncStatus, equals('PENDING'));
    });
  });
}
