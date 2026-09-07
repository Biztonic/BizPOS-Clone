import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/sync/adapters/sync_adapter.dart';
import 'package:biztonic_pos/models/user_profile.dart';
import 'package:biztonic_pos/sync/registry/sync_collection_registry.dart';

/// Sync adapter for the `employees` collection.
class EmployeeSyncAdapter extends SyncAdapter {
  @override
  String get collection => SyncCollectionRegistry.employees;

  @override
  Query buildQuery(FirebaseFirestore db, String storeId, DateTime? lastSyncTime) {
    // Cloud employees are stored in 'users' collection
    Query query = db.collection(SyncCollectionRegistry.users).where('storeId', isEqualTo: storeId);
    if (lastSyncTime != null) {
      query = query.where('updatedAt', isGreaterThan: Timestamp.fromDate(lastSyncTime));
    }
    return query;
  }

  @override
  Future<void> insertFromCloud(
    Map<String, dynamic> data,
    String docId,
    Repository repository,
  ) async {
    await repository.insertEmployee(UserProfile.fromMap(data, docId));
  }

  @override
  Future<void> deleteLocal(String docId, Repository repository) async {
    await repository.deleteEmployee(docId);
  }
}
