import 'package:biztonic_pos/sync/policy/plan_sync_policy.dart';

/// Centralized engine for subscription limits and platform restrictions.
///
/// Delegates to [PlanSyncPolicy] but provides a high-level interface
/// for the SyncService to check whether operations (like pulls or order creation)
/// are allowed under the current user's plan.
class LimitsEngine {
  final PlanSyncPolicy _policy;

  LimitsEngine({required PlanSyncPolicy policy}) : _policy = policy;

  /// Check if inbound sync is allowed based on plan and frequency.
  Future<bool> isPullAllowed({
    required String? storeId,
    required String? userRole,
    required String syncFrequency,
    required DateTime? lastSyncTime,
    required bool forceManual,
  }) async {
    return _policy.shouldPullInbound(
      storeId: storeId,
      userRole: userRole,
      syncFrequency: syncFrequency,
      lastSyncTime: lastSyncTime,
      forceManual: forceManual,
    );
  }

  /// Check if a new order can be created under the current limits.
  Future<void> validateOrderCreation({
    required String storeId,
    required String? userRole,
    required Future<Map<String, int>> Function(String storeId) getLocalOrderCounts,
  }) async {
    await _policy.checkOrderLimit(
      storeId: storeId,
      userRole: userRole,
      getLocalOrderCounts: getLocalOrderCounts,
    );
  }

  /// Returns the retention period (in days) for cloud data cleanup.
  Future<int?> getCloudRetentionDays(String storeId) async {
    final config = await _policy.getRetentionConfig(storeId);
    if (config['shouldCleanup'] == true) {
      return config['retentionDays'] as int;
    }
    return null;
  }

  /// Returns the human-readable plan name.
  Future<String> getPlanName(String? storeId) async {
    return _policy.getSubscriptionPlan(storeId);
  }

  // --- Synchronous throttle check for orchestrator ---
  
  bool _lastCanPull = true;
  String _lastThrottleReason = '';
  
  /// Synchronous check if pull sync is currently allowed.
  /// Updated asynchronously via [refreshThrottleState].
  bool canPullSync() => _lastCanPull;

  /// Reason for sync throttling (if canPullSync returns false).
  String get syncThrottleReason => _lastThrottleReason;

  /// Asynchronously refreshes the throttle state.
  /// Called before each sync cycle.
  Future<void> refreshThrottleState({
    required String? storeId,
    required String? userRole,
    required String syncFrequency,
    required DateTime? lastSyncTime,
  }) async {
    _lastCanPull = await isPullAllowed(
      storeId: storeId,
      userRole: userRole,
      syncFrequency: syncFrequency,
      lastSyncTime: lastSyncTime,
      forceManual: false,
    );
    if (!_lastCanPull) {
      _lastThrottleReason = 'Sync throttled by plan policy (frequency: $syncFrequency)';
    } else {
      _lastThrottleReason = '';
    }
  }
}
