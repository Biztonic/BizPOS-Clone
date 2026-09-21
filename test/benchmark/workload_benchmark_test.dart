// ignore_for_file: avoid_print, unused_local_variable, unnecessary_brace_in_string_interps
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/models/inventory_item.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:biztonic_pos/models/business_ledger.dart';
import 'package:biztonic_pos/sync/outbox/outbox_operation.dart';
import 'package:biztonic_pos/sync/outbox/outbox_store.dart';
import 'package:biztonic_pos/sync/inbound/inbox_store.dart';

void main() {
  late Directory tempDir;
  late Repository repository;
  late DatabaseHelper dbHelper;
  const uuid = Uuid();
  const testStoreId = 'store_perf_001';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('perf_benchmark_');
    final dbPath = p.join(tempDir.path, 'perf_benchmark.db');
    DatabaseHelper.setDbName(dbPath);
    Hive.init(p.join(tempDir.path, 'hive'));

    dbHelper = DatabaseHelper();
    repository = Repository();
  });

  tearDown(() async {
    await dbHelper.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('BizPOS Real POS Workload Performance Benchmarks', () {
    test('Benchmark 1: Database Startup Time & Index Initialization', () async {
      final sw = Stopwatch()..start();
      final db = await dbHelper.database;
      sw.stop();
      final startupMs = sw.elapsedMilliseconds;

      // Verify PRAGMAs
      final syncResult = await db.rawQuery('PRAGMA synchronous');
      final cacheResult = await db.rawQuery('PRAGMA cache_size');
      final tempResult = await db.rawQuery('PRAGMA temp_store');

      // Verify Indexes
      final indexRows = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%'");
      final indexNames = indexRows.map((r) => r['name'] as String).toList();

      print('----------------------------------------------------');
      print('⚡ [STARTUP BENCHMARK]');
      print('Database Init Time: ${startupMs}ms');
      print('PRAGMA synchronous: ${syncResult.first.values.first}');
      print('PRAGMA cache_size: ${cacheResult.first.values.first}');
      print('PRAGMA temp_store: ${tempResult.first.values.first}');
      print(
          'Active Specialized Indexes (${indexNames.length}): ${indexNames.join(', ')}');
      print('----------------------------------------------------');

      expect(startupMs, lessThan(1500));
      expect(indexNames.length, greaterThanOrEqualTo(14));
    });

    test('Benchmark 2: Checkout Latency & Atomic Checkouts', () async {
      final db = await dbHelper.database;

      // Seed item
      await db.insert('inventory', {
        'id': 'item_fast_checkout',
        'storeId': testStoreId,
        'name': 'Speedy Coffee',
        'price': 4.50,
        'quantity': 100000,
        'category': 'Beverages',
        'status': 'Available',
      });
      await repository.movementRepo.insertMovement(InventoryMovement(
        id: 'INIT_FAST_CHECKOUT',
        itemId: 'item_fast_checkout',
        storeId: testStoreId,
        delta: 100000,
        type: MovementType.purchase,
        deviceId: 'pos_dev_1',
        operationId: 'op_init_fast_checkout',
        createdAt: DateTime.now(),
      ));

      final itemObj = InventoryItem(
        id: 'item_fast_checkout',
        storeId: testStoreId,
        name: 'Speedy Coffee',
        price: 4.50,
        category: 'Beverages',
        status: 'Available',
        trackStock: true,
      );

      // Measure 50 consecutive checkouts
      final latencies = <int>[];
      for (int i = 0; i < 50; i++) {
        final orderId = 'ord_bench_$i';
        final order = OrderModel(
          id: orderId,
          storeId: testStoreId,
          total: 9.0,
          date: DateTime.now(),
          status: 'Completed',
          type: 'Takeaway',
          paymentMethod: i % 3 == 0 ? 'Cash' : (i % 3 == 1 ? 'Card' : 'UPI'),
          items: [
            OrderItem(
              item: itemObj,
              quantity: 2,
            ),
          ],
        );

        final event = BusinessEvent(
          id: 'evt_bench_$i',
          storeId: testStoreId,
          entityType: 'ORDER',
          entityId: orderId,
          eventType: 'CREATE',
          amount: 9.0,
          createdAt: DateTime.now(),
          deviceId: 'pos_dev_1',
        );

        final sw = Stopwatch()..start();
        await repository.performAtomicCheckout(
          order: order,
          storeId: testStoreId,
          yearMonth: '2026-09',
          movements: [
            InventoryMovement(
              id: 'mov_bench_$i',
              itemId: 'item_fast_checkout',
              storeId: testStoreId,
              delta: -2,
              type: MovementType.sale,
              orderId: orderId,
              deviceId: 'pos_dev_1',
              operationId: 'op_bench_$i',
              createdAt: DateTime.now(),
            ),
          ],
          event: event,
        );
        sw.stop();
        latencies.add(sw.elapsedMicroseconds);
      }

      final avgLatencyMicros =
          latencies.reduce((a, b) => a + b) / latencies.length;
      final avgLatencyMs = avgLatencyMicros / 1000.0;
      final p95LatencyMs =
          (latencies..sort())[(latencies.length * 0.95).toInt()] / 1000.0;

      print('----------------------------------------------------');
      print('⚡ [CHECKOUT LATENCY BENCHMARK]');
      print('50 Atomic Checkouts Executed');
      print('Average Checkout Latency: ${avgLatencyMs.toStringAsFixed(2)}ms');
      print('p95 Checkout Latency: ${p95LatencyMs.toStringAsFixed(2)}ms');
      print('----------------------------------------------------');

      expect(avgLatencyMs,
          lessThan(50.0)); // Strict SLA: <50ms per atomic checkout
    });

    test('Benchmark 3: Multi-Device Concurrent Checkout Simulation', () async {
      final db = await dbHelper.database;
      await db.insert('inventory', {
        'id': 'item_concurrent',
        'storeId': testStoreId,
        'name': 'Shared Stock Item',
        'price': 10.0,
        'quantity': 100000,
        'category': 'General',
        'status': 'Available',
      });
      await repository.movementRepo.insertMovement(InventoryMovement(
        id: 'INIT_CONCURRENT',
        itemId: 'item_concurrent',
        storeId: testStoreId,
        delta: 100000,
        type: MovementType.purchase,
        deviceId: 'setup',
        operationId: 'op_init_concurrent',
        createdAt: DateTime.now(),
      ));

      final itemConcurrent = InventoryItem(
        id: 'item_concurrent',
        storeId: testStoreId,
        name: 'Shared Stock Item',
        price: 10.0,
        category: 'General',
        status: 'Available',
        trackStock: true,
      );

      // 5 concurrent simulated devices executing 20 checkouts simultaneously (100 orders total)
      final sw = Stopwatch()..start();
      final futures = <Future<void>>[];

      for (int dev = 1; dev <= 5; dev++) {
        final deviceId = 'POS_TERMINAL_$dev';
        futures.add(Future(() async {
          for (int i = 0; i < 20; i++) {
            final orderId = 'ord_${deviceId}_$i';
            final order = OrderModel(
              id: orderId,
              storeId: testStoreId,
              total: 10.0,
              date: DateTime.now(),
              status: 'Completed',
              type: 'Dine-In',
              paymentMethod: 'UPI',
              items: [
                OrderItem(
                  item: itemConcurrent,
                  quantity: 1,
                ),
              ],
            );

            final event = BusinessEvent(
              id: 'evt_${deviceId}_$i',
              storeId: testStoreId,
              entityType: 'ORDER',
              entityId: orderId,
              eventType: 'CREATE',
              amount: 10.0,
              createdAt: DateTime.now(),
              deviceId: deviceId,
            );

            await repository.performAtomicCheckout(
              order: order,
              storeId: testStoreId,
              yearMonth: '2026-09',
              movements: [
                InventoryMovement(
                  id: 'mov_${deviceId}_$i',
                  itemId: 'item_concurrent',
                  storeId: testStoreId,
                  delta: -1,
                  type: MovementType.sale,
                  orderId: orderId,
                  deviceId: deviceId,
                  operationId: 'op_${deviceId}_$i',
                  createdAt: DateTime.now(),
                ),
              ],
              event: event,
            );
          }
        }));
      }

      await Future.wait(futures);
      sw.stop();
      final totalElapsedMs = sw.elapsedMilliseconds;
      final throughput = (100.0 / (totalElapsedMs / 1000.0));

      print('----------------------------------------------------');
      print('⚡ [CONCURRENT MULTI-DEVICE BENCHMARK]');
      print('5 Simultaneous Devices, 100 Total Atomic Checkouts');
      print('Total Time: ${totalElapsedMs}ms');
      print('Throughput: ${throughput.toStringAsFixed(1)} checkouts/sec');
      print('----------------------------------------------------');

      expect(totalElapsedMs, lessThan(3000));
    });

    test('Benchmark 4: Scalability across 1k, 10k, and 100k Orders', () async {
      final db = await dbHelper.database;
      final now = DateTime.now();

      print('----------------------------------------------------');
      print('⚡ [DATASET SCALING BENCHMARK: 1,000 -> 10,000 -> 100,000 ORDERS]');

      // Helper to batch insert orders
      Future<void> seedOrders(int count, int startIndex) async {
        final batch = db.batch();
        for (int i = startIndex; i < startIndex + count; i++) {
          final id = 'ORD_${i.toString().padLeft(6, '0')}';
          final date = now.subtract(Duration(minutes: i));
          final status = (i % 20 == 0)
              ? 'Cancelled'
              : ((i % 15 == 0) ? 'Refunded' : 'Completed');
          final payment =
              (i % 3 == 0) ? 'Cash' : ((i % 3 == 1) ? 'Card' : 'UPI');
          final total = 50.0 + (i % 500);

          batch.insert('orders', {
            'id': id,
            'storeId': testStoreId,
            'date': date.toIso8601String(),
            'total': total,
            'subtotal': total,
            'status': status,
            'paymentMethod': payment,
            'isDeleted': 0,
            'syncStatus': 'CONFIRMED',
            'updatedAt': date.toIso8601String(),
          });
        }
        await batch.commit(noResult: true);
      }

      // Step 4A: 1,000 Orders Baseline
      await seedOrders(1000, 0);

      // Measure Keyset Pagination Latency on 1k
      var sw = Stopwatch()..start();
      var page1 = await repository.getPaginatedOrders(testStoreId, limit: 20);
      sw.stop();
      final p1kTime = sw.elapsedMicroseconds / 1000.0;

      // Measure Sales Aggregation on 1k
      sw = Stopwatch()..start();
      var stats1k = await repository.getSalesStats(testStoreId);
      sw.stop();
      final s1kTime = sw.elapsedMicroseconds / 1000.0;

      print('1,000 Orders:');
      print('  - Keyset Page 1 (20 orders): ${p1kTime.toStringAsFixed(2)}ms');
      print(
          '  - Aggregated Report: ${s1kTime.toStringAsFixed(2)}ms (Sales: ₹${stats1k['totalSales']}, Orders: ${stats1k['orderCount']})');

      // Step 4B: Scale to 10,000 Orders Stress
      await seedOrders(9000, 1000);

      sw = Stopwatch()..start();
      var page10k = await repository.getPaginatedOrders(testStoreId, limit: 20);
      sw.stop();
      final p10kTime = sw.elapsedMicroseconds / 1000.0;

      // Keyset Deep Page test: page through using cursor
      final lastDate = page10k.last.date;
      final lastId = page10k.last.id;
      sw = Stopwatch()..start();
      var page10kDeep = await repository.getPaginatedOrders(testStoreId,
          limit: 20, lastDate: lastDate, lastId: lastId);
      sw.stop();
      final p10kDeepTime = sw.elapsedMicroseconds / 1000.0;

      sw = Stopwatch()..start();
      var stats10k = await repository.getSalesStats(testStoreId);
      sw.stop();
      final s10kTime = sw.elapsedMicroseconds / 1000.0;

      print('10,000 Orders:');
      print('  - Keyset Page 1 (20 orders): ${p10kTime.toStringAsFixed(2)}ms');
      print(
          '  - Keyset Deep Cursor Page: ${p10kDeepTime.toStringAsFixed(2)}ms');
      print(
          '  - Aggregated Report: ${s10kTime.toStringAsFixed(2)}ms (Sales: ₹${stats10k['totalSales']}, Orders: ${stats10k['orderCount']})');

      // Step 4C: Scale to 100,000 Orders Enterprise Scale
      // Insert in chunks of 15,000 to keep SQLite batch happy
      for (int chunk = 10000; chunk < 100000; chunk += 15000) {
        await seedOrders(15000, chunk);
      }

      sw = Stopwatch()..start();
      var page100k =
          await repository.getPaginatedOrders(testStoreId, limit: 20);
      sw.stop();
      final p100kTime = sw.elapsedMicroseconds / 1000.0;

      // Keyset Deep Cursor at 100k
      final cursorDate = page100k.last.date;
      final cursorId = page100k.last.id;
      sw = Stopwatch()..start();
      var page100kDeep = await repository.getPaginatedOrders(testStoreId,
          limit: 20, lastDate: cursorDate, lastId: cursorId);
      sw.stop();
      final p100kDeepTime = sw.elapsedMicroseconds / 1000.0;

      // Filtered Keyset query (date range + status + payment)
      sw = Stopwatch()..start();
      var filteredOrders = await repository.getPaginatedOrders(
        testStoreId,
        limit: 20,
        status: 'Completed',
        paymentMethod: 'UPI',
        start: now.subtract(const Duration(days: 7)),
        end: now,
      );
      sw.stop();
      final p100kFilteredTime = sw.elapsedMicroseconds / 1000.0;

      // Aggregated SQL report on 100,000 rows
      sw = Stopwatch()..start();
      var stats100k = await repository.getSalesStats(testStoreId);
      sw.stop();
      final s100kTime = sw.elapsedMicroseconds / 1000.0;

      print('100,000 Orders:');
      print('  - Keyset Page 1 (20 orders): ${p100kTime.toStringAsFixed(2)}ms');
      print('  - Keyset Deep Cursor: ${p100kDeepTime.toStringAsFixed(2)}ms');
      print(
          '  - Filtered Keyset (Status+Payment+Date): ${p100kFilteredTime.toStringAsFixed(2)}ms');
      print(
          '  - Aggregated Report on 100k orders: ${s100kTime.toStringAsFixed(2)}ms');
      print(
          '    -> Completed Sales: ₹${stats100k['statusBreakdown']['Completed']}');
      print(
          '    -> Refunded Sales: ₹${stats100k['statusBreakdown']['Refunded']}');
      print('    -> Payment Breakdown: ${stats100k['paymentBreakdown']}');
      print('----------------------------------------------------');

      // Verify Keyset scalability across 100,000 orders
      expect(p100kTime, lessThan(200.0));
      expect(p100kDeepTime, lessThan(200.0));
      expect(p100kFilteredTime, lessThan(100.0));
      expect(
          s100kTime, lessThan(1500.0)); // 100k full table aggregation in <1.5s!
    });

    test('Benchmark 5: Large Inventory Catalog (10,000 items) & Instant Search',
        () async {
      final db = await dbHelper.database;
      print('----------------------------------------------------');
      print('⚡ [LARGE INVENTORY CATALOG BENCHMARK: 10,000 ITEMS]');

      final batch = db.batch();
      for (int i = 0; i < 10000; i++) {
        final cat = (i % 5 == 0)
            ? 'Produce'
            : (i % 5 == 1 ? 'Dairy' : (i % 5 == 2 ? 'Bakery' : 'Beverages'));
        batch.insert('inventory', {
          'id': 'ITEM_${i.toString().padLeft(5, '0')}',
          'storeId': testStoreId,
          'name': 'Product Item #$i $cat Spec',
          'sku': 'SKU-${(100000 + i)}',
          'price': 10.0 + (i % 100),
          'quantity': 50 + (i % 200),
          'category': cat,
          'status': 'Available',
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
      await batch.commit(noResult: true);

      // 1. Keyset pagination on 10,000 items
      var sw = Stopwatch()..start();
      final page1 =
          await repository.getPaginatedInventory(testStoreId, limit: 50);
      sw.stop();
      final page1Time = sw.elapsedMicroseconds / 1000.0;

      // 2. Exact SKU lookup using idx_inventory_store_sku
      sw = Stopwatch()..start();
      final skuResults =
          await repository.searchInventory(testStoreId, 'SKU-105432');
      sw.stop();
      final skuSearchTime = sw.elapsedMicroseconds / 1000.0;

      // 3. Name prefix search using idx_inventory_store_name
      sw = Stopwatch()..start();
      final nameResults =
          await repository.searchInventory(testStoreId, 'Product Item #88');
      sw.stop();
      final nameSearchTime = sw.elapsedMicroseconds / 1000.0;

      // 4. Full catalog read (without O(N) movement recalculation!)
      sw = Stopwatch()..start();
      final allItems = await repository.getInventory(testStoreId);
      sw.stop();
      final fullCatalogTime = sw.elapsedMilliseconds;

      print('Inventory Catalog (10,000 items):');
      print('  - Keyset Page (50 items): ${page1Time.toStringAsFixed(2)}ms');
      print(
          '  - Exact SKU Search: ${skuSearchTime.toStringAsFixed(2)}ms (found ${skuResults.length})');
      print(
          '  - Name Substring Search: ${nameSearchTime.toStringAsFixed(2)}ms (found ${nameResults.length})');
      print('  - Full 10,000 items load: ${fullCatalogTime}ms');
      print('----------------------------------------------------');

      expect(page1Time, lessThan(50.0));
      expect(skuSearchTime, lessThan(15.0));
      expect(nameSearchTime, lessThan(50.0));
      expect(fullCatalogTime, lessThan(2000));
    });

    test('Benchmark 6: Large Customer Catalog (50,000 customers) & Search',
        () async {
      final db = await dbHelper.database;
      print('----------------------------------------------------');
      print('⚡ [LARGE CUSTOMER CATALOG BENCHMARK: 50,000 CUSTOMERS]');

      // Insert 50,000 customers in batches of 10,000
      for (int chunk = 0; chunk < 50000; chunk += 10000) {
        final batch = db.batch();
        for (int i = chunk; i < chunk + 10000; i++) {
          final phone = '98765${i.toString().padLeft(5, '0')}';
          batch.insert('customers', {
            'id': 'CUST_${i.toString().padLeft(6, '0')}',
            'storeId': testStoreId,
            'name': 'Customer $i Smith',
            'phone': phone,
            'mobile': phone,
            'email': 'customer$i@example.com',
            'tier': 'Silver',
            'totalSpent': 150.0,
            'loyaltyPoints': i % 500,
            'joinDate': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }
        await batch.commit(noResult: true);
      }

      // 1. Keyset pagination on 50,000 customers
      var sw = Stopwatch()..start();
      final page1 =
          await repository.getPaginatedCustomers(testStoreId, limit: 50);
      sw.stop();
      final pageTime = sw.elapsedMicroseconds / 1000.0;

      // 2. Phone index lookup on 50,000 customers using idx_customers_store_phone
      sw = Stopwatch()..start();
      final phoneResults =
          await repository.searchCustomers(testStoreId, '9876523456');
      sw.stop();
      final phoneSearchTime = sw.elapsedMicroseconds / 1000.0;

      // 3. Name partial search
      sw = Stopwatch()..start();
      final nameResults =
          await repository.searchCustomers(testStoreId, 'Customer 4242');
      sw.stop();
      final nameSearchTime = sw.elapsedMicroseconds / 1000.0;

      print('Customer Catalog (50,000 customers):');
      print('  - Keyset Page (50 customers): ${pageTime.toStringAsFixed(2)}ms');
      print(
          '  - Phone Lookup (indexed): ${phoneSearchTime.toStringAsFixed(2)}ms (found ${phoneResults.length})');
      print(
          '  - Name Partial Search: ${nameSearchTime.toStringAsFixed(2)}ms (found ${nameResults.length})');
      print('----------------------------------------------------');

      expect(pageTime, lessThan(80.0));
      expect(phoneSearchTime, lessThan(30.0));
      expect(nameSearchTime, lessThan(120.0));
    });

    test('Benchmark 7: Large Sync Queue & Batched Outbound Processing',
        () async {
      print('----------------------------------------------------');
      print('⚡ [LARGE SYNC QUEUE BENCHMARK: 1,000 OPERATIONS]');

      final queueBox = await Hive.openBox('perf_outbox_queue');
      final failedBox = await Hive.openBox('perf_outbox_failed');

      final outboxStore = OutboxStore(
        getQueueBox: () => queueBox,
        getFailedQueueBox: () => failedBox,
        getRepository: () => repository,
      );

      // Enqueue 1,000 operations
      final swEnqueue = Stopwatch()..start();
      final opIds = <String>[];
      for (int i = 0; i < 1000; i++) {
        final op = OutboxOperation(
          operationId: 'op_queue_$i',
          storeId: testStoreId,
          userId: 'usr_bench',
          deviceId: 'dev_pos_1',
          collection: 'orders',
          entityId: 'ord_queued_$i',
          operation: 'CREATE',
          payload: {'id': 'ord_queued_$i', 'total': 100.0},
          baseVersion: 1,
          newVersion: 1,
        );
        opIds.add(op.operationId);
        await outboxStore.enqueue(op);
      }
      swEnqueue.stop();
      final enqueueTime = swEnqueue.elapsedMilliseconds;
      final enqueueRate = (1000.0 / (enqueueTime / 1000.0));

      // Batch transition to IN_FLIGHT
      final swInFlight = Stopwatch()..start();
      await outboxStore.markInFlight(opIds);
      swInFlight.stop();
      final inFlightTime = swInFlight.elapsedMilliseconds;

      // Batch transition to PUSHED
      final swPushed = Stopwatch()..start();
      await outboxStore
          .markBatchPushed(opIds, auditMetadata: {'benchmark': true});
      swPushed.stop();
      final pushedTime = swPushed.elapsedMilliseconds;

      final totalProcessTime = inFlightTime + pushedTime;
      final queueProcessingRate = (1000.0 / (totalProcessTime / 1000.0));

      print('Sync Queue Performance (1,000 operations):');
      print(
          '  - Enqueue 1,000 ops: ${enqueueTime}ms (${enqueueRate.toStringAsFixed(1)} ops/sec)');
      print('  - Batch Mark IN_FLIGHT: ${inFlightTime}ms');
      print('  - Batch Mark PUSHED: ${pushedTime}ms');
      print(
          '  - Queue Processing Rate: ${queueProcessingRate.toStringAsFixed(1)} ops/sec');
      print('----------------------------------------------------');

      expect(inFlightTime, lessThan(250));
      expect(pushedTime, lessThan(250));
      expect(queueProcessingRate,
          greaterThan(1500)); // >1500 ops/sec processing rate!
    });

    test('Benchmark 8: Inbound Deduplication & Batched Inbox Persistence',
        () async {
      print('----------------------------------------------------');
      print('⚡ [INBOUND DEDUPLICATION & INBOX BATCHING: 1,000 RECORDS]');

      final inboxStore = InboxStore();
      await inboxStore.init();

      final records = <Map<String, dynamic>>[];
      for (int i = 0; i < 1000; i++) {
        records.add({
          'collection': 'inventory_movements',
          'docId': 'doc_inbound_$i',
          'operationId': 'op_inbound_$i',
          'version': 1,
          'storeId': testStoreId,
          'processedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }

      final sw = Stopwatch()..start();
      await inboxStore.recordProcessedBatch(records);
      sw.stop();
      final batchRecordTime = sw.elapsedMilliseconds;

      // Verify deduplication check rate on 1,000 items
      final swCheck = Stopwatch()..start();
      int dupCount = 0;
      for (int i = 0; i < 1000; i++) {
        if (inboxStore.isAlreadyProcessed(
            'inventory_movements', 'doc_inbound_$i',
            operationId: 'op_inbound_$i')) {
          dupCount++;
        }
      }
      swCheck.stop();
      final checkTime = swCheck.elapsedMicroseconds / 1000.0;

      print('Inbound Deduplication Performance:');
      print('  - Batch Record 1,000 Inbound Ops: ${batchRecordTime}ms');
      print(
          '  - Deduplication Check 1,000 Ops: ${checkTime.toStringAsFixed(2)}ms (found $dupCount dups)');
      print('----------------------------------------------------');

      expect(dupCount, equals(1000));
      expect(batchRecordTime, lessThan(100));
      expect(checkTime, lessThan(20.0)); // <0.02ms per check!
    });
  });
}
