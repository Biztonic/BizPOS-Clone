// ignore_for_file: unused_field
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/services/firestore_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:biztonic_pos/models/store.dart';
import 'package:biztonic_pos/services/offline_service.dart';
import 'package:biztonic_pos/models/settings.dart';
import 'package:biztonic_pos/utils/theme.dart';
import 'package:biztonic_pos/models/counter_model.dart';
import 'package:biztonic_pos/models/role_model.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/services/sync_service.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:intl/intl.dart';

Map<String, dynamic> _decodeJsonBackup(String json) => jsonDecode(json) as Map<String, dynamic>;

class StoreProvider with ChangeNotifier {
  late final FirebaseFirestore _db = getFirestore(); // Use 'bizpos' database
  final FirebaseAuth? _auth;
  final Repository _repository = Repository();
  final SyncService _syncService;

  // State
  String? _activeStoreId;
  Store? _activeStore;
  List<Store> _stores = [];

  
  // Theme State
  AppColorTheme _currentTheme = AppColorTheme.blue;
  bool _isDarkMode = false;
  int? _customThemeColor;
  UIStyle _uiStyle = UIStyle.standard;

  // Loading State
  bool _isLoading = false;

  StreamSubscription<DocumentSnapshot>? _storeSubscription;

  // Getters
  String? get activeStoreId => _activeStoreId;
  Store? get activeStore => _activeStore;
  List<Store> get stores => _stores;

  
  AppColorTheme get currentTheme => _currentTheme;
  bool get isDarkMode => _isDarkMode;
  int? get customThemeColor => _customThemeColor;
  UIStyle get uiStyle => _uiStyle;
  bool get isLoading => _isLoading;
  
  // Exposed Services & Auth
  SyncService get syncService => _syncService;
  User? get userProfile => _auth?.currentUser;
  
  StoreSettings? get storeSettings {
     if (_activeStore == null) return null;
     // Convert Store to StoreSettings
     return StoreSettings(
       id: _activeStore!.id,
       storeName: _activeStore!.name,
       address: _activeStore!.address,
       phone: _activeStore!.phone,
       logoUrl: _activeStore!.image,
       receipt: _activeStore!.receipt,
       modules: ModuleSettings(), // Default/Unknown? Or need to add modules to Store? Let's use default.
       dashboard: DashboardSettings(), // Default
       syncSettings: SyncSettings(), // Default
       counters: _counters.map((c) => c.name).toList(), // Map from local counters list
       kds: _activeStore!.kds,
       payment: _activeStore!.payment,
     );
  }

  StoreProvider(this._syncService, {FirebaseAuth? auth}) : _auth = auth ?? _getDefaultAuth() {
    _loadBackupSettings();
  }

