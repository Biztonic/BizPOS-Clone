import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/models/inventory_item.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';
import 'package:biztonic_pos/features/inventory/domain/policies/inventory_policy.dart';
import 'package:biztonic_pos/core/audit/audit_models.dart';
import 'package:biztonic_pos/core/audit/audit_service.dart';

mixin InventoryRepositoryMixin {
  Future<Database> get database;
  DatabaseHelper get dbHelper;
  InventoryMovementRepository get movementRepo;

  // --- INVENTORY ---

  Future<void> insertInventory(InventoryItem item) async {
    final db = await dbHelper.database;
    try {
      final prevRows = await db.query('inventory', columns: ['price', 'name'], where: 'id = ?', whereArgs: [item.id]);
      if (prevRows.isNotEmpty) {
        final oldPrice = (prevRows.first['price'] as num?)?.toDouble();
        if (oldPrice != null && oldPrice != item.price) {
          await AuditService().recordAction(
            storeId: item.storeId,
            action: AuditActionType.priceChange,
            actorId: 'admin',
            entityId: item.id,
            entityType: 'INVENTORY_ITEM',
            reason: 'Item price changed from $oldPrice to ${item.price}',
            previousState: {'price': oldPrice, 'name': item.name},
            newState: {'price': item.price, 'name': item.name},
          );
        }
      }

      await db.insert('inventory', item.toSqlMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      rethrow;
    }
  }

  /// Get total delta for pending (unsynced) inventory movements for an item
  Future<int> getPendingInventoryDelta(String itemId, {String? storeId}) async {
    return await movementRepo.getPendingDelta(itemId, storeId: storeId);
  }

  /// Manually update the quantity cache for an item (used during sync reconciliation)
  Future<void> updateInventoryCache(
      String itemId, int quantity, String storeId) async {
    final db = await dbHelper.database;
    await db.insert('cache_inventory_quantities',
        {'itemId': itemId, 'quantity': quantity, 'storeId': storeId},
        conflictAlgorithm: ConflictAlgorithm.replace);
    await db.rawUpdate(
        'UPDATE inventory SET quantity = ? WHERE id = ?', [quantity, itemId]);
  }

  Future<void> insertMovement(InventoryMovement movement,
      {Transaction? txn, NegativeStockPolicy? negativeStockPolicy}) async {
    await movementRepo.insertMovement(movement,
        txn: txn, negativeStockPolicy: negativeStockPolicy);
  }

  /// Rebuild the entire inventory quantity projection from the authoritative ledger
  Future<Map<String, int>> rebuildInventoryProjection(String storeId) async {
    return await movementRepo.rebuildInventoryProjection(storeId);
  }

  /// Backward-compatible alias for rebuildInventoryProjection
  Future<void> rebuildQuantityCache(String storeId) async {
    await movementRepo.rebuildInventoryProjection(storeId);
  }

  /// Reconcile inventory stock with movements ledger
  Future<ReconciliationReport> reconcileInventory(String storeId,
      {bool autoRepair = true}) async {
    return await movementRepo.reconcileInventory(storeId,
        autoRepair: autoRepair);
  }

  /// Backward-compatible alias for reconcileInventory
  Future<Map<String, int>> reconcileInventoryStock(String storeId) async {
    final report =
        await movementRepo.reconcileInventory(storeId, autoRepair: true);
    return Map.fromEntries(report.discrepancies
        .map((d) => MapEntry(d.itemId, d.expectedQuantity)));
  }

  // --- BATCH INVENTORY ---
  Future<void> batchInsertInventory(List<InventoryItem> items) async {
    if (items.isEmpty) return;

    final db = await dbHelper.database;
    final batch = db.batch();

    for (var item in items) {
      batch.insert(
        'inventory',
        item.toSqlMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<InventoryItem>> getInventory(String? storeId,
      {String? category}) async {
    final db = await dbHelper.database;

    String sql = 'SELECT * FROM inventory WHERE deletedAt IS NULL';
    List<dynamic> args = [];

    if (storeId != null && storeId.isNotEmpty) {
      sql += ' AND (storeId = ? OR storeId IS NULL OR storeId = \'\')';
      args.add(storeId);
    }

    if (category != null && category != 'All') {
      sql += ' AND category = ?';
      args.add(category);
    }

    sql += ' ORDER BY name ASC';

    final rows = await db.rawQuery(sql, args);
    return rows.map((r) => InventoryItem.fromSql(r)).toList();
  }

  /// Keyset paginated inventory retrieval
  Future<List<InventoryItem>> getPaginatedInventory(
    String? storeId, {
    int limit = 50,
    String? lastId,
    String? category,
  }) async {
    final db = await dbHelper.database;
    String sql = 'SELECT * FROM inventory WHERE deletedAt IS NULL';
    List<dynamic> args = [];

    if (storeId != null && storeId.isNotEmpty) {
      sql += ' AND (storeId = ? OR storeId IS NULL OR storeId = \'\')';
      args.add(storeId);
    }

    if (category != null && category != 'All') {
      sql += ' AND category = ?';
      args.add(category);
    }

    if (lastId != null && lastId.isNotEmpty) {
      sql += ' AND id > ?';
      args.add(lastId);
    }

    sql += ' ORDER BY id ASC LIMIT ?';
    args.add(limit);

    final rows = await db.rawQuery(sql, args);
    return rows.map((r) => InventoryItem.fromSql(r)).toList();
  }

  /// Indexed search by SKU exact/prefix, item name, or category
  Future<List<InventoryItem>> searchInventory(
    String? storeId,
    String query, {
    int limit = 50,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final db = await dbHelper.database;

    // Fast indexed path: Check exact SKU / barcode match first using idx_inventory_store_sku
    if (!cleanQuery.contains(' ') && storeId != null && storeId.isNotEmpty) {
      final skuRows = await db.rawQuery(
        'SELECT * FROM inventory WHERE storeId = ? AND sku = ? AND deletedAt IS NULL LIMIT ?',
        [storeId, cleanQuery, limit],
      );
      if (skuRows.isNotEmpty) {
        return skuRows.map((r) => InventoryItem.fromSql(r)).toList();
      }
    }

    String sql = 'SELECT * FROM inventory WHERE deletedAt IS NULL';
    List<dynamic> args = [];

    if (storeId != null && storeId.isNotEmpty) {
      sql += ' AND (storeId = ? OR storeId IS NULL OR storeId = \'\')';
      args.add(storeId);
    }

    sql += ' AND (sku = ? OR name LIKE ? OR category LIKE ?)';
    args.addAll([cleanQuery, '%$cleanQuery%', '%$cleanQuery%']);

    sql += ' ORDER BY name ASC LIMIT ?';
    args.add(limit);

    final rows = await db.rawQuery(sql, args);
    return rows.map((r) => InventoryItem.fromSql(r)).toList();
  }

  Future<InventoryItem?> getInventoryItem(String id, {String? storeId}) async {
    final db = await dbHelper.database;
    final rows = await db.query('inventory', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;

    return InventoryItem.fromSql(rows.first);
  }

  // DEBUG: Get ALL items (no filter)
  Future<List<InventoryItem>> getAllInventoryDebug() async {
    final db = await dbHelper.database;
    try {
      // Using rawQuery
      final rows = await db.rawQuery('SELECT * FROM inventory');

      final items = rows.map((r) => InventoryItem.fromSql(r)).toList();

      // Compute quantities from movements
      final allQuantities = await db.rawQuery('''
        SELECT itemId, SUM(delta) as quantity
        FROM inventory_movements
        GROUP BY itemId
      ''');

      final quantityMap = Map.fromEntries(allQuantities.map((row) =>
          MapEntry(row['itemId'] as String, (row['quantity'] as int?) ?? 0)));

      for (int i = 0; i < items.length; i++) {
        items[i] = items[i].copyWith(quantity: quantityMap[items[i].id] ?? 0);
      }

      return items;
    } catch (e) {
      return [];
    }
  }
}
