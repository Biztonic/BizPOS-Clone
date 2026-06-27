import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';

class InventoryMovementRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Insert a new inventory movement and update cache
  Future<void> insertMovement(InventoryMovement movement, {Transaction? txn}) async {
    if (txn != null) {
      await _insertMovementWithTxn(txn, movement);
    } else {
      final db = await _dbHelper.database;
      await db.transaction((newTxn) async {
        await _insertMovementWithTxn(newTxn, movement);
      });
    }
  }

  Future<void> _insertMovementWithTxn(Transaction txn, InventoryMovement movement) async {
    // 1. Insert Movement
    await txn.insert(
      'inventory_movements',
      movement.toSqlMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 2. Update Cache (Upsert-like logic using SQLite)
    // We use INSERT OR IGNORE to ensure row exists, then UPDATE
    await txn.rawInsert(
      'INSERT OR IGNORE INTO cache_inventory_quantities (itemId, storeId, quantity) VALUES (?, ?, 0)',
      [movement.itemId, movement.storeId]
    );
    
    await txn.rawUpdate(
      'UPDATE cache_inventory_quantities SET quantity = quantity + ? WHERE itemId = ? AND storeId = ?',
      [movement.delta, movement.itemId, movement.storeId]
    );

    // 3. Atomically update inventory table baseline quantity
    await txn.rawUpdate(
      'UPDATE inventory SET quantity = quantity + ? WHERE id = ?',
      [movement.delta, movement.itemId]
    );
  }

  /// Get all movements for a specific item
  Future<List<InventoryMovement>> getMovementsByItem(String itemId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inventory_movements',
      where: 'itemId = ?',
      whereArgs: [itemId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => InventoryMovement.fromMap(map, map['id'])).toList();
  }

  /// Get all movements for a store
  Future<List<InventoryMovement>> getMovementsByStore(String storeId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inventory_movements',
      where: 'storeId = ?',
      whereArgs: [storeId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => InventoryMovement.fromMap(map, map['id'])).toList();
  }

  /// Get current quantity for a specific item (SUM of all deltas, optionally filtered by store)
  Future<int> getItemQuantity(String itemId, {String? storeId}) async {
    final db = await _dbHelper.database;
    String sql = 'SELECT SUM(delta) as quantity FROM inventory_movements WHERE itemId = ?';
    List<dynamic> args = [itemId];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    final result = await db.rawQuery(sql, args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get quantities for all items (optionally filtered by store)
  Future<Map<String, int>> getAllQuantities(String? storeId) async {
    final db = await _dbHelper.database;
    String sql = '''
      SELECT itemId, SUM(delta) as quantity
      FROM inventory_movements
    ''';
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' WHERE storeId = ?';
      args.add(storeId);
    }
    sql += ' GROUP BY itemId';
    
    final result = await db.rawQuery(sql, args);
    
    return Map.fromEntries(
      result.map((row) => MapEntry(
        row['itemId'] as String, 
        (row['quantity'] as int?) ?? 0
      ))
    );
  }

  /// Get movements by type (SALE, PURCHASE, etc.)
  Future<List<InventoryMovement>> getMovementsByType(String? storeId, String type) async {
    final db = await _dbHelper.database;
    String sql = 'SELECT * FROM inventory_movements WHERE type = ?';
    List<dynamic> args = [type];
    
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    sql += ' ORDER BY createdAt DESC';

    final List<Map<String, dynamic>> maps = await db.rawQuery(sql, args);
    return maps.map((map) => InventoryMovement.fromMap(map, map['id'])).toList();
  }

  /// Get movements for a specific order
  Future<List<InventoryMovement>> getMovementsByOrder(String orderId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inventory_movements',
      where: 'orderId = ?',
      whereArgs: [orderId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => InventoryMovement.fromMap(map, map['id'])).toList();
  }

  /// Get pending movements (not synced)
  Future<List<InventoryMovement>> getPendingMovements() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inventory_movements',
      where: 'syncStatus = ?',
      whereArgs: ['PENDING'],
      orderBy: 'createdAt ASC',
    );
    return maps.map((map) => InventoryMovement.fromMap(map, map['id'])).toList();
  }

  /// Get total delta of pending movements for a specific item and store
  Future<int> getPendingDelta(String itemId, {String? storeId}) async {
    final db = await _dbHelper.database;
    String sql = 'SELECT SUM(delta) as total FROM inventory_movements WHERE itemId = ? AND syncStatus = ?';
    List<dynamic> args = [itemId, 'PENDING'];
    
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    
    final result = await db.rawQuery(sql, args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Mark movement as synced
  Future<void> markAsSynced(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'inventory_movements',
      {
        'syncStatus': 'CONFIRMED',
        'syncedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get movement count (optionally filtered by store)
  Future<int> getMovementCount(String? storeId) async {
    final db = await _dbHelper.database;
    String sql = 'SELECT COUNT(*) as count FROM inventory_movements';
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' WHERE storeId = ?';
      args.add(storeId);
    }
    final result = await db.rawQuery(sql, args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get movements within date range
  Future<List<InventoryMovement>> getMovementsByDateRange(
    String? storeId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _dbHelper.database;
    String sql = 'SELECT * FROM inventory_movements WHERE createdAt >= ? AND createdAt <= ?';
    List<dynamic> args = [startDate.toIso8601String(), endDate.toIso8601String()];
    
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    sql += ' ORDER BY createdAt DESC';

    final List<Map<String, dynamic>> maps = await db.rawQuery(sql, args);
    return maps.map((map) => InventoryMovement.fromMap(map, map['id'])).toList();
  }

  /// Get stock value (quantity * cost) for purchases
  Future<double> getStockValue(String? storeId) async {
    final db = await _dbHelper.database;
    String sql = "SELECT SUM(delta * COALESCE(cost, 0)) as value FROM inventory_movements WHERE type IN ('PURCHASE', 'INITIAL_STOCK')";
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    
    final result = await db.rawQuery(sql, args);
    return (result.first['value'] as num?)?.toDouble() ?? 0.0;
  }

  /// Delete all movements (for testing/reset)
  Future<void> clearAll() async {
    final db = await _dbHelper.database;
    await db.delete('inventory_movements');
  }

  /// Delete movements for a specific item
  Future<void> deleteMovementsByItem(String itemId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'inventory_movements',
      where: 'itemId = ?',
      whereArgs: [itemId],
    );
  }
  /// Rebuild the entire quantity cache for a store from the movements ledger
  Future<void> rebuildQuantityCache(String storeId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Clear existing cache for this store
      await txn.delete(
        'cache_inventory_quantities',
        where: 'storeId = ?',
        whereArgs: [storeId],
      );

      // 2. Calculate aggregates from movements
      final result = await txn.rawQuery('''
        SELECT itemId, SUM(delta) as total
        FROM inventory_movements
        WHERE storeId = ?
        GROUP BY itemId
      ''', [storeId]);

      // 3. Batch insert into cache
      final batch = txn.batch();
      for (var row in result) {
        batch.insert('cache_inventory_quantities', {
          'itemId': row['itemId'],
          'storeId': storeId,
          'quantity': row['total'] ?? 0,
        });
      }
      await batch.commit(noResult: true);
    });
  }
}
