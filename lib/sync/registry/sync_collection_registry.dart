import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

/// Centralized registry for all sync-aware Firestore collections.
///
/// Eliminates magic strings throughout the sync layer and provides
/// a single source of truth for collection names, Hive box mappings,
/// and module metadata.
class SyncCollectionRegistry {
  SyncCollectionRegistry._();

  // ─── Collection Names (Firestore) ──────────────────────────
  static const String orders = 'orders';
  static const String inventory = 'inventory';
  static const String customers = 'customers';
  static const String employees = 'employees';
  static const String settings = 'settings';
  static const String floors = 'floors';
  static const String tables = 'tables';
  static const String suppliers = 'suppliers';
  static const String notes = 'notes';
  static const String inventoryMovements = 'inventory_movements';
  static const String businessEvents = 'business_events';
  static const String counters = 'counters';
  static const String activityLogs = 'activity_logs';
  static const String stores = 'stores';
  static const String users = 'users';
  static const String platformLimits = 'platform_limits';

  // ─── Hive Box Names ────────────────────────────────────────
  static const String boxOrders = 'cache_orders';
  static const String boxInventory = 'cache_inventory';
  static const String boxCustomers = 'cache_customers';
  static const String boxSettings = 'cache_settings';
  static const String boxSyncQueue = 'sync_queue_v2';
  static const String boxFailedQueue = 'sync_failed_queue_v2';
  static const String boxSyncLogs = 'sync_logs';
  static const String boxSettingsGeneral = 'settings';

  /// Store-scoped Hive box name pattern for employees, floors, etc.
  static String boxEmployees(String? storeId) =>
      storeId != null ? 'cache_employees_$storeId' : 'cache_employees';
  static String boxFloors(String? storeId) =>
      storeId != null ? 'cache_floors_$storeId' : 'cache_floors';
  static String boxTables(String? storeId) =>
      storeId != null ? 'cache_tables_$storeId' : 'cache_tables';
  static String boxSuppliers(String? storeId) =>
      storeId != null ? 'cache_suppliers_$storeId' : 'cache_suppliers';
  static String boxNotes(String? storeId) =>
      storeId != null ? 'cache_notes_$storeId' : 'cache_notes';

  // ─── Module Lists ──────────────────────────────────────────

  /// All modules that participate in inbound pull sync.
  static const List<String> pullModules = [
    orders,
    inventory,
    customers,
    settings,
    employees,
    tables,
    floors,
    suppliers,
    notes,
    inventoryMovements,
  ];

  /// Modules that store heavy data (SQLite on mobile, Hive on web).
  static const List<String> heavyDataModules = [
    orders,
    inventory,
    customers,
    employees,
    floors,
    tables,
    suppliers,
    notes,
  ];

  /// Collections that require a `storeId` filter on root-level queries.
  static const List<String> storeFilteredCollections = [
    orders,
    inventory,
    customers,
    inventoryMovements,
    businessEvents,
    counters,
    activityLogs,
    employees,
    floors,
    tables,
    suppliers,
    notes,
  ];

  /// Collections that support reconciliation (orphan cleanup).
  static const List<String> reconcilableCollections = [
    orders,
    inventory,
    customers,
    employees,
    floors,
    tables,
    suppliers,
    notes,
  ];

  /// Collections that require idempotency protection.
  static const List<String> idempotentCollections = [
    orders,
    inventoryMovements,
    businessEvents,
  ];

  // ─── Lookups ───────────────────────────────────────────────

  /// Returns the Hive box name for a given collection.
  /// Returns `null` if no box mapping exists.
  static String? getBoxName(String collection, {String? storeId}) {
    switch (collection) {
      case orders:
        return boxOrders;
      case inventory:
        return boxInventory;
      case customers:
        return boxCustomers;
      case employees:
        return boxEmployees(storeId);
      case floors:
        return boxFloors(storeId);
      case tables:
        return boxTables(storeId);
      case suppliers:
        return boxSuppliers(storeId);
      case notes:
        return boxNotes(storeId);
      case settings:
        return boxSettings;
      default:
        return null;
    }
  }

  /// Returns the SQLite table name for a given collection.
  /// Some collections have different table names in SQLite.
  static String getSqlTable(String collection) {
    if (collection == settings) return 'store_settings';
    return collection;
  }

  /// All Hive boxes that should be pre-opened during init.
  static List<String> getInitBoxes() => [
        boxSyncQueue,
        boxFailedQueue,
        boxSettingsGeneral,
        boxOrders,
        boxInventory,
        boxCustomers,
        boxSettings,
        boxSyncLogs,
        // Note: store-scoped boxes (employees, floors, etc.) are opened dynamically
      ];

  /// Returns the Firestore path for a collection.
  /// All collections are now root-level.
  static String getFirestorePath(String collection) => collection;

  /// Returns true if this collection uses `storeId` field filtering
  /// (as opposed to document ID matching like settings).
  static bool usesStoreIdFilter(String collection) =>
      storeFilteredCollections.contains(collection);

  /// Returns true if this collection uses document ID matching (e.g., settings).
  static bool usesDocIdFilter(String collection) => collection == settings;

  /// Initializes all required Hive boxes during SyncService.init().
  static Future<void> initializeHive() async {
    for (var boxName in getInitBoxes()) {
      try {
        if (!Hive.isBoxOpen(boxName)) {
          await Hive.openBox(boxName);
        }
      } catch (e) {
        debugPrint('⚠️ [SyncCollectionRegistry] Failed to open box $boxName: $e');
      }
    }
  }
}
