import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';

void main() {
  late Directory tempDir;
  late InventoryMovementRepository movementRepo;

  const storeA = 'STORE_PROJ_A';
  const storeB = 'STORE_PROJ_B';
  const itemA1 = 'ITEM_PROJ_A1';
  const itemA2 = 'ITEM_PROJ_A2';
  const itemB1 = 'ITEM_PROJ_B1';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('repo_projection_test_');
    final dbPath = p.join(tempDir.path, 'repo_projection.db');
    DatabaseHelper.setDbName(dbPath);

    Hive.init(tempDir.path);
    await Hive.openBox('cache_inventory');

    movementRepo = InventoryMovementRepository();
  });

  tearDown(() async {
    await Hive.close();
    await DatabaseHelper().close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group(
      'Repository Tests: Inventory Projection Rebuild from Append-Only Ledger',
      () {
    test('1. Corrupted inventory cache is repaired to ground truth ledger sum',
        () async {
      final db = await DatabaseHelper().database;

      // 1. Seed item with corrupted/stale quantity in table (says 999)
      await db.insert('inventory', {
        'id': itemA1,
        'storeId': storeA,
        'name': 'Matcha Latte',
        'price': 200.0,
        'cost': 80.0,
        'quantity': 999, // STALE / CORRUPTED
        'category': 'Beverages',
        'status': 'ACTIVE',
        'trackStock': 1,
        'isDeleted': 0,
      });

      // 2. Insert ground-truth append-only movements in ledger:
      // +50 (Purchase)
      // -12 (Sale)
      // -5  (Sale)
      // +10 (Stock adjustment)
      // Net should be: 50 - 12 - 5 + 10 = 43
      final now = DateTime.now().toIso8601String();
      await db.insert('inventory_movements', {
        'id': 'MVT_P1',
        'itemId': itemA1,
        'storeId': storeA,
        'delta': 50,
        'type': 'PURCHASE',
        'createdAt': now,
        'operationId': 'op_p1',
        'isDeleted': 0,
      });
      await db.insert('inventory_movements', {
        'id': 'MVT_S1',
        'itemId': itemA1,
        'storeId': storeA,
        'delta': -12,
        'type': 'SALE',
        'createdAt': now,
        'operationId': 'op_s1',
        'isDeleted': 0,
      });
      await db.insert('inventory_movements', {
        'id': 'MVT_S2',
        'itemId': itemA1,
        'storeId': storeA,
        'delta': -5,
        'type': 'SALE',
        'createdAt': now,
        'operationId': 'op_s2',
        'isDeleted': 0,
      });
      await db.insert('inventory_movements', {
        'id': 'MVT_A1',
        'itemId': itemA1,
        'storeId': storeA,
        'delta': 10,
        'type': 'ADJUSTMENT',
        'createdAt': now,
        'operationId': 'op_a1',
        'isDeleted': 0,
      });

      // Execute projection rebuild
      final rebuiltSums = await movementRepo.rebuildInventoryProjection(storeA);
      expect(rebuiltSums[itemA1], 43);

      // Verify inventory table quantity repaired from 999 to 43
      final itemRows =
          await db.query('inventory', where: 'id = ?', whereArgs: [itemA1]);
      expect(itemRows.first['quantity'], 43);

      // Verify cache_inventory_quantities projection table updated
      final cacheRows = await db.query('cache_inventory_quantities',
          where: 'itemId = ?', whereArgs: [itemA1]);
      expect(cacheRows.length, 1);
      expect(cacheRows.first['quantity'], 43);
    });

    test('2. Multi-item and multi-tenant isolation during projection rebuild',
        () async {
      final db = await DatabaseHelper().database;
      final now = DateTime.now().toIso8601String();

      // Seed Store A items
      await db.insert('inventory',
          {'id': itemA1, 'storeId': storeA, 'name': 'Item A1', 'quantity': 0});
      await db.insert('inventory',
          {'id': itemA2, 'storeId': storeA, 'name': 'Item A2', 'quantity': 0});

      // Seed Store B item
      await db.insert('inventory', {
        'id': itemB1,
        'storeId': storeB,
        'name': 'Item B1',
        'quantity': 500
      });

      // Seed movements
      await db.insert('inventory_movements', {
        'id': 'M_A1',
        'itemId': itemA1,
        'storeId': storeA,
        'delta': 20,
        'type': 'PURCHASE',
        'createdAt': now,
        'operationId': 'op_m_a1',
        'isDeleted': 0
      });
      await db.insert('inventory_movements', {
        'id': 'M_A2',
        'itemId': itemA2,
        'storeId': storeA,
        'delta': 35,
        'type': 'PURCHASE',
        'createdAt': now,
        'operationId': 'op_m_a2',
        'isDeleted': 0
      });
      await db.insert('inventory_movements', {
        'id': 'M_B1',
        'itemId': itemB1,
        'storeId': storeB,
        'delta': 100,
        'type': 'PURCHASE',
        'createdAt': now,
        'operationId': 'op_m_b1',
        'isDeleted': 0
      });

      // Rebuild Store A
      final storeASums = await movementRepo.rebuildInventoryProjection(storeA);
      expect(storeASums[itemA1], 20);
      expect(storeASums[itemA2], 35);
      expect(storeASums.containsKey(itemB1), isFalse);

      // Store B table row must remain untouched at 500
      final storeBItem =
          await db.query('inventory', where: 'id = ?', whereArgs: [itemB1]);
      expect(storeBItem.first['quantity'], 500);
    });
  });
}