  static FirebaseAuth? _getDefaultAuth() {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  // --- INIT & SESSION ---

  Future<void> setActiveStoreId(String? storeId) async {
    if (storeId == _activeStoreId) return;
    _storeSubscription?.cancel();
    
    try {
        _activeStoreId = storeId;
        _isLoading = true;
        _syncService.setActiveStoreId(storeId);
        notifyListeners();
        
        if (storeId != null) {
           // NEW: Aggressive Profile Sync
           final user = _auth?.currentUser;
           if (user != null) {
             try {
                await _db.collection('users').doc(user.uid).set({'storeId': storeId}, SetOptions(merge: true));
             } catch (e) { /* Error ignored */ }
           }

            // Try Cache First
            bool pinned = false;
            if (Hive.isBoxOpen('cache_stores')) {
               final map = Hive.box('cache_stores').get(storeId);
               if (map != null) {
                  _activeStore = Store.fromMap(_deepSanitize(map as Map), storeId);
                  await OfflineService().pinStore(_activeStore!.toMap(), uid: user?.uid);
                  pinned = true;
                  notifyListeners();
               }
            }
            
            // Fallback: If not in Hive yet (e.g. just created), use in-memory list
            if (!pinned) {
               final matchingStores = _stores.where((s) => s.id == storeId).toList();
               if (matchingStores.isNotEmpty) {
                  _activeStore = matchingStores.first;
                  await OfflineService().pinStore(_activeStore!.toMap(), uid: user?.uid);
                  notifyListeners();
               }
            }
           
           // Start Listener for Real-time Updates (Unified Source)
           _storeSubscription = _db.collection('stores').doc(storeId).snapshots().listen((snap) {
              if (snap.exists) {
                 final data = snap.data()!;
                 final firestoreStore = Store.fromMap(data, snap.id);
                 final cachedStore = _activeStore;
                 
                 // Merge Logic: Preserve locally-cached address/phone if Firestore is missing them
                 _activeStore = firestoreStore.copyWith(
                    address: (firestoreStore.address == null || firestoreStore.address!.isEmpty) ? cachedStore?.address : firestoreStore.address,
                    phone: (firestoreStore.phone == null || firestoreStore.phone!.isEmpty) ? cachedStore?.phone : firestoreStore.phone,
                    gstin: (firestoreStore.gstin == null || firestoreStore.gstin!.isEmpty) ? cachedStore?.gstin : firestoreStore.gstin,
                 );

                 if (Hive.isBoxOpen('cache_stores')) {
                    Hive.box('cache_stores').put(storeId, _activeStore!.toMap());
                 }
                 OfflineService().pinStore(_activeStore!.toMap(), uid: _auth?.currentUser?.uid);
                 notifyListeners();
              }
           }, onError: (e) {
              debugPrint('⚠️ StoreProvider: Store Snapshot Listener Error: $e');
              // Don't clear local state on listener error (often connectivity related)
           });
           
           // Fetch Fresh (Immediate check)
           try {
             final doc = await _db.collection('stores').doc(storeId).get();
             if (doc.exists) {
                final firestoreStore = Store.fromMap(doc.data()!, doc.id);
                 final cachedStore = _activeStore;
                 _activeStore = firestoreStore.copyWith(
                    address: (firestoreStore.address == null || firestoreStore.address!.isEmpty) ? cachedStore?.address : firestoreStore.address,
                    phone: (firestoreStore.phone == null || firestoreStore.phone!.isEmpty) ? cachedStore?.phone : firestoreStore.phone,
                    gstin: (firestoreStore.gstin == null || firestoreStore.gstin!.isEmpty) ? cachedStore?.gstin : firestoreStore.gstin,
                 );
                _syncService.setActiveStoreId(storeId); 
                
                if (Hive.isBoxOpen('cache_stores')) {
                    Hive.box('cache_stores').put(storeId, _activeStore!.toMap());
                }
                await OfflineService().pinStore(_activeStore!.toMap(), uid: _auth?.currentUser?.uid);
             }
           } catch (e) {
             debugPrint('⚠️ StoreProvider: Fresh store fetch failed (likely offline): $e');
             // If we already have _activeStore from cache, we are good.
           }

           
           await _fetchUserStores();
        } else {
           _activeStore = null;
           _syncService.setActiveStoreId(null);
        }
    } finally {
       _isLoading = false;
       notifyListeners();
    }
  }

  void clearStores() {
    _stores = [];
    _activeStoreId = null;
    _activeStore = null;
    notifyListeners();
  }

  Future<void> _fetchUserStores() async {
    final user = _auth?.currentUser;
    
    // NEW: Load from Cache First (for offline accessibility, uid-isolated)
    final cachedStores = await OfflineService().getCachedUserStores(uid: user?.uid);
    if (cachedStores.isNotEmpty) {
       _stores = cachedStores.map((m) => Store.fromMap(m, m['id'] ?? '')).toList();
       debugPrint('🏬 StoreProvider: Loaded ${_stores.length} stores from local cache (uid: ${user?.uid}).');
       notifyListeners();
    }

    if (user == null) {
      debugPrint('⚠️ StoreProvider: No current user for store fetch.');
      return;
    }
    
    try {
      final Map<String, Store> uniqueStores = {};
      debugPrint('🏬 StoreProvider: Fetching fresh stores for ${user.uid}');

      // 1. Fetch by UID
      try {
        final q0 = await _db.collection('stores').where('owner', isEqualTo: user.uid).get();
        for (var doc in q0.docs) {
          uniqueStores[doc.id] = Store.fromMap(doc.data(), doc.id);
        }
      } catch (e) {
        debugPrint('⚠️ StoreProvider: UID Query Failed/Timeout: $e');
      }

      // 2. Fetch by Email
      if (user.email != null) {
        try {
          final q1 = await _db.collection('stores').where('ownerEmail', isEqualTo: user.email).get();
          for (var doc in q1.docs) {
            uniqueStores[doc.id] = Store.fromMap(doc.data(), doc.id);
          }
        } catch (e) {
          debugPrint('⚠️ StoreProvider: Email Query Failed/Timeout: $e');
        }
      }

      // 3. Direct access linking
      try {
        final userDoc = await _db.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
           final data = userDoc.data()!;
           final List<dynamic> accessIds = data['accessibleStoreIds'] ?? [];
           final List<dynamic> legacyIds = data['storeIds'] ?? [];
           final singleStoreId = data['storeId'];
           final allIds = {...accessIds, ...legacyIds, if (singleStoreId != null) singleStoreId}.where((id) => id != null && id.toString().isNotEmpty).toList();

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
      } catch (e) {
        debugPrint('⚠️ StoreProvider: ID-based Query Failed/Timeout: $e');
      }

      if (uniqueStores.isNotEmpty) {
         _stores = uniqueStores.values.toList();
         debugPrint('🏁 StoreProvider: Online fetch successful: ${_stores.length} stores');
         
         // Cache the results for next offline session (uid-isolated)
         await OfflineService().cacheUserStores(_stores.map((s) => s.toMap()).toList(), uid: user.uid);
         notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ StoreProvider: Error in _fetchUserStores: $e');
    }
  }


  List<List<T>> _chunkList<T>(List<T> list, int size) {
    List<List<T>> chunks = [];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }

  Future<void> fetchStores({bool isSuperAdmin = false}) async {
      final user = _auth?.currentUser;
      if (user == null) {
        clearStores();
        return;
      }

      try {
         _isLoading = true;
         notifyListeners();

         if (isSuperAdmin) {
           // Admin view: Fetch all stores
           final q = await _db.collection('stores').get();
           _stores = q.docs.map((d) => Store.fromMap(d.data(), d.id)).toList();
           notifyListeners();
           return;
         } else {
           // Regular user: Only show stores they own
           await _fetchUserStores();
         }
      } finally {
          _isLoading = false;
          notifyListeners();
      }
  }

  Future<void> deleteStore(String id) async {
      await _db.collection('stores').doc(id).delete();
      _stores.removeWhere((s) => s.id == id);
      if (_activeStoreId == id) {
          _activeStoreId = null;
          _activeStore = null;
      }
      notifyListeners();
  }

  // --- ACTIONS ---

  Future<String> addStore(String name, String ownerEmail, {String? address, String? phone}) async {
      final user = _auth?.currentUser;
      final email = ownerEmail.toLowerCase().trim();

      // 1. AVOID DUPLICATES: Check if a store with this name already exists for this owner
      try {
        final existingQuery = await _db.collection('stores')
            .where('ownerEmail', isEqualTo: email)
            .where('name', isEqualTo: name.trim())
            .get();
            
        if (existingQuery.docs.isNotEmpty) {
           final existingId = existingQuery.docs.first.id;
           debugPrint('🏬 StoreProvider: Store "$name" already exists ($existingId). Skipping creation.');
           // Ensure it's linked if not already (safeguard)
           if (user != null && user.email == email) {
              await _db.collection('users').doc(user.uid).set({
                 'storeIds': FieldValue.arrayUnion([existingId]),
              }, SetOptions(merge: true));
           }
           await fetchStores(); // Refresh local list
           return existingId;
        }
      } catch (e) {
        debugPrint('⚠️ StoreProvider: Existence check failed: $e');
      }
      
      // --- AUTO-ASSIGN SUBSCRIPTION FROM SALES APP ---
      String subscriptionPlan = 'Basic';
      List<String> addons = [];
      DateTime? expiry;
      String? foundRequestId;

      try {
        final emailList = {email.trim(), email.toLowerCase().trim()}.toList();
        debugPrint('🔍 StoreProvider: Searching for pending subscriptions for $emailList...');

        // 1. PRIORITIZE 'subscription_requests' (Most recent purchases from Sales App)
        QuerySnapshot? subQuery;
        // Expanded list of fields where Sales App might store the email
        final searchFields = ['ownerEmail', 'userId', 'customerEmail', 'email', 'customer_email', 'buyer_email', 'contactEmail'];
        
        for (final field in searchFields) {
          final q = await _db.collection('subscription_requests')
              .where(field, whereIn: emailList)
              .get();
              
          // Filter 'PENDING' locally to avoid requiring composite Firestore indexes
          final pendingDocs = q.docs.where((doc) {
             final data = doc.data();
             return data['status'] == 'PENDING';
          }).toList();
          
          if (pendingDocs.isNotEmpty) {
            // Reconstruct a pseudo QuerySnapshot or just assign the first pending doc
            subQuery = q; // We'll just pass the whole query result and filter it below
            debugPrint('🎯 StoreProvider: Found pending subscription via $field');
            break;
          }
        }

        if (subQuery != null && subQuery.docs.isNotEmpty) {
           // Filter to only PENDING ones locally
           final docs = subQuery.docs.where((doc) {
               final data = doc.data() as Map<String, dynamic>;
               return data['status'] == 'PENDING';
           }).toList();
           
           if (docs.isNotEmpty) {
             // Sort by createdAt descending to get the latest purchase
             try {
               docs.sort((a, b) {
                 final tA = a.get('createdAt');
                 final tB = b.get('createdAt');
                 if (tA == null || tB == null) return 0;
                 return (tB as dynamic).compareTo(tA);
               });
             } catch (e) {
               debugPrint('⚠️ StoreProvider: Failed to sort subscription requests: $e');
             }
             
             final subDoc = docs.first;
             final subData = subDoc.data() as Map<String, dynamic>;
             foundRequestId = subDoc.id;
           
           // Robust plan name extraction
           subscriptionPlan = subData['planType'] ?? subData['planName'] ?? subData['plan'] ?? subData['subscription_plan'] ?? 'Standard';
           
           // Ensure it's not defaulted to 'Basic' if we found a request
           if (subscriptionPlan.toLowerCase() == 'basic' || subscriptionPlan.isEmpty) {
              subscriptionPlan = 'Standard'; 
           }

           addons = List<String>.from(subData['selectedAddons'] ?? subData['addons'] ?? subData['purchased_addons'] ?? []);
           
           final duration = subData['durationInDays'] ?? subData['duration'] ?? 365; // Default to 1 year for pre-paid if unspecified
           expiry = DateTime.now().add(Duration(days: duration));
           debugPrint('🎫 StoreProvider: Detected pre-paid subscription ($subscriptionPlan, Addons: ${addons.length}) for $email');
           }
        }

        // 2. FALLBACK: Check user profile directly (Legacy or pre-synced data)
        if (expiry == null) {
          debugPrint('🔍 StoreProvider: No pending requests. Checking user profiles...');
          Map<String, dynamic>? userData;
          
          if (user != null) {
            final userDoc = await _db.collection('users').doc(user.uid).get();
            userData = userDoc.data();
          }
          
          // Fallback: Check legacy email-keyed docs
          if (userData == null || (!userData.containsKey('subscriptionPlan') && !userData.containsKey('planType') && !userData.containsKey('plan'))) {
             final legacyDoc = await _db.collection('users').doc(email).get();
             if (legacyDoc.exists) {
                userData = legacyDoc.data();
             } else {
                final legacyDocLower = await _db.collection('users').doc(email.toLowerCase().trim()).get();
                if (legacyDocLower.exists) {
                   userData = legacyDocLower.data();
                }
             }
          }

          if (userData != null) {
            final possiblePlan = userData['subscriptionPlan'] ?? userData['planType'] ?? userData['plan'] ?? userData['subscription_plan'];
            if (possiblePlan != null) {
              subscriptionPlan = possiblePlan.toString();
              addons = List<String>.from(userData['addons'] ?? userData['selectedAddons'] ?? userData['purchased_addons'] ?? []);
              
              final expiryVal = userData['subscriptionExpiry'] ?? userData['expiryDate'] ?? userData['expiry'];
              if (expiryVal != null) {
                expiry = _parseDateTime(expiryVal);
              } else {
                final duration = userData['durationInDays'] ?? userData['duration'] ?? 365;
                expiry = DateTime.now().add(Duration(days: duration));
              }
              debugPrint('🎫 StoreProvider: Found subscription ($subscriptionPlan) in user data');
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ StoreProvider: Subscription check failed: $e');
      }

      final docRef = _db.collection('stores').doc();
      final newStore = Store(
         id: docRef.id,
         name: name,
         owner: user?.uid ?? name,
         ownerEmail: email,
         status: 'Active',
         storeType: 'Restaurant',
         subscriptionPlan: subscriptionPlan,
         addons: addons,
         purchasedAddons: addons, // Sync purchased addons
         subscriptionExpiry: expiry,
         address: address, 
         phone: phone, 
         receipt: ReceiptSettings(),
         payment: PaymentSettings(),
         kds: KdsSettings(), 
      );
      
      await docRef.set(newStore.toMap());

      // Consume the subscription request if it was found
      try {
          if (foundRequestId != null) {
              await _db.collection('subscription_requests').doc(foundRequestId).update({
                  'status': 'APPROVED',
                  'storeId': docRef.id,
                  'storeName': name,
                  'approvedAt': FieldValue.serverTimestamp(),
              });
              
              // Also add to subscription_history for record keeping
              await _db.collection('stores').doc(docRef.id).collection('subscription_history').add({
                  'planName': subscriptionPlan,
                  'startDate': FieldValue.serverTimestamp(),
                  'endDate': expiry,
                  'status': 'Active',
                  'amount': 0.0, // Pre-paid
                  'paymentId': 'SALES_APP_PREPAID',
              });
          }
      } catch (e) {
         debugPrint('⚠️ StoreProvider: Error consuming subscription request: $e');
      }

      // LINK TO USER
      if (user != null) {
          // 1. If Creator is the Owner
          if (user.email == ownerEmail) {
              await _db.collection('users').doc(user.uid).set({
                 'storeId': docRef.id,
                 'storeIds': FieldValue.arrayUnion([docRef.id]),
                 'role': 'Store Owner'
              }, SetOptions(merge: true));
          } else {
              // 2. Admin creating for someone else
              // Link to the Admin so they can manage/onboard it
              await _db.collection('users').doc(user.uid).set({
                 'accessibleStoreIds': FieldValue.arrayUnion([docRef.id]),
              }, SetOptions(merge: true));

              // 3. Try to find the actual owner and link them
              try {
                final ownerQuery = await _db.collection('users').where('email', isEqualTo: ownerEmail).get();
                if (ownerQuery.docs.isNotEmpty) {
                    final ownerDoc = ownerQuery.docs.first;
                    await ownerDoc.reference.update({
                       'storeId': docRef.id,
                       'storeIds': FieldValue.arrayUnion([docRef.id]),
                       'role': 'Store Owner'
                    });
                }
              } catch (e) { /* Error ignored */ }
          }
      }

      // Optimistic update to stores list to prevent redirect loops in router
      if (!_stores.any((s) => s.id == newStore.id)) {
        _stores.add(newStore);
        // NEW: Cache immediately to prevent data loss on restart for new users
        await OfflineService().cacheUserStores(_stores.map((s) => s.toMap()).toList(), uid: user?.uid);
        notifyListeners();
      }

      await setActiveStoreId(docRef.id);
      return docRef.id;
  }

  Future<void> updateStoreSettings(Store updatedStore) async {
    if (_activeStoreId == null) return;
    
    // 1. Sync Down through SyncService (updates cloud & local cache)
    await _syncService.performLocalWrite(
      collection: 'stores',
      docId: _activeStoreId!,
      data: updatedStore.toMap(),
      action: 'update',
      localCacheBox: 'cache_stores',
      refreshCounts: false
    );
    
    // 2. Update Local State
    _activeStore = updatedStore;
    
    // 3. Update Stores list if present
    final idx = _stores.indexWhere((s) => s.id == updatedStore.id);
    if (idx != -1) {
        _stores[idx] = updatedStore;
    }
    
    notifyListeners();
  }
  
  Future<void> updateStoreStatus(String id, String status) async {
      await _db.collection('stores').doc(id).update({'status': status});
      if (_activeStoreId == id && _activeStore != null) {
          _activeStore = _activeStore!.copyWith(status: status);
          notifyListeners();
      }
      // Update local list
      final idx = _stores.indexWhere((s) => s.id == id);
      if (idx != -1) {
          _stores[idx] = _stores[idx].copyWith(status: status);
          notifyListeners();
      }
  }

  
  Future<void> updateSettingsConfig(StoreSettings newSettings) async {
      if (_activeStoreId == null) return;
      
      // Update local (Optimistic)
      if (_activeStore != null) {
          _activeStore = _activeStore!.copyWith(
            receipt: newSettings.receipt,
            payment: newSettings.payment,
            kds: newSettings.kds, // Added
          );
          notifyListeners();
      }
      
      // Sync
      await _syncService.performLocalWrite(
        collection: 'settings',
        docId: _activeStoreId!,
        data: newSettings.toMap(), // No need for nested 'settings' key if using root collection
        action: 'update',
        localCacheBox: 'cache_settings',
        refreshCounts: false
      );
  }

  Future<void> updateStoreAddons(String storeId, List<String> newAddons) async {
      // 1. Update Local State (Optimistic)
      final index = _stores.indexWhere((s) => s.id == storeId);
      if (index != -1) {
          _stores[index] = _stores[index].copyWith(addons: newAddons);
      }
      if (_activeStoreId == storeId && _activeStore != null) {
          _activeStore = _activeStore!.copyWith(addons: newAddons);
      }
      notifyListeners();

      // 2. Persist to Hive
      if (Hive.isBoxOpen('cache_stores')) {
          final store = index != -1 ? _stores[index] : _activeStore;
          if (store != null) {
             Hive.box('cache_stores').put(storeId, store.toMap());
          }
      }

      // 3. Update Firestore
      await _db.collection('stores').doc(storeId).update({
        'addons': newAddons,
        'updatedAt': FieldValue.serverTimestamp(),
      });
  }

  Future<void> updateStoreCustomRoles(List<String> roles) async {
      if (_activeStoreId == null || _activeStore == null) return;
      
      _activeStore = _activeStore!.copyWith(customRoles: roles);
      notifyListeners();

      if (Hive.isBoxOpen('cache_stores')) {
          Hive.box('cache_stores').put(_activeStoreId, _activeStore!.toMap());
      }

      await _db.collection('stores').doc(_activeStoreId).update({
        'customRoles': roles,
        'updatedAt': FieldValue.serverTimestamp(),
      });
  }

  Future<void> saveStoreRolesAndPermissions(List<String> roles, Map<String, Map<String, bool>> permissions) async {
      if (_activeStoreId == null || _activeStore == null) return;
      
      _activeStore = _activeStore!.copyWith(
        customRoles: roles,
        rolePermissions: permissions
      );
      notifyListeners();

      if (Hive.isBoxOpen('cache_stores')) {
          Hive.box('cache_stores').put(_activeStoreId, _activeStore!.toMap());
      }

      await _db.collection('stores').doc(_activeStoreId).update({
        'customRoles': roles,
        'rolePermissions': permissions,
        'updatedAt': FieldValue.serverTimestamp(),
      });
  }

  // --- THEME ---

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    // Persist to Hive 'settings' box
    if (Hive.isBoxOpen('settings')) {
       Hive.box('settings').put('darkMode', _isDarkMode);
    }
  }

  void setAppTheme(AppColorTheme theme) {
    _currentTheme = theme;
    _customThemeColor = null;
    notifyListeners();
    if (Hive.isBoxOpen('settings')) {
       Hive.box('settings').put('theme', theme.index);
    }
  }
  
  void setUIStyle(UIStyle style) {
    _uiStyle = style;
    notifyListeners();
    if (Hive.isBoxOpen('settings')) {
       Hive.box('settings').put('uiStyle', style.index);
    }
  }
  
  // Helpers to load prefs
  Future<void> loadUserPreferences() async {
     if (!Hive.isBoxOpen('settings')) return;
     final box = Hive.box('settings');
     
     _isDarkMode = box.get('darkMode', defaultValue: false);
     _uiStyle = UIStyle.values[box.get('uiStyle', defaultValue: 0)];
     final themeIdx = box.get('theme', defaultValue: 0);
     if (themeIdx < AppColorTheme.values.length) {
        _currentTheme = AppColorTheme.values[themeIdx];
     }
     await _loadBackupSettings();
     notifyListeners();
  }

  // --- SUBSCRIPTION HELPERS ---
  
  bool canPerformAction(String action, {int? ordersCount}) {
     // Always Allow
     return true;
  }
  
  String getBlockReason(String action) {
     return "";
  }

  // --- COUNTERS ---
  List<CounterModel> _counters = [];
  List<CounterModel> get counters => _counters;

  Future<void> fetchCounters() async {
    if (_activeStoreId == null) return;
    try {
      final snapshot = await _db
          .collection('stores')
          .doc(_activeStoreId)
          .collection('counters')
          .get();
      _counters = snapshot.docs
          .map((doc) => CounterModel.fromMap(doc.data(), doc.id))
          .toList();
      notifyListeners();
    } catch (e) { /* Error ignored */ }
  }

  Future<void> addStoreCounter(CounterModel counter) async {
    if (_activeStoreId == null) return;
    try {
      final docRef = _db
          .collection('stores')
          .doc(_activeStoreId)
          .collection('counters')
          .doc(); // Auto-ID
      
      final newCounter = CounterModel(
        id: docRef.id, 
        name: counter.name,
        assignedPrinterId: counter.assignedPrinterId,
        printerDevice: counter.printerDevice,
        isCfdEnabled: counter.isCfdEnabled
      );

      await docRef.set(newCounter.toMap());
      _counters.add(newCounter);
      notifyListeners();
    } catch (e) {

      rethrow;
    }
  }

  Future<void> updateCounter(CounterModel counter) async {
    if (_activeStoreId == null) return;
    try {
       await _db
          .collection('stores')
          .doc(_activeStoreId)
          .collection('counters')
          .doc(counter.id)
          .update(counter.toMap());
          
       final index = _counters.indexWhere((c) => c.id == counter.id);
       if (index != -1) {
         _counters[index] = counter;
         notifyListeners();
       }
    } catch (e) {

       rethrow;
    }
  }

  Future<void> removeStoreCounter(String id) async {
     await deleteStoreCounter(id);
  }

  Future<void> deleteStoreCounter(String id) async {
    if (_activeStoreId == null) return;
    try {
      await _db
          .collection('stores')
          .doc(_activeStoreId)
          .collection('counters')
          .doc(id)
          .delete();
          
      _counters.removeWhere((c) => c.id == id);
      notifyListeners();
    } catch (e) {

      rethrow;
    }
  }

  // --- STORE TYPES (GLOBAL) ---
  Future<List<String>> fetchStoreTypes() async {
    try {
       final doc = await _db.collection('settings').doc('global').get();
       if (doc.exists && doc.data()!['store_types'] != null) {
          return List<String>.from(doc.data()!['store_types']);
       }
       return [];
    } catch (e) {

       return [];
    }
  }

  Future<Map<String, dynamic>> fetchStoreTypeConfigs() async {
    try {
       final doc = await _db.collection('settings').doc('global').get();
       if (doc.exists && doc.data()!['store_type_configs'] != null) {
          return Map<String, dynamic>.from(doc.data()!['store_type_configs']);
       }
       return {};
    } catch (e) {

       return {};
    }
  }

  Future<void> addStoreType(String type, {Map<String, dynamic>? initialConfig}) async {
     try {
       final ref = _db.collection('settings').doc('global');
       // Transaction to ensure atomicity if possible, but for simplicity:
       await ref.set({
          'store_types': FieldValue.arrayUnion([type]),
          'store_type_configs': {
             type: initialConfig ?? {}
          }
       }, SetOptions(merge: true));
     } catch (e) {

       rethrow;
     }
  }

  Future<void> updateStoreType(String oldType, String newType, {Map<String, dynamic>? config}) async {
      try {
         final ref = _db.collection('settings').doc('global');
         
         // 1. Get current configs
         final doc = await ref.get();
         Map<String, dynamic> configs = {};
         if (doc.exists && doc.data()!['store_type_configs'] != null) {
             configs = Map<String, dynamic>.from(doc.data()!['store_type_configs']);
         }

         // 2. Prepare new config
         final oldConfig = configs[oldType] as Map<String, dynamic>? ?? {};
         final newConfig = config ?? oldConfig;
         
         // Remove old key, add new key
         configs.remove(oldType);
         configs[newType] = newConfig;

         await ref.update({
             'store_types': FieldValue.arrayRemove([oldType])
         });
         await ref.update({
             'store_types': FieldValue.arrayUnion([newType]),
             'store_type_configs': configs
         });
      } catch (e) {
         rethrow;
      }
  }

  Future<void> deleteStoreType(String type) async {
      try {
         final ref = _db.collection('settings').doc('global');
         await ref.update({
             'store_types': FieldValue.arrayRemove([type]),
             'store_type_configs.$type': FieldValue.delete()
         });
      } catch (e) {
         rethrow;
      }
  }

  // --- KIOSK ---
  Future<void> saveKioskPreference(bool enabled) async {
     if (Hive.isBoxOpen('settings')) {
        await Hive.box('settings').put('kiosk_mode', enabled);
     }
  }

  // --- ROLES ---
  List<RoleModel> _roles = [];
  List<RoleModel> get roles => _roles;
  final String _activeRole = 'Store Owner'; // Default to Store Owner for onboarding
  String get activeRole => _activeRole;

  Future<void> fetchRoles() async {
    try {
      final snap = await _db.collection('roles').get();
       final fetchedRoles = snap.docs.map((d) => RoleModel.fromMap(d.data(), d.id)).toList();
       
       // Ensure System Roles are present
       final systemRoles = [
         RoleModel(id: 'super_admin', name: 'Super Admin', permissions: {'admin': true}, isSystem: true),
         RoleModel(id: 'store_owner', name: 'Store Owner', permissions: {'admin': true}, isSystem: true),
       ];

       final Set<String> existingNames = fetchedRoles.map((r) => r.name).toSet();
       for (var sysRole in systemRoles) {
         if (!existingNames.contains(sysRole.name)) {
           fetchedRoles.add(sysRole);
         }
       }

       _roles = fetchedRoles;
       notifyListeners();
    } catch (e) { /* Error ignored */ }
  }

  Future<void> addRole(RoleModel role) async {
      try {
        final ref = _db.collection('roles').doc();
        final newRole = RoleModel(
          id: ref.id,
          name: role.name,
          permissions: role.permissions,
          isSystem: false,
        );
        await ref.set(newRole.toMap());
        _roles.add(newRole);
        notifyListeners();
      } catch (e) {
        rethrow;
      }
  }

  Future<void> updateRole(RoleModel role) async {
      try {
        await _db.collection('roles').doc(role.id).update(role.toMap());
        final i = _roles.indexWhere((r) => r.id == role.id);
        if (i != -1) {
           _roles[i] = role;
           notifyListeners();
        }
      } catch (e) {
        rethrow;
      }
  }

  Future<void> deleteRole(String id) async {
       try {
         await _db.collection('roles').doc(id).delete();
         _roles.removeWhere((r) => r.id == id);
         notifyListeners();
       } catch (e) {
         rethrow;
       }
  }

  // --- BACKUP & RESTORE ---
  bool _autoBackupEnabled = false;
  bool get autoBackupEnabled => _autoBackupEnabled;
  String _backupFrequency = 'Weekly';
  String get backupFrequency => _backupFrequency;
  TimeOfDay _backupTime = const TimeOfDay(hour: 2, minute: 0);
  TimeOfDay get backupTime => _backupTime;

  Future<void> _loadBackupSettings() async {
     if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        _autoBackupEnabled = box.get('autoBackupEnabled', defaultValue: false);
        _backupFrequency = box.get('backupFrequency', defaultValue: 'Weekly');
        
        final hour = box.get('backupTimeHour', defaultValue: 2);
        final minute = box.get('backupTimeMinute', defaultValue: 0);
        _backupTime = TimeOfDay(hour: hour, minute: minute);
        notifyListeners();
     }
  }

  Future<void> toggleAutoBackup(bool val) async {
     _autoBackupEnabled = val;
     notifyListeners();
     if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('autoBackupEnabled', val);
     }
  }
  
  void setBackupFrequency(String freq) {
    _backupFrequency = freq;
    notifyListeners();
    if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('backupFrequency', freq);
     }
  }
  
  void setBackupTime(TimeOfDay time) {
    _backupTime = time;
    notifyListeners();
    if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('backupTimeHour', time.hour);
        Hive.box('settings').put('backupTimeMinute', time.minute);
     }
  }
  
