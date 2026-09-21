import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    return all
        .sublist(start)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
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

  /// Provides a detailed diagnostic summary of cloud accessibility and data visibility.
  Future<String> inspectCloudData({
    required FirebaseFirestore db,
    required String? activeStoreId,
  }) async {
    if (activeStoreId == null) return "No Store Selected";
    StringBuffer sb = StringBuffer();
    sb.writeln("=== CLOUD INSPECTOR (${DateTime.now()}) ===");
    sb.writeln("Active Store ID: $activeStoreId");

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      sb.writeln("Auth UID: ${user.uid}");
      try {
        final userDoc = await db.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final uData = userDoc.data()!;
          sb.writeln("DB User Profile:");
          sb.writeln(" - Role: ${uData['role']}");
          sb.writeln(" - Profile storeId: ${uData['storeId']}");
          sb.writeln(" - accessibleStoreIds: ${uData['accessibleStoreIds']}");
          sb.writeln(" - storeIds: ${uData['storeIds']}");
        } else {
          sb.writeln("!!! USER DOC NOT FOUND !!!");
        }
      } catch (e) {
        sb.writeln("User Doc Fetch Error: $e");
      }
    }

    try {
      final orders = await db
          .collection('orders')
          .where('storeId', isEqualTo: activeStoreId)
          .limit(3)
          .get();
      sb.writeln("\n[ORDERS] Visible: ${orders.docs.length}");
      for (var d in orders.docs) {
        sb.writeln(" - ${d.id}: ${d.data()['status']}");
      }
    } catch (e) {
      sb.writeln("\nOrders Fetch Error: $e");
    }

    return sb.toString();
  }

  /// Formats outbox stats and failed operations for diagnostic views.
  Map<String, dynamic> formatOutboxDiagnostics(
      Map<String, int> stats, List<dynamic> deadLetters) {
    return {
      'stats': stats,
      'deadLetterCount': deadLetters.length,
      'deadLetters': deadLetters.map((op) {
        if (op is Map) return sanitizeData(Map<String, dynamic>.from(op));
        try {
          return sanitizeData(
              Map<String, dynamic>.from((op as dynamic).toMap()));
        } catch (_) {
          return {'raw': sanitizeMessage(op.toString())};
        }
      }).toList(),
    };
  }

  /// Sanitizes messages by masking credentials, pins, and auth tokens.
  static String sanitizeMessage(String message) {
    var sanitized = message;
    final sensitivePatterns = [
      RegExp(
          r'(pin|password|token|secret|credential|api_?key)[=:\s]+([^\s,;]+)',
          caseSensitive: false),
      RegExp(r'(Bearer)\s+[A-Za-z0-9\-\._~\+\/]+=*', caseSensitive: false),
    ];
    for (var pattern in sensitivePatterns) {
      sanitized = sanitized.replaceAllMapped(pattern, (match) {
        final prefix =
            match.groupCount >= 1 ? (match.group(1) ?? 'secret') : 'secret';
        return '$prefix: [REDACTED]';
      });
    }
    return sanitized;
  }

  /// Sanitizes key-value maps by deeply redacting sensitive credential keys.
  static Map<String, dynamic> sanitizeData(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    const sensitiveSubstrings = [
      'pin',
      'password',
      'token',
      'secret',
      'credential',
      'apikey',
      'api_key',
      'auth',
    ];

    data.forEach((key, value) {
      final keyLower = key.toLowerCase();
      final isSensitive = sensitiveSubstrings
          .any((s) => keyLower.contains(s) && keyLower != 'authuid');

      if (isSensitive) {
        sanitized[key] = '[REDACTED]';
      } else if (value is Map) {
        sanitized[key] = sanitizeData(Map<String, dynamic>.from(value));
      } else if (value is List) {
        sanitized[key] = value.map((item) {
          if (item is Map) {
            return sanitizeData(Map<String, dynamic>.from(item));
          }
          if (item is String) {
            return sanitizeMessage(item);
          }
          return item;
        }).toList();
      } else if (value is String) {
        sanitized[key] = sanitizeMessage(value);
      } else {
        sanitized[key] = value;
      }
    });

    return sanitized;
  }
}
