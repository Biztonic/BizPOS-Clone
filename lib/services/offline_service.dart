// ignore_for_file: unused_field
import 'dart:async';
import 'dart:convert';
import 'dart:math';
// import 'dart:io'; // Removed for Web Compatibility
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../utils/pin_utils.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum ConnectionQuality { offline, localNetwork, internet, backendAvailable }

class OfflineService {
  static bool isTesting = false;
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  static const String _authBoxName = 'auth_cache';
  static const String _syncQueueBox = 'sync_queue';

  // Connectivity Stream
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;

  // Connection Quality Stream
  final StreamController<ConnectionQuality> _connectionQualityController =
      StreamController<ConnectionQuality>.broadcast();
  Stream<ConnectionQuality> get connectionQualityStream =>
      _connectionQualityController.stream;

  ConnectionQuality _connectionQuality = ConnectionQuality.offline;
  ConnectionQuality get connectionQuality => _connectionQuality;

  Timer? _connectivityTimer;

  bool get isOnline =>
      _connectionQuality == ConnectionQuality.internet ||
      _connectionQuality == ConnectionQuality.backendAvailable;

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

    // Security cleanup: purge any legacy plaintext cred_* keys
    unawaited(_purgeLegacyPlaintextCredentials());

    _startConnectivityMonitor();

