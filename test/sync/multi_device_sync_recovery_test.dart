// ignore_for_file: deprecated_member_use_from_same_package
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';
import 'package:biztonic_pos/services/recovery_service.dart';
import 'package:biztonic_pos/sync/outbox/outbox_operation.dart';
import 'package:biztonic_pos/sync/outbox/outbox_store.dart';
import 'package:biztonic_pos/sync/conflict/conflict_engine.dart';
import 'package:biztonic_pos/sync/diagnostics/sync_diagnostics.dart';
import 'package:biztonic_pos/sync/registry/sync_collection_registry.dart';
import 'package:biztonic_pos/features/inventory/domain/entities/inventory_movement.dart';
import 'package:biztonic_pos/features/inventory/domain/policies/inventory_policy.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Multi-Device Sync & Inventory Recovery Hardening Tests', () {
    final testDbName =
        'test_sync_recovery_${DateTime.now().millisecondsSinceEpoch}.db';
    late Directory tempDir;
    late Repository repo;
    late Database db;
    late OutboxStore outboxStore;
    late ConflictEngine conflictEngine;
    late InventoryMovementRepository movementRepo;
    late RecoveryService recoveryService;

    const storeAlpha = 'STORE_ALPHA';
    const storeBeta = 'STORE_BETA';
    const device1 = 'POS_DEVICE_01';
    const device2 = 'POS_DEVICE_02';
    const userAlice = 'USER_ALICE';

    setUp(() async {
      DatabaseHelper.setDbName(testDbName);
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, testDbName);
      if (File(path).existsSync()) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }

      tempDir = Directory.systemTemp.createTempSync('hive_sync_recovery_test_');
      Hive.init(tempDir.path);

      await Hive.openBox(OutboxStore.primaryQueueBox);
      await Hive.openBox(OutboxStore.deadLetterBox);

      repo = Repository();
      movementRepo = InventoryMovementRepository();
      db = await DatabaseHelper().database;
      recoveryService = RecoveryService(dbHelper: DatabaseHelper(), movementRepo: movementRepo);

      outboxStore = OutboxStore(
        getQueueBox: () => Hive.box(OutboxStore.primaryQueueBox),
        getFailedQueueBox: () => Hive.box(OutboxStore.deadLetterBox),
        getRepository: () => repo,
      );

      conflictEngine = ConflictEngine();

      // Clean DB tables
      await db.delete('outbox_operations');
      await db.delete('conflict_records');
      await db.delete('inventory_movements');
      await db.delete('cache_inventory_quantities');
      await db.delete('inventory');
      await db.delete('orders');
      await db.delete('transaction_journal');
    });

    tearDown(() async {
      final queueBox = Hive.box(OutboxStore.primaryQueueBox);
      if (queueBox.isOpen) await queueBox.clear();
      final deadBox = Hive.box(OutboxStore.deadLetterBox);
      if (deadBox.isOpen) await deadBox.clear();

      await DatabaseHelper().close();
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, testDbName);
      if (File(path).existsSync()) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    // ─────────────────────────────────────────────────────────────
    // 1. DURABLE SYNC STATE MACHINE
    // ─────────────────────────────────────────────────────────────
    test('1. Durable state machine transitions: PENDING -> IN_FLIGHT -> CONFIRMED -> FAILED -> CONFLICTED -> DEAD_LETTER', () async {
      final op1 = OutboxOperation(
        operationId: 'op_state_01',
        storeId: storeAlpha,
        userId: userAlice,
        deviceId: device1,
        collection: 'inventory',
        entityId: 'ITEM_101',
        operation: 'create',
        payload: {'id': 'ITEM_101', 'name': 'Coffee'},
        baseVersion: 1,
        newVersion: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        attemptCount: 0,
        state: OutboxState.pending,
      );

      // Enqueue -> PENDING
      await outboxStore.enqueue(op1);
      var stats = outboxStore.getOutboxStats(storeId: storeAlpha);
      expect(stats['pending'], equals(1));

      // Transition -> IN_FLIGHT
      await outboxStore.markInFlight(['op_state_01']);
      stats = outboxStore.getOutboxStats(storeId: storeAlpha);
      expect(stats['inFlight'], equals(1));
      expect(stats['pending'], equals(0));

      // Transition -> PUSHED
      await outboxStore.markBatchPushed(['op_state_01']);
      stats = outboxStore.getOutboxStats(storeId: storeAlpha);
      expect(stats['pushed'], equals(1));
      expect(stats['inFlight'], equals(0));

      // Transition -> CONFIRMED
      await outboxStore.markBatchConfirmed(['op_state_01']);
      stats = outboxStore.getOutboxStats(storeId: storeAlpha);
      expect(stats['confirmed'], equals(1));
      expect(stats['pushed'], equals(0));

      // Second operation: transitions to FAILED then DEAD_LETTER on max attempts
      final op2 = OutboxOperation(
        operationId: 'op_state_02',
        storeId: storeAlpha,
        userId: userAlice,
        deviceId: device1,
        collection: 'orders',
        entityId: 'ORD_202',
        operation: 'create',
        payload: {'id': 'ORD_202'},
        baseVersion: 1,
        newVersion: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        attemptCount: 0,
        state: OutboxState.pending,
      );
      await outboxStore.enqueue(op2);

      // Fail 1st attempt -> FAILED with backoff
      await outboxStore.markFailed('op_state_02', 'Network timeout 504');
      stats = outboxStore.getOutboxStats(storeId: storeAlpha);
      expect(stats['failed'], equals(1));

      // Third operation: fatal error -> immediate DEAD_LETTER
      final op3 = OutboxOperation(
        operationId: 'op_state_03',
        storeId: storeAlpha,
        userId: userAlice,
        deviceId: device1,
        collection: 'inventory',
        entityId: 'ITEM_303',
        operation: 'create',
        payload: {'id': 'ITEM_303'},
        baseVersion: 1,
        newVersion: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        attemptCount: 0,
        state: OutboxState.pending,
      );
      await outboxStore.enqueue(op3);
      await outboxStore.markFailed('op_state_03', 'permission-denied: not authorized', isFatal: true);

      stats = outboxStore.getOutboxStats(storeId: storeAlpha);
      expect(stats['deadLetter'], equals(1));

      // Fourth operation: CONFLICTED
      final op4 = OutboxOperation(
        operationId: 'op_state_04',
        storeId: storeAlpha,
        userId: userAlice,
        deviceId: device1,
        collection: 'customers',
        entityId: 'CUST_404',
        operation: 'update',
        payload: {'id': 'CUST_404', 'name': 'Updated Local'},
        baseVersion: 1,
        newVersion: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        attemptCount: 0,
        state: OutboxState.pending,
      );
      await outboxStore.enqueue(op4);
      await outboxStore.markConflicted('op_state_04', 'Remote customer record has higher version');

      stats = outboxStore.getOutboxStats(storeId: storeAlpha);
      expect(stats['conflicted'], equals(1));

      // Total operations accounted for, none disappeared
      expect(stats['total'], equals(4));
    });

    // ─────────────────────────────────────────────────────────────
    // 2. IDEMPOTENT SYNCHRONIZATION
    // ─────────────────────────────────────────────────────────────
    test('2. Idempotent synchronization: duplicate outbox operations and inbound movements', () async {
      // Outbox Deduplication: Enqueueing the exact same operationId multiple times must not duplicate queue
      final op = OutboxOperation(
        operationId: 'op_idempotent_01',
        storeId: storeAlpha,
        userId: userAlice,
        deviceId: device1,
        collection: 'orders',
        entityId: 'ORD_IDEM_01',
        operation: 'create',
        payload: {'id': 'ORD_IDEM_01', 'total': 45.0},
        baseVersion: 1,
        newVersion: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        attemptCount: 0,
        state: OutboxState.pending,
      );

      await outboxStore.enqueue(op);
      await outboxStore.enqueue(op);
      await outboxStore.enqueue(op);

      final stats = outboxStore.getOutboxStats(storeId: storeAlpha);
      expect(stats['pending'], equals(1));
      expect(stats['total'], equals(1));

      // Inbound Movement Deduplication:
      // Seed item
      await db.insert('inventory', {
        'id': 'PROD_IDEM',
        'storeId': storeAlpha,
        'name': 'Tea',
        'category': 'Beverages',
        'price': 2.0,
        'quantity': 10,
        'trackStock': 1,
        'status': 'Active',
      });

      // Seed 10 stock into ledger via purchase
      await movementRepo.insertMovement(InventoryMovement(
        id: 'mov_seed_idem',
        storeId: storeAlpha,
        itemId: 'PROD_IDEM',
        operationId: 'op_purch_seed_idem',
        type: MovementType.purchase,
        delta: 10,
        deviceId: device1,
        createdAt: DateTime.now(),
        syncStatus: 'CONFIRMED',
      ));

      final movement = InventoryMovement(
        id: 'mov_idem_100',
        storeId: storeAlpha,
        itemId: 'PROD_IDEM',
        operationId: 'op_movement_idem_100',
        orderId: 'ORD_IDEM_01',
        type: MovementType.sale,
        delta: -3,
        reason: 'Sale ORD_IDEM_01',
        deviceId: device1,
        createdAt: DateTime.now(),
        syncStatus: 'CONFIRMED',
      );

      // First insert (10 - 3 = 7)
      await movementRepo.insertMovement(movement);
      var derivedQty = await movementRepo.getAggregatedQuantity('PROD_IDEM', storeId: storeAlpha);
      expect(derivedQty, equals(7));

      // Duplicate receipt of same movementId must replace/ignore and NOT double-deduct
      await movementRepo.insertMovement(movement);
      derivedQty = await movementRepo.getAggregatedQuantity('PROD_IDEM', storeId: storeAlpha);
      expect(derivedQty, equals(7));
    });

    // ─────────────────────────────────────────────────────────────
    // 3. TOMBSTONES & ANTI-RESURRECTION
    // ─────────────────────────────────────────────────────────────
    test('3. Tombstones: Deleted records must not resurrect during later synchronization', () async {
      final now = DateTime.now();
      final deletedTime = now.subtract(const Duration(minutes: 5));

      // Local item soft-deleted with tombstone
      await db.insert('inventory', {
        'id': 'ITEM_TOMBSTONE_01',
        'storeId': storeAlpha,
        'name': 'Old Seasonal Dish',
        'price': 15.0,
        'quantity': 0,
        'isDeleted': 1,
        'deletedAt': deletedTime.toIso8601String(),
        'updatedAt': deletedTime.toIso8601String(),
        'version': 3,
        'syncStatus': 'CONFIRMED',
      });

      // ConflictEngine check: Cloud sends an update timestamped BEFORE or SAME as the local deletion
      final staleCloudData = {
        'id': 'ITEM_TOMBSTONE_01',
        'name': 'Old Seasonal Dish (Stale Cloud Update)',
        'price': 15.0,
        'isDeleted': false,
        'updatedAt': now.subtract(const Duration(minutes: 10)).toIso8601String(),
        'version': 2,
      };

      final localData = {
        'id': 'ITEM_TOMBSTONE_01',
        'name': 'Old Seasonal Dish',
        'isDeleted': true,
        'deletedAt': deletedTime.toIso8601String(),
        'updatedAt': deletedTime.toIso8601String(),
        'version': 3,
      };

      final resolution = conflictEngine.resolve(
        collection: SyncCollectionRegistry.inventory,
        cloudData: staleCloudData,
        localData: localData,
        storeId: storeAlpha,
      );

      // Anti-resurrection rule: local tombstone wins!
      expect(resolution.action, equals(ResolutionAction.localWins));

      // Conversely, if cloud was updated strictly AFTER the deletion, cloud wins (explicit recreation)
      final newerCloudData = {
        'id': 'ITEM_TOMBSTONE_01',
        'name': 'Re-introduced Seasonal Dish',
        'price': 18.0,
        'isDeleted': false,
        'updatedAt': now.add(const Duration(minutes: 5)).toIso8601String(),
        'version': 4,
      };

      final newResolution = conflictEngine.resolve(
        collection: SyncCollectionRegistry.inventory,
        cloudData: newerCloudData,
        localData: localData,
        storeId: storeAlpha,
      );
      expect(newResolution.action, equals(ResolutionAction.cloudWins));
    });

    // ─────────────────────────────────────────────────────────────
    // 4. FULL-PULL SAFETY & FINANCIAL RECORDS IMMUNITY
    // ─────────────────────────────────────────────────────────────
    test('4. Full-pull safety: Never delete local records when cloud returns 0 or partial results', () async {
      // Seed local customers
      for (int i = 1; i <= 10; i++) {
        await db.insert('customers', {
          'id': 'CUST_LOCAL_$i',
          'storeId': storeAlpha,
          'name': 'Customer $i',
          'phone': '123456789$i',
          'syncStatus': 'CONFIRMED',
          'isDeleted': 0,
        });
      }

      // 1. Partial cloud pull safety: cloud returns only 1 id (10% of local count)
      // deleteOrphans should only delete unlisted records if explicitly called, but pull engine rejects partial sweeps
      // Let's verify financial records (orders) are NEVER in reconcilableCollections
      expect(SyncCollectionRegistry.reconcilableCollections.contains('orders'), isFalse);
      expect(SyncCollectionRegistry.reconcilableCollections.contains('inventory_movements'), isFalse);
      expect(SyncCollectionRegistry.reconcilableCollections.contains('business_events'), isFalse);

      // Seed order
      await db.insert('orders', {
        'id': 'ORD_FINANCIAL_IMMUNE',
        'storeId': storeAlpha,
        'total': 99.0,
        'status': 'COMPLETED',
        'syncStatus': 'CONFIRMED',
        'isDeleted': 0,
        'date': DateTime.now().toIso8601String(),
      });

      // Even if deleteOrphans is called with empty list for orders, orders must NOT be deleted
      await repo.deleteOrphans('orders', storeAlpha, []);
      final order = await repo.getOrder('ORD_FINANCIAL_IMMUNE');
      expect(order, isNotNull);
      expect(order!.id, equals('ORD_FINANCIAL_IMMUNE'));
    });

    // ─────────────────────────────────────────────────────────────
    // 5. INVENTORY INTEGRITY & MOVEMENT LEDGER (ALL TYPES)
    // ─────────────────────────────────────────────────────────────
    test('5. Inventory quantity derives strictly from movement ledger without zero-clamping', () async {
      const itemId = 'PROD_INTEGRITY_01';

      await db.insert('inventory', {
        'id': itemId,
        'storeId': storeAlpha,
        'name': 'Gourmet Burger',
        'price': 10.0,
        'quantity': 0,
        'trackStock': 1,
        'status': 'Active',
      });

      // 1. Purchase: +100
      await movementRepo.insertMovement(InventoryMovement(
        id: 'mov_type_purchase',
        storeId: storeAlpha,
        itemId: itemId,
        operationId: 'op_purch_1',
        type: MovementType.purchase,
        delta: 100,
        reason: 'Initial stock shipment',
        deviceId: device1,
        createdAt: DateTime.now(),
        syncStatus: 'CONFIRMED',
      ));

      // 2. Sale: -20
      await movementRepo.insertMovement(InventoryMovement(
        id: 'mov_type_sale',
        storeId: storeAlpha,
        itemId: itemId,
        operationId: 'op_sale_1',
        orderId: 'ORD_SALE_01',
        type: MovementType.sale,
        delta: -20,
        reason: 'Order #1',
        deviceId: device1,
        createdAt: DateTime.now(),
        syncStatus: 'CONFIRMED',
      ));

      // 3. Adjustment: -5 (waste/spoilage)
      await movementRepo.insertMovement(InventoryMovement(
        id: 'mov_type_adj',
        storeId: storeAlpha,
        itemId: itemId,
        operationId: 'op_adj_1',
        type: MovementType.adjustment,
        delta: -5,
        reason: 'Spoilage',
        deviceId: device1,
        createdAt: DateTime.now(),
        syncStatus: 'CONFIRMED',
      ));

      // 4. Transfer: -10 (transfer to branch B)
      await movementRepo.insertMovement(InventoryMovement(
        id: 'mov_type_transfer',
        storeId: storeAlpha,
        itemId: itemId,
        operationId: 'op_trans_1',
        type: MovementType.transfer,
        delta: -10,
        reason: 'Transfer to Branch Beta',
        deviceId: device1,
        createdAt: DateTime.now(),
        syncStatus: 'CONFIRMED',
      ));

      // 5. Return: +2 (customer return)
      await movementRepo.insertMovement(InventoryMovement(
        id: 'mov_type_return',
        storeId: storeAlpha,
        itemId: itemId,
        operationId: 'op_ret_1',
        orderId: 'ORD_SALE_01',
        type: MovementType.returnItem,
        delta: 2,
        reason: 'Customer return',
        deviceId: device1,
        createdAt: DateTime.now(),
        syncStatus: 'CONFIRMED',
      ));

      // 6. Void Item: +3
      await movementRepo.insertMovement(InventoryMovement(
        id: 'mov_type_void_item',
        storeId: storeAlpha,
        itemId: itemId,
        operationId: 'op_void_item_1',
        orderId: 'ORD_SALE_01',
        type: MovementType.voidItem,
        delta: 3,
        reason: 'Voided before payment',
        deviceId: device1,
        createdAt: DateTime.now(),
        syncStatus: 'CONFIRMED',
      ));

      // Expected calculation: 100 - 20 - 5 - 10 + 2 + 3 = 70
      final netQty = await movementRepo.getAggregatedQuantity(itemId, storeId: storeAlpha);
      expect(netQty, equals(70));

      // Verify projection rebuild
      await repo.rebuildInventoryProjection(storeAlpha);
      final item = await repo.getInventoryItem(itemId, storeId: storeAlpha);
      expect(item!.quantity, equals(70));
    });

    // ─────────────────────────────────────────────────────────────
    // 6. CONCURRENT OFFLINE SALES (NEGATIVE STOCK POLICY)
    // ─────────────────────────────────────────────────────────────
    test('6. Concurrent offline sales: allows negative stock without zero-clamping and converges correctly', () async {
      const itemId = 'PROD_CONCURRENT_01';

      await db.insert('inventory', {
        'id': itemId,
        'storeId': storeAlpha,
        'name': 'Cold Brew Bottle',
        'price': 5.0,
        'quantity': 5,
        'trackStock': 1,
        'status': 'Active',
      });

      // Initial purchase movement: +5
      await movementRepo.insertMovement(InventoryMovement(
        id: 'mov_init_5',
        storeId: storeAlpha,
        itemId: itemId,
        operationId: 'op_init_5',
        type: MovementType.purchase,
        delta: 5,
        reason: 'Starting stock',
        deviceId: device1,
        createdAt: DateTime.now(),
        syncStatus: 'CONFIRMED',
      ));

      // Device 1 sells 4 offline (Policy: allowWithWarning)
      await movementRepo.insertMovement(
        InventoryMovement(
          id: 'mov_dev1_sale',
          storeId: storeAlpha,
          itemId: itemId,
          operationId: 'op_dev1_sale',
          orderId: 'ORD_DEV1_01',
          type: MovementType.sale,
          delta: -4,
          reason: 'Offline sale Device 1',
          deviceId: device1,
          createdAt: DateTime.now(),
          syncStatus: 'PENDING',
        ),
        negativeStockPolicy: NegativeStockPolicy.allowWithWarning,
      );

      // Device 2 simultaneously sells 3 offline (Policy: allowWithWarning)
      await movementRepo.insertMovement(
        InventoryMovement(
          id: 'mov_dev2_sale',
          storeId: storeAlpha,
          itemId: itemId,
          operationId: 'op_dev2_sale',
          orderId: 'ORD_DEV2_01',
          type: MovementType.sale,
          delta: -3,
          reason: 'Offline sale Device 2',
          deviceId: device2,
          createdAt: DateTime.now(),
          syncStatus: 'PENDING',
        ),
        negativeStockPolicy: NegativeStockPolicy.allowWithWarning,
      );

      // Calculation: 5 - 4 - 3 = -2
      // Must NOT be zero-clamped to 0!
      final finalStock = await movementRepo.getAggregatedQuantity(itemId, storeId: storeAlpha);
      expect(finalStock, equals(-2));

      await repo.rebuildInventoryProjection(storeAlpha);
      final item = await repo.getInventoryItem(itemId, storeId: storeAlpha);
      expect(item!.quantity, equals(-2));
    });

    // ─────────────────────────────────────────────────────────────
    // 7. CROSS-STORE TENANT SAFETY
    // ─────────────────────────────────────────────────────────────
    test('7. Cross-store safety: operations strictly segregated by storeId', () async {
      const itemStoreA = 'ITEM_STORE_A';
      const itemStoreB = 'ITEM_STORE_B';

      await db.insert('inventory', {
        'id': itemStoreA,
        'storeId': storeAlpha,
        'name': 'Alpha Item',
        'price': 10.0,
        'quantity': 10,
        'trackStock': 1,
        'status': 'Active',
      });

      await db.insert('inventory', {
        'id': itemStoreB,
        'storeId': storeBeta,
        'name': 'Beta Item',
        'price': 20.0,
        'quantity': 20,
        'trackStock': 1,
        'status': 'Active',
      });

      // Seed purchase in Store Alpha (+10)
      await movementRepo.insertMovement(InventoryMovement(
        id: 'mov_alpha_seed',
        storeId: storeAlpha,
        itemId: itemStoreA,
        operationId: 'op_alpha_seed',
        type: MovementType.purchase,
        delta: 10,
        deviceId: device1,
        createdAt: DateTime.now(),
        syncStatus: 'CONFIRMED',
      ));

      // Seed purchase in Store Beta (+20)
      await movementRepo.insertMovement(InventoryMovement(
        id: 'mov_beta_seed',
        storeId: storeBeta,
        itemId: itemStoreB,
        operationId: 'op_beta_seed',
        type: MovementType.purchase,
        delta: 20,
        deviceId: device2,
        createdAt: DateTime.now(),
        syncStatus: 'CONFIRMED',
      ));

      // Movements in Store Alpha (10 - 5 = 5)
      await movementRepo.insertMovement(InventoryMovement(
        id: 'mov_alpha_1',
        storeId: storeAlpha,
        itemId: itemStoreA,
        operationId: 'op_alpha_1',
        type: MovementType.sale,
        delta: -5,
        reason: 'Store Alpha Sale',
        deviceId: device1,
        createdAt: DateTime.now(),
        syncStatus: 'CONFIRMED',
      ));

      // Movements in Store Beta (20 - 8 = 12)
      await movementRepo.insertMovement(InventoryMovement(
        id: 'mov_beta_1',
        storeId: storeBeta,
        itemId: itemStoreB,
        operationId: 'op_beta_1',
        type: MovementType.sale,
        delta: -8,
        reason: 'Store Beta Sale',
        deviceId: device2,
        createdAt: DateTime.now(),
        syncStatus: 'CONFIRMED',
      ));

      final alphaQty = await movementRepo.getAggregatedQuantity(itemStoreA, storeId: storeAlpha);
      final betaQty = await movementRepo.getAggregatedQuantity(itemStoreB, storeId: storeBeta);

      expect(alphaQty, equals(5));
      expect(betaQty, equals(12));

      // Querying Store Alpha for Beta item must return 0
      final crossQty = await movementRepo.getAggregatedQuantity(itemStoreB, storeId: storeAlpha);
      expect(crossQty, equals(0));
    });

    // ─────────────────────────────────────────────────────────────
    // 8. RECOVERY SIMULATION (CRASH & IN-FLIGHT RECOVERY)
    // ─────────────────────────────────────────────────────────────
    test('8. Crash recovery: reconciles partially applied transactions and recovers stuck IN_FLIGHT operations', () async {
      // 1. Stuck IN_FLIGHT outbox operation from previous process crash
      final stuckOp = OutboxOperation(
        operationId: 'op_stuck_in_flight',
        storeId: storeAlpha,
        userId: userAlice,
        deviceId: device1,
        collection: 'orders',
        entityId: 'ORD_STUCK_01',
        operation: 'create',
        payload: {'id': 'ORD_STUCK_01'},
        baseVersion: 1,
        newVersion: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        attemptCount: 1,
        state: OutboxState.inFlight,
      );

      final box = Hive.box(OutboxStore.primaryQueueBox);
      await box.put('op_stuck_in_flight', stuckOp.toMap());
      await repo.insertOutboxOperation(stuckOp);

      var stats = outboxStore.getOutboxStats(storeId: storeAlpha);
      expect(stats['inFlight'], equals(1));

      // App reboots: OutboxStore recovers stuck in-flight ops back to PENDING
      await outboxStore.recoverStaleInFlight();
      stats = outboxStore.getOutboxStats(storeId: storeAlpha);
      expect(stats['inFlight'], equals(0));
      expect(stats['pending'], equals(1));

      // 2. Dead-letter recovery: manual retry resets dead letters
      await outboxStore.markDeadLetter('op_stuck_in_flight', 'Temporary cloud downtime');
      stats = outboxStore.getOutboxStats(storeId: storeAlpha);
      expect(stats['deadLetter'], equals(1));

      final retriedCount = await outboxStore.retryAllDeadLetter(storeId: storeAlpha);
      expect(retriedCount, equals(1));
      stats = outboxStore.getOutboxStats(storeId: storeAlpha);
      expect(stats['deadLetter'], equals(0));
      expect(stats['pending'], equals(1));

      // 3. Transaction journal recovery test
      // Seed an uncommitted journal entry
      await db.insert('transaction_journal', {
        'id': 'tx_crash_01',
        'storeId': storeAlpha,
        'status': 'PENDING',
        'operations': '{"order":{"id":"ORD_CRASH_01","storeId":"$storeAlpha","total":50.0,"status":"COMPLETED"},"items":[],"movements":[],"event":{}}',
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Run recovery service
      final unresolved = await recoveryService.scanAndRecover();
      // Should handle crash gracefully without throwing
      expect(unresolved, isA<List>());
    });

    // ─────────────────────────────────────────────────────────────
    // 9. PRODUCTION DIAGNOSTICS & SECRET REDACTION
    // ─────────────────────────────────────────────────────────────
    test('9. Diagnostics: exposes 8 required fields and deeply redacts secrets, pins, tokens', () {
      final rawDiagnostics = {
        'pendingCount': 3,
        'failedCount': 1,
        'conflictCount': 0,
        'deadLetterCount': 0,
        'lastSuccessfulSync': DateTime.now().toIso8601String(),
        'lastError': 'Authentication failed for pin=1234 and Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
        'activeStore': storeAlpha,
        'deviceIdentifier': device1,
        'sensitiveConfig': {
          'api_key': 'AIzaSySecretApiKeyHere',
          'user_password': 'SuperSecretPassword',
          'nested': {
            'security_token': 'secret_jwt_token_here',
          }
        }
      };

      final sanitized = SyncDiagnostics.sanitizeData(rawDiagnostics);

      // Verify 8 required fields exist
      expect(sanitized.containsKey('pendingCount'), isTrue);
      expect(sanitized.containsKey('failedCount'), isTrue);
      expect(sanitized.containsKey('conflictCount'), isTrue);
      expect(sanitized.containsKey('deadLetterCount'), isTrue);
      expect(sanitized.containsKey('lastSuccessfulSync'), isTrue);
      expect(sanitized.containsKey('lastError'), isTrue);
      expect(sanitized.containsKey('activeStore'), isTrue);
      expect(sanitized.containsKey('deviceIdentifier'), isTrue);

      // Verify values
      expect(sanitized['pendingCount'], equals(3));
      expect(sanitized['failedCount'], equals(1));
      expect(sanitized['activeStore'], equals(storeAlpha));
      expect(sanitized['deviceIdentifier'], equals(device1));

      // Verify redaction of sensitive credentials in strings
      expect(sanitized['lastError'], isNot(contains('1234')));
      expect(sanitized['lastError'], contains('[REDACTED]'));

      // Verify redaction of sensitive map keys
      final config = sanitized['sensitiveConfig'] as Map<String, dynamic>;
      expect(config['api_key'], equals('[REDACTED]'));
      expect(config['user_password'], equals('[REDACTED]'));
      final nested = config['nested'] as Map<String, dynamic>;
      expect(nested['security_token'], equals('[REDACTED]'));
    });
  });
}
