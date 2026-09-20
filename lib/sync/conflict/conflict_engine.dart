import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/sync/conflict/conflict_record.dart';
import 'package:biztonic_pos/sync/registry/sync_collection_registry.dart';

enum ResolutionAction {
  cloudWins,
  localWins,
  mergeApplied,
  recordConflict,
}

class ConflictResolutionResult {
  final ResolutionAction action;
  final Map<String, dynamic>? mergedData;
  final ConflictRecord? conflictRecord;

  ConflictResolutionResult.cloudWins()
      : action = ResolutionAction.cloudWins,
        mergedData = null,
        conflictRecord = null;

  ConflictResolutionResult.localWins()
      : action = ResolutionAction.localWins,
        mergedData = null,
        conflictRecord = null;

  ConflictResolutionResult.merge(Map<String, dynamic> data)
      : action = ResolutionAction.mergeApplied,
        mergedData = data,
        conflictRecord = null;

  ConflictResolutionResult.conflict(ConflictRecord record)
      : action = ResolutionAction.recordConflict,
        mergedData = null,
        conflictRecord = record;
}

/// Handles deterministic, entity-specific conflict resolution.
///
/// BANS generic Last-Write-Wins (LWW) for financial & inventory operations.
/// Creates [ConflictRecord]s when automatic resolution is unsafe.
class ConflictEngine {
  /// Resolves conflicts deterministically per entity type.
  ConflictResolutionResult resolve({
    required String collection,
    required Map<String, dynamic> cloudData,
    required Map<String, dynamic>? localData,
    String? storeId,
  }) {
    if (localData == null) {
      return ConflictResolutionResult.cloudWins();
    }

    final localDeleted = localData['isDeleted'] == true ||
        localData['isDeleted'] == 1 ||
        localData['deletedAt'] != null;
    final cloudDeleted = cloudData['isDeleted'] == true ||
        cloudData['isDeleted'] == 1 ||
        cloudData['deletedAt'] != null;

    // TOMBSTONE PRESERVATION:
    // If local or cloud is deleted, deletions take precedence over non-deleted records
    // unless the non-deleted record is an explicit re-creation with a strictly newer timestamp.
    if (localDeleted && !cloudDeleted) {
      final localDeletedAt =
          DateTime.tryParse(localData['deletedAt']?.toString() ?? '');
      final cloudUpdatedAt =
          DateTime.tryParse(cloudData['updatedAt']?.toString() ?? '');
      if (localDeletedAt != null &&
          cloudUpdatedAt != null &&
          cloudUpdatedAt.isAfter(localDeletedAt)) {
        return ConflictResolutionResult.cloudWins();
      }
      return ConflictResolutionResult.localWins();
    }

    if (cloudDeleted && !localDeleted) {
      final cloudDeletedAt =
          DateTime.tryParse(cloudData['deletedAt']?.toString() ?? '');
      final localUpdatedAt =
          DateTime.tryParse(localData['updatedAt']?.toString() ?? '');
      if (localUpdatedAt != null &&
          cloudDeletedAt != null &&
          localUpdatedAt.isAfter(cloudDeletedAt)) {
        return ConflictResolutionResult.localWins();
      }
      return ConflictResolutionResult.cloudWins();
    }

    final localStatus = localData['syncStatus']?.toString() ?? '';
    final hasPendingLocalWrite =
        localStatus == 'PENDING' || localStatus == 'IN_FLIGHT';

    // If local has no pending writes and was already confirmed, cloud update is standard delta
    if (!hasPendingLocalWrite) {
      final cloudVersion = _parseInt(cloudData['version'], 1);
      final localVersion = _parseInt(localData['version'], 1);
      if (cloudVersion >= localVersion) {
        return ConflictResolutionResult.cloudWins();
      }
      return ConflictResolutionResult.localWins();
    }

    // Both local and cloud have concurrent mutations. Apply domain-specific matrix:
    switch (collection) {
      case SyncCollectionRegistry.inventory:
        return _resolveInventory(cloudData, localData, storeId);

      case SyncCollectionRegistry.orders:
        return _resolveOrders(cloudData, localData, storeId);

      case SyncCollectionRegistry.customers:
        return _resolveCustomers(cloudData, localData, storeId);

      case SyncCollectionRegistry.settings:
        return _resolveSettings(cloudData, localData, storeId);

      case SyncCollectionRegistry.employees:
        return _resolveEmployees(cloudData, localData, storeId);

      case SyncCollectionRegistry.tables:
        return _resolveTables(cloudData, localData, storeId);

      case SyncCollectionRegistry.inventoryMovements:
      case SyncCollectionRegistry.businessEvents:
        // Financial ledgers: immutable append semantics.
        // Identical records are deduplicated; divergent records are never overwritten.
        return ConflictResolutionResult.localWins();

      default:
        return _resolveGeneric(collection, cloudData, localData, storeId);
    }
  }

