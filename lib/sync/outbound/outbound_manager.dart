import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/services/firestore_helper.dart';
import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/sync/outbox/outbox_operation.dart';
import 'package:biztonic_pos/sync/outbox/outbox_store.dart';
import '../registry/sync_collection_registry.dart';

/// Manages the outbound sync queue — pushing local changes to Firestore
/// using an authoritative, crash-resilient Outbox architecture.
class OutboundManager {
  final Box? Function() getQueueBox;
  final Box? Function() getFailedQueueBox;
  final String? Function() getActiveStoreId;
  final String? Function() getUserId;
  final String? Function() getDeviceId;
  final Repository Function() getRepository;
  final Future<bool> Function() checkConnectivity;
  final Future<void> Function(String message, {bool isError}) logEvent;

  late final OutboxStore outboxStore;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  // Batch configuration: 25 items per Firestore batch (safe below 500 limit)
  static const int batchSize = 25;

  OutboundManager({
    required this.getQueueBox,
    required this.getFailedQueueBox,
    required this.getActiveStoreId,
    required this.getUserId,
    required this.getDeviceId,
    required this.getRepository,
    required this.checkConnectivity,
    required this.logEvent,
    OutboxStore? store,
  }) {
    outboxStore = store ??
        OutboxStore(
          getQueueBox: getQueueBox,
          getFailedQueueBox: getFailedQueueBox,
          getRepository: getRepository,
        );
  }

  /// Recovers any in-flight operations left over from an app kill or crash.
  Future<void> recoverStaleOperations() async {
    await outboxStore.recoverStaleInFlight();
  }

  /// Queue an operation for outbound sync.
  Future<String> queueOperation({
    required String collection,
    required String docId,
    required String action,
    required Map<String, dynamic> payload,
    String? operationId,
    int? baseVersion,
    int? newVersion,
  }) async {
    final storeId = getActiveStoreId() ?? payload['storeId']?.toString() ?? '';
    final userId = getUserId() ?? payload['userId']?.toString() ?? 'SYSTEM';
    final deviceId =
        getDeviceId() ?? payload['deviceId']?.toString() ?? 'LOCAL';

    final op = OutboxOperation(
      operationId: operationId,
      storeId: storeId,
      userId: userId,
      deviceId: deviceId,
      collection: collection,
      entityId: docId,
      operation: action.toUpperCase(),
      payload: payload,
      baseVersion: baseVersion ??
          (payload['baseVersion'] as num?)?.toInt() ??
          (payload['version'] as num?)?.toInt() ??
          1,
      newVersion: newVersion ??
          (payload['newVersion'] as num?)?.toInt() ??
          ((payload['version'] as num?)?.toInt() ?? 1),
    );

    final id = await outboxStore.enqueue(op);
    debugPrint(
        '📤 [OutboundManager] Queued: ${op.operation} on $collection/$docId (opId: $id)');
    return id;
  }

  /// Process pending items in the outbound queue.
  Future<void> processQueue({bool forceManual = false}) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final isConnected = await checkConnectivity();
      if (!isConnected) {
        debugPrint('📤 [OutboundManager] Offline — skipping outbound sync');
        return;
      }

      final storeId = getActiveStoreId();
      if (storeId == null || storeId.isEmpty) {
        debugPrint('📤 [OutboundManager] No active storeId — skipping queue');
        return;
      }

      // 1. Fetch ready operations (respecting exponential backoff)
      final readyOps = await outboxStore.getReadyOperations(
          storeId: storeId, limit: batchSize * 2);
      if (readyOps.isEmpty) return;

      debugPrint(
          '📤 [OutboundManager] Processing ${readyOps.length} ready outbox operations for store $storeId');

      // 2. Process in chunks
      for (var i = 0; i < readyOps.length; i += batchSize) {
        final chunk = readyOps.sublist(
            i,
            (i + batchSize < readyOps.length)
                ? i + batchSize
                : readyOps.length);
        await _processBatch(chunk, storeId);
      }

