import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/features/inventory/domain/entities/inventory_movement.dart';
import 'package:biztonic_pos/features/inventory/domain/policies/inventory_policy.dart';
import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';
import 'package:biztonic_pos/core/diagnostics/diagnostics_models.dart';
import 'package:biztonic_pos/core/diagnostics/diagnostics_service.dart';
import 'package:biztonic_pos/core/audit/audit_models.dart';
import 'package:biztonic_pos/core/audit/audit_service.dart';

/// Single item discrepancy record detected during reconciliation.
class InventoryDiscrepancy {
  final String itemId;
  final String storeId;
  final int expectedQuantity; // from ledger sum
  final int actualQuantity; // from projection
  final int drift; // actualQuantity - expectedQuantity
  final bool repaired;

  InventoryDiscrepancy({
    required this.itemId,
    required this.storeId,
    required this.expectedQuantity,
    required this.actualQuantity,
    required this.drift,
    this.repaired = false,
  });

  Map<String, dynamic> toMap() => {
        'itemId': itemId,
        'storeId': storeId,
        'expectedQuantity': expectedQuantity,
        'actualQuantity': actualQuantity,
        'drift': drift,
        'repaired': repaired,
      };
}

/// Comprehensive report produced by reconciliation tooling.
class ReconciliationReport {
  final String storeId;
  final DateTime timestamp;
  final int itemsChecked;
  final List<InventoryDiscrepancy> discrepancies;
  final bool autoRepaired;

  ReconciliationReport({
    required this.storeId,
    required this.timestamp,
    required this.itemsChecked,
    required this.discrepancies,
    required this.autoRepaired,
  });

  bool get hasDiscrepancies => discrepancies.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'storeId': storeId,
        'timestamp': timestamp.toIso8601String(),
        'itemsChecked': itemsChecked,
        'discrepancies': discrepancies.map((d) => d.toMap()).toList(),
        'autoRepaired': autoRepaired,
      };
}

class InventoryMovementRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ─── INSERT MOVEMENT (AUTHORITATIVE LEDGER ENTRY) ───────────

  /// Insert a new inventory movement into the immutable ledger and atomically
  /// update derived projections.
  ///
  /// Guarantees:
  /// 1. Idempotency: Duplicate movements (by id or operationId) are safely ignored.
  /// 2. Store isolation: Rejects cross-store item or store pollution.
  /// 3. Refund integrity: Validates original sale exists and has not been over-refunded.
  /// 4. Negative stock policy: Enforces store's BLOCK, ALLOW_WITH_WARNING, or ALLOW policy.
  /// 5. Single authoritative ledger: Derived caches (SQLite and Hive) are projections only.
  Future<bool> insertMovement(
    InventoryMovement movement, {
    Transaction? txn,
    NegativeStockPolicy? negativeStockPolicy,
    bool checkItemStore = true,
  }) async {
    return await DiagnosticsService().trace<bool>(
      subsystem: DiagnosticSubsystem.inventory,
      operationId: 'inv_mov_${movement.operationId}',
      storeId: movement.storeId,
      entityId: movement.itemId,
      actionName: 'Inventory Movement (${movement.type})',
      metadata: {
        'delta': movement.delta,
        'type': movement.type,
        'reason': movement.reason,
      },
      operation: () async {
        bool result;
        if (txn != null) {
          result = await _insertMovementWithTxn(
            txn,
            movement,
            negativeStockPolicy: negativeStockPolicy,
            checkItemStore: checkItemStore,
          );
        } else {
          final db = await _dbHelper.database;
          result = await db.transaction((newTxn) async {
            return await _insertMovementWithTxn(
              newTxn,
              movement,
              negativeStockPolicy: negativeStockPolicy,
              checkItemStore: checkItemStore,
            );
          });
        }

        if (result && movement.type == MovementType.adjustment) {
          await AuditService().recordAction(
            storeId: movement.storeId,
            action: AuditActionType.stockAdjustment,
            actorId: 'staff',
            entityId: movement.itemId,
            entityType: 'INVENTORY_ITEM',
            reason: movement.reason ?? 'Stock adjustment',
            newState: {'delta': movement.delta, 'unitCost': movement.unitCost},
          );
        }

        return result;
      },
    );
  }

  Future<bool> _insertMovementWithTxn(
    Transaction txn,
    InventoryMovement movement, {
    NegativeStockPolicy? negativeStockPolicy,
    bool checkItemStore = true,
  }) async {
    // ─── 1. Idempotency / Duplicate Guard ────────────────────
    // Check if movement already exists by primary ID or (storeId, operationId)
    final existingById = await txn.query(
      'inventory_movements',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [movement.id],
      limit: 1,
    );

    if (existingById.isNotEmpty) {
      debugPrint(
          '🛡️ InventoryMovementRepository: Duplicate movement ignored by id: ${movement.id}');
      return false;
    }

    if (movement.operationId.isNotEmpty) {
      final existingByOp = await txn.query(
        'inventory_movements',
        columns: ['id'],
        where: 'storeId = ? AND operationId = ?',
        whereArgs: [movement.storeId, movement.operationId],
        limit: 1,
      );

      if (existingByOp.isNotEmpty) {
        debugPrint(
            '🛡️ InventoryMovementRepository: Duplicate movement ignored by operationId: ${movement.operationId}');
        return false;
      }
    }

    // ─── 2. Cross-Store & Item Isolation Validation ──────────
    bool itemTracksStock = true;
    if (checkItemStore) {
      final itemRows = await txn.query(
        'inventory',
        columns: ['id', 'storeId', 'trackStock'],
        where: 'id = ?',
        whereArgs: [movement.itemId],
        limit: 1,
      );

      if (itemRows.isNotEmpty) {
        final itemStoreId = itemRows.first['storeId']?.toString();
        if (itemStoreId != null &&
            itemStoreId.isNotEmpty &&
            itemStoreId != movement.storeId) {
          throw CrossStoreViolationException(
            movementStoreId: movement.storeId,
            itemStoreId: itemStoreId,
            itemId: movement.itemId,
          );
        }

        final trackVal = itemRows.first['trackStock'];
        if (trackVal != null && (trackVal == 0 || trackVal == false)) {
          itemTracksStock = false;
        }
      } else {
        // Line item not found in local inventory table (e.g. custom charge or service)
        itemTracksStock = false;
      }
    }

    // ─── 3. Refund & Reversal Validation ─────────────────────
    if (movement.type == MovementType.refund ||
        movement.type == MovementType.saleReversal ||
        movement.type == MovementType.voidReversal) {
      await _validateRefundMovement(txn, movement);
    }

    // ─── 4. Negative Stock Policy Enforcement ────────────────
    final currentStock = await _getItemQuantityWithTxn(
      txn,
      movement.itemId,
      movement.storeId,
      seedIfMissing: movement.type != MovementType.initialStock,
    );
    final projectedStock = currentStock + movement.delta;

    final policy = negativeStockPolicy ?? NegativeStockPolicy.block;
    if (itemTracksStock && projectedStock < 0) {
      if (policy == NegativeStockPolicy.block) {
        throw InsufficientStockException(
          itemId: movement.itemId,
          storeId: movement.storeId,
          currentStock: currentStock,
          requestedDelta: movement.delta,
        );
      } else if (policy == NegativeStockPolicy.allowWithWarning) {
        debugPrint(
            '⚠️ NegativeStockWarning: Item ${movement.itemId} in store ${movement.storeId} stock will be negative: $projectedStock (Policy: ALLOW_WITH_WARNING)');
      }
    }

    // ─── 5. Insert Movement into Immutable Ledger ────────────
    await txn.insert(
      'inventory_movements',
      movement.toSqlMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    // ─── 6. Atomically Update Derived Projections ────────────
    // Derived Projection A: cache_inventory_quantities
    await txn.rawInsert(
      'INSERT OR REPLACE INTO cache_inventory_quantities (itemId, storeId, quantity) VALUES (?, ?, ?)',
      [movement.itemId, movement.storeId, projectedStock],
    );

    // Derived Projection B: inventory table quantity
    await txn.rawUpdate(
      'UPDATE inventory SET quantity = ? WHERE id = ?',
      [projectedStock, movement.itemId],
    );

    // Derived Projection C: Hive cache (if open)
    _updateHiveCacheProjection(movement.itemId, projectedStock);

    return true;
  }

  /// Validates that a refund or reversal corresponds to an actual sale
  /// and does not exceed the remaining sold quantity.
  Future<void> _validateRefundMovement(
      Transaction txn, InventoryMovement movement) async {
    final orderId = movement.orderId;
    if (orderId == null || orderId.isEmpty) {
      throw InvalidRefundException(
        orderId: 'NONE',
        itemId: movement.itemId,
        requestedQuantity: movement.delta,
        soldQuantity: 0,
        alreadyRefundedQuantity: 0,
        customMessage:
            'Refund movement for item ${movement.itemId} missing required orderId.',
      );
    }

    // Sum all SALE movements for this order and item
    final saleRows = await txn.rawQuery('''
      SELECT SUM(ABS(delta)) as totalSold
      FROM inventory_movements
      WHERE storeId = ? AND orderId = ? AND itemId = ? AND type = ? AND isDeleted = 0
    ''', [movement.storeId, orderId, movement.itemId, MovementType.sale]);

    final totalSold = (saleRows.first['totalSold'] as num?)?.toInt() ?? 0;
    if (totalSold <= 0) {
      throw InvalidRefundException(
        orderId: orderId,
        itemId: movement.itemId,
        requestedQuantity: movement.delta,
        soldQuantity: 0,
        alreadyRefundedQuantity: 0,
        customMessage:
            'Cannot refund item ${movement.itemId} on order $orderId: no original sale found in movement ledger.',
      );
    }

    // Sum all prior refund and reversal movements for this order and item
    final refundRows = await txn.rawQuery('''
      SELECT SUM(delta) as totalRefunded
      FROM inventory_movements
      WHERE storeId = ? AND orderId = ? AND itemId = ? 
        AND type IN (?, ?, ?) AND isDeleted = 0
    ''', [
      movement.storeId,
      orderId,
      movement.itemId,
      MovementType.refund,
      MovementType.saleReversal,
      MovementType.voidReversal,
    ]);

    final totalRefunded =
        (refundRows.first['totalRefunded'] as num?)?.toInt() ?? 0;
    final maxRefundable = totalSold - totalRefunded;

    if (movement.delta > maxRefundable) {
      throw InvalidRefundException(
        orderId: orderId,
        itemId: movement.itemId,
        requestedQuantity: movement.delta,
        soldQuantity: totalSold,
        alreadyRefundedQuantity: totalRefunded,
      );
    }
  }

  void _updateHiveCacheProjection(String itemId, int quantity) {
    try {
      if (Hive.isBoxOpen('cache_inventory')) {
        final box = Hive.box('cache_inventory');
        final raw = box.get(itemId);
        if (raw != null && raw is Map) {
          final itemData = Map<String, dynamic>.from(raw);
          itemData['quantity'] = quantity;
          itemData['syncStatus'] = 'PENDING';
          itemData['updatedAt'] = DateTime.now().toIso8601String();
          box.put(itemId, itemData);
        }
      }
    } catch (_) {}
  }

  // ─── QUANTITY QUERIES (FROM AUTHORITATIVE LEDGER) ───────────

  /// Get current quantity for a specific item (SUM of deltas in movement ledger).
  Future<int> getItemQuantity(String itemId, {String? storeId}) async {
    final db = await _dbHelper.database;
    String sql =
        'SELECT SUM(delta) as quantity FROM inventory_movements WHERE itemId = ? AND isDeleted = 0';
    List<dynamic> args = [itemId];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    final result = await db.rawQuery(sql, args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Alias for getItemQuantity
  Future<int> getAggregatedQuantity(String itemId, {String? storeId}) =>
      getItemQuantity(itemId, storeId: storeId);

  Future<int> _getItemQuantityWithTxn(
      Transaction txn, String itemId, String? storeId,
      {bool seedIfMissing = true}) async {
    String sql =
        'SELECT COUNT(*) as cnt, SUM(delta) as quantity FROM inventory_movements WHERE itemId = ? AND isDeleted = 0';
    List<dynamic> args = [itemId];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    final result = await txn.rawQuery(sql, args);
    final cnt = (result.first['cnt'] as num?)?.toInt() ?? 0;
    if (cnt == 0 && seedIfMissing) {
      final itemRows = await txn.query(
        'inventory',
        columns: ['quantity', 'cost', 'deviceId', 'storeId'],
        where: 'id = ?',
        whereArgs: [itemId],
        limit: 1,
      );
      if (itemRows.isNotEmpty) {
        final existingItemQty =
            (itemRows.first['quantity'] as num?)?.toInt() ?? 0;
        if (existingItemQty > 0) {
          final effStoreId =
              storeId ?? (itemRows.first['storeId'] as String?) ?? '';
          await txn.insert(
            'inventory_movements',
            {
              'id': 'init_$itemId',
              'itemId': itemId,
              'storeId': effStoreId,
              'type': 'INITIAL_STOCK',
              'delta': existingItemQty,
              'unitCost': (itemRows.first['cost'] as num?)?.toDouble() ?? 0.0,
              'reason': 'Initial Stock Preserved',
              'orderId': null,
              'deviceId': (itemRows.first['deviceId'] as String?) ?? 'system',
              'operationId': 'init_$itemId',
              'createdAt': DateTime.now().millisecondsSinceEpoch,
              'syncStatus': 'PENDING',
              'isDeleted': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          return existingItemQty;
        }
      }
    }
    return (result.first['quantity'] as num?)?.toInt() ?? 0;
  }

  /// Get quantities for all items in a store (calculated from movement ledger).
  Future<Map<String, int>> getAllQuantities(String? storeId) async {
    final db = await _dbHelper.database;
    String sql = '''
      SELECT itemId, SUM(delta) as quantity
      FROM inventory_movements
      WHERE isDeleted = 0
    ''';
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    sql += ' GROUP BY itemId';

    final result = await db.rawQuery(sql, args);
    return Map.fromEntries(result.map((row) =>
        MapEntry(row['itemId'] as String, (row['quantity'] as int?) ?? 0)));
  }

  // ─── PROJECTION REBUILDING (MATHEMATICALLY RECONSTRUCT) ──────

  /// Reconstructs derived inventory quantity projections entirely from the
  /// authoritative movements ledger.
  ///
  /// Rebuilds:
  /// 1. SQLite `cache_inventory_quantities`
  /// 2. SQLite `inventory.quantity`
  /// 3. Hive `cache_inventory`
  Future<Map<String, int>> rebuildInventoryProjection(String storeId) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      // 1. Calculate sum of movements per item for this store
      final result = await txn.rawQuery('''
        SELECT itemId, SUM(delta) as total
        FROM inventory_movements
        WHERE storeId = ? AND isDeleted = 0
        GROUP BY itemId
      ''', [storeId]);

      final Map<String, int> ledgerSums = {};
      for (var row in result) {
        final itemId = row['itemId'] as String?;
        if (itemId != null) {
          ledgerSums[itemId] = (row['total'] as num?)?.toInt() ?? 0;
        }
      }

      // 2. Fetch all inventory items (including current quantity & cost) for this store
      final storeItems = await txn.query(
        'inventory',
        columns: ['id', 'quantity', 'cost', 'deviceId'],
        where: 'storeId = ?',
        whereArgs: [storeId],
      );

      // 3. Clear existing cache_inventory_quantities for this store
      await txn.delete(
        'cache_inventory_quantities',
        where: 'storeId = ?',
        whereArgs: [storeId],
      );

      // 4. Batch update cache_inventory_quantities and inventory.quantity
      //    CRITICAL: Never overwrite a positive item quantity with 0 if no movements
      //    exist in the ledger for that item (e.g. after cloud pull or legacy item creation).
      final batch = txn.batch();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (final item in storeItems) {
        final itemId = item['id'] as String;
        final currentQty = (item['quantity'] as num?)?.toInt() ?? 0;
        final itemCost = (item['cost'] as num?)?.toDouble() ?? 0.0;
        final deviceId = (item['deviceId'] as String?) ?? 'system';

        int quantity;
        if (!ledgerSums.containsKey(itemId)) {
          // No ledger rows exist for this item yet -> preserve currentQty!
          quantity = currentQty;
          ledgerSums[itemId] = currentQty;
          if (currentQty > 0) {
            batch.insert(
              'inventory_movements',
              {
                'id': 'init_$itemId',
                'itemId': itemId,
                'storeId': storeId,
                'type': 'INITIAL_STOCK',
                'delta': currentQty,
                'unitCost': itemCost,
                'reason': 'Initial Stock Preserved',
                'orderId': null,
                'deviceId': deviceId,
                'operationId': 'init_$itemId',
                'createdAt': nowMs,
                'syncStatus': 'PENDING',
                'isDeleted': 0,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        } else {
          quantity = ledgerSums[itemId]!;
        }

        batch.insert('cache_inventory_quantities', {
          'itemId': itemId,
          'storeId': storeId,
          'quantity': quantity,
        });

        batch.update(
          'inventory',
          {'quantity': quantity},
          where: 'id = ?',
          whereArgs: [itemId],
        );
      }
      await batch.commit(noResult: true);

      // 5. Update Hive cache_inventory
      if (Hive.isBoxOpen('cache_inventory')) {
        final box = Hive.box('cache_inventory');
        for (final item in storeItems) {
          final itemId = item['id'] as String;
          final currentQty = (item['quantity'] as num?)?.toInt() ?? 0;
          final quantity = ledgerSums[itemId] ?? currentQty;
          final raw = box.get(itemId);
          if (raw != null && raw is Map) {
            final itemData = Map<String, dynamic>.from(raw);
            itemData['quantity'] = quantity;
            box.put(itemId, itemData);
          }
        }
      }

      debugPrint(
          '🔄 rebuildInventoryProjection: Rebuilt ${storeItems.length} items for store $storeId from ledger.');
      return ledgerSums;
    });
  }

  // ─── RECONCILIATION TOOLING ──────────────────────────────────

  /// Compares expected quantities (ledger sum) against actual quantities
  /// (inventory projection).
  ///
  /// Discrepancy handling:
  /// - Logs warning
  /// - Fires `InventoryDriftDetectedEvent`
  /// - If [autoRepair] is true: updates projections to match ledger
  /// - CRITICAL: Never modifies or overwrites the authoritative movement ledger!
  Future<ReconciliationReport> reconcileInventory(
    String storeId, {
    bool autoRepair = true,
  }) async {
    final db = await _dbHelper.database;
    final discrepancies = <InventoryDiscrepancy>[];
    int itemsChecked = 0;

    await db.transaction((txn) async {
      // 1. Calculate ledger sums
      final ledgerSums = await txn.rawQuery('''
        SELECT itemId, SUM(delta) as ledgerSum
        FROM inventory_movements
        WHERE storeId = ? AND isDeleted = 0
        GROUP BY itemId
      ''', [storeId]);

      final ledgerMap = <String, int>{};
      for (final row in ledgerSums) {
        final itemId = row['itemId'] as String?;
        if (itemId != null) {
          ledgerMap[itemId] = (row['ledgerSum'] as num?)?.toInt() ?? 0;
        }
      }

      // 2. Read current inventory projection
      final inventoryRows = await txn.query(
        'inventory',
        columns: ['id', 'quantity', 'cost', 'deviceId'],
        where: 'storeId = ?',
        whereArgs: [storeId],
      );

      itemsChecked = inventoryRows.length;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      for (final row in inventoryRows) {
        final itemId = row['id'] as String;
        final actualQty = (row['quantity'] as num?)?.toInt() ?? 0;

        // If no movements exist in the ledger for this item, preserve actualQty
        // and seed the missing INITIAL_STOCK movement instead of resetting stock to 0.
        if (!ledgerMap.containsKey(itemId)) {
          if (actualQty > 0) {
            await txn.insert(
              'inventory_movements',
              {
                'id': 'init_$itemId',
                'itemId': itemId,
                'storeId': storeId,
                'type': 'INITIAL_STOCK',
                'delta': actualQty,
                'unitCost': (row['cost'] as num?)?.toDouble() ?? 0.0,
                'reason': 'Initial Stock Preserved',
                'orderId': null,
                'deviceId': (row['deviceId'] as String?) ?? 'system',
                'operationId': 'init_$itemId',
                'createdAt': nowMs,
                'syncStatus': 'PENDING',
                'isDeleted': 0,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
            ledgerMap[itemId] = actualQty;
          }
          continue;
        }

        final expectedQty = ledgerMap[itemId] ?? actualQty;

        if (actualQty != expectedQty) {
          final drift = actualQty - expectedQty;
          debugPrint(
              '⚠️ RECONCILIATION DRIFT: Item $itemId in store $storeId | Expected (ledger): $expectedQty, Actual (projection): $actualQty, Drift: $drift');

          // Log diagnostic event via EventBus
          EventBus.instance.fire(InventoryDriftDetectedEvent(
            storeId: storeId,
            itemId: itemId,
            expectedQuantity: expectedQty,
            actualQuantity: actualQty,
            drift: drift,
            autoRepaired: autoRepair,
          ));

          if (autoRepair) {
            // Repair projection in inventory table
            await txn.update(
              'inventory',
              {'quantity': expectedQty},
              where: 'id = ?',
              whereArgs: [itemId],
            );

            // Repair projection in cache_inventory_quantities
            await txn.insert(
              'cache_inventory_quantities',
              {
                'itemId': itemId,
                'storeId': storeId,
                'quantity': expectedQty,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            // Repair Hive cache
            _updateHiveCacheProjection(itemId, expectedQty);
          }

          discrepancies.add(InventoryDiscrepancy(
            itemId: itemId,
            storeId: storeId,
            expectedQuantity: expectedQty,
            actualQuantity: actualQty,
            drift: drift,
            repaired: autoRepair,
          ));
        }
      }
    });

    return ReconciliationReport(
      storeId: storeId,
      timestamp: DateTime.now(),
      itemsChecked: itemsChecked,
      discrepancies: discrepancies,
      autoRepaired: autoRepair,
    );
  }

  // ─── STOCK TRANSFERS & ORDER VOIDS ───────────────────────────

  /// Atomically transfers stock between two stores.
  ///
  /// Creates:
  /// 1. `TRANSFER_OUT` movement on source store (delta: -quantity)
  /// 2. `TRANSFER_IN` movement on destination store (delta: +quantity)
  Future<void> transferStock({
    required String sourceStoreId,
    required String destinationStoreId,
    required String sourceItemId,
    required String destinationItemId,
    required int quantity,
    required String deviceId,
    String? reason,
    String? transferId,
    NegativeStockPolicy? sourcePolicy,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Transfer quantity must be greater than zero.');
    }
    if (sourceStoreId == destinationStoreId &&
        sourceItemId == destinationItemId) {
      throw ArgumentError(
          'Source and destination item/store must not be identical.');
    }

    final id = transferId ?? const Uuid().v4();
    final now = DateTime.now();
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Source Store: TRANSFER_OUT
      final outMovement = InventoryMovement(
        id: 'TX-OUT-$id',
        itemId: sourceItemId,
        storeId: sourceStoreId,
        type: MovementType.transferOut,
        delta: -quantity,
        reason: reason ?? 'Store Transfer to $destinationStoreId',
        deviceId: deviceId,
        operationId: 'xfer_out_$id',
        createdAt: now,
        syncStatus: 'PENDING',
      );

      await _insertMovementWithTxn(
        txn,
        outMovement,
        negativeStockPolicy: sourcePolicy ?? NegativeStockPolicy.block,
      );

      // 2. Destination Store: TRANSFER_IN
      final inMovement = InventoryMovement(
        id: 'TX-IN-$id',
        itemId: destinationItemId,
        storeId: destinationStoreId,
        type: MovementType.transferIn,
        delta: quantity,
        reason: reason ?? 'Store Transfer from $sourceStoreId',
        deviceId: deviceId,
        operationId: 'xfer_in_$id',
        createdAt: now,
        syncStatus: 'PENDING',
      );

      await _insertMovementWithTxn(
        txn,
        inMovement,
        negativeStockPolicy: NegativeStockPolicy.allow,
      );
    });
  }

  /// Reverses all stock deductions from an order by creating `VOID_REVERSAL`
  /// movements for each sold item.
  Future<List<InventoryMovement>> voidOrderStock({
    required String orderId,
    required String storeId,
    required String deviceId,
    String? reason,
    String? voidedBy,
  }) async {
    final db = await _dbHelper.database;
    final createdMovements = <InventoryMovement>[];

    await db.transaction((txn) async {
      // Find all SALE movements for this order
      final saleRows = await txn.query(
        'inventory_movements',
        where: 'storeId = ? AND orderId = ? AND type = ? AND isDeleted = 0',
        whereArgs: [storeId, orderId, MovementType.sale],
      );

      final now = DateTime.now();
      for (final row in saleRows) {
        final itemId = row['itemId'] as String;
        final soldDelta = (row['delta'] as num).toInt();
        final reversalQty = soldDelta.abs();

        final reversalMovement = InventoryMovement(
          id: const Uuid().v4(),
          itemId: itemId,
          storeId: storeId,
          type: MovementType.voidReversal,
          delta: reversalQty,
          orderId: orderId,
          reason: reason ?? 'Order Void Reversal',
          deviceId: deviceId,
          operationId: 'void_${orderId}_$itemId',
          createdAt: now,
          syncStatus: 'PENDING',
        );

        await _insertMovementWithTxn(
          txn,
          reversalMovement,
          negativeStockPolicy: NegativeStockPolicy.allow,
        );

        createdMovements.add(reversalMovement);
      }

      // Update order status to VOID in orders table
      await txn.update(
        'orders',
        {
          'status': 'VOID',
          'syncStatus': 'PENDING',
          'updatedAt': now.toIso8601String(),
          'voidedAt': now.toIso8601String(),
          'voidedBy': voidedBy,
          'voidReason': reason,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
    });

    return createdMovements;
  }

  // ─── QUERY HELPERS ───────────────────────────────────────────

  /// Get movements by item
  Future<List<InventoryMovement>> getMovementsByItem(String itemId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'inventory_movements',
      where: 'itemId = ? AND isDeleted = 0',
      whereArgs: [itemId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => InventoryMovement.fromSql(map)).toList();
  }

  /// Get movements by store
  Future<List<InventoryMovement>> getMovementsByStore(String storeId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'inventory_movements',
      where: 'storeId = ? AND isDeleted = 0',
      whereArgs: [storeId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => InventoryMovement.fromSql(map)).toList();
  }

  /// Get movements by type
  Future<List<InventoryMovement>> getMovementsByType(
      String? storeId, String type) async {
    final db = await _dbHelper.database;
    String sql =
        'SELECT * FROM inventory_movements WHERE type = ? AND isDeleted = 0';
    List<dynamic> args = [type];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    sql += ' ORDER BY createdAt DESC';
    final maps = await db.rawQuery(sql, args);
    return maps.map((map) => InventoryMovement.fromSql(map)).toList();
  }

  /// Get movements by order
  Future<List<InventoryMovement>> getMovementsByOrder(String orderId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'inventory_movements',
      where: 'orderId = ? AND isDeleted = 0',
      whereArgs: [orderId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => InventoryMovement.fromSql(map)).toList();
  }

  /// Get pending movements for cloud push
  Future<List<InventoryMovement>> getPendingMovements() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'inventory_movements',
      where: 'syncStatus = ? AND isDeleted = 0',
      whereArgs: ['PENDING'],
      orderBy: 'createdAt ASC',
    );
    return maps.map((map) => InventoryMovement.fromSql(map)).toList();
  }

  /// Total delta of pending movements
  Future<int> getPendingDelta(String itemId, {String? storeId}) async {
    final db = await _dbHelper.database;
    String sql =
        'SELECT SUM(delta) as total FROM inventory_movements WHERE itemId = ? AND syncStatus = ? AND isDeleted = 0';
    List<dynamic> args = [itemId, 'PENDING'];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    final result = await db.rawQuery(sql, args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Mark movement as synced
  Future<void> markAsSynced(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'inventory_movements',
      {
        'syncStatus': 'CONFIRMED',
        'syncedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Total count of movements in ledger (optionally filtered by store)
  Future<int> getMovementCount(String? storeId) async {
    final db = await _dbHelper.database;
    String sql =
        'SELECT COUNT(*) as count FROM inventory_movements WHERE isDeleted = 0';
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    final result = await db.rawQuery(sql, args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Total stock valuation
  Future<double> getStockValue(String? storeId) async {
    final db = await _dbHelper.database;
    String sql =
        "SELECT SUM(delta * COALESCE(unitCost, cost, 0)) as value FROM inventory_movements WHERE type IN ('PURCHASE', 'INITIAL_STOCK') AND isDeleted = 0";
    List<dynamic> args = [];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.add(storeId);
    }
    final result = await db.rawQuery(sql, args);
    return (result.first['value'] as num?)?.toDouble() ?? 0.0;
  }

  /// Clear all movements (for test teardowns only)
  @visibleForTesting
  Future<void> clearAll() async {
    final db = await _dbHelper.database;
    await db.delete('inventory_movements');
    await db.delete('cache_inventory_quantities');
  }

  /// Delete movements by item
  Future<void> deleteMovementsByItem(String itemId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'inventory_movements',
      where: 'itemId = ?',
      whereArgs: [itemId],
    );
  }
}
