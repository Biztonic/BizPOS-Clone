import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/sync/registry/sync_collection_registry.dart';
import 'package:biztonic_pos/services/database_helper.dart';

/// Handles cache repair, queue maintenance, and nuclear reset operations.
///
/// Previously scattered across `SyncService`:
/// - `_repairUnsyncedItems()` (lines 1483-1517)
/// - `clearStoreCache()` (lines 1112-1153)
/// - `clearAllLocalData()` (lines 1155-1158)
/// - `resetQueueRetries()` (lines 1160-1170)
class SyncMaintenanceEngine {
  final Box? Function() _getQueueBox;
  final Future<void> Function({
    required String collection,
    required String docId,
    required String action,
    required Map<String, dynamic> payload,
  }) _queueOperation;
  final String? Function() _getActiveStoreId;

  SyncMaintenanceEngine({
    required Box? Function() getQueueBox,
    required Future<void> Function({
      required String collection,
      required String docId,
      required String action,
      required Map<String, dynamic> payload,
    }) queueOperation,
    required String? Function() getActiveStoreId,
  })  : _getQueueBox = getQueueBox,
        _queueOperation = queueOperation,
        _getActiveStoreId = getActiveStoreId;

  /// Scans a Hive cache box for items that are PENDING/ERROR but not in
  /// the outbound queue, and re-queues them.
  ///
  /// This repairs the "lost write" scenario where a local write succeeded
  /// but the queue entry was lost (crash, box corruption, etc.).
  /// Scans a Hive cache box and SQLite table for items that are PENDING/ERROR
  /// but not in the outbound queue, and re-queues them.
  Future<int> repairUnsyncedItems(String module,
      {bool forceAll = false}) async {
    final storeId = _getActiveStoreId();
    int repairedCount = 0;

    final queueBox = _getQueueBox();
    final Set<String> queueKeys = {};
    if (queueBox != null && queueBox.isOpen) {
      for (final v in queueBox.values) {
        if (v is Map) {
          final state = (v['state'] ?? 'PENDING').toString().toUpperCase();
          if (state == 'PENDING' || state == 'IN_FLIGHT' || state == 'FAILED') {
            final docId = v['docId']?.toString();
            if (docId != null && docId.isNotEmpty) queueKeys.add(docId);
          }
        }
      }
    }

    // 1. Scan SQLite on Native (!kIsWeb) for heavy data modules
    if (!kIsWeb && storeId != null && storeId.isNotEmpty) {
      try {
        final db = await DatabaseHelper().database;
        String? tableName;
        if (module == SyncCollectionRegistry.inventory) {
          tableName = 'inventory';
        } else if (module == SyncCollectionRegistry.orders) {
          tableName = 'orders';
        } else if (module == SyncCollectionRegistry.customers) {
          tableName = 'customers';
        } else if (module == SyncCollectionRegistry.inventoryMovements) {
          tableName = 'inventory_movements';
        }

        if (tableName != null) {
          final whereClause = forceAll
              ? 'storeId = ?'
              : "storeId = ? AND (syncStatus = 'PENDING' OR syncStatus = 'ERROR' OR syncStatus IS NULL)";
          final rows = await db.query(
            tableName,
            where: whereClause,
            whereArgs: [storeId],
          );
          for (final row in rows) {
            final docId = row['id']?.toString() ?? '';
            if (docId.isEmpty || queueKeys.contains(docId)) continue;

            final payload = Map<String, dynamic>.from(row);
            payload['storeId'] = storeId;
            if (tableName == 'inventory_movements' &&
                payload['createdAt'] is int) {
              payload['createdAt'] = DateTime.fromMillisecondsSinceEpoch(
                      payload['createdAt'] as int)
                  .toIso8601String();
            }
            final action = (payload['deletedAt'] != null ||
                    payload['isDeleted'] == 1 ||
                    payload['isDeleted'] == true)
                ? 'delete'
                : 'create';
            await _queueOperation(
              collection: module,
              docId: docId,
              action: action,
              payload: payload,
            );
            queueKeys.add(docId);
            repairedCount++;
          }
        }
      } catch (e) {
        debugPrint('⚠️ [Maintenance] SQLite repair scan failed for $module: $e');
      }
    }

    // 2. Scan Hive cache box
    final boxName = SyncCollectionRegistry.getBoxName(module, storeId: storeId);
    if (boxName == null) return repairedCount;

    try {
      final box = await Hive.openBox(boxName);
      for (var key in box.keys) {
        final val = box.get(key);
        if (val is! Map) continue;

        bool shouldQueue = forceAll ||
            val['syncStatus'] == 'PENDING' ||
            val['syncStatus'] == 'ERROR' ||
            val['syncStatus'] == null;

        if (!shouldQueue) continue;
        if (queueKeys.contains(key.toString())) continue;

        // STORE ISOLATION: Only repair items belonging to the current active store
        final itemStoreId = (val['storeId'] ?? '').toString().trim();
        if (storeId != null &&
            itemStoreId.isNotEmpty &&
            itemStoreId != storeId) {
          continue;
        }

        final action = val['deletedAt'] != null
            ? 'delete'
            : (val['createdAt'] == null ? 'update' : 'create');

        await _queueOperation(
          collection: module,
          docId: key.toString(),
          action: action,
          payload: Map<String, dynamic>.from(val),
        );
        queueKeys.add(key.toString());
        repairedCount++;
      }

      if (repairedCount > 0) {
        debugPrint(
            '🔧 [Maintenance] Repaired $repairedCount unsynced items in $module');
      }
      return repairedCount;
    } catch (e) {
      debugPrint('⚠️ [Maintenance] Repair failed for $module: $e');
      return repairedCount;
    }
  }

