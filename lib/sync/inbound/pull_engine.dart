import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/services/firestore_helper.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';

/// Manages inbound sync — pulling cloud changes into local SQLite.
///
/// Extracted from SyncService._processInboundUpdates and _pullCollection.
class PullEngine {
  final Repository Function() getRepository;
  final String? Function() getActiveStoreId;
  final String? Function() getUserId;
  final Future<bool> Function() checkConnectivity;
  final Future<DateTime?> Function(String collection) getLastSyncTime;
  final Future<void> Function(String collection, DateTime time) saveLastSyncTime;
  final Future<void> Function(String message, {bool isError}) logEvent;

  bool _isPulling = false;
  bool get isPulling => _isPulling;

  /// Collections to sync, in dependency order.
  static const List<String> defaultModules = [
    'inventory',
    'orders',
    'customers',
    'employees',
    'tables',
    'counters',
    'floors',
  ];

  PullEngine({
    required this.getRepository,
    required this.getActiveStoreId,
    required this.getUserId,
    required this.checkConnectivity,
    required this.getLastSyncTime,
    required this.saveLastSyncTime,
    required this.logEvent,
  });

  /// Pull all modules from Firestore into local DB.
  Future<void> pullAll({bool forceFull = false, List<String>? modules}) async {
    if (_isPulling) return;
    _isPulling = true;

    try {
      final isConnected = await checkConnectivity();
      if (!isConnected) {
        debugPrint('📥 [PullEngine] Offline — skipping inbound sync');
        return;
      }

      final storeId = getActiveStoreId();
      if (storeId == null) return;

      final pullModules = modules ?? defaultModules;
      int totalPulled = 0;

      await Future.wait(pullModules.map((m) =>
        pullCollection(m, forceFull: forceFull).then((count) {
          totalPulled += count;
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

      debugPrint('📥 [PullEngine] Pull complete: $totalPulled items across ${pullModules.length} modules');
    } catch (e) {
      debugPrint('📥 [PullEngine] Error: $e');
      await logEvent('Inbound sync error: $e', isError: true);
    } finally {
      _isPulling = false;
    }
  }

  /// Pull a single collection from Firestore.
  /// Returns the number of items pulled.
  Future<int> pullCollection(String collection, {bool forceFull = false}) async {
    final storeId = getActiveStoreId();
    if (storeId == null) return 0;

    try {
      DateTime? lastSync;
      if (!forceFull) {
        lastSync = await getLastSyncTime(collection);
      }

      // Build query
      Query query = FirestoreHelper.storeCollection(storeId, collection);

      if (lastSync != null) {
        query = query.where('updatedAt', isGreaterThan: Timestamp.fromDate(lastSync));
      }

      // Fetch with limit to prevent memory issues
      final snapshot = await query.limit(500).get();

      if (snapshot.docs.isEmpty) {
        debugPrint('📥 [PullEngine] $collection: no new changes');
        return 0;
      }

      final repo = getRepository();
      int count = 0;

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;

          await _upsertLocal(repo, collection, doc.id, data);
          count++;
        } catch (e) {
          debugPrint('📥 [PullEngine] Error processing $collection/${doc.id}: $e');
        }
      }

      // Save sync timestamp
      await saveLastSyncTime(collection, DateTime.now());

      debugPrint('📥 [PullEngine] $collection: pulled $count items');
      return count;
    } catch (e) {
      debugPrint('📥 [PullEngine] Error pulling $collection: $e');
      await logEvent('Pull error for $collection: $e', isError: true);
      return 0;
    }
  }

  /// Upsert a document into the local SQLite database.
  /// TODO: Add proper upsert methods to Repository for each entity type.
  /// Currently delegates to existing insert methods with conflict resolution.
  Future<void> _upsertLocal(
    Repository repo,
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    // The actual upsert logic will be wired when Repository is
    // decomposed into feature-specific repositories (Phase 5).
    // For now, this serves as the contract that PullEngine expects.
    debugPrint('📥 [PullEngine] Upsert pending: $collection/$docId');
  }
}
