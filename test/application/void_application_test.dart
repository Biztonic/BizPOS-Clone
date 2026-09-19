import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';
import 'package:biztonic_pos/features/inventory/domain/entities/inventory_movement.dart';
import 'package:biztonic_pos/features/billing/domain/entities/order_entity.dart';
import 'package:biztonic_pos/features/billing/domain/policies/order_policy.dart';

void main() {
  late Directory tempDir;
  late InventoryMovementRepository movementRepo;

  const testStoreId = 'STORE_PUNE_01';
  const testItemId = 'ITEM_TEA_01';
  const testOrderId = 'ORD_VOID_TEST_101';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('app_void_test_');
    final dbPath = p.join(tempDir.path, 'app_void.db');
    DatabaseHelper.setDbName(dbPath);

    Hive.init(tempDir.path);
    await Hive.openBox('cache_inventory');
    await Hive.openBox('cache_orders');

    movementRepo = InventoryMovementRepository();

    final db = await DatabaseHelper().database;
    // 1. Seed item
    await db.insert('inventory', {
      'id': testItemId,
      'storeId': testStoreId,
      'name': 'Masala Chai',
      'price': 40.0,
      'cost': 15.0,
      'quantity': 100,
      'category': 'Beverages',
      'status': 'ACTIVE',
      'trackStock': 1,
      'isDeleted': 0,
    });

    // 2. Seed initial stock-in (+100)
    await db.insert('inventory_movements', {
      'id': 'MOV_INIT_CHAI_01',
      'itemId': testItemId,
      'storeId': testStoreId,
      'delta': 100,
      'type': 'PURCHASE',
      'cost': 15.0,
      'reason': 'Stock in',
      'deviceId': 'POS_PUNE_1',
      'operationId': 'init_chai_01',
      'createdAt': DateTime.now().toIso8601String(),
      'syncStatus': 'CONFIRMED',
      'isDeleted': 0,
    });

    // 3. Seed completed order in orders table
    await db.insert('orders', {
      'id': testOrderId,
      'storeId': testStoreId,
      'subtotal': 120.0,
      'discount': 0.0,
      'cgst': 3.0,
      'sgst': 3.0,
      'total': 126.0,
      'status': 'Completed',
      'type': 'Dine-In',
      'paymentMethod': 'Cash',
      'date': DateTime.now().toIso8601String(),
      'syncStatus': 'CONFIRMED',
      'isDeleted': 0,
    });

    // 4. Seed sale movement for this order (-3 cups sold)
    await db.insert('inventory_movements', {
      'id': 'MOV_SALE_CHAI_101',
      'itemId': testItemId,
      'storeId': testStoreId,
      'delta': -3,
      'type': 'SALE',
      'orderId': testOrderId,
      'cost': 15.0,
      'reason': 'Sale',
      'deviceId': 'POS_PUNE_1',
      'operationId': 'sale_chai_101',
      'createdAt': DateTime.now().toIso8601String(),
      'syncStatus': 'CONFIRMED',
      'isDeleted': 0,
    });
  });

  tearDown(() async {
    await Hive.close();
    await DatabaseHelper().close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Application Tests: Order Void Workflow', () {
    test(
        '1. voidOrderStock reverses stock deductions and updates order status to VOID',
        () async {
      // Stock before void: 100 initial - 3 sold = 97
      final stockBefore = await movementRepo.getAllQuantities(testStoreId);
      expect(stockBefore[testItemId], 97);

      // Execute void workflow
      final reversals = await movementRepo.voidOrderStock(
        orderId: testOrderId,
        storeId: testStoreId,
        deviceId: 'POS_PUNE_1',
        reason: 'Customer cancelled order before prep',
        voidedBy: 'MANAGER_JOHN',
      );

      expect(reversals.length, 1);
      expect(reversals.first.type, MovementType.voidReversal);
      expect(reversals.first.delta, 3);
      expect(reversals.first.orderId, testOrderId);

      // Stock after void: restored back to 100
      final stockAfter = await movementRepo.getAllQuantities(testStoreId);
      expect(stockAfter[testItemId], 100);

      // Verify database order record updated to VOID with audit trails
      final db = await DatabaseHelper().database;
      final orders =
          await db.query('orders', where: 'id = ?', whereArgs: [testOrderId]);
      expect(orders.first['status'], 'VOID');
      expect(
          orders.first['voidReason'], 'Customer cancelled order before prep');
      expect(orders.first['voidedBy'], 'MANAGER_JOHN');
      expect(orders.first['voidedAt'], isNotNull);
    });

    test('2. OrderPolicy prevents voiding an already voided order', () {
      final voidedOrder = OrderEntity(
        id: 'ORD_ALREADY_VOID',
        storeId: testStoreId,
        items: const [],
        total: 126.0,
        status: OrderStatus.voided,
        date: DateTime.now(),
      );

      final result = OrderPolicy.canVoid(voidedOrder);
      expect(result.isValid, isFalse);
      expect(result.message, contains('already voided'));
    });

    test('3. OrderPolicy prevents voiding a refunded order', () {
      final refundedOrder = OrderEntity(
        id: 'ORD_ALREADY_REFUNDED',
        storeId: testStoreId,
        items: const [],
        total: 126.0,
        status: OrderStatus.refunded,
        date: DateTime.now(),
      );

      final result = OrderPolicy.canVoid(refundedOrder);
      expect(result.isValid, isFalse);
      expect(result.message, contains('Cannot void a refunded order'));
    });

    test('4. OrderPolicy prevents voiding a cancelled order', () {
      final cancelledOrder = OrderEntity(
        id: 'ORD_ALREADY_CANCELLED',
        storeId: testStoreId,
        items: const [],
        total: 126.0,
        status: OrderStatus.cancelled,
        date: DateTime.now(),
      );

      final result = OrderPolicy.canVoid(cancelledOrder);
      expect(result.isValid, isFalse);
      expect(result.message, contains('Cannot void a cancelled order'));
    });
  });
}
