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
import 'package:biztonic_pos/features/inventory/domain/policies/inventory_policy.dart';

void main() {
  late Directory tempDir;
  late Repository repository;

  const testStoreId = 'STORE_ROLLBACK_01';
  const testItemId = 'ITEM_ROLLBACK_01';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('repo_rollback_test_');
    final dbPath = p.join(tempDir.path, 'repo_rollback.db');
    DatabaseHelper.setDbName(dbPath);

    repository = Repository();

    final db = await DatabaseHelper().database;
    // Seed item with 5 units in inventory
    await db.insert('inventory', {
      'id': testItemId,
      'storeId': testStoreId,
      'name': 'Gourmet Sandwich',
      'price': 200.0,
      'cost': 90.0,
      'quantity': 5,
      'category': 'Food',
      'status': 'ACTIVE',
      'trackStock': 1,
      'isDeleted': 0,
    });

    // Seed 5 units in movement ledger
    await db.insert('inventory_movements', {
      'id': 'MOV_INIT_SANDWICH',
      'itemId': testItemId,
      'storeId': testStoreId,
      'delta': 5,
      'type': 'PURCHASE',
      'cost': 90.0,
      'reason': 'Stock in',
      'deviceId': 'DEV_01',
      'operationId': 'op_init_sw',
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

  group('Repository Tests: SQLite Transaction Rollback & Invariant Protection',
      () {
    test(
        '1. Transaction abort mid-checkout rolls back order, items, movements, events, and counters completely',
        () async {
      final now = DateTime.now();
      final item = InventoryItem(
        id: testItemId,
        name: 'Gourmet Sandwich',
        price: 200.0,
        cost: 90.0,
        quantity: 5,
        storeId: testStoreId,
        category: 'Food',
        status: 'ACTIVE',
        trackStock: true,
      );

      // Attempt to purchase 10 units when only 5 are in stock -> will trigger InsufficientStockException in step 5
      final order = OrderModel(
        id: 'ORD_ROLLBACK_100',
        storeId: testStoreId,
        items: [OrderItem(item: item, quantity: 10)],
        total: 2000.0,
        date: now,
        status: 'Completed',
        type: 'Dine-In',
        paymentMethod: 'Cash',
      );

      final movements = [
        InventoryMovement(
          id: 'MOV_EXCESS_SALE',
          itemId: testItemId,
          storeId: testStoreId,
          type: MovementType.sale,
          delta: -10, // Exceeds available stock (5)
          orderId: 'ORD_ROLLBACK_100',
          unitCost: 90.0,
          reason: 'Sale',
          deviceId: 'DEV_01',
          operationId: 'op_excess_sale',
          createdAt: now,
        ),
      ];

      final event = BusinessEvent(
        id: 'EVT_ROLLBACK_100',
        storeId: testStoreId,
        entityType: 'ORDER',
        entityId: 'ORD_ROLLBACK_100',
        eventType: 'CREATE',
        amount: 2000.0,
        deviceId: 'DEV_01',
        createdAt: now,
      );

      // Perform checkout with BLOCK policy -> throws InsufficientStockException
      expect(
        () async => await repository.performAtomicCheckout(
          order: order,
          movements: movements,
          event: event,
          storeId: testStoreId,
          yearMonth: '2026-09',
          negativeStockPolicy: NegativeStockPolicy.block,
        ),
        throwsA(isA<InsufficientStockException>()),
      );

      final db = await DatabaseHelper().database;

      // Invariant 1: Order was NOT persisted
      final orders = await db
          .query('orders', where: 'id = ?', whereArgs: ['ORD_ROLLBACK_100']);
      expect(orders.isEmpty, isTrue, reason: 'Order must be rolled back');

      // Invariant 2: Order items were NOT persisted
      final items = await db.query('order_items',
          where: 'orderId = ?', whereArgs: ['ORD_ROLLBACK_100']);
      expect(items.isEmpty, isTrue, reason: 'Order items must be rolled back');

      // Invariant 3: Movements were NOT persisted
      final movs = await db.query('inventory_movements',
          where: 'id = ?', whereArgs: ['MOV_EXCESS_SALE']);
      expect(movs.isEmpty, isTrue, reason: 'Movements must be rolled back');

      // Invariant 4: Business event was NOT persisted
      final events = await db.query('business_events',
          where: 'id = ?', whereArgs: ['EVT_ROLLBACK_100']);
      expect(events.isEmpty, isTrue,
          reason: 'Business events must be rolled back');

      // Invariant 5: Monthly order counter was NOT incremented
      final counters = await db.query('monthly_order_counter',
          where: 'storeId = ? AND yearMonth = ?',
          whereArgs: [testStoreId, '2026-09']);
      expect(counters.isEmpty, isTrue,
          reason: 'Order counter must not be incremented');

      // Invariant 6: The journal entry created prior to transaction remains in PENDING state
      final journals = await db.query('transaction_journal',
          where: 'storeId = ?', whereArgs: [testStoreId]);
      expect(journals.isNotEmpty, isTrue);
      expect(journals.first['status'], 'PENDING',
          reason: 'Unfinished transaction journal must remain PENDING');
    });

    test('2. Manual SQLite transaction rollback cleans all mutations',
        () async {
      final db = await DatabaseHelper().database;

      try {
        await db.transaction((txn) async {
          await txn.insert('orders', {
            'id': 'ORD_MANUAL_ROLLBACK',
            'storeId': testStoreId,
            'subtotal': 100.0,
            'total': 100.0,
            'status': 'Draft',
            'date': DateTime.now().toIso8601String(),
            'syncStatus': 'PENDING',
          });

          // Throw simulated error
          throw Exception('Simulated fatal hardware failure mid-transaction');
        });
      } catch (e) {
        expect(e.toString(), contains('Simulated fatal hardware failure'));
      }

      final check = await db
          .query('orders', where: 'id = ?', whereArgs: ['ORD_MANUAL_ROLLBACK']);
      expect(check.isEmpty, isTrue);
    });
  });
}
