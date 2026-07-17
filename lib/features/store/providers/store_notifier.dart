import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:biztonic_pos/core/dependency_injection/providers.dart';
import 'package:biztonic_pos/features/auth/providers/auth_notifier.dart';
import 'package:biztonic_pos/features/store/data/store_repository.dart';
import 'package:biztonic_pos/features/subscriptions/data/subscription_repository.dart';
import 'package:biztonic_pos/services/sync_service.dart';
import '../domain/entities/store.dart';
import '../domain/entities/settings.dart';
import '../domain/entities/counter_model.dart';
import 'store_state.dart';

part 'store_notifier.g.dart';

@riverpod
class StoreNotifier extends _$StoreNotifier {
  late StoreRepository _storeRepo;
  late SubscriptionRepository _subRepo;
  late SyncService _syncService;
  StreamSubscription<DocumentSnapshot>? _storeSubscription;

  @override
  StoreState build() {
    _storeRepo = ref.watch(storeFeatureRepositoryProvider);
    _subRepo = ref.watch(subscriptionRepositoryProvider);
    _syncService = ref.watch(syncServiceProvider);
    
    // Watch Auth state to trigger fetch when user logs in
    final authState = ref.watch(authNotifierProvider);
    if (authState.user != null) {
      // Use microtask to avoid side effects during build
      Future.microtask(() => fetchStores());
    }

    ref.onDispose(() {
      _storeSubscription?.cancel();
    });

    return StoreState();
  }

  Future<void> setActiveStoreId(String? storeId) async {
    if (storeId == state.activeStoreId) return;
    _storeSubscription?.cancel();
    
    try {
        state = state.copyWith(activeStoreId: storeId, isLoading: true);
        _syncService.setActiveStoreId(storeId);
        
        if (storeId != null) {
           final user = FirebaseAuth.instance.currentUser;
           
           // Aggressive Profile Sync (legacy logic)
           if (user != null) {
             FirebaseFirestore.instance.collection('users').doc(user.uid).set({'storeId': storeId}, SetOptions(merge: true));
           }

           // Try Cache First
           final cachedStores = state.stores.where((s) => s.id == storeId).toList();
           if (cachedStores.isNotEmpty) {
              state = state.copyWith(activeStore: cachedStores.first);
              await _storeRepo.pinStore(state.activeStore!, uid: user?.uid);
           }
           
           // Start Listener
           _storeSubscription = _storeRepo.storeSnapshots(storeId).listen((snap) {
              if (snap.exists) {
                 final firestoreStore = Store.fromMap(snap.data() as Map<String, dynamic>, snap.id);
                 final cachedStore = state.activeStore;
                 
                 final updatedStore = firestoreStore.copyWith(
                    address: (firestoreStore.address == null || firestoreStore.address!.isEmpty) ? cachedStore?.address : firestoreStore.address,
                    phone: (firestoreStore.phone == null || firestoreStore.phone!.isEmpty) ? cachedStore?.phone : firestoreStore.phone,
                    gstin: (firestoreStore.gstin == null || firestoreStore.gstin!.isEmpty) ? cachedStore?.gstin : firestoreStore.gstin,
                 );

                 state = state.copyWith(activeStore: updatedStore);
                 _storeRepo.pinStore(updatedStore, uid: user?.uid);
                 
                 // Update in list
                 final updatedList = state.stores.map((s) => s.id == updatedStore.id ? updatedStore : s).toList();
                 state = state.copyWith(stores: updatedList);
              }
           });
           
           // Fetch Fresh
           final onlineStore = await _storeRepo.getStoreOnline(storeId);
           if (onlineStore != null) {
              final cachedStore = state.activeStore;
              final mergedStore = onlineStore.copyWith(
                address: (onlineStore.address == null || onlineStore.address!.isEmpty) ? cachedStore?.address : onlineStore.address,
                phone: (onlineStore.phone == null || onlineStore.phone!.isEmpty) ? cachedStore?.phone : onlineStore.phone,
                gstin: (onlineStore.gstin == null || onlineStore.gstin!.isEmpty) ? cachedStore?.gstin : onlineStore.gstin,
              );
              state = state.copyWith(activeStore: mergedStore);
              await _storeRepo.pinStore(mergedStore, uid: user?.uid);
           }
           
           await fetchCounters();
        } else {
           state = state.copyWith(clearActiveStore: true);
           _syncService.setActiveStoreId(null);
        }
    } finally {
        state = state.copyWith(isLoading: false);
    }
  }

