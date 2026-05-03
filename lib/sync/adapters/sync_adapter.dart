import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/services/repository.dart';

/// Contract for collection-specific sync behavior.
///
/// Decouples the sync engine from business entity knowledge.
/// Each adapter encapsulates how to:
/// - Parse cloud data into local entities
/// - Write entities to SQLite
/// - Delete entities from SQLite
/// - Handle collection-specific reconciliation logic
/// - Build Firestore queries (Delta vs Full)
///
/// The sync engine operates on adapters via this interface,
/// never importing OrderModel, InventoryItem, etc. directly.
abstract class SyncAdapter {
  /// The Firestore collection name this adapter handles.
  String get collection;

  /// Builds a Firestore query for pulling updates.
  /// Standard implementation uses 'storeId' filter and 'updatedAt' for deltas.
  Query buildQuery(FirebaseFirestore db, String storeId, DateTime? lastSyncTime) {
    Query query = db.collection(collection).where('storeId', isEqualTo: storeId);
    if (lastSyncTime != null) {
      query = query.where('updatedAt', isGreaterThan: Timestamp.fromDate(lastSyncTime));
    }
    return query;
  }

  /// Insert or update an entity from cloud data into local storage (SQLite).
  /// Only called on mobile/desktop (not web).
  Future<void> insertFromCloud(
    Map<String, dynamic> data,
    String docId,
    Repository repository,
  );

  /// Delete an entity from local storage (SQLite).
  /// Only called on mobile/desktop (not web).
  Future<void> deleteLocal(String docId, Repository repository);

  /// Optional: Post-pull hook for collection-specific logic
  /// (e.g., rebuilding inventory quantity cache after pulling movements).
  Future<void> onPullComplete(String storeId, Repository repository) async {}

  /// Optional: Custom reconciliation for inventory quantity after cloud sync.
  Future<void> reconcileAfterPull(
    Map<String, dynamic> data,
    String docId,
    Repository repository,
  ) async {}
}