    // Initial check
    _connectionQuality = await _checkConnectionQuality();
    _connectivityController.add(isOnline);
    _connectionQualityController.add(_connectionQuality);
  }

  void _startConnectivityMonitor() {
    // 1. Listen to OS-level connectivity changes (Instant feedback)
    _connectivity.onConnectivityChanged.listen((results) {
      _runConnectivityCheck();
    });

    // 2. Periodic Poll (For "Connected to WiFi but no Internet" cases on Mobile)
    if (!isTesting) {
      _connectivityTimer =
          Timer.periodic(const Duration(seconds: 10), (timer) async {
        await _runConnectivityCheck();
      });
    }
  }

  Future<void> _runConnectivityCheck() async {
    final oldQuality = _connectionQuality;
    final oldIsOnline = isOnline;

    _connectionQuality = await _checkConnectionQuality();

    if (isOnline != oldIsOnline) {
      _connectivityController.add(isOnline);
    }
    if (_connectionQuality != oldQuality) {
      _connectionQualityController.add(_connectionQuality);
      debugPrint(
          '📶 Connectivity: Connection quality changed to ${_connectionQuality.name}');
    }
  }

  Future<ConnectionQuality> _checkConnectionQuality() async {
    try {
      var connectivityResult = await _connectivity.checkConnectivity();
      bool hasNetwork =
          connectivityResult.any((r) => r != ConnectivityResult.none);
      if (!hasNetwork) return ConnectionQuality.offline;

      if (kIsWeb) {
        return ConnectionQuality
            .backendAvailable; // Web browser handles online state natively
      }

      // 1. Try generate_204 to confirm WAN internet routing
      try {
        final wanResponse =
            await Dio(BaseOptions(connectTimeout: const Duration(seconds: 2)))
                .get('https://clients3.google.com/generate_204');
        if (wanResponse.statusCode != 204) {
          return ConnectionQuality.localNetwork;
        }
      } catch (_) {
        return ConnectionQuality
            .localNetwork; // Interface works, but WAN check failed
      }

      // 2. Try Firestore/Firebase backend endpoint to confirm backend is available
      try {
        await Dio(BaseOptions(connectTimeout: const Duration(seconds: 2)))
            .head('https://firestore.googleapis.com');
        return ConnectionQuality.backendAvailable;
      } catch (_) {
        return ConnectionQuality
            .internet; // Internet works, but Firebase backend is blocked/unreachable
      }
    } catch (_) {
      return ConnectionQuality.offline;
    }
  }

  // Deprecated legacy helper, mapped for backward compatibility
  Future<bool> checkConnection() async {
    final quality = await _checkConnectionQuality();
    return quality == ConnectionQuality.internet ||
        quality == ConnectionQuality.backendAvailable;
  }

  void dispose() {
    _connectivityTimer?.cancel();
    _connectivityController.close();
  }

  // --- Auth Cache (Multi-User Isolated, Salted Verifiers Only) ---
  static const _secureStorage = FlutterSecureStorage();
  static const int _maxFailedAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 15);

  static const int _maxFailedPinAttempts = 5;
  static const Duration _pinLockoutDuration = Duration(minutes: 5);

  /// Cache offline verifier (Salted SHA-256 hash + salt) for secure offline login.
  /// Strictly complies with Zero Raw Password Storage: no plaintext or reversible
  /// credentials are ever saved.
  Future<void> cacheOfflineVerifier(String email, String password,
      {String? uid}) async {
    if (!Hive.isBoxOpen(_authBoxName)) await Hive.openBox(_authBoxName);
    final box = Hive.box(_authBoxName);
    final emailKey = email.toLowerCase().trim();

    // 1. Generate salt and salted SHA-256 hash for secure offline verifier
    final salt = _generateRandomSalt(16);
    final hash = _hashPassword(password, salt);
    await box.put('salt_$emailKey', salt);
    await box.put('hash_$emailKey', hash);

    // 2. Zero raw password storage (Principle 9) - purge any legacy key
    try {
      await _secureStorage.delete(key: 'cred_$emailKey');
    } catch (_) {}

    // 3. Reset failed attempts count and lockout on successful authorized login
    await box.put('failed_attempts_$emailKey', 0);
    await box.delete('locked_until_$emailKey');

    // 4. Record last authorized merchant credentials
    await box.put('last_login', DateTime.now().toIso8601String());
    await box.put('last_login_email', emailKey);
    await box.put('last_authorized_email', emailKey);
    if (uid != null) {
      await box.put('uid_$emailKey', uid);
      await box.put('last_authorized_uid', uid);
      await box.put('cached_uid', uid); // Global fallback for backward compat
    }
  }

  /// Backward-compatible alias for cacheOfflineVerifier.
  Future<void> cacheCredentials(String email, String password,
      {String? uid}) async {
    await cacheOfflineVerifier(email, password, uid: uid);
  }

  /// Get the email of the last authorized user on this terminal.
  String? getLastAuthorizedEmail() {
    if (!Hive.isBoxOpen(_authBoxName)) return null;
    final box = Hive.box(_authBoxName);
    return box.get('last_authorized_email') ?? box.get('last_login_email');
  }

  /// Get the UID of the last authorized user on this terminal.
  String? getLastAuthorizedUid() {
    if (!Hive.isBoxOpen(_authBoxName)) return null;
    final box = Hive.box(_authBoxName);
    return box.get('last_authorized_uid') ?? box.get('cached_uid');
  }

  String _generateRandomSalt(int length) {
    final rand = Random.secure();
    final values = List<int>.generate(length, (i) => rand.nextInt(256));
    return base64UrlEncode(values);
  }

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    return sha256.convert(bytes).toString();
  }

  /// Verify offline credentials using salted SHA-256 hashes from Hive cache.
  /// Requirement 6: Offline POS functionality must continue for the last authorized local user only.
  Future<bool> verifyOfflinePassword(String email, String password) async {
    final emailKey = email.toLowerCase().trim();

    if (isOfflineLockedOut(emailKey)) {
      debugPrint(
          '🔒 OfflineService: Offline login locked out for $email due to too many failed attempts.');
      return false;
    }

    if (!Hive.isBoxOpen(_authBoxName)) await Hive.openBox(_authBoxName);
    final box = Hive.box(_authBoxName);

    // Strict check: only the last authorized user can use offline POS functionality
    final lastAuth = getLastAuthorizedEmail();
    if (lastAuth != null && lastAuth.isNotEmpty && lastAuth != emailKey) {
      debugPrint(
          '🚫 OfflineService: Denied offline access for $emailKey. Last authorized user is $lastAuth.');
      await incrementFailedAttempts(emailKey);
      return false;
    }

    final salt = box.get('salt_$emailKey');
    final hash = box.get('hash_$emailKey');

    if (salt == null || hash == null) {
      await incrementFailedAttempts(emailKey);
      return false;
    }

    final attemptHash = _hashPassword(password, salt.toString());
    final isValid = attemptHash == hash.toString();

    if (isValid) {
      await resetFailedAttempts(emailKey);
      return true;
    } else {
      await incrementFailedAttempts(emailKey);
      return false;
    }
  }

  /// Check if offline login is currently locked out for [email].
  bool isOfflineLockedOut(String email) {
    if (!Hive.isBoxOpen(_authBoxName)) return false;
    final box = Hive.box(_authBoxName);
    final emailKey = email.toLowerCase().trim();
    final failedCount =
        box.get('failed_attempts_$emailKey', defaultValue: 0) as int;

    if (failedCount < _maxFailedAttempts) return false;

    final lockedUntilStr = box.get('locked_until_$emailKey') as String?;
    if (lockedUntilStr != null) {
      final lockedUntil = DateTime.tryParse(lockedUntilStr);
      if (lockedUntil != null) {
        if (DateTime.now().isBefore(lockedUntil)) {
          return true;
        } else {
          // Lockout duration has expired, reset counter
          box.put('failed_attempts_$emailKey', 0);
          box.delete('locked_until_$emailKey');
          return false;
        }
      }
    }
    return true;
  }

  /// Returns the remaining lockout seconds for [email], or 0 if not locked.
  int getRemainingLockoutSeconds(String email) {
    if (!Hive.isBoxOpen(_authBoxName)) return 0;
    final box = Hive.box(_authBoxName);
    final emailKey = email.toLowerCase().trim();
    final lockedUntilStr = box.get('locked_until_$emailKey') as String?;
    if (lockedUntilStr != null) {
      final lockedUntil = DateTime.tryParse(lockedUntilStr);
      if (lockedUntil != null && DateTime.now().isBefore(lockedUntil)) {
        return lockedUntil.difference(DateTime.now()).inSeconds;
      }
    }
    return 0;
  }

  /// Reset failed attempts count and lockout window.
  Future<void> resetFailedAttempts(String email) async {
    if (!Hive.isBoxOpen(_authBoxName)) await Hive.openBox(_authBoxName);
    final box = Hive.box(_authBoxName);
    final emailKey = email.toLowerCase().trim();
    await box.put('failed_attempts_$emailKey', 0);
    await box.delete('locked_until_$emailKey');
  }

  /// Increment failed attempts count and initiate lockout if threshold reached.
  Future<void> incrementFailedAttempts(String email) async {
    if (!Hive.isBoxOpen(_authBoxName)) await Hive.openBox(_authBoxName);
    final box = Hive.box(_authBoxName);
    final emailKey = email.toLowerCase().trim();
    final current =
        box.get('failed_attempts_$emailKey', defaultValue: 0) as int;
    final newCount = current + 1;
    await box.put('failed_attempts_$emailKey', newCount);

    if (newCount >= _maxFailedAttempts) {
      final lockedUntil = DateTime.now().add(_lockoutDuration);
      await box.put('locked_until_$emailKey', lockedUntil.toIso8601String());
      debugPrint(
          '🔒 OfflineService: Threshold reached. Account $email locked out until $lockedUntil');
    }
  }

  // --- Employee POS PIN Lockout & Verification Protection ---

  bool isEmployeePinLockedOut(String storeId, String empId) {
    if (!Hive.isBoxOpen(_employeesCacheBoxName)) return false;
    final box = Hive.box(_employeesCacheBoxName);
    final key = 'failed_pin_${storeId}_$empId';
    final count = box.get(key, defaultValue: 0) as int;
    if (count < _maxFailedPinAttempts) return false;

    final lockKey = 'pin_locked_until_${storeId}_$empId';
    final untilStr = box.get(lockKey) as String?;
    if (untilStr != null) {
      final lockedUntil = DateTime.tryParse(untilStr);
      if (lockedUntil != null) {
        if (DateTime.now().isBefore(lockedUntil)) {
          return true;
        } else {
          box.put(key, 0);
          box.delete(lockKey);
          return false;
        }
      }
    }
    return true;
  }

  int getRemainingPinLockoutSeconds(String storeId, String empId) {
    if (!Hive.isBoxOpen(_employeesCacheBoxName)) return 0;
    final box = Hive.box(_employeesCacheBoxName);
    final lockKey = 'pin_locked_until_${storeId}_$empId';
    final untilStr = box.get(lockKey) as String?;
    if (untilStr != null) {
      final lockedUntil = DateTime.tryParse(untilStr);
      if (lockedUntil != null && DateTime.now().isBefore(lockedUntil)) {
        return lockedUntil.difference(DateTime.now()).inSeconds;
      }
    }
    return 0;
  }

  Future<void> recordFailedPinAttempt(String storeId, String empId) async {
    if (!Hive.isBoxOpen(_employeesCacheBoxName)) {
      await Hive.openBox(_employeesCacheBoxName);
    }
    final box = Hive.box(_employeesCacheBoxName);
    final key = 'failed_pin_${storeId}_$empId';
    final count = (box.get(key, defaultValue: 0) as int) + 1;
    await box.put(key, count);

    if (count >= _maxFailedPinAttempts) {
      final lockedUntil = DateTime.now().add(_pinLockoutDuration);
      await box.put(
          'pin_locked_until_${storeId}_$empId', lockedUntil.toIso8601String());
      debugPrint(
          '🔒 OfflineService: Employee PIN locked for store $storeId emp $empId until $lockedUntil');
    }
  }

  Future<void> resetPinAttempts(String storeId, String empId) async {
    if (!Hive.isBoxOpen(_employeesCacheBoxName)) {
      await Hive.openBox(_employeesCacheBoxName);
    }
    final box = Hive.box(_employeesCacheBoxName);
    await box.put('failed_pin_${storeId}_$empId', 0);
    await box.delete('pin_locked_until_${storeId}_$empId');
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

  /// Purge legacy plaintext credentials from secure storage if present
  Future<void> _purgeLegacyPlaintextCredentials() async {
    try {
      final all = await _secureStorage.readAll();
      for (final key in all.keys) {
        if (key.startsWith('cred_')) {
          await _secureStorage.delete(key: key);
        }
      }
    } catch (_) {}
  }

  /// Deprecated: Raw password storage is eliminated for security compliance (Principle 9).
  /// Always returns null and purges legacy keys.
  Future<Map<String, String>?> getCachedCredentials({String? email}) async {
    if (!Hive.isBoxOpen(_authBoxName)) return null;
    final box = Hive.box(_authBoxName);
    final emailKey =
        (email ?? box.get('last_login_email'))?.toString().toLowerCase().trim();
    if (emailKey != null) {
      try {
        await _secureStorage.delete(key: 'cred_$emailKey');
      } catch (_) {}
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
    return Hive.box(_authBoxName)
        .get('is_offline_logged_in', defaultValue: false);
  }

  /// Get the email of the offline-logged-in user.
  String? getOfflineLoginEmail() {
    if (!Hive.isBoxOpen(_authBoxName)) return null;
    return Hive.box(_authBoxName).get('offline_email');
  }

  /// Clear credentials for the active session only.
  /// Requirement 10 & 11: Clears session-specific data while preserving
  /// other legitimate local user profiles, cached stores, and salted verifiers.
  Future<void> clearCredentials({String? email}) async {
    if (Hive.isBoxOpen(_authBoxName)) {
      final box = Hive.box(_authBoxName);
      final emailKey =
          (email ?? box.get('offline_email') ?? box.get('last_login_email'))
              ?.toString()
              .toLowerCase()
              .trim();
      if (emailKey != null) {
        try {
          await _secureStorage.delete(key: 'cred_$emailKey');
        } catch (_) {}
      }
      // Purge ONLY active session keys
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
  Future<void> cacheUserProfile(Map<String, dynamic> profileData,
      {String? uid}) async {
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
      return data.map(
          (key, value) => MapEntry(key.toString(), _sanitizeForHive(value)));
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
    if (!Hive.isBoxOpen(_pinnedStoreBoxName)) {
      await Hive.openBox(_pinnedStoreBoxName);
    }
    final box = Hive.box(_pinnedStoreBoxName);
    final key = uid != null ? "current_$uid" : "current";
    await box.put(key, _sanitizeForHive(storeData));
    await box.put("last_pinned_$key", DateTime.now().toIso8601String());
  }

  Future<Map?> getPinnedStore({String? uid}) async {
    if (!Hive.isBoxOpen(_pinnedStoreBoxName)) {
      await Hive.openBox(_pinnedStoreBoxName);
    }
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
  Future<void> cacheStoreEmployees(
      String storeId, List<Map<String, dynamic>> employees) async {
    if (!Hive.isBoxOpen(_employeesCacheBoxName)) {
      await Hive.openBox(_employeesCacheBoxName);
    }
    final box = Hive.box(_employeesCacheBoxName);

    // Remove old employee entries for THIS store only (not box.clear()!)
    final keysToDelete =
        box.keys.where((k) => k.toString().startsWith('${storeId}_')).toList();
    for (var key in keysToDelete) {
      await box.delete(key);
    }

    for (var emp in employees) {
      final map = Map<String, dynamic>.from(emp);
      // Requirements 7 & 8: Never store plaintext PINs in offline cache.
      if (map.containsKey('pin')) {
        final rawPin = map['pin']?.toString() ?? '';
        final empUid = map['uid']?.toString() ?? '';
        if (!map.containsKey('pinHash') ||
            map['pinHash'] == null ||
            map['pinHash'].toString().isEmpty) {
          if (rawPin.isNotEmpty && empUid.isNotEmpty) {
            map['pinHash'] = PinUtils.hashPin(rawPin, empUid);
          }
        }
        map.remove('pin');
      }
      final key = "${storeId}_${emp['employeeId']}";
      await box.put(key, _sanitizeForHive(map));
    }
  }

  Future<List<Map>> getCachedStoreEmployees(String storeId) async {
    if (!Hive.isBoxOpen(_employeesCacheBoxName)) {
      await Hive.openBox(_employeesCacheBoxName);
    }
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
  Future<void> cacheUserStores(List<Map<String, dynamic>> stores,
      {String? uid}) async {
    if (!Hive.isBoxOpen(_storesCacheBoxName)) {
      await Hive.openBox(_storesCacheBoxName);
    }
    final box = Hive.box(_storesCacheBoxName);
    final key = uid != null ? 'stores_$uid' : 'stores_global';
    // Store as a single serializable list under the user's key
    await box.put(key, stores.map((s) => _sanitizeForHive(s)).toList());
  }

  /// Get the cached store list for a specific [uid].
  Future<List<Map>> getCachedUserStores({String? uid}) async {
    if (!Hive.isBoxOpen(_storesCacheBoxName)) {
      await Hive.openBox(_storesCacheBoxName);
    }
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