  Future<String> _getBackupPath() async {
     final dir = io.Platform.isAndroid ? await getExternalStorageDirectory() : await getApplicationDocumentsDirectory();
     final backupDir = io.Directory("${dir?.path ?? ''}/backups");
     if (!await backupDir.exists()) {
       await backupDir.create(recursive: true);
     }
     return backupDir.path;
  }

  Future<List<Map<String, dynamic>>> getAvailableBackups() async {
     try {
       if (kIsWeb) return [];
       final path = await _getBackupPath();
       final dir = io.Directory(path);
       final List<io.FileSystemEntity> files = dir.listSync();
       
       final List<Map<String, dynamic>> backups = [];
       for (var file in files) {
         if (file is io.File && file.path.endsWith('.json')) {
           final stat = file.statSync();
            backups.add({
              'name': file.path.split(io.Platform.pathSeparator).last,
              'file': file.path, 
              'date': stat.modified,
              'size': "${(stat.size / 1024).toStringAsFixed(2)} KB",
              'isWeb': false,
              'key': null,
            });
         }
       }
       // Sort by date descending
       backups.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
       return backups;
     } catch (e) {
       debugPrint("Error listing backups: $e");
       return [];
     }
  }
  
  Future<void> exportLocalBackup() async {
     try {
       final dbHelper = DatabaseHelper();
       final db = await dbHelper.database;
       final List<String> configTables = ['store_settings', 'floors', 'tables', 'suppliers', 'notes'];
       final List<String> userTables = ['customers', 'employees', 'roles'];
       final List<String> transactionTables = ['orders', 'order_items', 'inventory'];
       
       final Map<String, List<Map<String, dynamic>>> backupData = {};
              for (var table in [...configTables, ...userTables, ...transactionTables]) {
          try {
             final rows = await db.query(table);
             backupData[table] = rows;
          } catch (e) {
             debugPrint("Table $table skipped: $e");
          }
        }

        // --- NEW: Add Hive Settings to Backup ---
        if (Hive.isBoxOpen('settings')) {
           final settingsBox = Hive.box('settings');
           final Map<String, dynamic> hiveSettings = {};
           for (var key in settingsBox.keys) {
              hiveSettings[key.toString()] = settingsBox.get(key);
           }
           backupData['hive_settings'] = [hiveSettings]; // Wrap in list to match structure
        }
       
       final jsonString = jsonEncode(backupData);
       final fileName = "bizpos_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json";
       
        if (kIsWeb) {
          final blob = html.Blob([jsonString], 'application/json');
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.document.createElement('a') as html.AnchorElement
            ..href = url
            ..style.display = 'none'
            ..download = fileName;
          html.document.body!.children.add(anchor);
          anchor.click();
          html.document.body!.children.remove(anchor);
          html.Url.revokeObjectUrl(url);
          debugPrint("Backup exported via browser download");
        } else {
          final backupDirPath = await _getBackupPath();
          final path = "$backupDirPath/$fileName";
          final file = io.File(path);
          await file.writeAsString(jsonString);
          debugPrint("Backup saved to: $path");
        }
     } catch (e) {
       debugPrint("Export failed: $e");
     }
  }
  