  Future<void> fetchStores({bool isSuperAdmin = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    state = state.copyWith(isLoading: true);
    try {
      if (isSuperAdmin) {
        // Not implemented in repo yet, but could be
      } else {
        final onlineStores = await _storeRepo.fetchUserStoresOnline(user);
        if (onlineStores.isNotEmpty) {
           state = state.copyWith(stores: onlineStores);
           await _storeRepo.cacheStores(onlineStores, uid: user.uid);
        } else {
           // Fallback to cache if online fails/empty
           final cached = await _storeRepo.getCachedStores(uid: user.uid);
           state = state.copyWith(stores: cached);
        }
      }
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<String> addStore(String name, String ownerEmail, {String? address, String? phone, String storeType = 'Restaurant'}) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = ownerEmail.toLowerCase().trim();

    state = state.copyWith(isLoading: true);
    try {
      // Search for pending subscription
      final subRequest = await _subRepo.findPendingSubscription(email);
      
      String subscriptionPlan = 'Basic';
      List<String> addons = [];
      DateTime? expiry;
      String? foundRequestId;

      if (subRequest != null) {
        foundRequestId = subRequest['id'];
        subscriptionPlan = subRequest['planType'] ?? subRequest['planName'] ?? subRequest['plan'] ?? 'Standard';
        if (subscriptionPlan.toLowerCase() == 'basic' || subscriptionPlan.isEmpty) {
          subscriptionPlan = 'Standard';
        }
        addons = List<String>.from(subRequest['selectedAddons'] ?? subRequest['addons'] ?? []);
        final duration = subRequest['durationInDays'] ?? subRequest['duration'] ?? 365;
        expiry = DateTime.now().add(Duration(days: duration));
      }

      final docRef = FirebaseFirestore.instance.collection('stores').doc();
      final newStore = Store(
        id: docRef.id,
        name: name,
        owner: user?.uid ?? name,
        ownerEmail: email,
        status: 'Active',
        storeType: storeType,
        subscriptionPlan: subscriptionPlan,
        addons: addons,
        purchasedAddons: addons,
        subscriptionExpiry: expiry,
        address: address,
        phone: phone,
        receipt: ReceiptSettings(),
        payment: PaymentSettings(),
        kds: KdsSettings(),
      );

      await docRef.set(newStore.toMap());

      if (foundRequestId != null) {
        await _subRepo.approveSubscriptionRequest(foundRequestId, docRef.id, name);
        await _subRepo.addSubscriptionHistory(docRef.id, subscriptionPlan, expiry);
      }

      // Link to User
      if (user != null) {
        if (user.email == ownerEmail) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'storeId': docRef.id,
            'storeIds': FieldValue.arrayUnion([docRef.id]),
            'role': 'Store Owner'
          }, SetOptions(merge: true));
        } else {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'accessibleStoreIds': FieldValue.arrayUnion([docRef.id]),
          }, SetOptions(merge: true));
        }
      }

      await fetchStores();
      await setActiveStoreId(docRef.id);
      return docRef.id;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> updateStoreSettings(Store updatedStore) async {
    state = state.copyWith(isLoading: true);
    try {
      await _storeRepo.updateStore(updatedStore);
      state = state.copyWith(activeStore: updatedStore);
      final updatedList = state.stores.map((s) => s.id == updatedStore.id ? updatedStore : s).toList();
      state = state.copyWith(stores: updatedList);
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // --- Counters ---
  Future<void> fetchCounters() async {
    if (state.activeStoreId == null) return;
    final counters = await _storeRepo.fetchCounters(state.activeStoreId!);
    state = state.copyWith(counters: counters);
  }

  Future<void> addCounter(CounterModel counter) async {
    if (state.activeStoreId == null) return;
    final newCounter = await _storeRepo.addCounter(state.activeStoreId!, counter);
    state = state.copyWith(counters: [...state.counters, newCounter]);
  }

  Future<void> updateCounter(CounterModel counter) async {
    if (state.activeStoreId == null) return;
    await _storeRepo.updateCounter(state.activeStoreId!, counter);
    final updated = state.counters.map((c) => c.id == counter.id ? counter : c).toList();
    state = state.copyWith(counters: updated);
  }

  Future<void> removeCounter(String counterId) async {
    if (state.activeStoreId == null) return;
    await _storeRepo.deleteCounter(state.activeStoreId!, counterId);
    final updated = state.counters.where((c) => c.id != counterId).toList();
    state = state.copyWith(counters: updated);
  }

  // --- Global Settings ---
  Future<List<String>> fetchStoreTypes() async {
    return await _storeRepo.fetchStoreTypes();
  }

  Future<Map<String, dynamic>> fetchStoreTypeConfigs() async {
    return await _storeRepo.fetchStoreTypeConfigs();
  }
}