  /// Clears all cached data for a specific store from Hive.
  Future<void> clearStoreCache(String storeId) async {
    final sid = storeId.trim().toLowerCase();

    for (var mod in SyncCollectionRegistry.heavyDataModules) {
      try {
        final boxName =
            SyncCollectionRegistry.getBoxName(mod, storeId: storeId);
        if (boxName == null) continue;

        final box = await Hive.openBox(boxName);
        final keysToDelete = [];
        for (var key in box.keys) {
          final val = box.get(key);
          if (val is Map) {
            final vStoreId =
                (val['storeId'] ?? '').toString().trim().toLowerCase();
            if (vStoreId == sid) keysToDelete.add(key);
          } else if (boxName.contains(sid)) {
            keysToDelete.add(key);
          }
        }
        if (keysToDelete.isNotEmpty) {
          await box.deleteAll(keysToDelete);
        }
      } catch (e) {
        /* Error ignored */
      }
    }

    // Clear settings for this store too
    try {
      final sBox =
          await Hive.openBox(SyncCollectionRegistry.boxSettingsGeneral);
      await sBox.delete('store_settings_$storeId');
      await sBox.delete('last_sync_time_$storeId');
    } catch (e) {
      /* Error ignored */
    }

    debugPrint('🧹 [Maintenance] Cleared cache for store $storeId');
  }

  /// Clears ALL local data (queue + settings). Nuclear option.
  Future<void> clearAllLocalData() async {
    final queueBox = _getQueueBox();
    if (queueBox != null) await queueBox.clear();
    if (Hive.isBoxOpen(SyncCollectionRegistry.boxSettingsGeneral)) {
      await Hive.box(SyncCollectionRegistry.boxSettingsGeneral).clear();
    }
    debugPrint('🧹 [Maintenance] Cleared ALL local data');
  }

  /// Resets retry counts on all items in the outbound queue.
  /// Useful when retries were exhausted due to temporary network issues.
  Future<void> resetQueueRetries() async {
    final queueBox = _getQueueBox();
    if (queueBox == null) return;

    int resetCount = 0;
    for (var key in queueBox.keys) {
      final val = queueBox.get(key);
      if (val is Map) {
        val['retryCount'] = 0;
        await queueBox.put(key, val);
        resetCount++;
      }
    }
    debugPrint('🔧 [Maintenance] Reset retries on $resetCount queue items');
  }

