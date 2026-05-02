// ignore_for_file: unused_field, unnecessary_type_check, curly_braces_in_flow_control_structures, unused_element, unused_local_variable
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/services/firestore_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io'; // NEW: For hardened connectivity checks
import 'package:flutter/foundation.dart';

import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/models/inventory_item.dart';
import 'package:biztonic_pos/models/customer.dart';
import 'package:biztonic_pos/models/user_profile.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:hive_flutter/hive_flutter.dart'; 
import 'package:uuid/uuid.dart';

class SyncService with ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  // --- STREAMS ---
  final StreamController<String> _syncStatusController = StreamController<String>.broadcast();
  Stream<String> get syncStatusStream => _syncStatusController.stream;

  // --- STATE ---
  // --- STATE ---
  final bool _isManualBackup = false; // Flag for manual backup
  String _syncStatus = "Synced"; 
  String get syncStatus => _syncStatus;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;
  
  String? _lastSyncError;
  String? get lastSyncError => _lastSyncError;
  set lastSyncError(String? value) {
    _lastSyncError = value;
    notifyListeners();
  }

  String? _lastSyncWarning;
  String? get lastSyncWarning => _lastSyncWarning;
  set lastSyncWarning(String? value) {
    _lastSyncWarning = value;
    notifyListeners();
  }
  
  String? _lastIndexErrorUrl;
  String? get lastIndexErrorUrl => _lastIndexErrorUrl;

  String? _deviceId;
  String? get deviceId => _deviceId;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  String _syncFrequency = 'LIVE';
  String get syncFrequency => _syncFrequency;
  
  // In-memory caching for performance
  Map<String, dynamic>? _cachedPlatformLimits;
  Map<String, dynamic> get platformLimits => _cachedPlatformLimits ?? {};
  
  String? _cachedSubscriptionPlan;
  String? get cachedSubscriptionPlan => _cachedSubscriptionPlan;

  void setSyncFrequency(String frequency) {
    if (_syncFrequency == frequency) return;
    _syncFrequency = frequency;
    _saveSyncFrequency();
    notifyListeners();
    if (frequency == 'LIVE') processSync();
  }

  Box? _queueBox;
  Box? _failedQueueBox; // For items that hit retry limits
  Box? _syncLogBox; // NEW: Persistent diagnostic logs
  Timer? _syncTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  bool _isBusy = false;
  bool get isBusy => _isBusy; 
  bool isUnrestricted = false; 

  String? _userId;
  String? get userId => _userId;
  
  String? _userRole;
  String? get userRole => _userRole;

  void setUserRole(String? role) {
    if (_userRole == role) return;

    _userRole = role;
    notifyListeners();
  }
  
  final Repository _repository = Repository();
  Repository get repository => _repository;
  final FirebaseFirestore _db = getFirestore(); // Use 'bizpos' database

  String? _activeStoreId;
  String? get activeStoreId => _activeStoreId;


  // Local Counts
  int _localOrdersCount = 0;
  int _localInventoryCount = 0;
  int _localCustomersCount = 0;
  int _localSettingsCount = 0;
  int _localEmployeesCount = 0;
  int _localTablesCount = 0;
  int _localFloorsCount = 0;
  int _localSuppliersCount = 0;
  int _localNotesCount = 0;
  
  int get localOrdersCount => _localOrdersCount;
  int get localInventoryCount => _localInventoryCount;
  int get localCustomersCount => _localCustomersCount;
  int get localSettingsCount => _localSettingsCount;
  int get localEmployeesCount => _localEmployeesCount;
  int get localTablesCount => _localTablesCount;
  int get localFloorsCount => _localFloorsCount;
  int get localSuppliersCount => _localSuppliersCount;
  int get localNotesCount => _localNotesCount;
  
  int get cachedOrdersCount => _localOrdersCount;
  int get cachedInventoryCount => _localInventoryCount;
  int get cachedCustomersCount => _localCustomersCount;

  int get pendingUploadCount {
    if (_queueBox == null || _queueBox!.isEmpty) return 0;
    if (_activeStoreId == null) return _queueBox!.length;
    // Filter: Count only items belonging to the active store
    int count = 0;
    for (var val in _queueBox!.values) {
      if (val is Map) {
        final itemStoreId = (val['activeStoreId'] ?? '').toString().trim();
        final payloadStoreId = (val['payload'] is Map ? (val['payload']['storeId'] ?? '').toString().trim() : '');
        if (itemStoreId == _activeStoreId || payloadStoreId == _activeStoreId) {
          count++;
        }
      }
    }
    return count;
  }
  int get failedUploadCount => _failedQueueBox?.length ?? 0;

  bool get _hasCloudAccess => FirebaseAuth.instance.currentUser != null;

  // --- INIT ---
  Future<void> init() async {
    debugPrint('🔄 SyncService.init START');
    try {
      // 1. Pre-open all critical boxes to eliminate JANK during transactions
      final boxesToOpen = [
        'sync_queue_v2',
        'sync_failed_queue_v2',
        'settings',
        'cache_orders',
        'cache_inventory',
        'cache_customers',
        'cache_settings',
        'cache_employees',
        'cache_tables',
        'cache_floors',
        'cache_suppliers',
        'cache_notes'
      ];

      for (var name in boxesToOpen) {
        if (!Hive.isBoxOpen(name)) {
          debugPrint('📦 SyncService: Pre-opening $name...');
          await Hive.openBox(name);
        }
      }

      _queueBox = Hive.box('sync_queue_v2');
      _failedQueueBox = Hive.box('sync_failed_queue_v2');
      
      // NEW: Open diagnostic log box
      if (!Hive.isBoxOpen('sync_logs')) {
        await Hive.openBox('sync_logs');
      }
      _syncLogBox = Hive.box('sync_logs');
      _logSyncEvent("SyncService Initialized (Device: $_deviceId)");

      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user != null) {
            debugPrint('👤 SyncService: User detected: ${user.uid}');
            setUserId(user.uid);
            if (_activeStoreId != null) unawaited(processSync());
        }
      });

      var settingsBox = Hive.box('settings');
      if (settingsBox.containsKey('deviceId')) {
         _deviceId = settingsBox.get('deviceId');
      } else {
         debugPrint('🆔 SyncService: Generating new Device ID...');
         _deviceId = const Uuid().v4();
         settingsBox.put('deviceId', _deviceId);
      }
      
      debugPrint('🌐 SyncService: Init Connectivity...');
      _initConnectivity();

      if (_syncTimer == null) {
        _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
          if (_isOnline) processSync();
        });
        debugPrint('✅ SyncService: Sync timer started.');
      } else {
        debugPrint('ℹ️ SyncService: Sync timer already running.');
      }
      debugPrint('✅ SyncService.init END');
    } catch (e) {
      debugPrint('❌ SyncService.init ERROR: $e');
    }
  }

  void _initConnectivity() {
    Connectivity().checkConnectivity().then((result) {
       final status = (result is List) 
          ? (result.isNotEmpty ? result.first : ConnectivityResult.none)
          : result;
       _updateConnectionStatus(status as ConnectivityResult);
    });
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
       _updateConnectionStatus(result.isNotEmpty ? result.first : ConnectivityResult.none);
    });
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    bool wasOffline = !_isOnline;
    _isOnline = (result != ConnectivityResult.none);
    notifyListeners();
    if (wasOffline && _isOnline && _hasCloudAccess) {
       _logSyncEvent("Network Restored ($result). Triggering sync...");
       processSync();
    }
  }

  // --- REMOVED DUPLICATE CONNECTIVITY CHECK ---
  // Replaced by consolidated version at line 1490

  /// NEW: Persistent diagnostic logging
  Future<void> _logSyncEvent(String message, {bool isError = false}) async {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = {
      't': timestamp,
      'm': message,
      'e': isError,
    };
    
    debugPrint('${isError ? "❌" : "ℹ️"} SYNC_LOG: $message');
    
    if (_syncLogBox != null && _syncLogBox!.isOpen) {
      await _syncLogBox!.add(logEntry);
      // Keep only last 100 logs
      if (_syncLogBox!.length > 100) {
        await _syncLogBox!.deleteAt(0);
      }
    }
  }

  Future<void> setUserId(String uid) async {
    if (_userId == uid) return;
    
    // Migration Logic: Move items from current box to new box
    Box? oldBox = _queueBox;
    Box? oldFailedBox = _failedQueueBox;
    String newBoxName = 'sync_queue_v2_$uid';
    String failedBoxName = 'sync_failed_queue_$uid';
    
    _userId = uid;
    _queueBox = await Hive.openBox(newBoxName);
    _failedQueueBox = await Hive.openBox(failedBoxName);
    
    if (oldBox != null && oldBox.isOpen && oldBox.name != newBoxName) {
       // Only migrate if coming from the legacy generic queue (not another user's queue)
       if (oldBox.name == 'sync_queue_v2') {
          for (var key in oldBox.keys) {
             await _queueBox!.add(oldBox.get(key));
          }
          await oldBox.clear();
       }
       await oldBox.close();
    }

    if (oldFailedBox != null && oldFailedBox.isOpen && oldFailedBox.name != failedBoxName) {
       if (oldFailedBox.name == 'sync_failed_queue_v2') {
          for (var key in oldFailedBox.keys) {
             await _failedQueueBox!.add(oldFailedBox.get(key));
          }
          await oldFailedBox.clear();
       }
       await oldFailedBox.close();
    }
    
    notifyListeners();
  }

  Future<void> setActiveStoreId(String? id) async {
    if (_activeStoreId == id) return;

    _activeStoreId = id;
    _cachedSubscriptionPlan = null; // Clear cache on store change
    
    // Clear counts immediately for fresh UI feedback
    _cloudOrdersCount = -1;
    _cloudInventoryCount = -1;
    _cloudCustomersCount = -1;
    _cloudSettingsCount = -1;
    _cloudEmployeesCount = -1;
    _cloudTablesCount = -1;
    _cloudFloorsCount = -1;
    _cloudSuppliersCount = -1;
    _cloudNotesCount = -1;
    
    _localEmployeesCount = 0;
    _localFloorsCount = 0;
    _localTablesCount = 0;
    _localSuppliersCount = 0;
    _localNotesCount = 0;
    
    await refreshLocalCounts();
    await _loadSyncFrequency();
    if (_hasCloudAccess && id != null) {
      unawaited(_preWarmCache(id));
      unawaited(processSync(forceManual: false));
    }
    notifyListeners();
  }

  Future<void> _preWarmCache(String storeId) async {
    _cachedSubscriptionPlan = await _getSubscriptionPlan(storeId);
    _cachedPlatformLimits = await retrievePlatformLimits();
    notifyListeners();
  }

  Future<void> processSync({bool forceManual = false, bool forceFull = false}) async {
    if (!_isOnline || _isBusy || _activeStoreId == null || !_hasCloudAccess) return;
    
    // Hardened check for Mobile
    if (!kIsWeb && !forceManual) {
       final hasRealInternet = await _checkActualConnectivity();
       if (!hasRealInternet) return;
    }

    _isBusy = true;
    _setStatus("Syncing...");
    _logSyncEvent("Sync Started (ForceFull: $forceFull, Manual: $forceManual)");

    try {
      _lastSyncError = null;

      // OFFLINE-FIRST: ALWAYS push outbound queue first (local → cloud).
      // This ensures locally-created data (inventory, orders, etc.) reaches the cloud
      // regardless of subscription plan throttling. Data safety > plan enforcement.
      await _processOutboundQueue(forceManual: forceManual);

      // Subscription-based throttling applies ONLY to inbound pull (cloud → local).
      bool shouldPullInbound = forceManual; // Manual sync always pulls

      if (!forceManual) {
        final plan = await _getSubscriptionPlan(_activeStoreId);
        bool isBasic = (plan == 'Basic');
        bool isStarting = (plan == 'Starting');
        bool hasAddon = await _hasDataCenterAddon(_activeStoreId);

        if (isStarting && _userRole != 'Super Admin') {
          // Starting Plan: no auto inbound pull (manual only)
          shouldPullInbound = false;
        } else if (isBasic && _userRole != 'Super Admin' && !hasAddon) {
          final limits = await retrievePlatformLimits();
          final freq = limits['sync_frequency_str'] ?? '1_DAY';
          shouldPullInbound = _shouldPullBasedOnFrequency(freq);
        } else if (!isStarting && _userRole != 'Super Admin' && !hasAddon) {
          // Standard Plan WITHOUT Data Center
          final limits = await retrievePlatformLimits();
          final freq = limits['sync_frequency_str'] ?? '1_DAY';
          shouldPullInbound = _shouldPullBasedOnFrequency(freq);
        } else if (_userRole != 'Super Admin') {
          // Data Center Addon active
          if (_syncFrequency == 'MANUAL') {
            shouldPullInbound = false;
          } else if (_syncFrequency == 'LIVE') {
            shouldPullInbound = true;
          } else {
            shouldPullInbound = _shouldPullBasedOnFrequency(_syncFrequency);
          }
        } else {
          shouldPullInbound = true; // Super Admin always pulls
        }
      }

      if (shouldPullInbound) {
        await _processInboundUpdates(forceFull: forceFull);
      }
      
      _lastSyncTime = DateTime.now();
      // Global sync time for throttling
      if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
      await Hive.box('settings').put('last_sync_time_$_activeStoreId', _lastSyncTime!.millisecondsSinceEpoch);
      
      _setStatus("Synced");
      _logSyncEvent("Sync Completed Successfully");
      await refreshCloudCounts();
      await _reportUsage(); // NEW: Report usage stats to cloud for Super Admin visibility

      // Basic Plan Retention Cleanup (Skip if Standard Plan)
      final plan = await _getSubscriptionPlan(_activeStoreId);
      if ((plan == 'Basic') && _activeStoreId != null && shouldPullInbound) {
         final limits = await retrievePlatformLimits();
         final retentionDays = limits['cloud_retention_days'] ?? 30;
         await _performCloudRetentionCleanup(_activeStoreId!, retentionDays);
      }

    } catch (e) {
      _setStatus("Sync Failed");
      _logSyncEvent("Sync Failed: $e", isError: true);
    } finally {
      await refreshLocalCounts(notify: false);
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Helper: Determine if inbound pull should happen based on frequency setting
  bool _shouldPullBasedOnFrequency(String freq) {
    if (_lastSyncTime == null) return true; // First sync always pulls
    final diff = DateTime.now().difference(_lastSyncTime!);
    if (freq == '1_DAY' || freq == 'DAILY') return diff.inHours >= 24;
    if (freq == '1_WEEK' || freq == 'WEEKLY') return diff.inDays >= 7;
    if (freq == '1_MONTH') return diff.inDays >= 30;
    return true; // Unknown frequency = pull
  }

  Future<void> _performCloudRetentionCleanup(String storeId, int retentionDays) async {
     final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
     final timestamp = Timestamp.fromDate(cutoff);
     
     // 1. Cleanup Orders
     try {
        final oldOrders = await _db.collection('orders')
           .where('storeId', isEqualTo: storeId)
           .where('createdAt', isLessThan: timestamp)
           .get();
        
        if (oldOrders.docs.isNotEmpty) {
           final batch = _db.batch();
           for (var doc in oldOrders.docs) {
              batch.delete(doc.reference);
           }
           await batch.commit();
        }
     } catch (e) { /* Ignore cleanup errors */ }

     // 2. Cleanup Activity Logs
     try {
        final oldLogs = await _db.collection('activity_logs')
           .where('storeId', isEqualTo: storeId)
           .where('timestamp', isLessThan: timestamp)
           .get();
        
        if (oldLogs.docs.isNotEmpty) {
           final batch = _db.batch();
           for (var doc in oldLogs.docs) {
              batch.delete(doc.reference);
           }
           await batch.commit();
        }
     } catch (e) { /* Ignore cleanup errors */ }
  }

   Future<void> _processOutboundQueue({bool forceManual = false}) async {
    if (_queueBox == null || _queueBox!.isEmpty) return;
    
    final Map<dynamic, dynamic> queueMap = _queueBox!.toMap();
    final sortedKeys = queueMap.keys.toList()..sort();
    
    // STALE ITEM CLEANUP: Remove items older than 7 days that are clearly orphaned
    final now = DateTime.now().millisecondsSinceEpoch;
    const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
    final List<dynamic> staleKeys = [];
    for (var key in sortedKeys) {
      final val = queueMap[key] as Map;
      final createdAt = val['createdAt'] as int? ?? now;
      final retryCount = val['retryCount'] ?? 0;
      if ((now - createdAt) > sevenDaysMs && retryCount > 3) {
        staleKeys.add(key);
      }
    }
    if (staleKeys.isNotEmpty) {
      debugPrint('🧹 SYNC: Cleaning ${staleKeys.length} stale queue items (>7 days old with retries)');
      for (var key in staleKeys) {
        _failedQueueBox?.put(key, queueMap[key]);
      }
      await _queueBox!.deleteAll(staleKeys);
      notifyListeners();
      return; // Re-enter on next cycle with a clean queue
    }
    
    // Filter to only items belonging to the current store
    final List<dynamic> eligibleKeys = [];
    for (var key in sortedKeys) {
      final val = queueMap[key] as Map;
      final retryCount = val['retryCount'] ?? 0;
      
      // RETRY LIMIT: Move items that have failed too many times to the failed queue
      if (retryCount > 5 && !forceManual) { 
         debugPrint("🚫 SYNC: Moving stuck item $key to failed queue (Retries: $retryCount)");
         _failedQueueBox?.put(key, val);
         await _queueBox!.delete(key);
         continue; 
      }

      // STORE ISOLATION: Skip items from other stores
      final payload = val['payload'] is Map ? Map<String, dynamic>.from(val['payload']) : <String, dynamic>{};
      final itemStoreId = (val['activeStoreId'] ?? payload['storeId'] ?? '').toString().trim();
      if (_activeStoreId != null && itemStoreId.isNotEmpty && itemStoreId != _activeStoreId) {
         continue; // Skip — belongs to another store
      }
      
      eligibleKeys.add(key);
    }
    
    if (eligibleKeys.isEmpty) return;
    
    // Process in small sub-batches of 20 to isolate failures
    const int subBatchSize = 20;
    for (int i = 0; i < eligibleKeys.length; i += subBatchSize) {
      final chunkKeys = eligibleKeys.sublist(i, (i + subBatchSize) > eligibleKeys.length ? eligibleKeys.length : i + subBatchSize);
      
      // Try batch commit first (fast path)
      bool batchSuccess = await _tryBatchCommit(chunkKeys, queueMap);
      
      if (!batchSuccess) {
        // FALLBACK: Process items individually so one bad item doesn't block others
        debugPrint('⚠️ SYNC: Batch failed, falling back to individual processing for ${chunkKeys.length} items');
        for (var key in chunkKeys) {
          await _trySingleItemCommit(key, queueMap);
        }
      }
    }
    
    notifyListeners();
   }
  
  /// Attempt to commit a batch of queue items. Returns true on success.
  Future<bool> _tryBatchCommit(List<dynamic> keys, Map<dynamic, dynamic> queueMap) async {
    final batch = _db.batch();
    final List<dynamic> processedInThisBatch = [];
    
    for (var key in keys) {
      final val = queueMap[key] as Map;
      try {
        final collection = val['collection'] as String;
        final docId = val['docId'] as String;
        final type = val['type'];
        final payload = Map<String, dynamic>.from(val['payload']);
        
        String finalPath = collection;
        String moduleName = finalPath.contains('/') ? finalPath.split('/').last : finalPath;

        // Ensure storeId is present in payload
        if (['orders', 'inventory', 'customers', 'employees', 'floors', 'tables', 'suppliers', 'notes', 'settings', 'inventory_movements', 'business_events', 'counters', 'activity_logs'].contains(moduleName)) {
            if ((payload['storeId'] == null || payload['storeId'].toString().isEmpty) && _activeStoreId != null) {
               payload['storeId'] = _activeStoreId!.trim();
            }
        }

        payload['deviceId'] = payload['deviceId'] ?? _deviceId;
        payload['lastModifiedBy'] = _deviceId;

        DocumentReference ref = _db.collection(finalPath).doc(docId);
        payload['updatedAt'] = FieldValue.serverTimestamp();
        payload['syncedAt'] = FieldValue.serverTimestamp();

        if (type == 'CREATE' || type == 'UPDATE') {
          batch.set(ref, payload, SetOptions(merge: true));
        } else if (type == 'DELETE') {
          batch.delete(ref);
        }
        processedInThisBatch.add(key);
      } catch (e) {
        // Item-level error during prep — skip this item
        final retryCount = (val['retryCount'] ?? 0) + 1;
        val['retryCount'] = retryCount;
        _queueBox!.put(key, val);
      }
    }
    
    if (processedInThisBatch.isEmpty) return true;
    
    try {
      await batch.commit();
      
      // Success: Mark items as PUSHED and remove from queue
      for (var key in processedInThisBatch) {
        final val = queueMap[key] as Map;
        final col = val['collection'] as String;
        final id = val['docId'] as String;
        
        // SQLite: Mark as PUSHED
        if (!kIsWeb) {
          try { await _repository.markAsPushed(col, id); } catch (_) {}
        }
        
        // Hive: Mark as PUSHED
        for (var m in ['orders', 'inventory', 'customers', 'employees', 'floors', 'tables', 'suppliers', 'notes', 'settings']) {
          if (col.endsWith(m)) {
            final b = _getBoxName(m);
            if (b != null) {
              try {
                final box = await Hive.openBox(b);
                final v = box.get(id);
                if (v is Map) {
                  final mv = Map<String, dynamic>.from(v);
                  mv['syncStatus'] = 'PUSHED';
                  mv['syncedAt'] = DateTime.now().toIso8601String();
                  await box.put(id, mv);
                }
              } catch (_) {}
            }
            break;
          }
        }
      }
      
      await _queueBox!.deleteAll(processedInThisBatch);
      return true;
    } catch (e) {
      _lastSyncError = "Batch Error: $e";
      debugPrint('❌ SYNC: Batch commit failed: $e');
      return false; // Signal caller to use individual fallback
    }
  }
  
  /// Attempt to commit a single queue item. Used as fallback when batch fails.
  Future<void> _trySingleItemCommit(dynamic key, Map<dynamic, dynamic> queueMap) async {
    final val = queueMap[key];
    if (val == null || val is! Map) {
      await _queueBox!.delete(key);
      return;
    }
    
    try {
      final collection = val['collection'] as String;
      final docId = val['docId'] as String;
      final type = val['type'];
      final payload = Map<String, dynamic>.from(val['payload']);
      
      String finalPath = collection;
      String moduleName = finalPath.contains('/') ? finalPath.split('/').last : finalPath;

      if (['orders', 'inventory', 'customers', 'employees', 'floors', 'tables', 'suppliers', 'notes', 'settings', 'inventory_movements', 'business_events', 'counters', 'activity_logs'].contains(moduleName)) {
          if ((payload['storeId'] == null || payload['storeId'].toString().isEmpty) && _activeStoreId != null) {
             payload['storeId'] = _activeStoreId!.trim();
          }
      }

      payload['deviceId'] = payload['deviceId'] ?? _deviceId;
      payload['lastModifiedBy'] = _deviceId;
      payload['updatedAt'] = FieldValue.serverTimestamp();
      payload['syncedAt'] = FieldValue.serverTimestamp();

      DocumentReference ref = _db.collection(finalPath).doc(docId);
      
      if (type == 'CREATE' || type == 'UPDATE') {
        await ref.set(payload, SetOptions(merge: true));
      } else if (type == 'DELETE') {
        await ref.delete();
      }
      
      // Success: Mark as PUSHED and remove from queue
      if (!kIsWeb) {
        try { await _repository.markAsPushed(collection, docId); } catch (_) {}
      }
      
      for (var m in ['orders', 'inventory', 'customers', 'employees', 'floors', 'tables', 'suppliers', 'notes', 'settings']) {
        if (collection.endsWith(m)) {
          final b = _getBoxName(m);
          if (b != null) {
            try {
              final box = await Hive.openBox(b);
              final v = box.get(docId);
              if (v is Map) {
                final mv = Map<String, dynamic>.from(v);
                mv['syncStatus'] = 'PUSHED';
                mv['syncedAt'] = DateTime.now().toIso8601String();
                await box.put(docId, mv);
              }
            } catch (_) {}
          }
          break;
        }
      }
      
      await _queueBox!.delete(key);
      debugPrint('✅ SYNC: Individual item committed: $collection/$docId');
    } catch (e) {
      debugPrint('❌ SYNC: Individual item FAILED ($key): $e');
      // Increment retry and leave in queue
      try {
        final updated = Map<String, dynamic>.from(val);
        updated['retryCount'] = (updated['retryCount'] ?? 0) + 1;
        updated['lastError'] = e.toString().substring(0, (e.toString().length > 100 ? 100 : e.toString().length));
        await _queueBox!.put(key, updated);
      } catch (_) {
        // If even updating fails, just delete this corrupted item
        await _queueBox!.delete(key);
      }
    }
  }

  Future<void> _processInboundUpdates({bool forceFull = false}) async {
    final modules = [
      'orders', 
      'inventory', 
      'customers', 
      'settings', 
      'employees', 
      'tables', 
      'floors', 
      'suppliers', 
      'notes',
      'inventory_movements' // Added for event sourcing
    ];
    
    // Parallelize pulls with individual error handling to prevent one failure from blocking all
    await Future.wait(modules.map((m) => _pullCollection(m, forceFull: forceFull).catchError((e) {
      debugPrint("❌ SyncService: Module pull failed ($m): $e");
    })));

    // REBUILD CACHE: After pulling movements, rebuild the quantity cache to ensure it matches the ledger
    if (_activeStoreId != null && !kIsWeb) {
      try {
        await _repository.rebuildQuantityCache(_activeStoreId!);
        debugPrint("✅ SyncService: Inventory quantity cache rebuilt for $_activeStoreId");
      } catch (e) {
        debugPrint("❌ SyncService: Failed to rebuild inventory cache: $e");
      }
    }
  }

  Future<void> _pullCollection(String collection, {bool forceFull = false}) async {

    try {
      // INCREMENTAL SYNC: Use delta queries (updatedAt > lastSyncTime) when possible.
      // Falls back to full scan gracefully if composite indexes are missing (see fallback on line ~575).
      bool bypassDelta = forceFull; // Only bypass delta when explicitly requesting a full sync
      // MOVED TO ROOT: floors, tables, employees, suppliers, notes
      // All these collections are root-level with storeId filtering.
      String finalPath = collection;
      
      // SPECIAL CASE: Settings are stored in the 'settings' collection (NOT 'stores')
      if (collection == 'settings') {
         finalPath = 'settings'; 
      }

      Query query = _db.collection(finalPath);
      
      // Filter by storeId ONLY for root collections
      if (['orders', 'inventory', 'customers', 'inventory_movements', 'business_events', 'counters', 'activity_logs', 'employees', 'floors', 'tables', 'suppliers', 'notes'].contains(collection)) {
          query = query.where('storeId', isEqualTo: _activeStoreId);
      } else if (collection == 'settings') {
          query = query.where(FieldPath.documentId, isEqualTo: _activeStoreId);
      }
      // For employees, floors, tables, suppliers, notes → no storeId filter needed (path-scoped)

      QuerySnapshot? snapshot;

      final lastSyncTime = await _getLastSyncTime(collection);
      if (lastSyncTime != null && !bypassDelta) {
         try {
            final deltaQuery = query.where('updatedAt', isGreaterThan: Timestamp.fromDate(lastSyncTime));
            snapshot = await deltaQuery.get();

            _lastSyncWarning = null; 
            _lastSyncError = null;
         } catch (e) {
             final err = e.toString();
             bool isIndexError = err.contains("failed-precondition") || err.contains("index");
             bool isPermissionDeniedWithUrl = err.contains("permission-denied") && err.contains("https://console.firebase.google.com");
             
             if (isIndexError || isPermissionDeniedWithUrl) {
                _lastIndexErrorUrl = _extractIndexLink(err);
                _lastSyncWarning = "Performance Warning ($collection): Missing index for delta sync. Using fallback.";
                
                if (_lastIndexErrorUrl != null) {
                   debugPrint("\n⚠️ MISSING INDEX DETECTED ($collection)");
                   debugPrint("To fix this, create the index here:");
                   debugPrint(_lastIndexErrorUrl);
                   debugPrint("");
                }
             } else {
                _lastSyncError = "Pull Error ($collection): $e";
             }
         }
      }

      snapshot ??= await query.get();

      final Set<String> cloudIds = {};
      
      // Open box once for performance (ALL PLATFORMS)
      Box? box;
      final boxName = _getBoxName(collection);
      if (boxName != null && !Hive.isBoxOpen(boxName)) {
          box = await Hive.openBox(boxName);
      } else if (boxName != null) {
          box = Hive.box(boxName);
      }

      for (var doc in snapshot.docs) {
        try {
           final data = doc.data() as Map<String, dynamic>;
           final cloudUpdatedAt = _parseDate(data['serverUpdatedAt'] ?? data['updatedAt']);

           // VERSION-BASED CONFLICT RESOLUTION (Local-First)
           // Local DB is the source of truth. Only accept cloud data if:
           // 1. Local item doesn't exist yet (new from cloud), OR
           // 2. Cloud version is strictly higher than local version, OR
           // 3. Local item is already CONFIRMED (safe to overwrite with newer cloud)
           // NEVER overwrite local PENDING or PUSHED items (they haven't completed round-trip)
           bool shouldUpdate = true;
           final int cloudVersion = (data['version'] ?? 1) is int ? (data['version'] ?? 1) : int.tryParse(data['version'].toString()) ?? 1;
           if (box != null) {
              final String docKey = doc.id;
              final localData = box.get(docKey);
              if (localData is Map) {
                  final localSyncStatus = localData['syncStatus']?.toString() ?? '';
                  final localVersion = (localData['version'] ?? 1) is int ? (localData['version'] ?? 1) : int.tryParse(localData['version']?.toString() ?? '1') ?? 1;
                  
                  // RULE 0 (ZOMBIE PROTECTION): deletedAt always wins.
                  // If cloud says item is deleted, accept the deletion regardless of local version.
                  // This prevents "zombie records" where a deleted item is resurrected by a stale device.
                  final cloudDeletedAt = _parseDate(data['deletedAt']);
                  final localDeletedAt = _parseDate(localData['deletedAt']?.toString());
                  
                  if (cloudDeletedAt != null && localDeletedAt == null && localSyncStatus != 'PENDING' && localSyncStatus != 'PUSHED') {
                     // Cloud deleted, local didn't (and local has no unsynced changes) → accept deletion
                     // Let it fall through to the isDeleted handler below
                  } else if (localDeletedAt != null && cloudDeletedAt == null && (localSyncStatus == 'PENDING' || localSyncStatus == 'PUSHED')) {
                     // Local deleted with unsynced changes, cloud hasn't seen it → preserve local delete
                     cloudIds.add(doc.id);
                     continue;
                  } else {
                     // RULE 1: Never overwrite items that are still in transit (PENDING/PUSHED)
                     if (localSyncStatus == 'PENDING' || localSyncStatus == 'PUSHED') {
                        // Local has unsynced changes - skip cloud version
                        cloudIds.add(doc.id); // Still track it as seen in cloud
                        continue; 
                     }
                     
                     // RULE 2: Only accept cloud if its version is strictly higher
                     if (cloudVersion < localVersion && localSyncStatus == 'CONFIRMED') {
                        cloudIds.add(doc.id); // Track as seen
                        continue; // Local has newer version
                     }
                     
                     // RULE 3 (TIEBREAKER): If versions are equal, use timestamp as tiebreaker
                     if (cloudVersion == localVersion && localSyncStatus == 'CONFIRMED') {
                        final cloudUpdated = _parseDate(data['updatedAt']);
                        final localUpdated = _parseDate(localData['updatedAt']?.toString());
                        
                        if (cloudUpdated != null && localUpdated != null && !cloudUpdated.isAfter(localUpdated)) {
                           cloudIds.add(doc.id);
                           continue; // Local is same or more recent — skip
                        }
                        // else: Cloud is more recent — accept update (fall through)
                     }
                  }
              }
           }

           cloudIds.add(doc.id);
           bool isDeleted = data['deletedAt'] != null || data['isDeleted'] == true || data['isDeleted'] == 1;
           
           if (isDeleted) {
              if (!kIsWeb) {
                  // SQLite: Mark as deleted using isDeleted flag (soft delete)
                  final sqlTable = collection == 'settings' ? 'store_settings' : collection;
                  if (['orders', 'inventory', 'customers', 'employees', 'settings', 'floors', 'tables', 'suppliers', 'notes'].contains(collection)) {
                    try {
                      // Use repository to soft-delete and mark as confirmed from cloud
                      await _repository.deleteOfflineEntity(sqlTable, doc.id);
                      // Override syncStatus to CONFIRMED since this delete came from cloud
                      await _repository.markAsConfirmed(sqlTable, doc.id);
                    } catch (_) {}
                  }
              }
              // Hive Delete (All Platforms if box exists)
              if (box != null) {
                 await box.delete(doc.id);
              }
              continue; 
           }
           
           data['syncStatus'] = 'CONFIRMED';
           data['id'] = doc.id; 
           final sanitizedData = _deepSanitize(data);

           // 1. Hive Write (ALL PLATFORMS - Metadata & Cache)
           if (box != null) {
              if (collection == 'settings') {
                 await box.put(doc.id, sanitizedData);
              } else {
                 await box.put(doc.id, sanitizedData);
              }
           }

           // 2. SQLite Write (MOBILE/DESKTOP - Heavy Data)
           if (!kIsWeb) {
              try {
                if (collection == 'orders') {
                  await _repository.insertOrder(OrderModel.fromMap(data, doc.id));
                } else if (collection == 'inventory') {
                    final item = InventoryItem.fromMap(data, doc.id);
                    await _repository.insertInventory(item);
                    
                    // SAFE INVENTORY SYNC: Reconcile cloud quantity with local pending (unsynced) movements
                    // Rule: Local Cache = Cloud Quantity + Local Pending Delta
                    final cloudQuantity = _parseInt(data['quantity']);
                    final pendingDelta = await _repository.getPendingInventoryDelta(doc.id, storeId: data['storeId']);
                    final safeQuantity = cloudQuantity + pendingDelta;
                    
                    await _repository.updateInventoryCache(doc.id, safeQuantity, data['storeId'] ?? '');
                } else if (collection == 'customers') {
                  await _repository.insertCustomer(Customer.fromMap(data, doc.id));
                 } else if (collection == 'employees') {
                   await _repository.insertEmployee(UserProfile.fromMap(data, doc.id));
                } else if (collection == 'settings') {
                  await _repository.insertStoreSettings(doc.id, sanitizedData);
                } else if (collection == 'floors') {
                  await _repository.insertFloor(doc.id, sanitizedData['storeId'] ?? '', sanitizedData);
                } else if (collection == 'tables') {
                  await _repository.insertTable(doc.id, sanitizedData['storeId'] ?? '', sanitizedData);
                } else if (collection == 'suppliers') {
                  await _repository.insertSupplier(doc.id, sanitizedData['storeId'] ?? '', sanitizedData);
                } else if (collection == 'notes') {
                  await _repository.insertNote(doc.id, sanitizedData['storeId'] ?? '', sanitizedData);
                } else if (collection == 'inventory_movements') {
                  await _repository.insertMovement(InventoryMovement.fromMap(data, doc.id));
                }
              } catch (parseError) { /* Error ignored */ }
           }
        } catch (e) { /* Error ignored */ }
      }

      // RECONCILIATION: State-driven cleanup for full syncs
      // RULE: Only remove items that are CONFIRMED + isDeleted, or missing from cloud while CONFIRMED
      if (forceFull && _activeStoreId != null) {
         try {
            final boxName = _getBoxName(collection);
            if (boxName != null) {
               final box = await Hive.openBox(boxName);
               final keysToDelete = [];
               for (var key in box.keys) {
                  if (collection == 'settings' && key.toString().startsWith('store_settings_')) {
                     // Keep track of settings related to current store only
                     final val = box.get(key);
                     if (val is Map && key.toString() == 'store_settings_$_activeStoreId' && !cloudIds.contains(_activeStoreId)) {
                        keysToDelete.add(key);
                     }
                     continue; 
                  }
                  final val = box.get(key);
                  if (val is Map) {
                     final vStoreId = (val['storeId'] ?? '').toString().trim().toLowerCase();
                     final status = val['syncStatus'] ?? '';
                     final isDeletedFlag = val['isDeleted'] == true || val['isDeleted'] == 1;
                     
                     // STATE-DRIVEN RECONCILIATION:
                     // Only delete from Hive if:
                     // 1. Item belongs to this store
                     // 2. Item is NOT in cloud snapshot
                     // 3. Item is CONFIRMED (has completed a round-trip)
                     // 4. Item is NOT pending/pushed (has no unsynced local changes)
                     // Items with PENDING or PUSHED status are NEVER removed from cache
                     if (vStoreId == _activeStoreId!.trim().toLowerCase() && 
                         !cloudIds.contains(key.toString()) && 
                         status == 'CONFIRMED' &&
                         isDeletedFlag) {
                        keysToDelete.add(key);
                     }
                  }
               }
               if (keysToDelete.isNotEmpty) {
                  await box.deleteAll(keysToDelete);
               }
            }
            
            // 2. SQLite Reconciliation (MOBILE/DESKTOP) - Uses the new state-driven deleteOrphans
            if (!kIsWeb && ['orders', 'inventory', 'customers', 'employees', 'floors', 'tables', 'suppliers', 'notes'].contains(collection)) {
               final table = collection;
               await _repository.deleteOrphans(table, _activeStoreId!, cloudIds.toList());
            }
         } catch (e) { /* Error ignored */ }
      }

      // If we got here, pull was successful 
      if (['customers', 'settings', 'orders', 'inventory', 'employees', 'floors', 'tables', 'suppliers', 'notes'].contains(collection)) {
         await _saveLastSyncTime(collection, DateTime.now());
         _lastSyncError = null; 
          // Retain _lastSyncWarning if it was set during fallback, but clear error
      }
    } catch (e) {
      _lastSyncError = "Pull Error ($collection): $e";
    }
  }

  void _setStatus(String status) {
    if (_syncStatus != status) {
      _syncStatus = status;
      notifyListeners();
    }
  }

  Future<void> refreshLocalCounts({bool notify = true}) async {
    if (_activeStoreId == null) return;
    final String currentStoreId = _activeStoreId!.trim();
    
    // ALWAYS GET METADATA FROM HIVE (ALL PLATFORMS)
    try {
        final boxNameEmp = _getBoxName('employees');
        if (boxNameEmp != null) {
            final box = await Hive.openBox(boxNameEmp);
            _localEmployeesCount = box.values.where((v) {
                if (v is! Map) return false;
                final vStoreId = (v['storeId'] ?? '').toString().trim().toLowerCase();
                return vStoreId == currentStoreId.toLowerCase() && (v['deletedAt'] == null || v['deletedAt'] == false);
            }).length;
        }

        final boxNameFlr = _getBoxName('floors');
        if (boxNameFlr != null) {
            final box = await Hive.openBox(boxNameFlr);
            _localFloorsCount = box.values.where((v) {
                if (v is! Map) return false;
                final vStoreId = (v['storeId'] ?? '').toString().trim().toLowerCase();
                return vStoreId == currentStoreId.toLowerCase() && (v['deletedAt'] == null || v['deletedAt'] == false);
            }).length;
        }

        final boxNameTbl = _getBoxName('tables');
        if (boxNameTbl != null) {
            final box = await Hive.openBox(boxNameTbl);
            _localTablesCount = box.values.where((v) {
                if (v is! Map) return false;
                final vStoreId = (v['storeId'] ?? '').toString().trim().toLowerCase();
                return vStoreId == currentStoreId.toLowerCase() && (v['deletedAt'] == null || v['deletedAt'] == false);
            }).length;
        }

        final boxNameSup = _getBoxName('suppliers');
        if (boxNameSup != null) {
            final box = await Hive.openBox(boxNameSup);
            _localSuppliersCount = box.values.where((v) {
                if (v is! Map) return false;
                final vStoreId = (v['storeId'] ?? '').toString().trim().toLowerCase();
                return vStoreId == currentStoreId.toLowerCase() && (v['deletedAt'] == null || v['deletedAt'] == false);
            }).length;
        }

        final boxNameNotes = _getBoxName('notes');
        if (boxNameNotes != null) {
            final box = await Hive.openBox(boxNameNotes);
            _localNotesCount = box.values.where((v) {
                if (v is! Map) return false;
                final vStoreId = (v['storeId'] ?? '').toString().trim().toLowerCase();
                return vStoreId == currentStoreId.toLowerCase() && (v['deletedAt'] == null || v['deletedAt'] == false);
            }).length;
        }

        if (Hive.isBoxOpen('cache_settings')) {
            final box = Hive.box('cache_settings');
            _localSettingsCount = box.containsKey(currentStoreId) ? 1 : 0; 
        } else {
            final box = await Hive.openBox('cache_stores');
            _localSettingsCount = box.containsKey('store_settings_$currentStoreId') ? 1 : 0; 
        }

    } catch (e) { /* Error ignored */ }

    if (kIsWeb) {
        // WEB: Use Hive for Heavy Data Counts (Filtered by Store)
        try {
            final modules = ['orders', 'inventory', 'customers', 'employees', 'floors', 'tables', 'suppliers', 'notes'];
            
            final List<Future<int>> countingFutures = modules.map((mod) async {
               final boxName = _getBoxName(mod);
               if (boxName == null) return 0;
               final box = await Hive.openBox(boxName);
               return box.values.where((v) {
                  if (v is! Map) return false;
                  final vStoreId = (v['storeId'] ?? '').toString().trim().toLowerCase();
                  return vStoreId == currentStoreId.toLowerCase() && (v['deletedAt'] == null || v['deletedAt'] == false);
               }).length;
            }).toList();

            final results = await Future.wait(countingFutures);
            _localOrdersCount = results[0];
            _localInventoryCount = results[1];
            _localCustomersCount = results[2];
            _localEmployeesCount = results[3];
            _localFloorsCount = results[4];
            _localTablesCount = results[5];
            _localSuppliersCount = results[6];
            _localNotesCount = results[7];
        } catch (e) { /* Error ignored */ }
    } else {
       // MOBILE/DESKTOP: Use SQLite Repository for Heavy Data
       _localOrdersCount = await _repository.getOrderCount(currentStoreId);
       _localInventoryCount = await _repository.getInventoryCount(currentStoreId);
       _localCustomersCount = await _repository.getCustomerCount(currentStoreId);
       _localEmployeesCount = await _repository.getEmployeeCount(currentStoreId);
       _localFloorsCount = await _repository.getFloorCount(currentStoreId);
       _localTablesCount = await _repository.getTableCount(currentStoreId);
       // Suppliers & Notes: Use Hive counts (already set above from metadata section)
       // If Hive counts are still 0, fall back to repository
       if (_localSuppliersCount == 0) {
          try {
            _localSuppliersCount = await _repository.getSupplierCount(currentStoreId);
          } catch (_) { /* repository may not have this method yet */ }
       }
       if (_localNotesCount == 0) {
          try {
            _localNotesCount = await _repository.getNoteCount(currentStoreId);
          } catch (_) { /* repository may not have this method yet */ }
       }
    }
    
     if (_isOnline) await refreshCloudCounts(notify: false);
     if (notify) notifyListeners();
   }

  int _cloudOrdersCount = -1;
  int _cloudInventoryCount = -1;
  int _cloudCustomersCount = -1;
  int _cloudSettingsCount = -1;
  int _cloudEmployeesCount = -1;
  int _cloudTablesCount = -1;
  int _cloudFloorsCount = -1;
  int _cloudSuppliersCount = -1;
  int _cloudNotesCount = -1;

  int get cloudOrdersCount => _cloudOrdersCount;
  int get cloudInventoryCount => _cloudInventoryCount;
  int get cloudCustomersCount => _cloudCustomersCount;
  int get cloudSettingsCount => _cloudSettingsCount;
  int get cloudEmployeesCount => _cloudEmployeesCount;
  int get cloudTablesCount => _cloudTablesCount;
  int get cloudFloorsCount => _cloudFloorsCount;
  int get cloudSuppliersCount => _cloudSuppliersCount;
  int get cloudNotesCount => _cloudNotesCount;

  Future<void> refreshCloudCounts({bool notify = true}) async {
    if (!_isOnline || _activeStoreId == null) return;

    try {
      _cloudOrdersCount = await _getCloudCount('orders', _activeStoreId);
      _cloudInventoryCount = await _getCloudCount('inventory', _activeStoreId);
      _cloudCustomersCount = await _getCloudCount('customers', _activeStoreId);
    } catch (e) {
      _cloudCustomersCount = -1;
    }

    try {
      final String sid = _activeStoreId!.trim();
      final qSets = await _db.collection('settings').doc(sid).get();
      _cloudSettingsCount = qSets.exists ? 1 : 0;
    } catch (e) {
      _cloudSettingsCount = 0;
    }

    _cloudEmployeesCount = await _getCloudCount('employees', _activeStoreId);
    _cloudFloorsCount = await _getCloudCount('floors', _activeStoreId);
    _cloudTablesCount = await _getCloudCount('tables', _activeStoreId);
    _cloudSuppliersCount = await _getCloudCount('suppliers', _activeStoreId);
    _cloudNotesCount = await _getCloudCount('notes', _activeStoreId);

    if (notify) notifyListeners();
  }

   Future<int> _getCloudCount(String collection, String? storeId) async {
      try {
         // ALL MOVED TO ROOT: floors, tables, employees, suppliers, notes
         // Root collections need storeId filter; subcollections are no longer used.
         Query query = _db.collection(collection);
         
         if (storeId != null) {
            query = query.where('storeId', isEqualTo: storeId);
         }
         
         final snapshot = await query.get();
         final validDocs = snapshot.docs.where((d) => (d.data() as Map)['deletedAt'] == null).length;
         
         debugPrint("SYNC: _getCloudCount - $collection Found ${snapshot.size} docs, Valid: $validDocs");
         return validDocs;
      } catch (e) {
         debugPrint("SYNC: _getCloudCount ERROR ($collection): $e");
         return -1;
      }
   }

  String? _getBoxName(String collection) {
    final sid = _activeStoreId;
    switch (collection) {
      case 'orders': return 'cache_orders';
      case 'inventory': return 'cache_inventory';
      case 'customers': return 'cache_customers';
      case 'employees': return sid != null ? 'cache_employees_$sid' : 'cache_employees';
      case 'floors': return sid != null ? 'cache_floors_$sid' : 'cache_floors';
      case 'tables': return sid != null ? 'cache_tables_$sid' : 'cache_tables';
      case 'suppliers': return sid != null ? 'cache_suppliers_$sid' : 'cache_suppliers';
      case 'notes': return sid != null ? 'cache_notes_$sid' : 'cache_notes';
      case 'settings': return 'cache_settings';
      default: return null;
    }
  }

  String? _extractIndexLink(String error) {
    if (!error.contains("https://console.firebase.google.com")) return null;
    try {
      final start = error.indexOf("https://console.firebase.google.com");
      final end = error.indexOf(" ", start);
      if (end == -1) return error.substring(start).replaceAll("]", "").replaceAll(")", "");
      return error.substring(start, end).replaceAll("]", "").replaceAll(")", "");
    } catch (e) { return null; }
  }

  Future<String> inspectCloudData() async {
     if (_activeStoreId == null) return "No Store Selected";
     StringBuffer sb = StringBuffer();
     sb.writeln("=== CLOUD INSPECTOR (${DateTime.now()}) ===");
     sb.writeln("Active Store ID: $_activeStoreId");
     
     final user = FirebaseAuth.instance.currentUser;
     if (user != null) {
        sb.writeln("Auth UID: ${user.uid}");
        try {
          final userDoc = await _db.collection('users').doc(user.uid).get();
          if (userDoc.exists) {
            final uData = userDoc.data()!;
            sb.writeln("DB User Profile:");
            sb.writeln(" - Role: ${uData['role']}");
            sb.writeln(" - Profile storeId: ${uData['storeId']}");
            sb.writeln(" - accessibleStoreIds: ${uData['accessibleStoreIds']}");
            sb.writeln(" - storeIds: ${uData['storeIds']}");
          } else {
            sb.writeln("!!! USER DOC NOT FOUND !!!");
          }
        } catch (e) { sb.writeln("User Doc Fetch Error: $e"); }
     }

     try {
       final orders = await _db.collection('orders').where('storeId', isEqualTo: _activeStoreId).limit(3).get();
       sb.writeln("\n[ORDERS] Visible: ${orders.docs.length}");
       for(var d in orders.docs) {
         sb.writeln(" - ${d.id}: ${d.data()['status']}");
       }
     } catch (e) { sb.writeln("\nOrders Fetch Error: $e"); }

     return sb.toString();
  }

  Future<void> forceSyncDown() async {
      _lastSyncTime = null;
      if (Hive.isBoxOpen('settings') && _activeStoreId != null) {
         await Hive.box('settings').delete('last_sync_time_$_activeStoreId');
      }
      await processSync(forceManual: true, forceFull: true);
  }

  Future<void> nuclearReset() async {
      if (_activeStoreId == null) return;
      _setStatus("Nuclear Reset...");
      await clearStoreCache(_activeStoreId!);
      await forceSyncDown();
  }

  Future<void> clearStoreCache(String storeId) async {

      final sid = storeId.trim().toLowerCase();
      
      final modules = [
        'orders', 'inventory', 'customers', 'employees', 'floors', 'tables', 'suppliers', 'notes'
      ];
      for (var mod in modules) {
         try {
            final boxName = _getBoxName(mod);
            if (boxName == null) continue;

            final box = await Hive.openBox(boxName);
            final keysToDelete = [];
            for (var key in box.keys) {
               final val = box.get(key);
               if (val is Map) {
                  final vStoreId = (val['storeId'] ?? '').toString().trim().toLowerCase();
                  if (vStoreId == sid) keysToDelete.add(key);
               } else if (boxName.contains(sid)) {
                  // If box is store-specific, we might clear everything, 
                  // but keep it safe by checking keys or identifying by boxName
                  keysToDelete.add(key);
               }
            }
            if (keysToDelete.isNotEmpty) {
               await box.deleteAll(keysToDelete);

            }
         } catch (e) { /* Error ignored */ }
      }
      
      // Clear settings for this store too
      try {
         final sBox = await Hive.openBox('settings');
         await sBox.delete('store_settings_$storeId');
         await sBox.delete('last_sync_time_$storeId');
      } catch (e) { /* Error ignored */ }
      
      await refreshLocalCounts();
      notifyListeners();
  }

  Future<void> clearAllLocalData() async {
      if (_queueBox != null) await _queueBox!.clear();
      if (Hive.isBoxOpen('settings')) await Hive.box('settings').clear();
  }

  Future<void> resetQueueRetries() async {
      if (_queueBox == null) return;
      for (var key in _queueBox!.keys) {
          final val = _queueBox!.get(key);
          if (val is Map) {
             val['retryCount'] = 0;
             await _queueBox!.put(key, val);
          }
      }
      notifyListeners();
  }

  Future<void> queueOperation({required String collection, required String docId, required String action, required Map<String, dynamic> payload}) async {
    if (_queueBox == null) return;

    // Deduplication Logic: Find if there's already a pending operation for this document
    dynamic existingKey;
    try {
      existingKey = _queueBox!.keys.firstWhere((k) {
        final val = _queueBox!.get(k);
        return val is Map && val['collection'] == collection && val['docId'] == docId;
      }, orElse: () => null);
    } catch (_) {
      existingKey = null;
    }

    final data = {
      'type': action.toUpperCase(), 
      'collection': collection, 
      'docId': docId, 
      'payload': payload, 
      'retryCount': 0, 
      'activeStoreId': _activeStoreId, // Tag with current store for filtering
      'createdAt': DateTime.now().millisecondsSinceEpoch
    };

    if (existingKey != null) {
      // Update existing pending operation with the latest payload
      await _queueBox!.put(existingKey, data);
    } else {
      // Add new operation to the queue
      await _queueBox!.add(data);
    }

    if (_isOnline && _hasCloudAccess) {
       // Fire and forget - don't block the UI for sync initiation
       unawaited(processSync());
    }
  }

  // --- SUBSCRIPTION & LIMITS ---
   // --- SUBSCRIPTION & LIMITS ---
    Future<Map<String, dynamic>> retrievePlatformLimits() async {
     // 1. Try Cache First (Fastest)
     if (_cachedPlatformLimits != null) return _cachedPlatformLimits!;

     if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        final val = box.get('platform_limits');
        if (val != null && val is Map) {
           _cachedPlatformLimits = {
              'daily': val['daily'] ?? 50,
              'monthly': val['monthly'] ?? 1500,
              // Add-on Rates (Default 0)
              'rate_customer_management': val['rate_customer_management'] ?? 0,
              'rate_franchise_management': val['rate_franchise_management'] ?? 0,
              'rate_central_catalog': val['rate_central_catalog'] ?? 0,
              'rate_employee_management': val['rate_employee_management'] ?? 0,
              'rate_supplier_management': val['rate_supplier_management'] ?? 0,
              'rate_kds_management': val['rate_kds_management'] ?? 0,
               'rate_table_reservation': val['rate_table_reservation'] ?? 0,
               'rate_data_center': val['rate_data_center'] ?? 0,
               'rate_integration_hub': val['rate_integration_hub'] ?? 0,
               'sync_frequency_str': (val['sync_frequency_str'] ?? '1_DAY').toString(),
               'cloud_retention_days': val['cloud_retention_days'] ?? 30,
            };
            return _cachedPlatformLimits!;
        }
     }

     // 2. Try Cloud (If Online)
     if (_isOnline) {
        try {
           final doc = await _db.collection('settings').doc('platform_limits').get();
           if (doc.exists) {
              final data = doc.data()!;
              final limits = {
                 'daily': _parseLimit(data['daily'] ?? data['maxOrdersPerDay'], 2000),
                 'monthly': _parseLimit(data['monthly'] ?? data['maxOrdersPerMonth'], 50000),
                 // Add-on Rates
                 'rate_customer_management': (data['rate_customer_management'] ?? 0) as num,
                 'rate_franchise_management': (data['rate_franchise_management'] ?? 0) as num,
                 'rate_central_catalog': (data['rate_central_catalog'] ?? 0) as num,
                 'rate_employee_management': (data['rate_employee_management'] ?? 0) as num,
                 'rate_supplier_management': (data['rate_supplier_management'] ?? 0) as num,
                 'rate_kds_management': (data['rate_kds_management'] ?? 0) as num,
                  'rate_table_reservation': (data['rate_table_reservation'] ?? 0) as num,
                  'rate_data_center': (data['rate_data_center'] ?? 0) as num,
                  'rate_integration_hub': (data['rate_integration_hub'] ?? 0) as num,
                  'sync_frequency_str': (data['sync_frequency'] ?? '1_DAY').toString(),
                  'cloud_retention_days': _parseLimit(data['cloud_retention_days'], 30),
               };
              // Update Cache
              await updatePlatformLimitsCache(limits);
              return limits;
           }
        } catch (e) { /* Error ignored */ }
     }
     
     // 3. Return Cache or Default
     final result = {
        'daily': 2000, 
        'monthly': 50000,
        'rate_customer_management': 0,
        'rate_franchise_management': 0,
        'rate_central_catalog': 0,
        'rate_employee_management': 0,
        'rate_supplier_management': 0,
        'rate_kds_management': 0,
        'rate_table_reservation': 0,
        'rate_data_center': 0,
     };
     _cachedPlatformLimits = result;
     notifyListeners();
     return result;
  }

  // --- PLAN HELPERS ---
   Future<bool> _hasDataCenterAddon(String? storeId) async {
       if (storeId == null) return false;
       try {
         if (Hive.isBoxOpen('cache_stores')) {
            final box = Hive.box('cache_stores');
            // Check both prefixed and raw ID keys for cross-compatibility
            final data = box.get('store_settings_$storeId') ?? box.get(storeId);
            if (data != null && data is Map) {
               final addons = (data['addons'] as List<dynamic>?)?.map((e) => e?.toString() ?? '').toList() ?? [];
               return addons.contains('data_center');
            }
         }

         // Robust Fallback: Try fetching from Cloud if online and cache is empty
         if (_isOnline) {
            final doc = await _db.collection('stores').doc(storeId).get();
            if (doc.exists) {
               final data = doc.data()!;
               final addons = (data['addons'] as List<dynamic>?)?.map((e) => e?.toString() ?? '').toList() ?? [];
               return addons.contains('data_center');
            }
         }
         return false;
       } catch (e) {
         return false;
       }
    }

   Future<String> _getSubscriptionPlan(String? storeId) async {
    if (storeId == null) return 'Basic';
    
    // Return cached value if available
    if (_cachedSubscriptionPlan != null && storeId == _activeStoreId) {
      return _cachedSubscriptionPlan!;
    }

    try {
      final doc = await _db.collection('stores').doc(storeId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final plan = data['subscriptionPlan'] ?? 'Basic';
        if (storeId == _activeStoreId) _cachedSubscriptionPlan = plan;
        return plan;
      }
      return 'Basic';
    } catch (e) {
      return 'Basic';
    }
  }

  Future<void> checkOrderLimit(String storeId) async {
      final plan = await _getSubscriptionPlan(storeId);
      
      // 1. Check if Plan has Limits
      // Starting Plan: Unlimited
      // Premium Plan (Hypothetical): Unlimited?
      // Basic Plan: Limited
      if (plan == 'Starting' || plan == 'Standard' || _userRole == 'Super Admin') return; // Unlimited Orders

      // Basic Plan Logic (Limited)
      final limits = await retrievePlatformLimits();
      int dailyLimit = limits['daily'] ?? 50;
      int monthlyLimit = limits['monthly'] ?? 1500;
      
      // Count Logic...
      int dailyCount = 0;
      int monthlyCount = 0;
      
      // Offline Mode Calculation (Basic/Starting)
      // Since Starting returns early, only Basic reaches here.
      // Basic is Offline Mode, so use Local Count.
      // Note: If we add an "Online Limited" plan, we'd check connectivity here.
      // But Basic is Offline.
      
      final counts = await _getLocalOrderCounts(storeId);
      dailyCount = counts['daily']!;
      monthlyCount = counts['monthly']!;

      if (dailyCount >= dailyLimit) throw Exception("Daily Order Limit Reached ($dailyCount/$dailyLimit). Upgrade to 'Standard Plan' for Unlimited Orders.");
      if (monthlyCount >= monthlyLimit) throw Exception("Monthly Order Limit Reached ($monthlyCount/$monthlyLimit). Upgrade to 'Standard Plan' for Unlimited Orders.");
  }

  Future<Map<String, int>> _getLocalOrderCounts(String storeId) async {
      final now = DateTime.now();
      
      // FOR NATIVE (ANDROID/IOS/DESKTOP): Use Optimized SQL Count (O(1))
      if (!kIsWeb) {
        final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        final yearMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";
        
        final daily = await _repository.getDailyOrderCount(storeId, dateStr);
        final monthly = await _repository.getMonthlyOrderCount(storeId, yearMonth);
        
        return {
          'daily': daily,
          'monthly': monthly,
        };
      }
      
      // FOR WEB: Fallback to Hive enumeration (No SQLite on Web)
      final todayStart = DateTime(now.year, now.month, now.day);
      final monthStart = DateTime(now.year, now.month, 1);
      
      int d = 0;
      int m = 0;
      
      if (Hive.isBoxOpen('cache_orders')) {
         final box = Hive.box('cache_orders');
         final sid = storeId.toLowerCase();
         for (var val in box.values) {
            if (val is Map) {
               if ((val['storeId'] ?? '').toString().toLowerCase() == sid) {
                   final dateStr = val['createdAt'] ?? val['date'];
                   if (dateStr != null) {
                      final date = DateTime.tryParse(dateStr.toString());
                      if (date != null) {
                         if (date.isAfter(todayStart)) d++;
                         if (date.isAfter(monthStart)) m++;
                      }
                   }
               }
            }
         }
      }
      return {'daily': d, 'monthly': m};
  }

  /// REAL INTERNET CHECK (Beyond connectivity_plus)
  /// Crucial for Android to prevent sync hanging on "dead" Wifi.
  Future<bool> _checkActualConnectivity() async {
    if (kIsWeb) return true; // Web browser handles this via offline event listener

    try {
      // 1. Level: Multi-host DNS Lookup (Google & Cloudflare)
      // If we can resolve these, we definitely have real internet.
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) return true;
    } catch (_) {
      try {
        final result = await InternetAddress.lookup('8.8.8.8').timeout(const Duration(seconds: 2));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) return true;
      } catch (_) {
        try {
           final result = await InternetAddress.lookup('1.1.1.1').timeout(const Duration(seconds: 2));
           if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) return true;
        } catch (_) {
           return false;
        }
      }
    }
    return false;
  }

  Future<int> _getCloudOrderCountByDate(String storeId, DateTime since) async {
      try {
         final query = _db.collection('orders')
            .where('storeId', isEqualTo: storeId)
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
         final snap = await query.count().get();
         return snap.count ?? 0;
      } catch (e) {

         return 0;
      }
  }



  // --- LEGACY ADAPTERS (End of Class) ---

  Future<void> syncUp({bool forceManual = false}) async {
     await _repairUnsyncedItems('orders');
     await _repairUnsyncedItems('inventory');
     await processSync(forceManual: forceManual);
  }
  Future<void> smartSync() async => processSync();
  Future<void> resolveMismatches({String? inventoryCollection}) async {
     final modules = ['orders', 'inventory', 'customers', 'employees', 'floors', 'tables', 'suppliers', 'notes'];
     for(var m in modules) {
       await _repairUnsyncedItems(m);
     }
     await processSync(); // Push repairs first, then pull
  }
  
  Future<void> syncModule(String module, {bool forceManual = false}) async {
     if (_activeStoreId == null) return;
     // Offline Mode Block (Basic & Starting)
     if (!forceManual && _userRole != 'Super Admin') {
        final plan = await _getSubscriptionPlan(_activeStoreId);
        if (plan == 'Basic' || plan == 'Starting') {

           return;
        }
     }
     // Force full sync for specific module to fix mismatches
     _isBusy = true;
     notifyListeners();
     try {
       // 1. REPAIR: Look for local items that are PENDING but not in outbound queue
       await _repairUnsyncedItems(module.toLowerCase(), forceAll: forceManual);
       
       // 2. Push any repairs
       await _processOutboundQueue(); 
       
       // 3. Pull updates
       await _pullCollection(module.toLowerCase(), forceFull: true);
       await refreshCloudCounts(); // Await cloud counts
     } finally {
       await refreshLocalCounts(); // Await local counts
       _isBusy = false;
       notifyListeners();
     }
  }

   Future<void> _repairUnsyncedItems(String module, {bool forceAll = false}) async {

      final boxName = _getBoxName(module);
      if (boxName == null) return;
      
      try {
         final box = await Hive.openBox(boxName);
         final queueKeys = _queueBox?.toMap().values.map((v) => v['docId']).toSet() ?? {};
         
         int repairedCount = 0;
         for (var key in box.keys) {
            final val = box.get(key);
            bool shouldQueue = forceAll || (val is Map && (val['syncStatus'] == 'PENDING' || val['syncStatus'] == 'ERROR' || val['syncStatus'] == null));

            if (val is Map && shouldQueue && !queueKeys.contains(key.toString())) {
               // STORE ISOLATION: Only repair items belonging to the current active store
               final itemStoreId = (val['storeId'] ?? '').toString().trim();
               if (_activeStoreId != null && itemStoreId.isNotEmpty && itemStoreId != _activeStoreId) {
                  continue; 
               }

               // Re-queue

               await queueOperation(
                  collection: module, 
                  docId: key.toString(),
                  action: val['deletedAt'] != null ? 'delete' : (val['createdAt'] == null ? 'update' : 'create'),
                  payload: Map<String, dynamic>.from(val)
               );
               repairedCount++;
            }
         }

      } catch (e) { /* Error ignored */ }
  }

  Future<void> syncModuleUp(String module) async => processSync();
  Future<void> syncModuleDown(String module) async => processSync();
  bool isSyncingModule(String module) => _isBusy;

    Map<String, dynamic> getDetailedStats() {
       final Map<String, int> pendingBreakdown = {
          'orders': 0, 'inventory': 0, 'customers': 0, 'settings': 0,
          'employees': 0, 'floors': 0, 'tables': 0, 'suppliers': 0, 'notes': 0
       };
       
       if (_queueBox != null) {
          for(var val in _queueBox!.values) {
             if (val is Map) {
                // STORE ISOLATION: Only count items for the active store
                final itemStoreId = (val['activeStoreId'] ?? '').toString().trim();
                final payloadStoreId = (val['payload'] is Map ? (val['payload']['storeId'] ?? '').toString().trim() : '');
                if (_activeStoreId != null && itemStoreId.isNotEmpty && itemStoreId != _activeStoreId && payloadStoreId != _activeStoreId) {
                   continue; // Skip items from other stores
                }
                final col = (val['collection'] as String? ?? '').toLowerCase();
                for(var mod in pendingBreakdown.keys) {
                   if (col.contains(mod)) {
                      pendingBreakdown[mod] = (pendingBreakdown[mod] ?? 0) + 1;
                      break;
                   }
                }
             }
          }
       }

       return {
         'pending': pendingUploadCount,
         'orders': _localOrdersCount,
         'inventory': _localInventoryCount,
         'customers': _localCustomersCount,
         'settings': _localSettingsCount,
         'cloudOrders': _cloudOrdersCount,
         'cloudInventory': _cloudInventoryCount,
         'cloudCustomers': _cloudCustomersCount,
         'cloudSettings': _cloudSettingsCount >= 0 ? _cloudSettingsCount : 0, 
       
         'employees': _localEmployeesCount,
         'cloudEmployees': _cloudEmployeesCount,
         
         'tables': _localTablesCount,
         'cloudTables': _cloudTablesCount,
         
         'floors': _localFloorsCount,
         'cloudFloors': _cloudFloorsCount,
         
         'suppliers': _localSuppliersCount,
         'cloudSuppliers': _cloudSuppliersCount,
         
         'notes': _localNotesCount,
         'cloudNotes': _cloudNotesCount,
         'isOnline': _isOnline,
         'isBusy': _isBusy,
         'lastSync': _lastSyncTime,
         'deviceId': _deviceId,
         'pendingBreakdown': pendingBreakdown
       };
    }

  Future<Map<String, String>> checkIntegrity() async {
      return {
        "Status": "Integrity check not implemented in new architecture.",
        "System": "Data is synced automatically via Delta Sync engine."
      };
  }

  Future<List<Map<String, dynamic>>> fetchCloudDocuments({required String collection, int limit = 10, String? storeId}) async {
      String finalPath = collection;
      // ALL MOVED TO ROOT
      // if (!collection.contains('/') && ['employees', 'floors', 'tables', 'suppliers', 'notes'].contains(collection)) {
      //    finalPath = 'stores/$_activeStoreId/$collection';
      // }
      
      Query query = _db.collection(finalPath);
      if (storeId != null) query = query.where('storeId', isEqualTo: storeId); 
      // Ensure root collections are filtered by storeId if not explicitly passed
      if (storeId == null && ['orders', 'inventory', 'customers', 'employees', 'floors', 'tables', 'suppliers', 'notes'].contains(collection) && _activeStoreId != null) {
          query = query.where('storeId', isEqualTo: _activeStoreId);
      }
      
      final snapshot = await query.limit(limit).get();
    return snapshot.docs.map((d) => d.data() as Map<String, dynamic>).toList();
  }

  String generateId([String? prefix]) {
    final id = const Uuid().v4();
    return prefix != null ? "${prefix}_$id" : id;
  }
  
  String generateUniqueId([String? prefix]) => generateId(prefix);

  Future<void> performLocalWrite({required String collection, required String docId, required Map<String, dynamic> data, required String action, String? localCacheBox, bool refreshCounts = true}) async {
    // DEVICE IDENTITY: Tag every local write with this device's ID for multi-device conflict tracing
    data['deviceId'] = data['deviceId'] ?? _deviceId;
    data['lastModifiedBy'] = _deviceId;

    // OFFLINE-FIRST: Always write to Hive cache on ALL platforms for ALL collections.
    // Previously restricted to Web + metadata-only collections, which caused inventory/orders/customers
    // to be missing from Hive on mobile. This broke reconciliation safety (PENDING check) and
    // prevented local-first data recovery after failed cloud syncs.
    {
       // Determine Box Name (Prioritize mapping collection search for module name)
       String? boxName = localCacheBox;
       final modules = ['orders', 'inventory', 'customers', 'employees', 'floors', 'tables', 'suppliers', 'notes', 'settings'];
       for (var mod in modules) {
          if (collection.endsWith(mod)) {
             boxName = _getBoxName(mod) ?? boxName;
             break;
          }
       }
       
       boxName ??= collection == 'orders' ? 'cache_orders' : 
                   (collection == 'inventory' ? 'cache_inventory' : 
                   (collection == 'customers' ? 'cache_customers' : null));

       if (boxName != null) {
          try {
              final box = await Hive.openBox(boxName); 
              if (action == 'delete') {
                 await box.delete(docId);
              } else {
                 final payload = Map<String, dynamic>.from(data);
                 payload['id'] = docId; // Ensure ID exists for re-hydration
                 payload['syncStatus'] = 'PENDING'; // Explicitly mark for repair scanner
                 await box.put(docId, _deepSanitize(payload));
              }
          } catch (e) { /* Error ignored */ }
       }
    }
    
    // WEB DIRECT WRITE (Bypass Queue for Reliability)
    if (kIsWeb) {
        try {
        // Strict Path Construction
        String finalPath = collection;
        // ALL MOVED TO ROOT: orders, inventory, customers, employees, floors, tables, suppliers, notes
        // Subcollections are no longer used for core data.
        if (collection.startsWith('stores/$_activeStoreId/')) {
           finalPath = collection.split('/').last;
        }

           DocumentReference ref = _db.collection(finalPath).doc(docId);
           Map<String, dynamic> payload = Map<String, dynamic>.from(data);
           
           // Store address/phone are basic info - always sync to cloud

           if (_activeStoreId != null && !payload.containsKey('storeId')) {
              payload['storeId'] = _activeStoreId;
           }
           // Ensure timestamps
           payload['updatedAt'] = FieldValue.serverTimestamp();
           
           if (action == 'create' || action == 'update') {
              payload['syncedAt'] = FieldValue.serverTimestamp();
              await ref.set(payload, SetOptions(merge: true));
           } else if (action == 'delete') {
              await ref.update({'deletedAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
           }
           if (refreshCounts) refreshCloudCounts(); 
          // return; // Don't return, let it queue if needed, or at least let it finish
       } catch (e) {

          // Fallback to Queue
       }
    }
    if (!kIsWeb) {
        if (collection == 'orders') {
           if (action == 'delete') {
             await _repository.deleteOrder(docId);
           } else {
             await _repository.insertOrder(OrderModel.fromMap(data, docId));
           }
        } else if (collection == 'inventory' || localCacheBox == 'cache_inventory') {
           if (action == 'delete') {
             await _repository.deleteInventory(docId);
           } else {
             await _repository.insertInventory(InventoryItem.fromMap(data, docId));
           }
        } else if (collection == 'customers') {
           if (action == 'delete') {
             await _repository.deleteCustomer(docId);
           } else {
             await _repository.insertCustomer(Customer.fromMap(data, docId));
           }
        } else if (collection == 'employees') {
           if (action == 'delete') {
             await _repository.deleteEmployee(docId);
           } else {
             await _repository.insertEmployee(UserProfile.fromMap(data, docId));
           }
        } else if (collection == 'settings') {
           await _repository.insertStoreSettings(docId, data);
        } else if (collection == 'floors') {
           await _repository.insertFloor(docId, _activeStoreId ?? '', data);
        } else if (collection == 'tables') {
           await _repository.insertTable(docId, _activeStoreId ?? '', data);
        } else if (collection == 'suppliers') {
           await _repository.insertSupplier(docId, _activeStoreId ?? '', data);
        } else if (collection == 'notes') {
           await _repository.insertNote(docId, _activeStoreId ?? '', data);
        }
    }
     if (refreshCounts) refreshLocalCounts();
     
     // Store address/phone are basic info - always sync to cloud
      Map<String, dynamic> cloudPayload = Map<String, dynamic>.from(data);

     await queueOperation(collection: collection, docId: docId, action: action, payload: cloudPayload);
  }

  Future<DateTime?> _getLastSyncTime(String collection) async {
    if (_activeStoreId == null) return null;
    if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
    final box = Hive.box('settings');
    final key = 'last_sync_${collection}_$_activeStoreId';
    if (box.containsKey(key)) {
       return DateTime.fromMillisecondsSinceEpoch(box.get(key));
    }
    return null;
  }

  Future<void> _saveLastSyncTime(String collection, DateTime time) async {
     if (_activeStoreId == null) return;
     if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
     await Hive.box('settings').put('last_sync_${collection}_$_activeStoreId', time.millisecondsSinceEpoch);
  }

  Future<void> _loadSyncFrequency() async {
    if (_activeStoreId == null) return;
    if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
    final box = Hive.box('settings');
    _syncFrequency = box.get('sync_freq_$_activeStoreId', defaultValue: 'LIVE');
  }

  Future<void> _saveSyncFrequency() async {
    if (_activeStoreId == null) return;
    if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
    final box = Hive.box('settings');
    await box.put('sync_freq_$_activeStoreId', _syncFrequency);
  }

  // Helper to sanitize data for Hive (Convert Timestamps/DateTimes to Strings)
  dynamic _deepSanitize(dynamic value) {
    if (value is Map) {
      final Map<String, dynamic> result = {};
      value.forEach((k, v) {
        result[k.toString()] = _deepSanitize(v);
      });
      return result;
    }
    else if (value is List) {
      return value.map((e) => _deepSanitize(e)).toList();
    } else if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else if (value is DateTime) {
      return value.toIso8601String();
    } else if (value is DocumentReference) {
      return value.id; // Store ID string for Hive
    }
    return value;
  }

  DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is Timestamp) return date.toDate();
    if (date is DateTime) return date;
    if (date is String) return DateTime.tryParse(date);
    if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
    return null;
  }

  Future<void> _reportUsage() async {
    if (_activeStoreId == null || !_isOnline) return;
    try {
      final sid = _activeStoreId!;
      final counts = await _getLocalOrderCounts(sid);
      
      // Update usage metadata for Super Admin visibility
      await _db.collection('stores').doc(sid).collection('metadata').doc('usage').set({
        'dailyOrders': counts['daily'],
        'monthlyOrders': counts['monthly'],
        'lastReported': FieldValue.serverTimestamp(),
        'storeId': sid,
      }, SetOptions(merge: true));
      
      debugPrint('✅ SyncService: Usage reported for $sid: ${counts['daily']} orders today.');
    } catch (e) {
      debugPrint('❌ SyncService: Error reporting usage: $e');
    }
  }
  Future<void> updatePlatformLimitsCache(Map<String, dynamic> limits) async {
    _cachedPlatformLimits = limits;
    if (Hive.isBoxOpen('settings')) {
      await Hive.box('settings').put('platform_limits', limits);
    }
    notifyListeners();
  }

  int _parseLimit(dynamic v, int fallback) {
    return _parseInt(v, fallback);
  }

  int _parseInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  double _parseDouble(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }
}


