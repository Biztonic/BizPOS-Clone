import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Handles state-driven conflict resolution for sync operations.
///
/// Compares cloud versions/timestamps against local versions/timestamps
/// to decide which version "wins" during a pull operation.
///
/// Decouples versioning logic from the main sync orchestrator.
class ConflictEngine {
  
  /// Determines if the cloud version of a document should overwrite the local version.
  ///
  /// Logic:
  /// 1. If local status is PENDING or PUSHED, local "wins" (offline-first).
  /// 2. If cloud version > local version, cloud "wins".
  /// 3. If versions are equal, cloud updatedAt > local updatedAt, cloud "wins".
  bool shouldCloudWin({
    required Map<String, dynamic> cloudData,
    required Map<String, dynamic>? localData,
  }) {
    if (localData == null) return true;

    // 1. Check local sync status
    final localSyncStatus = localData['syncStatus']?.toString() ?? '';
    if (localSyncStatus == 'PENDING' || localSyncStatus == 'PUSHED') {
      return false; // Local has unsynced changes, preserve them.
    }

    // 2. Version-based comparison
    final int cloudVersion = _parseInt(cloudData['version'], 1);
    final int localVersion = _parseInt(localData['version'], 1);

    if (cloudVersion > localVersion) return true;
    if (cloudVersion < localVersion) return false;

    // 3. Timestamp-based comparison (fallback)
    final cloudUpdated = _parseDate(cloudData['updatedAt']);
    final localUpdated = _parseDate(localData['updatedAt']);

    if (cloudUpdated != null && localUpdated != null) {
      return cloudUpdated.isAfter(localUpdated);
    }

    // Default to cloud if everything else is equal or missing
    return true;
  }

  int _parseInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
