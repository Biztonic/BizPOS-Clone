import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/services/firestore_helper.dart';

// --- Engine Imports ---
import 'package:biztonic_pos/sync/orchestrator/sync_orchestrator.dart';
import 'package:biztonic_pos/sync/inbound/pull_engine.dart';
import 'package:biztonic_pos/sync/outbound/outbound_manager.dart';
import 'package:biztonic_pos/sync/diagnostics/sync_diagnostics.dart';
import 'package:biztonic_pos/sync/diagnostics/stats_engine.dart';
import 'package:biztonic_pos/sync/maintenance/sync_maintenance.dart';
import 'package:biztonic_pos/sync/policy/plan_sync_policy.dart';
import 'package:biztonic_pos/sync/limits/limits_engine.dart';
import 'package:biztonic_pos/sync/registry/sync_collection_registry.dart';

// --- Adapter Imports (only files that exist) ---
import 'package:biztonic_pos/sync/adapters/sync_adapter.dart';
import 'package:biztonic_pos/sync/adapters/orders_sync_adapter.dart';
import 'package:biztonic_pos/sync/adapters/customer_sync_adapter.dart';
import 'package:biztonic_pos/sync/adapters/employee_sync_adapter.dart';
import 'package:biztonic_pos/sync/adapters/inventory_sync_adapter.dart';
import 'package:biztonic_pos/sync/adapters/movement_sync_adapter.dart';
import 'package:biztonic_pos/sync/adapters/settings_sync_adapter.dart';
import 'package:biztonic_pos/sync/adapters/generic_sync_adapter.dart';

