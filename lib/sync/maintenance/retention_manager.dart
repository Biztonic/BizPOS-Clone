import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:biztonic_pos/sync/registry/sync_collection_registry.dart';

/// Handles cloud data retention cleanup for plan-limited stores.
///
/// On Basic plans, old orders and activity logs are purged from Firestore
/// after a configurable retention period (default: 30 days).
///
/// Previously inlined in `SyncService._performCloudRetentionCleanup()`
/// (~40 lines at sync_engine.dart:508-543).
class RetentionManager {
  final FirebaseFirestore _db;

  RetentionManager({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// Cleans up cloud documents older than [retentionDays] for the given store.
  ///
  /// Currently targets:
  /// - `orders` (by `createdAt`)
  /// - `activity_logs` (by `timestamp`)
  ///
  /// Uses batched writes to avoid Firestore rate limiting.
  Future<void> performCloudRetentionCleanup(
    String storeId,
    int retentionDays,
  ) async {
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    final timestamp = Timestamp.fromDate(cutoff);

    debugPrint(
        '🧹 [RetentionManager] Cleaning data older than $retentionDays days for store $storeId');

    // 1. Cleanup Orders
    await _cleanupCollection(
      collection: SyncCollectionRegistry.orders,
      storeId: storeId,
      timestampField: 'createdAt',
      cutoff: timestamp,
    );

    // 2. Cleanup Activity Logs
    await _cleanupCollection(
      collection: SyncCollectionRegistry.activityLogs,
      storeId: storeId,
      timestampField: 'timestamp',
      cutoff: timestamp,
    );
  }

  /// Generic cleanup for any collection with a storeId + timestamp filter.
  Future<void> _cleanupCollection({
    required String collection,
    required String storeId,
    required String timestampField,
    required Timestamp cutoff,
  }) async {
    try {
      final snapshot = await _db
          .collection(collection)
          .where('storeId', isEqualTo: storeId)
          .where(timestampField, isLessThan: cutoff)
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Batch in groups of 500 (Firestore limit)
        final batches = <WriteBatch>[];
        var currentBatch = _db.batch();
        int count = 0;

        for (var doc in snapshot.docs) {
          currentBatch.delete(doc.reference);
          count++;
          if (count % 500 == 0) {
            batches.add(currentBatch);
            currentBatch = _db.batch();
          }
        }
        batches.add(currentBatch);

        for (var batch in batches) {
          await batch.commit();
        }

        debugPrint(
            '🧹 [RetentionManager] Deleted ${snapshot.docs.length} expired docs from $collection');
      }
    } catch (e) {
      debugPrint(
          '⚠️ [RetentionManager] Cleanup error ($collection): $e');
    }
  }
}
