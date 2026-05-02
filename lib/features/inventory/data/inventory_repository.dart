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
    final items = rows.map((r) => InventoryItem.fromSql(r)).toList();
    
    final quantities = await movementRepo.getAllQuantities(storeId);
    
    for (int i = 0; i < items.length; i++) {
      items[i] = items[i].copyWith(quantity: quantities[items[i].id] ?? 0);
    }
    
    return items;
  }

  Future<InventoryItem?> getInventoryItem(String id, {String? storeId}) async {
    final db = await dbHelper.database;
    final rows = await db.query('inventory', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    
    final item = InventoryItem.fromSql(rows.first);
    final quantity = await movementRepo.getItemQuantity(id, storeId: storeId);
    return item.copyWith(quantity: quantity);
  }

  // DEBUG: Get ALL items (no filter)
  Future<List<InventoryItem>> getAllInventoryDebug() async {
    final db = await dbHelper.database;
    try {
      final rows = await db.rawQuery('SELECT * FROM inventory');
      final items = rows.map((r) => InventoryItem.fromSql(r)).toList();
      
      final allQuantities = await db.rawQuery('''
        SELECT itemId, SUM(delta) as quantity
        FROM inventory_movements
        GROUP BY itemId
      ''');
      
      final quantityMap = Map.fromEntries(
        allQuantities.map((row) => MapEntry(
          row['itemId'] as String,
          (row['quantity'] as int?) ?? 0
        ))
      );
      
      for (int i = 0; i < items.length; i++) {
        items[i] = items[i].copyWith(quantity: quantityMap[items[i].id] ?? 0);
      }
      
      return items;
    } catch (e) {
       return [];
    }
  }
}
