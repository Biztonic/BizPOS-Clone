import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/sync/adapters/sync_adapter.dart';
import 'package:biztonic_pos/sync/registry/sync_collection_registry.dart';

/// Sync adapter for the `settings` collection.
///
/// Settings use document-ID matching (not storeId field filtering)
/// and have a different SQLite table name (`store_settings`).
class SettingsSyncAdapter extends SyncAdapter {
  @override
  String get collection => SyncCollectionRegistry.settings;

  @override
  Query buildQuery(FirebaseFirestore db, String storeId, DateTime? lastSyncTime) {
    // Settings are matched by document ID = storeId
    return db.collection(collection).where(FieldPath.documentId, isEqualTo: storeId);
  }

  @override
  Future<void> insertFromCloud(
    Map<String, dynamic> data,
    String docId,
    Repository repository,
  ) async {
    await repository.insertStoreSettings(docId, data);
  }

  @override
  Future<void> deleteLocal(String docId, Repository repository) async {
    // Settings are not truly "deleted" — they're overwritten.
    // Soft-delete is handled at the sync engine level.
    try {
      await repository.deleteOfflineEntity('store_settings', docId);
    } catch (_) {}
  }
}
