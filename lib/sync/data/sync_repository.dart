import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/sync/outbox/outbox_operation.dart';
import 'package:biztonic_pos/sync/conflict/conflict_record.dart';

class SyncRepository {
  final DatabaseHelper dbHelper;

  SyncRepository({required this.dbHelper});

  // --- DELETE (SOFT DELETE) ---
  /// VOIDs an order instead of deleting it to preserve audit trail.
  Future<void> voidOrder(String id, {String? voidedBy, String? reason}) async {
    final db = await dbHelper.database;
    await db.rawUpdate('''
      UPDATE orders 
      SET status = 'VOID', 
          syncStatus = 'PENDING', 
          updatedAt = ?, 
          voidedAt = ?, 
          voidedBy = ?, 
          voidReason = ?,
          version = version + 1
      WHERE id = ?
    ''', [
      DateTime.now().toIso8601String(),
      DateTime.now().toIso8601String(),
      voidedBy,
      reason,
      id
    ]);
  }

  Future<void> deleteInventory(String id, {String? deletedBy}) async {
    final db = await dbHelper.database;
    await db.rawUpdate('''
      UPDATE inventory 
      SET deletedAt = ?, 
          deletedBy = ?, 
          isDeleted = 1, 
          syncStatus = 'PENDING', 
          updatedAt = ?,
          version = version + 1
      WHERE id = ?
    ''', [
      DateTime.now().toIso8601String(),
      deletedBy,
      DateTime.now().toIso8601String(),
      id
    ]);
  }

  Future<void> deleteCustomer(String id, {String? deletedBy}) async {
    final db = await dbHelper.database;
    await db.rawUpdate('''
      UPDATE customers 
      SET deletedAt = ?, 
          deletedBy = ?, 
          isDeleted = 1, 
          syncStatus = 'PENDING', 
          updatedAt = ?,
          version = version + 1
      WHERE id = ?
    ''', [
      DateTime.now().toIso8601String(),
      deletedBy,
      DateTime.now().toIso8601String(),
      id
    ]);
  }

  Future<void> deleteOrder(String id, {String? deletedBy}) async {
    final db = await dbHelper.database;
    await db.rawUpdate('''
      UPDATE orders 
      SET status = 'DELETED', 
          deletedAt = ?, 
          deletedBy = ?, 
          isDeleted = 1, 
          syncStatus = 'PENDING', 
          updatedAt = ?,
          version = version + 1
      WHERE id = ?
    ''', [
      DateTime.now().toIso8601String(),
      deletedBy,
      DateTime.now().toIso8601String(),
      id
    ]);
  }

  Future<void> deleteEmployee(String id, {String? deletedBy}) async {
    final db = await dbHelper.database;
    await db.rawUpdate('''
      UPDATE employees 
      SET deletedAt = ?, 
          deletedBy = ?, 
          isDeleted = 1, 
          syncStatus = 'PENDING', 
          updatedAt = ?,
          version = version + 1
      WHERE id = ?
    ''', [
      DateTime.now().toIso8601String(),
      deletedBy,
      DateTime.now().toIso8601String(),
      id
    ]);
  }

  // --- OUTBOX OPERATIONS ---

  Future<void> insertOutboxOperation(OutboxOperation op) async {
    final db = await dbHelper.database;
    await db.insert(
      'outbox_operations',
      op.toSqlRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateOutboxOperation(OutboxOperation op) async {
    final db = await dbHelper.database;
    await db.update(
      'outbox_operations',
      op.toSqlRow(),
      where: 'operationId = ?',
      whereArgs: [op.operationId],
    );
  }

  Future<List<OutboxOperation>> getOutboxOperations({
    String? storeId,
    dynamic state,
    int? limit,
  }) async {
    final db = await dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (storeId != null && storeId.isNotEmpty) {
      whereClauses.add('storeId = ?');
      whereArgs.add(storeId);
    }
    final stateStr = state is OutboxState ? state.value : state?.toString();
    if (stateStr != null && stateStr.isNotEmpty) {
      whereClauses.add('state = ?');
      whereArgs.add(stateStr);
    }

    final rows = await db.query(
      'outbox_operations',
      where: whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'createdAt ASC',
      limit: limit,
    );

    return rows.map((r) => OutboxOperation.fromSqlRow(r)).toList();
  }

  Future<void> deleteOutboxOperation(String operationId) async {
    final db = await dbHelper.database;
    await db.delete(
      'outbox_operations',
      where: 'operationId = ?',
      whereArgs: [operationId],
    );
  }

  // --- CONFLICT RECORDS ---

  Future<void> insertConflictRecord(ConflictRecord record) async {
    final db = await dbHelper.database;
    await db.insert(
      'conflict_records',
      record.toSqlRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ConflictRecord>> getConflictRecords({
    String? storeId,
    int? limit,
  }) async {
    final db = await dbHelper.database;
    final where =
        (storeId != null && storeId.isNotEmpty) ? 'storeId = ?' : null;
    final args = (storeId != null && storeId.isNotEmpty) ? [storeId] : null;

    final rows = await db.query(
      'conflict_records',
      where: where,
      whereArgs: args,
      orderBy: 'createdAt DESC',
      limit: limit,
    );

    return rows.map((r) => ConflictRecord.fromMap(r)).toList();
  }

  Future<void> resolveConflictRecord(
      String id, String resolution, String resolvedBy) async {
    final db = await dbHelper.database;
    await db.update(
      'conflict_records',
      {
        'resolution': resolution,
        'resolvedBy': resolvedBy,
        'resolvedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- SYNC STATE MACHINE ---

  Future<void> markAsPushed(String table, String id) async {
    final db = await dbHelper.database;
    final idCol = table == 'store_settings' ? 'storeId' : 'id';
    await db.update(
        table,
        {
          'syncStatus': 'PUSHED',
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: '$idCol = ?',
        whereArgs: [id]);
  }

  Future<void> markAsConfirmed(String table, String id) async {
    final db = await dbHelper.database;
    final idCol = table == 'store_settings' ? 'storeId' : 'id';
    await db.update(
        table,
        {
          'syncStatus': 'CONFIRMED',
          'lastSyncedAt': DateTime.now().toIso8601String(),
        },
        where: '$idCol = ?',
        whereArgs: [id]);
  }

  Future<void> markAsSynced(String table, String id) async {
    final db = await dbHelper.database;
    final idCol = table == 'store_settings' ? 'storeId' : 'id';
    await db.update(
        table,
        {
          'syncStatus': 'CONFIRMED',
          'lastSyncedAt': DateTime.now().toIso8601String(),
          'synced': 1
        },
        where: '$idCol = ?',
        whereArgs: [id]);
  }
}
