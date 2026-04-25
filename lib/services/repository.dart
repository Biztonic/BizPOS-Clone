import 'dart:convert';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/models/inventory_item.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:biztonic_pos/models/customer.dart';
import 'package:biztonic_pos/models/business_ledger.dart';
import 'package:biztonic_pos/models/user_profile.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';
import 'package:sqflite/sqflite.dart';

class Repository {
  final _dbHelper = DatabaseHelper();
  final _movementRepo = InventoryMovementRepository();

  // --- ORDERS ---
  
  Future<void> insertOrder(OrderModel order) async {
      final db = await _dbHelper.database;
      try {
        // 1. Immutability Check (Security Risk 1)
        final existingRows = await db.query('orders', where: 'id = ?', whereArgs: [order.id]);
        if (existingRows.isNotEmpty) {
           final existingStatus = existingRows.first['status'] as String;
           final bool isIncomingSync = order.syncStatus == 'SYNCED' || order.syncStatus == 'CONFIRMED';

           if (['Completed', 'Cancelled', 'Refunded', 'VOID'].contains(existingStatus) && !isIncomingSync) {
              return; 
           }
        }

        await db.insert(
          'orders', 
          order.toSqlMap(), 
          conflictAlgorithm: ConflictAlgorithm.replace
        );
        
        // 2. Insert Items (Sequential for Web Stability)
        for (var item in order.items) {
          await db.insert(
            'order_items', 
            item.toSqlMap(order.id),
            conflictAlgorithm: ConflictAlgorithm.replace
          );
        }
      } catch (e) {
          rethrow;
      }
  }

  /// Optimized Daily Order Count using SQL
  Future<int> getDailyOrderCount(String storeId, String dateStr) async {
    return await _dbHelper.count(
      'orders',
      where: 'storeId = ? AND date = ? AND isDeleted = 0',
      whereArgs: [storeId, dateStr],
    );
  }

  /// Optimized Monthly Order Count using SQL
  Future<int> getMonthlyOrderCount(String storeId, String yearMonth) async {
    return await _dbHelper.count(
      'orders',
      where: 'storeId = ? AND date LIKE ? AND isDeleted = 0',
      whereArgs: [storeId, '$yearMonth-%'],
    );
  }

