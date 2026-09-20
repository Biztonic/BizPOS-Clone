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
import 'package:biztonic_pos/sync/inbound/inbox_store.dart';

/// Manages inbound sync — pulling cloud changes into local Hive & SQLite
/// with multi-page pagination, verified orphan reconciliation, and deterministic conflicts.
class PullEngine {
  final FirebaseFirestore _db;
  final Repository Function() getRepository;
  final String? Function() getActiveStoreId;
  final Future<bool> Function() checkConnectivity;
  final Future<DateTime?> Function(String collection) getLastSyncTime;
  final Future<void> Function(String collection, DateTime time)
      saveLastSyncTime;
  final Future<void> Function(String message, {bool isError}) logEvent;
  final Map<String, SyncAdapter> _adapters;

  final ConflictEngine _conflictEngine = ConflictEngine();
  final InboxStore _inboxStore = InboxStore();

  bool _isPulling = false;
  bool get isPulling => _isPulling;

  static const int pageSize = 200;

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
        _adapters = adapters {
    unawaited(_inboxStore.init());
  }

  /// Pull all registered modules from Firestore.
  Future<void> pullAll({bool forceFull = false}) async {
    if (_isPulling) return;
    _isPulling = true;

    try {
      final storeId = getActiveStoreId();
      if (storeId == null) return;

      const modules = SyncCollectionRegistry.pullModules;
      int totalPulled = 0;

      for (var m in modules) {
        try {
          final count = await pullCollection(m, forceFull: forceFull);
          totalPulled += count;
        } catch (e) {
          debugPrint('📥 [PullEngine] Error pulling $m: $e');
        }
      }

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

  /// Pull a single collection from Firestore using verified multi-page pagination.
  Future<int> pullCollection(String collection,
      {bool forceFull = false}) async {
    final storeId = getActiveStoreId();
    if (storeId == null) return 0;

    final adapter = _adapters[collection];
    if (adapter == null) {
      debugPrint('⚠️ [PullEngine] No adapter found for $collection');
      return 0;
    }

    try {
      final lastSync = forceFull ? null : await getLastSyncTime(collection);
      Query baseQuery = adapter.buildQuery(_db, storeId, lastSync);

      final boxName =
          SyncCollectionRegistry.getBoxName(collection, storeId: storeId);
      Box? box;
      if (boxName != null) {
        box = await Hive.openBox(boxName);
      }

      final repo = getRepository();
      int pulledCount = 0;
      final Set<String> verifiedCloudIds = {};
      DocumentSnapshot? lastVisibleDoc;
      bool isCompleteDataset = true;

      // 1. Multi-Page Pagination Loop
      while (true) {
        Query pageQuery = baseQuery.limit(pageSize);
        if (lastVisibleDoc != null) {
          pageQuery = pageQuery.startAfterDocument(lastVisibleDoc);
        }

        QuerySnapshot pageSnapshot;
        try {
          pageSnapshot = await pageQuery.get();
        } catch (e) {
          isCompleteDataset = false;
          debugPrint('📥 [PullEngine] Page fetch failed for $collection: $e');
          await logEvent('Page fetch failed for $collection: $e',
              isError: true);
          break;
        }

        if (pageSnapshot.docs.isEmpty) {
          break; // All pages fetched
        }

        final Map<String, dynamic> pageHiveBatch = {};
        final List<Map<String, dynamic>> pageInboxBatch = [];

        for (var doc in pageSnapshot.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            verifiedCloudIds.add(doc.id);

            // Tenant isolation verification
            final docStore = data['storeId']?.toString();
            if (docStore != null &&
                docStore.isNotEmpty &&
                docStore != storeId) {
              debugPrint(
                  '🚫 [PullEngine] Tenant mismatch on incoming doc ${doc.id}: $docStore != $storeId');
              continue;
            }

            final version = _parseInt(data['version'], 1);
            final operationId = data['operationId']?.toString();

            // Inbound Deduplication for financial ledgers
            if (collection == SyncCollectionRegistry.inventoryMovements ||
                collection == SyncCollectionRegistry.businessEvents) {
              if (_inboxStore.isAlreadyProcessed(collection, doc.id,
                  version: version, operationId: operationId)) {
                continue; // Skip duplicate financial event
              }
            }

            final localData = box?.get(doc.id);
            final localMap =
                localData is Map ? Map<String, dynamic>.from(localData) : null;

            // Deterministic Conflict Resolution
            final resolution = _conflictEngine.resolve(
              collection: collection,
              cloudData: data,
              localData: localMap,
              storeId: storeId,
            );

            if (resolution.action == ResolutionAction.localWins) {
              continue; // Local mutation preserved
            }

            if (resolution.action == ResolutionAction.recordConflict &&
                resolution.conflictRecord != null) {
              if (!kIsWeb) {
                try {
                  await repo.insertConflictRecord(resolution.conflictRecord!);
                } catch (_) {}
              }
              await logEvent(
                  'Recorded conflict on $collection/${doc.id}: ${resolution.conflictRecord!.conflictType}',
                  isError: true);
              continue;
            }

            // Handle Tombsones / Soft Deletions
            final bool isDeleted = data['deletedAt'] != null ||
                data['isDeleted'] == true ||
                data['isDeleted'] == 1;

            if (isDeleted) {
              if (!kIsWeb) {
                await adapter.deleteLocal(doc.id, repo);
              }
              if (box != null) {
                final tombstone = Map<String, dynamic>.from(data);
                tombstone['id'] = doc.id;
                tombstone['isDeleted'] = true;
                tombstone['deletedAt'] = tombstone['deletedAt'] ?? DateTime.now().toIso8601String();
                tombstone['syncStatus'] = 'CONFIRMED';
                await box.put(doc.id, _deepSanitize(tombstone));
              }
              pageInboxBatch.add({
                'collection': collection,
                'docId': doc.id,
                'version': version,
                'operationId': operationId,
                'storeId': storeId,
                'processedAt': DateTime.now().millisecondsSinceEpoch,
              });
              continue;
            }

            final sanitizedData = _deepSanitize(
                resolution.mergedData != null ? resolution.mergedData! : data);
            sanitizedData['syncStatus'] = 'CONFIRMED';

            // 1. Hive Persistence (Cache)
            if (box != null) {
              pageHiveBatch[doc.id] = sanitizedData;
            }

            // 2. SQLite Persistence
            if (!kIsWeb) {
              await adapter.insertFromCloud(sanitizedData, doc.id, repo);
              await adapter.reconcileAfterPull(sanitizedData, doc.id, repo);
            }

            pageInboxBatch.add({
              'collection': collection,
              'docId': doc.id,
              'version': version,
              'operationId': operationId,
              'storeId': storeId,
              'processedAt': DateTime.now().millisecondsSinceEpoch,
            });

            pulledCount++;
          } catch (e) {
            debugPrint(
                '📥 [PullEngine] Error processing $collection/${doc.id}: $e');
          }
        }

        // Batched Hive persistence per page
        if (box != null && pageHiveBatch.isNotEmpty) {
          await box.putAll(pageHiveBatch);
        }

        // Batched Inbox deduplication persistence per page
        if (pageInboxBatch.isNotEmpty) {
          await _inboxStore.recordProcessedBatch(pageInboxBatch);
        }

        lastVisibleDoc = pageSnapshot.docs.last;
        if (pageSnapshot.docs.length < pageSize) {
          break; // Reached end of collection
        }
      }

      // 2. VERIFIED ORPHAN RECONCILIATION
      // Only perform orphan cleanup after a verified complete dataset!
      if (forceFull &&
          SyncCollectionRegistry.reconcilableCollections.contains(collection)) {
        if (isCompleteDataset) {
          await _cleanupOrphans(
              collection, storeId, verifiedCloudIds, box, repo);
        } else {
          debugPrint(
              '⚠️ [PullEngine] Incomplete dataset for $collection. Skipped orphan cleanup to protect local data.');
          await logEvent(
              'Skipped orphan cleanup for $collection: dataset incomplete.',
              isError: true);
        }
      }

      // Post-pull hook (e.g. inventory ledger reconciliation)
      await adapter.onPullComplete(storeId, repo);

      await saveLastSyncTime(collection, DateTime.now());
      return pulledCount;
    } catch (e) {
      debugPrint('📥 [PullEngine] Pull failed for $collection: $e');
      await logEvent('Pull failed for $collection: $e', isError: true);
      return 0;
    }
  }

  /// Safe orphan cleanup: only deletes CONFIRMED items that are missing from cloud.
  /// Never touches local items with PENDING or IN_FLIGHT status.
  /// Aborts immediately if cloudIds is empty or drastically smaller than local dataset.
  Future<void> _cleanupOrphans(
    String collection,
    String storeId,
    Set<String> cloudIds,
    Box? box,
    Repository repo,
  ) async {
    // 0. Full-pull safety check: Never wipe local data if cloudIds returned empty!
    if (cloudIds.isEmpty) {
      debugPrint(
          '🛡️ [PullEngine] Aborted orphan cleanup for $collection: cloudIds set is empty.');
      return;
    }

    if (box != null && box.isNotEmpty) {
      // If cloud returned fewer than 25% of local items and local has > 5 items, protect local data!
      if (cloudIds.length < (box.length * 0.25) && box.length > 5) {
        debugPrint(
            '🛡️ [PullEngine] Aborted orphan cleanup for $collection: cloud count (${cloudIds.length}) drastically below local count (${box.length}). Possible partial query.');
        return;
      }
    }

    // 1. Hive cleanup
    if (box != null) {
      final keysToDelete = <dynamic>[];
      for (var key in box.keys) {
        final idStr = key.toString();
        if (!cloudIds.contains(idStr)) {
          final val = box.get(key);
          // Never delete items with pending offline changes or items already tombstoned
          if (val is Map) {
            final syncStatus = val['syncStatus']?.toString();
            final isDeleted = val['isDeleted'] == true || val['isDeleted'] == 1;
            if (!isDeleted && (syncStatus == 'CONFIRMED' || syncStatus == 'PUSHED')) {
              keysToDelete.add(key);
            }
          }
        }
      }
      if (keysToDelete.isNotEmpty) {
        await box.deleteAll(keysToDelete);
        debugPrint(
            '🧹 [PullEngine] Hive pruned ${keysToDelete.length} orphans in $collection');
      }
    }

    // 2. SQLite cleanup
    if (!kIsWeb) {
      try {
        await repo.deleteOrphans(collection, storeId, cloudIds.toList());
      } catch (e) {
        debugPrint('⚠️ [PullEngine] SQLite orphan cleanup error: $e');
      }
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
        sanitized[key] = value
            .map((e) => e is Map<String, dynamic> ? _deepSanitize(e) : e)
            .toList();
      } else {
        sanitized[key] = value;
      }
    });
    return sanitized;
  }

  int _parseInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }
}