      EventBus.instance.fire(SyncCompletedEvent(
        storeId: storeId,
        itemsPushed: readyOps.length,
      ));
    } catch (e) {
      debugPrint('📤 [OutboundManager] Error processing queue: $e');
      await logEvent('Outbound sync error: $e', isError: true);
    } finally {
      _isSyncing = false;
    }
  }

  /// Processes a single batch of operations.
  Future<void> _processBatch(
      List<OutboxOperation> operations, String storeId) async {
    if (operations.isEmpty) return;

    // Mark as IN_FLIGHT
    final opIds = operations.map((o) => o.operationId).toList();
    await outboxStore.markInFlight(opIds);

    // Try batch commit first
    final batch = FirebaseFirestore.instance.batch();
    final validOps = <OutboxOperation>[];

    for (var op in operations) {
      // Cross-store boundary check
      if (op.storeId.isNotEmpty && op.storeId != storeId) {
        debugPrint(
            '🚫 [OutboundManager] Cross-store violation: op store ${op.storeId} != active $storeId');
        await outboxStore.markDeadLetter(
            op.operationId, 'Cross-store tenant violation');
        continue;
      }

      final payload = Map<String, dynamic>.from(op.payload);
      payload['storeId'] = storeId;
      payload['deviceId'] = payload['deviceId'] ?? op.deviceId;
      payload['updatedAt'] =
          payload['updatedAt'] ?? DateTime.now().toIso8601String();
      payload['version'] = op.newVersion;

      final ref = FirestoreHelper.storeDoc(storeId, op.collection, op.entityId);

      switch (op.operation) {
        case 'CREATE':
        case 'SET':
        case 'UPDATE':
          batch.set(ref, payload, SetOptions(merge: true));
          break;
        case 'DELETE':
          // Soft-delete tombstone write
          payload['isDeleted'] = true;
          payload['deletedAt'] =
              payload['deletedAt'] ?? DateTime.now().toIso8601String();
          payload['deletedBy'] = op.userId;
          batch.set(ref, payload, SetOptions(merge: true));
          break;
      }

      validOps.add(op);
    }

    if (validOps.isEmpty) return;

    try {
      await batch.commit();

      // Post-commit: mark operations PUSHED and update local entities
      final repo = getRepository();
      for (var op in validOps) {
        await outboxStore.markPushed(op.operationId, auditMetadata: {
          'batchCommitted': true,
          'committedAt': DateTime.now().toIso8601String(),
        });

        // Update local entity sync status
        if (!kIsWeb) {
          try {
            await repo.markAsPushed(op.collection, op.entityId);
          } catch (_) {}
        }
        await _markHiveAsPushed(op.collection, op.entityId, storeId);
      }

      debugPrint(
          '📤 [OutboundManager] Batch committed ${validOps.length} operations successfully');
    } catch (e) {
      debugPrint(
          '📤 [OutboundManager] Batch commit failed: $e. Falling back to individual operations...');
      await logEvent(
          'Batch commit failed: $e. Falling back to single-item commits.',
          isError: true);

      // FALLBACK: Do not assume all failed. Commit individually to isolate errors.
      for (var op in validOps) {
        await _trySingleItemCommit(op, storeId);
      }
    }
  }

  /// Fallback single-operation commit with granular error handling and exponential backoff.
  Future<void> _trySingleItemCommit(OutboxOperation op, String storeId) async {
    try {
      final payload = Map<String, dynamic>.from(op.payload);
      payload['storeId'] = storeId;
      payload['deviceId'] = payload['deviceId'] ?? op.deviceId;
      payload['updatedAt'] =
          payload['updatedAt'] ?? DateTime.now().toIso8601String();
      payload['version'] = op.newVersion;

      final ref = FirestoreHelper.storeDoc(storeId, op.collection, op.entityId);

      switch (op.operation) {
        case 'CREATE':
        case 'SET':
        case 'UPDATE':
          await ref.set(payload, SetOptions(merge: true));
          break;
        case 'DELETE':
          payload['isDeleted'] = true;
          payload['deletedAt'] =
              payload['deletedAt'] ?? DateTime.now().toIso8601String();
          payload['deletedBy'] = op.userId;
          await ref.set(payload, SetOptions(merge: true));
          break;
      }

      // Mark single item as PUSHED
      await outboxStore.markPushed(op.operationId, auditMetadata: {
        'singleCommitted': true,
        'committedAt': DateTime.now().toIso8601String(),
      });

      if (!kIsWeb) {
        try {
          await getRepository().markAsPushed(op.collection, op.entityId);
        } catch (_) {}
      }
      await _markHiveAsPushed(op.collection, op.entityId, storeId);

      debugPrint(
          '📤 [OutboundManager] Single commit succeeded: ${op.collection}/${op.entityId}');
    } catch (e) {
      debugPrint(
          '❌ [OutboundManager] Single commit failed for ${op.collection}/${op.entityId}: $e');
      final isFatal = OutboxStore.isFatalError(e);
      await outboxStore.markFailed(op.operationId, e.toString(),
          isFatal: isFatal);
      await logEvent('Commit failed for ${op.collection}/${op.entityId}: $e',
          isError: true);
    }
  }

  /// Helper to update sync status in Hive cache.
  Future<void> _markHiveAsPushed(
      String collection, String docId, String storeId) async {
    final boxName =
        SyncCollectionRegistry.getBoxName(collection, storeId: storeId);
    if (boxName != null) {
      try {
        final box = await Hive.openBox(boxName);
        final data = box.get(docId);
        if (data is Map) {
          final updated = Map<String, dynamic>.from(data);
          updated['syncStatus'] = 'PUSHED';
          updated['syncedAt'] = DateTime.now().toIso8601String();
          await box.put(docId, updated);
        }
      } catch (_) {}
    }
  }

  /// Direct write to Firestore for Web platform.
  Future<void> performWebDirectWrite({
    required String collection,
    required String docId,
    required String action,
    required Map<String, dynamic> data,
  }) async {
    try {
      final storeId = getActiveStoreId();
      if (storeId == null) return;

      data['storeId'] = data['storeId'] ?? storeId;
      data['deviceId'] = data['deviceId'] ?? getDeviceId();

      final ref = FirestoreHelper.storeDoc(storeId, collection, docId);

      switch (action.toUpperCase()) {
        case 'CREATE':
        case 'SET':
        case 'UPDATE':
          await ref.set(data, SetOptions(merge: true));
          break;
        case 'DELETE':
          data['isDeleted'] = true;
          data['deletedAt'] = DateTime.now().toIso8601String();
          await ref.set(data, SetOptions(merge: true));
          break;
      }
      debugPrint('🌐 [OutboundManager] Web direct write: $collection/$docId');
    } catch (e) {
      debugPrint('🌐 [OutboundManager] Web direct write failed: $e');
    }
  }

  /// Get queue statistics for diagnostics.
  Map<String, int> getQueueStats({String? storeId}) {
    return outboxStore.getOutboxStats(storeId: storeId ?? getActiveStoreId());
  }

  /// Reset retry counts on all failed/dead-letter items.
  Future<int> resetRetries({String? storeId}) async {
    return outboxStore.retryAllDeadLetter(
        storeId: storeId ?? getActiveStoreId());
  }
}
