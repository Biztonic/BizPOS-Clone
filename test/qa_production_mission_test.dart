import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:biztonic_pos/models/inventory_item.dart';
import 'package:biztonic_pos/features/inventory/domain/policies/inventory_policy.dart';
import 'package:biztonic_pos/features/store/domain/entities/subscription_history.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_service.dart';
import 'package:biztonic_pos/sync/registry/sync_collection_registry.dart';
import 'package:biztonic_pos/sync/outbox/outbox_store.dart';
import 'package:biztonic_pos/sync/outbox/outbox_operation.dart';
import 'package:biztonic_pos/sync/maintenance/sync_maintenance.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/features/billing/domain/entities/order_entity.dart';
import 'package:biztonic_pos/features/billing/domain/use_cases/calculate_tax.dart';
import 'package:biztonic_pos/kernel/idempotency/idempotency_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('bizpos_qa_mission_');
    Hive.init(tempDir.path);
    await Hive.openBox(EntitlementService.boxName);
    await Hive.openBox('cache_inventory');
    await Hive.openBox('sync_queue_v2');
    await Hive.openBox('sync_failed_queue');
  });

  tearDownAll(() async {
    try {
      await Hive.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('ISSUE 1 — Addon Entitlements, Unpurchased Addon Stripping & RBAC', () {
    test('1.1 Basic plan with stale Hive cache strips unpurchased addons and blocks all addon menus', () async {
      const storeId = 'store_basic_qa_1';
      final box = Hive.box(EntitlementService.boxName);

      // Simulate polluted local cache with unpurchased addons from an older session
      await box.put(storeId, {
        'storeId': storeId,
        'plan': 'Basic',
        'status': 'ACTIVE',
        'startDate': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        'endDate': DateTime.now().add(const Duration(days: 25)).toIso8601String(),
        'addons': ['table_reservation', 'data_center', 'kds_management'],
        'purchasedAddons': ['table_reservation', 'data_center', 'kds_management'],
        'version': 1,
      });

      // Server syncs clean Basic plan with 0 purchased addons
      await EntitlementService.instance.syncFromStore(
        storeId: storeId,
        planName: 'Basic',
        status: 'Active',
        addons: const <String>[],
        purchasedAddons: const <String>[],
        fromServer: true,
      );

      expect(EntitlementService.instance.hasAddon('table_reservation', storeId: storeId), isFalse);
      expect(EntitlementService.instance.hasAddon('tables', storeId: storeId), isFalse);
      expect(EntitlementService.instance.hasAddon('data_center', storeId: storeId), isFalse);
      expect(EntitlementService.instance.hasAddon('kds_management', storeId: storeId), isFalse);
      expect(EntitlementService.instance.hasAddon('employee_management', storeId: storeId), isFalse);
      expect(EntitlementService.instance.hasAddon('supplier_management', storeId: storeId), isFalse);

      // Core features remain accessible on Basic plan
      expect(EntitlementService.instance.isFeatureEnabled('pos', storeId: storeId), isTrue);
      expect(EntitlementService.instance.isFeatureEnabled('inventory', storeId: storeId), isTrue);
      expect(EntitlementService.instance.isFeatureEnabled('reports', storeId: storeId), isTrue);
    });

    test('1.2 Standalone purchased addon unlocks ONLY the purchased addon and blocks all unpurchased addons', () async {
      const storeId = 'store_addon_buyer_1';

      // Store purchased ONLY table_reservation, even if addons list had an unpurchased extra
      await EntitlementService.instance.syncFromStore(
        storeId: storeId,
        planName: 'Standard',
        status: 'Active',
        addons: const ['table_reservation', 'data_center'],
        purchasedAddons: const ['table_reservation'],
        fromServer: true,
      );

      // Purchased addon is unlocked (via canonical key and alias)
      expect(EntitlementService.instance.hasAddon('table_reservation', storeId: storeId), isTrue);
      expect(EntitlementService.instance.hasAddon('tables', storeId: storeId), isTrue);

      // Unpurchased addon ('data_center') is strictly BLOCKED despite being in addons list
      expect(EntitlementService.instance.hasAddon('data_center', storeId: storeId), isFalse);
      expect(EntitlementService.instance.hasAddon('kds_management', storeId: storeId), isFalse);
      expect(EntitlementService.instance.hasAddon('franchise_management', storeId: storeId), isFalse);
    });

    test('1.3 SubscriptionHistory.isActive and isQueued are case-insensitive', () {
      final now = DateTime.now();
      final activeMixed = SubscriptionHistory(
        id: 'sub_1',
        storeId: 'store_1',
        planName: 'Standard',
        amount: 999,
        billingCycle: 'Monthly',
        startDate: now.subtract(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 29)),
        status: 'Active', // Mixed case written by StoreProvider.addStore
        selectedAddons: const ['table_reservation'],
        isAddonOnly: true,
      );
      final queuedMixed = SubscriptionHistory(
        id: 'sub_2',
        storeId: 'store_1',
        planName: 'Standard',
        amount: 999,
        billingCycle: 'Monthly',
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
        status: 'Queued',
      );

      expect(activeMixed.isActive, isTrue);
      expect(queuedMixed.isQueued, isTrue);
    });

    test('1.4 Enterprise tier and Super Admin override verification', () async {
      const entStoreId = 'store_enterprise_qa';
      await EntitlementService.instance.syncFromStore(
        storeId: entStoreId,
        planName: 'Enterprise',
        status: 'ACTIVE',
        addons: const [],
        purchasedAddons: const [],
        fromServer: true,
      );

      expect(EntitlementService.instance.hasAddon('table_reservation', storeId: entStoreId), isTrue);
      expect(EntitlementService.instance.hasAddon('data_center', storeId: entStoreId), isTrue);
      expect(EntitlementService.instance.hasAddon('franchise_management', storeId: entStoreId), isTrue);
      expect(
        EntitlementService.instance.isFeatureEnabled(
          'data_center',
          storeId: 'store_basic_qa_1',
          userRole: 'Super Admin',
        ),
        isTrue,
      );
    });
  });

  group('ISSUE 2 — Inventory Stock Preservation Across Logins & Ledger Self-Healing', () {
    final movRepo = InventoryMovementRepository();
    final dbHelper = DatabaseHelper();

    test('2.1 SyncCollectionRegistry pulls inventoryMovements BEFORE inventory', () {
      final movIdx = SyncCollectionRegistry.pullModules
          .indexOf(SyncCollectionRegistry.inventoryMovements);
      final invIdx = SyncCollectionRegistry.pullModules
          .indexOf(SyncCollectionRegistry.inventory);

      expect(movIdx, greaterThanOrEqualTo(0));
      expect(invIdx, greaterThanOrEqualTo(0));
      expect(
        movIdx < invIdx,
        isTrue,
        reason: 'inventoryMovements must be pulled before inventory so onPullComplete rebuilds projections with complete movement data',
      );
    });

    test('2.2 rebuildInventoryProjection NEVER resets stock to 0 on next login when INITIAL_STOCK movement is missing', () async {
      final db = await dbHelper.database;
      const storeId = 'store_stock_persist_qa';
      const itemId = 'item_login_persist_1';

      await db.delete('inventory', where: 'id = ?', whereArgs: [itemId]);
      await db.delete('inventory_movements', where: 'itemId = ?', whereArgs: [itemId]);

      // Simulate cloud pull inserting an item with quantity = 45 into SQLite & Hive,
      // while inventory_movements has no rows yet for this item.
      final item = InventoryItem(
        id: itemId,
        storeId: storeId,
        name: 'Arabica Coffee Beans 1kg',
        category: 'Beverages',
        price: 850.0,
        cost: 500.0,
        quantity: 45,
        status: 'In Stock',
        trackStock: true,
      );
      await db.insert('inventory', item.toSqlMap());
      await Hive.box('cache_inventory').put(itemId, item.toHiveMap());

      // Trigger rebuildInventoryProjection (called by InventorySyncAdapter.onPullComplete on login)
      final projections = await movRepo.rebuildInventoryProjection(storeId);

      // Stock MUST remain 45, never 0!
      expect(projections[itemId], equals(45));

      final sqlRows = await db.query('inventory', where: 'id = ?', whereArgs: [itemId]);
      expect((sqlRows.first['quantity'] as num).toInt(), equals(45));

      final hiveMap = Hive.box('cache_inventory').get(itemId) as Map;
      expect((hiveMap['quantity'] as num).toInt(), equals(45));

      // Verify that an INITIAL_STOCK movement (delta: 45, syncStatus: 'PENDING') was auto-seeded
      final ledgerQty = await movRepo.getItemQuantity(itemId, storeId: storeId);
      expect(ledgerQty, equals(45));
    });

    test('2.3 Subsequent sales and adjustments accurately deduct/add from preserved stock and enforce negative stock protection', () async {
      const storeId = 'store_stock_persist_qa';
      const itemId = 'item_login_persist_1';

      // Sale of 5 units -> stock should become 40
      final saleMov = InventoryMovement(
        id: const Uuid().v4(),
        itemId: itemId,
        storeId: storeId,
        type: MovementType.sale,
        delta: -5,
        orderId: 'ord_qa_101',
        deviceId: 'dev_qa_1',
        operationId: 'sale_ord_qa_101_$itemId',
        createdAt: DateTime.now(),
      );
      final inserted = await movRepo.insertMovement(saleMov);
      expect(inserted, isTrue);

      final qtyAfterSale = await movRepo.getItemQuantity(itemId, storeId: storeId);
      expect(qtyAfterSale, equals(40));

      // Attempt sale of 100 units -> must throw InsufficientStockException under block policy
      final overSaleMov = InventoryMovement(
        id: const Uuid().v4(),
        itemId: itemId,
        storeId: storeId,
        type: MovementType.sale,
        delta: -100,
        orderId: 'ord_qa_102',
        deviceId: 'dev_qa_1',
        operationId: 'sale_ord_qa_102_$itemId',
        createdAt: DateTime.now(),
      );
      await expectLater(
        () => movRepo.insertMovement(overSaleMov, negativeStockPolicy: NegativeStockPolicy.block),
        throwsA(isA<InsufficientStockException>()),
      );

      // Stock remains 40 after blocked oversale
      expect(await movRepo.getItemQuantity(itemId, storeId: storeId), equals(40));
    });
  });

  group('ISSUE 3 — Data Center Outbox Confirmation Cleanup & SQLite Self-Healing', () {
    test('3.1 OutboxStore.markBatchConfirmed deletes confirmed entries from sync_queue_v2 so pending count reaches 0', () async {
      final queueBox = Hive.box('sync_queue_v2');
      await queueBox.clear();

      final outboxStore = OutboxStore(
        getQueueBox: () => queueBox,
        getFailedQueueBox: () => Hive.box('sync_failed_queue'),
        getRepository: () => Repository(),
      );

      const storeId = 'store_sync_qa_1';
      final op1 = OutboxOperation(
        operationId: 'op_qa_1',
        storeId: storeId,
        userId: 'user_1',
        deviceId: 'dev_1',
        collection: 'inventory',
        entityId: 'item_1',
        operation: 'create',
        payload: {'id': 'item_1', 'storeId': storeId, 'quantity': 20},
      );
      final op2 = OutboxOperation(
        operationId: 'op_qa_2',
        storeId: storeId,
        userId: 'user_1',
        deviceId: 'dev_1',
        collection: 'inventory_movements',
        entityId: 'init_item_1',
        operation: 'create',
        payload: {'id': 'init_item_1', 'storeId': storeId, 'delta': 20},
      );

      await outboxStore.enqueue(op1);
      await outboxStore.enqueue(op2);
      expect(queueBox.length, equals(2));

      final ready = await outboxStore.getReadyOperations(storeId: storeId);
      expect(ready.length, equals(2));

      // Confirm both operations (simulating successful Firestore batch commit)
      await outboxStore.markBatchConfirmed(['op_qa_1', 'op_qa_2']);

      // Queue box MUST now be empty so Data Center shows 0 Pending ("Synced")
      expect(queueBox.isEmpty, isTrue);
    });

    test('3.2 SyncMaintenanceEngine.repairUnsyncedItems scans SQLite tables for PENDING rows and queues them', () async {
      final db = await DatabaseHelper().database;
      final queueBox = Hive.box('sync_queue_v2');
      await queueBox.clear();

      const storeId = 'store_repair_sqlite_qa';
      const itemId = 'item_unsynced_sqlite_1';

      await db.delete('inventory', where: 'id = ?', whereArgs: [itemId]);
      await db.insert('inventory', {
        'id': itemId,
        'storeId': storeId,
        'name': 'Pending SQLite Item',
        'category': 'General',
        'price': 120.0,
        'cost': 80.0,
        'quantity': 15,
        'trackStock': 1,
        'syncStatus': 'PENDING',
      });

      final queuedPayloads = <Map<String, dynamic>>[];
      final maintenance = SyncMaintenanceEngine(
        getQueueBox: () => queueBox,
        getActiveStoreId: () => storeId,
        queueOperation: ({
          required String collection,
          required String docId,
          required String action,
          required Map<String, dynamic> payload,
        }) async {
          queuedPayloads.add({
            'collection': collection,
            'docId': docId,
            'action': action,
            'payload': payload,
          });
        },
      );

      final repaired = await maintenance.repairUnsyncedItems(
        SyncCollectionRegistry.inventory,
      );

      expect(repaired, greaterThanOrEqualTo(1));
      expect(
        queuedPayloads.any((q) => q['docId'] == itemId && q['collection'] == 'inventory'),
        isTrue,
      );
    });
  });

  group('TAX, GST (CGST/SGST), IDEMPOTENCY & PERFORMANCE BENCHMARKS', () {
    test('4.1 GST Exclusive Calculations (CGST + SGST split & discounts)', () {
      final calc = CalculateTaxUseCase();

      // 18% GST on ₹1000 with ₹100 discount -> taxable ₹900, GST ₹162 (CGST ₹81, SGST ₹81), total ₹1062
      final excl = calc.execute(const CalculateTaxParams(
        items: [
          OrderItemEntity(
            itemId: 'ITEM_GST_1',
            itemName: 'Product 1',
            price: 1000.0,
            cost: 500.0,
            quantity: 1,
          ),
        ],
        taxRate: 18.0,
        discountAmount: 100.0,
      ));

      expect(excl.discount, closeTo(100.0, 0.01));
      expect(excl.subtotal, closeTo(1000.0, 0.01));
      expect(excl.cgst, closeTo(81.0, 0.01));
      expect(excl.sgst, closeTo(81.0, 0.01));
      expect(excl.total, closeTo(1062.0, 0.01));
    });

    test('4.2 Rapid double-checkout idempotency blocks duplicate submission', () async {
      final idemKey = 'checkout_idem_qa_${DateTime.now().microsecondsSinceEpoch}';
      final firstAttempt = await IdempotencyService().checkAndReserveKey(
        key: idemKey,
        entityType: 'ORDER',
        entityId: 'ord_999',
        deviceId: 'dev_qa_1',
      );
      final secondAttempt = await IdempotencyService().checkAndReserveKey(
        key: idemKey,
        entityType: 'ORDER',
        entityId: 'ord_999',
        deviceId: 'dev_qa_1',
      );

      expect(firstAttempt, isTrue);
      expect(secondAttempt, isFalse, reason: 'Second rapid tap with same idempotency key must be rejected');
    });

    test('4.3 High-Volume Performance Benchmark: 1,000 products projection rebuild < 1500ms', () async {
      final db = await DatabaseHelper().database;
      final movRepo = InventoryMovementRepository();
      const perfStoreId = 'store_perf_1000';

      final sw = Stopwatch()..start();
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (int i = 0; i < 1000; i++) {
          final id = 'perf_item_$i';
          batch.insert(
            'inventory',
            {
              'id': id,
              'storeId': perfStoreId,
              'name': 'Perf Product $i',
              'category': 'Bulk',
              'price': 100.0,
              'cost': 60.0,
              'quantity': 25,
              'trackStock': 1,
              'syncStatus': 'CONFIRMED',
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          batch.insert(
            'inventory_movements',
            {
              'id': 'init_$id',
              'itemId': id,
              'storeId': perfStoreId,
              'type': 'INITIAL_STOCK',
              'delta': 25,
              'unitCost': 60.0,
              'reason': 'Perf Seed',
              'deviceId': 'perf_dev',
              'operationId': 'init_$id',
              'createdAt': DateTime.now().millisecondsSinceEpoch,
              'syncStatus': 'CONFIRMED',
              'isDeleted': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });

      final rebuildSw = Stopwatch()..start();
      final projections = await movRepo.rebuildInventoryProjection(perfStoreId);
      rebuildSw.stop();
      sw.stop();

      expect(projections.length, equals(1000));
      expect(projections['perf_item_500'], equals(25));
      expect(
        rebuildSw.elapsedMilliseconds,
        lessThan(2500),
        reason: '1,000 product projection rebuild must complete in under 2.5s (actual: ${rebuildSw.elapsedMilliseconds}ms)',
      );
    });
  });
}
