import 'package:flutter/foundation.dart';

/// Resolves data conflicts between local SQLite and cloud Firestore.
/// Uses "Last Writer Wins" with version numbering.
class ConflictResolver {
  /// Resolve conflict between local and cloud data.
  static Map<String, dynamic>? resolve({
    required Map<String, dynamic> localData,
    required Map<String, dynamic> cloudData,
    String strategy = 'LWW',
  }) {
    switch (strategy) {
      case 'LWW':
        return _lastWriterWins(localData, cloudData);
      case 'LOCAL_FIRST':
        return localData;
      case 'CLOUD_FIRST':
        return cloudData;
      default:
        return _lastWriterWins(localData, cloudData);
    }
  }

  static Map<String, dynamic>? _lastWriterWins(
    Map<String, dynamic> localData,
    Map<String, dynamic> cloudData,
  ) {
    final localVersion = _extractVersion(localData);
    final cloudVersion = _extractVersion(cloudData);
    if (localVersion != cloudVersion) {
      return localVersion > cloudVersion ? localData : cloudData;
    }
    final localUpdated = _extractDateTime(localData['updatedAt']);
    final cloudUpdated = _extractDateTime(cloudData['updatedAt']);
    if (localUpdated != null && cloudUpdated != null) {
      return localUpdated.isAfter(cloudUpdated) ? localData : cloudData;
    }
    return cloudData;
  }

  static int _extractVersion(Map<String, dynamic> data) {
    final v = data['version'];
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 1;
    return 1;
  }

  static DateTime? _extractDateTime(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    try { return val.toDate(); } catch (_) { return null; }
  }

  /// Check data integrity between local and cloud.
  static Future<Map<String, String>> checkIntegrity({
    required Future<int> Function(String) getLocalCount,
    required Future<int> Function(String) getCloudCount,
    List<String> collections = const ['orders', 'inventory', 'customers'],
  }) async {
    final results = <String, String>{};
    for (var c in collections) {
      try {
        final l = await getLocalCount(c);
        final r = await getCloudCount(c);
        final d = (l - r).abs();
        results[c] = d == 0 ? 'Synced ($l)' : 'Mismatch (local:$l cloud:$r)';
      } catch (e) {
        results[c] = 'Error: $e';
      }
    }
    debugPrint('[ConflictResolver] Integrity: $results');
    return results;
  }
}
