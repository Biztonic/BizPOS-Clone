import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:biztonic_pos/models/business_ledger.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';
import 'package:biztonic_pos/features/inventory/domain/policies/inventory_policy.dart';
import 'package:biztonic_pos/services/recovery_service.dart';
import 'package:biztonic_pos/sync/outbox/outbox_operation.dart';
import 'dart:convert';

mixin OrderRepositoryMixin {
  Future<Database> get database;
  DatabaseHelper get dbHelper;
  InventoryMovementRepository get movementRepo;

  // --- ORDERS ---

  Future<void> insertOrder(OrderModel order) async {
    final db = await dbHelper.database;
    try {
      // 1. Immutability Check (Security Risk 1)
      final existingRows =
          await db.query('orders', where: 'id = ?', whereArgs: [order.id]);
      if (existingRows.isNotEmpty) {
        final existingStatus = existingRows.first['status'] as String;
        final bool isIncomingSync =
            order.syncStatus == 'SYNCED' || order.syncStatus == 'CONFIRMED';

        if (['Completed', 'Cancelled', 'Refunded', 'VOID']
                .contains(existingStatus) &&
            !isIncomingSync) {
          return;
        }
      }

      await db.insert('orders', order.toSqlMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

      // 2. Insert Items (Sequential for Web Stability)
      for (var item in order.items) {
        await db.insert('order_items', item.toSqlMap(order.id),
            conflictAlgorithm: ConflictAlgorithm.replace);
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
    List<OutboxOperation>? outboxOperations,
    NegativeStockPolicy? negativeStockPolicy,
  }) async {
    final db = await dbHelper.database;
    final txId = 'TX-${DateTime.now().millisecondsSinceEpoch}-${order.id}';

    // Build default outbox operation for order if not supplied
    final effectiveOutboxOps = outboxOperations ??
        [
          OutboxOperation(
            operationId: 'op_order_${order.id}',
            storeId: storeId,
            userId: 'system',
            deviceId: order.deviceId ?? 'device-pos',
            collection: 'orders',
            entityId: order.id,
            operation: 'CREATE',
            payload: order.toHiveMap(),
          )
        ];

    final payload = jsonEncode({
      'order': order.toSqlMap(),
      'orderItems': order.items.map((e) => e.toSqlMap(order.id)).toList(),
      'event': event.toSqlMap(),
      'movements': movements.map((e) => e.toSqlMap()).toList(),
      'outboxOperations': effectiveOutboxOps.map((e) => e.toSqlRow()).toList(),
      'yearMonth': yearMonth,
    });

    // 0. Create Journal Entry (Pending) OUTSIDE transaction
    await db.insert('transaction_journal', {
      'id': txId,
      'storeId': storeId,
      'status': 'PENDING',
      'operations': payload,
      'createdAt': DateTime.now().toIso8601String(),
    });

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
        event.toSqlMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 4. Update Token Counter (Atomic Upsert)
      await txn.rawInsert('''
        INSERT INTO monthly_order_counter (storeId, yearMonth, count)
        VALUES (?, ?, 1)
        ON CONFLICT(storeId, yearMonth) DO UPDATE SET count = count + 1
      ''', [storeId, yearMonth]);

      // 5. Insert Inventory Movements (Centralized logic updates cache)
      for (var movement in movements) {
        await movementRepo.insertMovement(movement,
            txn: txn, negativeStockPolicy: negativeStockPolicy);
      }

      // 6. Insert Outbox Operations Atomically (Guarantees sync queue durability)
      for (var op in effectiveOutboxOps) {
        await txn.insert(
          'outbox_operations',
          op.toSqlRow(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 7. Mark Journal Complete
      await txn.update(
        'transaction_journal',
        {
          'status': 'COMPLETED',
          'completedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [txId],
      );
    });
  }

  Future<void> replayTransaction(String txId, String operationsJson) async {
    final recoveryService = RecoveryService(
      dbHelper: dbHelper,
      movementRepo: movementRepo,
    );
    await recoveryService.reconcileTransaction(txId, autoReconcile: true);
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
    if (storeId == null || storeId.isEmpty) return [];
    // RETRY LOGIC FOR LOCKS
    int retries = 3;
    while (retries > 0) {
      try {
        final db = await dbHelper.database;
        // 1. Fetch ALL Orders (Include VOID for audit)
        String sql = 'SELECT * FROM orders WHERE storeId = ?';
        List<dynamic> args = [storeId];
        sql += ' ORDER BY date DESC';

        final orderRows = await db.rawQuery(sql, args);

        if (orderRows.isEmpty) return [];

        // 2. Fetch ALL Items for these orders (Optimization: Single Query)
        String itemSql =
            'SELECT * FROM order_items WHERE orderId IN (SELECT id FROM orders WHERE storeId = ?)';
        List<dynamic> itemArgs = [storeId];

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
    final db = await dbHelper.database;
    final orderRows =
        await db.query('orders', where: 'id = ?', whereArgs: [id]);
    if (orderRows.isEmpty) return null;

    final itemRows =
        await db.query('order_items', where: 'orderId = ?', whereArgs: [id]);
    final items = itemRows.map((r) => OrderItem.fromSql(r)).toList();

    return OrderModel.fromSql(orderRows.first, items);
  }

  Future<List<OrderModel>> getOrdersByCustomer(
      String storeId, String customerId) async {
    try {
      final db = await dbHelper.database;
      // Fetch orders for this customer (Sorted by Date DESC)
      final orderRows = await db.rawQuery(
          "SELECT * FROM orders WHERE storeId = ? AND (customerRefId = ? OR customerId = ?) AND (deletedAt IS NULL OR status = 'Cancelled') ORDER BY date DESC",
          [storeId, customerId, customerId]);

      if (orderRows.isEmpty) return [];

      // Fetch items for these orders
      final orderIds = orderRows.map((r) => r['id'] as String).toList();
      final placeholders = List.filled(orderIds.length, '?').join(',');

      final itemRows = await db.rawQuery(
          'SELECT * FROM order_items WHERE orderId IN ($placeholders)',
          orderIds);

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

  // --- PAGINATED ORDERS (SCALABLE KEYSET READS) ---
  Future<List<OrderModel>> getPaginatedOrders(String? storeId,
      {int limit = 20,
      DateTime? lastDate,
      String? lastId,
      DateTime? start,
      DateTime? end,
      String? status,
      String? paymentMethod}) async {
    if (storeId == null || storeId.isEmpty) return [];
    try {
      final db = await dbHelper.database;
      String sql =
          "SELECT * FROM orders WHERE isDeleted = 0 AND storeId = ? AND (deletedAt IS NULL OR status = 'Cancelled')";
      List<dynamic> args = [storeId];

      if (status != null &&
          status.isNotEmpty &&
          status != 'All' &&
          status != 'All Statuses') {
        sql += ' AND status = ?';
        args.add(status);
      }

      if (paymentMethod != null &&
          paymentMethod.isNotEmpty &&
          paymentMethod != 'All' &&
          paymentMethod != 'All Methods') {
        sql += ' AND paymentMethod = ?';
        args.add(paymentMethod);
      }

      if (start != null) {
        sql += ' AND date >= ?';
        args.add(start.toIso8601String());
      }

      if (end != null) {
        sql += ' AND date <= ?';
        args.add(end.add(const Duration(days: 1)).toIso8601String());
      }

      // True O(1) Keyset Pagination with deterministic tie-breaker
      if (lastDate != null && lastId != null) {
        sql += ' AND (date < ? OR (date = ? AND id < ?))';
        args.add(lastDate.toIso8601String());
        args.add(lastDate.toIso8601String());
        args.add(lastId);
      } else if (lastDate != null) {
        sql += ' AND date < ?';
        args.add(lastDate.toIso8601String());
      }

      sql += ' ORDER BY date DESC, id DESC LIMIT ?';
      args.add(limit);

      final orderRows = await db.rawQuery(sql, args);
      if (orderRows.isEmpty) return [];

      // EFFICIENT ITEM FETCH: Only fetch items for the IDs we just got
      final orderIds = orderRows.map((r) => r['id'] as String).toList();
      final placeholders = List.filled(orderIds.length, '?').join(',');

      final itemRows = await db.rawQuery(
          'SELECT * FROM order_items WHERE orderId IN ($placeholders)',
          orderIds);

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
    if (storeId == null || storeId.isEmpty) return [];
    try {
      final db = await dbHelper.database;
      String sql =
          "SELECT * FROM orders WHERE synced = 0 AND storeId = ? AND (deletedAt IS NULL OR status = 'Cancelled') ORDER BY date DESC";
      final rows = await db.rawQuery(sql, [storeId]);
      if (rows.isEmpty) return [];

      final orderIds = rows.map((r) => r['id'] as String).toList();
      final placeholders = List.filled(orderIds.length, '?').join(',');
      final itemRows = await db.rawQuery(
          'SELECT * FROM order_items WHERE orderId IN ($placeholders)',
          orderIds);

      Map<String, List<OrderItem>> itemsMap = {};
      for (var row in itemRows) {
        final item = OrderItem.fromSql(row);
        if (item.orderId != null) {
          itemsMap.putIfAbsent(item.orderId!, () => []).add(item);
        }
      }

      return rows.map((r) {
        final String orderId = r['id'] as String;
        return OrderModel.fromSql(r, itemsMap[orderId] ?? []);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // --- REPORTING AGGREGATIONS (SQL) ---
  Future<Map<String, dynamic>> getSalesStats(String storeId,
      {DateTime? start,
      DateTime? end,
      String? status,
      String? paymentMethod}) async {
    final db = await dbHelper.database;

    String filter =
        ' WHERE o.storeId = ? AND o.deletedAt IS NULL AND (o.isDeleted = 0 OR o.isDeleted IS NULL)';
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
        SUM(CASE WHEN paymentMethod = 'Card' THEN (CASE WHEN status = 'Refunded' THEN 0 ELSE total END) ELSE 0 END) as cardSales,
        SUM(CASE WHEN paymentMethod = 'Cash' THEN (CASE WHEN status = 'Refunded' THEN 0 ELSE total END) ELSE 0 END) as cashSales,
        SUM(CASE WHEN paymentMethod = 'UPI' THEN (CASE WHEN status = 'Refunded' THEN 0 ELSE total END) ELSE 0 END) as upiSales,
        SUM(CASE WHEN paymentMethod NOT IN ('Card', 'Cash', 'UPI') THEN (CASE WHEN status = 'Refunded' THEN 0 ELSE total END) ELSE 0 END) as otherSales,
        SUM(CASE WHEN status = 'Completed' THEN total ELSE 0 END) as completedSales,
        SUM(CASE WHEN status = 'Refunded' THEN total ELSE 0 END) as refundedSales,
        SUM(CASE WHEN status = 'Cancelled' THEN total ELSE 0 END) as cancelledSales,
        COUNT(CASE WHEN status = 'Completed' THEN 1 ELSE NULL END) as completedCount,
        COUNT(CASE WHEN status = 'Refunded' THEN 1 ELSE NULL END) as refundedCount,
        COUNT(CASE WHEN status = 'Cancelled' THEN 1 ELSE NULL END) as cancelledCount
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

    final categoryRows = await db.rawQuery('''
      SELECT 
        oi.category, 
        SUM(CASE WHEN o.status = 'Refunded' THEN 0 ELSE (oi.price * oi.quantity) END) as sales,
        SUM(CASE WHEN o.status = 'Refunded' THEN 0 ELSE (oi.cost * oi.quantity) END) as cogs
      FROM order_items oi
      JOIN orders o ON oi.orderId = o.id
      $filter
      GROUP BY oi.category
    ''', args);

    final dayRows = await db.rawQuery('''
      SELECT 
        strftime('%Y-%m-%d', o.date) as day,
        SUM(CASE WHEN o.status = 'Refunded' THEN 0 ELSE (oi.price * oi.quantity) END) as sales,
        SUM(CASE WHEN o.status = 'Refunded' THEN 0 ELSE (oi.cost * oi.quantity) END) as cogs
      FROM order_items oi
      JOIN orders o ON oi.orderId = o.id
      $filter
      GROUP BY day
    ''', args);

    double total = (orderStats.first['totalSales'] as num? ?? 0).toDouble();
    int count = (orderStats.first['count'] as num? ?? 0).toInt();
    double card = (orderStats.first['cardSales'] as num? ?? 0).toDouble();
    double cash = (orderStats.first['cashSales'] as num? ?? 0).toDouble();
    double upi = (orderStats.first['upiSales'] as num? ?? 0).toDouble();
    double other = (orderStats.first['otherSales'] as num? ?? 0).toDouble();
    double completedSales =
        (orderStats.first['completedSales'] as num? ?? 0).toDouble();
    double refundedSales =
        (orderStats.first['refundedSales'] as num? ?? 0).toDouble();
    double cancelledSales =
        (orderStats.first['cancelledSales'] as num? ?? 0).toDouble();
    int completedCount =
        (orderStats.first['completedCount'] as num? ?? 0).toInt();
    int refundedCount =
        (orderStats.first['refundedCount'] as num? ?? 0).toInt();
    int cancelledCount =
        (orderStats.first['cancelledCount'] as num? ?? 0).toInt();

    double cogs = (itemStats.first['totalCogs'] as num? ?? 0).toDouble();
    double avg = count > 0 ? total / count : 0.0;

    final List<Map<String, dynamic>> categoryStats = categoryRows
        .map((row) => {
              'category': row['category'] ?? 'Uncategorized',
              'sales': (row['sales'] as num? ?? 0).toDouble(),
              'cogs': (row['cogs'] as num? ?? 0).toDouble(),
              'profit':
                  ((row['sales'] as num? ?? 0) - (row['cogs'] as num? ?? 0))
                      .toDouble(),
            })
        .toList();

    final List<Map<String, dynamic>> dayStats = dayRows
        .map((row) => {
              'day': row['day'] ?? '',
              'sales': (row['sales'] as num? ?? 0).toDouble(),
              'cogs': (row['cogs'] as num? ?? 0).toDouble(),
              'profit':
                  ((row['sales'] as num? ?? 0) - (row['cogs'] as num? ?? 0))
                      .toDouble(),
            })
        .toList();

    return {
      'totalSales': total,
      'orderCount': count,
      'avgOrderValue': avg,
      'cardSales': card,
      'cashSales': cash,
      'upiSales': upi,
      'otherSales': other,
      'completedSales': completedSales,
      'refundedSales': refundedSales,
      'cancelledSales': cancelledSales,
      'paymentBreakdown': {
        'Cash': cash,
        'Card': card,
        'UPI': upi,
        'Other': other,
      },
      'statusBreakdown': {
        'Completed': completedSales,
        'Refunded': refundedSales,
        'Cancelled': cancelledSales,
        'completedSales': completedSales,
        'refundedSales': refundedSales,
        'cancelledSales': cancelledSales,
        'completedCount': completedCount,
        'refundedCount': refundedCount,
        'cancelledCount': cancelledCount,
      },
      'totalCogs': cogs,
      'grossProfit': total - cogs,
      'categoryStats': categoryStats,
      'dayStats': dayStats,
    };
  }

  Future<List<Map<String, dynamic>>> getSalesByDay(
      String storeId, int days) async {
    final db = await dbHelper.database;
    final start = DateTime.now().subtract(Duration(days: days));

    // Group by Day (SQLite strftime)
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
    await db.update('orders', {'synced': 1},
        where: 'id = ?', whereArgs: [orderId]);
  }
}
