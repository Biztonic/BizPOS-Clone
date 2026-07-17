import '../core/design/tokens/app_colors.dart';
// ignore_for_file: unused_field, deprecated_member_use_from_same_package, dead_code, curly_braces_in_flow_control_structures, unused_element, avoid_types_as_parameter_names, dead_null_aware_expression, body_might_complete_normally_catch_error, deprecated_member_use, unused_local_variable
import 'package:biztonic_pos/models/role_model.dart';
import 'package:biztonic_pos/models/franchise.dart';
import 'package:biztonic_pos/core/theme/theme_provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/services/firestore_helper.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:biztonic_pos/providers/auth_provider.dart';
import 'dart:math'; 
import 'package:biztonic_pos/utils/pin_utils.dart';
import 'package:biztonic_pos/models/store.dart';
import 'package:biztonic_pos/models/user_profile.dart';
import 'package:biztonic_pos/models/inventory_item.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/models/counter_model.dart';
import 'package:biztonic_pos/models/customer.dart';
import 'package:biztonic_pos/models/settings.dart'; 
import 'package:hive_flutter/hive_flutter.dart'; 
import 'package:biztonic_pos/services/google_drive_service.dart';
import 'package:biztonic_pos/providers/order_provider.dart';
import 'package:biztonic_pos/services/sync_service.dart';
import 'package:biztonic_pos/services/recovery_service.dart';
import 'package:biztonic_pos/services/offline_service.dart';
import 'package:biztonic_pos/providers/customer_provider.dart';
import '../routing/router_notifier.dart';
import 'package:biztonic_pos/providers/store_provider.dart';
import 'package:biztonic_pos/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/services/employee_repository.dart';
import 'package:biztonic_pos/utils/theme.dart';
import 'package:biztonic_pos/models/subscription_request.dart';
import 'package:biztonic_pos/models/subscription_history.dart';
import 'package:biztonic_pos/services/printer_manager_service.dart';
import 'package:biztonic_pos/services/database_helper.dart';

import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';
import 'package:biztonic_pos/features/inventory/domain/use_cases/adjust_stock.dart';
import 'package:biztonic_pos/features/inventory/data/mappers/inventory_mapper.dart';
import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';

import 'package:biztonic_pos/sync/registry/sync_collection_registry.dart';

class DashboardProvider with ChangeNotifier {
  static bool isTesting = false;
  Timer? _timeUpdateTimer;
  late final FirebaseFirestore _db = getFirestore();
  final FirebaseAuth? _auth;
  final SyncService _syncService = SyncService();
  final Repository _repository = Repository(); 

  static FirebaseAuth? _getDefaultAuth() {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }
  
  final EmployeeRepository _employeeRepository = EmployeeRepository();
  SyncService get syncService => _syncService;

  List<Map<String, dynamic>> _attendanceRecords = [];
  List<Map<String, dynamic>> get attendanceRecords => _attendanceRecords;
  final List<Map<String, dynamic>> _leaveRequests = [];
  List<Map<String, dynamic>> get leaveRequests => _leaveRequests;
  List<Map<String, dynamic>> _payrollRecords = [];
  List<Map<String, dynamic>> get payrollRecords => _payrollRecords;

  // --- INITIAL SYNC STATE ---
  bool _isInitialSyncing = false;
  bool get isInitialSyncing => _isInitialSyncing;
  double _initialSyncProgress = 0.0;
  double get initialSyncProgress => _initialSyncProgress;
  String _initialSyncStatus = "";
  String get initialSyncStatus => _initialSyncStatus;

  // --- CONSOLIDATED STATE ---
  final bool _isSwitchingStore = false;
  bool _isInitialized = false;
  bool _isFetchingUserData = false; // Prevent redundant concurrent fetches
  int _fetchGeneration = 0; // Tracks fetch generation to discard stale retries
  bool _pendingStoreRetry = false; // Flag: StoreProvider was injected after auth fired
  bool get isInitialized => _isInitialized;
  
  // Missing fields restored
  List<UserProfile> _systemUsers = [];
  bool _subscriptionHistoryLoaded = false;
  final List<InventoryItem> _centralInventory = [];
  // Redefine if missing, or we can just hope it's not complaining about it
  List<SubscriptionHistory> get rejectedSubscriptions => _subscriptionHistory.where((s) => s.status == 'REJECTED').toList();
  bool _isOnline = true;
  bool _isLoading = false;
  List<CounterModel> _counters = [];
  StreamSubscription? _countersSubscription;
  bool _isOfflineLoggedIn = false; // New field for offline tracking
  bool get isOfflineLoggedIn => _isOfflineLoggedIn;
 
  bool _autoBackupEnabled = false;
  String _backupFrequency = 'Daily';
  TimeOfDay _backupTime = const TimeOfDay(hour: 0, minute: 0);
  
  // Stream Subscriptions for cleanup
  final List<StreamSubscription> _subscriptions = [];
  bool _isDisposed = false;

  RouterNotifier? _routerNotifier;
  
  // UI States
  bool _isSidebarCollapsed = false;
  bool get isSidebarCollapsed => _isSidebarCollapsed;
  void toggleSidebar() {
     _isSidebarCollapsed = !_isSidebarCollapsed;
     notifyListeners();
  }

  // Backup Cache
  List<Map<String, dynamic>> _availableBackups = [];
  List<Map<String, dynamic>> get availableBackups => _availableBackups;
  bool _isFetchingBackups = false;
  bool get isFetchingBackups => _isFetchingBackups;

  void setLoading(bool val) {
    if (_isDisposed) return;
    _isLoading = val;
    notifyListeners();
  }

  void refreshDashboard() {
    notifyListeners();
  }

  final RecoveryService _recoveryService = RecoveryService();
  List<Map<String, dynamic>> _pendingRecoveries = [];
  List<Map<String, dynamic>> get pendingRecoveries => _pendingRecoveries;

  DashboardProvider({FirebaseAuth? auth}) : _auth = auth ?? _getDefaultAuth() {
     debugPrint('🏗️ DashboardProvider Constructor START');
     _listenToGlobalSettings();
     try {
       _syncService.init();
     } catch (e) {
       debugPrint('❌ DashboardProvider: SyncService.init() Failed: $e');
     }

     final offlineService = OfflineService();
     _isOnline = offlineService.isOnline;      
     final connectivitySub = offlineService.connectivityStream.listen((status) {
       if (_isDisposed) return;
       if (_isOnline != status) {
         _isOnline = status;
         notifyListeners();
         if (_isOnline) {
           _syncService.smartSync();
         }
       }
     });
     _subscriptions.add(connectivitySub);

      final syncCompletedSub = EventBus.instance.on<SyncCompletedEvent>((event) {
        if (_isDisposed) return;
        if (event.storeId == _activeStoreId) {
          reloadLocalData();
        }
      });
      _subscriptions.add(syncCompletedSub);

    // _syncService.addListener(_onSyncUpdate); // Removed to prevent UI jank during background syncs

    // Developer mode moved to init()
    _checkClockTampered();
    if (!isTesting) {
      _timeUpdateTimer = Timer.periodic(const Duration(minutes: 5), (_) => _updateLastKnownTime());
    }
    
    debugPrint('✅ DashboardProvider Constructor END');
  }

  @override
  void dispose() {
    debugPrint('🗑️ DashboardProvider.dispose() called');
    _isDisposed = true;
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    // _syncService.removeListener(_onSyncUpdate);
    
    if (_inventoryProvider != null) _inventoryProvider!.removeListener(_onInventoryChange);
    if (_orderProvider != null) _orderProvider!.removeListener(_onOrderChange);
    if (_customerProvider != null) _customerProvider!.removeListener(_onCustomerChange);
    if (_storeProvider != null) _storeProvider!.removeListener(_onStoreChange);
    if (_authProvider != null) _authProvider!.removeListener(_onAuthChange);
    
    _countersSubscription?.cancel();
    _timeUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  bool _isInitStarted = false;

  void init() {
    debugPrint('🏗️ DashboardProvider.init START');
    try {
      if (_isInitStarted) return;
      _isInitStarted = true;
      if (_isInitialized) return;
      // _isInitialized = true; // REMOVED: Set true only after first data fetch or failure
      
      debugPrint('📦 DashboardProvider: Loading from cache...');
      _loadDeveloperMode();
      _loadFromCache();
      _loadConsumableDurationFromCache(); 
      _loadGlobalSettingsFromCache(); 

      try {
        debugPrint('🎨 DashboardProvider: Loading user preferences...');
        _loadUserPreferences();
      } catch (e) {
         debugPrint('❌ DashboardProvider: Prefs Load Error: $e');
      }

      debugPrint('📐 DashboardProvider: Loading layout...');
      loadLayout();
      
      debugPrint('🛠️ DashboardProvider: Loading Admin Config...');
      _loadAdminConfig();
      _loadPlatformLimits(); 
      
      debugPrint('☁️ DashboardProvider: Init Backup Service...');
      _initBackupService();
      refreshAvailableBackups(); // Fetch backups early

      debugPrint('🔒 DashboardProvider: Init Kiosk Mode...');
      _initKioskMode();

      if (!kIsWeb) {
         _checkPrinterSetup();
      }
      
      debugPrint('🔑 DashboardProvider: Setting up Auth Listener...');
      final authSub = _auth?.authStateChanges().listen((user) async {
        if (_isDisposed) return;
        if (user != null) {
          debugPrint('👤 DashboardProvider: User detected: ${user.uid}');
          await DatabaseHelper.switchUser(user.uid);
          await _restorePinnedStore(uid: user.uid); 
          await _fetchUserData(user.uid); // AWAIT THIS
          _listenToGlobalSettings(); 
        } else {
          debugPrint('👤 DashboardProvider: No user logged in (or Offline Mode).');
          if (_isOfflineLoggedIn) {
             await _checkOfflineSession();
          } else {
             _userProfile = null;
             _activeRole = 'Unauthorized';
             _isInitialized = true;
             _routerNotifier?.notify();
             notifyListeners();
          }
        }
      });
      if (authSub != null) {
        _subscriptions.add(authSub);
      }
      debugPrint('✅ DashboardProvider.init END');
    } catch (e, stack) {
      debugPrint('❌ DashboardProvider.init CRITICAL ERROR: $e');
      debugPrintStack(stackTrace: stack);
    }
  }
  
  String _syncStatus = 'Idle';
  bool _isSyncing = false;

  Future<void> _initSync() async {
    await _syncService.init();
    await _loadFromCache();
    
    // Run Recovery Runner on startup
    await _runRecoveryRunner();

    // Initial pull
    if (_activeStoreId != null) {
      final prefsBox = Hive.box('settings');
      final setupKey = 'initial_sync_completed_$_activeStoreId';
      final isSetupCompleted = prefsBox.get(setupKey, defaultValue: false) == true;
      final isOnline = _syncService.isOnline;

      if (!isSetupCompleted && isOnline) {
        _isInitialSyncing = true;
        _initialSyncProgress = 0.0;
        _initialSyncStatus = "Connecting to store...";
        notifyListeners();

        try {
          await _performInitialSetupSync();
          await prefsBox.put(setupKey, true);
          await reloadLocalData();
        } catch (e) {
          debugPrint("❌ DashboardProvider: Initial setup sync failed: $e");
        } finally {
          _isInitialSyncing = false;
          notifyListeners();
        }
      } else {
        await _syncService.processSync();
      }
    }
  }

  Future<void> _performInitialSetupSync() async {
    final modules = [
      SyncCollectionRegistry.settings,
      SyncCollectionRegistry.employees,
      SyncCollectionRegistry.floors,
      SyncCollectionRegistry.tables,
      SyncCollectionRegistry.suppliers,
      SyncCollectionRegistry.customers,
      SyncCollectionRegistry.inventory,
      SyncCollectionRegistry.orders,
      SyncCollectionRegistry.notes,
      SyncCollectionRegistry.inventoryMovements,
    ];
    
    double progressPerModule = 1.0 / modules.length;
    
    for (int i = 0; i < modules.length; i++) {
      final module = modules[i];
      
      final displayName = module[0].toUpperCase() + module.substring(1).replaceAll('_', ' ');
      _initialSyncStatus = "Setting up $displayName...";
      notifyListeners();
      
      try {
        await _syncService.pullCollection(module, forceFull: true);
      } catch (e) {
        debugPrint("📥 [InitialSync] Error pulling $module: $e");
      }
      
      _initialSyncProgress = (i + 1) * progressPerModule;
      notifyListeners();
      
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    _initialSyncStatus = "Finalizing store configuration...";
    _initialSyncProgress = 1.0;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 600));
  }

