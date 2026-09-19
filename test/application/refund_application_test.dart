import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';
import 'package:biztonic_pos/features/inventory/domain/entities/inventory_movement.dart';
import 'package:biztonic_pos/features/inventory/domain/policies/inventory_policy.dart';
import 'package:biztonic_pos/features/billing/domain/entities/order_entity.dart';
import 'package:biztonic_pos/features/billing/domain/policies/order_policy.dart';

void main() {
  late Directory tempDir;
  late InventoryMovementRepository movementRepo;

  const testStoreId = 'STORE_MUMBAI_01';
  const testItemId = 'ITEM_PIZZA_01';
  const testOrderId = 'ORD_COMPLETED_101';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('app_refund_test_');
    final dbPath = p.join(tempDir.path, 'app_refund.db');
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
      'name': 'Margherita Pizza',
      'price': 250.0,
      'cost': 110.0,
      'quantity': 20,
      'category': 'Food',
      'status': 'ACTIVE',
      'trackStock': 1,
      'isDeleted': 0,
    });

    // 2. Seed initial stock-in (+20)
    await db.insert('inventory_movements', {
      'id': 'MOV_INIT_201',
      'itemId': testItemId,
      'storeId': testStoreId,
      'delta': 20,
      'type': 'PURCHASE',
      'cost': 110.0,
      'reason': 'Stock in',
      'deviceId': 'POS_MUMBAI_1',
      'operationId': 'init_201',
      'createdAt': DateTime.now().toIso8601String(),
      'syncStatus': 'CONFIRMED',
      'isDeleted': 0,
    });

    // 3. Seed completed order in orders table
    await db.insert('orders', {
      'id': testOrderId,
      'storeId': testStoreId,
      'subtotal': 500.0,
      'discount': 0.0,
      'cgst': 12.5,
      'sgst': 12.5,
      'total': 525.0,
      'status': 'Completed',
      'type': 'Dine-In',
      'paymentMethod': 'Cash',
      'date': DateTime.now().toIso8601String(),
      'syncStatus': 'CONFIRMED',
      'isDeleted': 0,
    });

    // 4. Seed sale movement for this order (-2 sold)
    await db.insert('inventory_movements', {
      'id': 'MOV_SALE_101',
      'itemId': testItemId,
      'storeId': testStoreId,
      'delta': -2,
      'type': 'SALE',
      'orderId': testOrderId,
      'cost': 110.0,
      'reason': 'Order Sale',
      'deviceId': 'POS_MUMBAI_1',
      'operationId': 'sale_101',
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

  group('Application Tests: Order Refund Workflow', () {
    test(
        '1. Valid refund restores inventory stock and registers ledger movement',
        () async {
      // Check initial stock (20 initial - 2 sold = 18)
      final quantitiesBefore = await movementRepo.getAllQuantities(testStoreId);
      expect(quantitiesBefore[testItemId], 18);

      // Perform refund of 2 units
      final refundMovement = InventoryMovement(
        id: 'MOV_REFUND_101',
        itemId: testItemId,
        storeId: testStoreId,
        type: MovementType.refund,
        delta: 2, // Positive delta for refund
        orderId: testOrderId,
        unitCost: 110.0,
        reason: 'Customer Return',
        deviceId: 'POS_MUMBAI_1',
        operationId: 'refund_101_$testItemId',
        createdAt: DateTime.now(),
      );

      final result = await movementRepo.insertMovement(refundMovement);
      expect(result, isTrue);

      // Check stock restored to 20
      final quantitiesAfter = await movementRepo.getAllQuantities(testStoreId);
      expect(quantitiesAfter[testItemId], 20);

      // Verify order status update in DB
      final db = await DatabaseHelper().database;
      await db.update(
        'orders',
        {'status': 'Refunded', 'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [testOrderId],
      );

      final updatedOrders =
          await db.query('orders', where: 'id = ?', whereArgs: [testOrderId]);
      expect(updatedOrders.first['status'], 'Refunded');
    });

    test(
        '2. Refund quantity exceeding original sale quantity is blocked with InvalidRefundException',
        () async {
      final excessRefund = InventoryMovement(
        id: 'MOV_EXCESS_REFUND',
        itemId: testItemId,
        storeId: testStoreId,
        type: MovementType.refund,
        delta: 5, // Only 2 were sold!
        orderId: testOrderId,
        unitCost: 110.0,
        reason: 'Fraudulent refund',
        deviceId: 'POS_MUMBAI_1',
        operationId: 'excess_refund_101',
        createdAt: DateTime.now(),
      );

      expect(
        () async => await movementRepo.insertMovement(excessRefund),
        throwsA(isA<InvalidRefundException>()),
      );
    });

    test(
        '3. OrderPolicy validates refund eligibility: completed allowed, cancelled rejected',
        () {
      final completedOrder = OrderEntity(
        id: 'ORD_COMPLETED',
        storeId: testStoreId,
        items: const [],
        total: 100.0,
        status: OrderStatus.completed,
        date: DateTime.now(),
      );
      expect(OrderPolicy.canRefund(completedOrder).isValid, isTrue);

      final cancelledOrder = OrderEntity(
        id: 'ORD_CANCELLED',
        storeId: testStoreId,
        items: const [],
        total: 100.0,
        status: OrderStatus.cancelled,
        date: DateTime.now(),
      );
      final refundValidation = OrderPolicy.canRefund(cancelledOrder);
      expect(refundValidation.isValid, isFalse);
      expect(refundValidation.message,
          contains('Only completed orders can be refunded'));
    });

    test(
        '4. Refunding order with no sale history throws InvalidRefundException',
        () async {
      final orphanRefund = InventoryMovement(
        id: 'MOV_ORPHAN_REFUND',
        itemId: testItemId,
        storeId: testStoreId,
        type: MovementType.refund,
        delta: 1,
        orderId: 'ORD_NON_EXISTENT_999',
        unitCost: 110.0,
        reason: 'Non-existent sale refund',
        deviceId: 'POS_MUMBAI_1',
        operationId: 'orphan_refund_999',
        createdAt: DateTime.now(),
      );

      expect(
        () async => await movementRepo.insertMovement(orphanRefund),
        throwsA(isA<InvalidRefundException>()),
      );
    });
  });
}