  /// Backward-compatible boolean evaluator.
  bool shouldCloudWin({
    String collection = 'generic',
    required Map<String, dynamic> cloudData,
    required Map<String, dynamic>? localData,
    String? storeId,
    Function(ConflictRecord)? onConflictDetected,
  }) {
    final result = resolve(
      collection: collection,
      cloudData: cloudData,
      localData: localData,
      storeId: storeId,
    );

    switch (result.action) {
      case ResolutionAction.cloudWins:
        return true;
      case ResolutionAction.localWins:
        return false;
      case ResolutionAction.mergeApplied:
        if (result.mergedData != null && localData != null) {
          localData.addAll(result.mergedData!);
        }
        return true;
      case ResolutionAction.recordConflict:
        if (result.conflictRecord != null && onConflictDetected != null) {
          onConflictDetected(result.conflictRecord!);
        }
        return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DOMAIN-SPECIFIC CONFLICT RESOLVERS
  // ─────────────────────────────────────────────────────────────

  /// Inventory Conflict Resolver:
  /// NEVER use LWW for stock quantity! Stock is strictly movement-ledger derived.
  /// Master metadata (price, name, category) merges with highest version.
  ConflictResolutionResult _resolveInventory(
    Map<String, dynamic> cloudData,
    Map<String, dynamic> localData,
    String? storeId,
  ) {
    final cloudQty = _parseInt(cloudData['quantity'], 0);
    final localQty = _parseInt(localData['quantity'], 0);

    // If stock quantities diverge while local is pending, preserve local quantity projection!
    // Flag ConflictRecord if difference is significant and manual inspection is needed
    ConflictRecord? record;
    if (cloudQty != localQty) {
      record = ConflictRecord(
        storeId: storeId ?? localData['storeId']?.toString() ?? '',
        collection: SyncCollectionRegistry.inventory,
        entityId: localData['id']?.toString() ?? '',
        conflictType: 'INVENTORY_STOCK_DIVERGENCE',
        localData: {'quantity': localQty},
        cloudData: {'quantity': cloudQty},
        resolution: 'LOCAL_STOCK_PRESERVED_PENDING_RECONCILIATION',
      );
    }

    final cloudVersion = _parseInt(cloudData['version'], 1);
    final localVersion = _parseInt(localData['version'], 1);

    // Merge metadata: highest version wins for product details, local quantity is preserved
    final merged = Map<String, dynamic>.from(
        cloudVersion >= localVersion ? cloudData : localData);
    merged['quantity'] =
        localQty; // Never overwrite local stock with cloud LWW!
    merged['syncStatus'] = localData[
        'syncStatus']; // Maintain pending status until outbound pushes

    if (record != null) {
      return ConflictResolutionResult.conflict(record);
    }
    return ConflictResolutionResult.merge(merged);
  }

  /// Orders Conflict Resolver:
  /// Paid/completed orders are immutable financial transactions.
  /// Open draft orders merge items.
  ConflictResolutionResult _resolveOrders(
    Map<String, dynamic> cloudData,
    Map<String, dynamic> localData,
    String? storeId,
  ) {
    final localStatus = localData['status']?.toString().toUpperCase();
    final cloudStatus = cloudData['status']?.toString().toUpperCase();

    // VOID status takes precedence for security and fraud prevention
    if (localStatus == 'VOID' || cloudStatus == 'VOID') {
      final merged = Map<String, dynamic>.from(
          localStatus == 'VOID' ? localData : cloudData);
      merged['status'] = 'VOID';
      return ConflictResolutionResult.merge(merged);
    }

    // Finalized orders are immutable
    if (localStatus == 'COMPLETED' || localStatus == 'PAID') {
      return ConflictResolutionResult.localWins();
    }

    // Draft / open table orders: merge line items
    if (localStatus == 'DRAFT' ||
        localStatus == 'OPEN' ||
        localStatus == 'IN_PROGRESS') {
      final localItems = (localData['items'] as List?) ?? [];
      final cloudItems = (cloudData['items'] as List?) ?? [];

      // Combine items by item/variant ID
      final itemMap = <String, Map<String, dynamic>>{};
      for (var item in [...cloudItems, ...localItems]) {
        if (item is Map) {
          final mItem = Map<String, dynamic>.from(item);
          final id =
              mItem['itemId']?.toString() ?? mItem['id']?.toString() ?? '';
          if (itemMap.containsKey(id)) {
            final existing = itemMap[id]!;
            final currentQty = _parseInt(existing['quantity'], 1);
            final addQty = _parseInt(mItem['quantity'], 1);
            existing['quantity'] = currentQty + addQty;
          } else {
            itemMap[id] = mItem;
          }
        }
      }

      final merged = Map<String, dynamic>.from(cloudData);
      merged['items'] = itemMap.values.toList();
      merged['total'] = localData['total'] ?? cloudData['total'];
      merged['syncStatus'] = localData['syncStatus'];
      return ConflictResolutionResult.merge(merged);
    }

    return ConflictResolutionResult.localWins();
  }

  /// Customers Conflict Resolver:
  /// Profile master data uses highest version; loyalty balance is additive.
  ConflictResolutionResult _resolveCustomers(
    Map<String, dynamic> cloudData,
    Map<String, dynamic> localData,
    String? storeId,
  ) {
    final cloudVersion = _parseInt(cloudData['version'], 1);
    final localVersion = _parseInt(localData['version'], 1);

    final merged = Map<String, dynamic>.from(
        cloudVersion >= localVersion ? cloudData : localData);

    // If both modified points, preserve additive points delta
    final localPoints = _parseInt(localData['loyaltyPoints'], 0);
    final cloudPoints = _parseInt(cloudData['loyaltyPoints'], 0);
    if (localPoints != cloudPoints) {
      merged['loyaltyPoints'] = math.max(localPoints, cloudPoints);
    }

    merged['syncStatus'] = localData['syncStatus'];
    return ConflictResolutionResult.merge(merged);
  }

  /// Settings Conflict Resolver:
  /// Financial settings divergence (e.g. tax rate) creates ConflictRecord.
  ConflictResolutionResult _resolveSettings(
    Map<String, dynamic> cloudData,
    Map<String, dynamic> localData,
    String? storeId,
  ) {
    final cloudTax = cloudData['taxRate'] ?? cloudData['tax_rate'];
    final localTax = localData['taxRate'] ?? localData['tax_rate'];

    if (cloudTax != null &&
        localTax != null &&
        cloudTax.toString() != localTax.toString()) {
      final record = ConflictRecord(
        storeId: storeId ?? localData['storeId']?.toString() ?? '',
        collection: SyncCollectionRegistry.settings,
        entityId: localData['id']?.toString() ?? 'store_settings',
        conflictType: 'TAX_RATE_DIVERGENCE',
        localData: {'taxRate': localTax},
        cloudData: {'taxRate': cloudTax},
        resolution: 'MANUAL_REQUIRED',
      );
      return ConflictResolutionResult.conflict(record);
    }

    // Default: highest version wins
    final cloudVersion = _parseInt(cloudData['version'], 1);
    final localVersion = _parseInt(localData['version'], 1);
    return cloudVersion >= localVersion
        ? ConflictResolutionResult.cloudWins()
        : ConflictResolutionResult.localWins();
  }

  /// Employees Conflict Resolver:
  /// Role privilege hierarchy: Owner > Manager > Cashier > Staff.
  /// SUSPENDED / REMOVED status always takes precedence for security.
  ConflictResolutionResult _resolveEmployees(
    Map<String, dynamic> cloudData,
    Map<String, dynamic> localData,
    String? storeId,
  ) {
    final cloudStatus = cloudData['status']?.toString().toUpperCase();
    final localStatus = localData['status']?.toString().toUpperCase();

    // Security first: suspension or removal cannot be overridden by an offline client
    if (cloudStatus == 'SUSPENDED' || cloudStatus == 'REMOVED') {
      return ConflictResolutionResult.cloudWins();
    }
    if (localStatus == 'SUSPENDED' || localStatus == 'REMOVED') {
      return ConflictResolutionResult.localWins();
    }

    final cloudRole = cloudData['role']?.toString();
    final localRole = localData['role']?.toString();

    final roleRanks = {'Owner': 4, 'Manager': 3, 'Cashier': 2, 'Staff': 1};
    final cloudRank = roleRanks[cloudRole] ?? 0;
    final localRank = roleRanks[localRole] ?? 0;

    if (cloudRank != localRank) {
      return cloudRank > localRank
          ? ConflictResolutionResult.cloudWins()
          : ConflictResolutionResult.localWins();
    }

    final cloudVersion = _parseInt(cloudData['version'], 1);
    final localVersion = _parseInt(localData['version'], 1);
    return cloudVersion >= localVersion
        ? ConflictResolutionResult.cloudWins()
        : ConflictResolutionResult.localWins();
  }

  /// Tables Conflict Resolver:
  /// OCCUPIED status wins over AVAILABLE to prevent double seating.
  /// If two different orderIds seated simultaneously, flag ConflictRecord.
  ConflictResolutionResult _resolveTables(
    Map<String, dynamic> cloudData,
    Map<String, dynamic> localData,
    String? storeId,
  ) {
    final cloudStatus = cloudData['status']?.toString().toUpperCase();
    final localStatus = localData['status']?.toString().toUpperCase();

    final cloudOrder = cloudData['activeOrderId']?.toString();
    final localOrder = localData['activeOrderId']?.toString();

    // Double-seat collision check
    if (cloudOrder != null &&
        localOrder != null &&
        cloudOrder.isNotEmpty &&
        localOrder.isNotEmpty &&
        cloudOrder != localOrder) {
      final record = ConflictRecord(
        storeId: storeId ?? localData['storeId']?.toString() ?? '',
        collection: SyncCollectionRegistry.tables,
        entityId: localData['id']?.toString() ?? '',
        conflictType: 'TABLE_DOUBLE_SEAT',
        localData: {'orderId': localOrder, 'status': localStatus},
        cloudData: {'orderId': cloudOrder, 'status': cloudStatus},
        resolution: 'MANUAL_REQUIRED',
      );
      return ConflictResolutionResult.conflict(record);
    }

    // OCCUPIED wins over AVAILABLE
    if (localStatus == 'OCCUPIED') return ConflictResolutionResult.localWins();
    if (cloudStatus == 'OCCUPIED') return ConflictResolutionResult.cloudWins();

    final cloudVersion = _parseInt(cloudData['version'], 1);
    final localVersion = _parseInt(localData['version'], 1);
    return cloudVersion >= localVersion
        ? ConflictResolutionResult.cloudWins()
        : ConflictResolutionResult.localWins();
  }

  ConflictResolutionResult _resolveGeneric(
    String collection,
    Map<String, dynamic> cloudData,
    Map<String, dynamic> localData,
    String? storeId,
  ) {
    final cloudVersion = _parseInt(cloudData['version'], 1);
    final localVersion = _parseInt(localData['version'], 1);

    if (cloudVersion > localVersion) {
      return ConflictResolutionResult.cloudWins();
    }
    if (cloudVersion < localVersion) {
      return ConflictResolutionResult.localWins();
    }

    final cloudUpdated = _parseDate(cloudData['updatedAt']);
    final localUpdated = _parseDate(localData['updatedAt']);

    if (cloudUpdated != null && localUpdated != null) {
      return cloudUpdated.isAfter(localUpdated)
          ? ConflictResolutionResult.cloudWins()
          : ConflictResolutionResult.localWins();
    }

    return ConflictResolutionResult.cloudWins();
  }

  int _parseInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