  Future<void> _runRecoveryRunner() async {
    debugPrint('🔍 DashboardProvider: Running Recovery Service...');
    try {
      final recoveries = await _recoveryService.scanAndRecover();
      _pendingRecoveries = recoveries;
      if (_pendingRecoveries.isNotEmpty) {
        debugPrint('⚠️ DashboardProvider: Found ${_pendingRecoveries.length} incomplete transactions!');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ DashboardProvider: Error running recovery: $e');
    }
  }

  Future<void> discardRecovery(String txId) async {
    await _recoveryService.discardTransaction(txId);
    _pendingRecoveries.removeWhere((t) => t['txId'] == txId);
    notifyListeners();
  }

  Future<void> resolveRecovery(String txId, BuildContext context) async {
    final tx = _pendingRecoveries.firstWhere((t) => t['txId'] == txId, orElse: () => {});
    if (tx.isEmpty) return;

    try {
      final raw = tx['raw'] as String;
      
      // Execute Replay via Repository (OrderRepositoryMixin)
      await _repository.replayTransaction(txId, raw);

      // Clean up local state
      _pendingRecoveries.removeWhere((t) => t['txId'] == txId);
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction recovered successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ DashboardProvider: Error resolving recovery: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to recover: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void updateAuthStatus(bool status) {
    if (_isOfflineLoggedIn != status) {
       _isOfflineLoggedIn = status;
       notifyListeners();
    }
    if (status && _userProfile == null) {
       rehydrateOfflineUser();
    }
    if (_isOfflineLoggedIn) {
       _checkOfflineSession();
    }
  }

  AuthProvider? _authProvider;
  void injectAuthProvider(AuthProvider provider) {
    if (_authProvider == provider) return;
    if (_authProvider != null) {
      _authProvider!.removeListener(_onAuthChange);
    }
    _authProvider = provider;
    _authProvider!.addListener(_onAuthChange);
    _onAuthChange();
  }

  void _onAuthChange() {
    if (_authProvider != null) {
      updateAuthStatus(_authProvider!.isOfflineLoggedIn);
    }
  }

  InventoryProvider? _inventoryProvider;
  OrderProvider? _orderProvider;
  CustomerProvider? _customerProvider;
  CustomerProvider? get customerProvider => _customerProvider;
  StoreProvider? _storeProvider; 
  
  void injectInventory(InventoryProvider provider) {
    if (_inventoryProvider == provider) return;
    if (_inventoryProvider != null) {
       _inventoryProvider!.removeListener(_onInventoryChange);
    }
    _inventoryProvider = provider;
    _inventoryProvider!.addListener(_onInventoryChange);
    notifyListeners();
  }

  void injectOrderProvider(OrderProvider provider) {
    if (_orderProvider == provider) return;
    if (_orderProvider != null) {
       _orderProvider!.removeListener(_onOrderChange);
    }
    _orderProvider = provider;
    _orderProvider!.addListener(_onOrderChange);
    notifyListeners();
  }

  void injectCustomerProvider(CustomerProvider provider) {
    if (_customerProvider == provider) return;
    if (_customerProvider != null) {
       _customerProvider!.removeListener(_onCustomerChange);
    }
    _customerProvider = provider;
    _customerProvider!.addListener(_onCustomerChange);
    notifyListeners();
  }
  
  void injectStoreProvider(StoreProvider provider) {
    if (_storeProvider == provider) return;
    if (_storeProvider != null) {
       _storeProvider!.removeListener(_onStoreChange);
    }
    _storeProvider = provider;
    _storeProvider!.addListener(_onStoreChange);

    // FIX: Android Race Condition (STABILIZED)
    // On Android, Firebase resolves cached auth SYNCHRONOUSLY, so _fetchUserData
    // runs BEFORE injectStoreProvider is called. The store loading block was skipped
    // because _storeProvider was null. Now we detect that case and schedule a
    // deferred retry instead of force-resetting the lock (which caused
    // "Future already completed" crashes from re-entrant calls).
    final user = _auth?.currentUser;
    if (user != null && _stores.isEmpty && _activeStoreId == null && _userProfile != null) {
      debugPrint('🔁 DashboardProvider: StoreProvider injected after auth fired. Scheduling deferred retry...');
      _pendingStoreRetry = true;
      // Use scheduleMicrotask to ensure the current _fetchUserData call has
      // fully completed (including its finally block) before we retry.
      Future.microtask(() {
        if (_pendingStoreRetry && !_isDisposed) {
          _pendingStoreRetry = false;
          _isInitialized = false;
          _hasCheckedStores = false;
          // _isFetchingUserData will be false by now (set in finally block)
          debugPrint('🔁 DashboardProvider: Executing deferred _fetchUserData retry');
          _fetchUserData(user.uid);
        }
      });
    }

    notifyListeners();
  }

  void injectRouterNotifier(RouterNotifier notifier) {
    _routerNotifier = notifier;
  }

  /// Safety-net: Called by StoreSelectScreen if it mounts with empty stores.
  /// Re-fetches stores from cache + Firestore and updates local state.
  Future<void> fetchStoresDirectly() async {
    debugPrint('🛡️ DashboardProvider.fetchStoresDirectly: Safety-net store fetch triggered');
    
    // 1. Try cache first for instant UI (uid-isolated)
    final uid = _auth?.currentUser?.uid;
    final cachedStores = await OfflineService().getCachedUserStores(uid: uid);
    if (cachedStores.isNotEmpty) {
      _stores = cachedStores.map((m) => Store.fromMap(m, m['id']?.toString() ?? '')).toList();
      debugPrint('📦 DashboardProvider: Loaded ${_stores.length} stores from cache (safety-net, uid: $uid)');
      _hasCheckedStores = true;
      notifyListeners();
    }
    
    // 2. Then fetch fresh from Firestore via StoreProvider
    if (_storeProvider != null) {
      try {
        await _storeProvider!.fetchStores(isSuperAdmin: isSuperAdmin);
        final freshStores = _storeProvider!.stores;
        if (freshStores.isNotEmpty) {
          _stores = freshStores;
          debugPrint('✅ DashboardProvider: Safety-net fetched ${_stores.length} stores from Firestore');
        }
      } catch (e) {
        debugPrint('❌ DashboardProvider: Safety-net Firestore fetch failed: $e');
      }
    }
    
    _hasCheckedStores = true;
    _isInitialized = true;
    
    // 3. Auto-select logic: If exactly one store is found and no store is active, select it automatically.
    // This addresses the "open correct linked store instantly" request.
    if (_activeStoreId == null && _stores.length == 1) {
       final soloStoreId = _stores.first.id;
       debugPrint('🎯 DashboardProvider: Auto-selecting single store after refresh: $soloStoreId');
       _activeStoreId = soloStoreId;
       if (_storeProvider != null) {
          await _storeProvider!.setActiveStoreId(soloStoreId);
       }
    } else if (_activeStoreId == null) {
       // Try to restore pinned store if we still don't have an active one
        final uid = _auth?.currentUser?.uid;
       if (uid != null) {
          await _restorePinnedStore(uid: uid);
       }
    }
    
    debugPrint('🏁 DashboardProvider: fetchStoresDirectly completed. Stores: ${_stores.length}, Active: $_activeStoreId');
    _routerNotifier?.notify(); 
    notifyListeners();
  }
  
  // Delegation
  Future<void> fetchRoles() async {
      if (_storeProvider != null) {
          await _storeProvider!.fetchRoles();
          _roles = _storeProvider!.roles;
          notifyListeners();
      }
  }

  Future<void> updateStoreStatus(String id, String status) async {
      if (_storeProvider != null) await _storeProvider!.updateStoreStatus(id, status);
  }

  Future<List<String>> fetchStoreTypes() async {
      if (_storeProvider != null) {
          return await _storeProvider!.fetchStoreTypes();
      }
      return [];
  }

  void _onInventoryChange() {
      notifyListeners();
  }
  
  bool _needsPrinterSetup = false;
  bool get needsPrinterSetup => _needsPrinterSetup;

  void dismissPrinterSetup() {
    _needsPrinterSetup = false;
    final box = Hive.box('settings');
    box.put('printer_setup_prompted', true);
    notifyListeners();
  }

  void _onOrderChange() {
    if (_orderProvider != null) {
       _orders = _orderProvider!.orders; 
       _isLoadingOrders = _orderProvider!.isLoading;
       _hasMoreOrders = _orderProvider!.hasMore;
    }
    notifyListeners();
  }




  void _onCustomerChange() {
    if (_customerProvider != null) {
       _customers = _customerProvider!.customers;
    }
    notifyListeners();
  }
  
  void logout() {
     clearSession();
  }

  Future<List<OrderModel>> fetchCustomerOrders(String customerId) async {
      if (_orderProvider != null) {
          return await _repository.getOrdersByCustomer(_activeStoreId!, customerId);
      }
      return [];
  }

  // --- INVENTORY METHODS (LEGACY BRIDGE) ---
  
  Future<void> addItem(InventoryItem item) async {
    if (_inventoryProvider != null) {
      final entity = InventoryMapper.fromLegacy(item);
      await _inventoryProvider!.saveItem(entity);
      notifyListeners();
    }
  }

  Future<void> updateItem(InventoryItem item) async {
    if (_inventoryProvider != null) {
      final entity = InventoryMapper.fromLegacy(item);
      await _inventoryProvider!.saveItem(entity);
      notifyListeners();
    }
  }

  Future<void> requestDemo(String name, String phone) async {
      await _db.collection('leads').add({
          'name': name, 'phone': phone, 'createdAt': FieldValue.serverTimestamp()
      });
  }

  Future<void> updateUserProfile({String? name, String? phone, String? phoneNumber, String? email, String? photoBase64}) async {
      if (_userProfile == null) return;
      _userProfile = _userProfile!.copyWith(
         name: name ?? _userProfile!.name,
         pinHash: phone ?? phoneNumber ?? _userProfile!.pinHash, 
      );
      notifyListeners();
  }

  Future<void> importCentralItem(InventoryItem item, {String? storeId, double? overridePrice, num? overrideQty, double? overrideCost, String? counterId}) async {
      if (_inventoryProvider != null) {
          final targetStoreId = storeId ?? _activeStoreId;
          if (targetStoreId == null) return;
          
          final newItem = item.copyWith(
             id: const Uuid().v4(),
             storeId: targetStoreId,
             price: overridePrice ?? item.price,
             quantity: (overrideQty ?? item.quantity).toInt(),
             cost: overrideCost ?? item.cost
          );
          await _inventoryProvider!.addInventoryItem(newItem, _activeStoreId!);
      }
  }



  bool _dataControlGridView = false;
  bool get dataControlGridView => _dataControlGridView;
  void setDataControlGridView(bool val) {
     _dataControlGridView = val;
     notifyListeners();
  }

  Future<Map<String, dynamic>> fetchPaginatedCentralInventory({int limit = 20, DocumentSnapshot? startAfter, String? queryStr, String? filterStoreType}) async {
      Query q = _db.collection('central_catalog');
      if (filterStoreType != null && filterStoreType.isNotEmpty) {
          q = q.where('storeType', isEqualTo: filterStoreType);
      } else {
          q = q.orderBy('name');
      }
      q = q.limit(limit);
      if (startAfter != null) {
          q = q.startAfterDocument(startAfter);
      }
      try {
        final snap = await q.get();
        var items = snap.docs.map((d) => InventoryItem.fromMap(d.data() as Map<String,dynamic>, d.id)).toList();
        if (filterStoreType != null && filterStoreType.isNotEmpty) {
           items.sort((a, b) => a.name.compareTo(b.name));
        }
        return {
            'items': items,
            'lastDoc': snap.docs.isNotEmpty ? snap.docs.last : null
        };
      } catch (e) {
         rethrow;
      }
  }

  Future<String> validateDatabase() async {
      return await _syncService.checkIntegrity();
  }

  Future<String> requestLogs() async {
      return "Logs unavailable in release build";
  }

  Future<void> deleteUser(String uid) async {
       try {
         final callable = FirebaseFunctions.instance.httpsCallable('deleteUserAuth');
         await callable.call({'uid': uid});
       } catch (e) {
         debugPrint("Note: Could not delete user from Auth: $e");
       }
       await _db.collection('users').doc(uid).delete();
       if (_storeProvider != null && _activeStoreId != null) {
           await _db.collection('stores').doc(_activeStoreId).collection('employees').doc(uid).delete();
       }
       _systemUsers.removeWhere((u) => u.uid == uid);
       notifyListeners();
  }

  Future<void> _checkAndAutoActivateReadySubs() async {
    if (activeStore == null) return;
    final String checkingStoreId = activeStore!.id; 
    final now = DateTime.now();
    final activeSubs = _subscriptionHistory.where((h) => h.isActive && h.endDate.isAfter(now)).toList();
    final hasActiveBase = activeSubs.any((h) => !h.isAddonOnly && h.planName == 'Standard');
    
    if (hasActiveBase) {
      const String plan = 'Standard';
      final Set<String> activeAddons = Set<String>.from(activeStore!.purchasedAddons);
      for (var sub in activeSubs) {
        activeAddons.addAll(sub.selectedAddons);
      }
      final List<String> addonList = activeAddons.toList();
      bool planMismatch = activeStore!.subscriptionPlan != plan;
      bool addonsMismatch = !listEquals(activeStore!.addons, addonList);
      
      if (planMismatch || addonsMismatch) {
        if (activeStore?.id != checkingStoreId) return;
        await _db.collection('stores').doc(checkingStoreId).update({
          'subscriptionPlan': plan,
          'addons': addonList,
        });
        await _updateLocalStoreState(plan, addonList);
      }
      return;
    }

    if (activeStore!.autoActivateSubscription) {
      try {
        final snapshot = await _db.collection('stores').doc(checkingStoreId)
            .collection('subscription_history')
            .get();

        final queuedSubs = snapshot.docs
            .map((d) => SubscriptionHistory.fromMap(d.data(), d.id))
            .where((h) => h.status == 'QUEUED')
            .toList();

        if (queuedSubs.isNotEmpty) {
          if (activeStore?.id != checkingStoreId) return;
          queuedSubs.sort((a, b) => a.startDate.compareTo(b.startDate));
          await activateSubscriptionCoupon(queuedSubs.first.id);
          return;
        }
      } catch (e) {
        debugPrint("Error auto-activating sub: $e");
      }
    }

    if (!_subscriptionHistoryLoaded) return;

    if (activeStore!.subscriptionPlan != 'Basic' || activeStore!.addons.length != activeStore!.purchasedAddons.length) {
      if (activeStore?.id != checkingStoreId) return;
      final List<String> permanentAddons = activeStore!.purchasedAddons;
      await _db.collection('stores').doc(checkingStoreId).update({
        'subscriptionPlan': 'Basic',
        'addons': permanentAddons,
      });
      await _updateLocalStoreState('Basic', permanentAddons);
    }
  }

  int get consolidatedStandardDays => _getConsolidatedStandardDays();

  Future<DateTime> _getLatestSubscriptionEndDate(String storeId) async {
    final snapshot = await _db.collection('stores').doc(storeId)
        .collection('subscription_history')
        .get();
    final histories = snapshot.docs.map((d) => SubscriptionHistory.fromMap(d.data(), d.id)).toList();
    final relevant = histories.where((h) => (h.status == 'ACTIVE' || h.status == 'QUEUED') && h.endDate.isAfter(DateTime.now())).toList();
    if (relevant.isEmpty) return DateTime.now();
    DateTime maxEnd = DateTime.now();
    for (var h in relevant) {
      if (h.endDate.isAfter(maxEnd)) maxEnd = h.endDate;
    }
    return maxEnd;
  }

  Future<void> _updateLocalStoreState(String plan, List<String> addons) async {
    if (activeStore == null) return;
    // Actually update the store state via StoreProvider (the source of truth for activeStore)
    if (_storeProvider != null && _activeStoreId != null) {
      try {
        final updatedStore = activeStore!.copyWith(
          subscriptionPlan: plan,
          addons: addons,
        );
        await _storeProvider!.updateStoreSettings(updatedStore);
      } catch (e) {
        debugPrint('⚠️ DashboardProvider._updateLocalStoreState: $e');
      }
    }
    notifyListeners();
  }

  Future<void> toggleAutoActivateSub(bool value) async {
    if (activeStore == null) return;
    try {
      await _db.collection('stores').doc(activeStore!.id).update({
        'autoActivateSubscription': value,
      });
      if (value) {
        _checkAndAutoActivateReadySubs();
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error toggling auto-activate: $e");
      rethrow;
    }
  }

  Future<void> activateSubscriptionCoupon(String historyId) async {
    if (activeStore == null) return;
    try {
      final subDocRef = _db.collection('stores').doc(activeStore!.id)
          .collection('subscription_history').doc(historyId);
      final subDoc = await subDocRef.get();
      if (!subDoc.exists) return;
      final data = subDoc.data()!;
      if (data['status'] == 'ACTIVE') return; 
      final cycle = data['billingCycle'] ?? 'Monthly';
      final startDate = await _getLatestSubscriptionEndDate(activeStore!.id);
      final endDate = cycle == 'Yearly' 
          ? startDate.add(const Duration(days: 365)) 
          : startDate.add(const Duration(days: 30));

      await subDocRef.update({
        'status': 'ACTIVE',
        'startDate': startDate.millisecondsSinceEpoch,
        'endDate': endDate.millisecondsSinceEpoch,
      });

      await _db.collection('stores').doc(activeStore!.id).update({
        'subscriptionPlan': 'Standard',
      });
      
      // Refresh local state and subscription history
      final selectedAddons = List<String>.from(data['selectedAddons'] ?? []);
      final currentAddons = Set<String>.from(activeStore!.addons);
      currentAddons.addAll(selectedAddons);
      await _updateLocalStoreState('Standard', currentAddons.toList());
      await fetchSubscriptionHistory();
      notifyListeners();
    } catch (e) {
      debugPrint("Error activating coupon: $e");
      rethrow;
    }
  }

  Future<void> updateUserRole(String uid, String role) async {
       await _db.collection('users').doc(uid).update({'role': role});
       notifyListeners();
  }

  Future<void> updateUserStores(String uid, List<String> storeIds) async {
        await _db.collection('users').doc(uid).update({'storeIds': storeIds});
        notifyListeners();
  }

  Future<Map<String, int>> getUserStats() async {
       final userCount = await _db.collection('users').count().get();
       final adminCount = await _db.collection('users').where('role', isEqualTo: 'Admin').count().get();
       final activeUserCount = await _db.collection('users').where('role', isNotEqualTo: 'Unauthorized').count().get();
       final activeSubCount = await _db.collection('stores')
           .where('subscriptionPlan', whereIn: ['Starting', 'Standard', 'Premium', 'Elite', 'Enterprise'])
           .count().get();

       return {
          'total': userCount.count ?? 0,
          'admins': adminCount.count ?? 0,
          'active': activeUserCount.count ?? 0,
          'subscriptions': activeSubCount.count ?? 0,
       };
  }

  Future<List<UserProfile>> searchUsers(String query) async {
       if (query.isEmpty) return [];
       final snap = await _db.collection('users')
           .where('name', isGreaterThanOrEqualTo: query)
           .where('name', isLessThan: '${query}z')
           .limit(20)
           .get();
       return snap.docs.map((d) => UserProfile.fromMap(d.data(), d.id)).toList();
  }

  Future<List<UserProfile>> fetchPotentialStoreOwners() async {
       final custom = await _db.collection('users').get();
       return custom.docs.map((d) => UserProfile.fromMap(d.data(), d.id)).toList();
  }

  Future<void> inviteEmployee(String email, String role, String name) async {}

  List<UserProfile> get systemUsers {
    if (_activeRole == 'Super Admin' || _activeRole == 'Store Owner' || _activeRole == 'Franchise Owner') {
      return _systemUsers;
    }
    return _employees;
  }

  Future<void> fetchSystemUsers() async {
      try {
        final s = await _db.collection('users').get();
        _systemUsers = s.docs.map((d) => UserProfile.fromMap(d.data(), d.id)).toList();
        notifyListeners();
      } catch (e) {
        debugPrint('Error fetching system users: $e');
      }
  }

  Future<void> fetchStores() async {
      if (_storeProvider != null) {
        await _storeProvider!.fetchStores(isSuperAdmin: isSuperAdmin);
        _stores = _storeProvider!.stores;
        notifyListeners();
      }
  }

  Future<String> addStore(String name, String owner, {String? address, String? phone, String? franchiseCode, String storeType = 'Restaurant'}) async {
      if (_storeProvider != null) {
          return await _storeProvider!.addStore(name, owner, address: address, phone: phone, franchiseCode: franchiseCode, storeType: storeType);
      }
      return '';
  }

  Future<void> deleteStore(String id) async {
      if (_storeProvider != null) await _storeProvider!.deleteStore(id);
  }

  List<String> get globalDisabledAddons {
    final addons = _adminConfig['disabledAddons'];
    if (addons is List) {
      return addons.map((e) => e.toString()).toList();
    }
    return [];
  }

  bool hasAddon(String key) {
    if (globalDisabledAddons.contains(key)) {
      debugPrint('🔒 hasAddon($key): BLOCKED by globalDisabledAddons');
      return false;
    }
    if (activeStore == null) {
      debugPrint('🔒 hasAddon($key): BLOCKED - activeStore is null');
      return false;
    }

    // Resolve feature status based on store type configurations
    final type = activeStore!.storeType;
    final config = _storeTypeConfigs[type];
    if (config is Map && config.containsKey(key)) {
      final isEnabled = config[key] == true;
      debugPrint('🔑 hasAddon($key): RESOLVED by storeType $type config = $isEnabled');
      return isEnabled;
    }

    // Default templates if no custom config exists yet
    if (type == 'Restaurant') {
      if (['table_reservation', 'kds_management', 'employee_management'].contains(key)) return true;
      if (['barcode_scanner'].contains(key)) return false;
    } else if (type == 'Grocery' || type == 'Supermarket') {
      if (['barcode_scanner', 'customer_management', 'supplier_management', 'data_center'].contains(key)) return true;
      if (['table_reservation', 'kds_management'].contains(key)) return false;
    }

    if (activeStore!.subscriptionPlan != 'Standard') {
      debugPrint('🔒 hasAddon($key): BLOCKED - store is on ${activeStore!.subscriptionPlan} plan (not Standard)');
      return false;
    }
    if (_userProfile != null && _userProfile!.role != 'Store Owner' && _userProfile!.role != 'Franchise Owner' && _userProfile!.accessibleAddons != null) {
       if (!_userProfile!.accessibleAddons!.contains(key)) {
         debugPrint('🔒 hasAddon($key): BLOCKED by accessibleAddons filter (role: ${_userProfile!.role})');
         return false;
       }
    }
    final result = activeStore!.addons.contains(key);
    debugPrint('🔑 hasAddon($key): $result | addons=${activeStore!.addons} | purchasedAddons=${activeStore!.purchasedAddons} | plan=${activeStore!.subscriptionPlan}');
    return result;
  }

  Future<void> updateStoreAddons(List<String> newAddons) async {
    if (activeStore == null) return;
    if (_storeProvider != null) {
        await _storeProvider!.updateStoreAddons(activeStore!.id, newAddons);
        notifyListeners();
        return;
    }
    final oldAddons = List<String>.from(activeStore!.addons);
    try {
      final updatedStore = activeStore!.copyWith(addons: newAddons);
      final storeIndex = stores.indexWhere((s) => s.id == activeStore!.id);
      if (storeIndex != -1) {
        _stores[storeIndex] = updatedStore;
      }
      if (Hive.isBoxOpen('cache_stores')) {
         Hive.box('cache_stores').put(updatedStore.id, updatedStore.toMap());
      }
      notifyListeners();
      await _db.collection('stores').doc(updatedStore.id).update({
        'addons': newAddons,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Don't notify on error — state hasn't changed
      rethrow;
    }
  }

  Future<void> updateStorePlan(String newPlan) async {
    if (activeStore == null) return;
    try {
      final storeIndex = stores.indexWhere((s) => s.id == activeStore!.id);
      if (storeIndex != -1) {
        _stores[storeIndex] = activeStore!;
      }
      if (Hive.isBoxOpen('cache_stores')) {
         Hive.box('cache_stores').put(activeStore!.id, activeStore!.toMap());
      }
      notifyListeners();
    } catch (e) {
      notifyListeners();
      rethrow;
    }
  }

  final bool _userOverriddenTheme = false;
  int? _customThemeColor;
  UserProfile? get userProfile => _userProfile;
  StoreSettings? get storeSettings => _storeSettings;
  String get dashboardBgType => _dashboardBgType;
  String get dashboardBgSource => _dashboardBgSource;
  String get heroButtonStyle => _heroButtonStyle;
  Color get heroButtonColor => _heroButtonColor;
  Store? get activeStore => _storeProvider?.activeStore;
  String? get activeStoreId => _activeStoreId;
  String get activeRole => _activeRole;
  bool get isSuperAdmin => _activeRole == 'Super Admin' || _superAdmins.any((a) => a.uid == _userProfile?.uid);
  bool get isLoading => _isLoading;
  bool get isOnline => _isOnline;
  bool get isDataControlGridView => _isDataControlGridView;
  bool get isAutoBackupEnabled => _storeProvider?.autoBackupEnabled ?? false;
  TimeOfDay get backupTime => _storeProvider?.backupTime ?? const TimeOfDay(hour: 0, minute: 0);
  String get backupFrequency => _storeProvider?.backupFrequency ?? 'Daily';
  String get subscriptionStatusMessage => 'Active';
  List<InventoryItem> get centralInventory => _centralInventory;
  int? get customThemeColor => _customThemeColor;

  DateTime? _lastSyncReload;
  Timer? _syncDebounceTimer;

  void _onSyncUpdate() {
    final newStatus = _syncService.syncStatus;
    final newBusy = _syncService.isBusy;
    final statusChanged = _syncStatus != newStatus || _isSyncing != newBusy;

    _syncStatus = newStatus;
    _isSyncing = newBusy;

    if (newStatus == 'Synced') {
       final now = DateTime.now();
       if (_lastSyncReload == null || now.difference(_lastSyncReload!).inSeconds >= 2) {
          _lastSyncReload = now;
          _loadFromCache();
       }
    }
    // Only notify if something actually changed, with debouncing
    if (statusChanged) {
      _syncDebounceTimer?.cancel();
      _syncDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (!_isDisposed) {
          debugPrint('🔄 DashboardProvider: Debounced sync update notification');
          notifyListeners();
        }
      });
    }
  }
  
  final Map<String, int> _cart = {};
  Map<String, int> get cart => _cart;

  void addToCart(InventoryItem item) {
    _cart[item.id] = (_cart[item.id] ?? 0) + 1;
    notifyListeners();
  }

  void removeFromCart(String itemId) {
    if (_cart.containsKey(itemId)) {
      if (_cart[itemId]! > 1) {
        _cart[itemId] = _cart[itemId]! - 1;
      } else {
        _cart.remove(itemId);
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  double calculateCartTotal(List<InventoryItem> inventory) {
    double total = 0;
    _cart.forEach((itemId, quantity) {
      try {
        final item = inventory.firstWhere((i) => i.id == itemId);
        total += item.price * quantity;
      } catch (e) {
        // Item not found in inventory
      }
    });
    return total;
  }

  UserProfile? _originalProfile; 
  UserProfile? get originalProfile => _originalProfile;

  Future<void> restoreOwnerSession() async {
      if (_originalProfile != null) {
          _userProfile = _originalProfile;
          _originalProfile = null;
          notifyListeners();
      }
  }

  Future<void> loadEmployeeProfileForVirtualLogin(String uid, Map<String, dynamic> userData) async {
      _userProfile = UserProfile.fromMap(userData, uid);
      _activeRole = userData['role'] ?? 'Cashier';
      notifyListeners();
  }

  Future<void> clearSession() async {
       // 1. FIRESTORE CLEANUP (While Authenticated)
       try {
          if (_activeStoreId != null) {
             String currentDeviceId = "unknown";
             if (Hive.isBoxOpen('settings')) {
                currentDeviceId = Hive.box('settings').get('app_device_id', defaultValue: 'unknown');
             }
             if (activeStore?.subscriptionPlan == 'Basic' || activeStore?.subscriptionPlan == 'Free') {
                await _db.collection('stores').doc(_activeStoreId).update({
                   'activeDeviceId': null
                }).timeout(const Duration(seconds: 5));
             }
          }
        } catch(e) { /* Permission error likely or timeout */ }

       // 2. INTERNAL STATE CLEARING
       // NOTE: We intentionally do NOT unpin the store or clear cache_user_stores.
       // This ensures that on re-login, the pinned store and cached store list
       // survive and can be restored immediately without waiting for Firestore.
       // _restorePinnedStore validates the ID against the user's store list anyway.
       _activeStoreId = null;
       _subscriptionHistoryLoaded = false; 
       _subscriptionHistory = [];
       _userProfile = null;
       _originalProfile = null;
       _stores = [];
       _hasCheckedStores = false;
       
       // CRITICAL: Reset ALL initialization flags so the next login starts fresh
       _isInitialized = false;
       _isInitStarted = false;
       _isFetchingUserData = false;
       _pendingStoreRetry = false;
       _fetchGeneration++; // Invalidate any in-flight fetches

       // 3. HIVE CACHE CLEARING (order/inventory caches only, NOT store caches)
       final cachesToClear = ['cache_orders', 'cache_inventory', 'cache_customers', 'cache_employees'];
       for (var cache in cachesToClear) {
           if (Hive.isBoxOpen(cache)) await Hive.box(cache).clear();
       }

       if (_storeProvider != null) {
           _storeProvider!.clearStores();
       }
       _superAdmins.clear();

       // 4. AUTH SIGN OUT (Last step)
       await OfflineService().clearCredentials(); 
       await _auth?.signOut();
       await DatabaseHelper.switchUser(null);
       
       notifyListeners();
   }

  bool isFeatureEnabled(String key) {
    // Core features that are always enabled
    if (['dashboard', 'pos', 'reports', 'settings'].contains(key)) return true;
    String internalAddonKey = key;
    if (key == 'crm') internalAddonKey = 'customer_management';
    if (key == 'employees') internalAddonKey = 'employee_management';
    if (key == 'inventory') internalAddonKey = 'inventory_management';

    const addonKeys = [
      'customer_management', 'franchise_management', 'central_catalog',
      'employee_management', 'supplier_management', 'kds_management',
      'table_reservation', 'data_center', 'integration_hub', 'loyalty_program'
    ];

    if (addonKeys.contains(internalAddonKey)) {
      if (!hasAddon(internalAddonKey)) {
        debugPrint('⛔ isFeatureEnabled($key → $internalAddonKey): HIDDEN - addon not purchased');
        return false;
      }
    }

    if (activeRole != 'Store Owner' && activeRole != 'Admin' && activeRole != 'Super Admin' && activeRole != 'Franchise Owner') {
      if (key == 'admin') return false;
      final store = activeStore;
      final userRole = _userProfile?.role;
      if (store != null && userRole != null && store.rolePermissions.containsKey(userRole)) {
        final perms = store.rolePermissions[userRole]!;
        if (perms.containsKey(key)) {
          return perms[key] == true;
        }
        return false;
      }
      return true;
    }
    return true;
  }


  
  


  List<Map<String, dynamic>> getSalesForecast() {
      final now = DateTime.now();
      return List.generate(3, (index) {
          final day = now.add(Duration(days: index + 1));
          return {
             'day': "${day.day}/${day.month}", 
             'sales': 5000.0 + (index * 500), 
             'isForecast': true
          };
      });
  }



  void saveKioskPreference(bool enabled) {
    if (Hive.isBoxOpen('settings')) {
       Hive.box('settings').put('isKioskModeEnabled', enabled);
    }
  }

  Future<void> _initKioskMode() async {
     if (!isTesting) {
       await Future.delayed(const Duration(seconds: 1));
     }
  }

  void updateDashboardSettings({String? bgType, String? bgSource, String? heroStyle, Color? heroColor, bool? showSeconds}) {
    if (bgType != null) _dashboardBgType = bgType;
    if (bgSource != null) _dashboardBgSource = bgSource;
    if (heroStyle != null) _heroButtonStyle = heroStyle;
    if (heroColor != null) _heroButtonColor = heroColor;
    if (showSeconds != null) _showClockSeconds = showSeconds;
    _saveUserPreference('dashboardBgType', _dashboardBgType);
    _saveUserPreference('dashboardBgSource', _dashboardBgSource);
    _saveUserPreference('heroButtonStyle', _heroButtonStyle);
    _saveUserPreference('heroButtonColor', _heroButtonColor.value);
    _saveUserPreference('showClockSeconds', _showClockSeconds);
    notifyListeners();
  }

  void _saveUserPreference(String key, dynamic value) {
    if (!Hive.isBoxOpen('settings')) return;
    final uid = _userProfile?.uid ?? 'guest';
    Hive.box('settings').put('${uid}_$key', value);
  }

  void _loadUserPreferences() {
    if (!Hive.isBoxOpen('settings')) return;
    final uid = _userProfile?.uid ?? 'guest';
    final box = Hive.box('settings');
    _isDarkMode = box.get('${uid}_isDarkMode', defaultValue: false);
    final themeIndex = box.get('${uid}_themeColor', defaultValue: 0);
    _currentTheme = AppColorTheme.values[themeIndex];
    final styleIndex = box.get('${uid}_uiStyle', defaultValue: 0);
    _uiStyle = UIStyle.values[styleIndex];
    _dashboardBgType = box.get('${uid}_dashboardBgType', defaultValue: 'video');
    _dashboardBgSource = box.get('${uid}_dashboardBgSource', defaultValue: 'https://www.shutterstock.com/shutterstock/videos/3789099487/preview/stock-footage-hyperspace-travel-loop-k-vertical.webm');
    _heroButtonStyle = box.get('${uid}_heroButtonStyle', defaultValue: 'glass');
    final colorInt = box.get('${uid}_heroButtonColor', defaultValue: 4294922834);
    _heroButtonColor = Color(colorInt);
    _showClockSeconds = box.get('${uid}_showClockSeconds', defaultValue: true);
    _isDataControlGridView = box.get('${uid}_isDataControlGridView', defaultValue: true);
    if (_activeStoreId == null) {
       final lastStoreId = box.get('last_store_$uid');
       if (lastStoreId != null) setActiveStoreId(lastStoreId!);
    }
    loadLayout();
    notifyListeners();
  }

  void _initBackupService() {
    _driveService.restoreSession().then((_) {
       notifyListeners();
    });
    
    // Load last backup time from Hive
    if (Hive.isBoxOpen('settings')) {
      final lastTimeStr = Hive.box('settings').get('lastAutoBackup');
      if (lastTimeStr != null) {
        _lastAutoBackup = DateTime.tryParse(lastTimeStr);
      }
    }

    if (autoBackupEnabled) {
      _startAutoBackupTimer();
    }
  }

  Future<void> reloadLocalData() async {
     await _loadFromCache();
  }

  bool _isReloading = false;
  bool _hasForcedSync = false;
  Future<void> _loadFromCache({bool force = false}) async {
    if (_isReloading && !force) return;
    if (_isDemoMode) return; 
    _isReloading = true;

    try {
      final uid = _activeStoreId;
      bool isGlobalView = uid == null && (_isDeveloperMode && _activeRole == 'Super Admin');
      if (uid != null || isGlobalView) {
          if (_inventoryProvider != null) {
              await _inventoryProvider!.fetchInventory(uid ?? 'global', refresh: true); 
          } else {
              final sqlItems = await _repository.getInventory(uid);
              final Set<String> originalSqlIds = sqlItems.map((i) => i.id).toSet();
              for (var pinnedItem in _pinnedItems.values) {
                 if (!originalSqlIds.contains(pinnedItem.id)) sqlItems.add(pinnedItem);
              }
              for (var id in originalSqlIds) {
                 if (_pinnedItems.containsKey(id)) _pinnedItems.remove(id);
              }
              _storeInventory = sqlItems;
          }
          if (_customerProvider != null) {
             await _customerProvider!.fetchCustomers(uid, refresh: true);
          } else {
             _customers = await _repository.getCustomers(uid);
          }
          if (_orderProvider != null) {
              await _orderProvider!.fetchOrders(uid, refresh: true);
          } else {
              _orders = await _repository.getPaginatedOrders(uid, limit: _ordersPerPage);
              _hasMoreOrders = _orders.isNotEmpty;
           }
            if (_activeStoreId != null) {
                _subscribeToEmployees(_activeStoreId!);
                _subscribeToSettings(_activeStoreId!);
                _subscribeToCounters(_activeStoreId!);
            }
            await fetchEmployees(refresh: true);
           if (isGlobalView && _storeSettings == null) {
               _activeStoreId = 'global';
               _storeSettings = StoreSettings(id: 'global', storeName: 'Global View', modules: ModuleSettings(), receipt: ReceiptSettings(), payment: PaymentSettings(), dashboard: DashboardSettings(), syncSettings: SyncSettings(), kds: KdsSettings());
              _subscribeToSystemUsers();
           }
      } else {
          _storeInventory = []; _customers = []; _orders = [];
          Future.microtask(() {
            if (_inventoryProvider != null) _inventoryProvider!.clearInventory(); 
            if (_orderProvider != null) _orderProvider!.clearOrders();
            if (_customerProvider != null) _customerProvider!.clearCustomers();
          });
      }
      if (Hive.isBoxOpen('settings')) {
         final settingsBox = Hive.box('settings');
         _autoBackupEnabled = settingsBox.get('autoBackupEnabled', defaultValue: false);
         _backupFrequency = settingsBox.get('backupFrequency', defaultValue: 'Daily');
          final hour = settingsBox.get('backupTimeHour', defaultValue: 2);
          final minute = settingsBox.get('backupTimeMinute', defaultValue: 0);
          _backupTime = TimeOfDay(hour: hour, minute: minute);
       }
      if (_activeStoreId != null && Hive.isBoxOpen('cache_stores')) {
         final storeBox = Hive.box('cache_stores');
         final storeData = storeBox.get(_activeStoreId);
          if (storeData != null) {
             syncService.setActiveStoreId(_activeStoreId!);
          }
      }
      if ((_storeInventory.isEmpty || _orders.isEmpty) && _isOnline && _activeStoreId != null && !_hasForcedSync) {
         _hasForcedSync = true;
         Future.delayed(const Duration(seconds: 2), () => _syncService.forceSyncDown());
      }
     } finally { _isReloading = false; }
  }

  void _checkPrinterSetup() {
    final box = Hive.box('settings');
    final alreadyPrompted = box.get('printer_setup_prompted', defaultValue: false);
    if (alreadyPrompted) return;
    final manager = PrinterManagerService();
    if (manager.assignments.isEmpty) {
      _needsPrinterSetup = true;
      notifyListeners();
    }
  }

  // --- MISSING MEMBERS FROM ORIGINAL FILE (PROXIES & STATE) ---
  UserProfile? _userProfile;
  StoreSettings? _storeSettings;
  String _dashboardBgType = 'video';
  String _dashboardBgSource = 'https://www.shutterstock.com/shutterstock/videos/3789099487/preview/stock-footage-hyperspace-travel-loop-k-vertical.webm';
  String _heroButtonStyle = 'glass';
  Color _heroButtonColor = const Color(0xff00d1b2);
  String? _activeStoreId;
  String _activeRole = 'Unauthorized';
  bool _isDataControlGridView = true;
  List<InventoryItem> _storeInventory = [];
  List<OrderModel> _orders = [];
  List<Customer> _customers = [];
  List<UserProfile> _employees = [];
  List<UserProfile> _superAdmins = [];
  List<SubscriptionHistory> _subscriptionHistory = [];
  List<SubscriptionHistory> get subscriptionHistory => _subscriptionHistory;
  String? _userFetchError;
  String? get userFetchError => _userFetchError;
  bool _isDarkMode = false;
  final bool _isDemoMode = false;
  bool _isDeveloperMode = false;
  AppColorTheme _currentTheme = AppColorTheme.blue;
  UIStyle _uiStyle = UIStyle.standard;
  bool _showClockSeconds = true;
  final int _ordersPerPage = 20;
  DateTime? _lastOrderDate;
  bool _hasMoreOrders = false;
  final Map<String, InventoryItem> _pinnedItems = {};
  List<Store> _stores = [];
  bool _hasCheckedStores = false;
  bool _isLoadingOrders = false;
  final GoogleDriveService _driveService = GoogleDriveService();

  List<OrderModel> get orders => _orders;
  bool get hasCheckedStores => _hasCheckedStores;

  bool get hasAnyStore {
    if (_stores.isNotEmpty) return true;
    if (_userProfile?.storeId != null && _userProfile!.storeId!.isNotEmpty) return true;
    if (_userProfile?.accessibleStoreIds != null && _userProfile!.accessibleStoreIds!.isNotEmpty) return true;
    return isSuperAdmin;
  }

  List<Store> get stores => _stores;

  ThemeNotifier? _themeNotifier;

  void injectThemeNotifier(ThemeNotifier notifier) {
    _themeNotifier = notifier;
    // Synchronize initial state
    _isDarkMode = _themeNotifier!.isDarkMode;
    _currentTheme = _themeNotifier!.currentTheme;
    _uiStyle = _themeNotifier!.uiStyle;
    notifyListeners();
  }

  // Theme & UI Getters
  bool get isDarkMode => _themeNotifier?.isDarkMode ?? _isDarkMode;
  AppColorTheme get currentTheme => _themeNotifier?.currentTheme ?? _currentTheme;
  UIStyle get uiStyle => _themeNotifier?.uiStyle ?? _uiStyle;
  bool get isDeveloperMode => _isDeveloperMode;
  
  Future<Map<String, dynamic>> getPlatformLimits() async => await _syncService.retrievePlatformLimits();
  Map<String, dynamic> get platformLimits => _syncService.platformLimits;
  
  Future<Map<String, dynamic>> retrievePlatformLimits() async => await _syncService.retrievePlatformLimits();
  
  Future<void> updatePlatformLimits(Map<String, dynamic> limits) async {
    await _db.collection('settings').doc('platform_limits').set(limits, SetOptions(merge: true));
    await _syncService.updatePlatformLimitsCache(limits);
    notifyListeners();
  }

  Map<String, dynamic> _adminConfig = {};
  Map<String, dynamic> get adminConfig => _adminConfig;
  
  Future<void> updateAdminConfig(Map<String, dynamic> config, {String? newSecurityPassword}) async {
    _adminConfig.addAll(config);
    if (newSecurityPassword != null) {
      _adminConfig['adminSecurityPassword'] = newSecurityPassword;
    }
    
    // Save to Firestore 'settings/admin_config'
    try {
      await _db.collection('settings').doc('admin_config').set(_adminConfig, SetOptions(merge: true));
    } catch (e) {
      debugPrint("❌ Error updating admin config: $e");
    }
    
    notifyListeners();
  }

  Future<bool> verifyAdminSecurityPassword(String pass) async {
    return pass == "1234"; // Placeholder
  }

  Future<void> toggleGlobalAddon(String key, bool value) async {
    // If value is true, enable it (remove from disabled list)
    // If value is false, disable it (add to disabled list)
    final disabledSet = Set<String>.from(globalDisabledAddons);
    if (value) {
      disabledSet.remove(key);
    } else {
      disabledSet.add(key);
    }
    
    _adminConfig['disabledAddons'] = disabledSet.toList();
    notifyListeners();
    
    // Attempt to save to Firestore if we have the admin config document ID
    // Note: If updateAdminConfig handles this, we can just call it instead.
    await updateAdminConfig({'disabledAddons': disabledSet.toList()});
  }
  
  int getAddonDays(String key) {
    final now = DateTime.now();
    int totalDays = 0;
    for (var sub in _subscriptionHistory) {
      if (sub.selectedAddons.contains(key) && (sub.status == 'ACTIVE' || sub.status == 'QUEUED')) {
        if (sub.endDate.isAfter(now)) {
           final effectiveStart = sub.startDate.isBefore(now) ? now : sub.startDate;
           if (sub.endDate.isAfter(effectiveStart)) {
             totalDays += sub.endDate.difference(effectiveStart).inDays;
           }
        }
      }
    }
    return totalDays;
  }

  void setUIStyle(UIStyle style) {
    if (_themeNotifier != null) {
      _themeNotifier!.setUIStyle(style);
    } else {
      _uiStyle = style;
      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('uiStyle', style.index);
      }
    }
    notifyListeners();
  }

  void setAppTheme(AppColorTheme theme) {
    if (_themeNotifier != null) {
      _themeNotifier!.setAppTheme(theme);
    } else {
      _currentTheme = theme;
    }
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeNotifier != null) {
      _themeNotifier!.toggleTheme();
    } else {
      _isDarkMode = !_isDarkMode;
      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('isDarkMode', _isDarkMode);
      }
    }
    notifyListeners();
  }

  Future<void> _loadDeveloperMode() async {
    try {
      final box = await Hive.openBox('settings');
      _isDeveloperMode = box.get('isDeveloperMode', defaultValue: false);
      debugPrint('🛠️ DashboardProvider: Loaded Developer Mode state: $_isDeveloperMode');
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ DashboardProvider: Error loading developer mode: $e');
    }
  }

  void toggleDeveloperMode() async {
    _isDeveloperMode = !_isDeveloperMode;
    try {
      final box = await Hive.openBox('settings');
      await box.put('isDeveloperMode', _isDeveloperMode);
    } catch (e) {
      debugPrint('⚠️ DashboardProvider: Error saving developer mode: $e');
    }
    notifyListeners();
  }

  // Subscription Management
  List<SubscriptionRequest> _pendingSubscriptions = [];
  List<SubscriptionRequest> get pendingSubscriptions => _pendingSubscriptions;

  Future<void> fetchPendingSubscriptions() async {
    if (!_isOnline) {
      debugPrint('🌐 DashboardProvider: Offline. Skipping fetchPendingSubscriptions.');
      return;
    }
    try {
      Query query = _db.collection('subscription_requests').where('status', isEqualTo: 'PENDING');
      
      // Filter for regular users
      if (_activeRole != 'Super Admin') {
        if (_activeStoreId != null) {
          query = query.where('storeId', isEqualTo: _activeStoreId);
        } else if (_auth?.currentUser != null) {
          query = query.where('userId', isEqualTo: _auth!.currentUser!.uid);
        }
      }

      final snap = await query.get();
      _pendingSubscriptions = snap.docs.map((d) => SubscriptionRequest.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ DashboardProvider: Error fetching pending subscriptions: $e');
    }
  }

  Future<void> approveSubscriptionRequest(SubscriptionRequest request) async {
    final storeId = request.storeId;
    final now = DateTime.now();
    final expiry = now.add(Duration(days: request.durationInDays));
    
    // Find if franchise addon is being approved
    final bool hasFranchiseAddon = request.selectedAddons.contains('franchise_management');
    DocumentReference? userRefToUpdate;

    if (hasFranchiseAddon) {
      if (request.userId != null && request.userId.isNotEmpty) {
        userRefToUpdate = _db.collection('users').doc(request.userId);
      } else {
        try {
          final usersSnap = await _db.collection('users')
              .where('email', isEqualTo: request.ownerEmail)
              .get();
          if (usersSnap.docs.isNotEmpty) {
            userRefToUpdate = usersSnap.docs.first.reference;
          } else {
            // Case-insensitive fallback lookup
            final allUsers = await _db.collection('users').get();
            final matches = allUsers.docs.where((d) => 
              (d.data()['email'] as String?)?.toLowerCase() == request.ownerEmail.toLowerCase()
            ).toList();
            if (matches.isNotEmpty) {
              userRefToUpdate = matches.first.reference;
            }
          }
        } catch (e) {
          debugPrint('⚠️ DashboardProvider: Error finding user by email for role update: $e');
        }
      }
    }

    // Hoist outside transaction so we can use them for local state update after commit
    List<String> finalPurchased = [];
    List<String> finalActive = [];

    await _db.runTransaction((tx) async {
      final storeRef = _db.collection('stores').doc(storeId);
      final storeSnap = await tx.get(storeRef);
      
      final List<String> currentPurchased = List<String>.from(storeSnap.data()?['purchasedAddons'] ?? []);
      final List<String> currentActive = List<String>.from(storeSnap.data()?['addons'] ?? []);
      
      for (var addon in request.selectedAddons) {
        if (!currentPurchased.contains(addon)) currentPurchased.add(addon);
        if (!currentActive.contains(addon)) currentActive.add(addon);
      }

      // Capture for post-transaction local state update
      finalPurchased = currentPurchased;
      finalActive = currentActive;

      // 1. Update Request Status (Move Writes AFTER Reads)
      tx.update(_db.collection('subscription_requests').doc(request.id), {
        'status': 'APPROVED', 
        'approvedAt': FieldValue.serverTimestamp()
      });
      
      // 2. Update Store
      tx.update(storeRef, {
        'subscriptionPlan': request.planType,
        'subscriptionExpiry': Timestamp.fromDate(expiry),
        'lastUpgradeDate': FieldValue.serverTimestamp(),
        'purchasedAddons': currentPurchased,
        'addons': currentActive,
      });

      // 3. Update User Role if franchise addon purchased
      if (userRefToUpdate != null) {
        tx.update(userRefToUpdate, {
          'role': 'Franchise Owner',
        });
      }

      // 4. Add to History
      final historyRef = storeRef.collection('subscription_history').doc();
      tx.set(historyRef, {
        'planName': request.planType,
        'billingCycle': request.billingCycle,
        'durationDays': request.durationInDays,
        'startDate': FieldValue.serverTimestamp(),
        'endDate': Timestamp.fromDate(expiry),
        'price': request.amount,
        'status': 'ACTIVE',
        'storeId': storeId,
        'selectedAddons': request.selectedAddons,
        'isAddonOnly': request.isAddonOnly,
      });
    });

    // Force refresh local store state so sidebar/UI immediately reflects changes
    await _updateLocalStoreState(request.planType, finalActive);
    // Also update purchasedAddons locally
    if (activeStore != null && _storeProvider != null) {
      try {
        final updatedStore = activeStore!.copyWith(purchasedAddons: finalPurchased);
        await _storeProvider!.updateStoreSettings(updatedStore);
      } catch (e) {
        debugPrint('⚠️ DashboardProvider: Error updating purchasedAddons locally: $e');
      }
    }

    // Update local user role state if matching current user
    final matchesUid = request.userId != null && request.userId.isNotEmpty && _userProfile?.uid == request.userId;
    final matchesEmail = request.ownerEmail.isNotEmpty && _userProfile?.email.toLowerCase() == request.ownerEmail.toLowerCase();
    if (hasFranchiseAddon && _userProfile != null && (matchesUid || matchesEmail)) {
      _userProfile = _userProfile!.copyWith(role: 'Franchise Owner');
      _activeRole = 'Franchise Owner';
      notifyListeners();
    }

    await fetchSubscriptionHistory();
    fetchPendingSubscriptions();
    notifyListeners();
  }

  Future<void> rejectSubscriptionRequest(SubscriptionRequest request) async {
    await _db.collection('subscription_requests').doc(request.id).update({'status': 'REJECTED', 'rejectedAt': FieldValue.serverTimestamp()});
    fetchPendingSubscriptions();
  }

  Future<void> fetchEmployees({bool refresh = false}) async {
    if (_activeStoreId == null) return;
    try {
      // Harmonized Fetch: Check root 'users' (for owners/admins) and root 'employees' (for staff)
      // Stop querying nested 'stores/{id}/employees' to align with root-level sync logic
      final rootSnap = await _db.collection('users').where('storeId', isEqualTo: _activeStoreId).get();
      final empSnap = await _db.collection('employees').where('storeId', isEqualTo: _activeStoreId).get();
      
      final rootEmployees = rootSnap.docs.map((d) => UserProfile.fromMap(d.data(), d.id)).toList();
      final staffEmployees = empSnap.docs.map((d) => UserProfile.fromMap(d.data(), d.id)).toList();

      final all = [...rootEmployees, ...staffEmployees];
      final Map<String, UserProfile> unique = {for (var e in all) e.uid: e};
      
      _employees = unique.values.toList();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ DashboardProvider: Error fetching employees: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchEmployeesForStore(String storeId) async {
    if (!_isOnline) {
      debugPrint('🏬 DashboardProvider: Device is offline. Loading cached store employees.');
      final cached = await OfflineService().getCachedStoreEmployees(storeId);
      return cached.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    try {
      // Harmonized Fetch: Check root 'users' (for owners/admins) and root 'employees' (for staff)
      // Stop querying nested 'stores/{id}/employees'
      final rootSnap = await _db.collection('users').where('storeId', isEqualTo: storeId).get();
      final empSnap = await _db.collection('employees').where('storeId', isEqualTo: storeId).get();

      final List<Map<String, dynamic>> allData = [];
      
      allData.addAll(rootSnap.docs.map((doc) => {...doc.data(), 'uid': doc.id}));
      allData.addAll(empSnap.docs.map((doc) => {...doc.data(), 'uid': doc.id}));

      final Map<String, Map<String, dynamic>> unique = {for (var e in allData) e['uid'] as String: e};
      
      return unique.values
             .where((data) => data['role'] != 'Super Admin')
             .toList();
    } catch (e) {
      debugPrint('❌ DashboardProvider: Error fetching employees for store $storeId: $e');
      return [];
    }
  }



  Future<void> createSubscriptionRequest({
    required String planType, 
    int durationInDays = 30, 
    required double amount,
    String? billingCycle,
    List<String>? selectedAddons,
    bool isAddonOnly = false,
  }) async {
    final int finalDuration = billingCycle == 'Yearly' ? 365 : 30;
    if (_activeStoreId == null) return;
    
    // BACKEND-LEVEL LOCK: Prevent duplicate pending requests for the same store
    if (_pendingSubscriptions.any((req) => req.storeId == _activeStoreId && req.status == 'PENDING')) {
      throw Exception("A pending subscription request already exists for this store.");
    }

    String sName = 'Unknown Store';
    if (_storeProvider != null) {
      try {
        final currentStore = _storeProvider!.stores.firstWhere((s) => s.id == _activeStoreId);
        sName = currentStore.name;
      } catch (e) {
        debugPrint('⚠️ DashboardProvider: Could not find store name for $_activeStoreId');
      }
    }

    await _db.collection('subscription_requests').add({
      'storeId': _activeStoreId,
      'storeName': sName,
      'ownerEmail': activeStore?.ownerEmail ?? _auth?.currentUser?.email ?? '',
      'planType': planType,
      'durationInDays': finalDuration,
      'amount': amount,
      'billingCycle': billingCycle ?? 'Monthly',
      'selectedAddons': selectedAddons ?? [],
      'status': 'PENDING',
      'createdAt': FieldValue.serverTimestamp(),
      'userId': _auth?.currentUser?.uid,
      'isAddonOnly': isAddonOnly,
    });
    // Refresh pending list so UI shows the new pending request immediately
    await fetchPendingSubscriptions();
  }


  // Admin & Store Config
  Future<Map<String, dynamic>> fetchAdminConfig() async {
    try {
      final doc = await _db.collection('settings').doc('admin_config').get();
      if (doc.exists) {
        _adminConfig = doc.data()!;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ DashboardProvider: Failed to fetch admin config (likely Firebase uninitialized): $e');
    }
    return _adminConfig;
  }

  Future<void> updateStoreSettings(Store updatedStore) async {
    if (_storeProvider != null) {
      await _storeProvider!.updateStoreSettings(updatedStore);
    } else {
      await _db.collection('stores').doc(updatedStore.id).update(updatedStore.toMap());
    }
    notifyListeners();
  }

  // Metadata Management
  Future<List<String>> fetchMetadata(String key) async {
    final doc = await _db.collection('settings').doc('metadata').get();
    if (doc.exists && doc.data() != null && doc.data()![key] != null) {
      return List<String>.from(doc.data()![key]);
    }
    return [];
  }

  Future<void> addMetadata(String key, String value) async {
    await _db.collection('settings').doc('metadata').set({
      key: FieldValue.arrayUnion([value])
    }, SetOptions(merge: true));
  }

  Future<void> deleteMetadata(String key, String value) async {
    await _db.collection('settings').doc('metadata').set({
      key: FieldValue.arrayRemove([value])
    }, SetOptions(merge: true));
  }

  // --- ADDITIONAL MODULES (INVENTORY, CUSTOMERS, ETC) ---

  List<InventoryItem> get storeInventory => _inventoryProvider?.storeInventory ?? [];
  int getItemStock(String itemId) => _inventoryProvider?.getItemStock(itemId) ?? 0;
  double getItemCost(String itemId) => _inventoryProvider?.getItemCost(itemId) ?? 0.0;
  List<Customer> get customers => _customerProvider?.customers ?? [];
  List<UserProfile> get superAdmins => _superAdmins;
  
  List<CounterModel> get counters => [
    CounterModel(id: 'orders', name: 'Orders'),
    CounterModel(id: 'inventory', name: 'Inventory'),
  ];

  Future<void> addInventoryItem(InventoryItem item, {File? imageFile}) async {
    if (_activeStoreId == null) return;
    await _inventoryProvider?.addInventoryItem(item, _activeStoreId!, imageFile: imageFile);
    notifyListeners();
  }

  Future<void> updateInventoryItem(InventoryItem item, {File? imageFile}) async {
    await _inventoryProvider?.updateInventoryItem(item, imageFile: imageFile);
    notifyListeners();
  }

  Future<void> deleteInventoryItem(String id) async {
    await _inventoryProvider?.deleteInventoryItem(id);
    notifyListeners();
  }

  Future<void> addCustomer(Customer customer) async {
    await _customerProvider?.addCustomer(customer);
  }

  Future<void> addCustomers(List<Customer> customers) async {
    await _customerProvider?.addCustomers(customers);
  }

  Future<void> updateCustomer(Customer customer) async {
    await _customerProvider?.updateCustomer(customer);
  }

  Future<void> updateCustomerLoyalty(String id, num points) async {
    await _db.collection('customers').doc(id).update({'loyaltyPoints': FieldValue.increment(points)});
    notifyListeners();
  }

  Timer? _backupTimer;
  DateTime? _lastAutoBackup;

  void _startAutoBackupTimer() {
    _backupTimer?.cancel();
    if (!isTesting) {
      _backupTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
         _checkAndRunAutoBackup();
      });
    }
  }

  Future<void> _checkAndRunAutoBackup() async {
    if (_storeProvider == null || !_storeProvider!.autoBackupEnabled) return;
    
    final now = DateTime.now();
    final backupTime = _storeProvider!.backupTime;
    
    if (now.hour == backupTime.hour && now.minute == backupTime.minute) {
       // Avoid multiple backups in the same minute
       if (_lastAutoBackup != null && 
           _lastAutoBackup!.year == now.year && 
           _lastAutoBackup!.month == now.month && 
           _lastAutoBackup!.day == now.day &&
           _lastAutoBackup!.hour == now.hour &&
           _lastAutoBackup!.minute == now.minute) {
         return;
       }

       bool shouldBackup = false;
       if (_lastAutoBackup == null) {
          shouldBackup = true;
       } else {
          final diff = now.difference(_lastAutoBackup!);
          final freq = _storeProvider!.backupFrequency;
           if (freq == 'Daily' && diff.inDays >= 1) shouldBackup = true;
           else if (freq == 'Weekly' && diff.inDays >= 7) shouldBackup = true;
           else if (freq == 'Monthly' && diff.inDays >= 30) shouldBackup = true;
        }

        if (shouldBackup) {
           _lastAutoBackup = now;
           // Persist last backup time
           if (Hive.isBoxOpen('settings')) {
              Hive.box('settings').put('lastAutoBackup', now.toIso8601String());
           }
           debugPrint("⏰ Auto Backup Triggered...");
           await exportLocalBackup();
        }
    }
  }

  void setBackupTime(TimeOfDay time) {
    _storeProvider?.setBackupTime(time);
    notifyListeners();
  }

  Future<void> exportLocalBackup() async {
    await _storeProvider?.exportLocalBackup();
  }

  Future<void> restoreLocalBackup({dynamic file, String? webKey}) async {
    await _storeProvider?.restoreLocalBackup(file: file, webKey: webKey);
    // After restore, we should re-initialize everything
    _isInitialized = false; // Reset to allow init() to run
    init(); 
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getAvailableBackups() async {
    if (_availableBackups.isEmpty) {
      await refreshAvailableBackups();
    }
    return _availableBackups;
  }

  Future<void> refreshAvailableBackups() async {
    if (_storeProvider == null) return;
    _isFetchingBackups = true;
    notifyListeners();
    try {
      _availableBackups = await _storeProvider!.getAvailableBackups();
    } catch (e) {
      debugPrint('❌ DashboardProvider: Error fetching backups: $e');
    } finally {
      _isFetchingBackups = false;
      notifyListeners();
    }
  }

  String get debugCollectionFound => "None";
  bool get autoBackupEnabled => _storeProvider?.autoBackupEnabled ?? false;

  void toggleAutoBackup(bool val) {
    _storeProvider?.toggleAutoBackup(val);
    if (val) _startAutoBackupTimer();
    else _backupTimer?.cancel();
    notifyListeners();
  }

  void setBackupFrequency(String freq) {
    _storeProvider?.setBackupFrequency(freq);
    notifyListeners();
  }


  Future<void> batchUpdateStock(dynamic changes) async {
    if (changes is Map<String, int>) {
      final useCase = AdjustStockUseCase(InventoryMovementRepository());
      
      for (var entry in changes.entries) {
        final itemId = entry.key;
        final newQty = entry.value;
        final currentQty = getItemStock(itemId);
        final delta = newQty - currentQty;
        
        if (delta != 0) {
          final item = _storeInventory.firstWhere((i) => i.id == itemId, orElse: () => InventoryItem(id: '', name: '', price: 0, quantity: 0, status: '', category: '', trackStock: false));
          if (item.id.isNotEmpty) {
             await useCase.execute(AdjustStockParams(
               movement: InventoryMovement(
                 id: const Uuid().v4(),
                 itemId: itemId,
                 storeId: _activeStoreId ?? '',
                 type: 'ADJUSTMENT',
                 delta: delta,
                 deviceId: 'system',
                 createdAt: DateTime.now(),
                 cost: item.cost ?? 0.0,
                 syncStatus: 'PENDING',
               )
             ));
             
             // Update the item's quantity locally so the UI reflects the change
             final updatedItem = item.copyWith(quantity: newQty);
             await updateInventoryItem(updatedItem);
          }
        }
      }
    }
    notifyListeners();
  }

  Future<void> checkSubscriptionLimits() async {
    // Logic to check usage against platform limits
  }

  Future<void> refundOrder(String orderId) async {
    if (_orderProvider == null) return;
    await _orderProvider!.refundOrder(orderId);
    notifyListeners();
  }

  Future<void> createEmployeeWithPin(String name, String role, String pin) async {
    if (_activeStoreId == null) return;
    
    final String uid = const Uuid().v4();
    // Generate a 4-digit numeric employee ID for PIN-based login
    final String employeeId = (Random().nextInt(9000) + 1000).toString(); 
    final String pinHash = PinUtils.hashPin(pin, uid);
    
    final newUser = UserProfile(
      uid: uid,
      email: '$employeeId@bizpos.com', // Unique dummy email
      name: name,
      role: role,
      storeId: _activeStoreId,
      employeeId: employeeId,
      pinHash: pinHash,
      createdAt: DateTime.now(),
      accessibleStoreIds: [_activeStoreId!],
      permissions: {},
    );

    // Persist via SyncService (Routes to stores/{id}/employees in Firestore)
    await _syncService.performLocalWrite(
      collection: 'employees',
      docId: uid,
      data: newUser.toMap(),
      action: 'create',
      localCacheBox: 'cache_employees'
    );

    _employees.add(newUser);
    notifyListeners();
  }

  Future<void> updateEmployeeRole(String uid, String role) async {
    await _syncService.performLocalWrite(
      collection: 'employees',
      docId: uid,
      data: {'role': role},
      action: 'update',
      localCacheBox: 'cache_employees'
    );
    
    final index = _employees.indexWhere((e) => e.uid == uid);
    if (index != -1) {
      _employees[index] = _employees[index].copyWith(role: role);
    }
    notifyListeners();
  }

  List<UserProfile> get employees => _employees;

  List<RoleModel> get roles => _storeProvider != null ? _storeProvider!.roles : _roles;
  List<RoleModel> _roles = [
    RoleModel(id: 'admin', name: 'Admin', permissions: {}, isSystem: true),
    RoleModel(id: 'manager', name: 'Manager', permissions: {}, isSystem: true),
    RoleModel(id: 'cashier', name: 'Cashier', permissions: {}, isSystem: true),
    RoleModel(id: 'waiter', name: 'Waiter', permissions: {}, isSystem: true),
  ];

  final List<Franchise> _franchises = [];
  List<Franchise> get franchises => _franchises;

  Future<void> removeEmployee(String uid) async {
    await _syncService.performLocalWrite(
      collection: 'employees',
      docId: uid,
      data: {},
      action: 'delete',
      localCacheBox: 'cache_employees'
    );
    
    _employees.removeWhere((e) => e.uid == uid);
    notifyListeners();
  }

  Future<Map<String, dynamic>> fetchPaginatedUsers({int limit = 20, dynamic startAfter, String? filterRole}) async {
    try {
      _userFetchError = null;
      Query query = _db.collection('users');

      if (filterRole != null && filterRole != 'All') {
        if (filterRole == 'Unauthorized') {
          query = query.where('role', isEqualTo: 'Unauthorized');
        } else {
          query = query.where('role', isEqualTo: filterRole);
        }
      }

      query = query.limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter as DocumentSnapshot);
      }

      final snap = await query.get();
      final users = snap.docs.map((d) => UserProfile.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();

      // Gather store plans for these users to populate `storePlans`
      final Map<String, String> storePlans = {};
      final uniqueStoreIds = users.map((u) => u.storeId).where((id) => id != null && id.isNotEmpty).cast<String>().toSet();

      if (uniqueStoreIds.isNotEmpty) {
        final List<String> storeIdsList = uniqueStoreIds.toList();
        for (var i = 0; i < storeIdsList.length; i += 10) {
          final chunk = storeIdsList.sublist(i, i + 10 > storeIdsList.length ? storeIdsList.length : i + 10);
          final storesSnap = await _db.collection('stores')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (var doc in storesSnap.docs) {
            final plan = doc.data()['subscriptionPlan']?.toString() ?? 'Basic';
            storePlans[doc.id] = plan;
          }
        }
      }

      return {
        'users': users,
        'storePlans': storePlans,
        'lastDoc': snap.docs.isNotEmpty ? snap.docs.last : null,
      };
    } catch (e) {
      _userFetchError = e.toString();
      debugPrint('❌ DashboardProvider: Error fetching paginated users: $e');
      notifyListeners();
      return {
        'users': <UserProfile>[],
        'storePlans': <String, String>{},
        'lastDoc': null,
      };
    }
  }

  Future<void> approveDemoRequest(String uid) async {
    await _db.collection('users').doc(uid).update({'demoStatus': 'approved'});
    notifyListeners();
  }

  final List<Map<String, dynamic>> _auditLogData = [];
  List<Map<String, dynamic>> get auditLogs => _auditLogData;

  Future<void> fetchAuditLogs() async {
     // Placeholder for actual fetch logic
  }

  Rect? get activeTargetRect => null;
  String? get activeTargetInstruction => null;
  void exitDemoMode() {}

  Future<void> placeOrder(OrderModel order) async {
    await _orderProvider?.placeOrder(order, activeStore);
  }

  Future<void> updateOrder(OrderModel order) async {
    await _orderProvider?.updateOrder(order);
  }

   Future<void> addOrder(OrderModel order) async {
     await _orderProvider?.placeOrder(order, activeStore);
     notifyListeners();
   }

   Future<OrderModel?> getOrder(String id) async {
     return await _orderProvider?.getOrder(id);
   }

   // --- AUTH & USER LINKING ---
  Future<void> linkUserToStore(String uid, String storeId) async {
    await _db.collection('users').doc(uid).update({
      'storeId': storeId,
      'storeIds': FieldValue.arrayUnion([storeId])
    });
  }

  // --- DEMO / TRAINING MODE ---
  bool get isDemoMode => _isDemoMode;
  final String _demoStep = 'none';
  String get demoStep => _demoStep;

  void nextDemoStep() {
    notifyListeners();
  }

  void reportDemoTarget(String step, Rect rect, String instruction) {}

  // --- STORE TYPE CONFIGS ---
  Map<String, dynamic> _storeTypeConfigs = {};
  Map<String, dynamic> get storeTypeConfigs => _storeTypeConfigs;

  void _listenToGlobalSettings() {
    try {
      // Optimistically load from local cache first
      if (Hive.isBoxOpen('store_type_configs')) {
        final box = Hive.box('store_type_configs');
        _storeTypeConfigs = Map<String, dynamic>.from(box.get('configs', defaultValue: {}));
      }

      _db.collection('settings').doc('global').snapshots().listen((snap) {
         if (snap.exists) {
           final data = snap.data();
           if (data != null && data['store_type_configs'] != null) {
             final configs = Map<String, dynamic>.from(data['store_type_configs']);
             _storeTypeConfigs = configs;
             if (Hive.isBoxOpen('store_type_configs')) {
               Hive.box('store_type_configs').put('configs', configs);
             }
             notifyListeners();
           }
         }
      }, onError: (e) {
        debugPrint('⚠️ DashboardProvider: Error in global settings stream: $e');
      });
    } catch (e) {
      debugPrint('⚠️ DashboardProvider: Failed to listen to global settings: $e');
    }
  }

  Future<void> saveStoreTypeConfig(String type, Map<String, dynamic> config) async {
    try {
      _storeTypeConfigs[type] = config;
      if (Hive.isBoxOpen('store_type_configs')) {
        await Hive.box('store_type_configs').put('configs', _storeTypeConfigs);
      }
      
      await _db.collection('settings').doc('global').set({
        'store_types': FieldValue.arrayUnion([type]),
        'store_type_configs': {
          type: config
        }
      }, SetOptions(merge: true));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> deleteStoreTypeConfig(String type) async {
    try {
      _storeTypeConfigs.remove(type);
      if (Hive.isBoxOpen('store_type_configs')) {
        await Hive.box('store_type_configs').put('configs', _storeTypeConfigs);
      }
      
      await _db.collection('settings').doc('global').update({
        'store_types': FieldValue.arrayRemove([type]),
        'store_type_configs.$type': FieldValue.delete()
      });
      notifyListeners();
    } catch (_) {}
  }
  void _listenToPlatformLimits() {}
  void _listenToSyncStatus() {
    _syncService.syncStatusStream.listen((status) {
       // Update local sync status state if needed
       notifyListeners();
    });
  }
  void _listenToCentralCatalog() {}
  void _listenToCounters() {}
  void _listenToAuthChanges() {}
  void _loadGlobalSettingsFromCache() {}
  void _loadConsumableDurationFromCache() {}
  void loadLayout() {}
  void _loadAdminConfig() {
    fetchAdminConfig();
  }

  void _loadPlatformLimits() {
    _syncService.retrievePlatformLimits().then((_) {
       notifyListeners();
    });
  }

  Future<void> _fetchUserData(String uid) async {
    if (_isFetchingUserData) {
      debugPrint('👤 DashboardProvider: _fetchUserData already in progress for $uid. Skipping redundant call.');
      return;
    }
    _isFetchingUserData = true;
    _fetchGeneration++;
    final int thisGeneration = _fetchGeneration;
    debugPrint('👤 DashboardProvider: _fetchUserData starting (generation: $thisGeneration)');
    
    try {
      // 1. OPTIMISTIC LOAD: Check Cache First for immediate UI responsiveness
      final cachedProfile = await OfflineService().getCachedUserProfile(uid: uid);
      if (cachedProfile != null) {
         final data = Map<String, dynamic>.from(cachedProfile);
         _userProfile = UserProfile.fromMap(data, uid);
         _activeRole = _userProfile?.role ?? 'Unauthorized';
         debugPrint('📦 DashboardProvider: Loaded role from cache: $_activeRole');
         
         // If we have a role, we can allow the UI to start rendering earlier
         if (!_isInitialized && _activeRole != 'Unauthorized') {
            _isInitialized = true;
            _routerNotifier?.notify();
            notifyListeners();
         }
      }

      if (!_isOnline) {
        debugPrint('🌐 DashboardProvider: Offline Mode. Finalizing offline user session.');
        _loadAdminConfig();
        _loadPlatformLimits();
        if (_storeProvider != null) {
          debugPrint('🏬 DashboardProvider: Loading user stores from local cache...');
          await _storeProvider!.fetchStores(isSuperAdmin: isSuperAdmin);
          _stores = _storeProvider!.stores;
          if (_activeStoreId == null) {
             await _restorePinnedStore(uid: uid);
          }
          if (_activeStoreId == null && _stores.length == 1) {
            final soloStoreId = _stores.first.id;
            _activeStoreId = soloStoreId;
            await _storeProvider!.setActiveStoreId(soloStoreId);
          } else if (_activeStoreId != null) {
             _loadFromCache();
             // ignore: unawaited_futures
             fetchPendingSubscriptions();
             // ignore: unawaited_futures
             fetchSubscriptionHistory();
          }
        }
        _isInitialized = true;
        _routerNotifier?.notify();
        notifyListeners();
        return;
      }

      debugPrint('👤 DashboardProvider: Fetching user data for $uid');
      Map<String, dynamic>? userData;
      try {
        final doc = await _db.collection('users').doc(uid).get();
        if (doc.exists && doc.data() != null) {
          userData = doc.data()!;
          _userProfile = UserProfile.fromMap(userData, uid);
          _activeRole = _userProfile!.role;
          debugPrint('👤 DashboardProvider: User Role identified as: $_activeRole');

          // Generate franchise code if missing for Franchise Owner
          if (_activeRole == 'Franchise Owner' && (userData['franchiseCode'] == null || userData['franchiseCode'].toString().isEmpty)) {
            final String generatedCode = (Random().nextInt(900000) + 100000).toString();
            userData['franchiseCode'] = generatedCode;
            userData['franchiseId'] = uid;
            
            await _db.collection('users').doc(uid).update({
              'franchiseCode': generatedCode,
              'franchiseId': uid,
            });
            
            await _db.collection('franchises').doc(uid).set({
              'id': uid,
              'name': _userProfile!.name.isNotEmpty ? "${_userProfile!.name} Franchise" : "Franchise",
              'ownerEmail': _userProfile!.email,
              'code': generatedCode,
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            _userProfile = UserProfile.fromMap(userData, uid);
            debugPrint('🔑 Generated franchise code for owner: $generatedCode');
          }

          // Persist to Cache for next launch
          await OfflineService().cacheUserProfile(userData, uid: uid);
        } else {
          debugPrint('⚠️ DashboardProvider: User document NOT FOUND in Firestore for $uid.');
        }
      } catch (e) {
        debugPrint('❌ DashboardProvider: GET USER DOC FAILED for $uid: $e');
        if (e.toString().contains('permission-denied')) {
           debugPrint('⛔ DashboardProvider: FIRESTORE PERMISSION DENIED for users/$uid. Check Security Rules.');
        }
        
        if (_userProfile == null) {
          _activeStoreId = null;
          _isInitialized = true;
          _hasCheckedStores = true;
          _routerNotifier?.notify();
          notifyListeners();
          return;
        }
        debugPrint('⚠️ DashboardProvider: Proceeding with cached profile: ${_userProfile?.role}');
      }

      if (_userProfile != null) {
         // Load additional configs once user is identified
         _loadAdminConfig();
         _loadPlatformLimits();
         
         // Trigger Store Fetch
         if (_storeProvider != null) {
           debugPrint('🏬 DashboardProvider: Triggering store fetch via StoreProvider');
           try {
              await _storeProvider!.fetchStores(isSuperAdmin: isSuperAdmin);
              _stores = _storeProvider!.stores;
              
              // --- RETRY LOGIC FOR EXISTING OWNERS/ADMINS ---
              // If we expect stores (Owner/Admin) but got 0, wait a moment and try one more time.
              // This solves the "Existing user sees No Stores found" issue on slow connections.
              if (_stores.isEmpty && (_activeRole == 'Store Owner' || _activeRole == 'Admin')) {
                 debugPrint('⏳ DashboardProvider: Owner has 0 stores. Retrying sync in 2s...');
                 await Future.delayed(const Duration(seconds: 2));
                 await _storeProvider!.fetchStores(isSuperAdmin: isSuperAdmin);
                 _stores = _storeProvider!.stores;
                 debugPrint('✅ DashboardProvider: Retry fetch result: ${_stores.length} stores');
              }
              
              debugPrint('✅ DashboardProvider: Stores populated: ${_stores.length}');
           } catch (e) {
              debugPrint('❌ DashboardProvider: FETCH STORES FAILED: $e');
           }
           _hasCheckedStores = true;
           
           // --- DASHBOARD RESTORATION LOGIC ---
           // Try to restore last active store if none is currently selected (e.g. fresh launch)
           if (_activeStoreId == null) {
              await _restorePinnedStore(uid: uid);
           }

           // Fallback to User Profile storeId if restoration didn't yield an active store
           if (_activeStoreId == null) {
               if (_userProfile?.storeId != null && _userProfile!.storeId!.isNotEmpty) {
                  _activeStoreId = _userProfile!.storeId;
                  debugPrint('🎯 DashboardProvider: Auto-selecting store from User Profile: $_activeStoreId');
               } else if (_userProfile?.accessibleStoreIds != null && _userProfile!.accessibleStoreIds!.isNotEmpty) {
                  _activeStoreId = _userProfile!.accessibleStoreIds!.first;
                  debugPrint('🎯 DashboardProvider: Auto-selecting store from accessibleStoreIds: $_activeStoreId');
               }
               
               if (_activeStoreId != null && _storeProvider != null) {
                  // ignore: unawaited_futures
                  _storeProvider!.setActiveStoreId(_activeStoreId);
               }
           }

           // Validate Restored ID: If restored ID is NOT in the user's list of stores, clear it
           if (_activeStoreId != null && _stores.isNotEmpty) {
              bool hasAccess = _stores.any((s) => s.id == _activeStoreId);
              if (!hasAccess && !isSuperAdmin) {
                  debugPrint('⚠️ DashboardProvider: Restored Store ID $_activeStoreId is INVALID for this user. Clearing.');
                  _activeStoreId = null;
                  await OfflineService().unpinStore(uid: uid);
              }
           }

           // --- AUTO-SELECT LOGIC ---
           if (_activeStoreId == null && _stores.length == 1) {
             final soloStoreId = _stores.first.id;
             debugPrint('🎯 DashboardProvider: Auto-selecting single available store: $soloStoreId');
             _activeStoreId = soloStoreId;
             await _storeProvider!.setActiveStoreId(soloStoreId);
           } else if (_activeStoreId != null) {
               // Re-trigger cache load for the current active store
               _loadFromCache(); 
               fetchPendingSubscriptions();
               // Load subscription history and auto-activate if needed
               fetchSubscriptionHistory().then((_) {
                 _checkAndAutoActivateReadySubs();
               });
            }
         } else {
            // FIX: _storeProvider is NULL (Android race condition - auth fired before injection)
            // Don't mark as fully initialized yet — injectStoreProvider will retry _fetchUserData
            debugPrint('⚠️ DashboardProvider: _storeProvider is NULL during _fetchUserData. Deferring store load...');
            
            // Still try to restore pinned store from cache as a stopgap
            if (_activeStoreId == null) {
               await _restorePinnedStore(uid: uid);
            }

            // Fallback to User Profile storeId if restoration didn't yield an active store
            if (_activeStoreId == null) {
                if (_userProfile?.storeId != null && _userProfile!.storeId!.isNotEmpty) {
                   _activeStoreId = _userProfile!.storeId;
                   debugPrint('🎯 DashboardProvider: Auto-selecting store from User Profile (Deferred): $_activeStoreId');
                } else if (_userProfile?.accessibleStoreIds != null && _userProfile!.accessibleStoreIds!.isNotEmpty) {
                   _activeStoreId = _userProfile!.accessibleStoreIds!.first;
                   debugPrint('🎯 DashboardProvider: Auto-selecting store from accessibleStoreIds (Deferred): $_activeStoreId');
                }
            }
            
            // Load cached stores list so hasAnyStore returns true (prevents /create-store redirect)
            final cachedStores = await OfflineService().getCachedUserStores(uid: uid);
            if (cachedStores.isNotEmpty) {
               _stores = cachedStores.map((m) => Store.fromMap(Map<String, dynamic>.from(m), m['id']?.toString() ?? '')).toList();
               debugPrint('📦 DashboardProvider: Loaded ${_stores.length} stores from cache (storeProvider pending)');
               _hasCheckedStores = true;
               
               // Auto-select single store even without provider
               if (_activeStoreId == null && _stores.length == 1) {
                 _activeStoreId = _stores.first.id;
                 debugPrint('🎯 DashboardProvider: Auto-selecting cached store: $_activeStoreId');
               }
            }
             // DON'T set _isInitialized = true yet — let injectStoreProvider handle the full init
             debugPrint('🏁 DashboardProvider: Deferring initialization until StoreProvider is injected.');
             return; 
          }
          
          _isInitialized = true;
          debugPrint('🏁 DashboardProvider: Initialized with ${_stores.length} stores. Signaling router...');
          _routerNotifier?.notify(); // EXPLICIT SIGNAL TO GO_ROUTER
          notifyListeners();
      } else {
        _activeStoreId = null; // Ensure fresh state for new user
        _isInitialized = true;
        _hasCheckedStores = true; 
        debugPrint('⚠️ DashboardProvider: User document NOT FOUND or cached profile missing for $uid. Signaling router...');
        _routerNotifier?.notify(); 
        notifyListeners();
      }
    } catch (e) {
      debugPrint("❌ DashboardProvider: Critical error in _fetchUserData: $e");
      _isInitialized = true;
      _hasCheckedStores = true;
      _routerNotifier?.notify();
      notifyListeners();
    } finally {
      _isFetchingUserData = false;
    }
  }
  Future<void> _restorePinnedStore({String? uid}) async {
    final pinnedStore = await OfflineService().getPinnedStore(uid: uid);
    if (pinnedStore != null && _activeStoreId == null) {
       _activeStoreId = pinnedStore['id'];
       debugPrint('🏬 DashboardProvider: Last Active Store Restored: $_activeStoreId');
       if (_storeProvider != null) {
          // Rehydrate StoreProvider so activeStore is not null immediately
          // ignore: unawaited_futures
          _storeProvider!.setActiveStoreId(_activeStoreId);
       }
    }
  }

  Future<void> _checkOfflineSession() async {
    // Note: This check relies on _isOfflineLoggedIn which is injected from AuthProvider
    if (!_isOfflineLoggedIn) {
       debugPrint('ℹ️ DashboardProvider: Skipping _checkOfflineSession (No Offline Login State)');
       return;
    }
    
    debugPrint('🌐 DashboardProvider: Checking Offline Session...');
    final offlineEmail = OfflineService().getOfflineLoginEmail();
    final cachedUid = OfflineService().getCachedUserId(email: offlineEmail);
    
    if (cachedUid == null) {
       debugPrint('❌ DashboardProvider: No cached UID found for offline email: $offlineEmail');
       _isInitialized = true;
       _routerNotifier?.notify();
       notifyListeners();
       return;
    }
    
    await DatabaseHelper.switchUser(cachedUid);
    
    final profile = await OfflineService().getCachedUserProfile(uid: cachedUid);
    if (profile != null) {
      _userProfile = UserProfile.fromMap(profile, profile['uid'] ?? cachedUid);
      _activeRole = _userProfile!.role;
      debugPrint('👤 DashboardProvider: Offline User Profile Rehydrated (Role: $_activeRole)');
      
      // Try to restore last active store if available
      await _restorePinnedStore(uid: cachedUid);
      
      // Fetch user data & stores list for offline user
      await _fetchUserData(cachedUid);
    } else {
      debugPrint('❌ DashboardProvider: Cached user profile not found for UID: $cachedUid');
      _isInitialized = true;
      _routerNotifier?.notify();
      notifyListeners();
    }
  }

  Future<void> rehydrateOfflineUser() async {
     await _checkOfflineSession();
  }

  void _initPermissions() {
    // Placeholder for new _initPermissions method
    debugPrint('Initializing permissions...');
  }

  void _onStoreChange() {
    if (_storeProvider != null) {
      final oldStores = _stores;
      _stores = _storeProvider!.stores; 
      final newId = _storeProvider!.activeStoreId;
      
      // AUTO-SELECT SINGLE STORE: If no active store is set but we now have exactly one, auto-select it.
      if (newId == null && _stores.length == 1 && !isSuperAdmin) {
          final soloId = _stores.first.id;
          if (soloId.isNotEmpty) {
             debugPrint('🎯 DashboardProvider: Single store detected via StoreProvider, auto-selecting: $soloId');
             _storeProvider!.setActiveStoreId(soloId);
             return; // The next call to _onStoreChange (after setActiveStoreId) will handle the state update
          }
      }

      if (_activeStoreId != newId) {
        debugPrint('🔄 DashboardProvider: Active store changed to $newId');
        _activeStoreId = newId;
        if (newId != null && newId.isNotEmpty) {
          _initSync(); 
          _initPermissions();
          _initBackupService();

          // Load subscription state for the new store
          fetchSubscriptionHistory().then((_) {
            _checkAndAutoActivateReadySubs();
          });
          fetchPendingSubscriptions();

          // Pin store and cache employees for offline employee login
          try {
            final store = _stores.firstWhere((s) => s.id == newId, orElse: () => _storeProvider!.stores.firstWhere((s) => s.id == newId));
            final storeMap = store.toMap();
            storeMap['id'] = store.id; // Ensure ID is included for offline persistence
            OfflineService().pinStore(storeMap, uid: _auth?.currentUser?.uid).then((_) {
               fetchEmployeesForStore(newId).then((employees) {
                  OfflineService().cacheStoreEmployees(newId, employees);
                  debugPrint('📌 DashboardProvider: Store pinned and ${employees.length} employees cached for offline login');
               });
            });
          } catch (e) {
            debugPrint("⚠️ DashboardProvider: Failed to pin store or cache employees: $e");
          }
        }
        notifyListeners();
      } else {
        // Store ID is the same — but store DATA may have changed (addons, plan, etc.)
        // Always propagate StoreProvider changes so sidebar/UI reacts to addon/plan updates
        notifyListeners();
      }
    }
  }
  Future<void> fetchSubscriptionHistory() async {
    if (_activeStoreId == null) return;
    if (!_isOnline) {
      debugPrint('🌐 DashboardProvider: Offline. Skipping fetchSubscriptionHistory.');
      return;
    }
    try {
       final snap = await _db.collection('stores').doc(_activeStoreId).collection('subscription_history').orderBy('startDate', descending: true).get();
       _subscriptionHistory = snap.docs.map((d) => SubscriptionHistory.fromMap(d.data(), d.id)).toList();
       _subscriptionHistoryLoaded = true;
       notifyListeners();
    } catch (e) {
       debugPrint('❌ DashboardProvider: Error fetching subscription history: $e');
    }
  }

  Future<Map<String, dynamic>> fetchGlobalSubscriptionStats() async {
    try {
      debugPrint('📊 DashboardProvider: Fetching Global Subscription Stats...');
      
      // 1. Fetch all stores for plan distribution and store counts
      final storeSnap = await _db.collection('stores').get();
      
      int totalStores = storeSnap.docs.length;
      int activeSubs = 0;
      Map<String, int> planDistribution = {};
      Map<String, double> storeRevenue = {};
      Map<String, int> activeAddons = {};

      for (var d in storeSnap.docs) {
        final data = d.data();
        final plan = data['subscriptionPlan'] ?? 'Free';
        planDistribution[plan] = (planDistribution[plan] ?? 0) + 1;
        if (plan != 'Free' && plan != 'Basic') {
          activeSubs++;
        }
        
        final addonsData = data['addons'];
        if (addonsData is List) {
           for (var addon in addonsData) {
              final aStr = addon.toString();
              activeAddons[aStr] = (activeAddons[aStr] ?? 0) + 1;
           }
        }
      }

      // 2. Fetch subscription requests for revenue and history
      final requestSnap = await _db.collection('subscription_requests').get();
          
      double totalValue = 0;
      List<Map<String, dynamic>> recentHistory = [];

      for (var d in requestSnap.docs) {
        final data = d.data();
        final status = data['status'] ?? 'PENDING';
        final amount = (data['amount'] ?? 0.0).toDouble();
        
        if (status == 'APPROVED' || status == 'COMPLETED') {
           totalValue += amount;
           final sName = data['storeName'] ?? 'Unknown Store';
           storeRevenue[sName] = (storeRevenue[sName] ?? 0.0) + amount;
        }
        
        recentHistory.add({
          ...data,
          'id': d.id,
          'createdAt': data['createdAt'],
        });
      }

      // Sort history and revenue
      // Sort history (defensive)
      recentHistory.sort((a, b) {
        final tA = a['createdAt'];
        final tB = b['createdAt'];
        if (tA == null && tB == null) return 0;
        if (tA == null) return 1;
        if (tB == null) return -1;
        try {
          // Both should be Timestamps or comparable
          return (tB as dynamic).compareTo(tA);
        } catch (e) {
          return 0;
        }
      });
      final sortedRevenue = Map.fromEntries(
        storeRevenue.entries.toList()..sort((e1, e2) => e2.value.compareTo(e1.value))
      );

      // 4. Detailed Store List
      List<Map<String, dynamic>> storeDetails = [];
      
      // Fetch General Platform Limits to compute "remaining" logic later in UI
      final limitsDoc = await _db.collection('settings').doc('platform_limits').get();
      final Map<String, dynamic> rawLimits = limitsDoc.exists ? (limitsDoc.data() ?? {}) : {};
      
      debugPrint('🔍 DEBUG: platform_limits doc exists: ${limitsDoc.exists}');
      debugPrint('🔍 DEBUG: platform_limits raw data: $rawLimits');

      final int dLimit = _parseLimit(rawLimits['daily'], 2000);
      final int mLimit = _parseLimit(rawLimits['monthly'], 50000);
      
      final Map<String, dynamic> limits = {
        'daily': dLimit,
        'monthly': mLimit,
      };

      debugPrint('📊 DashboardProvider: Platform Limits Parsed -> Daily: $dLimit, Monthly: $mLimit');


      await Future.wait(storeSnap.docs.map((d) async {
        final data = d.data();
        final storeId = d.id;
        final plan = data['subscriptionPlan'] ?? 'Basic';
        
        int dailyOrders = 0;
        int monthlyOrders = 0;
        
        if (plan == 'Basic') {
           try {
             // Basic stores report their local counts to this subcollection during sync
             final usageDoc = await _db.collection('stores').doc(storeId).collection('metadata').doc('usage').get();
             if (usageDoc.exists) {
               final usageData = usageDoc.data()!;
               dailyOrders = usageData['dailyOrders'] ?? 0;
               monthlyOrders = usageData['monthlyOrders'] ?? 0;
             }
           } catch (_) {}
        }

        storeDetails.add({
          'id': storeId,
          'name': data['name'] ?? 'Unknown',
          'ownerEmail': data['ownerEmail'] ?? '',
          'plan': plan,
          'addons': List<String>.from(data['addons'] ?? []),
          'expiry': data['subscriptionExpiry'],
          'dailyOrders': dailyOrders,
          'monthlyOrders': monthlyOrders,
          'dailyLimit': limits['daily'] ?? 50,
          'monthlyLimit': limits['monthly'] ?? 1500,
        });
      }));


      return {
        'totalValue': totalValue,
        'activeSubs': activeSubs,
        'totalStores': totalStores,
        'planDistribution': planDistribution,
        'storeRevenue': sortedRevenue,
        'recentHistory': recentHistory.take(10).toList(),
        'activeAddons': activeAddons,
        'storeDetails': storeDetails,
        'platformLimits': limits,
      };

    } catch (e) {
      debugPrint('❌ DashboardProvider: Error fetching global stats: $e');
      return {};
    }
  }
  int _getConsolidatedStandardDays() {
    final now = DateTime.now();
    int totalDays = 0;
    for (var sub in _subscriptionHistory) {
      if (sub.planName == 'Standard' && !sub.isAddonOnly && (sub.status == 'ACTIVE' || sub.status == 'QUEUED')) {
        if (sub.endDate.isAfter(now)) {
           final effectiveStart = sub.startDate.isBefore(now) ? now : sub.startDate;
           if (sub.endDate.isAfter(effectiveStart)) {
             totalDays += sub.endDate.difference(effectiveStart).inDays;
           }
        }
      }
    }
    return totalDays;
  }
  void _subscribeToSystemUsers() {
    _db.collection('users').where('role', isEqualTo: 'Super Admin').snapshots().listen((snap) {
       _superAdmins = snap.docs.map((d) => UserProfile.fromMap(d.data(), d.id)).toList();
       notifyListeners();
    });
    
    _db.collection('users').where('role', whereIn: ['Store Owner', 'Franchise Owner']).snapshots().listen((snap) {
       _systemUsers = snap.docs.map((d) => UserProfile.fromMap(d.data(), d.id)).toList();
       notifyListeners();
    });
  }

  StreamSubscription? _employeeLegacySub;
  StreamSubscription? _employeeAccessSub;

  void _subscribeToEmployees(String storeId) {
    _employeeLegacySub?.cancel();
    _employeeAccessSub?.cancel();
    
    // Set of employees to avoid duplicates
    final Map<String, UserProfile> uniqueEmployees = {};

    void updateEmployees() {
      _employees = uniqueEmployees.values.toList();
      notifyListeners();
    }
    
    // 1. Legacy: storeId direct match
    _employeeLegacySub = _db.collection('users')
       .where('storeId', isEqualTo: storeId)
       .snapshots()
       .listen((snapshot) {
           for (var doc in snapshot.docs) {
             uniqueEmployees[doc.id] = UserProfile.fromMap(doc.data(), doc.id);
           }
           updateEmployees();
       }, onError: (e) { /* Error ignored */ });

    // 2. Modern: accessibleStoreIds contains match
    _employeeAccessSub = _db.collection('users')
       .where('accessibleStoreIds', arrayContains: storeId)
       .snapshots()
       .listen((snapshot) {
           for (var doc in snapshot.docs) {
             uniqueEmployees[doc.id] = UserProfile.fromMap(doc.data(), doc.id);
           }
           updateEmployees();
       }, onError: (e) { /* Error ignored */ });

    // 3. NEW: Subcollection employees (stores/{storeId}/employees)
    final employeeSubCol = _db.collection('stores').doc(storeId).collection('employees')
       .snapshots()
       .listen((snapshot) {
           for (var doc in snapshot.docs) {
             uniqueEmployees[doc.id] = UserProfile.fromMap(doc.data(), doc.id);
           }
           updateEmployees();
       }, onError: (e) { /* Error ignored */ });
    _subscriptions.add(employeeSubCol);
       
    // Add to main subscriptions
    _subscriptions.add(_employeeLegacySub!);
    _subscriptions.add(_employeeAccessSub!);
  }

  Future<void> _loadOfflineSettings(String storeId) async {
    try {
      final offlineData = await _repository.getStoreSettings(storeId);
      if (offlineData != null && _storeSettings == null) {
        _storeSettings = StoreSettings.fromMap(offlineData, storeId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("❌ DashboardProvider: Error loading offline settings: $e");
    }
  }

  void _subscribeToSettings(String storeId) {
    _loadOfflineSettings(storeId); // Initial load from local Cache
    _db.collection('settings').doc(storeId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        _storeSettings = StoreSettings.fromMap(snapshot.data()!, snapshot.id);
        notifyListeners();
      }
    }, onError: (e) {
       debugPrint("❌ DashboardProvider: Error listening to settings: $e");
    });
  }

  void _subscribeToCounters(String storeId) {
     _countersSubscription?.cancel();
     _countersSubscription = _db.collection('counters')
         .where('storeId', isEqualTo: storeId)
         .snapshots()
         .listen((snapshot) {
             _counters = snapshot.docs.map((d) => CounterModel.fromMap(d.data(), d.id)).toList();
             notifyListeners();
         }, onError: (e) {
             debugPrint("❌ DashboardProvider: Error listening to counters: $e");
         });
  }
  
  Map<String, dynamic> _deepSanitize(Map map) {
    return Map<String, dynamic>.from(map);
  }

  Future<void> setActiveStoreId(String id) async {
    if (_activeStoreId == id) return;
    
    debugPrint('🏬 DashboardProvider: Setting Active Store ID to $id');
    if (_storeProvider != null) {
      await _storeProvider!.setActiveStoreId(id);
      // _onStoreChange will be triggered by listener
    } else {
      _activeStoreId = id;
      _loadFromCache();
    }
    fetchPendingSubscriptions();
    notifyListeners();
  }

  Future<void> fetchAttendance(String employeeId) async {
    // Stub implementation to be hooked up to repository/firestore
    _attendanceRecords = [];
    notifyListeners();
  }

  Future<void> fetchPayroll(String employeeId) async {
    // Stub implementation
    _payrollRecords = [];
    notifyListeners();
  }

  Future<void> updateEmployeePermissions(String employeeId, Map<String, bool> permissions, {List<String>? accessibleAddons, String? preferredTheme}) async {
    try {
      if (_activeStoreId != null) {
        final payload = {
          'permissions': permissions,
          if (accessibleAddons != null) 'accessibleAddons': accessibleAddons,
          if (preferredTheme != null) 'preferredTheme': preferredTheme,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        await _db.collection('stores/$_activeStoreId/employees').doc(employeeId).update(payload);
        fetchEmployees(refresh: true); // Refresh internal list
      }
    } catch(e) {
      debugPrint("Error updating permissions: $e");
    }
  }

  Future<void> updateEmployeeRates(String employeeId, {double? hourlyRate, double? monthlySalary}) async {
    try {
      if (_activeStoreId != null) {
        final payload = {
          if (hourlyRate != null) 'hourlyRate': hourlyRate,
          if (monthlySalary != null) 'monthlySalary': monthlySalary,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        await _db.collection('stores/$_activeStoreId/employees').doc(employeeId).update(payload);
        fetchEmployees(refresh: true);
      }
    } catch(e) {
      debugPrint("Error updating rates: $e");
    }
  }

  int _parseLimit(dynamic v, int fallback) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  bool _isClockTampered = false;
  bool get isClockTampered => _isClockTampered;

  void _checkClockTampered() {
    try {
      final box = Hive.box('settings');
      final lastKnownMs = box.get('last_known_time') as int?;
      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      // Threshold: January 1, 2025 (1735689600000 ms)
      const int thresholdMs = 1735689600000;

      if (nowMs < thresholdMs) {
        // System clock reset to default/epoch time (e.g. 1970/2020) due to offline boot.
        _isClockTampered = false;
        debugPrint('ℹ️ DashboardProvider: Clock reset detected (before 2025). Bypassing tamper check.');
      } else if (lastKnownMs != null && nowMs < lastKnownMs) {
        // Clock is in realistic range but went backward relative to last known time.
        // This indicates a manual rollback to bypass subscription.
        _isClockTampered = true;
        debugPrint('⚠️ DashboardProvider: Clock Tampering Detected! now=$nowMs, lastKnown=$lastKnownMs');
      } else {
        _isClockTampered = false;
        box.put('last_known_time', nowMs);
      }
    } catch (e) {
      debugPrint('⚠️ DashboardProvider: Error checking clock tampering: $e');
    }
  }

  void _updateLastKnownTime() {
    if (_isClockTampered) return;
    try {
      final box = Hive.box('settings');
      final lastKnownMs = box.get('last_known_time') as int?;
      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      const int thresholdMs = 1735689600000;

      if (nowMs < thresholdMs) {
        _isClockTampered = false;
      } else if (lastKnownMs != null && nowMs < lastKnownMs) {
        _isClockTampered = true;
        notifyListeners();
        debugPrint('⚠️ DashboardProvider: Clock Tampering Detected in background! now=$nowMs, lastKnown=$lastKnownMs');
      } else {
        box.put('last_known_time', nowMs);
      }
    } catch (e) {
      debugPrint('⚠️ DashboardProvider: Error updating last known time: $e');
    }
  }

  void recheckClockStatus() {
    try {
      final box = Hive.box('settings');
      final lastKnownMs = box.get('last_known_time') as int?;
      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      const int thresholdMs = 1735689600000;

      if (nowMs < thresholdMs || lastKnownMs == null || nowMs >= lastKnownMs) {
        _isClockTampered = false;
        if (nowMs >= thresholdMs) {
          box.put('last_known_time', nowMs);
        }
        notifyListeners();
        debugPrint('✅ DashboardProvider: Clock restored successfully!');
      } else {
        debugPrint('⚠️ DashboardProvider: Clock is still tampered.');
      }
    } catch (e) {
      debugPrint('⚠️ DashboardProvider: Error rechecking clock status: $e');
    }
  }

  Future<void> addExistingStoreToFranchise({
    required String email,
    required String password,
  }) async {
    final uid = _userProfile?.uid;
    if (uid == null) {
      throw Exception("User not authenticated.");
    }
    final franchiseName = _userProfile?.name.isNotEmpty == true 
        ? "${_userProfile!.name} Franchise" 
        : "Franchise";

    final secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryApp_${Random().nextInt(1000000)}',
      options: Firebase.app().options,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    
    try {
      final creds = await secondaryAuth.signInWithEmailAndPassword(email: email.trim(), password: password);
      final storeOwnerUid = creds.user?.uid;
      if (storeOwnerUid == null) {
        throw Exception("Authentication failed.");
      }
      
      // 2. Fetch and update the store using secondaryDb (authenticated as store owner)
      final secondaryDb = FirebaseFirestore.instanceFor(app: secondaryApp);
      final storeSnap = await secondaryDb.collection('stores')
          .where('ownerEmail', isEqualTo: email.toLowerCase().trim())
          .get();
          
      if (storeSnap.docs.isEmpty) {
        throw Exception("No store found owned by $email.");
      }
      
      final storeIds = <String>[];
      for (var doc in storeSnap.docs) {
        await secondaryDb.collection('stores').doc(doc.id).update({
          'franchiseId': uid,
          'franchiseName': franchiseName,
        });
        storeIds.add(doc.id);
      }
      
      // Link store IDs to franchise owner using primary _db (authenticated as franchise owner)
      await _db.collection('users').doc(uid).set({
        'accessibleStoreIds': FieldValue.arrayUnion(storeIds),
        'storeIds': FieldValue.arrayUnion(storeIds),
      }, SetOptions(merge: true));
      
      // Refresh local stores list in StoreProvider
      if (_storeProvider != null) {
        await _storeProvider!.fetchStores(isSuperAdmin: isSuperAdmin);
        _stores = _storeProvider!.stores;
        notifyListeners();
      }
    } finally {
      await secondaryApp.delete();
    }
  }
}
