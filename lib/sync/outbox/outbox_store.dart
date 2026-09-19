import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/sync/outbox/outbox_operation.dart';

/// Manages durable outbox operations across Hive and SQLite.
///
/// Ensures mutations survive app crashes, process kills, and device restarts.
class OutboxStore {
  final Box? Function() getQueueBox;
  final Box? Function() getFailedQueueBox;
  final Repository Function() getRepository;

  static const String primaryQueueBox = 'sync_queue_v2';
  static const String deadLetterBox = 'sync_dead_letter_v2';

  static const int maxAttempts = 6;
  static const int baseDelaySeconds = 2;
  static const int maxDelaySeconds = 300; // 5 minutes

  OutboxStore({
    required this.getQueueBox,
    required this.getFailedQueueBox,
    required this.getRepository,
  });

  /// Computes next retry timestamp with exponential backoff and randomized jitter.
  static int computeNextRetryAt(int attemptCount) {
    if (attemptCount <= 0) {
      return DateTime.now().millisecondsSinceEpoch;
    }
    // Exponential calculation: base * 2^(attempts-1)
    final expMultiplier = math.pow(2, math.min(attemptCount - 1, 8)).toDouble();
    final delay = (baseDelaySeconds * expMultiplier)
        .clamp(baseDelaySeconds, maxDelaySeconds.toDouble());

    // Jitter: +/- 20%
    final jitterRange = delay * 0.2;
    final randomJitter =
        (math.Random().nextDouble() * 2 * jitterRange) - jitterRange;
    final finalDelaySeconds =
        math.max(baseDelaySeconds.toDouble(), delay + randomJitter);

    return DateTime.now().millisecondsSinceEpoch +
        (finalDelaySeconds * 1000).round();
  }

  /// Checks if an error is a non-recoverable permanent failure.
  static bool isFatalError(dynamic error) {
    if (error == null) return false;
    final msg = error.toString().toLowerCase();
    return msg.contains('permission-denied') ||
        msg.contains('unauthenticated') ||
        msg.contains('not-found') ||
        msg.contains('invalid-argument') ||
        msg.contains('failed-precondition');
  }

  /// Recovers any in-flight operations stuck from a previous process crash.
  Future<void> recoverStaleInFlight() async {
    final box = getQueueBox();
    if (box != null && box.isOpen) {
      for (var key in box.keys) {
        final val = box.get(key);
        if (val is Map) {
          final stateStr = val['state']?.toString();
          if (stateStr == 'IN_FLIGHT') {
            final op = OutboxOperation.fromMap(val, key.toString());
            // Reset to pending so it can be picked up safely
            final updated = op.copyWith(state: OutboxState.pending);
            await box.put(key, updated.toMap());
            if (!kIsWeb) {
              try {
                await getRepository().updateOutboxOperation(updated);
              } catch (_) {}
            }
            debugPrint(
                '🔄 [OutboxStore] Recovered stuck IN_FLIGHT operation: ${op.operationId}');
          }
        }
      }
    }
  }

  /// Enqueues an operation into durable storage.
  /// Returns the operationId.
  Future<String> enqueue(OutboxOperation op) async {
    final box = getQueueBox();
    final key = op.operationId;

    // 1. Hive Persistence (universal)
    if (box != null && box.isOpen) {
      // Deduplication: if identical operationId is already present, do not re-enqueue
      final existing = box.get(key);
      if (existing != null && existing is Map) {
        final existingOp = OutboxOperation.fromMap(existing, key);
        if (existingOp.state != OutboxState.failed &&
            existingOp.state != OutboxState.deadLetter) {
          debugPrint('🛡️ [OutboxStore] Operation already in queue: $key');
          return key;
        }
      }
      await box.put(key, op.toMap());
    }

    // 2. SQLite Persistence (native)
    if (!kIsWeb) {
      try {
        await getRepository().insertOutboxOperation(op);
      } catch (e) {
        debugPrint('⚠️ [OutboxStore] SQLite enqueue fallback failed: $e');
      }
    }

    debugPrint(
        '📥 [OutboxStore] Enqueued operation ${op.operationId} (${op.collection}/${op.entityId}) [${op.operation}]');
    return key;
  }

  /// Fetches pending operations that are ready to be processed.
  /// Respects `nextRetryAt` for backoff.
  Future<List<OutboxOperation>> getReadyOperations({
    String? storeId,
    int limit = 50,
  }) async {
    final readyOps = <OutboxOperation>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    final box = getQueueBox();
    if (box != null && box.isOpen) {
      for (var key in box.keys) {
        if (readyOps.length >= limit) break;
        final val = box.get(key);
        if (val is Map) {
          final op = OutboxOperation.fromMap(val, key.toString());

          // Tenant isolation check
          if (storeId != null && storeId.isNotEmpty && op.storeId != storeId) {
            continue;
          }

          // State eligibility
          if (op.state == OutboxState.pending ||
              (op.state == OutboxState.failed &&
                  (op.nextRetryAt == null || now >= op.nextRetryAt!))) {
            readyOps.add(op);
          }
        }
      }
    }

    return readyOps;
  }

