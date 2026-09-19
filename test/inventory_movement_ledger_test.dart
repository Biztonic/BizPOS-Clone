import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';
import 'package:biztonic_pos/features/inventory/domain/entities/inventory_movement.dart';
import 'package:biztonic_pos/features/inventory/domain/policies/inventory_policy.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Authoritative Inventory Movement Ledger Tests', () {
    late InventoryMovementRepository repo;
    late Database db;
    final testDbName =
        'test_ledger_${DateTime.now().millisecondsSinceEpoch}.db';
    const storeA = 'STORE_ALPHA';
    const storeB = 'STORE_BETA';
    const item1 = 'ITEM_BURGER_01';
    const item2 = 'ITEM_FRIES_01';
    const itemStoreB = 'ITEM_BETA_01';

    setUp(() async {
      DatabaseHelper.setDbName(testDbName);
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, testDbName);
      if (File(path).existsSync()) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }

      repo = InventoryMovementRepository();
      db = await DatabaseHelper().database;

      // Ensure clean state before each test
      await db.delete('inventory_movements');
      await db.delete('cache_inventory_quantities');
      await db.delete('orders');
      await db.delete('inventory');

      // Seed catalog items
      await db.insert(
          'inventory',
          {
            'id': item1,
            'storeId': storeA,
            'name': 'Classic Burger',
            'category': 'Food',
            'price': 120.0,
            'quantity': 0,
            'trackStock': 1,
            'status': 'Active',
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert(
          'inventory',
          {
            'id': item2,
            'storeId': storeA,
            'name': 'French Fries',
            'category': 'Food',
            'price': 60.0,
            'quantity': 0,
            'trackStock': 1,
            'status': 'Active',
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert(
          'inventory',
          {
            'id': itemStoreB,
            'storeId': storeB,
            'name': 'Beta Special',
            'category': 'Food',
            'price': 200.0,
            'quantity': 0,
            'trackStock': 1,
            'status': 'Active',
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
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
    });

    // ─── 1. PURCHASE ─────────────────────────────────────────
    test('1. purchase: increments ledger and updates derived projections',
        () async {
      final movement = InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.purchase,
        delta: 50,
        unitCost: 45.0,
        reason: 'Supplier Purchase PO-101',
        deviceId: 'DEV_MAIN',
        operationId: 'po_101_$item1',
        createdAt: DateTime.now(),
      );

      final success = await repo.insertMovement(movement);
      expect(success, isTrue);

      // Verify ledger sum
      final qty = await repo.getItemQuantity(item1, storeId: storeA);
      expect(qty, equals(50));

      // Verify SQLite projection in cache_inventory_quantities
      final cacheRows = await db.query('cache_inventory_quantities',
          where: 'itemId = ? AND storeId = ?', whereArgs: [item1, storeA]);
      expect(cacheRows.first['quantity'], equals(50));

      // Verify SQLite projection in inventory table
      final invRows =
          await db.query('inventory', where: 'id = ?', whereArgs: [item1]);
      expect(invRows.first['quantity'], equals(50));
    });

    // ─── 2. SALE ─────────────────────────────────────────────
    test('2. sale: creates exactly one stock deduction movement', () async {
      // Seed 50 stock via purchase
      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.purchase,
        delta: 50,
        unitCost: 45.0,
        deviceId: 'DEV_MAIN',
        createdAt: DateTime.now(),
      ));

      // Perform sale of 15 units
      final saleMovement = InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.sale,
        delta: -15,
        orderId: 'ORD_9001',
        reason: 'Sale',
        deviceId: 'DEV_MAIN',
        operationId: 'sale_ORD_9001_$item1',
        createdAt: DateTime.now(),
      );

      final success = await repo.insertMovement(saleMovement);
      expect(success, isTrue);

      // Ledger sum must now be 35
      final qty = await repo.getItemQuantity(item1, storeId: storeA);
      expect(qty, equals(35));

      // Both projections must be exactly 35
      final cacheRows = await db.query('cache_inventory_quantities',
          where: 'itemId = ?', whereArgs: [item1]);
      expect(cacheRows.first['quantity'], equals(35));

      final invRows =
          await db.query('inventory', where: 'id = ?', whereArgs: [item1]);
      expect(invRows.first['quantity'], equals(35));
    });

    // ─── 3. REFUND ───────────────────────────────────────────
    test(
        '3. refund: requires original sale validation and prevents over-refunding',
        () async {
      // Seed 20 stock and sell 10
      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.purchase,
        delta: 20,
        deviceId: 'DEV_MAIN',
        createdAt: DateTime.now(),
      ));

      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.sale,
        delta: -10,
        orderId: 'ORD_SALE_55',
        deviceId: 'DEV_MAIN',
        operationId: 'sale_ORD_SALE_55_$item1',
        createdAt: DateTime.now(),
      ));

      // Attempt 3a: Refund on non-existent order must throw InvalidRefundException
      expect(
        () => repo.insertMovement(InventoryMovement(
          id: const Uuid().v4(),
          itemId: item1,
          storeId: storeA,
          type: MovementType.refund,
          delta: 5,
          orderId: 'NON_EXISTENT_ORDER',
          deviceId: 'DEV_MAIN',
          operationId: 'refund_fake_1',
          createdAt: DateTime.now(),
        )),
        throwsA(isA<InvalidRefundException>()),
      );

      // Attempt 3b: Refund more than sold (12 > 10) must throw InvalidRefundException
      expect(
        () => repo.insertMovement(InventoryMovement(
          id: const Uuid().v4(),
          itemId: item1,
          storeId: storeA,
          type: MovementType.refund,
          delta: 12,
          orderId: 'ORD_SALE_55',
          deviceId: 'DEV_MAIN',
          operationId: 'refund_over_1',
          createdAt: DateTime.now(),
        )),
        throwsA(isA<InvalidRefundException>()),
      );

      // Attempt 3c: Valid partial refund of 4 units succeeds
      final refund1 = await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.refund,
        delta: 4,
        orderId: 'ORD_SALE_55',
        deviceId: 'DEV_MAIN',
        operationId: 'refund_valid_1',
        createdAt: DateTime.now(),
      ));
      expect(refund1, isTrue);
      expect(await repo.getItemQuantity(item1, storeId: storeA), equals(14));

      // Attempt 3d: Valid second refund of remaining 6 units succeeds
      final refund2 = await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.refund,
        delta: 6,
        orderId: 'ORD_SALE_55',
        deviceId: 'DEV_MAIN',
        operationId: 'refund_valid_2',
        createdAt: DateTime.now(),
      ));
      expect(refund2, isTrue);
      expect(await repo.getItemQuantity(item1, storeId: storeA), equals(20));

      // Attempt 3e: Third refund of 1 unit exceeds total sold (already refunded 10 of 10) -> throws
      expect(
        () => repo.insertMovement(InventoryMovement(
          id: const Uuid().v4(),
          itemId: item1,
          storeId: storeA,
          type: MovementType.refund,
          delta: 1,
          orderId: 'ORD_SALE_55',
          deviceId: 'DEV_MAIN',
          operationId: 'refund_exceed_3',
          createdAt: DateTime.now(),
        )),
        throwsA(isA<InvalidRefundException>()),
      );
    });

    // ─── 4. VOID ─────────────────────────────────────────────
    test('4. void: creates VOID_REVERSAL movements and restores stock',
        () async {
      // Seed stock for item1 (10) and item2 (10)
      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.purchase,
        delta: 10,
        deviceId: 'DEV_1',
        createdAt: DateTime.now(),
      ));
      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item2,
        storeId: storeA,
        type: MovementType.purchase,
        delta: 10,
        deviceId: 'DEV_1',
        createdAt: DateTime.now(),
      ));

      // Place order: 3 burgers, 5 fries
      const voidOrderId = 'ORD_TO_VOID_1';
      await db.insert('orders', {
        'id': voidOrderId,
        'storeId': storeA,
        'total': 660.0,
        'date': DateTime.now().toIso8601String(),
        'status': 'Completed',
      });

      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.sale,
        delta: -3,
        orderId: voidOrderId,
        deviceId: 'DEV_1',
        operationId: 'sale_${voidOrderId}_$item1',
        createdAt: DateTime.now(),
      ));
      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item2,
        storeId: storeA,
        type: MovementType.sale,
        delta: -5,
        orderId: voidOrderId,
        deviceId: 'DEV_1',
        operationId: 'sale_${voidOrderId}_$item2',
        createdAt: DateTime.now(),
      ));

      expect(await repo.getItemQuantity(item1, storeId: storeA), equals(7));
      expect(await repo.getItemQuantity(item2, storeId: storeA), equals(5));

      // Execute order voiding
      final reversals = await repo.voidOrderStock(
        orderId: voidOrderId,
        storeId: storeA,
        deviceId: 'DEV_1',
        reason: 'Customer cancelled at counter',
        voidedBy: 'cashier_01',
      );

      expect(reversals.length, equals(2));
      expect(reversals.any((m) => m.itemId == item1 && m.delta == 3), isTrue);
      expect(reversals.any((m) => m.itemId == item2 && m.delta == 5), isTrue);

      // Quantities must be completely restored in ledger and projections
      expect(await repo.getItemQuantity(item1, storeId: storeA), equals(10));
      expect(await repo.getItemQuantity(item2, storeId: storeA), equals(10));

      final orderRow =
          await db.query('orders', where: 'id = ?', whereArgs: [voidOrderId]);
      expect(orderRow.first['status'], equals('VOID'));
    });

    // ─── 5. MULTIPLE DEVICES ─────────────────────────────────
    test('5. multiple devices: concurrent operations apply without collision',
        () async {
      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.purchase,
        delta: 100,
        deviceId: 'SERVER',
        createdAt: DateTime.now(),
      ));

      // Terminal A sells 10
      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.sale,
        delta: -10,
        deviceId: 'TERMINAL_A',
        operationId: 'termA_sale_01',
        createdAt: DateTime.now(),
      ));

      // Terminal B sells 25
      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.sale,
        delta: -25,
        deviceId: 'TERMINAL_B',
        operationId: 'termB_sale_01',
        createdAt: DateTime.now(),
      ));

      // Stock is 100 - 10 - 25 = 65
      expect(await repo.getItemQuantity(item1, storeId: storeA), equals(65));
      final allMovements = await repo.getMovementsByItem(item1);
      expect(allMovements.length, equals(3));
      expect(allMovements.any((m) => m.deviceId == 'TERMINAL_A'), isTrue);
      expect(allMovements.any((m) => m.deviceId == 'TERMINAL_B'), isTrue);
    });

    // ─── 6. OFFLINE SALE ─────────────────────────────────────
    test('6. offline sale: records PENDING movement and transitions on sync',
        () async {
      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.purchase,
        delta: 30,
        deviceId: 'OFFLINE_POS',
        createdAt: DateTime.now(),
      ));

      final offlineMvtId = const Uuid().v4();
      await repo.insertMovement(InventoryMovement(
        id: offlineMvtId,
        itemId: item1,
        storeId: storeA,
        type: MovementType.sale,
        delta: -5,
        deviceId: 'OFFLINE_POS',
        operationId: 'offline_sale_01',
        createdAt: DateTime.now(),
        syncStatus: 'PENDING',
      ));

      // Projection updated immediately for offline cashier
      expect(await repo.getItemQuantity(item1, storeId: storeA), equals(25));

      final pending = await repo.getPendingMovements();
      expect(pending.any((m) => m.id == offlineMvtId), isTrue);

      // Mark confirmed upon cloud sync
      await repo.markAsSynced(offlineMvtId);
      final pendingAfter = await repo.getPendingMovements();
      expect(pendingAfter.any((m) => m.id == offlineMvtId), isFalse);
    });

    // ─── 7. RETRY ────────────────────────────────────────────
    test(
        '7. retry: identical operationId is treated idempotently without duplicate deduction',
        () async {
      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.purchase,
        delta: 40,
        deviceId: 'POS_1',
        createdAt: DateTime.now(),
      ));

      const opId = 'sale_retry_tx_123';
      final mvt1 = InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.sale,
        delta: -10,
        deviceId: 'POS_1',
        operationId: opId,
        createdAt: DateTime.now(),
      );

      final firstAttempt = await repo.insertMovement(mvt1);
      expect(firstAttempt, isTrue);
      expect(await repo.getItemQuantity(item1, storeId: storeA), equals(30));

      // Network retry: exact same operationId sent with new movementId
      final mvtRetry = InventoryMovement(
        id: const Uuid().v4(), // Different movement ID
        itemId: item1,
        storeId: storeA,
        type: MovementType.sale,
        delta: -10,
        deviceId: 'POS_1',
        operationId: opId, // Same operation ID
        createdAt: DateTime.now(),
      );

      final retryAttempt = await repo.insertMovement(mvtRetry);
      expect(retryAttempt, isFalse); // Successfully suppressed

      // Stock MUST remain 30, NOT 20!
      expect(await repo.getItemQuantity(item1, storeId: storeA), equals(30));
    });

    // ─── 8. DUPLICATE MOVEMENT ───────────────────────────────
    test('8. duplicate movement: identical movementId is safely ignored',
        () async {
      const fixedMvtId = 'MVT_FIXED_UUID_999';
      final mvt = InventoryMovement(
        id: fixedMvtId,
        itemId: item1,
        storeId: storeA,
        type: MovementType.initialStock,
        delta: 50,
        deviceId: 'SYSTEM',
        createdAt: DateTime.now(),
      );

      final first = await repo.insertMovement(mvt);
      expect(first, isTrue);

      final duplicate = await repo.insertMovement(mvt);
      expect(duplicate, isFalse);

      expect(await repo.getItemQuantity(item1, storeId: storeA), equals(50));
    });

    // ─── 9. STOCK ADJUSTMENT ─────────────────────────────────
    test('9. stock adjustment: positive and negative adjustments update ledger',
        () async {
      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.purchase,
        delta: 20,
        deviceId: 'POS',
        createdAt: DateTime.now(),
      ));

      // Wastage / Damage (-3)
      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.damage,
        delta: -3,
        reason: 'Dropped on floor',
        deviceId: 'POS',
        operationId: 'dmg_01',
        createdAt: DateTime.now(),
      ));
      expect(await repo.getItemQuantity(item1, storeId: storeA), equals(17));

      // Physical count audit (+5 found)
      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.adjustment,
        delta: 5,
        reason: 'Audit reconciliation surplus',
        deviceId: 'POS',
        operationId: 'adj_surplus_01',
        createdAt: DateTime.now(),
      ));
      expect(await repo.getItemQuantity(item1, storeId: storeA), equals(22));
    });

    // ─── 10. TRANSFER ────────────────────────────────────────
    test('10. transfer: atomic TRANSFER_OUT and TRANSFER_IN across stores',
        () async {
      // Store A has 100 burgers
      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.purchase,
        delta: 100,
        deviceId: 'HQ',
        createdAt: DateTime.now(),
      ));

      // Store B has 0 of its special item
      expect(
          await repo.getItemQuantity(itemStoreB, storeId: storeB), equals(0));

      // Transfer 30 units from Store A to Store B
      await repo.transferStock(
        sourceStoreId: storeA,
        destinationStoreId: storeB,
        sourceItemId: item1,
        destinationItemId: itemStoreB,
        quantity: 30,
        deviceId: 'HQ_DISPATCH',
        reason: 'Inter-store transfer',
        transferId: 'XFER_101',
      );

      // Store A quantity must be 70
      expect(await repo.getItemQuantity(item1, storeId: storeA), equals(70));
      // Store B quantity must be 30
      expect(
          await repo.getItemQuantity(itemStoreB, storeId: storeB), equals(30));
    });

    // ─── 11. PROJECTION REBUILD ──────────────────────────────
    test(
        '11. projection rebuild: reconstructs quantities from movements ledger',
        () async {
      // Create series of movements
      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.purchase,
        delta: 80,
        deviceId: 'DEV',
        createdAt: DateTime.now(),
      ));
      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.sale,
        delta: -25,
        deviceId: 'DEV',
        createdAt: DateTime.now(),
      ));

      // Now intentionally corrupt/wipe projections
      await db.rawUpdate('UPDATE inventory SET quantity = 0');
      await db.rawDelete('DELETE FROM cache_inventory_quantities');

      // Projections are corrupted
      final wipedInv =
          await db.query('inventory', where: 'id = ?', whereArgs: [item1]);
      expect(wipedInv.first['quantity'], equals(0));

      // Rebuild projection from ledger
      final rebuilt = await repo.rebuildInventoryProjection(storeA);
      expect(rebuilt[item1], equals(55));

      // Verify projections restored
      final restoredInv =
          await db.query('inventory', where: 'id = ?', whereArgs: [item1]);
      expect(restoredInv.first['quantity'], equals(55));

      final restoredCache = await db.query('cache_inventory_quantities',
          where: 'itemId = ?', whereArgs: [item1]);
      expect(restoredCache.first['quantity'], equals(55));
    });

    // ─── 12. CORRUPTED PROJECTION & RECONCILIATION ───────────
    test(
        '12. corrupted projection: reconciliation detects drift and repairs projection without altering ledger',
        () async {
      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.purchase,
        delta: 40,
        deviceId: 'DEV',
        createdAt: DateTime.now(),
      ));

      // Ledger count is 1 movement, sum is 40
      final movementCountBefore = await repo.getMovementCount(storeA);
      expect(movementCountBefore, equals(1));

      // Intentionally corrupt the inventory projection to 9999
      await db.rawUpdate(
          'UPDATE inventory SET quantity = 9999 WHERE id = ?', [item1]);

      // Reconcile with autoRepair: false
      final dryRunReport =
          await repo.reconcileInventory(storeA, autoRepair: false);
      expect(dryRunReport.hasDiscrepancies, isTrue);
      expect(dryRunReport.discrepancies.first.expectedQuantity, equals(40));
      expect(dryRunReport.discrepancies.first.actualQuantity, equals(9999));
      expect(dryRunReport.discrepancies.first.drift, equals(9959));
      expect(dryRunReport.discrepancies.first.repaired, isFalse);

      // Projection is still 9999
      final uncorrupted =
          await db.query('inventory', where: 'id = ?', whereArgs: [item1]);
      expect(uncorrupted.first['quantity'], equals(9999));

      // Reconcile with autoRepair: true
      final repairReport =
          await repo.reconcileInventory(storeA, autoRepair: true);
      expect(repairReport.hasDiscrepancies, isTrue);
      expect(repairReport.discrepancies.first.repaired, isTrue);

      // Projection is now repaired to 40
      final repaired =
          await db.query('inventory', where: 'id = ?', whereArgs: [item1]);
      expect(repaired.first['quantity'], equals(40));

      // Ledger MUST be untouched (still exactly 1 movement, sum 40)
      final movementCountAfter = await repo.getMovementCount(storeA);
      expect(movementCountAfter, equals(movementCountBefore));
      expect(await repo.getItemQuantity(item1, storeId: storeA), equals(40));
    });

    // ─── 13. STORE ISOLATION ─────────────────────────────────
    test('13. store isolation: rejects cross-store item movement', () async {
      // Attempting to move itemStoreB (which belongs to STORE_BETA) under STORE_ALPHA must throw
      expect(
        () => repo.insertMovement(InventoryMovement(
          id: const Uuid().v4(),
          itemId: itemStoreB,
          storeId: storeA, // Mismatched store!
          type: MovementType.sale,
          delta: -1,
          deviceId: 'HACKER_TERMINAL',
          createdAt: DateTime.now(),
        )),
        throwsA(isA<CrossStoreViolationException>()),
      );
    });

    // ─── 14. NEGATIVE STOCK POLICY ───────────────────────────
    test(
        '14. negative stock policy: BLOCK blocks, ALLOW_WITH_WARNING and ALLOW permit',
        () async {
      // Current stock is 5
      await repo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: item1,
        storeId: storeA,
        type: MovementType.purchase,
        delta: 5,
        deviceId: 'POS',
        createdAt: DateTime.now(),
      ));

      // 14a. BLOCK policy: requesting 10 items throws InsufficientStockException
      expect(
        () => repo.insertMovement(
          InventoryMovement(
            id: const Uuid().v4(),
            itemId: item1,
            storeId: storeA,
            type: MovementType.sale,
            delta: -10,
            deviceId: 'POS',
            operationId: 'block_test_01',
            createdAt: DateTime.now(),
          ),
          negativeStockPolicy: NegativeStockPolicy.block,
        ),
        throwsA(isA<InsufficientStockException>()),
      );
      // Stock remains 5
      expect(await repo.getItemQuantity(item1, storeId: storeA), equals(5));

      // 14b. ALLOW_WITH_WARNING policy: allows negative stock (-5)
      final allowWarningSuccess = await repo.insertMovement(
        InventoryMovement(
          id: const Uuid().v4(),
          itemId: item1,
          storeId: storeA,
          type: MovementType.sale,
          delta: -10,
          deviceId: 'POS',
          operationId: 'warning_test_01',
          createdAt: DateTime.now(),
        ),
        negativeStockPolicy: NegativeStockPolicy.allowWithWarning,
      );
      expect(allowWarningSuccess, isTrue);
      expect(await repo.getItemQuantity(item1, storeId: storeA), equals(-5));

      // 14c. ALLOW policy: permits further negative stock (-15)
      final allowSuccess = await repo.insertMovement(
        InventoryMovement(
          id: const Uuid().v4(),
          itemId: item1,
          storeId: storeA,
          type: MovementType.sale,
          delta: -10,
          deviceId: 'POS',
          operationId: 'allow_test_01',
          createdAt: DateTime.now(),
        ),
        negativeStockPolicy: NegativeStockPolicy.allow,
      );
      expect(allowSuccess, isTrue);
      expect(await repo.getItemQuantity(item1, storeId: storeA), equals(-15));
    });
  });
}
