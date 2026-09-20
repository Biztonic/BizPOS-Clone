import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Tracks inbound messages and cloud documents to prevent duplicate processing.
class InboxStore {
  static const String boxName = 'sync_inbox_v1';
  Box? _box;

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      try {
        _box = await Hive.openBox(boxName);
      } catch (e) {
        debugPrint('⚠️ [InboxStore] Failed to open box $boxName: $e');
      }
    } else {
      _box = Hive.box(boxName);
    }
  }

  /// Generates a composite inbox key.
  String _makeKey(String collection, String docId, {String? operationId}) {
    if (operationId != null && operationId.isNotEmpty) {
      return 'op_${collection}_$operationId';
    }
    return 'doc_${collection}_$docId';
  }

  /// Checks if an inbound cloud entity or financial event has already been processed.
  bool isAlreadyProcessed(
    String collection,
    String docId, {
    int? version,
    String? operationId,
  }) {
    final box = _box ?? (Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null);
    if (box == null || !box.isOpen) return false;

    // Check by operationId if available (for financial transactions)
    if (operationId != null && operationId.isNotEmpty) {
      final opKey = _makeKey(collection, docId, operationId: operationId);
      if (box.containsKey(opKey)) return true;
    }

    final key = _makeKey(collection, docId);
    final existing = box.get(key);
    if (existing == null) return false;

    if (existing is Map) {
      final processedVersion = (existing['version'] as num?)?.toInt() ?? 1;
      if (version != null && version <= processedVersion) {
        return true;
      }
    }
    return false;
  }

  /// Records an inbound document as processed.
  Future<void> recordProcessed(
    String collection,
    String docId, {
    int? version,
    String? operationId,
    String? storeId,
  }) async {
    final box = _box ?? (Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null);
    if (box == null || !box.isOpen) return;

    final data = {
      'collection': collection,
      'docId': docId,
      'version': version ?? 1,
      'operationId': operationId,
      'storeId': storeId,
      'processedAt': DateTime.now().millisecondsSinceEpoch,
    };

    final key = _makeKey(collection, docId);
    await box.put(key, data);

    if (operationId != null && operationId.isNotEmpty) {
      final opKey = _makeKey(collection, docId, operationId: operationId);
      await box.put(opKey, data);
    }
  }

  /// Records a batch of inbound documents as processed.
  Future<void> recordProcessedBatch(List<Map<String, dynamic>> records) async {
    final box = _box ?? (Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null);
    if (box == null || !box.isOpen || records.isEmpty) return;

    final Map<String, dynamic> batch = {};
    for (var r in records) {
      final collection = r['collection'] as String;
      final docId = r['docId'] as String;
      final opId = r['operationId'] as String?;
      final key = _makeKey(collection, docId);
      batch[key] = r;
      if (opId != null && opId.isNotEmpty) {
        final opKey = _makeKey(collection, docId, operationId: opId);
        batch[opKey] = r;
      }
    }
    await box.putAll(batch);
  }

  /// Prunes old inbox records older than `maxAge`.
  Future<int> cleanup({Duration maxAge = const Duration(days: 14)}) async {
    final box = _box ?? (Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null);
    if (box == null || !box.isOpen) return 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAgeMs = maxAge.inMilliseconds;
    final toDelete = <dynamic>[];

    for (var key in box.keys) {
      final val = box.get(key);
      if (val is Map) {
        final processedAt = (val['processedAt'] as num?)?.toInt() ?? now;
        if ((now - processedAt) > maxAgeMs) {
          toDelete.add(key);
        }
      }
    }

    if (toDelete.isNotEmpty) {
      await box.deleteAll(toDelete);
      debugPrint(
          '🧹 [InboxStore] Pruned ${toDelete.length} old inbox deduplication records');
    }

    return toDelete.length;
  }

  /// Clears store inbox records on store switch or nuclear reset.
  Future<void> clearStore(String storeId) async {
    final box = _box ?? (Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null);
    if (box == null || !box.isOpen) return;

    final toDelete = <dynamic>[];
    for (var key in box.keys) {
      final val = box.get(key);
      if (val is Map && val['storeId']?.toString() == storeId) {
        toDelete.add(key);
      }
    }
    if (toDelete.isNotEmpty) {
      await box.deleteAll(toDelete);
    }
  }
}
