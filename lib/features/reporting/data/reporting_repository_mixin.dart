import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/models/business_ledger.dart';

mixin ReportingRepositoryMixin {
  Future<Database> get database;
  DatabaseHelper get dbHelper;

  // --- COUNTS ---
  Future<int> getOrderCount(String? storeId) async {
    final db = await dbHelper.database;
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
    final db = await dbHelper.database;
    String sql = "SELECT COUNT(*) FROM orders WHERE date >= ? AND (deletedAt IS NULL AND status NOT IN ('Cancelled', 'VOID', 'Refunded'))";
    List<dynamic> args = [since.toIso8601String()];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.insert(0, storeId); // Add storeId at the beginning of args
    }
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }

  Future<int> getInventoryCount(String? storeId) async {
    final db = await dbHelper.database;
    String sql = 'SELECT COUNT(*) FROM inventory WHERE deletedAt IS NULL';
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }

  Future<int> getCustomerCount(String? storeId) async {
    final db = await dbHelper.database;
    String sql = 'SELECT COUNT(*) FROM customers WHERE deletedAt IS NULL';
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }

  Future<int> getEmployeeCount(String? storeId) async {
    final db = await dbHelper.database;
    String sql = 'SELECT COUNT(*) FROM employees WHERE deletedAt IS NULL';
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }

  Future<int> getFloorCount(String? storeId) async {
    final db = await dbHelper.database;
    String sql = 'SELECT COUNT(*) FROM floors WHERE deletedAt IS NULL';
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }

  Future<int> getTableCount(String? storeId) async {
    final db = await dbHelper.database;
    String sql = 'SELECT COUNT(*) FROM tables WHERE deletedAt IS NULL';
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }

  Future<int> getSupplierCount(String? storeId) async {
    final db = await dbHelper.database;
    String sql = 'SELECT COUNT(*) FROM suppliers WHERE deletedAt IS NULL';
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }

  Future<int> getNoteCount(String? storeId) async {
    final db = await dbHelper.database;
    String sql = 'SELECT COUNT(*) FROM notes WHERE deletedAt IS NULL';
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }

  // --- BUSINESS LEDGER ---
  
  Future<void> insertBusinessEvent(BusinessEvent event) async {
    final db = await dbHelper.database;
    await db.insert(
      'business_events', 
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace
    );
  }

  Future<List<BusinessEvent>> getUnsyncedEvents(String? storeId) async {
    final db = await dbHelper.database;
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
    final db = await dbHelper.database;
    await db.update(
      'business_events', 
      {'synced': 1, 'syncedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id]
    );
  }

  Future<List<BusinessEvent>> getBusinessEvents(String storeId, {int limit = 50}) async {
    final db = await dbHelper.database;
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
    await dbHelper.nukeDatabase();
  }

}


