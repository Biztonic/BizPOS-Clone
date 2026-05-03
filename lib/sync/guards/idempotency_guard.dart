import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Prevents duplicate Firestore writes caused by timeout → retry scenarios.
///
/// Critical for POS operations where duplicates are catastrophic:
/// - Duplicate invoices
/// - Duplicate payments
/// - Duplicate inventory movements
/// - Duplicate refunds
///
/// Usage:
/// ```dart
/// final key = IdempotencyGuard.generateKey('orders', orderId, 'create');
/// if (await guard.isAlreadyProcessed(key)) return; // Skip duplicate
/// await firestoreWrite(...);
/// await guard.markProcessed(key);
/// ```
class IdempotencyGuard {
  static const String _boxName = 'idempotency_keys';
  static const int _maxEntries = 5000;
  static const Duration _ttl = Duration(hours: 24);

  Box? _box;

  /// Initializes the idempotency store. Call once during app init.
  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }
    // Background cleanup of expired entries
    await cleanupExpired();
  }

  /// Generates a deterministic idempotency key for an operation.
  ///
  /// Format: `{collection}:{docId}:{action}:{contentHash}`
  /// The contentHash ensures that re-submitting the *same* data
  /// is blocked, but submitting *updated* data for the same doc is allowed.
  static String generateKey(
    String collection,
    String docId,
    String action, {
    Map<String, dynamic>? payload,
  }) {
    final base = '$collection:$docId:${action.toUpperCase()}';
    if (payload != null && payload.isNotEmpty) {
      // Use a lightweight hash of key fields to detect duplicate content
      // We hash: amount, total, quantity, delta — the fields where duplicates are dangerous
      final dangerFields = <String>[];
      for (final key in ['total', 'amount', 'delta', 'quantity', 'refundAmount']) {
        if (payload.containsKey(key)) {
          dangerFields.add('$key=${payload[key]}');
        }
      }
      if (dangerFields.isNotEmpty) {
        return '$base:${dangerFields.join(',')}';
      }
    }
    return base;
  }

  /// Returns `true` if this operation has already been successfully processed
  /// and should NOT be retried.
  Future<bool> isAlreadyProcessed(String key) async {
    final box = _box;
    if (box == null || !box.isOpen) return false;

    final entry = box.get(key);
    if (entry == null) return false;

    if (entry is Map) {
      final processedAt = entry['processedAt'] as int?;
      if (processedAt != null) {
        final age = DateTime.now().millisecondsSinceEpoch - processedAt;
        if (age > _ttl.inMilliseconds) {
          // Expired — allow retry
          await box.delete(key);
          return false;
        }
        return true; // Still within TTL — block duplicate
      }
    }
    return false;
  }

  /// Marks an operation as successfully processed.
  /// Call this AFTER the Firestore write succeeds.
  Future<void> markProcessed(String key) async {
    final box = _box;
    if (box == null || !box.isOpen) return;

    await box.put(key, {
      'processedAt': DateTime.now().millisecondsSinceEpoch,
    });

    // Evict oldest entries if we exceed capacity
    if (box.length > _maxEntries) {
      await _evictOldest(box.length - _maxEntries);
    }
  }

  /// Removes an idempotency key, allowing the operation to be retried.
  /// Use when a write definitively FAILED (not timed out — failed).
  Future<void> clearKey(String key) async {
    final box = _box;
    if (box == null || !box.isOpen) return;
    await box.delete(key);
  }

  /// Removes all expired entries from the store.
  Future<void> cleanupExpired() async {
    final box = _box;
    if (box == null || !box.isOpen) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final keysToDelete = <dynamic>[];

    for (final key in box.keys) {
      final entry = box.get(key);
      if (entry is Map) {
        final processedAt = entry['processedAt'] as int?;
        if (processedAt != null && (now - processedAt) > _ttl.inMilliseconds) {
          keysToDelete.add(key);
        }
      }
    }

    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
      debugPrint('🛡️ [IdempotencyGuard] Cleaned ${keysToDelete.length} expired keys');
    }
  }

  /// Evicts the oldest N entries when capacity is exceeded.
  Future<void> _evictOldest(int count) async {
    final box = _box;
    if (box == null || !box.isOpen || count <= 0) return;

    // Collect entries with timestamps for sorting
    final entries = <MapEntry<dynamic, int>>[];
    for (final key in box.keys) {
      final val = box.get(key);
      if (val is Map) {
        entries.add(MapEntry(key, val['processedAt'] as int? ?? 0));
      }
    }

    // Sort by processedAt ascending (oldest first)
    entries.sort((a, b) => a.value.compareTo(b.value));

    // Delete the oldest N
    final keysToDelete = entries.take(count).map((e) => e.key).toList();
    await box.deleteAll(keysToDelete);
  }

  /// Returns the number of tracked idempotency keys (for diagnostics).
  int get trackedCount => _box?.length ?? 0;
}
