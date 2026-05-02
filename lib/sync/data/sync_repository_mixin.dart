import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';

mixin SyncRepositoryMixin {
  Future<Database> get database;
  DatabaseHelper get dbHelper;

  // --- DELETE (SOFT DELETE) ---
  /// VOIDs an order instead of deleting it to preserve audit trail.
  Future<void> voidOrder(String id, {String? voidedBy, String? reason}) async {
    final db = await dbHelper.database;
    await db.update('orders', 
      {
        'status': 'VOID', 
        'syncStatus': 'PENDING', 
        'updatedAt': DateTime.now().toIso8601String(),
        'voidedAt': DateTime.now().toIso8601String(),
        'voidedBy': voidedBy,
        'voidReason': reason,
      }, 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }

  Future<void> deleteInventory(String id) async {
    final db = await dbHelper.database;
     await db.update('inventory', 
      {'deletedAt': DateTime.now().toIso8601String(), 'isDeleted': 1, 'syncStatus': 'PENDING', 'updatedAt': DateTime.now().toIso8601String()}, 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }

  Future<void> deleteCustomer(String id) async {
    final db = await dbHelper.database;
     await db.update('customers', 
      {'deletedAt': DateTime.now().toIso8601String(), 'isDeleted': 1, 'syncStatus': 'PENDING', 'updatedAt': DateTime.now().toIso8601String()}, 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }

  Future<void> deleteOrder(String id) async {
    final db = await dbHelper.database;
    await db.update('orders', 
      {'status': 'DELETED', 'isDeleted': 1, 'syncStatus': 'PENDING', 'updatedAt': DateTime.now().toIso8601String()}, 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }

  Future<void> deleteEmployee(String id) async {
    final db = await dbHelper.database;
    await db.update('employees', 
      {'deletedAt': DateTime.now().toIso8601String(), 'isDeleted': 1, 'syncStatus': 'PENDING', 'updatedAt': DateTime.now().toIso8601String()}, 
      where: 'id = ?', 
      whereArgs: [id]
    );
  }

  // --- SYNC STATE MACHINE ---
  
  /// Marks an item as PUSHED (uploaded to cloud but not yet confirmed by pull)
  Future<void> markAsPushed(String table, String id) async {
    final db = await dbHelper.database;
    final idCol = table == 'store_settings' ? 'storeId' : 'id';
    await db.update(table, {
      'syncStatus': 'PUSHED',
      'updatedAt': DateTime.now().toIso8601String(),
    }, where: '$idCol = ?', whereArgs: [id]);
  }

  /// Marks an item as CONFIRMED (verified to exist in cloud via pull query)
  Future<void> markAsConfirmed(String table, String id) async {
    final db = await dbHelper.database;
    final idCol = table == 'store_settings' ? 'storeId' : 'id';
    await db.update(table, {
      'syncStatus': 'CONFIRMED',
      'lastSyncedAt': DateTime.now().toIso8601String(),
    }, where: '$idCol = ?', whereArgs: [id]);
  }

  /// Legacy: marks as SYNCED (equivalent to CONFIRMED for backwards compatibility)
  Future<void> markAsSynced(String table, String id) async {
     final db = await dbHelper.database;
     final idCol = table == 'store_settings' ? 'storeId' : 'id';
     await db.update(table, {
       'syncStatus': 'CONFIRMED', 
       'lastSyncedAt': DateTime.now().toIso8601String(),
       'synced': 1 // Legacy support
     }, where: '$idCol = ?', whereArgs: [id]);
  }

}


