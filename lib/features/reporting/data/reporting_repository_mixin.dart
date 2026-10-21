import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/models/business_ledger.dart';

mixin ReportingRepositoryMixin {
  Future<Database> get database;
  DatabaseHelper get dbHelper;

  // --- COUNTS (Strict Local Tenant Isolation) ---
  Future<int> getOrderCount(String? storeId) async {
    if (storeId == null || storeId.isEmpty) return 0;
    final db = await dbHelper.database;
    const sql =
        "SELECT COUNT(*) FROM orders WHERE storeId = ? AND (deletedAt IS NULL AND status NOT IN ('Cancelled', 'VOID', 'Refunded'))";
    final int count =
        Sqflite.firstIntValue(await db.rawQuery(sql, [storeId])) ?? 0;
    return count;
  }

  // Authoritative Subscription Limits Count
  Future<int> getOrderCountSince(String? storeId, DateTime since) async {
    if (storeId == null || storeId.isEmpty) return 0;
    final db = await dbHelper.database;
    const sql =
        "SELECT COUNT(*) FROM orders WHERE storeId = ? AND date >= ? AND (deletedAt IS NULL AND status NOT IN ('Cancelled', 'VOID', 'Refunded'))";
    final args = [storeId, since.toIso8601String()];
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }

  Future<int> getInventoryCount(String? storeId) async {
    if (storeId == null || storeId.isEmpty) return 0;
    final db = await dbHelper.database;
    const sql =
        'SELECT COUNT(*) FROM inventory WHERE storeId = ? AND deletedAt IS NULL';
    return Sqflite.firstIntValue(await db.rawQuery(sql, [storeId])) ?? 0;
  }

  Future<int> getCustomerCount(String? storeId) async {
    if (storeId == null || storeId.isEmpty) return 0;
    final db = await dbHelper.database;
    const sql =
        'SELECT COUNT(*) FROM customers WHERE storeId = ? AND deletedAt IS NULL';
    return Sqflite.firstIntValue(await db.rawQuery(sql, [storeId])) ?? 0;
  }

  Future<int> getEmployeeCount(String? storeId) async {
    if (storeId == null || storeId.isEmpty) return 0;
    final db = await dbHelper.database;
    const sql =
        'SELECT COUNT(*) FROM employees WHERE storeId = ? AND deletedAt IS NULL';
    return Sqflite.firstIntValue(await db.rawQuery(sql, [storeId])) ?? 0;
  }

  Future<int> getFloorCount(String? storeId) async {
    if (storeId == null || storeId.isEmpty) return 0;
    final db = await dbHelper.database;
    const sql =
        'SELECT COUNT(*) FROM floors WHERE storeId = ? AND deletedAt IS NULL';
    return Sqflite.firstIntValue(await db.rawQuery(sql, [storeId])) ?? 0;
  }

  Future<int> getTableCount(String? storeId) async {
    if (storeId == null || storeId.isEmpty) return 0;
    final db = await dbHelper.database;
    const sql =
        'SELECT COUNT(*) FROM tables WHERE storeId = ? AND deletedAt IS NULL';
    return Sqflite.firstIntValue(await db.rawQuery(sql, [storeId])) ?? 0;
  }

  Future<int> getSupplierCount(String? storeId) async {
    if (storeId == null || storeId.isEmpty) return 0;
    final db = await dbHelper.database;
    const sql =
        'SELECT COUNT(*) FROM suppliers WHERE storeId = ? AND deletedAt IS NULL';
    return Sqflite.firstIntValue(await db.rawQuery(sql, [storeId])) ?? 0;
  }

  Future<int> getNoteCount(String? storeId) async {
    if (storeId == null || storeId.isEmpty) return 0;
    final db = await dbHelper.database;
    const sql =
        'SELECT COUNT(*) FROM notes WHERE storeId = ? AND deletedAt IS NULL';
    return Sqflite.firstIntValue(await db.rawQuery(sql, [storeId])) ?? 0;
  }

  // --- BUSINESS LEDGER ---

  Future<void> insertBusinessEvent(BusinessEvent event) async {
    final db = await dbHelper.database;
    await db.insert('business_events', event.toSqlMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<BusinessEvent>> getUnsyncedEvents(String? storeId) async {
    if (storeId == null || storeId.isEmpty) return [];
    final db = await dbHelper.database;
    const sql =
        'SELECT * FROM business_events WHERE storeId = ? AND synced = 0';
    final rows = await db.rawQuery(sql, [storeId]);
    return rows.map((r) => BusinessEvent.fromMap(r)).toList();
  }

  Future<void> markEventAsSynced(String id) async {
    final db = await dbHelper.database;
    await db.update('business_events',
        {'synced': 1, 'syncedAt': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<BusinessEvent>> getBusinessEvents(String storeId,
      {int limit = 50}) async {
    if (storeId.isEmpty) return [];
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