  Future<void> restoreLocalBackup({dynamic file, String? webKey}) async {
     try {
       String? jsonString;
       
       if (file == null && webKey == null) {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
             type: FileType.custom,
             allowedExtensions: ['json'],
             withData: true, 
          );
          if (result == null) return; 
          
          if (kIsWeb) {
             jsonString = utf8.decode(result.files.first.bytes!);
          } else {
             final path = result.files.first.path!;
             jsonString = await io.File(path).readAsString();
          }
       } else if (file is String) {
          if (!kIsWeb) jsonString = await io.File(file).readAsString();
       }
       
       if (jsonString != null && jsonString.isNotEmpty) {
          final dbHelper = DatabaseHelper();
          final db = await dbHelper.database;
          final Map<String, dynamic> backupData = await compute(_decodeJsonBackup, jsonString);
          
          await dbHelper.clearAll(); // Wipe SQLite database
                    final batch = db.batch();
           for (var entry in backupData.entries) {
              final table = entry.key;
              if (table == 'hive_settings') continue; // Handle separately
              
              final rows = entry.value as List<dynamic>;
              for (var row in rows) {
                 batch.insert(table, row as Map<String, dynamic>);
              }
           }
           await batch.commit(noResult: true);

           // --- NEW: Restore Hive Settings ---
           if (backupData.containsKey('hive_settings')) {
              final settingsList = backupData['hive_settings'] as List<dynamic>;
              if (settingsList.isNotEmpty && Hive.isBoxOpen('settings')) {
                 final settingsBox = Hive.box('settings');
                 final hiveSettings = settingsList.first as Map<String, dynamic>;
                 for (var entry in hiveSettings.entries) {
                    await settingsBox.put(entry.key, entry.value);
                 }
                 await _loadBackupSettings(); // Refresh local variables
              }
           }
           
           if (_activeStoreId != null) {
              await _fetchUserStores();
           }
       }
     } catch (e) {
       debugPrint("Restore failed: $e");
     }
  }

  // --- HELPER FOR HIVE DATA CASTING ---
  Map<String, dynamic> _deepSanitize(Map input) {
    final Map<String, dynamic> output = {};
    for (var key in input.keys) {
      var value = input[key];
      if (value is Map) {
        value = _deepSanitize(value);
      } else if (value is List) {
        value = value.map((e) => e is Map ? _deepSanitize(e) : e).toList();
      }
      output[key.toString()] = value;
    }
    return output;
  }
  DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    try {
      if (val.runtimeType.toString().contains('Timestamp')) return val.toDate();
    } catch (_) {}
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val);
    return null;
  }
}
