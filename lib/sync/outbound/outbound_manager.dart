import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/services/firestore_helper.dart';
import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';
import 'package:biztonic_pos/services/repository.dart';

/// Manages the outbound sync queue — pushing local changes to Firestore.
///
/// Extracted from SyncService._processOutboundQueue, _tryBatchCommit,
/// _trySingleItemCommit, and queueOperation.
class OutboundManager {
  final Box? Function() getQueueBox;
  final Box? Function() getFailedQueueBox;
  final String? Function() getActiveStoreId;
  final String? Function() getUserId;
  final String? Function() getDeviceId;
  final Repository Function() getRepository;
  final Future<bool> Function() checkConnectivity;
  final Future<void> Function(String message, {bool isError}) logEvent;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  // Retry configuration
  static const int maxRetries = 5;
  static const int batchSize = 20;

  OutboundManager({
    required this.getQueueBox,
    required this.getFailedQueueBox,
    required this.getActiveStoreId,
    required this.getUserId,
    required this.getDeviceId,
    required this.getRepository,
    required this.checkConnectivity,
    required this.logEvent,
  });

  /// Queue an operation for outbound sync.
  Future<void> queueOperation({
    required String collection,
    required String docId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final box = getQueueBox();
    if (box == null || !box.isOpen) return;

    // Use keys consistent with SyncService to avoid breaking existing data
    final key = '${collection}_$docId';
    final storeId = getActiveStoreId();
    final userId = getUserId();

    await box.put(key, {
      'collection': collection,
      'docId': docId,
      'type': action.toUpperCase(),
      'payload': payload,
      'activeStoreId': storeId,
      'userId': userId,
      'deviceId': getDeviceId(),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'retryCount': 0,
    });

    debugPrint('📤 [OutboundManager] Queued: $action on $collection/$docId');
  }

  /// Process all pending items in the outbound queue.
  Future<void> processQueue({bool forceManual = false}) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final isConnected = await checkConnectivity();
      if (!isConnected) {
        debugPrint('📤 [OutboundManager] Offline — skipping outbound sync');
        return;
      }

      final box = getQueueBox();
      if (box == null || !box.isOpen || box.isEmpty) return;

      final keys = box.keys.toList();
      final queueMap = box.toMap();

      // --- STALE ITEM CLEANUP ---
      final now = DateTime.now().millisecondsSinceEpoch;
      const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
      final List<dynamic> staleKeys = [];
      for (var key in keys) {
        final val = queueMap[key] as Map?;
        if (val == null) continue;
        final createdAt = val['createdAt'] as int? ?? now;
        final retryCount = (val['retryCount'] ?? 0) as int;
        if ((now - createdAt) > sevenDaysMs && retryCount > 3) {
          staleKeys.add(key);
        }
      }
      if (staleKeys.isNotEmpty) {
        debugPrint('🧹 [OutboundManager] Cleaning ${staleKeys.length} stale queue items (>7 days old)');
        for (var key in staleKeys) {
          await getFailedQueueBox()?.put(key, queueMap[key]);
        }
        await box.deleteAll(staleKeys);
        return;
      }

      debugPrint('📤 [OutboundManager] Processing ${keys.length} queued items');

      // Try batch commit first
      final batchSuccess = await _tryBatchCommit(keys, queueMap);

      if (!batchSuccess) {
        // Fall back to single-item commits
        for (var key in keys) {
          await _trySingleItemCommit(key, queueMap);
        }
      }

      final storeId = getActiveStoreId();
      if (storeId != null) {
        EventBus.instance.fire(SyncCompletedEvent(
          storeId: storeId,
          itemsPushed: keys.length,
        ));
      }
    } catch (e) {
      debugPrint('📤 [OutboundManager] Error: $e');
      await logEvent('Outbound sync error: $e', isError: true);
    } finally {
      _isSyncing = false;
    }
  }

  /// Attempt to commit all queued items in a Firestore batch.
  Future<bool> _tryBatchCommit(List<dynamic> keys, Map<dynamic, dynamic> queueMap) async {
    try {
      final storeId = getActiveStoreId();
      if (storeId == null || storeId.isEmpty) {
        debugPrint('📤 [OutboundManager] WARNING: No active storeId, skipping batch commit');
        return false;
      }

      final batch = FirebaseFirestore.instance.batch();
      final processedKeys = <dynamic>[];
      int batchCount = 0;

      for (var key in keys) {
        if (batchCount >= batchSize) break;

        final item = queueMap[key];
        if (item == null) continue;

        final collection = item['collection'] as String?;
        final docId = item['docId'] as String?;
        final type = item['type'] as String?;
        final payload = Map<String, dynamic>.from(item['payload'] ?? {});

        if (collection == null || docId == null || type == null) continue;

        // Inject storeId if missing (Legacy support)
        if (payload['storeId'] == null || payload['storeId'].toString().isEmpty) {
          payload['storeId'] = storeId;
        }
        payload['deviceId'] = payload['deviceId'] ?? getDeviceId();

        final ref = FirestoreHelper.storeDoc(storeId, collection, docId);

        switch (type) {
          case 'CREATE':
          case 'SET':
          case 'UPDATE':
            batch.set(ref, payload, SetOptions(merge: true));
            break;
          case 'DELETE':
            batch.delete(ref);
            break;
        }

        processedKeys.add(key);
        batchCount++;
      }

      if (processedKeys.isEmpty) return true;

      await batch.commit();

      // --- POST-COMMIT MARKING ---
      final repo = getRepository();
      final box = getQueueBox();
      
      for (var key in processedKeys) {
        final item = queueMap[key];
        final col = item['collection'] as String;
        final id = item['docId'] as String;

        // 1. Mark as PUSHED in SQLite
        if (!kIsWeb) {
          try { await repo.markAsPushed(col, id); } catch (_) {}
        }

        // 2. Mark as PUSHED in Hive Cache
        await _markHiveAsPushed(col, id);

        // 3. Remove from queue
        await box?.delete(key);
      }

      debugPrint('📤 [OutboundManager] Batch committed ${processedKeys.length} items');
      return true;
    } catch (e) {
      debugPrint('📤 [OutboundManager] Batch commit failed: $e');
      return false;
    }
  }

  /// Commit a single queued item (fallback when batch fails).
  Future<void> _trySingleItemCommit(dynamic key, Map<dynamic, dynamic> queueMap) async {
    final item = queueMap[key];
    if (item == null) return;

    final collection = item['collection'] as String?;
    final docId = item['docId'] as String?;
    final type = item['type'] as String?;
    final payload = Map<String, dynamic>.from(item['payload'] ?? {});
    final retryCount = (item['retryCount'] ?? 0) as int;
    final storeId = getActiveStoreId();

    if (collection == null || docId == null || type == null || storeId == null || storeId.isEmpty) return;

    try {
      // Inject storeId if missing
      if (payload['storeId'] == null || payload['storeId'].toString().isEmpty) {
        payload['storeId'] = storeId;
      }
      payload['deviceId'] = payload['deviceId'] ?? getDeviceId();

      final ref = FirestoreHelper.storeDoc(storeId, collection, docId);

      switch (type) {
        case 'CREATE':
        case 'SET':
        case 'UPDATE':
          await ref.set(payload, SetOptions(merge: true));
          break;
        case 'DELETE':
          await ref.delete();
          break;
      }

      await _markHiveAsPushed(collection, docId);
      if (!kIsWeb) {
        try { await getRepository().markAsPushed(collection, docId); } catch (_) {}
      }

      await getQueueBox()?.delete(key);
      debugPrint('📤 [OutboundManager] Single commit: $collection/$docId');
    } catch (e) {
      debugPrint('📤 [OutboundManager] Single commit failed: $e');

      if (retryCount >= maxRetries) {
        // Move to failed queue
        await getFailedQueueBox()?.put(key, {...item, 'failedAt': DateTime.now().toIso8601String()});
        await getQueueBox()?.delete(key);
        await logEvent('Moved to failed queue after $maxRetries retries: $collection/$docId', isError: true);
      } else {
        // Increment retry count
        await getQueueBox()?.put(key, {...item, 'retryCount': retryCount + 1});
      }
    }
  }

  /// Get queue statistics for diagnostics.
  Map<String, int> getQueueStats() {
    final box = getQueueBox();
    final failedBox = getFailedQueueBox();
    return {
      'pending': box?.length ?? 0,
      'failed': failedBox?.length ?? 0,
    };
  }

  /// Reset retry counts on all queued items.
  Future<void> resetRetries() async {
    final box = getQueueBox();
    if (box == null || !box.isOpen) return;

    for (var key in box.keys) {
      final item = box.get(key);
      if (item != null && item is Map) {
        await box.put(key, {...Map<String, dynamic>.from(item), 'retryCount': 0});
      }
    }
  }

  /// Helper to update sync status in Hive cache.
  Future<void> _markHiveAsPushed(String collection, String docId) async {
    final modules = ['orders', 'inventory', 'customers', 'employees', 'floors', 'tables', 'suppliers', 'notes', 'settings'];
    String? boxName;
    for (var mod in modules) {
      if (collection.endsWith(mod)) {
        boxName = 'cache_$mod';
        if (mod == 'settings') boxName = 'settings';
        break;
      }
    }

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

  /// Direct write to Firestore for Web platform (bypasses queue for reliability).
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
          await ref.delete();
          break;
      }
      debugPrint('🌐 [OutboundManager] Web direct write: $collection/$docId');
    } catch (e) {
      debugPrint('🌐 [OutboundManager] Web direct write failed: $e');
    }
  }
}