  /// Marks a batch of operations as IN_FLIGHT.
  Future<void> markInFlight(List<String> operationIds) async {
    final box = getQueueBox();
    for (var id in operationIds) {
      if (box != null && box.isOpen) {
        final val = box.get(id);
        if (val is Map) {
          final op = OutboxOperation.fromMap(val, id)
              .copyWith(state: OutboxState.inFlight);
          await box.put(id, op.toMap());
          if (!kIsWeb) {
            try {
              await getRepository().updateOutboxOperation(op);
            } catch (_) {}
          }
        }
      }
    }
  }

  /// Marks an operation as successfully PUSHED with audit metadata.
  Future<void> markPushed(String operationId,
      {Map<String, dynamic>? auditMetadata}) async {
    final box = getQueueBox();
    if (box != null && box.isOpen) {
      final val = box.get(operationId);
      if (val is Map) {
        final currentOp = OutboxOperation.fromMap(val, operationId);
        final op = currentOp.copyWith(
          state: OutboxState.pushed,
          auditMetadata: {
            ...?currentOp.auditMetadata,
            ...?auditMetadata,
            'pushedAt': DateTime.now().toIso8601String(),
          },
        );
        await box.put(operationId, op.toMap());
        if (!kIsWeb) {
          try {
            await getRepository().updateOutboxOperation(op);
          } catch (_) {}
        }
      }
    }
  }

  /// Marks an operation as CONFIRMED (safe for eventual pruning).
  Future<void> markConfirmed(String operationId) async {
    final box = getQueueBox();
    if (box != null && box.isOpen) {
      final val = box.get(operationId);
      if (val is Map) {
        final currentOp = OutboxOperation.fromMap(val, operationId);
        final op = currentOp.copyWith(
          state: OutboxState.confirmed,
          auditMetadata: {
            ...?currentOp.auditMetadata,
            'confirmedAt': DateTime.now().toIso8601String(),
          },
        );
        await box.put(operationId, op.toMap());
        if (!kIsWeb) {
          try {
            await getRepository().updateOutboxOperation(op);
          } catch (_) {}
        }
      }
    }
  }

  /// Marks an operation as FAILED with exponential backoff and jitter.
  /// Transitions to DEAD_LETTER if max attempts exceeded or if error is fatal.
  Future<void> markFailed(String operationId, String error,
      {bool isFatal = false}) async {
    final box = getQueueBox();
    if (box == null || !box.isOpen) return;

    final val = box.get(operationId);
    if (val is! Map) return;

    final currentOp = OutboxOperation.fromMap(val, operationId);
    final nextAttempts = currentOp.attemptCount + 1;
    final fatal = isFatal || isFatalError(error);

    if (fatal || nextAttempts >= maxAttempts) {
      // Transition to DEAD_LETTER
      await markDeadLetter(operationId, error);
      return;
    }

    final nextRetry = computeNextRetryAt(nextAttempts);
    final updatedOp = currentOp.copyWith(
      attemptCount: nextAttempts,
      nextRetryAt: nextRetry,
      state: OutboxState.failed,
      lastError: error,
    );

    await box.put(operationId, updatedOp.toMap());
    if (!kIsWeb) {
      try {
        await getRepository().updateOutboxOperation(updatedOp);
      } catch (_) {}
    }

    debugPrint(
        '⚠️ [OutboxStore] Operation $operationId failed (attempt $nextAttempts). Next retry at: ${DateTime.fromMillisecondsSinceEpoch(nextRetry)}');
  }

  /// Moves an operation to DEAD_LETTER status.
  Future<void> markDeadLetter(String operationId, String error) async {
    final box = getQueueBox();
    final failedBox = getFailedQueueBox();

    if (box != null && box.isOpen) {
      final val = box.get(operationId);
      if (val is Map) {
        final currentOp = OutboxOperation.fromMap(val, operationId);
        final deadOp = currentOp.copyWith(
          state: OutboxState.deadLetter,
          lastError: error,
          auditMetadata: {
            ...?currentOp.auditMetadata,
            'deadLetterAt': DateTime.now().toIso8601String(),
          },
        );

        // Put into dead letter / failed box
        if (failedBox != null && failedBox.isOpen) {
          await failedBox.put(operationId, deadOp.toMap());
        }
        await box.put(operationId, deadOp.toMap());

        if (!kIsWeb) {
          try {
            await getRepository().updateOutboxOperation(deadOp);
          } catch (_) {}
        }

        debugPrint(
            '💀 [OutboxStore] Operation $operationId moved to DEAD_LETTER: $error');
      }
    }
  }

