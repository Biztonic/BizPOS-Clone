import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/sync/outbox/outbox_operation.dart';
import 'package:biztonic_pos/sync/conflict/conflict_record.dart';

mixin SyncRepositoryMixin {
  Future<Database> get database;
  DatabaseHelper get dbHelper;

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

  /// Refunds an order and preserves immutable financial history with audit trail.
  Future<void> refundOrder(
    String id, {
    required String refundedBy,
    required String reason,
    required double refundAmount,
    String? deviceId,
  }) async {
    final db = await dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.rawUpdate('''
      UPDATE orders 
      SET status = 'Refunded', 
          syncStatus = 'PENDING', 
          updatedAt = ?, 
          voidedAt = ?, 
          voidedBy = ?, 
          voidReason = ?,
          version = version + 1
      WHERE id = ? AND status != 'Refunded' AND status != 'VOID'
    ''', [
      now,
      now,
      refundedBy,
      'Refund ($refundAmount): $reason',
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

  /// Marks an item as PUSHED (uploaded to cloud but not yet confirmed by pull)
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

  /// Batch mark operations in outbox as IN_FLIGHT
  Future<void> markOutboxBatchInFlight(List<String> operationIds) async {
    if (operationIds.isEmpty) return;
    final db = await dbHelper.database;
    final placeholders = List.filled(operationIds.length, '?').join(',');
    final nowIso = DateTime.now().toIso8601String();
    await db.rawUpdate(
      'UPDATE outbox_operations SET state = ?, updatedAt = ? WHERE operationId IN ($placeholders)',
      ['IN_FLIGHT', nowIso, ...operationIds],
    );
  }

  /// Batch mark operations in outbox as PUSHED
  Future<void> markOutboxBatchPushed(List<String> operationIds) async {
    if (operationIds.isEmpty) return;
    final db = await dbHelper.database;
    final placeholders = List.filled(operationIds.length, '?').join(',');
    final nowIso = DateTime.now().toIso8601String();
    await db.rawUpdate(
      'UPDATE outbox_operations SET state = ?, updatedAt = ? WHERE operationId IN ($placeholders)',
      ['PUSHED', nowIso, ...operationIds],
    );
  }

  /// Batch mark entity tables as PUSHED grouped by collection
  Future<void> markBatchAsPushed(List<dynamic> operations) async {
    if (operations.isEmpty) return;
    final db = await dbHelper.database;
    final Map<String, List<String>> byTable = {};
    for (var op in operations) {
      final col = (op.collection ?? '').toString();
      final id = (op.entityId ?? '').toString();
      if (col.isNotEmpty && id.isNotEmpty) {
        byTable.putIfAbsent(col, () => []).add(id);
      }
    }

    final nowIso = DateTime.now().toIso8601String();
    for (var entry in byTable.entries) {
      final table = entry.key;
      final ids = entry.value;
      final idCol = table == 'store_settings' ? 'storeId' : 'id';
      final placeholders = List.filled(ids.length, '?').join(',');
      try {
        await db.rawUpdate(
          'UPDATE $table SET syncStatus = ?, updatedAt = ? WHERE $idCol IN ($placeholders)',
          ['PUSHED', nowIso, ...ids],
        );
      } catch (_) {}
    }
  }

  /// Marks an item as CONFIRMED (verified to exist in cloud via pull query)
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

  /// Legacy: marks as SYNCED (equivalent to CONFIRMED for backwards compatibility)
  Future<void> markAsSynced(String table, String id) async {
    final db = await dbHelper.database;
    final idCol = table == 'store_settings' ? 'storeId' : 'id';
    await db.update(
        table,
        {
          'syncStatus': 'CONFIRMED',
          'lastSyncedAt': DateTime.now().toIso8601String(),
          'synced': 1 // Legacy support
        },
        where: '$idCol = ?',
        whereArgs: [id]);
  }
}
