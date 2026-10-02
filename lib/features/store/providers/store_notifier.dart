import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:biztonic_pos/core/dependency_injection/providers.dart';
import 'package:biztonic_pos/features/auth/providers/auth_notifier.dart';
import 'package:biztonic_pos/features/auth/data/auth_repository.dart';
import 'package:biztonic_pos/features/store/data/store_repository.dart';
import 'package:biztonic_pos/features/subscriptions/data/subscription_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:biztonic_pos/services/offline_service.dart';
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

  Future<void> setActiveStoreId(String? storeId, {Store? initialStore}) async {
    if (storeId == state.activeStoreId &&
        state.activeStore != null &&
        initialStore == null) {
      return;
    }
    _storeSubscription?.cancel();

    try {
      state = state.copyWith(
        activeStoreId: storeId,
        activeStore: initialStore ?? state.activeStore,
        isLoading: state.activeStore == null && initialStore == null,
      );
      _syncService.setActiveStoreId(storeId);

      if (storeId != null) {
        final user = FirebaseAuth.instance.currentUser;

        // 1. Try initialStore or in-memory stores
        if (initialStore != null) {
          state = state.copyWith(activeStore: initialStore);
          await _storeRepo.pinStore(initialStore, uid: user?.uid);
        } else {
          final cachedStores =
              state.stores.where((s) => s.id == storeId).toList();
          if (cachedStores.isNotEmpty) {
            state = state.copyWith(activeStore: cachedStores.first);
            await _storeRepo.pinStore(state.activeStore!, uid: user?.uid);
          } else {
            // 2. Try Offline/Pinned Cache
            try {
              final pinned =
                  await OfflineService().getPinnedStore(uid: user?.uid);
              if (pinned != null &&
                  (pinned['id'] == storeId ||
                      (storeId.isNotEmpty && pinned['name'] != null))) {
                final pinnedStore =
                    Store.fromMap(pinned, pinned['id'] ?? storeId);
                state = state.copyWith(activeStore: pinnedStore);
              } else {
                // 3. Try user cached stores
                final userCached =
                    await _storeRepo.getCachedStores(uid: user?.uid);
                final match = userCached.where((s) => s.id == storeId).toList();
                if (match.isNotEmpty) {
                  state = state.copyWith(activeStore: match.first);
                }
              }
            } catch (cacheErr) {
              debugPrint('⚠️ StoreNotifier: Cache fallback failed: $cacheErr');
            }
          }
        }

        // Profile Sync via AuthRepository
        if (user != null) {
          try {
            await AuthRepository()
                .updateUserProfile(user.uid, {'storeId': storeId});
          } catch (e) {
            debugPrint('⚠️ StoreNotifier: updateUserProfile failed: $e');
          }
        }

        // Start Listener
        try {
          _storeSubscription = _storeRepo.storeSnapshots(storeId).listen((snap) {
            if (snap.exists && snap.data() != null) {
              final firestoreStore =
                  Store.fromMap(snap.data() as Map<String, dynamic>, snap.id);
              final cachedStore = state.activeStore;

              final updatedStore = firestoreStore.copyWith(
                address: (firestoreStore.address == null ||
                        firestoreStore.address!.isEmpty)
                    ? cachedStore?.address
                    : firestoreStore.address,
                phone: (firestoreStore.phone == null ||
                        firestoreStore.phone!.isEmpty)
                    ? cachedStore?.phone
                    : firestoreStore.phone,
                gstin: (firestoreStore.gstin == null ||
                        firestoreStore.gstin!.isEmpty)
                    ? cachedStore?.gstin
                    : firestoreStore.gstin,
              );

              state = state.copyWith(activeStore: updatedStore);
              _storeRepo.pinStore(updatedStore, uid: user?.uid);

              // Update in list
              final updatedList = state.stores
                  .map((s) => s.id == updatedStore.id ? updatedStore : s)
                  .toList();
              state = state.copyWith(stores: updatedList);
            }
          }, onError: (e) {
            debugPrint('⚠️ StoreNotifier: storeSnapshots stream error: $e');
          });
        } catch (e) {
          debugPrint('⚠️ StoreNotifier: storeSnapshots listen error: $e');
        }

        // Fetch Fresh
        try {
          final onlineStore = await _storeRepo.getStoreOnline(storeId);
          if (onlineStore != null) {
            final cachedStore = state.activeStore;
            final mergedStore = onlineStore.copyWith(
              address:
                  (onlineStore.address == null || onlineStore.address!.isEmpty)
                      ? cachedStore?.address
                      : onlineStore.address,
              phone: (onlineStore.phone == null || onlineStore.phone!.isEmpty)
                  ? cachedStore?.phone
                  : onlineStore.phone,
              gstin: (onlineStore.gstin == null || onlineStore.gstin!.isEmpty)
                  ? cachedStore?.gstin
                  : onlineStore.gstin,
            );
            state = state.copyWith(activeStore: mergedStore);
            await _storeRepo.pinStore(mergedStore, uid: user?.uid);
          }
        } catch (e) {
          debugPrint('⚠️ StoreNotifier: getStoreOnline failed: $e');
        }

        try {
          await fetchCounters();
        } catch (e) {
          debugPrint('⚠️ StoreNotifier: fetchCounters failed: $e');
        }
      } else {
        state = state.copyWith(clearActiveStore: true);
        _syncService.setActiveStoreId(null);
      }
    } catch (e) {
      debugPrint('⚠️ StoreNotifier: setActiveStoreId error: $e');
      state = state.copyWith(error: e.toString());
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

  Future<String> addStore(String name, String ownerEmail,
      {String? address, String? phone, String storeType = 'Restaurant'}) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = ownerEmail.toLowerCase().trim();

    state = state.copyWith(isLoading: true);
    try {
      final existingCount = state.stores.length;
      if (existingCount >= 1 && user != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final role = doc.data()?['role'] ?? 'Store Owner';
          if (role != 'Super Admin') {
            if (role == 'Store Owner') {
              throw Exception(
                  'Store Owners cannot add more than one store under their account. Multi-store management requires the Franchise Owner role and Franchise Add-on.');
            }
            if (role == 'Franchise Owner') {
              final hasAddon = state.stores.any((s) =>
                  s.addons.contains('franchise_management') ||
                  s.purchasedAddons.contains('franchise_management'));
              if (!hasAddon) {
                throw Exception(
                    'Multi-store feature requires the Franchise Add-on. Please purchase the Franchise Add-on from BizStore to add more stores.');
              }
            }
          }
        } catch (e) {
          if (e.toString().contains('Store Owners') ||
              e.toString().contains('Franchise Add-on')) {
            rethrow;
          }
        }
      }

      // Search for pending subscription
      final subRequest = await _subRepo.findPendingSubscription(email);

      String subscriptionPlan = 'Basic';
      List<String> addons = [];
      DateTime? expiry;
      String? foundRequestId;

      if (subRequest != null) {
        foundRequestId = subRequest['id'];
        subscriptionPlan = subRequest['planType'] ??
            subRequest['planName'] ??
            subRequest['plan'] ??
            'Standard';
        if (subscriptionPlan.toLowerCase() == 'basic' ||
            subscriptionPlan.isEmpty) {
          subscriptionPlan = 'Standard';
        }
        addons = List<String>.from(
            subRequest['selectedAddons'] ?? subRequest['addons'] ?? []);
        final duration =
            subRequest['durationInDays'] ?? subRequest['duration'] ?? 365;
        expiry = DateTime.now().add(Duration(days: duration));
      }

      final newStore = Store(
        id: '',
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

      final newStoreId = await _storeRepo.createStore(newStore);

      if (foundRequestId != null) {
        await _subRepo.approveSubscriptionRequest(
            foundRequestId, newStoreId, name);
        await _subRepo.addSubscriptionHistory(
            newStoreId, subscriptionPlan, expiry);
      }

      // Link to User via AuthRepository (upsert — doc may not exist yet)
      if (user != null) {
        if (user.email == ownerEmail) {
          await AuthRepository().upsertUserProfile(user.uid, {
            'storeId': newStoreId,
            'storeIds': FieldValue.arrayUnion([newStoreId]),
            'role': 'Store Owner'
          });
        } else {
          await AuthRepository().upsertUserProfile(user.uid, {
            'accessibleStoreIds': FieldValue.arrayUnion([newStoreId]),
          });
        }
      }

      await fetchStores();
      await setActiveStoreId(newStoreId);
      return newStoreId;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> updateStoreSettings(Store updatedStore) async {
    state = state.copyWith(isLoading: true);
    try {
      await _storeRepo.updateStore(updatedStore);
      state = state.copyWith(activeStore: updatedStore);
      final updatedList = state.stores
          .map((s) => s.id == updatedStore.id ? updatedStore : s)
          .toList();
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
    final newCounter =
        await _storeRepo.addCounter(state.activeStoreId!, counter);
    state = state.copyWith(counters: [...state.counters, newCounter]);
  }

  Future<void> updateCounter(CounterModel counter) async {
    if (state.activeStoreId == null) return;
    await _storeRepo.updateCounter(state.activeStoreId!, counter);
    final updated =
        state.counters.map((c) => c.id == counter.id ? counter : c).toList();
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
