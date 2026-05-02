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

    final db = await dbHelper.database;
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
    final db = await dbHelper.database;
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
    final db = await dbHelper.database;
    final rows = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Customer.fromSql(rows.first);
  }

}


