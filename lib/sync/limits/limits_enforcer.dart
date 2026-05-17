import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/core/config/plan_config.dart';
import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';

/// Enforces subscription plan limits (order counts, inventory limits, etc.)
///
/// Extracted from SyncService.checkOrderLimit, retrievePlatformLimits,
/// _getLocalOrderCounts, _getSubscriptionPlan, _hasDataCenterAddon.
class LimitsEnforcer {
  final Repository Function() getRepository;
  final String? Function() getActiveStoreId;
  final Future<void> Function(String message, {bool isError}) logEvent;

  // Cached values
  Map<String, dynamic>? _cachedPlatformLimits;
  String? _cachedSubscriptionPlan;

  Map<String, dynamic> get platformLimits => _cachedPlatformLimits ?? {};
  String? get cachedSubscriptionPlan => _cachedSubscriptionPlan;

  // Order count state (exposed for UI)
  int _todayOrderCount = 0;
  int _monthlyOrderCount = 0;
  int _totalOrderCount = 0;
  int _dailyLimit = 0;
  int _monthlyLimit = 0;
  bool _isLimitReached = false;

  int get todayOrderCount => _todayOrderCount;
  int get monthlyOrderCount => _monthlyOrderCount;
  int get totalOrderCount => _totalOrderCount;
  int get dailyLimit => _dailyLimit;
  int get monthlyLimit => _monthlyLimit;
  bool get isLimitReached => _isLimitReached;

  LimitsEnforcer({
    required this.getRepository,
    required this.getActiveStoreId,
    required this.logEvent,
  });

  /// Check order limits for the current store/plan.
  /// Fires [PlanLimitReachedEvent] if limit is reached.
  Future<void> checkOrderLimit(String storeId) async {
    try {
      final plan = _cachedSubscriptionPlan ?? 'Basic';
      final limits = _cachedPlatformLimits ?? {};

      // Get configured limits
      _dailyLimit = _extractLimit(limits, 'dailyOrderLimit');
      _monthlyLimit = _extractLimit(limits, 'monthlyOrderLimit');

      // Fall back to plan defaults if not configured
      if (_dailyLimit <= 0) {
        _dailyLimit = PlanConfig.getLimit(plan, 'orders');
      }

      // Get actual counts from SQLite
      final counts = await _getLocalOrderCounts(storeId);
      _todayOrderCount = counts['today'] ?? 0;
      _monthlyOrderCount = counts['monthly'] ?? 0;
      _totalOrderCount = counts['total'] ?? 0;

      // Check limits
      _isLimitReached = false;

      if (_dailyLimit > 0 && _todayOrderCount >= _dailyLimit) {
        _isLimitReached = true;
        EventBus.instance.fire(PlanLimitReachedEvent(
          storeId: storeId,
          limitType: 'orders',
          currentCount: _todayOrderCount,
          maxAllowed: _dailyLimit,
        ));
      }

      if (_monthlyLimit > 0 && _monthlyOrderCount >= _monthlyLimit) {
        _isLimitReached = true;
        EventBus.instance.fire(PlanLimitReachedEvent(
          storeId: storeId,
          limitType: 'orders',
          currentCount: _monthlyOrderCount,
          maxAllowed: _monthlyLimit,
        ));
      }

      debugPrint('📊 [LimitsEnforcer] Plan: $plan | Today: $_todayOrderCount/$_dailyLimit | Month: $_monthlyOrderCount/$_monthlyLimit');
    } catch (e) {
      debugPrint('📊 [LimitsEnforcer] Error checking limits: $e');
    }
  }

  /// Get local order counts from SQLite grouped by time period.
  Future<Map<String, int>> _getLocalOrderCounts(String storeId) async {
    try {
      final repo = getRepository();
      final db = await repo.database;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final monthStart = DateTime(now.year, now.month, 1).toIso8601String();

      // Single query with conditional counting
      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) as total,
          SUM(CASE WHEN date >= ? THEN 1 ELSE 0 END) as today,
          SUM(CASE WHEN date >= ? THEN 1 ELSE 0 END) as monthly
        FROM orders 
        WHERE storeId = ? 
          AND status NOT IN ('VOID', 'Cancelled')
          AND (syncStatus IS NULL OR syncStatus != 'DELETED')
      ''', [todayStart, monthStart, storeId]);

      if (result.isNotEmpty) {
        return {
          'today': (result.first['today'] as int?) ?? 0,
          'monthly': (result.first['monthly'] as int?) ?? 0,
          'total': (result.first['total'] as int?) ?? 0,
        };
      }

      return {'today': 0, 'monthly': 0, 'total': 0};
    } catch (e) {
      debugPrint('📊 [LimitsEnforcer] Error getting counts: $e');
      return {'today': 0, 'monthly': 0, 'total': 0};
    }
  }

  /// Update cached platform limits.
  void updatePlatformLimits(Map<String, dynamic> limits) {
    _cachedPlatformLimits = limits;
  }

  /// Update cached subscription plan.
  void updateSubscriptionPlan(String plan) {
    _cachedSubscriptionPlan = plan;
  }

  /// Check if a feature is available under the current plan.
  bool isFeatureAvailable(String feature) {
    final plan = _cachedSubscriptionPlan ?? 'Basic';
    return PlanConfig.isFeatureAvailable(plan, feature);
  }

  int _extractLimit(Map<String, dynamic> limits, String key) {
    final val = limits[key];
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }
}
