import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';
import 'package:biztonic_pos/features/inventory/domain/entities/inventory_movement.dart';
import 'package:biztonic_pos/features/inventory/domain/use_cases/adjust_stock.dart';
import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';

void main() {
  late Directory tempDir;
  late InventoryMovementRepository movementRepo;
  late AdjustStockUseCase useCase;

  const testStoreId = 'STORE_BANGALORE_01';
  const testItemId = 'ITEM_COFFEE_01';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('app_stock_adjust_test_');
    final dbPath = p.join(tempDir.path, 'app_stock_adjust.db');
    DatabaseHelper.setDbName(dbPath);

    Hive.init(tempDir.path);
    await Hive.openBox('cache_inventory');

    movementRepo = InventoryMovementRepository();
    useCase = AdjustStockUseCase(movementRepo);

    final db = await DatabaseHelper().database;
    // 1. Seed item in inventory table
    await db.insert('inventory', {
      'id': testItemId,
      'storeId': testStoreId,
      'name': 'Filter Coffee Beans 500g',
      'price': 350.0,
      'cost': 180.0,
      'quantity': 25,
      'category': 'Packaged Goods',
      'status': 'ACTIVE',
      'trackStock': 1,
      'isDeleted': 0,
    });

    // 2. Seed initial stock in movement ledger (+25)
    await db.insert('inventory_movements', {
      'id': 'MOV_INIT_COFFEE_01',
      'itemId': testItemId,
      'storeId': testStoreId,
      'delta': 25,
      'type': 'PURCHASE',
      'cost': 180.0,
      'reason': 'Initial Stock',
      'deviceId': 'POS_BLR_1',
      'operationId': 'init_coffee_01',
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

  group('Application Tests: Stock Adjustment Workflow', () {
    test(
        '1. Positive stock adjustment increases quantity and dispatches InventoryAdjustedEvent',
        () async {
      InventoryAdjustedEvent? capturedEvent;
      final sub = EventBus.instance.on<InventoryAdjustedEvent>((event) {
        capturedEvent = event;
      });

      final movement = InventoryMovement(
        id: 'MOV_ADJ_ADD_10',
        itemId: testItemId,
        storeId: testStoreId,
        type: MovementType.adjustment,
        delta: 10,
        cost: 180.0,
        reason: 'Physical Audit Count Surplus',
        deviceId: 'POS_BLR_1',
        operationId: 'adj_add_coffee_01',
        createdAt: DateTime.now(),
      );

      final success =
          await useCase.execute(AdjustStockParams(movement: movement));
      expect(success, isTrue);

      // Verify stock increased from 25 to 35
      final quantities = await movementRepo.getAllQuantities(testStoreId);
      expect(quantities[testItemId], 35);

      // Verify event was fired on EventBus
      expect(capturedEvent, isNotNull);
      expect(capturedEvent!.itemId, testItemId);
      expect(capturedEvent!.delta, 10);
      expect(capturedEvent!.storeId, testStoreId);

      await sub.cancel();
    });

    test('2. Negative stock adjustment within limit decreases ledger quantity',
        () async {
      final movement = InventoryMovement(
        id: 'MOV_ADJ_SUB_5',
        itemId: testItemId,
        storeId: testStoreId,
        type: MovementType.adjustment,
        delta: -5,
        cost: 180.0,
        reason: 'Spillage / Damaged packaging',
        deviceId: 'POS_BLR_1',
        operationId: 'adj_sub_coffee_01',
        createdAt: DateTime.now(),
      );

      final success =
          await useCase.execute(AdjustStockParams(movement: movement));
      expect(success, isTrue);

      // Stock reduced from 25 to 20
      final quantities = await movementRepo.getAllQuantities(testStoreId);
      expect(quantities[testItemId], 20);
    });

    test(
        '3. Negative stock adjustment exceeding current stock returns false under BLOCK policy',
        () async {
      final excessiveReduction = InventoryMovement(
        id: 'MOV_ADJ_EXCESS',
        itemId: testItemId,
        storeId: testStoreId,
        type: MovementType.adjustment,
        delta: -30, // Current is 25 -> projected -5
        cost: 180.0,
        reason: 'Excessive audit deduction',
        deviceId: 'POS_BLR_1',
        operationId: 'adj_excess_coffee_01',
        createdAt: DateTime.now(),
      );

      // AdjustStockUseCase catches InsufficientStockException and returns false
      final success = await useCase
          .execute(AdjustStockParams(movement: excessiveReduction));
      expect(success, isFalse);

      // Stock should remain unmodified at 25
      final quantities = await movementRepo.getAllQuantities(testStoreId);
      expect(quantities[testItemId], 25);
    });

    test(
        '4. Cross-store adjustment is rejected preventing cross-tenant stock pollution',
        () async {
      final crossStoreMovement = InventoryMovement(
        id: 'MOV_CROSS_STORE_ADJ',
        itemId: testItemId, // belongs to testStoreId
        storeId: 'STORE_COMPLETELY_DIFFERENT', // different store!
        type: MovementType.adjustment,
        delta: 10,
        deviceId: 'POS_ROGUE',
        operationId: 'cross_store_adj_01',
        createdAt: DateTime.now(),
      );

      final success = await useCase
          .execute(AdjustStockParams(movement: crossStoreMovement));
      expect(success, isFalse);
    });
  });
}
