import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Persistent sync diagnostics and logging.
/// Extracted from SyncService._logSyncEvent and inspectCloudData.
class SyncDiagnostics {
  Box? _logBox;

  Future<void> init(Box? logBox) async {
    _logBox = logBox;
  }

  /// Log a sync event with timestamp.
  Future<void> log(String message, {bool isError = false}) async {
    final entry = {
      'message': message,
      'isError': isError,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      if (_logBox != null && _logBox!.isOpen) {
        // Keep last 100 entries
        if (_logBox!.length > 100) {
          await _logBox!.deleteAt(0);
        }
        await _logBox!.add(entry);
      }
    } catch (e) {
      debugPrint('[SyncDiagnostics] Failed to log: $e');
    }

    if (isError) {
      debugPrint('❌ [Sync] $message');
    } else {
      debugPrint('📋 [Sync] $message');
    }
  }

  /// Get recent sync log entries.
  List<Map<String, dynamic>> getRecentLogs({int limit = 20}) {
    if (_logBox == null || !_logBox!.isOpen) return [];
    final all = _logBox!.values.toList();
    final start = all.length > limit ? all.length - limit : 0;
    return all.sublist(start).map((e) =>
      Map<String, dynamic>.from(e as Map)
    ).toList();
  }

  /// Get error-only logs.
  List<Map<String, dynamic>> getErrorLogs({int limit = 10}) {
    return getRecentLogs(limit: 50)
      .where((e) => e['isError'] == true)
      .take(limit)
      .toList();
  }

  /// Clear all diagnostic logs.
  Future<void> clearLogs() async {
    if (_logBox != null && _logBox!.isOpen) {
      await _logBox!.clear();
    }
  }
}
