import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'inventory_movement_repository.dart';
import '../features/inventory/domain/entities/inventory_movement.dart';
import '../features/inventory/domain/policies/inventory_policy.dart';
import '../core/diagnostics/diagnostics_models.dart';
import '../core/diagnostics/diagnostics_service.dart';

Map<String, dynamic> _decodeJson(String json) =>
    jsonDecode(json) as Map<String, dynamic>;

/// Status of transaction resolution during recovery.
enum TransactionResolutionStatus {
  committed,
  rolledBack,
  partiallyAppliedRecovered,
  failed,
}

extension TransactionResolutionStatusExt on TransactionResolutionStatus {
  String get wireName {
    switch (this) {
      case TransactionResolutionStatus.committed:
        return 'COMMITTED';
      case TransactionResolutionStatus.rolledBack:
        return 'ROLLED_BACK';
      case TransactionResolutionStatus.partiallyAppliedRecovered:
        return 'PARTIALLY_APPLIED_RECOVERED';
      case TransactionResolutionStatus.failed:
        return 'FAILED';
    }
  }
}

/// Structured reconciliation report produced for each evaluated transaction.
class TransactionReconciliationReport {
  final String txId;
  final String storeId;
  final DateTime evaluatedAt;
  final TransactionResolutionStatus status;
  final bool orderExisted;
  final int itemsFound;
  final int itemsExpected;
  final bool eventExisted;
  final int movementsFound;
  final int movementsExpected;
  final bool counterIncremented;
  final List<String> actionsTaken;
  final String? error;

  TransactionReconciliationReport({
    required this.txId,
    required this.storeId,
    required this.evaluatedAt,
    required this.status,
    required this.orderExisted,
    required this.itemsFound,
    required this.itemsExpected,
    required this.eventExisted,
    required this.movementsFound,
    required this.movementsExpected,
    required this.counterIncremented,
    required this.actionsTaken,
    this.error,
  });

  bool get isCommitted => status == TransactionResolutionStatus.committed;
  bool get isRolledBack => status == TransactionResolutionStatus.rolledBack;
  bool get isRecovered =>
      status == TransactionResolutionStatus.partiallyAppliedRecovered;
  bool get isFailed => status == TransactionResolutionStatus.failed;

  Map<String, dynamic> toMap() => {
        'txId': txId,
        'storeId': storeId,
        'evaluatedAt': evaluatedAt.toIso8601String(),
        'status': status.wireName,
        'orderExisted': orderExisted,
        'itemsFound': itemsFound,
        'itemsExpected': itemsExpected,
        'eventExisted': eventExisted,
        'movementsFound': movementsFound,
        'movementsExpected': movementsExpected,
        'counterIncremented': counterIncremented,
        'actionsTaken': actionsTaken,
        'error': error,
      };

  @override
  String toString() =>
      'TransactionReconciliationReport(txId: $txId, status: ${status.name}, actions: ${actionsTaken.length})';
}

class RecoveryService {
  final DatabaseHelper _dbHelper;
  final InventoryMovementRepository _movementRepo;

  RecoveryService({
    DatabaseHelper? dbHelper,
    InventoryMovementRepository? movementRepo,
  })  : _dbHelper = dbHelper ?? DatabaseHelper(),
        _movementRepo = movementRepo ?? InventoryMovementRepository();

  final List<TransactionReconciliationReport> _reports = [];
  List<TransactionReconciliationReport> get reports =>
      List.unmodifiable(_reports);

  /// Scans the transaction_journal for PENDING records and resolves them deterministically.
  ///
  /// Guarantees:
  /// 1. Idempotency: Never duplicates an order, order items, inventory movement, counter, or ledger event.
  /// 2. Completeness: Does not consider "order exists" alone sufficient if movements or items are missing.
  /// 3. Crash resilience: Handles corrupted JSON payloads without crashing the host process.
  ///
  /// Returns a list of unresolved records requiring operator attention (e.g. rolled back or failed).
  Future<List<Map<String, dynamic>>> scanAndRecover({
    bool autoReconcilePartials = true,
  }) async {
    final reports = await scanAndRecoverReports(
      autoReconcilePartials: autoReconcilePartials,
    );

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> unresolved = [];

    for (var report in reports) {
      if (report.status == TransactionResolutionStatus.rolledBack ||
          report.status == TransactionResolutionStatus.failed) {
        final rows = await db.query(
          'transaction_journal',
          where: 'id = ?',
          whereArgs: [report.txId],
        );
        if (rows.isNotEmpty) {
          final row = rows.first;
          unresolved.add({
            'txId': report.txId,
            'storeId': report.storeId,
            'status': report.status.wireName,
            'raw': row['operations'] as String? ?? '',
            'createdAt': row['createdAt'],
            'report': report.toMap(),
          });
        }
      }
    }

    return unresolved;
  }