  Future<void> performAtomicCheckout({
    required OrderModel order,
    required List<InventoryMovement> movements,
    required BusinessEvent event,
    required String storeId,
    required String yearMonth,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Insert Order
      await txn.insert(
        'orders',
        order.toSqlMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Insert Order Items
      for (var item in order.items) {
        await txn.insert(
          'order_items',
          item.toSqlMap(order.id),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 3. Insert Business Event
      await txn.insert(
        'business_events',
        event.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 4. Update Token Counter
      final counterResults = await txn.query(
        'monthly_order_counter',
        where: 'storeId = ? AND yearMonth = ?',
        whereArgs: [storeId, yearMonth],
      );

      if (counterResults.isEmpty) {
        await txn.insert('monthly_order_counter', {
          'storeId': storeId,
          'yearMonth': yearMonth,
          'count': 1,
        });
      } else {
        int currentCount = counterResults.first['count'] as int;
        await txn.update(
          'monthly_order_counter',
          {'count': currentCount + 1},
          where: 'storeId = ? AND yearMonth = ?',
          whereArgs: [storeId, yearMonth],
        );
      }

      // 5. Insert Inventory Movements (Centralized logic updates cache)
      for (var movement in movements) {
        await _movementRepo.insertMovement(movement, txn: txn);
      }
    });
  }

  // --- BATCH ORDERS ---
  Future<void> batchInsertOrders(List<OrderModel> orders) async {
    if (orders.isEmpty) return;

    final db = await _dbHelper.database;
    final batch = db.batch();

    for (var order in orders) {
      batch.insert(
        'orders',
        order.toSqlMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (var item in order.items) {
        batch.insert(
          'order_items',
          item.toSqlMap(order.id),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<List<OrderModel>> getOrders(String? storeId) async {
    // RETRY LOGIC FOR LOCKS
    int retries = 3;
    while (retries > 0) {
      try {
        final db = await _dbHelper.database;
        // 1. Fetch ALL Orders (Include VOID for audit)
        String sql = 'SELECT * FROM orders WHERE 1=1';
        List<dynamic> args = [];
        if (storeId != null) {
          sql += ' AND storeId = ?';
          args.add(storeId);
        }
        sql += ' ORDER BY date DESC';

        final orderRows = await db.rawQuery(sql, args);

        if (orderRows.isEmpty) return [];

        // 2. Fetch ALL Items for these orders (Optimization: Single Query)
        // We use a safe approach: Fetch all items for this store creates a large result set, 
        // but it's faster than 1000 small queries.
        // Better: Fetch items where orderId IN (ids).. but limits apply. 
        // For now, fetching all items for the store is safe assuming order_items cleaned up.
        // Or better: Let's fetch all items for this store.
        
        String itemSql = 'SELECT * FROM order_items';
        List<dynamic> itemArgs = [];
        if (storeId != null) {
          itemSql += ' WHERE orderId IN (SELECT id FROM orders WHERE storeId = ?)';
          itemArgs.add(storeId);
        }
        
        final itemRows = await db.rawQuery(itemSql, itemArgs);
        
        // 3. Map Items to Orders (In-Memory)
        Map<String, List<OrderItem>> itemsMap = {};
        for (var row in itemRows) {
           final item = OrderItem.fromSql(row);
           if (item.orderId != null) {
               if (!itemsMap.containsKey(item.orderId!)) {
                  itemsMap[item.orderId!] = [];
               }
               itemsMap[item.orderId!]!.add(item);
           }
        }

        List<OrderModel> orders = [];
        for (var row in orderRows) {
           String orderId = row['id'] as String;
           List<OrderItem> items = itemsMap[orderId] ?? [];
           orders.add(OrderModel.fromSql(row, items));
        }
        
        return orders;
      } catch (e) {

        if (e.toString().contains('locked') && retries > 1) {

           await Future.delayed(const Duration(milliseconds: 200));
           retries--;
        } else {

           return []; // Return empty only on fatal
        }
      }
    }
    return [];
  }

  Future<OrderModel?> getOrder(String id) async {
    final db = await _dbHelper.database;
    final orderRows = await db.query('orders', where: 'id = ?', whereArgs: [id]);
    if (orderRows.isEmpty) return null;
    
    final itemRows = await db.query('order_items', where: 'orderId = ?', whereArgs: [id]);
    final items = itemRows.map((r) => OrderItem.fromSql(r)).toList();
    
    return OrderModel.fromSql(orderRows.first, items);
  }

  Future<List<OrderModel>> getOrdersByCustomer(String storeId, String customerId) async {
    try {
      final db = await _dbHelper.database;
      // Fetch orders for this customer (Sorted by Date DESC)
      final orderRows = await db.rawQuery(
        "SELECT * FROM orders WHERE storeId = ? AND (customerRefId = ? OR customerId = ?) AND (deletedAt IS NULL OR status = 'Cancelled') ORDER BY date DESC", 
        [storeId, customerId, customerId]
      );

      if (orderRows.isEmpty) return [];

      // Fetch items for these orders
      final orderIds = orderRows.map((r) => r['id'] as String).toList();
      final placeholders = List.filled(orderIds.length, '?').join(',');

      final itemRows = await db.rawQuery(
          'SELECT * FROM order_items WHERE orderId IN ($placeholders)',
          orderIds
      );

      Map<String, List<OrderItem>> itemsMap = {};
      for (var row in itemRows) {
         final item = OrderItem.fromSql(row);
         if (item.orderId != null) {
             itemsMap.putIfAbsent(item.orderId!, () => []).add(item);
         }
      }

      List<OrderModel> orders = [];
      for (var row in orderRows) {
         String orderId = row['id'] as String;
         List<OrderItem> items = itemsMap[orderId] ?? [];
         orders.add(OrderModel.fromSql(row, items));
      }
      return orders;
    } catch (e) {

      return [];
    }
  }

  // --- PAGINATED ORDERS (SCALABLE READS) ---
  Future<List<OrderModel>> getPaginatedOrders(String? storeId, {int limit = 20, DateTime? lastDate}) async {
    try {
      final db = await _dbHelper.database;
      String sql = "SELECT * FROM orders WHERE (deletedAt IS NULL OR status = 'Cancelled')";
      List<dynamic> args = [];
      
      if (storeId != null) {
        sql += ' AND storeId = ?';
        args.add(storeId);
      }

      // O(1) Keyset Pagination
      if (lastDate != null) {
         sql += ' AND date < ?';
         args.add(lastDate.toIso8601String());
      }

      sql += ' ORDER BY date DESC LIMIT ?';
      args.add(limit);

      final orderRows = await db.rawQuery(sql, args);
      if (orderRows.isEmpty) return [];

      // EFFICIENT ITEM FETCH: Only fetch items for the IDs we just got
      // This is much faster than fetching "all items for store"
      final orderIds = orderRows.map((r) => r['id'] as String).toList();
      final placeholders = List.filled(orderIds.length, '?').join(',');
      
      final itemRows = await db.rawQuery(
          'SELECT * FROM order_items WHERE orderId IN ($placeholders)',
          orderIds
      );

      // Map Items
      Map<String, List<OrderItem>> itemsMap = {};
      for (var row in itemRows) {
         final item = OrderItem.fromSql(row);
         if (item.orderId != null) {
             itemsMap.putIfAbsent(item.orderId!, () => []).add(item);
         }
      }

      // Assemble
      List<OrderModel> orders = [];
      for (var row in orderRows) {
         String orderId = row['id'] as String;
         List<OrderItem> items = itemsMap[orderId] ?? [];
         orders.add(OrderModel.fromSql(row, items));
      }
      return orders;

    } catch (e) {

      return [];
    }
  }

  Future<List<OrderModel>> getUnsyncedOrders(String? storeId) async {
    try {
      final db = await _dbHelper.database;
      String sql = "SELECT * FROM orders WHERE synced = 0 AND (deletedAt IS NULL OR status = 'Cancelled')";
      List<dynamic> args = [];
      if (storeId != null) {
        sql += ' AND storeId = ?';
        args.add(storeId);
      }
      final rows = await db.rawQuery(sql, args);
      
      List<OrderModel> orders = [];
      for (var row in rows) {
        String orderId = row['id'] as String;
        final itemRows = await db.rawQuery('SELECT * FROM order_items WHERE orderId = ?', [orderId]);
        List<OrderItem> items = itemRows.map((r) => OrderItem.fromSql(r)).toList();
        orders.add(OrderModel.fromSql(row, items));
      }
      return orders;
    } catch (e) {

      return [];
    }
  }

  // --- REPORTING AGGREGATIONS (SQL) ---
  Future<Map<String, dynamic>> getSalesStats(String storeId, {DateTime? start, DateTime? end, String? status, String? paymentMethod}) async {
    final db = await _dbHelper.database;
    
    String filter = ' WHERE o.storeId = ? AND o.deletedAt IS NULL';
    List<dynamic> args = [storeId];

    if (start != null) {
      filter += ' AND o.date >= ?';
      args.add(start.toIso8601String());
    }
    if (end != null) {
      filter += ' AND o.date <= ?';
      args.add(end.toIso8601String());
    }
    if (status != null) {
      filter += ' AND o.status = ?';
      args.add(status);
    } else {
      filter += " AND o.status NOT IN ('Cancelled', 'VOID')";
    }

    if (paymentMethod != null) {
       filter += ' AND o.paymentMethod = ?';
       args.add(paymentMethod);
    }

    final orderStats = await db.rawQuery('''
      SELECT 
        COUNT(CASE WHEN status = 'Refunded' THEN NULL ELSE 1 END) as count, 
        SUM(CASE WHEN status = 'Refunded' THEN 0 ELSE total END) as totalSales,
        SUM(CASE WHEN paymentMethod IN ('Card', 'UPI') THEN (CASE WHEN status = 'Refunded' THEN 0 ELSE total END) ELSE 0 END) as cardSales,
        SUM(CASE WHEN paymentMethod = 'Cash' THEN (CASE WHEN status = 'Refunded' THEN 0 ELSE total END) ELSE 0 END) as cashSales
      FROM orders o
      $filter
    ''', args);

    // 2. Aggregate COGS from Order Items
    final itemStats = await db.rawQuery('''
      SELECT SUM(CASE WHEN o.status = 'Refunded' THEN 0 ELSE (oi.cost * oi.quantity) END) as totalCogs
      FROM order_items oi
      JOIN orders o ON oi.orderId = o.id
      $filter
    ''', args);

    double total = (orderStats.first['totalSales'] as num? ?? 0).toDouble();
    int count = (orderStats.first['count'] as num? ?? 0).toInt();
    double card = (orderStats.first['cardSales'] as num? ?? 0).toDouble();
    double cash = (orderStats.first['cashSales'] as num? ?? 0).toDouble();
    double cogs = (itemStats.first['totalCogs'] as num? ?? 0).toDouble();
    double avg = count > 0 ? total / count : 0.0;

    return {
      'totalSales': total,
      'orderCount': count,
      'avgOrderValue': avg,
      'cardSales': card,
      'cashSales': cash,
      'totalCogs': cogs,
      'grossProfit': total - cogs,
    };
  }

  Future<List<Map<String, dynamic>>> getSalesByDay(String storeId, int days) async {
    final db = await _dbHelper.database;
    final start = DateTime.now().subtract(Duration(days: days));
    
    // Group by Day (SQLite strftime)
    // Adjust format based on requirement, assumng YYYY-MM-DD
    final result = await db.rawQuery('''
      SELECT strftime('%Y-%m-%d', date) as day, SUM(CASE WHEN status = 'Refunded' THEN 0 ELSE total END) as dailyTotal 
      FROM orders 
      WHERE storeId = ? AND date >= ? AND status NOT IN ('Cancelled', 'VOID') AND deletedAt IS NULL
      GROUP BY day 
      ORDER BY day ASC
    ''', [storeId, start.toIso8601String()]);
    
    return result;
  }

  Future<void> markOrderAsSynced(String orderId) async {
    final db = await _dbHelper.database;
    await db.update('orders', {'synced': 1}, where: 'id = ?', whereArgs: [orderId]);
  }
  
  // --- INVENTORY ---

  Future<void> insertInventory(InventoryItem item) async {
       final db = await _dbHelper.database;
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

  /// Get total delta for pending (unsynced) inventory movements for an item
  Future<int> getPendingInventoryDelta(String itemId, {String? storeId}) async {
    return await _movementRepo.getPendingDelta(itemId, storeId: storeId);
  }

  /// Manually update the quantity cache for an item (used during sync reconciliation)
  Future<void> updateInventoryCache(String itemId, int quantity, String storeId) async {
    final db = await _dbHelper.database;
    await db.insert(
      'cache_inventory_quantities',
      {'itemId': itemId, 'quantity': quantity, 'storeId': storeId},
      conflictAlgorithm: ConflictAlgorithm.replace
    );
  }

  Future<void> insertMovement(InventoryMovement movement, {Transaction? txn}) async {
      await _movementRepo.insertMovement(movement, txn: txn);
  }

  /// Rebuild the inventory quantity cache for a specific store
  Future<void> rebuildQuantityCache(String storeId) async {
    await _movementRepo.rebuildQuantityCache(storeId);
  }

  // --- BATCH INVENTORY ---
  Future<void> batchInsertInventory(List<InventoryItem> items) async {
    if (items.isEmpty) return;

    final db = await _dbHelper.database;
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
    final db = await _dbHelper.database;
    
    // Using rawQuery
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
    
    // Compute quantities from movements (event sourcing)
    final quantities = await _movementRepo.getAllQuantities(storeId);
    
    // Update items with computed quantities
    for (int i = 0; i < items.length; i++) {
      items[i] = items[i].copyWith(quantity: quantities[items[i].id] ?? 0);
    }
    
    return items;
  }

  Future<InventoryItem?> getInventoryItem(String id, {String? storeId}) async {
    final db = await _dbHelper.database;
    final rows = await db.query('inventory', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    
    final item = InventoryItem.fromSql(rows.first);
    // Add movement-based quantity (Pass storeId to filter if desired)
    final quantity = await _movementRepo.getItemQuantity(id, storeId: storeId);
    return item.copyWith(quantity: quantity);
  }

  // DEBUG: Get ALL items (no filter)
  Future<List<InventoryItem>> getAllInventoryDebug() async {

    final db = await _dbHelper.database;
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

  // --- CUSTOMERS ---

  Future<void> insertCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    try {
      await db.insert(
        'customers',
        customer.toSqlMap(),
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    } catch (e) {

      rethrow;
    }
  }

  // --- BATCH CUSTOMERS ---
  Future<void> batchInsertCustomers(List<Customer> customers) async {
    if (customers.isEmpty) return;

    final db = await _dbHelper.database;
    final batch = db.batch();

    for (var customer in customers) {
      batch.insert(
        'customers',
        customer.toSqlMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Customer>> getCustomers(String? storeId) async {
    final db = await _dbHelper.database;
    String sql = 'SELECT * FROM customers WHERE deletedAt IS NULL';
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    final rows = await db.rawQuery(sql, args);
    return rows.map((r) => Customer.fromSql(r)).toList();
  }

  Future<Customer?> getCustomer(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Customer.fromSql(rows.first);
  }

  // --- COUNTS ---
  Future<int> getOrderCount(String? storeId) async {
    final db = await _dbHelper.database;
    String sql = "SELECT COUNT(*) FROM orders WHERE (deletedAt IS NULL AND status NOT IN ('Cancelled', 'VOID', 'Refunded'))";
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    final int count = Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
    return count;
  }
  
  // New for Subscription Limits
  Future<int> getOrderCountSince(String? storeId, DateTime since) async {
    final db = await _dbHelper.database;
    String sql = "SELECT COUNT(*) FROM orders WHERE date >= ? AND (deletedAt IS NULL AND status NOT IN ('Cancelled', 'VOID', 'Refunded'))";
    List<dynamic> args = [since.toIso8601String()];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.insert(0, storeId); // Add storeId at the beginning of args
    }
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }

  Future<int> getInventoryCount(String? storeId) async {
    final db = await _dbHelper.database;
    String sql = 'SELECT COUNT(*) FROM inventory WHERE deletedAt IS NULL';
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }

  Future<int> getCustomerCount(String? storeId) async {
    final db = await _dbHelper.database;
    String sql = 'SELECT COUNT(*) FROM customers WHERE deletedAt IS NULL';
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }

  Future<int> getEmployeeCount(String? storeId) async {
    final db = await _dbHelper.database;
    String sql = 'SELECT COUNT(*) FROM employees WHERE deletedAt IS NULL';
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }

  Future<int> getFloorCount(String? storeId) async {
    final db = await _dbHelper.database;
    String sql = 'SELECT COUNT(*) FROM floors WHERE deletedAt IS NULL';
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }

  Future<int> getTableCount(String? storeId) async {
    final db = await _dbHelper.database;
    String sql = 'SELECT COUNT(*) FROM tables WHERE deletedAt IS NULL';
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }

  Future<int> getSupplierCount(String? storeId) async {
    final db = await _dbHelper.database;
    String sql = 'SELECT COUNT(*) FROM suppliers WHERE deletedAt IS NULL';
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }

  Future<int> getNoteCount(String? storeId) async {
    final db = await _dbHelper.database;
    String sql = 'SELECT COUNT(*) FROM notes WHERE deletedAt IS NULL';
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }

  // --- DELETE (SOFT DELETE) ---
  /// VOIDs an order instead of deleting it to preserve audit trail.
  Future<void> voidOrder(String id, {String? voidedBy, String? reason}) async {
    final db = await _dbHelper.database;
    await db.update('orders', 
      {
        'status': 'VOID', 
        'syncStatus': 'PENDING', 
        'updatedAt': DateTime.now().toIso8601String(),
        'voidedAt': DateTime.now().toIso8601String(),
        'voidedBy': voidedBy,
        'voidReason': reason,
      }, 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }

  Future<void> deleteInventory(String id) async {
    final db = await _dbHelper.database;
     await db.update('inventory', 
      {'deletedAt': DateTime.now().toIso8601String(), 'isDeleted': 1, 'syncStatus': 'PENDING', 'updatedAt': DateTime.now().toIso8601String()}, 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }

  Future<void> deleteCustomer(String id) async {
    final db = await _dbHelper.database;
     await db.update('customers', 
      {'deletedAt': DateTime.now().toIso8601String(), 'isDeleted': 1, 'syncStatus': 'PENDING', 'updatedAt': DateTime.now().toIso8601String()}, 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }

  Future<void> deleteOrder(String id) async {
    final db = await _dbHelper.database;
    await db.update('orders', 
      {'status': 'DELETED', 'isDeleted': 1, 'syncStatus': 'PENDING', 'updatedAt': DateTime.now().toIso8601String()}, 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }

  Future<void> deleteEmployee(String id) async {
    final db = await _dbHelper.database;
    await db.update('employees', 
      {'deletedAt': DateTime.now().toIso8601String(), 'isDeleted': 1, 'syncStatus': 'PENDING', 'updatedAt': DateTime.now().toIso8601String()}, 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }

  // --- SYNC STATE MACHINE ---
  
  /// Marks an item as PUSHED (uploaded to cloud but not yet confirmed by pull)
  Future<void> markAsPushed(String table, String id) async {
    final db = await _dbHelper.database;
    final idCol = table == 'store_settings' ? 'storeId' : 'id';
    await db.update(table, {
      'syncStatus': 'PUSHED',
      'updatedAt': DateTime.now().toIso8601String(),
    }, where: '$idCol = ?', whereArgs: [id]);
  }

  /// Marks an item as CONFIRMED (verified to exist in cloud via pull query)
  Future<void> markAsConfirmed(String table, String id) async {
    final db = await _dbHelper.database;
    final idCol = table == 'store_settings' ? 'storeId' : 'id';
    await db.update(table, {
      'syncStatus': 'CONFIRMED',
      'lastSyncedAt': DateTime.now().toIso8601String(),
    }, where: '$idCol = ?', whereArgs: [id]);
  }

  /// Legacy: marks as SYNCED (equivalent to CONFIRMED for backwards compatibility)
  Future<void> markAsSynced(String table, String id) async {
     final db = await _dbHelper.database;
     final idCol = table == 'store_settings' ? 'storeId' : 'id';
     await db.update(table, {
       'syncStatus': 'CONFIRMED', 
       'lastSyncedAt': DateTime.now().toIso8601String(),
       'synced': 1 // Legacy support
     }, where: '$idCol = ?', whereArgs: [id]);
  }

  // --- BUSINESS LEDGER ---
  
  Future<void> insertBusinessEvent(BusinessEvent event) async {
    final db = await _dbHelper.database;
    await db.insert(
      'business_events', 
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace
    );
  }

  Future<List<BusinessEvent>> getUnsyncedEvents(String? storeId) async {
    final db = await _dbHelper.database;
    String sql = 'SELECT * FROM business_events WHERE synced = 0';
    List<dynamic> args = [];
    
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    
    final rows = await db.rawQuery(sql, args);
    return rows.map((r) => BusinessEvent.fromMap(r)).toList();
  }

  Future<void> markEventAsSynced(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'business_events', 
      {'synced': 1, 'syncedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id]
    );
  }

  Future<List<BusinessEvent>> getBusinessEvents(String storeId, {int limit = 50}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'business_events',
      where: 'storeId = ?',
      whereArgs: [storeId],
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return rows.map((r) => BusinessEvent.fromMap(r)).toList();
  }

  // --- MAINTENANCE ---
  Future<void> resetLocalDatabase() async {
    await _dbHelper.nukeDatabase();
  }

  // --- MIGRATED OFFLINE CONFIG ENTITIES (JSON BLOBS) ---
  
  // Settings
  Future<void> insertStoreSettings(String storeId, Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    await db.insert('store_settings', {
      'storeId': storeId,
      'data': jsonEncode(data),
      'syncStatus': 'CONFIRMED',
      'updatedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getStoreSettings(String storeId) async {
    final db = await _dbHelper.database;
    final rows = await db.query('store_settings', where: 'storeId = ? AND deletedAt IS NULL', whereArgs: [storeId]);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
  }

  // Floors
  Future<void> insertFloor(String id, String storeId, Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    await db.insert('floors', {
      'id': id,
      'storeId': storeId,
      'data': jsonEncode(data),
      'syncStatus': 'CONFIRMED',
      'updatedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Tables
  Future<void> insertTable(String id, String storeId, Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    await db.insert('tables', {
      'id': id,
      'storeId': storeId,
      'data': jsonEncode(data),
      'syncStatus': 'CONFIRMED',
      'updatedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Suppliers
  Future<void> insertSupplier(String id, String storeId, Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    await db.insert('suppliers', {
      'id': id,
      'storeId': storeId,
      'data': jsonEncode(data),
      'syncStatus': 'CONFIRMED',
      'updatedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Notes
  Future<void> insertNote(String id, String storeId, Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    await db.insert('notes', {
      'id': id,
      'storeId': storeId,
      'data': jsonEncode(data),
      'syncStatus': 'CONFIRMED',
      'updatedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Employees (Special Case: Not a blob)
  Future<void> insertEmployee(UserProfile emp) async {
    final db = await _dbHelper.database;
    await db.insert('employees', {
      'id': emp.uid,
      'storeId': emp.storeId,
      'name': emp.name,
      'email': emp.email,
      'role': emp.role,
      'employeeId': emp.employeeId,
      'pin': emp.pinHash, // SQLite uses 'pin' column
      'createdAt': emp.createdAt?.toIso8601String(),
      'syncStatus': 'CONFIRMED',
      'updatedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Generic Deletion for config entities from SQLite
  Future<void> deleteOfflineEntity(String table, String id) async {
    final db = await _dbHelper.database;
    // For store_settings, id is storeId
    final idColumn = table == 'store_settings' ? 'storeId' : 'id';
    await db.update(table, 
      {'deletedAt': DateTime.now().toIso8601String(), 'isDeleted': 1, 'syncStatus': 'PENDING', 'updatedAt': DateTime.now().toIso8601String()}, 
      where: '$idColumn = ?', 
      whereArgs: [id]
    );
  }

  /// Safe Reconciliation: Only physically delete items that are CONFIRMED and explicitly soft-deleted.
  /// Items that are PENDING, PUSHED, or not explicitly deleted are NEVER removed.
  Future<int> deleteOrphans(String table, String storeId, List<String> currentCloudIds) async {
    final db = await _dbHelper.database;
    final idCol = table == 'store_settings' ? 'storeId' : 'id';

    if (currentCloudIds.isEmpty) {
       // Cloud is empty for this store → only delete items that were CONFIRMED and explicitly soft-deleted
       return await db.delete(
         table,
         where: 'storeId = ? AND syncStatus = ? AND isDeleted = 1',
         whereArgs: [storeId, 'CONFIRMED'],
       );
    }
    
    // Only delete items that:
    // 1. Belong to this store
    // 2. Are NOT in the cloud result set
    // 3. Were previously CONFIRMED (verified to have existed in cloud)
    // 4. Are explicitly marked as soft-deleted
    //
    // Items with syncStatus PENDING or PUSHED are NEVER touched (they haven't round-tripped yet)
    final placeholders = List.filled(currentCloudIds.length, '?').join(',');
    final deletedCount = await db.delete(
      table, 
      where: 'storeId = ? AND $idCol NOT IN ($placeholders) AND syncStatus = ? AND isDeleted = 1', 
      whereArgs: [storeId, ...currentCloudIds, 'CONFIRMED']
    );
    
    if (deletedCount > 0) {
      debugPrint('🛡️ Repository: Cleaned up $deletedCount orphan records in $table for store $storeId');
    }
    return deletedCount;
  }

  /// Gets items that need pushing (PENDING or PUSHED status)
  Future<List<Map<String, dynamic>>> getUnsyncedRows(String table) async {
    final db = await _dbHelper.database;
    return await db.query(table, where: "syncStatus IN ('PENDING', 'PUSHED') OR syncStatus IS NULL");
  }
}
