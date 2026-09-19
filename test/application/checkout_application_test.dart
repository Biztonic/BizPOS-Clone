import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/features/billing/application/checkout_orchestrator.dart';
import 'package:biztonic_pos/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:biztonic_pos/features/billing/domain/entities/order_entity.dart';
import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';

void main() {
  late Directory tempDir;
  late BillingRepositoryImpl billingRepository;
  late CheckoutOrchestrator orchestrator;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('app_checkout_test_');
    final dbPath = p.join(tempDir.path, 'app_checkout.db');
    DatabaseHelper.setDbName(dbPath);

    Hive.init(tempDir.path);
    await Hive.openBox('cache_orders');
    await Hive.openBox('cache_inventory');
    await Hive.openBox('idempotency_keys_v1');

    billingRepository = BillingRepositoryImpl();
    orchestrator = CheckoutOrchestrator(billingRepository: billingRepository);

    // Seed inventory item in SQLite for the store
    final db = await DatabaseHelper().database;
    await db.insert('inventory', {
      'id': 'ITEM_BURGER_01',
      'storeId': 'STORE_DELHI_01',
      'name': 'Paneer Burger',
      'price': 150.0,
      'cost': 70.0,
      'quantity': 50,
      'category': 'Fast Food',
      'status': 'ACTIVE',
      'trackStock': 1,
      'isDeleted': 0,
    });

    // Seed initial stock-in in immutable ledger
    await db.insert('inventory_movements', {
      'id': 'MOV_INIT_001',
      'itemId': 'ITEM_BURGER_01',
      'storeId': 'STORE_DELHI_01',
      'delta': 50,
      'type': 'PURCHASE',
      'cost': 70.0,
      'reason': 'Initial Stock In',
      'deviceId': 'POS_TERMINAL_A',
      'operationId': 'init_stock_001',
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

  group('Application Tests: Checkout Orchestrator', () {
    test(
        '1. Full atomic checkout persists order, movements, ledger event, and updates token counter',
        () async {
      OrderCreatedEvent? capturedEvent;
      final sub = EventBus.instance.on<OrderCreatedEvent>((event) {
        capturedEvent = event;
      });

      final now = DateTime.now();
      final orderEntity = OrderEntity(
        id: 'ORD_TEST_1001',
        storeId: 'STORE_DELHI_01',
        items: const [
          OrderItemEntity(
            itemId: 'ITEM_BURGER_01',
            itemName: 'Paneer Burger',
            price: 150.0,
            quantity: 2,
            cgst: 3.75,
            sgst: 3.75,
            cost: 70.0,
          ),
        ],
        subtotal: 300.0,
        discount: 0.0,
        cgst: 7.5,
        sgst: 7.5,
        total: 315.0,
        status: OrderStatus.completed,
        type: OrderType.dineIn,
        paymentMethod: PaymentMethod.cash,
        date: now,
      );

      final params = CheckoutParams(
        order: orderEntity,
        activeStoreId: 'STORE_DELHI_01',
        deviceId: 'POS_TERMINAL_A',
        idempotencyKey: 'IDEMP_CHECKOUT_UUID_001',
        trackInventory: true,
        taxRate: 5.0,
      );

      final result = await orchestrator.execute(params);

      expect(result.isSuccess, isTrue);
      expect(result.order, isNotNull);
      expect(result.order!.id, 'ORD_TEST_1001');
      expect(result.order!.cgst, 7.5);
      expect(result.order!.sgst, 7.5);
      expect(result.order!.total, 315.0);

      // Verify SQLite Database Persistence
      final db = await DatabaseHelper().database;
      final orders = await db
          .query('orders', where: 'id = ?', whereArgs: ['ORD_TEST_1001']);
      expect(orders.length, 1);
      expect(orders.first['storeId'], 'STORE_DELHI_01');
      expect(orders.first['status'], 'Completed');

      // Verify order items in SQLite
      final items = await db.query('order_items',
          where: 'orderId = ?', whereArgs: ['ORD_TEST_1001']);
      expect(items.length, 1);
      expect(items.first['itemId'], 'ITEM_BURGER_01');
      expect(items.first['quantity'], 2);

      // Verify transaction journal completed
      final journals = await db.query('transaction_journal',
          where: 'storeId = ?', whereArgs: ['STORE_DELHI_01']);
      expect(journals.isNotEmpty, isTrue);
      expect(journals.first['status'], 'COMPLETED');

      // Verify business event created in ledger
      final events = await db.query('business_events',
          where: 'entityId = ?', whereArgs: ['ORD_TEST_1001']);
      expect(events.length, 1);
      expect(events.first['eventType'], 'CREATE');
      expect(events.first['amount'], 315.0);

      // Verify monthly order counter incremented
      final currentYearMonth =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final counters = await db.query('monthly_order_counter',
          where: 'storeId = ? AND yearMonth = ?',
          whereArgs: ['STORE_DELHI_01', currentYearMonth]);
      expect(counters.isNotEmpty, isTrue);
      expect(counters.first['count'], 1);

      // Verify cache_orders Hive box contains the order
      final orderBox = Hive.box('cache_orders');
      expect(orderBox.containsKey('ORD_TEST_1001'), isTrue);

      // Verify EventBus decoupled event fired
      expect(capturedEvent, isNotNull);
      expect(capturedEvent!.order.id, 'ORD_TEST_1001');

      await sub.cancel();
    });

    test(
        '2. Duplicate checkout attempt with identical idempotencyKey is blocked',
        () async {
      final orderEntity = OrderEntity(
        id: 'ORD_TEST_1002',
        storeId: 'STORE_DELHI_01',
        items: const [
          OrderItemEntity(
            itemId: 'ITEM_BURGER_01',
            itemName: 'Paneer Burger',
            price: 150.0,
            quantity: 1,
            cgst: 3.75,
            sgst: 3.75,
            cost: 70.0,
          ),
        ],
        subtotal: 150.0,
        discount: 0.0,
        cgst: 3.75,
        sgst: 3.75,
        total: 157.5,
        status: OrderStatus.completed,
        type: OrderType.takeaway,
        paymentMethod: PaymentMethod.card,
        date: DateTime.now(),
      );

      final params = CheckoutParams(
        order: orderEntity,
        activeStoreId: 'STORE_DELHI_01',
        deviceId: 'POS_TERMINAL_A',
        idempotencyKey: 'IDEMP_CHECKOUT_REPLAY_KEY',
        trackInventory: false,
        taxRate: 5.0,
      );

      // First run: succeeds
      final firstResult = await orchestrator.execute(params);
      expect(firstResult.isSuccess, isTrue);

      // Second run with duplicate key: blocked
      final secondResult = await orchestrator.execute(params);
      expect(secondResult.isSuccess, isFalse);
      expect(secondResult.error, contains('Duplicate checkout'));
    });

    test(
        '3. Domain validation rejects order with zero or negative total before DB write',
        () async {
      final invalidOrder = OrderEntity(
        id: 'ORD_TEST_INVALID',
        storeId: 'STORE_DELHI_01',
        items: const [], // Empty items violates OrderPolicy
        subtotal: 0.0,
        discount: 0.0,
        cgst: 0.0,
        sgst: 0.0,
        total: 0.0,
        status: OrderStatus.completed,
        type: OrderType.takeaway,
        paymentMethod: PaymentMethod.cash,
        date: DateTime.now(),
      );

      final params = CheckoutParams(
        order: invalidOrder,
        activeStoreId: 'STORE_DELHI_01',
        deviceId: 'POS_TERMINAL_A',
        idempotencyKey: 'IDEMP_INVALID_ORDER_01',
      );

      final result = await orchestrator.execute(params);
      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);

      // Verify no order written to DB
      final db = await DatabaseHelper().database;
      final count = await db
          .query('orders', where: 'id = ?', whereArgs: ['ORD_TEST_INVALID']);
      expect(count.isEmpty, isTrue);
    });
  });
}
