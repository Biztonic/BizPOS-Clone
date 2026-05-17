import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';
import 'package:biztonic_pos/sync/adapters/sync_adapter.dart';
import 'package:biztonic_pos/sync/registry/sync_collection_registry.dart';
import 'package:biztonic_pos/sync/conflict/conflict_engine.dart';

/// Manages inbound sync — pulling cloud changes into local Hive & SQLite.
///
/// This engine is now the primary orchestrator for inbound data flow,
/// utilizing [SyncAdapter]s for collection-specific logic and
/// [ConflictEngine] for state-driven reconciliation.
class PullEngine {
  final FirebaseFirestore _db;
  final Repository Function() getRepository;
  final String? Function() getActiveStoreId;
  final Future<bool> Function() checkConnectivity;
  final Future<DateTime?> Function(String collection) getLastSyncTime;
  final Future<void> Function(String collection, DateTime time) saveLastSyncTime;
  final Future<void> Function(String message, {bool isError}) logEvent;
  final Map<String, SyncAdapter> _adapters;
  final ConflictEngine _conflictEngine = ConflictEngine();

  bool _isPulling = false;
  bool get isPulling => _isPulling;

  PullEngine({
    FirebaseFirestore? db,
    required this.getRepository,
    required this.getActiveStoreId,
    required this.checkConnectivity,
    required this.getLastSyncTime,
    required this.saveLastSyncTime,
    required this.logEvent,
    required Map<String, SyncAdapter> adapters,
  })  : _db = db ?? FirebaseFirestore.instance,
        _adapters = adapters;

  /// Pull all registered modules from Firestore.
  Future<void> pullAll({bool forceFull = false}) async {
    if (_isPulling) return;
    _isPulling = true;

    try {
      final storeId = getActiveStoreId();
      if (storeId == null) return;

      const modules = SyncCollectionRegistry.pullModules;
      int totalPulled = 0;

      // Parallelize pulls with individual error handling
      await Future.wait(modules.map((m) =>
        pullCollection(m, forceFull: forceFull).then((pulledCount) {
          totalPulled += pulledCount;
        }).catchError((e) {
          debugPrint('📥 [PullEngine] Error pulling $m: $e');
        })
      ));

      if (totalPulled > 0) {
        EventBus.instance.fire(SyncCompletedEvent(
          storeId: storeId,
          itemsPulled: totalPulled,
        ));
      }

      debugPrint('📥 [PullEngine] Inbound sync complete: $totalPulled items');
    } finally {
      _isPulling = false;
    }
  }

  /// Pull a single collection from Firestore.
  Future<int> pullCollection(String collection, {bool forceFull = false}) async {
    final storeId = getActiveStoreId();
    if (storeId == null) return 0;

    final adapter = _adapters[collection];
    if (adapter == null) {
      debugPrint('⚠️ [PullEngine] No adapter found for $collection');
      return 0;
    }

    try {
      final lastSync = forceFull ? null : await getLastSyncTime(collection);
      
      // DELEGATED: Query building moved to adapter
      Query query = adapter.buildQuery(_db, storeId, lastSync);

      final snapshot = await query.limit(500).get();
      if (snapshot.docs.isEmpty) return 0;

      final boxName = SyncCollectionRegistry.getBoxName(collection, storeId: storeId);
      Box? box;
      if (boxName != null) {
        box = await Hive.openBox(boxName);
      }

      final repo = getRepository();
      int pulledCount = 0;
      final Set<String> cloudIds = {};

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          cloudIds.add(doc.id);

          final localData = box?.get(doc.id);

          // DELEGATED: Conflict resolution moved to ConflictEngine
          if (!_conflictEngine.shouldCloudWin(cloudData: data, localData: localData is Map ? Map<String, dynamic>.from(localData) : null)) {
            continue;
          }

          // Handle deletions
          bool isDeleted = data['deletedAt'] != null || data['isDeleted'] == true || data['isDeleted'] == 1;
          if (isDeleted) {
            if (!kIsWeb) await adapter.deleteLocal(doc.id, repo);
            if (box != null) await box.delete(doc.id);
            continue;
          }

          // Sanitize and mark as confirmed
          data['syncStatus'] = 'CONFIRMED';
          final sanitizedData = _deepSanitize(data);

          // 1. Hive Persistence (Cache)
          if (box != null) await box.put(doc.id, sanitizedData);

          // 2. Adapter Persistence (SQLite)
          if (!kIsWeb) {
            await adapter.insertFromCloud(sanitizedData, doc.id, repo);
            await adapter.reconcileAfterPull(sanitizedData, doc.id, repo);
          }
          pulledCount++;
        } catch (e) {
          debugPrint('📥 [PullEngine] Error processing $collection/${doc.id}: $e');
        }
      }

      // RECONCILIATION: Orphan cleanup on full sync
      if (forceFull && SyncCollectionRegistry.reconcilableCollections.contains(collection)) {
        await _cleanupOrphans(collection, storeId, cloudIds, box, repo);
      }

      // Post-pull hook
      await adapter.onPullComplete(storeId, repo);

      await saveLastSyncTime(collection, DateTime.now());
      return pulledCount;
    } catch (e) {
      debugPrint('📥 [PullEngine] Pull failed for $collection: $e');
      await logEvent('Pull error for $collection: $e', isError: true);
      return 0;
    }
  }

  Future<void> _cleanupOrphans(String collection, String storeId, Set<String> cloudIds, Box? box, Repository repo) async {
    // 1. Hive cleanup
    if (box != null) {
      final keysToDelete = [];
      for (var key in box.keys) {
        if (!cloudIds.contains(key.toString())) {
          final val = box.get(key);
          if (val is Map && val['syncStatus'] == 'CONFIRMED') {
             keysToDelete.add(key);
          }
        }
      }
      if (keysToDelete.isNotEmpty) await box.deleteAll(keysToDelete);
    }

    // 2. SQLite cleanup
    if (!kIsWeb) {
      await repo.deleteOrphans(collection, storeId, cloudIds.toList());
    }
  }

  Map<String, dynamic> _deepSanitize(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    data.forEach((key, value) {
      if (value is Timestamp) {
        sanitized[key] = value.toDate().toIso8601String();
      } else if (value is Map<String, dynamic>) {
        sanitized[key] = _deepSanitize(value);
      } else if (value is List) {
        sanitized[key] = value.map((e) => e is Map<String, dynamic> ? _deepSanitize(e) : e).toList();
      } else {
        sanitized[key] = value;
      }
    });
    return sanitized;
  }
}