/// Thin facade over the decomposed sync architecture.
///
/// Responsibilities:
/// - Initializes all engines (Pull, Outbound, Orchestrator, Stats, Maintenance)
/// - Exposes the public API that providers depend on
/// - Manages connectivity and auth state listeners
/// - Routes all work to specialized engines
class SyncService with ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  // --- STREAMS ---
  final StreamController<String> _syncStatusController = StreamController<String>.broadcast();
  Stream<String> get syncStatusStream => _syncStatusController.stream;

  // --- ENGINE REFERENCES ---
  late final SyncOrchestrator _orchestrator;
  late final PullEngine _pullEngine;
  late final OutboundManager _outboundManager;
  late final SyncDiagnostics _diagnostics;
  late final StatsEngine _statsEngine;
  late final SyncMaintenanceEngine _maintenanceEngine;
  late final PlanSyncPolicy _planPolicy;
  late final LimitsEngine _limitsEngine;

  // --- ADAPTER MAP ---
  Map<String, SyncAdapter> _adapters = {};

  // --- HIVE BOXES ---
  Box? _queueBox;
  Box? _failedQueueBox;

  // --- STATE ---
  bool _isInitialized = false;

  String _syncStatus = "Idle";
  String get syncStatus => _syncStatus;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  String? _lastSyncError;
  String? get lastSyncError => _lastSyncError;
  set lastSyncError(String? val) => _lastSyncError = val;

  String? _lastSyncWarning;
  String? get lastSyncWarning => _lastSyncWarning;
  set lastSyncWarning(String? val) => _lastSyncWarning = val;

  /// Extracts a Firebase index creation URL from an error message, if present.
  String? get lastIndexErrorUrl {
    if (_lastSyncError != null) return _extractIndexLink(_lastSyncError!);
    if (_lastSyncWarning != null) return _extractIndexLink(_lastSyncWarning!);
    return null;
  }

  String? _deviceId;
  String? get deviceId => _deviceId;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  String _syncFrequency = 'LIVE';
  String get syncFrequency => _syncFrequency;

  void setSyncFrequency(String freq) {
    if (_syncFrequency == freq) return;
    _syncFrequency = freq;
    notifyListeners();
  }

  bool get isSyncing => _isInitialized ? _orchestrator.isBusy : false;
  bool get isBusy => isSyncing;

  String? _userId;
  String? get userId => _userId;

  String? _userRole;
  String? get userRole => _userRole;

  Timer? _syncTimer;

  final Repository _repository = Repository();
  Repository get repository => _repository;
  final FirebaseFirestore _db = getFirestore();

  String? _activeStoreId;
  String? get activeStoreId => _activeStoreId;

  // --- Cached Platform Limits (backward compat for providers) ---
  Map<String, dynamic>? _cachedPlatformLimits;
  Map<String, dynamic> get platformLimits => _cachedPlatformLimits ?? {};

  String? _cachedSubscriptionPlan;

  // --- Local Counts (backed by StatsEngine) ---
  Map<String, int> _localCounts = {};

  int get localOrdersCount => _localCounts[SyncCollectionRegistry.orders] ?? 0;
  int get localInventoryCount => _localCounts[SyncCollectionRegistry.inventory] ?? 0;
  int get localCustomersCount => _localCounts[SyncCollectionRegistry.customers] ?? 0;
  int get localSettingsCount => _localCounts[SyncCollectionRegistry.settings] ?? 0;
  int get localEmployeesCount => _localCounts[SyncCollectionRegistry.employees] ?? 0;
  int get localTablesCount => _localCounts[SyncCollectionRegistry.tables] ?? 0;
  int get localFloorsCount => _localCounts[SyncCollectionRegistry.floors] ?? 0;
  int get localSuppliersCount => _localCounts[SyncCollectionRegistry.suppliers] ?? 0;
  int get localNotesCount => _localCounts[SyncCollectionRegistry.notes] ?? 0;

  int get cachedOrdersCount => localOrdersCount;
  int get cachedInventoryCount => localInventoryCount;
  int get cachedCustomersCount => localCustomersCount;

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

  // ─────────────────────────────────────────────────────────────
  // SETTERS (called by providers)
  // ─────────────────────────────────────────────────────────────

  void setActiveStoreId(String? id) {
    if (_activeStoreId == id) return;
    _activeStoreId = id;
    _planPolicy.clearCache();
    _cachedPlatformLimits = null;
    _cachedSubscriptionPlan = null;
    notifyListeners();
  }

  void setUserId(String? id) {
    _userId = id;
  }

  void setUserRole(String? role) {
    if (_userRole == role) return;
    _userRole = role;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_isInitialized) return;
    debugPrint('🔄 SyncService.init START');

    try {
      // 1. Boxes
      await SyncCollectionRegistry.initializeHive();
      _queueBox = Hive.box(SyncCollectionRegistry.boxSyncQueue);
      _failedQueueBox = Hive.box(SyncCollectionRegistry.boxFailedQueue);

      // 2. Specialized Engines
      _diagnostics = SyncDiagnostics();
      await _diagnostics.init(Hive.box(SyncCollectionRegistry.boxSyncLogs));

      _outboundManager = OutboundManager(
        getQueueBox: () => _queueBox,
        getFailedQueueBox: () => _failedQueueBox,
        getActiveStoreId: () => activeStoreId,
        getUserId: () => FirebaseAuth.instance.currentUser?.uid,
        getDeviceId: () => _deviceId,
        getRepository: () => _repository,
        checkConnectivity: _checkInternetConnection,
        logEvent: _diagnostics.log,
      );

      _planPolicy = PlanSyncPolicy(db: _db);
      _limitsEngine = LimitsEngine(policy: _planPolicy);

      _statsEngine = StatsEngine(
        db: _db,
        repository: _repository,
        getActiveStoreId: () => _activeStoreId,
      );

      _pullEngine = PullEngine(
        db: _db,
        getActiveStoreId: () => activeStoreId,
        getRepository: () => _repository,
        checkConnectivity: _checkInternetConnection,
        getLastSyncTime: _getLastSyncTime,
        saveLastSyncTime: _saveLastSyncTime,
        logEvent: _diagnostics.log,
        adapters: _adapters = {}, // Will be populated in _registerAdapters
      );

      _maintenanceEngine = SyncMaintenanceEngine(
        getQueueBox: () => _queueBox,
        queueOperation: queueOperation,
        getActiveStoreId: () => _activeStoreId,
      );

      // 3. Register Adapters
      _registerAdapters();

      // 4. Orchestrator
      _orchestrator = SyncOrchestrator(
        pullEngine: _pullEngine,
        outboundManager: _outboundManager,
        planPolicy: _planPolicy,
        limitsEngine: _limitsEngine,
        setStatus: (s) => _syncStatus = s,
        setLastError: (e) => _lastSyncError = e,
        setLastWarning: (w) => _lastSyncWarning = w,
        setLastSyncTime: (t) => _lastSyncTime = t,
        refreshCounts: refreshLocalCounts,
        checkConnectivity: _checkInternetConnection,
        notifyListeners: notifyListeners,
      );

      // 5. Auth & Device ID
      _setupAuthListener();
      await _initDeviceId();

      _initConnectivity();
      _startSyncTimer();

      // 6. Run Maintenance (Background)
      unawaited(_maintenanceEngine.repairAllModules());

      _isInitialized = true;
      debugPrint("✅ SyncService Decomposed Initialized");
    } catch (e) {
      debugPrint("❌ SyncService Init Error: $e");
    }
  }

  void _registerAdapters() {
    // Typed adapters
    final typedAdapters = <SyncAdapter>[
      OrdersSyncAdapter(),
      CustomerSyncAdapter(),
      EmployeeSyncAdapter(),
      InventorySyncAdapter(),
      MovementSyncAdapter(),
      SettingsSyncAdapter(),
    ];

    for (var adapter in typedAdapters) {
      _adapters[adapter.collection] = adapter;
    }

    // Generic adapters (floors, tables, suppliers, notes)
    _adapters.addAll(GenericSyncAdapter.createAll());
  }

  void _setupAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        setUserId(user.uid);
        if (_activeStoreId != null) processSync();
      }
    });
  }

  Future<void> _initDeviceId() async {
    final settingsBox = Hive.box(SyncCollectionRegistry.boxSettingsGeneral);
    _deviceId = settingsBox.get('deviceId');
    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      await settingsBox.put('deviceId', _deviceId);
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isOnline) processSync();
    });
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
      _diagnostics.log("Network Restored ($result). Triggering sync...");
      processSync();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LOCAL COUNTS (Delegated to StatsEngine)
  // ─────────────────────────────────────────────────────────────

  Future<void> refreshLocalCounts({bool notify = true}) async {
    if (_activeStoreId == null) return;
    try {
      _localCounts = await _statsEngine.refreshLocalCounts();
      if (_isOnline) {
        unawaited(refreshCloudCounts(notify: false));
      }
      if (notify) notifyListeners();
    } catch (e) {
      debugPrint('❌ SyncService: Failed to refresh local counts: $e');
    }
  }

  Map<String, int> _cloudCounts = {};

  int get cloudOrdersCount => _cloudCounts[SyncCollectionRegistry.orders] ?? -1;
  int get cloudInventoryCount => _cloudCounts[SyncCollectionRegistry.inventory] ?? -1;
  int get cloudCustomersCount => _cloudCounts[SyncCollectionRegistry.customers] ?? -1;
  int get cloudSettingsCount => _cloudCounts[SyncCollectionRegistry.settings] ?? -1;
  int get cloudEmployeesCount => _cloudCounts[SyncCollectionRegistry.employees] ?? -1;
  int get cloudTablesCount => _cloudCounts[SyncCollectionRegistry.tables] ?? -1;
  int get cloudFloorsCount => _cloudCounts[SyncCollectionRegistry.floors] ?? -1;
  int get cloudSuppliersCount => _cloudCounts[SyncCollectionRegistry.suppliers] ?? -1;
  int get cloudNotesCount => _cloudCounts[SyncCollectionRegistry.notes] ?? -1;

  Future<void> refreshCloudCounts({bool notify = true}) async {
    if (!_isOnline || _activeStoreId == null) return;
    try {
      _cloudCounts = await _statsEngine.refreshCloudCounts();
      if (notify) notifyListeners();
    } catch (e) {
      debugPrint('❌ SyncService: Failed to refresh cloud counts: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SUBSCRIPTION & LIMITS (Delegated to PlanPolicy/LimitsEngine)
  // ─────────────────────────────────────────────────────────────

  /// Validates if an order can be created based on plan limits.
  Future<void> checkOrderLimit(String storeId) async {
    await _limitsEngine.validateOrderCreation(
      storeId: storeId,
      userRole: _userRole,
      getLocalOrderCounts: _statsEngine.getLocalOrderCounts,
    );
  }

  /// Whether the store is currently subscribed.
  bool get isSubscribed {
    // A store is considered subscribed if a plan beyond 'Basic' is cached.
    final plan = _cachedSubscriptionPlan ?? 'Basic';
    return plan != 'Basic';
  }

  /// Human-readable plan name.
  String get planName => _cachedSubscriptionPlan ?? 'Basic';

  /// Retrieves platform limits (with caching).
  Future<Map<String, dynamic>> retrievePlatformLimits() async {
    final limits = await _planPolicy.retrievePlatformLimits();
    _cachedPlatformLimits = limits;
    return limits;
  }

  /// Updates the platform limits cache.
  Future<void> updatePlatformLimitsCache(Map<String, dynamic> limits) async {
    _cachedPlatformLimits = limits;
    await _planPolicy.updatePlatformLimitsCache(limits);
    notifyListeners();
  }

  /// Returns the retention period (in days) for cloud data cleanup.
  Future<bool> hasDataCenterAddon(String? storeId) async => _planPolicy.hasDataCenterAddon(storeId);

  String? _extractIndexLink(String error) {
    if (!error.contains("https://console.firebase.google.com")) return null;
    try {
      final start = error.indexOf("https://console.firebase.google.com");
      final end = error.indexOf(" ", start);
      if (end == -1) return error.substring(start).replaceAll("]", "").replaceAll(")", "");
      return error.substring(start, end).replaceAll("]", "").replaceAll(")", "");
    } catch (e) { return null; }
  }

  // ─────────────────────────────────────────────────────────────
  // SYNC ACTIONS
  // ─────────────────────────────────────────────────────────────

  Future<void> processSync({bool forceManual = false, bool forceFull = false}) async {
    await _orchestrator.processSync(forceManual: forceManual, forceFull: forceFull);
  }

  Future<void> forceSyncDown() async {
    await _maintenanceEngine.clearStoreMetadata(_activeStoreId);
    await processSync(forceManual: true, forceFull: true);
  }

  Future<void> nuclearReset() async {
    if (_activeStoreId == null) return;
    await _maintenanceEngine.clearStoreCache(_activeStoreId!);
    await forceSyncDown();
  }

  Future<void> clearStoreCache(String storeId) async {
    await _maintenanceEngine.clearStoreCache(storeId);
    await refreshLocalCounts();
  }

  Future<void> clearAllLocalData() async {
    await _maintenanceEngine.clearAllLocalData();
  }

  Future<void> resetQueueRetries() async {
    await _maintenanceEngine.resetQueueRetries();
    notifyListeners();
  }

  Future<void> syncUp({bool forceManual = false}) async {
    await processSync(forceManual: forceManual);
  }

  Future<void> smartSync() async => processSync();

  Future<void> resolveMismatches({String? inventoryCollection}) async {
    await _maintenanceEngine.repairAllModules();
    await processSync();
  }

  Future<void> syncModule(String module, {bool forceManual = false}) async {
    if (_activeStoreId == null) return;
    await _maintenanceEngine.repairUnsyncedItems(module.toLowerCase());
    await processSync(forceManual: forceManual);
  }

  Future<void> syncModuleUp(String module) async => processSync();
  Future<void> syncModuleDown(String module) async => processSync();
  bool isSyncingModule(String module) => isBusy;

  // ─────────────────────────────────────────────────────────────
  // DIAGNOSTICS
  // ─────────────────────────────────────────────────────────────

  Future<String> inspectCloudData() async {
    return _diagnostics.inspectCloudData(db: _db, activeStoreId: _activeStoreId);
  }

  /// Returns a diagnostic integrity check string.
  Future<String> checkIntegrity() async {
    final sb = StringBuffer();
    sb.writeln("=== INTEGRITY CHECK (${DateTime.now()}) ===");
    sb.writeln("Store: $_activeStoreId");
    sb.writeln("Online: $_isOnline");
    sb.writeln("Queue: ${_queueBox?.length ?? 0} items");
    sb.writeln("Failed: ${_failedQueueBox?.length ?? 0} items");
    sb.writeln("Local Counts: $_localCounts");
    sb.writeln("Cloud Counts: $_cloudCounts");
    sb.writeln("Adapters: ${_adapters.keys.toList()}");
    return sb.toString();
  }

  Map<String, dynamic> getDetailedStats() {
    return _statsEngine.getDetailedStats(
      localCounts: _localCounts,
      cloudCounts: _cloudCounts,
      pendingCount: pendingUploadCount,
      isOnline: _isOnline,
      isBusy: isBusy,
      lastSync: _lastSyncTime,
      deviceId: _deviceId,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // OUTBOUND QUEUE
  // ─────────────────────────────────────────────────────────────

  /// Queues an operation for background synchronization.
  Future<void> queueOperation({
    required String collection,
    required String docId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    await _outboundManager.queueOperation(
      collection: collection,
      docId: docId,
      action: action,
      payload: payload,
    );

    if (_isOnline && _hasCloudAccess) {
      unawaited(processSync());
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LOCAL WRITE (Offline-First Write Path)
  // ─────────────────────────────────────────────────────────────

  Future<void> performLocalWrite({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
    required String action,
    String? localCacheBox,
    bool refreshCounts = true,
  }) async {
    // 1. Tag with device ID
    data['deviceId'] = data['deviceId'] ?? _deviceId;
    data['lastModifiedBy'] = _deviceId;

    // 2. Offline-First Hive Write
    final boxName = localCacheBox ?? SyncCollectionRegistry.getBoxName(collection);
    if (boxName != null) {
      try {
        final box = await Hive.openBox(boxName);
        if (action == 'delete') {
          await box.delete(docId);
        } else {
          final payload = Map<String, dynamic>.from(data);
          payload['id'] = docId;
          payload['syncStatus'] = 'PENDING';
          await box.put(docId, _deepSanitize(payload));
        }
      } catch (e) {
        debugPrint("⚠️ [SyncService] Hive write failed: $e");
      }
    }

    // 3. Web Direct Write (Bypass Queue for Reliability)
    if (kIsWeb) {
      await _outboundManager.performWebDirectWrite(
        collection: collection,
        docId: docId,
        action: action,
        data: data,
      );
    }

    // 4. Native SQLite Write
    if (!kIsWeb) {
      final adapter = _adapters[collection];
      if (adapter != null) {
        if (action == 'delete') {
          await adapter.deleteLocal(docId, _repository);
        } else {
          await adapter.insertFromCloud(data, docId, _repository);
        }
      }
    }

    if (refreshCounts) this.refreshLocalCounts();

    // 5. Queue for Cloud Sync
    await queueOperation(
      collection: collection,
      docId: docId,
      action: action,
      payload: Map<String, dynamic>.from(data),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ID GENERATION
  // ─────────────────────────────────────────────────────────────

  /// Generates a unique UUID v4 string.
  String generateId() => const Uuid().v4();

  /// Generates a unique ID with an optional prefix (e.g., 'INV', 'MVT', 'EVT').
  String generateUniqueId([String? prefix]) {
    final id = const Uuid().v4();
    return prefix != null ? '${prefix}_$id' : id;
  }

  // ─────────────────────────────────────────────────────────────
  // CONNECTIVITY HELPERS
  // ─────────────────────────────────────────────────────────────

  Future<bool> _checkInternetConnection() async {
    if (kIsWeb) return true;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  Future<DateTime?> _getLastSyncTime(String collection) async {
    if (_activeStoreId == null) return null;
    final box = await Hive.openBox(SyncCollectionRegistry.boxSettingsGeneral);
    final key = 'last_sync_${collection}_$_activeStoreId';
    final val = box.get(key);
    return val != null ? DateTime.fromMillisecondsSinceEpoch(val) : null;
  }

  Future<void> _saveLastSyncTime(String collection, DateTime time) async {
    if (_activeStoreId == null) return;
    final box = await Hive.openBox(SyncCollectionRegistry.boxSettingsGeneral);
    await box.put('last_sync_${collection}_$_activeStoreId', time.millisecondsSinceEpoch);
  }

  dynamic _deepSanitize(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _deepSanitize(v)));
    } else if (value is List) {
      return value.map((e) => _deepSanitize(e)).toList();
    } else if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else if (value is DateTime) {
      return value.toIso8601String();
    } else if (value is DocumentReference) {
      return value.id;
    }
    return value;
  }
}
