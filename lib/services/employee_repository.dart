import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/models/user_profile.dart';
import 'dart:convert';

class EmployeeRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Insert or update employee in local database
  Future<void> insertEmployee(UserProfile employee) async {
    final db = await _dbHelper.database;
    
    final data = {
      'id': employee.uid,
      'storeId': employee.storeId,
      'name': employee.name,
      'email': employee.email,
      'role': employee.role,
      'employeeId': employee.employeeId,
      'pinHash': employee.pinHash,
      'permissions': employee.permissions != null ? jsonEncode(employee.permissions) : null,
      'hourlyRate': employee.hourlyRate,
      'monthlySalary': employee.monthlySalary,
      'createdAt': employee.createdAt?.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'deletedAt': null,
      'syncStatus': 'PENDING',
      'deviceId': null, // Will be set by sync service
      'lastSyncedAt': null,
    };

    await db.insert(
      'employees',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all employees for a specific store
  Future<List<UserProfile>> getEmployeesByStore(String storeId) async {
    final db = await _dbHelper.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'employees',
      where: 'storeId = ? AND deletedAt IS NULL',
      whereArgs: [storeId],
      orderBy: 'name ASC',
    );

    return maps.map((map) => _mapToUserProfile(map)).toList();
  }

  /// Get single employee by ID
  Future<UserProfile?> getEmployeeById(String id) async {
    final db = await _dbHelper.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'employees',
      where: 'id = ? AND deletedAt IS NULL',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return _mapToUserProfile(maps.first);
  }

  /// Soft delete employee
  Future<void> deleteEmployee(String id) async {
    final db = await _dbHelper.database;
    
    await db.update(
      'employees',
      {
        'deletedAt': DateTime.now().toIso8601String(),
        'isDeleted': 1,
        'updatedAt': DateTime.now().toIso8601String(),
        'syncStatus': 'PENDING',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark employee as synced
  Future<void> markAsSynced(String id) async {
    final db = await _dbHelper.database;
    
    await db.update(
      'employees',
      {
        'syncStatus': 'CONFIRMED',
        'lastSyncedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get employees with pending sync status
  Future<List<Map<String, dynamic>>> getPendingEmployees() async {
    final db = await _dbHelper.database;
    
    return await db.query(
      'employees',
      where: 'syncStatus = ?',
      whereArgs: ['PENDING'],
    );
  }

  /// Update employee role
  Future<void> updateEmployeeRole(String id, String newRole) async {
    final db = await _dbHelper.database;
    
    await db.update(
      'employees',
      {
        'role': newRole,
        'updatedAt': DateTime.now().toIso8601String(),
        'syncStatus': 'PENDING',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get employee count for a store
  Future<int> getEmployeeCount(String storeId) async {
    final db = await _dbHelper.database;
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM employees WHERE storeId = ? AND deletedAt IS NULL',
      [storeId],
    );
    
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Convert database map to UserProfile
  UserProfile _mapToUserProfile(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['id'] as String,
      email: map['email'] as String,
      name: map['name'] as String,
      role: map['role'] as String,
      storeId: map['storeId'] as String?,
      employeeId: map['employeeId'] as String?,
      pinHash: map['pinHash'] as String? ?? map['pin'] as String?,
      permissions: map['permissions'] != null ? Map<String, bool>.from(jsonDecode(map['permissions'])) : null,
      hourlyRate: (map['hourlyRate'] ?? 0.0).toDouble(),
      monthlySalary: (map['monthlySalary'] ?? 0.0).toDouble(),
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      accessibleStoreIds: map['storeId'] != null ? [map['storeId'] as String] : [],
    );
  }

  // --- ATTENDANCE ---
  Future<void> insertAttendance(Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    await db.insert('employee_attendance', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAttendance(String employeeId) async {
    final db = await _dbHelper.database;
    return await db.query('employee_attendance', where: 'employeeId = ?', whereArgs: [employeeId], orderBy: 'checkIn DESC');
  }

  // --- LEAVES ---
  Future<void> insertLeave(Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    await db.insert('employee_leaves', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getLeaves(String employeeId) async {
    final db = await _dbHelper.database;
    return await db.query('employee_leaves', where: 'employeeId = ?', whereArgs: [employeeId], orderBy: 'startDate DESC');
  }

  // --- PAYROLL ---
  Future<void> insertPayroll(Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    await db.insert('employee_payroll', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getPayroll(String employeeId) async {
    final db = await _dbHelper.database;
    return await db.query('employee_payroll', where: 'employeeId = ?', whereArgs: [employeeId], orderBy: 'periodEnd DESC');
  }

  /// Clear all employees (for testing/reset)
  Future<void> clearAll() async {
    final db = await _dbHelper.database;
    await db.delete('employees');
  }
}
