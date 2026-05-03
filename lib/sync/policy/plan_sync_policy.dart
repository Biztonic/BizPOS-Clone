import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/sync/registry/sync_collection_registry.dart';

/// Encapsulates ALL subscription plan / throttling / limits logic.
///
/// This was previously scattered across `SyncService.processSync()`,
/// `_getSubscriptionPlan()`, `_hasDataCenterAddon()`, `checkOrderLimit()`,
/// and `_shouldPullBasedOnFrequency()` — totaling ~200 lines of plan-awareness
/// inside the sync orchestrator.
///
/// Now: SyncService calls `policy.shouldPullInbound(...)` and gets a boolean.
class PlanSyncPolicy {
  final FirebaseFirestore _db;

  PlanSyncPolicy({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ─── Cached State ──────────────────────────────────────────
  String? _cachedPlan;
  String? _cachedStoreId;
  Map<String, dynamic>? _cachedPlatformLimits;

  // ─── Core Decision: Should Inbound Pull Happen? ────────────

  /// Single decision point for whether inbound sync should pull data.
  ///
  /// Evaluates: plan tier, addon status, user role, sync frequency,
  /// and time since last sync.
  Future<bool> shouldPullInbound({
    required String? storeId,
    required String? userRole,
    required String syncFrequency,
    required DateTime? lastSyncTime,
    required bool forceManual,
  }) async {
    if (forceManual) return true;
    if (userRole == 'Super Admin') return true;
    if (storeId == null) return false;

    final plan = await getSubscriptionPlan(storeId);
    final hasAddon = await hasDataCenterAddon(storeId);

    // Starting Plan: no auto inbound pull (manual only)
    if (plan == 'Starting') return false;

    // Basic Plan without Data Center addon
    if (plan == 'Basic' && !hasAddon) {
      final limits = await retrievePlatformLimits();
      final freq = limits['sync_frequency_str'] ?? '1_DAY';
      return _shouldPullBasedOnFrequency(freq, lastSyncTime);
    }

    // Standard Plan without Data Center addon
    if (!hasAddon) {
      final limits = await retrievePlatformLimits();
      final freq = limits['sync_frequency_str'] ?? '1_DAY';
      return _shouldPullBasedOnFrequency(freq, lastSyncTime);
    }

    // Data Center Addon active
    if (syncFrequency == 'MANUAL') return false;
    if (syncFrequency == 'LIVE') return true;
    return _shouldPullBasedOnFrequency(syncFrequency, lastSyncTime);
  }

  // ─── Plan Queries ──────────────────────────────────────────

  /// Returns the subscription plan for a store.
  Future<String> getSubscriptionPlan(String? storeId) async {
    if (storeId == null) return 'Basic';

    // Return cached value if for the same store
    if (_cachedPlan != null && _cachedStoreId == storeId) {
      return _cachedPlan!;
    }

    try {
      final doc = await _db.collection(SyncCollectionRegistry.stores).doc(storeId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final plan = (data['subscriptionPlan'] ?? 'Basic').toString();
        _cachedPlan = plan;
        _cachedStoreId = storeId;
        return plan;
      }
      return 'Basic';
    } catch (e) {
      return 'Basic';
    }
  }

  /// Checks if the store has the Data Center addon active.
  Future<bool> hasDataCenterAddon(String? storeId) async {
    if (storeId == null) return false;
    try {
      // Try local cache first
      if (Hive.isBoxOpen('cache_stores')) {
        final box = Hive.box('cache_stores');
        final data = box.get('store_settings_$storeId') ?? box.get(storeId);
        if (data != null && data is Map) {
          final addons = (data['addons'] as List<dynamic>?)
                  ?.map((e) => e?.toString() ?? '')
                  .toList() ??
              [];
          return addons.contains('data_center');
        }
      }

      // Cloud fallback
      final doc = await _db.collection(SyncCollectionRegistry.stores).doc(storeId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final addons = (data['addons'] as List<dynamic>?)
                ?.map((e) => e?.toString() ?? '')
                .toList() ??
            [];
        return addons.contains('data_center');
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ─── Order Limits ──────────────────────────────────────────

  /// Checks if the store has exceeded its order limits.
  /// Throws an [Exception] if limits are breached.
  Future<void> checkOrderLimit({
    required String storeId,
    required String? userRole,
    required Future<Map<String, int>> Function(String storeId) getLocalOrderCounts,
  }) async {
    final plan = await getSubscriptionPlan(storeId);

    // Unlimited plans
    if (plan == 'Starting' || plan == 'Standard' || userRole == 'Super Admin') return;

    // Basic Plan (Limited)
    final limits = await retrievePlatformLimits();
    int dailyLimit = limits['daily'] ?? 50;
    int monthlyLimit = limits['monthly'] ?? 1500;

    final counts = await getLocalOrderCounts(storeId);
    final dailyCount = counts['daily'] ?? 0;
    final monthlyCount = counts['monthly'] ?? 0;

    if (dailyCount >= dailyLimit) {
      throw Exception(
          "Daily Order Limit Reached ($dailyCount/$dailyLimit). Upgrade to 'Standard Plan' for Unlimited Orders.");
    }
    if (monthlyCount >= monthlyLimit) {
      throw Exception(
          "Monthly Order Limit Reached ($monthlyCount/$monthlyLimit). Upgrade to 'Standard Plan' for Unlimited Orders.");
    }
  }

  // ─── Retention Policy ──────────────────────────────────────

  /// Returns retention configuration for a given store.
  Future<Map<String, dynamic>> getRetentionConfig(String storeId) async {
    final plan = await getSubscriptionPlan(storeId);
    final limits = await retrievePlatformLimits();

    return {
      'shouldCleanup': plan == 'Basic',
      'retentionDays': limits['cloud_retention_days'] ?? 30,
    };
  }

  // ─── Platform Limits ──────────────────────────────────────

  /// Retrieves platform-wide limits with cache-first strategy.
  Future<Map<String, dynamic>> retrievePlatformLimits() async {
    // 1. Memory cache
    if (_cachedPlatformLimits != null) return _cachedPlatformLimits!;

    // 2. Hive cache
    if (Hive.isBoxOpen(SyncCollectionRegistry.boxSettingsGeneral)) {
      final box = Hive.box(SyncCollectionRegistry.boxSettingsGeneral);
      final val = box.get('platform_limits');
      if (val != null && val is Map) {
        _cachedPlatformLimits = _parseLimitsFromCache(val);
        return _cachedPlatformLimits!;
      }
    }

    // 3. Cloud fetch
    try {
      final doc = await _db
          .collection(SyncCollectionRegistry.settings)
          .doc(SyncCollectionRegistry.platformLimits)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final limits = _parseLimitsFromCloud(data);
        _cachedPlatformLimits = limits;
        // Persist to Hive
        await _updateLimitsCache(limits);
        return limits;
      }
    } catch (e) {
      debugPrint('⚠️ PlanSyncPolicy: Failed to fetch platform limits: $e');
    }

    // 4. Defaults
    _cachedPlatformLimits = _defaultLimits;
    return _cachedPlatformLimits!;
  }

  /// Clears plan cache (e.g., on store change).
  void clearCache() {
    _cachedPlan = null;
    _cachedStoreId = null;
    _cachedPlatformLimits = null;
  }

  /// Updates the platform limits cache (called from SyncService for backward compat).
  Future<void> updatePlatformLimitsCache(Map<String, dynamic> limits) async {
    _cachedPlatformLimits = limits;
    await _updateLimitsCache(limits);
  }

  // ─── Private Helpers ───────────────────────────────────────

  bool _shouldPullBasedOnFrequency(String freq, DateTime? lastSyncTime) {
    if (lastSyncTime == null) return true;
    final diff = DateTime.now().difference(lastSyncTime);
    if (freq == '1_DAY' || freq == 'DAILY') return diff.inHours >= 24;
    if (freq == '1_WEEK' || freq == 'WEEKLY') return diff.inDays >= 7;
    if (freq == '1_MONTH') return diff.inDays >= 30;
    return true; // Unknown frequency = pull
  }

  Future<void> _updateLimitsCache(Map<String, dynamic> limits) async {
    if (Hive.isBoxOpen(SyncCollectionRegistry.boxSettingsGeneral)) {
      await Hive.box(SyncCollectionRegistry.boxSettingsGeneral)
          .put('platform_limits', limits);
    }
  }

  Map<String, dynamic> _parseLimitsFromCache(Map val) {
    return {
      'daily': val['daily'] ?? 50,
      'monthly': val['monthly'] ?? 1500,
      'rate_customer_management': val['rate_customer_management'] ?? 0,
      'rate_franchise_management': val['rate_franchise_management'] ?? 0,
      'rate_central_catalog': val['rate_central_catalog'] ?? 0,
      'rate_employee_management': val['rate_employee_management'] ?? 0,
      'rate_supplier_management': val['rate_supplier_management'] ?? 0,
      'rate_kds_management': val['rate_kds_management'] ?? 0,
      'rate_table_reservation': val['rate_table_reservation'] ?? 0,
      'rate_data_center': val['rate_data_center'] ?? 0,
      'rate_integration_hub': val['rate_integration_hub'] ?? 0,
      'sync_frequency_str': (val['sync_frequency_str'] ?? '1_DAY').toString(),
      'cloud_retention_days': val['cloud_retention_days'] ?? 30,
    };
  }

  Map<String, dynamic> _parseLimitsFromCloud(Map<String, dynamic> data) {
    return {
      'daily': _parseLimit(data['daily'] ?? data['maxOrdersPerDay'], 2000),
      'monthly': _parseLimit(data['monthly'] ?? data['maxOrdersPerMonth'], 50000),
      'rate_customer_management': (data['rate_customer_management'] ?? 0) as num,
      'rate_franchise_management': (data['rate_franchise_management'] ?? 0) as num,
      'rate_central_catalog': (data['rate_central_catalog'] ?? 0) as num,
      'rate_employee_management': (data['rate_employee_management'] ?? 0) as num,
      'rate_supplier_management': (data['rate_supplier_management'] ?? 0) as num,
      'rate_kds_management': (data['rate_kds_management'] ?? 0) as num,
      'rate_table_reservation': (data['rate_table_reservation'] ?? 0) as num,
      'rate_data_center': (data['rate_data_center'] ?? 0) as num,
      'rate_integration_hub': (data['rate_integration_hub'] ?? 0) as num,
      'sync_frequency_str': (data['sync_frequency'] ?? '1_DAY').toString(),
      'cloud_retention_days': _parseLimit(data['cloud_retention_days'], 30),
    };
  }

  static const Map<String, dynamic> _defaultLimits = {
    'daily': 2000,
    'monthly': 50000,
    'rate_customer_management': 0,
    'rate_franchise_management': 0,
    'rate_central_catalog': 0,
    'rate_employee_management': 0,
    'rate_supplier_management': 0,
    'rate_kds_management': 0,
    'rate_table_reservation': 0,
    'rate_data_center': 0,
  };

  int _parseLimit(dynamic v, int fallback) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}
