import 'package:sqflite/sqflite.dart';
import '../models/inventory_item.dart';
import 'database_helper.dart';

class InventoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // --- READS ---

  Future<List<InventoryItem>> getInventory(String? storeId, {String? queryStr, int limit = 100, int offset = 0}) async {
    try {
      final db = await _dbHelper.database;
      
      // 1. Fetch Items (Static Data)
      String whereClause = 'deletedAt IS NULL';
      List<dynamic> args = [];
      
      if (storeId != null) {
        whereClause += ' AND storeId = ?';
        args.add(storeId);
      }
      
      if (queryStr != null && queryStr.isNotEmpty) {
        whereClause += ' AND name LIKE ?';
        args.add('%$queryStr%');
      }

      final List<Map<String, dynamic>> maps = await db.query(
        'inventory',
        where: whereClause,
        whereArgs: args,
        limit: limit,
        offset: offset,
        orderBy: 'name ASC',
      );

      if (maps.isEmpty) return [];

      // 2. Fetch Cached Quantities for these items
      final itemIds = maps.map((m) => m['id'] as String).toList();
      final placeholders = List.filled(itemIds.length, '?').join(',');
      
      final List<Map<String, dynamic>> qtyMaps = await db.query(
        'cache_inventory_quantities',
        columns: ['itemId', 'quantity'],
        where: 'itemId IN ($placeholders)',
        whereArgs: itemIds,
      );
      
      final qtyMap = {for (var m in qtyMaps) m['itemId'] as String: (m['quantity'] as int)};

      // 3. Merge
      return List.generate(maps.length, (i) {
        final item = InventoryItem.fromSql(maps[i]);
        return item.copyWith(
          quantity: qtyMap[item.id] ?? 0
        );
      });
    } catch (e) {
      return [];
    }
  }
  
  Future<InventoryItem?> getItemById(String itemId) async {
    try {
      final db = await _dbHelper.database;
      final maps = await db.query(
        'inventory',
        where: 'id = ?',
        whereArgs: [itemId],
      );

      if (maps.isNotEmpty) {
         final item = InventoryItem.fromSql(maps.first);
         final qtyMap = await db.query(
           'cache_inventory_quantities',
           columns: ['quantity'],
           where: 'itemId = ?',
           whereArgs: [itemId]
         );
         final qty = (qtyMap.isNotEmpty) ? (qtyMap.first['quantity'] as int) : 0;
         return item.copyWith(quantity: qty);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- WRITES (Static Data Only) ---
  
  Future<void> insertInventory(InventoryItem item) async {
    final db = await _dbHelper.database;
    // Store static data. Quantity in this map will be ignored/0 per model update
    await db.insert(
      'inventory',
      item.toSqlMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteInventory(String id) async {
    final db = await _dbHelper.database;
    // Soft Delete
    await db.update(
      'inventory', 
      {
        'deletedAt': DateTime.now().toIso8601String(), 
        'syncStatus': 'PENDING'
      }, 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }
  
  // --- CACHE UPDATES (Called by Sync or MovementRepo) ---
  
  Future<void> updateQuantityCache(String itemId, int newQty, String storeId) async {
    final db = await _dbHelper.database;
    await db.insert(
      'cache_inventory_quantities',
      {'itemId': itemId, 'quantity': newQty, 'storeId': storeId},
      conflictAlgorithm: ConflictAlgorithm.replace
    );
  }
  
  Future<void> incrementQuantityCache(String itemId, int delta) async {
     final db = await _dbHelper.database;
     // Read-Modify-Write (Safe in transaction if needed, but simple update query is Atomic in SQLite)
     // atomic update: UPDATE cache SET quantity = quantity + delta WHERE itemId = ?
     await db.rawUpdate(
       'UPDATE cache_inventory_quantities SET quantity = quantity + ? WHERE itemId = ?',
       [delta, itemId]
     );
  }
}
