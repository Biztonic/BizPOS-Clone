import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:biztonic_pos/models/business_ledger.dart';
import 'package:biztonic_pos/models/inventory_item.dart';
import 'package:uuid/uuid.dart';

void main() {
  late Directory tempDir;
  late Repository repository;
  const uuid = Uuid();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('stress_simulation_test_');
    final dbPath = p.join(tempDir.path, 'stress_simulation.db');
    DatabaseHelper.setDbName(dbPath);

    repository = Repository();

    final db = await DatabaseHelper().database;
    await db.insert('inventory', {
      'id': 'item_1',
      'storeId': 'test_store',
      'name': 'Test Product',
      'price': 100.0,
      'quantity': 100,
      'category': 'test',
      'status': 'Available',
    });

    await repository.movementRepo.insertMovement(InventoryMovement(
      id: 'INIT_ITEM_1',
      itemId: 'item_1',
      storeId: 'test_store',
      delta: 100,
      type: MovementType.purchase,
      deviceId: 'test_device',
      operationId: 'op_init_item_1',
      createdAt: DateTime.now(),
    ));
  });

  tearDown(() async {
    await DatabaseHelper().close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('System Stress & Batch Simulation Tests', () {
    test('High Volume Atomic Checkout Performance (50 Orders)', () async {
      debugPrint('--- Starting Atomic Checkout Performance Test ---');
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 50; i++) {
        final orderId = 'STRESS_${uuid.v4()}';
        final order = OrderModel(
          id: orderId,
          storeId: 'test_store',
          total: 100.0,
          date: DateTime.now(),
          status: 'Completed',
          type: 'Dine-In',
          paymentMethod: 'Cash',
          items: [
            OrderItem(
              item: InventoryItem(
                id: 'item_1',
                name: 'Test Product',
                price: 100.0,
                category: 'test',
                trackStock: false,
                status: 'Available',
              ),
              quantity: 1,
              cgst: 5.0,
              sgst: 5.0,
            ),
          ],
        );

        final movements = [
          InventoryMovement(
            id: uuid.v4(),
            itemId: 'item_1',
            storeId: 'test_store',
            delta: -1,
            type: MovementType.sale,
            deviceId: 'test_device',
            operationId: 'op_stress_$i',
            createdAt: DateTime.now(),
          ),
        ];

        final event = BusinessEvent(
          id: uuid.v4(),
          storeId: 'test_store',
          entityType: 'ORDER',
          entityId: orderId,
          eventType: 'CREATE',
          amount: 100.0,
          createdAt: DateTime.now(),
          deviceId: 'test_device',
        );

        await repository.performAtomicCheckout(
          order: order,
          movements: movements,
          event: event,
          storeId: 'test_store',
          yearMonth: '2026-03',
        );
      }

      stopwatch.stop();
      debugPrint(
          'Completed 50 atomic checkouts in ${stopwatch.elapsedMilliseconds}ms');

      final db = await DatabaseHelper().database;
      final count = await db.rawQuery(
          "SELECT COUNT(*) as c FROM orders WHERE id LIKE 'STRESS_%'");
      expect(count.first['c'], 50);

      expect(stopwatch.elapsed.inSeconds, lessThan(15),
          reason: 'Checkout logic too slow for high-volume POS');
    });

    test(
        'High Volume Batch Chunking and Ingestion Simulation (1000 items in 500-item chunks)',
        () async {
      debugPrint('--- Starting High Volume Batch Ingestion Test ---');
      final db = await DatabaseHelper().database;

      // Generate 1000 orders
      final List<OrderModel> orders = List.generate(1000, (i) {
        return OrderModel(
          id: 'BATCH_ORD_$i',
          storeId: 'test_store',
          total: 100.0,
          date: DateTime.now(),
          status: 'Completed',
          type: 'Takeaway',
          paymentMethod: 'Cash',
          items: [],
        );
      });

      // Split into chunks of 500
      const chunkSize = 500;
      final chunks = <List<OrderModel>>[];
      for (var i = 0; i < orders.length; i += chunkSize) {
        chunks.add(orders.sublist(i,
            (i + chunkSize > orders.length) ? orders.length : i + chunkSize));
      }

      expect(chunks.length, 2);
      expect(chunks[0].length, 500);
      expect(chunks[1].length, 500);

      final stopwatch = Stopwatch()..start();

      // Process both chunks via SQLite batch commits
      for (final chunk in chunks) {
        final batch = db.batch();
        for (final ord in chunk) {
          batch.insert('orders', ord.toSqlMap());
        }
        await batch.commit(noResult: true);
      }

      stopwatch.stop();
      debugPrint(
          'Committed 1000 orders in 2 batches in ${stopwatch.elapsedMilliseconds}ms');

      final countResult = await db.rawQuery(
          "SELECT COUNT(*) as c FROM orders WHERE id LIKE 'BATCH_ORD_%'");
      expect(countResult.first['c'], 1000);
      expect(stopwatch.elapsed.inSeconds, lessThan(10));
    });
  });
}
