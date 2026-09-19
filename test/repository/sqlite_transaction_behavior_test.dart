import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/models/inventory_item.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:biztonic_pos/models/business_ledger.dart';

void main() {
  late Directory tempDir;
  late Repository repository;

  const testStoreId = 'STORE_TX_TEST_01';
  const testItemId = 'ITEM_TX_01';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('repo_tx_behavior_test_');
    final dbPath = p.join(tempDir.path, 'repo_tx_behavior.db');
    DatabaseHelper.setDbName(dbPath);

    repository = Repository();

    final db = await DatabaseHelper().database;
    // Seed inventory item
    await db.insert('inventory', {
      'id': testItemId,
      'storeId': testStoreId,
      'name': 'Paneer Tikka Roll',
      'price': 180.0,
      'cost': 80.0,
      'quantity': 50,
      'category': 'Food',
      'status': 'ACTIVE',
      'trackStock': 1,
      'isDeleted': 0,
    });

    // Seed initial stock in movement ledger (+50)
    await db.insert('inventory_movements', {
      'id': 'MOV_INIT_TX_01',
      'itemId': testItemId,
      'storeId': testStoreId,
      'delta': 50,
      'type': 'PURCHASE',
      'cost': 80.0,
      'reason': 'Stock in',
      'deviceId': 'DEV_01',
      'operationId': 'op_init_tx_01',
      'createdAt': DateTime.now().toIso8601String(),
      'syncStatus': 'CONFIRMED',
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
      'Repository Tests: SQLite Transaction Behavior & Multi-Entity Atomicity',
      () {
    test(
        '1. performAtomicCheckout writes order, items, movements, event, counter, and marks journal COMPLETED',
        () async {
      final now = DateTime.now();
      final item = InventoryItem(
        id: testItemId,
        name: 'Paneer Tikka Roll',
        price: 180.0,
        cost: 80.0,
        quantity: 50,
        storeId: testStoreId,
        category: 'Food',
        status: 'ACTIVE',
        trackStock: true,
      );

      final order = OrderModel(
        id: 'ORD_ATOMIC_001',
        storeId: testStoreId,
        items: [OrderItem(item: item, quantity: 2, cgst: 4.5, sgst: 4.5)],
        subtotal: 360.0,
        cgst: 9.0,
        sgst: 9.0,
        total: 378.0,
        date: now,
        status: 'Completed',
        type: 'Dine-In',
        paymentMethod: 'Cash',
      );

      final movements = [
        InventoryMovement(
          id: 'MOV_TX_001',
          itemId: testItemId,
          storeId: testStoreId,
          type: MovementType.sale,
          delta: -2,
          orderId: 'ORD_ATOMIC_001',
          unitCost: 80.0,
          reason: 'Sale',
          deviceId: 'DEV_01',
          operationId: 'sale_tx_001',
          createdAt: now,
        ),
      ];

      final event = BusinessEvent(
        id: 'EVT_TX_001',
        storeId: testStoreId,
        entityType: 'ORDER',
        entityId: 'ORD_ATOMIC_001',
        eventType: 'CREATE',
        amount: 378.0,
        createdAt: now,
        deviceId: 'DEV_01',
      );

      await repository.performAtomicCheckout(
        order: order,
        movements: movements,
        event: event,
        storeId: testStoreId,
        yearMonth: '2026-09',
      );

      final db = await DatabaseHelper().database;

      // 1. Order exists
      final orderRows = await db
          .query('orders', where: 'id = ?', whereArgs: ['ORD_ATOMIC_001']);
      expect(orderRows.length, 1);
      expect(orderRows.first['total'], 378.0);
      expect(orderRows.first['status'], 'Completed');

      // 2. Order items exist
      final itemRows = await db.query('order_items',
          where: 'orderId = ?', whereArgs: ['ORD_ATOMIC_001']);
      expect(itemRows.length, 1);
      expect(itemRows.first['itemId'], testItemId);
      expect(itemRows.first['quantity'], 2);

      // 3. Movement exists in ledger
      final movRows = await db.query('inventory_movements',
          where: 'id = ?', whereArgs: ['MOV_TX_001']);
      expect(movRows.length, 1);
      expect(movRows.first['delta'], -2);

      // 4. Business event exists
      final evtRows = await db
          .query('business_events', where: 'id = ?', whereArgs: ['EVT_TX_001']);
      expect(evtRows.length, 1);
      expect(evtRows.first['amount'], 378.0);

      // 5. Monthly order counter incremented
      final counterRows = await db.query('monthly_order_counter',
          where: 'storeId = ? AND yearMonth = ?',
          whereArgs: [testStoreId, '2026-09']);
      expect(counterRows.length, 1);
      expect(counterRows.first['count'], 1);

      // 6. Transaction journal marked COMPLETED
      final journalRows = await db.query('transaction_journal',
          where: 'storeId = ?', whereArgs: [testStoreId]);
      expect(journalRows.isNotEmpty, isTrue);
      expect(journalRows.first['status'], 'COMPLETED');
    });

    test('2. Sequential checkouts increment the token counter monotonically',
        () async {
      final now = DateTime.now();
      final item = InventoryItem(
        id: testItemId,
        name: 'Paneer Tikka Roll',
        price: 180.0,
        cost: 80.0,
        quantity: 50,
        storeId: testStoreId,
        category: 'Food',
        status: 'ACTIVE',
        trackStock: true,
      );

      for (int i = 1; i <= 3; i++) {
        final order = OrderModel(
          id: 'ORD_SEQ_$i',
          storeId: testStoreId,
          items: [OrderItem(item: item, quantity: 1)],
          total: 180.0,
          date: now,
          status: 'Completed',
          type: 'Takeaway',
          paymentMethod: 'Cash',
        );

        final movements = [
          InventoryMovement(
            id: 'MOV_SEQ_$i',
            itemId: testItemId,
            storeId: testStoreId,
            type: MovementType.sale,
            delta: -1,
            orderId: 'ORD_SEQ_$i',
            deviceId: 'DEV_01',
            operationId: 'op_seq_$i',
            createdAt: now,
          ),
        ];

        final event = BusinessEvent(
          id: 'EVT_SEQ_$i',
          storeId: testStoreId,
          entityType: 'ORDER',
          entityId: 'ORD_SEQ_$i',
          eventType: 'CREATE',
          amount: 180.0,
          deviceId: 'DEV_01',
          createdAt: now,
        );

        await repository.performAtomicCheckout(
          order: order,
          movements: movements,
          event: event,
          storeId: testStoreId,
          yearMonth: '2026-09',
        );
      }

      final count =
          await repository.getMonthlyOrderCount(testStoreId, '2026-09');
      expect(count, 3);
    });
  });
}