  /// Scans all PENDING journal records and returns structured reconciliation reports.
  Future<List<TransactionReconciliationReport>> scanAndRecoverReports({
    bool autoReconcilePartials = true,
  }) async {
    return await DiagnosticsService().trace<List<TransactionReconciliationReport>>(
      subsystem: DiagnosticSubsystem.recovery,
      operationId: 'recovery_scan_journal_${DateTime.now().millisecondsSinceEpoch}',
      actionName: 'Scan & Reconcile Transaction Journal',
      operation: () => _scanAndRecoverReportsInternal(autoReconcilePartials: autoReconcilePartials),
    );
  }

  Future<List<TransactionReconciliationReport>> _scanAndRecoverReportsInternal({
    bool autoReconcilePartials = true,
  }) async {
    final db = await _dbHelper.database;
    final pendingRecords = await db.query(
      'transaction_journal',
      where: 'status = ?',
      whereArgs: ['PENDING'],
      orderBy: 'createdAt ASC',
    );

    final List<TransactionReconciliationReport> results = [];

    for (var record in pendingRecords) {
      final txId = record['id'] as String;
      final storeId = (record['storeId'] as String?) ?? '';
      final operationsJson = record['operations'] as String?;

      if (operationsJson == null || operationsJson.trim().isEmpty) {
        await _markStatus(db, txId, 'FAILED',
            error: 'Empty operations payload');
        final report = TransactionReconciliationReport(
          txId: txId,
          storeId: storeId,
          evaluatedAt: DateTime.now(),
          status: TransactionResolutionStatus.failed,
          orderExisted: false,
          itemsFound: 0,
          itemsExpected: 0,
          eventExisted: false,
          movementsFound: 0,
          movementsExpected: 0,
          counterIncremented: false,
          actionsTaken: ['Marked FAILED due to empty operations payload'],
          error: 'Empty operations payload',
        );
        results.add(report);
        _reports.add(report);
        continue;
      }

      final report = await _reconcileRecord(
        db,
        txId,
        storeId,
        operationsJson,
        autoReconcilePartials: autoReconcilePartials,
      );

      results.add(report);
      _reports.add(report);
    }

    return results;
  }

  /// Evaluates and reconciles a single transaction by ID.
  Future<TransactionReconciliationReport> reconcileTransaction(
    String txId, {
    bool autoReconcile = true,
  }) async {
    final db = await _dbHelper.database;
    final records = await db.query(
      'transaction_journal',
      where: 'id = ?',
      whereArgs: [txId],
    );

    if (records.isEmpty) {
      throw ArgumentError('Transaction $txId not found in transaction_journal');
    }

    final record = records.first;
    final storeId = (record['storeId'] as String?) ?? '';
    final operationsJson = record['operations'] as String? ?? '';

    final report = await _reconcileRecord(
      db,
      txId,
      storeId,
      operationsJson,
      autoReconcilePartials: autoReconcile,
    );

    _reports.add(report);
    return report;
  }

