import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/models/inventory_item.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';

class InventoryRepository {
  final DatabaseHelper dbHelper;
  final InventoryMovementRepository movementRepo;

  InventoryRepository({
    required this.dbHelper,
    required this.movementRepo,
  });

  // --- INVENTORY ---

  Future<void> insertInventory(InventoryItem item) async {
       final db = await dbHelper.database;
       try {
         await db.insert(
           'inventory',
           item.toSqlMap(),
           conflictAlgorithm: ConflictAlgorithm.replace
         );
       } catch (e) {
         rethrow;
       }
  }

  Future<int> getPendingInventoryDelta(String itemId, {String? storeId}) async {
    return await movementRepo.getPendingDelta(itemId, storeId: storeId);
  }

  Future<void> updateInventoryCache(String itemId, int quantity, String storeId) async {
    final db = await dbHelper.database;
    await db.insert(
      'cache_inventory_quantities',
      {'itemId': itemId, 'quantity': quantity, 'storeId': storeId},
      conflictAlgorithm: ConflictAlgorithm.replace
    );
    await db.rawUpdate(
      'UPDATE inventory SET quantity = ? WHERE id = ?',
      [quantity, itemId]
    );
  }

  Future<void> insertMovement(InventoryMovement movement, {Transaction? txn}) async {
      await movementRepo.insertMovement(movement, txn: txn);
  }

  Future<void> rebuildQuantityCache(String storeId) async {
    await movementRepo.rebuildQuantityCache(storeId);
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

  Future<List<InventoryItem>> getInventory(String? storeId, {String? category}) async {
    final db = await dbHelper.database;
    
    String sql = 'SELECT * FROM inventory WHERE deletedAt IS NULL';
    List<dynamic> args = [];

    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    
    if (category != null && category != 'All') {
      sql += ' AND category = ?';
      args.add(category);
    }

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
      final rows = await db.rawQuery('SELECT * FROM inventory');
      return rows.map((r) => InventoryItem.fromSql(r)).toList();
    } catch (e) {
       return [];
    }
  }
}