  /// Manually retries a specific operation by resetting attempts and state to PENDING.
  Future<void> retryOperation(String operationId) async {
    final box = getQueueBox();
    if (box != null && box.isOpen) {
      final val = box.get(operationId);
      if (val is Map) {
        final currentOp = OutboxOperation.fromMap(val, operationId);
        final resetOp = currentOp.copyWith(
          state: OutboxState.pending,
          attemptCount: 0,
          nextRetryAt: null,
          lastError: null,
        );
        await box.put(operationId, resetOp.toMap());
        if (!kIsWeb) {
          try {
            await getRepository().updateOutboxOperation(resetOp);
          } catch (_) {}
        }
        debugPrint('🔄 [OutboxStore] Manually retried operation: $operationId');
      }
    }
  }

  /// Manually retries all DEAD_LETTER and FAILED operations.
  Future<int> retryAllDeadLetter({String? storeId}) async {
    final box = getQueueBox();
    int count = 0;
    if (box != null && box.isOpen) {
      for (var key in box.keys) {
        final val = box.get(key);
        if (val is Map) {
          final op = OutboxOperation.fromMap(val, key.toString());
          if (storeId != null && storeId.isNotEmpty && op.storeId != storeId) {
            continue;
          }
          if (op.state == OutboxState.deadLetter ||
              op.state == OutboxState.failed) {
            await retryOperation(op.operationId);
            count++;
          }
        }
      }
    }
    return count;
  }

  /// Prunes CONFIRMED outbox operations older than `maxAge`.
  Future<int> cleanupConfirmed(
      {Duration maxAge = const Duration(days: 7)}) async {
    final box = getQueueBox();
    if (box == null || !box.isOpen) return 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAgeMs = maxAge.inMilliseconds;
    final toDelete = <dynamic>[];

    for (var key in box.keys) {
      final val = box.get(key);
      if (val is Map) {
        final stateStr = val['state']?.toString();
        final createdAt = (val['createdAt'] as num?)?.toInt() ?? now;
        if ((stateStr == 'CONFIRMED' || stateStr == 'PUSHED') &&
            (now - createdAt) > maxAgeMs) {
          toDelete.add(key);
        }
      }
    }

    if (toDelete.isNotEmpty) {
      await box.deleteAll(toDelete);
      if (!kIsWeb) {
        for (var id in toDelete) {
          try {
            await getRepository().deleteOutboxOperation(id.toString());
          } catch (_) {}
        }
      }
      debugPrint(
          '🧹 [OutboxStore] Pruned ${toDelete.length} confirmed/aged outbox operations');
    }

    return toDelete.length;
  }

  /// Returns diagnostic stats about outbox states.
  Map<String, int> getOutboxStats({String? storeId}) {
    final box = getQueueBox();
    int pending = 0;
    int inFlight = 0;
    int pushed = 0;
    int confirmed = 0;
    int failed = 0;
    int conflicted = 0;
    int deadLetter = 0;

    if (box != null && box.isOpen) {
      for (var val in box.values) {
        if (val is Map) {
          if (storeId != null && storeId.isNotEmpty) {
            final opStore =
                val['storeId']?.toString() ?? val['activeStoreId']?.toString();
            if (opStore != storeId) continue;
          }

          final state = OutboxState.fromValue(val['state']?.toString());
          switch (state) {
            case OutboxState.pending:
              pending++;
              break;
            case OutboxState.inFlight:
              inFlight++;
              break;
            case OutboxState.pushed:
              pushed++;
              break;
            case OutboxState.confirmed:
              confirmed++;
              break;
            case OutboxState.failed:
              failed++;
              break;
            case OutboxState.conflicted:
              conflicted++;
              break;
            case OutboxState.deadLetter:
              deadLetter++;
              break;
          }
        }
      }
    }

    return {
      'pending': pending,
      'inFlight': inFlight,
      'pushed': pushed,
      'confirmed': confirmed,
      'failed': failed,
      'conflicted': conflicted,
      'deadLetter': deadLetter,
      'total': pending +
          inFlight +
          pushed +
          confirmed +
          failed +
          conflicted +
          deadLetter,
    };
  }

  /// Returns a list of operations currently in DEAD_LETTER state.
  List<OutboxOperation> getDeadLetterOperations(
      {String? storeId, int limit = 50}) {
    final box = getQueueBox();
    final list = <OutboxOperation>[];
    if (box != null && box.isOpen) {
      for (var key in box.keys) {
        if (list.length >= limit) break;
        final val = box.get(key);
        if (val is Map) {
          final op = OutboxOperation.fromMap(val, key.toString());
          if (storeId != null && storeId.isNotEmpty && op.storeId != storeId) {
            continue;
          }
          if (op.state == OutboxState.deadLetter) {
            list.add(op);
          }
        }
      }
    }
    return list;
  }
}
