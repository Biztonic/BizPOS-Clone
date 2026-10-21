import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/models/customer.dart';

mixin CustomerRepositoryMixin {
  Future<Database> get database;
  DatabaseHelper get dbHelper;

  // --- CUSTOMERS ---

  Future<void> insertCustomer(Customer customer) async {
    final db = await dbHelper.database;
    try {
      await db.insert('customers', customer.toSqlMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      if (e.toString().contains('no column named')) {
        try {
          await db.execute(
              'ALTER TABLE customers ADD COLUMN udhariBalance REAL DEFAULT 0.0');
        } catch (_) {}
        try {
          await db.execute(
              'ALTER TABLE customers ADD COLUMN creditLimit REAL DEFAULT 0.0');
        } catch (_) {}
        try {
          await db.insert('customers', customer.toSqlMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
          return;
        } catch (_) {
          final sanitized = Map<String, dynamic>.from(customer.toSqlMap())
            ..remove('udhariBalance')
            ..remove('creditLimit');
          await db.insert('customers', sanitized,
              conflictAlgorithm: ConflictAlgorithm.replace);
          return;
        }
      }
      rethrow;
    }
  }

  // --- BATCH CUSTOMERS ---
  Future<void> batchInsertCustomers(List<Customer> customers) async {
    if (customers.isEmpty) return;

    final db = await dbHelper.database;
    try {
      final batch = db.batch();
      for (var customer in customers) {
        batch.insert(
          'customers',
          customer.toSqlMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      if (e.toString().contains('no column named')) {
        try {
          await db.execute(
              'ALTER TABLE customers ADD COLUMN udhariBalance REAL DEFAULT 0.0');
        } catch (_) {}
        try {
          await db.execute(
              'ALTER TABLE customers ADD COLUMN creditLimit REAL DEFAULT 0.0');
        } catch (_) {}
        final batch = db.batch();
        for (var customer in customers) {
          batch.insert(
            'customers',
            customer.toSqlMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
        return;
      }
      rethrow;
    }
  }

  Future<List<Customer>> getCustomers(String? storeId,
      {int limit = 100}) async {
    final db = await dbHelper.database;
    String sql = 'SELECT * FROM customers WHERE deletedAt IS NULL';
    List<dynamic> args = [];
    if (storeId != null && storeId.isNotEmpty) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    sql += ' ORDER BY name ASC LIMIT ?';
    args.add(limit);
    final rows = await db.rawQuery(sql, args);
    return rows.map((r) => Customer.fromSql(r)).toList();
  }

  /// Keyset paginated customer retrieval
  Future<List<Customer>> getPaginatedCustomers(
    String? storeId, {
    int limit = 50,
    String? lastId,
  }) async {
    final db = await dbHelper.database;
    String sql =
        'SELECT * FROM customers WHERE isDeleted = 0 AND deletedAt IS NULL';
    List<dynamic> args = [];
    if (storeId != null && storeId.isNotEmpty) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    if (lastId != null && lastId.isNotEmpty) {
      sql += ' AND id > ?';
      args.add(lastId);
    }
    sql += ' ORDER BY id ASC LIMIT ?';
    args.add(limit);
    final rows = await db.rawQuery(sql, args);
    return rows.map((r) => Customer.fromSql(r)).toList();
  }

  /// Indexed search by exact phone, exact mobile, or prefix/partial name
  Future<List<Customer>> searchCustomers(
    String? storeId,
    String query, {
    int limit = 50,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final db = await dbHelper.database;

    // Fast indexed path: Exact phone/mobile lookup using idx_customers_store_phone or idx_customers_store_mobile
    final isNumericQuery = RegExp(r'^[0-9+\-]+$').hasMatch(cleanQuery);
    if (isNumericQuery && storeId != null && storeId.isNotEmpty) {
      var phoneRows = await db.rawQuery(
        'SELECT * FROM customers WHERE storeId = ? AND isDeleted = 0 AND phone = ? AND deletedAt IS NULL LIMIT ?',
        [storeId, cleanQuery, limit],
      );
      if (phoneRows.isEmpty) {
        phoneRows = await db.rawQuery(
          'SELECT * FROM customers WHERE storeId = ? AND isDeleted = 0 AND mobile = ? AND deletedAt IS NULL LIMIT ?',
          [storeId, cleanQuery, limit],
        );
      }
      if (phoneRows.isNotEmpty) {
        return phoneRows.map((r) => Customer.fromSql(r)).toList();
      }
    }

    String sql =
        'SELECT * FROM customers WHERE isDeleted = 0 AND deletedAt IS NULL';
    List<dynamic> args = [];
    if (storeId != null && storeId.isNotEmpty) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    sql += ' AND (phone = ? OR mobile = ? OR name LIKE ?)';
    args.addAll([cleanQuery, cleanQuery, '%$cleanQuery%']);
    sql += ' ORDER BY name ASC LIMIT ?';
    args.add(limit);
    final rows = await db.rawQuery(sql, args);
    return rows.map((r) => Customer.fromSql(r)).toList();
  }

  Future<Customer?> getCustomer(String id) async {
    final db = await dbHelper.database;
    final rows = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Customer.fromSql(rows.first);
  }
}