  /// Repairs all pull modules by scanning for unsynced items and re-queuing them.
  Future<void> repairAllModules() async {
    int totalRepaired = 0;

    // 1. Purge corrupted queue entries first
    await purgeCorruptedQueueEntries();

    // 2. Repair orphaned transaction journals
    await repairTransactionJournals();

    // 3. Prune old completed/discarded journals
    await pruneTransactionJournals();

    // 4. Re-queue unsynced items
    for (var module in SyncCollectionRegistry.pullModules) {
      totalRepaired += await repairUnsyncedItems(module);
    }
    debugPrint(
        '🔧 [Maintenance] repairAllModules complete: $totalRepaired items repaired');
  }

  /// Purges sync queue entries that are structurally invalid or corrupted
  Future<void> purgeCorruptedQueueEntries() async {
    try {
      final queueBox = _getQueueBox();
      if (queueBox == null || !queueBox.isOpen) return;

      final keysToRemove = [];
      for (var key in queueBox.keys) {
        final val = queueBox.get(key);
        if (val is! Map) {
          keysToRemove.add(key);
          continue;
        }

        final docId = val['docId'];
        final collection = val['collection'];
        final action = val['type'];

        // If fundamental fields are missing, it's corrupted
        if (docId == null || collection == null || action == null) {
          keysToRemove.add(key);
        }
      }

      if (keysToRemove.isNotEmpty) {
        await queueBox.deleteAll(keysToRemove);
        debugPrint(
            '⚠️ [Maintenance] Purged ${keysToRemove.length} corrupted sync queue entries');
      }
    } catch (e) {
      debugPrint(
          '⚠️ [Maintenance] Failed to purge corrupted queue entries: $e');
    }
  }

  /// Finds interrupted/orphaned SQLite transactions and marks them FAILED
  Future<void> repairTransactionJournals() async {
    try {
      final db = await DatabaseHelper().database;

      // Transactions older than 1 hour that are still PENDING are considered abandoned
      final oneHourAgo =
          DateTime.now().subtract(const Duration(hours: 1)).toIso8601String();

      final pendingTxs = await db.query(
        'transaction_journal',
        where: 'status = ? AND createdAt < ?',
        whereArgs: ['PENDING', oneHourAgo],
      );

      if (pendingTxs.isEmpty) return;

      debugPrint(
          '🔧 [Maintenance] Found ${pendingTxs.length} corrupted/interrupted transactions. Repairing...');

      final batch = db.batch();
      for (var tx in pendingTxs) {
        batch.update(
          'transaction_journal',
          {
            'status': 'FAILED',
            'error': 'Crash interrupted transaction',
            'completedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [tx['id']],
        );
      }
      await batch.commit(noResult: true);

      debugPrint(
          '⚠️ [Maintenance] Marked ${pendingTxs.length} orphaned transactions as FAILED');
    } catch (e) {
      debugPrint('⚠️ [Maintenance] Transaction journal repair failed: $e');
    }
  }

  /// Prunes COMPLETED or DISCARDED journal entries older than 30 days
  Future<void> pruneTransactionJournals() async {
    try {
      final db = await DatabaseHelper().database;

      // Entries older than 30 days
      final thirtyDaysAgo =
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String();

      final count = await db.delete(
        'transaction_journal',
        where: '(status = ? OR status = ?) AND createdAt < ?',
        whereArgs: ['COMPLETED', 'DISCARDED', thirtyDaysAgo],
      );

      if (count > 0) {
        debugPrint(
            '🧹 [Maintenance] Pruned $count old transaction journal entries');
      }
    } catch (e) {
      debugPrint('⚠️ [Maintenance] Transaction journal pruning failed: $e');
    }
  }

  /// Clears sync metadata (last sync times) for a store, forcing a full re-pull.
  Future<void> clearStoreMetadata(String? storeId) async {
    if (storeId == null) return;
    try {
      final sBox =
          await Hive.openBox(SyncCollectionRegistry.boxSettingsGeneral);
      for (var module in SyncCollectionRegistry.pullModules) {
        await sBox.delete('last_sync_${module}_$storeId');
      }
      debugPrint('🧹 [Maintenance] Cleared sync metadata for store $storeId');
    } catch (e) {
      debugPrint('⚠️ [Maintenance] Failed to clear metadata: $e');
    }
  }
}
