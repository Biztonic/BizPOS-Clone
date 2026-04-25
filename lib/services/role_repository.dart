import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/models/role_model.dart';

class RoleRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Insert or update role in local database
  Future<void> insertRole(RoleModel role) async {
    final db = await _dbHelper.database;
    
    final data = {
      'id': role.id,
      'storeId': null, // Will be set for store-specific roles
      'name': role.name,
      'permissions': jsonEncode(role.permissions), // Store as JSON string
      'isSystem': role.isSystem ? 1 : 0,
      'description': role.description,
      'storeAccessMode': role.storeAccessMode,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'deletedAt': null,
      'syncStatus': 'PENDING',
      'lastSyncedAt': null,
    };

    await db.insert(
      'roles',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert role with specific storeId
  Future<void> insertRoleWithStore(RoleModel role, String? storeId) async {
    final db = await _dbHelper.database;
    
    final data = {
      'id': role.id,
      'storeId': storeId,
      'name': role.name,
      'permissions': jsonEncode(role.permissions),
      'isSystem': role.isSystem ? 1 : 0,
      'description': role.description,
      'storeAccessMode': role.storeAccessMode,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'deletedAt': null,
      'syncStatus': 'PENDING',
      'lastSyncedAt': null,
    };

    await db.insert(
      'roles',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all roles for a specific store (includes system roles)
  Future<List<RoleModel>> getRolesByStore(String storeId) async {
    final db = await _dbHelper.database;
    
    // Get both system roles and store-specific roles
    final List<Map<String, dynamic>> maps = await db.query(
      'roles',
      where: '(storeId IS NULL OR storeId = ?) AND deletedAt IS NULL',
      whereArgs: [storeId],
      orderBy: 'isSystem DESC, name ASC', // System roles first
    );

    return maps.map((map) => _mapToRoleModel(map)).toList();
  }

  /// Get only system roles (storeId is NULL)
  Future<List<RoleModel>> getSystemRoles() async {
    final db = await _dbHelper.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'roles',
      where: 'storeId IS NULL AND deletedAt IS NULL',
      orderBy: 'name ASC',
    );

    return maps.map((map) => _mapToRoleModel(map)).toList();
  }

  /// Get all roles (system + all stores)
  Future<List<RoleModel>> getAllRoles() async {
    final db = await _dbHelper.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'roles',
      where: 'deletedAt IS NULL',
      orderBy: 'isSystem DESC, name ASC',
    );

    return maps.map((map) => _mapToRoleModel(map)).toList();
  }

  /// Get single role by ID
  Future<RoleModel?> getRoleById(String id) async {
    final db = await _dbHelper.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'roles',
      where: 'id = ? AND deletedAt IS NULL',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return _mapToRoleModel(maps.first);
  }

  /// Soft delete role
  Future<void> deleteRole(String id) async {
    final db = await _dbHelper.database;
    
    await db.update(
      'roles',
      {
        'deletedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'syncStatus': 'PENDING',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark role as synced
  Future<void> markAsSynced(String id) async {
    final db = await _dbHelper.database;
    
    await db.update(
      'roles',
      {
        'syncStatus': 'CONFIRMED',
        'lastSyncedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get roles with pending sync status
  Future<List<Map<String, dynamic>>> getPendingRoles() async {
    final db = await _dbHelper.database;
    
    return await db.query(
      'roles',
      where: 'syncStatus = ?',
      whereArgs: ['PENDING'],
    );
  }

  /// Get role count
  Future<int> getRoleCount() async {
    final db = await _dbHelper.database;
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM roles WHERE deletedAt IS NULL',
    );
    
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Convert database map to RoleModel
  RoleModel _mapToRoleModel(Map<String, dynamic> map) {
    Map<String, bool> permissions = {};
    
    // Parse JSON permissions
    if (map['permissions'] != null) {
      try {
        final decoded = jsonDecode(map['permissions'] as String);
        if (decoded is Map) {
          permissions = Map<String, bool>.from(decoded);
        }
      } catch (e) { /* Error ignored */ }
    }

    return RoleModel(
      id: map['id'] as String,
      name: map['name'] as String,
      permissions: permissions,
      isSystem: (map['isSystem'] as int) == 1,
      description: map['description'] as String?,
      storeAccessMode: map['storeAccessMode'] as String? ?? 'single',
    );
  }

  /// Clear all roles (for testing/reset)
  Future<void> clearAll() async {
    final db = await _dbHelper.database;
    await db.delete('roles');
  }
}