  Future<TransactionReconciliationReport> _reconcileRecord(
    Database db,
    String txId,
    String storeId,
    String operationsJson, {
    required bool autoReconcilePartials,
  }) async {
    Map<String, dynamic> payload;
    try {
      payload = await compute(_decodeJson, operationsJson);
    } catch (e) {
      debugPrint('RecoveryService: Corrupt JSON payload for TX $txId: $e');
      await _markStatus(db, txId, 'FAILED', error: 'Corrupted JSON: $e');
      return TransactionReconciliationReport(
        txId: txId,
        storeId: storeId,
        evaluatedAt: DateTime.now(),
        status: TransactionResolutionStatus.failed,
        orderExisted: false,
        itemsFound: 0,
        itemsExpected: 0,
        eventExisted: false,
        movementsFound: 0,
        movementsExpected: 0,
        counterIncremented: false,
        actionsTaken: ['Marked FAILED due to unparseable JSON'],
        error: 'Corrupted JSON: $e',
      );
    }

    final orderMap = payload['order'] as Map<String, dynamic>?;
    final orderItems = (payload['orderItems'] as List<dynamic>?) ?? [];
    final eventMap = payload['event'] as Map<String, dynamic>?;
    final movementsList = (payload['movements'] as List<dynamic>?) ?? [];
    final yearMonth = (payload['yearMonth'] as String?) ?? '';

    if (orderMap == null || !orderMap.containsKey('id')) {
      await _markStatus(db, txId, 'FAILED',
          error: 'Missing order payload or ID');
      return TransactionReconciliationReport(
        txId: txId,
        storeId: storeId,
        evaluatedAt: DateTime.now(),
        status: TransactionResolutionStatus.failed,
        orderExisted: false,
        itemsFound: 0,
        itemsExpected: orderItems.length,
        eventExisted: false,
        movementsFound: 0,
        movementsExpected: movementsList.length,
        counterIncremented: false,
        actionsTaken: ['Marked FAILED: missing order payload'],
        error: 'Missing order payload',
      );
    }

    final orderId = orderMap['id'] as String;
    final resolvedStoreId = (orderMap['storeId'] as String?) ?? storeId;

    // ─── 1. Deep Database State Inspection ─────────────────────────
    final orderRows = await db.query(
      'orders',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [orderId],
    );
    final bool orderExisted = orderRows.isNotEmpty;

    final existingItems = await db.query(
      'order_items',
      where: 'orderId = ?',
      whereArgs: [orderId],
    );
    final int itemsFound = existingItems.length;
    final int itemsExpected = orderItems.length;

    bool eventExisted = false;
    final eventId = eventMap?['id'] as String?;
    if (eventId != null) {
      final eventRows = await db.query(
        'business_events',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [eventId],
      );
      eventExisted = eventRows.isNotEmpty;
    }

    int movementsFound = 0;
    for (var m in movementsList) {
      if (m is Map<String, dynamic>) {
        final mId = m['id'] as String?;
        final opId = m['operationId'] as String?;
        final existingM = await db.query(
          'inventory_movements',
          columns: ['id'],
          where:
              'id = ? OR (storeId = ? AND operationId = ? AND operationId IS NOT NULL)',
          whereArgs: [mId, resolvedStoreId, opId],
          limit: 1,
        );
        if (existingM.isNotEmpty) {
          movementsFound++;
        }
      }
    }
    final int movementsExpected = movementsList.length;

    final List<String> actions = [];
    bool counterIncremented = false;

    // ─── 2. State Classification ──────────────────────────────────
    final bool allEffectsExist = orderExisted &&
        (itemsExpected == 0 || itemsFound >= itemsExpected) &&
        (eventMap == null || eventExisted) &&
        (movementsExpected == 0 || movementsFound >= movementsExpected);

    final bool noEffectsExist = !orderExisted &&
        itemsFound == 0 &&
        !eventExisted &&
        movementsFound == 0;

    // ─── Case 1: COMMITTED (All effects exist in database) ─────────
    if (allEffectsExist) {
      debugPrint('🛡️ RecoveryService: TX $txId committed; updating journal.');
      await _markStatus(db, txId, 'COMPLETED');
      actions.add(
          'Verified all transaction effects committed. Marked journal COMPLETED.');
      return TransactionReconciliationReport(
        txId: txId,
        storeId: resolvedStoreId,
        evaluatedAt: DateTime.now(),
        status: TransactionResolutionStatus.committed,
        orderExisted: true,
        itemsFound: itemsFound,
        itemsExpected: itemsExpected,
        eventExisted: eventExisted,
        movementsFound: movementsFound,
        movementsExpected: movementsExpected,
        counterIncremented: false,
        actionsTaken: actions,
      );
    }

    // ─── Case 2: ROLLED_BACK (Zero effects exist) ─────────────────
    if (noEffectsExist) {
      debugPrint('🛡️ RecoveryService: TX $txId was rolled back.');
      await _markStatus(db, txId, 'ROLLED_BACK');
      actions.add(
          'Verified clean rollback in SQLite. Marked journal ROLLED_BACK.');
      return TransactionReconciliationReport(
        txId: txId,
        storeId: resolvedStoreId,
        evaluatedAt: DateTime.now(),
        status: TransactionResolutionStatus.rolledBack,
        orderExisted: false,
        itemsFound: 0,
        itemsExpected: itemsExpected,
        eventExisted: false,
        movementsFound: 0,
        movementsExpected: movementsExpected,
        counterIncremented: false,
        actionsTaken: actions,
      );
    }

    // ─── Case 3: PARTIALLY APPLIED (Idempotent Recovery) ──────────
    debugPrint(
        '🛡️ RecoveryService: TX $txId is PARTIALLY APPLIED (order: $orderExisted, items: $itemsFound/$itemsExpected, event: $eventExisted, movements: $movementsFound/$movementsExpected)');

    if (!autoReconcilePartials) {
      actions.add('Partially applied state detected. Auto-reconcile disabled.');
      return TransactionReconciliationReport(
        txId: txId,
        storeId: resolvedStoreId,
        evaluatedAt: DateTime.now(),
        status: TransactionResolutionStatus.partiallyAppliedRecovered,
        orderExisted: orderExisted,
        itemsFound: itemsFound,
        itemsExpected: itemsExpected,
        eventExisted: eventExisted,
        movementsFound: movementsFound,
        movementsExpected: movementsExpected,
        counterIncremented: false,
        actionsTaken: actions,
      );
    }

    // Execute Idempotent Atomic Completion
    await db.transaction((txn) async {
      // Step A: Insert Order if missing
      if (!orderExisted) {
        await txn.insert(
          'orders',
          orderMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        actions.add('Inserted missing order ($orderId)');

        // Increment monthly order counter ONLY if order was missing
        if (resolvedStoreId.isNotEmpty && yearMonth.isNotEmpty) {
          final counterResults = await txn.query(
            'monthly_order_counter',
            where: 'storeId = ? AND yearMonth = ?',
            whereArgs: [resolvedStoreId, yearMonth],
          );

          if (counterResults.isEmpty) {
            await txn.insert('monthly_order_counter', {
              'storeId': resolvedStoreId,
              'yearMonth': yearMonth,
              'count': 1,
            });
          } else {
            final currentCount = counterResults.first['count'] as int;
            await txn.update(
              'monthly_order_counter',
              {'count': currentCount + 1},
              where: 'storeId = ? AND yearMonth = ?',
              whereArgs: [resolvedStoreId, yearMonth],
            );
          }
          counterIncremented = true;
          actions.add('Incremented monthly_order_counter ($yearMonth)');
        }
      } else {
        actions.add(
            'Order already present ($orderId); skipped counter increment to prevent duplication.');
      }

      // Step B: Reconcile Order Items (avoid duplication)
      if (itemsFound < itemsExpected) {
        // Clean out incomplete item list and write canonical items
        await txn.delete(
          'order_items',
          where: 'orderId = ?',
          whereArgs: [orderId],
        );
        for (var item in orderItems) {
          if (item is Map<String, dynamic>) {
            await txn.insert(
              'order_items',
              item,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
        actions.add(
            'Synchronized complete order items list ($itemsExpected items)');
      } else {
        actions.add('Order items already complete ($itemsFound items)');
      }

      // Step C: Reconcile Business Event
      if (!eventExisted && eventMap != null) {
        await txn.insert(
          'business_events',
          eventMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        actions.add('Inserted missing business event (${eventMap['id']})');
      }

      // Step D: Reconcile Inventory Movements
      for (var movementMap in movementsList) {
        if (movementMap is Map<String, dynamic>) {
          final mId = movementMap['id'] as String;
          final opId = movementMap['operationId'] as String?;

          final existingM = await txn.query(
            'inventory_movements',
            columns: ['id'],
            where:
                'id = ? OR (storeId = ? AND operationId = ? AND operationId IS NOT NULL)',
            whereArgs: [mId, resolvedStoreId, opId],
            limit: 1,
          );

          if (existingM.isEmpty) {
            final movement = InventoryMovement.fromMap(
              movementMap,
              mId,
            );
            await _movementRepo.insertMovement(
              movement,
              txn: txn,
              negativeStockPolicy: NegativeStockPolicy.allowWithWarning,
            );
            actions.add(
                'Inserted missing inventory movement ($mId for ${movement.itemId})');
          } else {
            actions.add(
                'Movement already committed ($mId); skipped to prevent inventory drift');
          }
        }
      }

      // Step E: Reconcile Outbox Operations
      final outboxList = (payload['outboxOperations'] as List<dynamic>?) ?? [];
      for (var opMap in outboxList) {
        if (opMap is Map<String, dynamic>) {
          await txn.insert(
            'outbox_operations',
            opMap,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          actions.add('Reconciled outbox operation for cloud push');
        }
      }

      // Step F: Mark Journal Completed
      await txn.update(
        'transaction_journal',
        {
          'status': 'COMPLETED',
          'completedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [txId],
      );
      actions.add('Marked transaction_journal record as COMPLETED');
    });

    return TransactionReconciliationReport(
      txId: txId,
      storeId: resolvedStoreId,
      evaluatedAt: DateTime.now(),
      status: TransactionResolutionStatus.partiallyAppliedRecovered,
      orderExisted: orderExisted,
      itemsFound: itemsFound,
      itemsExpected: itemsExpected,
      eventExisted: eventExisted,
      movementsFound: movementsFound,
      movementsExpected: movementsExpected,
      counterIncremented: counterIncremented,
      actionsTaken: actions,
    );
  }

  Future<void> _markStatus(
    Database db,
    String txId,
    String status, {
    String? error,
  }) async {
    final values = <String, dynamic>{
      'status': status,
      'completedAt': DateTime.now().toIso8601String(),
    };
    if (error != null) {
      values['error'] = error;
    }
    await db.update(
      'transaction_journal',
      values,
      where: 'id = ?',
      whereArgs: [txId],
    );
  }

  Future<void> discardTransaction(String txId) async {
    final db = await _dbHelper.database;
    await _markStatus(db, txId, 'DISCARDED');
  }
}
