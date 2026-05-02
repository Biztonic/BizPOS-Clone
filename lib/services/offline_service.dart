// ignore_for_file: unused_field
import 'dart:async';
// import 'dart:io'; // Removed for Web Compatibility 
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  static const String _authBoxName = 'auth_cache';
  static const String _syncQueueBox = 'sync_queue';
  
  // Connectivity Stream
  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;
  Timer? _connectivityTimer;
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Box? _authBox;
  Box? _syncBox;
  
  // Connectivity Plus
  final Connectivity _connectivity = Connectivity();

  Future<void> init() async {
    if (!Hive.isBoxOpen(_authBoxName)) {
      _authBox = await Hive.openBox(_authBoxName);
    } else {
      _authBox = Hive.box(_authBoxName);
    }

    if (!Hive.isBoxOpen(_syncQueueBox)) {
      _syncBox = await Hive.openBox(_syncQueueBox);
    } else {
      _syncBox = Hive.box(_syncQueueBox);
    }

    _startConnectivityMonitor();
    
    // Initial check
    _isOnline = await _checkConnection();
    _connectivityController.add(_isOnline);
  }
  
  void _startConnectivityMonitor() {
    // 1. Listen to OS-level connectivity changes (Instant feedback)
    _connectivity.onConnectivityChanged.listen((results) {
      // results is List<ConnectivityResult> in newer versions
      // Handle both single and list for safety if version varies
       _checkConnection().then((connected) {
         if (connected != _isOnline) {
           _isOnline = connected;
           _connectivityController.add(_isOnline);
         }
       });
    });

    // 2. Periodic Poll (For \"Connected to WiFi but no Internet\" cases on Mobile)
    _connectivityTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
       bool connected = await _checkConnection();
       if (connected != _isOnline) {
         _isOnline = connected;
         _connectivityController.add(_isOnline);
       }
    });
  }
  
  Future<bool> _checkConnection() async {
    // 1. Check Network Interface First (Cheap)
    var connectivityResult = await _connectivity.checkConnectivity();
    // Support List<ConnectivityResult> (new) and ConnectivityResult (old) just in case
    bool hasNetwork = false;
     hasNetwork = connectivityResult.any((r) => r != ConnectivityResult.none);
  
    if (!hasNetwork) return false; // Definitely offline

    // 2. Platform Specific Internet Check
    if (kIsWeb) {
      return true; 
    } else {
      // Simple fallback or rely on connectivity for now to avoid dart:io dependency issues
      return true;
    }
  }

  void dispose() {
    _connectivityTimer?.cancel();
    _connectivityController.close();
  }

  // --- Auth Cache (Multi-User Isolated) ---

  /// Cache credentials keyed by email so multiple users can coexist offline.
  Future<void> cacheCredentials(String email, String password, {String? uid}) async {
    final box = Hive.box(_authBoxName);
    final emailKey = email.toLowerCase().trim();
    await box.put('cred_$emailKey', password);
    await box.put('last_login', DateTime.now().toIso8601String());
    await box.put('last_login_email', emailKey);
    if (uid != null) {
      await box.put('uid_$emailKey', uid);
      await box.put('cached_uid', uid); // Keep global fallback for backward compat
    }
  }

  /// Cache the real Firebase UID for offline login sessions (keyed by email).
  Future<void> cacheUserId(String uid, {String? email}) async {
    if (!Hive.isBoxOpen(_authBoxName)) await Hive.openBox(_authBoxName);
    final box = Hive.box(_authBoxName);
    await box.put('cached_uid', uid);
    if (email != null) {
      await box.put('uid_${email.toLowerCase().trim()}', uid);
    }
  }

  /// Retrieve the cached Firebase UID. If [email] is provided, returns the
  /// UID specifically associated with that email; otherwise returns the
  /// last-logged-in UID.
  String? getCachedUserId({String? email}) {
    if (!Hive.isBoxOpen(_authBoxName)) return null;
    final box = Hive.box(_authBoxName);
    if (email != null) {
      return box.get('uid_${email.toLowerCase().trim()}');
    }
    return box.get('cached_uid');
  }

  /// Retrieve cached credentials for a specific [email].
  /// Returns null if no credentials are cached for this email.
  Map<String, String>? getCachedCredentials({String? email}) {
    if (!Hive.isBoxOpen(_authBoxName)) return null;
    final box = Hive.box(_authBoxName);
    // Resolve which email to look up
    final emailKey = (email ?? box.get('last_login_email'))?.toString().toLowerCase().trim();
    if (emailKey == null) return null;
    final password = box.get('cred_$emailKey');
    if (password != null) {
      return {'email': emailKey, 'password': password.toString()};
    }
    return null;
  }

  Future<void> setOfflineLoginState(bool isLoggedIn, {String? email}) async {
    if (!Hive.isBoxOpen(_authBoxName)) await Hive.openBox(_authBoxName);
    final box = Hive.box(_authBoxName);
    await box.put('is_offline_logged_in', isLoggedIn);
    if (email != null) {
      await box.put('offline_email', email.toLowerCase().trim());
    }
  }

  bool getOfflineLoginState() {
     if (!Hive.isBoxOpen(_authBoxName)) return false;
     return Hive.box(_authBoxName).get('is_offline_logged_in', defaultValue: false);
  }

  /// Get the email of the offline-logged-in user.
  String? getOfflineLoginEmail() {
    if (!Hive.isBoxOpen(_authBoxName)) return null;
    return Hive.box(_authBoxName).get('offline_email');
  }

  /// Clear credentials for the current session only (not all users).
  Future<void> clearCredentials() async {
    if (Hive.isBoxOpen(_authBoxName)) {
       final box = Hive.box(_authBoxName);
       // Only clear session flags, NOT per-email credential caches.
       // This allows other users' offline caches to survive.
       await box.delete('is_offline_logged_in');
       await box.delete('offline_email');
       await box.delete('cached_uid');
    }
  }

  // --- Order Queue ---

  Future<void> queueOrder(OrderModel order) async {
    final box = Hive.box(_syncQueueBox);
    final orderMap = order.toHiveMap(); // Use Hive-compatible map
    await box.add(orderMap);
  }

  List<OrderModel> getQueuedOrders() {
    if (!Hive.isBoxOpen(_syncQueueBox)) return [];
    final box = Hive.box(_syncQueueBox);
    final List<dynamic> raw = box.values.toList();
    return raw.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      return OrderModel.fromMap(map, map['id'] ?? ''); 
    }).toList();
  }

  Future<void> removeQueuedOrder(int index) async {
    if (Hive.isBoxOpen(_syncQueueBox)) {
       await Hive.box(_syncQueueBox).deleteAt(index);
    }
  }
  
  Future<void> clearQueue() async {
    if (Hive.isBoxOpen(_syncQueueBox)) {
       await Hive.box(_syncQueueBox).clear();
    }
  }

  // --- User Profile Cache (uid-isolated) ---
  static const String _userBoxName = 'user_profile_cache';

  /// Cache a user profile keyed by [uid] so multiple users can coexist.
  Future<void> cacheUserProfile(Map<String, dynamic> profileData, {String? uid}) async {
    if (!Hive.isBoxOpen(_userBoxName)) await Hive.openBox(_userBoxName);
    final box = Hive.box(_userBoxName);
    final key = uid != null ? 'profile_$uid' : 'profile';
    // Sanitize data (convert Timestamps to strings) for Hive compatibility
    await box.put(key, _sanitizeForHive(profileData));
  }

  /// Get the cached user profile for a specific [uid].
  Future<Map?> getCachedUserProfile({String? uid}) async {
    if (!Hive.isBoxOpen(_userBoxName)) await Hive.openBox(_userBoxName);
    final box = Hive.box(_userBoxName);
    final key = uid != null ? 'profile_$uid' : 'profile';
    final data = box.get(key);
    if (data != null) {
      return data as Map;
    }
    return null;
  }

  // Helper to make Firestore data Hive-compatible (Recursive)
  dynamic _sanitizeForHive(dynamic data) {
    if (data == null) return null;
    
    if (data is Timestamp) {
      return data.toDate().toIso8601String();
    }
    
    if (data is DocumentReference) {
      return data.path;
    }
    
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), _sanitizeForHive(value)));
    }
    
    if (data is List) {
      return data.map((item) => _sanitizeForHive(item)).toList();
    }
    
    return data; // Primitives are fine
  }

  // --- Quick Employee Login Cache ---
  static const String _pinnedStoreBoxName = 'pinned_store';
  static const String _employeesCacheBoxName = 'cache_employees';

  Future<void> pinStore(Map<String, dynamic> storeData, {String? uid}) async {
    if (!Hive.isBoxOpen(_pinnedStoreBoxName)) await Hive.openBox(_pinnedStoreBoxName);
    final box = Hive.box(_pinnedStoreBoxName);
    final key = uid != null ? "current_$uid" : "current";
    await box.put(key, _sanitizeForHive(storeData));
    await box.put("last_pinned_$key", DateTime.now().toIso8601String());
  }

  Future<Map?> getPinnedStore({String? uid}) async {
    if (!Hive.isBoxOpen(_pinnedStoreBoxName)) await Hive.openBox(_pinnedStoreBoxName);
    final box = Hive.box(_pinnedStoreBoxName);
    final key = uid != null ? "current_$uid" : "current";
    final data = box.get(key);
    if (data != null) {
      return data as Map;
    }
    return null;
  }

  /// Cache employees for a specific store. Only overwrites keys for THIS store,
  /// preserving employee caches of other stores.
  Future<void> cacheStoreEmployees(String storeId, List<Map<String, dynamic>> employees) async {
    if (!Hive.isBoxOpen(_employeesCacheBoxName)) await Hive.openBox(_employeesCacheBoxName);
    final box = Hive.box(_employeesCacheBoxName);
    
    // Remove old employee entries for THIS store only (not box.clear()!)
    final keysToDelete = box.keys.where((k) => k.toString().startsWith('${storeId}_')).toList();
    for (var key in keysToDelete) {
      await box.delete(key);
    }
    
    for (var emp in employees) {
      final key = "${storeId}_${emp['employeeId']}";
      await box.put(key, _sanitizeForHive(emp));
    }
  }

  Future<List<Map>> getCachedStoreEmployees(String storeId) async {
    if (!Hive.isBoxOpen(_employeesCacheBoxName)) await Hive.openBox(_employeesCacheBoxName);
    final box = Hive.box(_employeesCacheBoxName);
    return box.values
      .where((e) => (e as Map)['storeId'] == storeId)
      .map((e) => e as Map)
      .toList();
  }

  Future<void> unpinStore({String? uid}) async {
    if (Hive.isBoxOpen(_pinnedStoreBoxName)) {
      final key = uid != null ? "current_$uid" : "current";
      await Hive.box(_pinnedStoreBoxName).delete(key);
    }
    // NOTE: Do NOT clear all employees. They belong to the store, not the user session.
  }

  // --- Accessible Stores Cache (uid-isolated) ---
  static const String _storesCacheBoxName = 'cache_user_stores';

  /// Cache a user's store list keyed by [uid]. Does NOT wipe other users' caches.
  Future<void> cacheUserStores(List<Map<String, dynamic>> stores, {String? uid}) async {
    if (!Hive.isBoxOpen(_storesCacheBoxName)) await Hive.openBox(_storesCacheBoxName);
    final box = Hive.box(_storesCacheBoxName);
    final key = uid != null ? 'stores_$uid' : 'stores_global';
    // Store as a single serializable list under the user's key
    await box.put(key, stores.map((s) => _sanitizeForHive(s)).toList());
  }

  /// Get the cached store list for a specific [uid].
  Future<List<Map>> getCachedUserStores({String? uid}) async {
    if (!Hive.isBoxOpen(_storesCacheBoxName)) await Hive.openBox(_storesCacheBoxName);
    final box = Hive.box(_storesCacheBoxName);
    final key = uid != null ? 'stores_$uid' : 'stores_global';
    final data = box.get(key);
    if (data != null && data is List) {
      return data.map((e) => e as Map).toList();
    }
    // Backward compat: try old format (indexed values) if uid-keyed data not found
    if (uid != null) {
      final fallback = box.get('stores_global');
      if (fallback != null && fallback is List) {
        return fallback.map((e) => e as Map).toList();
      }
    }
    return [];
  }
}

