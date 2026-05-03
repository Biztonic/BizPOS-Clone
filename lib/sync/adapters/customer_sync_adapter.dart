import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/sync/adapters/sync_adapter.dart';
import 'package:biztonic_pos/models/customer.dart';
import 'package:biztonic_pos/sync/registry/sync_collection_registry.dart';

/// Sync adapter for the `customers` collection.
class CustomerSyncAdapter extends SyncAdapter {
  @override
  String get collection => SyncCollectionRegistry.customers;

  @override
  Future<void> insertFromCloud(
    Map<String, dynamic> data,
    String docId,
    Repository repository,
  ) async {
    await repository.insertCustomer(Customer.fromMap(data, docId));
  }

  @override
  Future<void> deleteLocal(String docId, Repository repository) async {
    await repository.deleteCustomer(docId);
  }
}
