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
}
