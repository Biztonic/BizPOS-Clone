import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:biztonic_pos/models/business_ledger.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';

class OrderRepository {
  final DatabaseHelper dbHelper;
  final InventoryMovementRepository movementRepo;

  OrderRepository({
    required this.dbHelper,
    required this.movementRepo,
  });

  // --- ORDERS ---
  
  Future<void> insertOrder(OrderModel order) async {
      final db = await dbHelper.database;
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
    return await dbHelper.count(
      'orders',
      where: 'storeId = ? AND date = ? AND isDeleted = 0',
      whereArgs: [storeId, dateStr],
    );
  }

  /// Optimized Monthly Order Count using SQL
  Future<int> getMonthlyOrderCount(String storeId, String yearMonth) async {
    return await dbHelper.count(
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
    final db = await dbHelper.database;
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
        await movementRepo.insertMovement(movement, txn: txn);
      }
    });
  }

  // --- BATCH ORDERS ---
  Future<void> batchInsertOrders(List<OrderModel> orders) async {
    if (orders.isEmpty) return;

    final db = await dbHelper.database;
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
    int retries = 3;
    while (retries > 0) {
      try {
        final db = await dbHelper.database;
        String sql = 'SELECT * FROM orders WHERE 1=1';
        List<dynamic> args = [];
        if (storeId != null) {
          sql += ' AND storeId = ?';
          args.add(storeId);
        }
        sql += ' ORDER BY date DESC';

        final orderRows = await db.rawQuery(sql, args);

        if (orderRows.isEmpty) return [];

        String itemSql = 'SELECT * FROM order_items';
        List<dynamic> itemArgs = [];
        if (storeId != null) {
          itemSql += ' WHERE orderId IN (SELECT id FROM orders WHERE storeId = ?)';
          itemArgs.add(storeId);
        }
        
        final itemRows = await db.rawQuery(itemSql, itemArgs);
        
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
           return [];
        }
      }
    }
    return [];
  }

  Future<OrderModel?> getOrder(String id) async {
    final db = await dbHelper.database;
    final orderRows = await db.query('orders', where: 'id = ?', whereArgs: [id]);
    if (orderRows.isEmpty) return null;
    
    final itemRows = await db.query('order_items', where: 'orderId = ?', whereArgs: [id]);
    final items = itemRows.map((r) => OrderItem.fromSql(r)).toList();
    
    return OrderModel.fromSql(orderRows.first, items);
  }

  Future<List<OrderModel>> getOrdersByCustomer(String storeId, String customerId) async {
    try {
      final db = await dbHelper.database;
      final orderRows = await db.rawQuery(
        "SELECT * FROM orders WHERE storeId = ? AND (customerRefId = ? OR customerId = ?) AND (deletedAt IS NULL OR status = 'Cancelled') ORDER BY date DESC", 
        [storeId, customerId, customerId]
      );

      if (orderRows.isEmpty) return [];

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

  Future<List<OrderModel>> getPaginatedOrders(String? storeId, {int limit = 20, DateTime? lastDate}) async {
    try {
      final db = await dbHelper.database;
      String sql = "SELECT * FROM orders WHERE (deletedAt IS NULL OR status = 'Cancelled')";
      List<dynamic> args = [];
      
      if (storeId != null) {
        sql += ' AND storeId = ?';
        args.add(storeId);
      }

      if (lastDate != null) {
         sql += ' AND date < ?';
         args.add(lastDate.toIso8601String());
      }

      sql += ' ORDER BY date DESC LIMIT ?';
      args.add(limit);

      final orderRows = await db.rawQuery(sql, args);
      if (orderRows.isEmpty) return [];

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

  Future<List<OrderModel>> getUnsyncedOrders(String? storeId) async {
    try {
      final db = await dbHelper.database;
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

  Future<Map<String, dynamic>> getSalesStats(String storeId, {DateTime? start, DateTime? end, String? status, String? paymentMethod}) async {
    final db = await dbHelper.database;
    
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
    final db = await dbHelper.database;
    final start = DateTime.now().subtract(Duration(days: days));
    
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
    final db = await dbHelper.database;
    await db.update('orders', {'synced': 1}, where: 'id = ?', whereArgs: [orderId]);
  }
}
