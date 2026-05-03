import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/models/user_profile.dart';
import 'package:flutter/foundation.dart';

mixin StoreRepositoryMixin {
  Future<Database> get database;
  DatabaseHelper get dbHelper;

  // --- MIGRATED OFFLINE CONFIG ENTITIES (JSON BLOBS) ---
  
  // Settings
  Future<void> insertStoreSettings(String storeId, Map<String, dynamic> data) async {
    final db = await dbHelper.database;
    await db.insert('store_settings', {
      'storeId': storeId,
      'data': jsonEncode(data),
      'syncStatus': 'CONFIRMED',
      'updatedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getStoreSettings(String storeId) async {
    final db = await dbHelper.database;
    final rows = await db.query('store_settings', where: 'storeId = ? AND deletedAt IS NULL', whereArgs: [storeId]);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
  }

  // Floors
  Future<void> insertFloor(String id, String storeId, Map<String, dynamic> data) async {
    final db = await dbHelper.database;
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
    final db = await dbHelper.database;
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
    final db = await dbHelper.database;
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
    final db = await dbHelper.database;
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
    final db = await dbHelper.database;
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
    final db = await dbHelper.database;
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
    final db = await dbHelper.database;
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
    final db = await dbHelper.database;
    return await db.query(table, where: "syncStatus IN ('PENDING', 'PUSHED') OR syncStatus IS NULL");
  }
}


