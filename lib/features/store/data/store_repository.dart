import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:biztonic_pos/services/firestore_helper.dart';
import 'package:biztonic_pos/services/offline_service.dart';
import 'package:biztonic_pos/services/sync_service.dart';
import '../domain/entities/store.dart';
import '../domain/entities/counter_model.dart';

class StoreRepository {
  final FirebaseFirestore _db = getFirestore();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OfflineService _offlineService = OfflineService();
  final SyncService _syncService;

  StoreRepository(this._syncService);

  Stream<DocumentSnapshot> storeSnapshots(String storeId) {
    return _db.collection('stores').doc(storeId).snapshots();
  }

  Future<List<Store>> getCachedStores({String? uid}) async {
    final cachedData = await _offlineService.getCachedUserStores(uid: uid);
    return cachedData.map((m) => Store.fromMap(m, m['id'] ?? '')).toList();
  }

  Future<void> cacheStores(List<Store> stores, {String? uid}) async {
    await _offlineService.cacheUserStores(
      stores.map((s) => s.toMap()).toList(),
      uid: uid,
    );
  }

  Future<Store?> getStoreOnline(String storeId) async {
    final doc = await _db.collection('stores').doc(storeId).get();
    if (doc.exists) {
      return Store.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Future<List<Store>> fetchUserStoresOnline(User user) async {
    final Map<String, Store> uniqueStores = {};

    // 1. Fetch by UID
    try {
      final q0 = await _db.collection('stores').where('owner', isEqualTo: user.uid).get();
      for (var doc in q0.docs) {
        uniqueStores[doc.id] = Store.fromMap(doc.data(), doc.id);
      }
    } catch (e) {}

    // 2. Fetch by Email
    if (user.email != null) {
      try {
        final q1 = await _db.collection('stores').where('ownerEmail', isEqualTo: user.email).get();
        for (var doc in q1.docs) {
          uniqueStores[doc.id] = Store.fromMap(doc.data(), doc.id);
        }
      } catch (e) {}
    }

    // 3. Direct access linking
    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final List<dynamic> accessIds = data['accessibleStoreIds'] ?? [];
        final List<dynamic> legacyIds = data['storeIds'] ?? [];
        final singleStoreId = data['storeId'];
        final allIds = {...accessIds, ...legacyIds, if (singleStoreId != null) singleStoreId}
            .where((id) => id != null && id.toString().isNotEmpty)
            .toList();

        if (allIds.isNotEmpty) {
          final chunks = _chunkList(allIds, 10);
          for (var chunk in chunks) {
            final q2 = await _db.collection('stores').where(FieldPath.documentId, whereIn: chunk).get();
            for (var doc in q2.docs) {
              uniqueStores[doc.id] = Store.fromMap(doc.data(), doc.id);
            }
          }
        }
      }
    } catch (e) {}

    return uniqueStores.values.toList();
  }

  Future<void> updateStore(Store store) async {
    await _syncService.performLocalWrite(
      collection: 'stores',
      docId: store.id,
      data: store.toMap(),
      action: 'update',
      localCacheBox: 'cache_stores',
      refreshCounts: false,
    );
  }

  Future<void> deleteStore(String id) async {
    await _db.collection('stores').doc(id).delete();
  }

  Future<void> pinStore(Store store, {String? uid}) async {
    await _offlineService.pinStore(store.toMap(), uid: uid);
  }

  // --- Counters ---
  Future<List<CounterModel>> fetchCounters(String storeId) async {
    final snapshot = await _db.collection('stores').doc(storeId).collection('counters').get();
    return snapshot.docs.map((doc) => CounterModel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<CounterModel> addCounter(String storeId, CounterModel counter) async {
    final docRef = _db.collection('stores').doc(storeId).collection('counters').doc();
    final newCounter = CounterModel(
      id: docRef.id,
      name: counter.name,
      assignedPrinterId: counter.assignedPrinterId,
      printerDevice: counter.printerDevice,
      isCfdEnabled: counter.isCfdEnabled,
    );
    await docRef.set(newCounter.toMap());
    return newCounter;
  }

  Future<void> updateCounter(String storeId, CounterModel counter) async {
    await _db.collection('stores').doc(storeId).collection('counters').doc(counter.id).update(counter.toMap());
  }

  Future<void> deleteCounter(String storeId, String counterId) async {
    await _db.collection('stores').doc(storeId).collection('counters').doc(counterId).delete();
  }

  // --- Global Store Types ---
  Future<List<String>> fetchStoreTypes() async {
    final doc = await _db.collection('settings').doc('global').get();
    if (doc.exists && doc.data()?['store_types'] != null) {
      return List<String>.from(doc.data()!['store_types']);
    }
    return [];
  }

  Future<Map<String, dynamic>> fetchStoreTypeConfigs() async {
    final doc = await _db.collection('settings').doc('global').get();
    if (doc.exists && doc.data()?['store_type_configs'] != null) {
      return Map<String, dynamic>.from(doc.data()!['store_type_configs']);
    }
    return {};
  }

  Future<void> addStoreType(String type, {Map<String, dynamic>? initialConfig}) async {
    await _db.collection('settings').doc('global').set({
      'store_types': FieldValue.arrayUnion([type]),
      'store_type_configs': {
        type: initialConfig ?? {}
      }
    }, SetOptions(merge: true));
  }

  Future<void> deleteStoreType(String type) async {
    await _db.collection('settings').doc('global').update({
      'store_types': FieldValue.arrayRemove([type]),
      'store_type_configs.$type': FieldValue.delete()
    });
  }

  List<List<T>> _chunkList<T>(List<T> list, int size) {
    List<List<T>> chunks = [];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }
}
