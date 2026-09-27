import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/services/firestore_helper.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_model.dart';
import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';
import 'package:biztonic_pos/core/diagnostics/diagnostics_models.dart';
import 'package:biztonic_pos/core/diagnostics/diagnostics_service.dart';
import 'package:biztonic_pos/core/audit/audit_models.dart';
import 'package:biztonic_pos/core/audit/audit_service.dart';

/// Authoritative single source of truth for subscription plans,
/// feature flags, quotas, addons, and offline lifecycle enforcement.
class EntitlementService {
  static final EntitlementService _instance = EntitlementService._internal();
  static EntitlementService get instance => _instance;

  EntitlementService._internal();

  factory EntitlementService({
    FirebaseFirestore? db,
    Repository? repository,
  }) {
    if (db != null) _instance._dbOverride = db;
    if (repository != null) _instance._repoOverride = repository;
    return _instance;
  }

  static const String boxName = 'entitlements_v1';

  FirebaseFirestore? _dbOverride;
  Repository? _repoOverride;

  FirebaseFirestore get _db => _dbOverride ?? getFirestore();
  Repository get _repo => _repoOverride ?? Repository();

  final Map<String, StoreEntitlement> _memoryCache = {};

  /// Predefined features per plan tier.
  /// Note: Modular BizStore addons (table_reservation, data_center, kds_management,
  /// employee_management, supplier_management, customer_management, integration_hub,
  /// franchise_management, central_catalog, loyalty_program) are NOT in defaultPlanFeatures
  /// for Basic/Standard/Professional — they must be explicitly present in store.addons.
  static const Map<PlanTier, Set<String>> defaultPlanFeatures = {
    PlanTier.starting: {
      'dashboard',
      'pos',
      'billing',
      'inventory',
      'basic_inventory',
      'reports',
      'basic_reports',
      'sales',
      'orders',
      'settings',
      'biz_store',
    },
    PlanTier.basic: {
      'dashboard',
      'pos',
      'billing',
      'inventory',
      'basic_inventory',
      'reports',
      'basic_reports',
      'sales',
      'orders',
      'settings',
      'biz_store',
    },
    PlanTier.standard: {
      'dashboard',
      'pos',
      'billing',
      'inventory',
      'basic_inventory',
      'reports',
      'basic_reports',
      'sales',
      'orders',
      'settings',
      'biz_store',
    },
    PlanTier.professional: {
      'dashboard',
      'pos',
      'billing',
      'inventory',
      'basic_inventory',
      'reports',
      'basic_reports',
      'sales',
      'orders',
      'advanced_reports',
      'multi_store',
      'api_access',
      'settings',
      'biz_store',
    },
    PlanTier.enterprise: {'*'},
  };

  /// Predefined limits per plan tier.
  static const Map<PlanTier, Map<String, int>> defaultPlanLimits = {
    PlanTier.starting: {
      'orders': 50,
      'dailyOrders': 20,
      'monthlyOrders': 50,
      'inventory': 30,
      'customers': 20,
      'employees': 2,
      'stores': 1,
    },
    PlanTier.basic: {
      'orders': 500,
      'dailyOrders': 50,
      'monthlyOrders': 1500,
      'inventory': 200,
      'customers': 100,
      'employees': 5,
      'stores': 1,
    },
    PlanTier.standard: {
      'orders': -1, // Unlimited
      'dailyOrders': -1,
      'monthlyOrders': -1,
      'inventory': -1,
      'customers': -1,
      'employees': 15,
      'stores': 3,
    },
    PlanTier.professional: {
      'orders': -1,
      'dailyOrders': -1,
      'monthlyOrders': -1,
      'inventory': -1,
      'customers': -1,
      'employees': -1,
      'stores': 10,
    },
    PlanTier.enterprise: {
      'orders': -1,
      'dailyOrders': -1,
      'monthlyOrders': -1,
      'inventory': -1,
      'customers': -1,
      'employees': -1,
      'stores': -1,
    },
  };

  // ─────────────────────────────────────────────────────────────
  // INITIALIZATION & CACHE
  // ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      try {
        await Hive.openBox(boxName);
      } catch (e) {
        debugPrint(
            '⚠️ [EntitlementService] Failed to open Hive box $boxName: $e');
      }
    }
  }

  /// Evaluates and resolves the authoritative entitlement for a store.
  StoreEntitlement getEntitlement(String storeId) {
    if (storeId.isEmpty) {
      return _buildDefaultEntitlement('global');
    }

    // 1. Memory Cache
    if (_memoryCache.containsKey(storeId)) {
      return evaluateStatus(_memoryCache[storeId]!);
    }

    // 2. Persistent Hive Cache
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box(boxName);
      final raw = box.get(storeId);
      if (raw is Map) {
        final cached = StoreEntitlement.fromMap(raw);
        // Anti-Bypass: verify cryptographic tamper hash
        if (cached.verifyIntegrity()) {
          final evaluated = evaluateStatus(cached);
          _memoryCache[storeId] = evaluated;
          return evaluated;
        } else {
          debugPrint(
              '🚨 [EntitlementService] Tamper detected in entitlement cache for store $storeId! Falling back to safe default.');
        }
      }
    }

    // 3. Fallback safe baseline
    final fallback = _buildDefaultEntitlement(storeId);
    _memoryCache[storeId] = fallback;
    return fallback;
  }

  /// Re-evaluates plan status according to current date, end date, and grace days.
  StoreEntitlement evaluateStatus(StoreEntitlement entitlement) {
    // Administratively fixed states
    if (entitlement.status == PlanStatus.suspended ||
        entitlement.status == PlanStatus.cancelled) {
      return entitlement;
    }

    if (entitlement.endDate == null) {
      return entitlement;
    }

    final now = DateTime.now();
    if (now.isBefore(entitlement.endDate!)) {
      if (entitlement.status != PlanStatus.active &&
          entitlement.status != PlanStatus.trial) {
        return entitlement.copyWith(status: PlanStatus.active);
      }
      return entitlement;
    }

    // Expiry date reached -> evaluate grace period
    final graceCutoff =
        entitlement.endDate!.add(Duration(days: entitlement.gracePeriodDays));
    if (now.isBefore(graceCutoff)) {
      if (entitlement.status != PlanStatus.grace) {
        return entitlement.copyWith(status: PlanStatus.grace);
      }
      return entitlement;
    }

    // Grace period exceeded -> EXPIRED
    if (entitlement.status != PlanStatus.expired) {
      return entitlement.copyWith(status: PlanStatus.expired);
    }

    return entitlement;
  }

  /// Updates or sets entitlement locally (e.g. after cloud pull or admin approval).
  Future<void> updateEntitlement(StoreEntitlement entitlement) async {
    final verified = entitlement.verifyIntegrity()
        ? entitlement
        : StoreEntitlement.create(
            storeId: entitlement.storeId,
            plan: entitlement.plan,
            status: entitlement.status,
            startDate: entitlement.startDate,
            endDate: entitlement.endDate,
            gracePeriodDays: entitlement.gracePeriodDays,
            addons: entitlement.addons,
            purchasedAddons: entitlement.purchasedAddons,
            limits: entitlement.limits,
            features: entitlement.features,
            version: entitlement.version,
            serverTimestamp: entitlement.serverTimestamp,
          );

    _memoryCache[entitlement.storeId] = verified;

    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box(boxName);
      await box.put(entitlement.storeId, verified.toMap());
    }
  }

  /// Synchronizes or updates the authoritative entitlement from store entity fields.
  Future<void> syncFromStore({
    required String storeId,
    required String planName,
    required String status,
    required List<String> addons,
    List<String>? purchasedAddons,
    DateTime? startDate,
    DateTime? endDate,
    bool fromServer = false,
  }) async {
    if (storeId.isEmpty) return;
    final tier = PlanTier.fromString(planName);
    final planStat = PlanStatus.fromString(status);
    final current = getEntitlement(storeId);

    final bool trustIncoming = fromServer || purchasedAddons != null;

    // Defensive Anti-Tamper check:
    // If incoming local plan is higher than current verified plan, do NOT elevate without server verification
    final effectiveTier = trustIncoming
        ? tier
        : ((current.plan.index >= tier.index || current.version == 1)
            ? tier
            : current.plan);

    final effectivePurchased = trustIncoming
        ? <String>{
            if (purchasedAddons != null) ...purchasedAddons,
            if (purchasedAddons == null && fromServer) ...addons,
          }
        : current.purchasedAddons;

    // Only enable addons that are both installed on the store (`addons`) and purchased (`effectivePurchased`),
    // unless the store is on the Enterprise tier.
    final Set<String> effectiveAddons = (effectiveTier == PlanTier.enterprise)
        ? addons.toSet()
        : (trustIncoming
            ? addons.where((a) => effectivePurchased.contains(a)).toSet()
            : addons.where((a) => current.isAddonAllowed(a)).toSet());

    final entitlement = StoreEntitlement.create(
      storeId: storeId,
      plan: effectiveTier,
      status: planStat,
      startDate: startDate ?? current.startDate ?? DateTime.now(),
      endDate: endDate ?? current.endDate,
      gracePeriodDays: current.gracePeriodDays,
      addons: effectiveAddons,
      purchasedAddons: effectivePurchased,
      limits: defaultPlanLimits[effectiveTier] ??
          defaultPlanLimits[PlanTier.basic]!,
      features: defaultPlanFeatures[effectiveTier] ??
          defaultPlanFeatures[PlanTier.basic]!,
      version: current.version + 1,
    );

    await updateEntitlement(entitlement);
  }

  /// Sets an in-memory entitlement directly (useful for tests or immediate state propagation).
  void registerInMemory(StoreEntitlement entitlement) {
    _memoryCache[entitlement.storeId] = entitlement;
  }

  // ─────────────────────────────────────────────────────────────
  // AUTHORITATIVE DECISION METHODS
  // ─────────────────────────────────────────────────────────────

  /// Returns the current plan tier for a store.
  PlanTier currentPlan(String storeId) => getEntitlement(storeId).plan;

  /// Returns human-readable plan name.
  String planName(String storeId) => currentPlan(storeId).value;

  /// Returns the current lifecycle status for a store.
  PlanStatus planStatus(String storeId) => getEntitlement(storeId).status;

  /// Whether the store currently has an active subscription or is within grace period.
  bool isSubscribed(String storeId) {
    final status = planStatus(storeId);
    return status == PlanStatus.active ||
        status == PlanStatus.trial ||
        status == PlanStatus.grace;
  }

  static const Map<String, Set<String>> _featureAliases = {
    'crm': {'crm', 'customer_management', 'customers'},
    'customer_management': {'crm', 'customer_management', 'customers'},
    'customers': {'crm', 'customer_management', 'customers'},
    'employees': {'employees', 'employee_management'},
    'employee_management': {'employees', 'employee_management'},
    'kds': {'kds', 'kds_management'},
    'kds_management': {'kds', 'kds_management'},
    'tables': {'tables', 'table_reservation'},
    'table_reservation': {'tables', 'table_reservation'},
    'suppliers': {'suppliers', 'supplier_management'},
    'supplier_management': {'suppliers', 'supplier_management'},
    'franchise': {'franchise', 'franchise_management'},
    'franchise_management': {'franchise', 'franchise_management'},
    'inventory': {'inventory', 'inventory_management', 'basic_inventory'},
    'inventory_management': {
      'inventory',
      'inventory_management',
      'basic_inventory'
    },
    'pos': {'pos', 'billing'},
    'billing': {'pos', 'billing'},
    'reports': {'reports', 'basic_reports', 'advanced_reports'},
    'basic_reports': {'reports', 'basic_reports', 'advanced_reports'},
  };

  static const Set<String> _allAddonKeys = {
    'crm',
    'customer_management',
    'customers',
    'employees',
    'employee_management',
    'kds',
    'kds_management',
    'tables',
    'table_reservation',
    'suppliers',
    'supplier_management',
    'franchise',
    'franchise_management',
    'data_center',
    'integration_hub',
    'central_catalog',
    'loyalty_program',
    'barcode_scanner',
  };

  /// Normalizes any addon alias to its canonical addon key.
  static String canonicalizeAddonKey(String key) {
    final clean = key.trim().toLowerCase();
    if (clean.isEmpty) return '';
    switch (clean) {
      case 'crm':
      case 'customers':
      case 'customer_management':
        return 'customer_management';
      case 'employees':
      case 'staff':
      case 'employee_management':
        return 'employee_management';
      case 'kds':
      case 'kds_management':
        return 'kds_management';
      case 'tables':
      case 'floors':
      case 'table_management':
      case 'table_reservation':
        return 'table_reservation';
      case 'suppliers':
      case 'supplier_management':
        return 'supplier_management';
      case 'franchise':
      case 'franchise_management':
        return 'franchise_management';
      case 'data_sync':
      case 'cloud_sync':
      case 'data_center':
        return 'data_center';
      default:
        return clean;
    }
  }

  /// Authoritative check for whether an addon is enabled.
  bool hasAddon(String addonKey, {required String storeId}) {
    if (storeId.isEmpty) return false;
    final entitlement = getEntitlement(storeId);
    if (!entitlement.isUsable) return false;

    // Enterprise tier unlocks all addons
    if (entitlement.plan == PlanTier.enterprise ||
        entitlement.features.contains('*')) {
      return true;
    }

    final aliases = _featureAliases[addonKey] ?? {addonKey};
    final isInstalled = aliases.any((k) => entitlement.addons.contains(k));
    final isPurchased =
        aliases.any((k) => entitlement.purchasedAddons.contains(k));

    if (isInstalled && isPurchased) {
      return true;
    }

    return false;
  }

  /// Authoritative check for whether a feature is unlocked.
  bool isFeatureEnabled(
    String featureKey, {
    required String storeId,
    String? userRole,
  }) {
    // Super Admin has global override access
    if (userRole == 'Super Admin') return true;

    final entitlement = getEntitlement(storeId);
    if (entitlement.isSuspended || entitlement.isExpired) return false;

    // Core navigation features and core sub-sections are always unlocked for any usable plan
    const coreFeatures = {
      'dashboard',
      'pos',
      'billing',
      'inventory',
      'basic_inventory',
      'reports',
      'basic_reports',
      'sales',
      'orders',
      'settings',
      'biz_store',
    };
    if (coreFeatures.contains(featureKey) ||
        featureKey.startsWith('settings.') ||
        featureKey.startsWith('dashboard.') ||
        featureKey.startsWith('card.') ||
        featureKey.startsWith('feature.pos.')) {
      return true;
    }

    // Enterprise unlocks all
    if (entitlement.features.contains('*') ||
        entitlement.plan == PlanTier.enterprise) {
      return true;
    }

    // Modular BizStore addons strictly require hasAddon (Standard+ plan & installed addon)
    if (_allAddonKeys.contains(featureKey)) {
      return hasAddon(featureKey, storeId: storeId);
    }

    final aliases = _featureAliases[featureKey] ?? {featureKey};
    for (final k in aliases) {
      if (entitlement.features.contains(k)) {
        return true;
      }
    }

    return false;
  }

  /// Authoritative action gatekeeper.
  ///
  /// Replaces all legacy mocks (`canPerformAction` -> true).
  bool canPerformAction(
    String action, {
    required String storeId,
    int? currentCount,
  }) {
    final entitlement = getEntitlement(storeId);

    // 1. Suspended or Cancelled stores cannot perform mutations
    if (entitlement.status == PlanStatus.suspended ||
        entitlement.status == PlanStatus.cancelled) {
      return false;
    }

    // 2. Expired past grace period
    if (entitlement.status == PlanStatus.expired) {
      return false;
    }

    // 3. Quota evaluation for restricted resources
    switch (action.toLowerCase()) {
      case 'create_order':
      case 'sale':
      case 'orders':
        final limit = entitlement.limits['orders'] ?? -1;
        if (limit != -1 && currentCount != null && currentCount >= limit) {
          return false;
        }
        return true;

      case 'add_inventory':
      case 'inventory':
        final limit = entitlement.limits['inventory'] ?? -1;
        if (limit != -1 && currentCount != null && currentCount >= limit) {
          return false;
        }
        return true;

      case 'add_customer':
      case 'customers':
        final limit = entitlement.limits['customers'] ?? -1;
        if (limit != -1 && currentCount != null && currentCount >= limit) {
          return false;
        }
        return true;

      case 'add_employee':
      case 'employees':
        final limit = entitlement.limits['employees'] ?? -1;
        if (limit != -1 && currentCount != null && currentCount >= limit) {
          return false;
        }
        return true;

      case 'sync_cloud':
      case 'data_center':
        if (entitlement.plan == PlanTier.starting) return false;
        if (entitlement.plan == PlanTier.basic &&
            !entitlement.addons.contains('data_center')) {
          return false;
        }
        return true;

      default:
        return isFeatureEnabled(action, storeId: storeId);
    }
  }

  /// Descriptive reason for why an action is restricted.
  String getBlockReason(String action, {required String storeId}) {
    final entitlement = getEntitlement(storeId);

    if (entitlement.status == PlanStatus.suspended) {
      return "Store account is suspended. Please contact platform support.";
    }
    if (entitlement.status == PlanStatus.cancelled) {
      return "Subscription was cancelled. Please reactivate your store.";
    }
    if (entitlement.status == PlanStatus.expired) {
      return "Subscription has expired. Please renew your plan to continue.";
    }

    switch (action.toLowerCase()) {
      case 'create_order':
      case 'sale':
      case 'orders':
        final limit = entitlement.limits['orders'] ?? -1;
        return "Order limit reached ($limit max). Upgrade to Standard plan for unlimited orders.";

      case 'add_inventory':
      case 'inventory':
        final limit = entitlement.limits['inventory'] ?? -1;
        return "Catalog limit reached ($limit items max). Upgrade your plan to add more products.";

      case 'add_customer':
      case 'customers':
        final limit = entitlement.limits['customers'] ?? -1;
        return "Customer quota reached ($limit max). Upgrade your plan to expand CRM capacity.";

      case 'add_employee':
      case 'employees':
        final limit = entitlement.limits['employees'] ?? -1;
        return "Employee staff limit reached ($limit accounts max).";

      case 'sync_cloud':
      case 'data_center':
        return "Live Cloud Sync requires 'Data Center' addon or Standard plan.";

      default:
        return "Feature '${action.toUpperCase()}' is not included in your ${entitlement.plan.value} plan.";
    }
  }

  /// Verifies daily and monthly order quota from local counters.
  /// Throws [PlanLimitExceededException] if limits are breached.
  Future<void> checkOrderLimit(String storeId) async {
    return await DiagnosticsService().trace<void>(
      subsystem: DiagnosticSubsystem.subscription,
      operationId: 'subscription_quota_check',
      storeId: storeId,
      actionName: 'Subscription Quota Check',
      customErrorClassifier: (_) => DiagnosticErrorCategory.permissionError,
      operation: () => _checkOrderLimitInternal(storeId),
    );
  }

  Future<void> _checkOrderLimitInternal(String storeId) async {
    final entitlement = getEntitlement(storeId);

    if (entitlement.isSuspended) {
      throw PlanLimitExceededException("Store account suspended");
    }
    if (entitlement.isExpired) {
      throw PlanLimitExceededException("Subscription expired");
    }

    // Unlimited on Standard, Professional, and Enterprise
    if (entitlement.plan == PlanTier.standard ||
        entitlement.plan == PlanTier.professional ||
        entitlement.plan == PlanTier.enterprise) {
      return;
    }

    final dailyLimit = entitlement.limits['dailyOrders'] ?? 50;
    final monthlyLimit = entitlement.limits['monthlyOrders'] ?? 1500;

    final counts = await _getLocalOrderCounts(storeId);
    final dailyCount = counts['daily'] ?? 0;
    final monthlyCount = counts['monthly'] ?? 0;

    if (dailyLimit > 0 && dailyCount >= dailyLimit) {
      EventBus.instance.fire(PlanLimitReachedEvent(
        storeId: storeId,
        limitType: 'DAILY_ORDER_LIMIT',
        currentCount: dailyCount,
        maxAllowed: dailyLimit,
      ));
      throw PlanLimitExceededException(
          "Daily Order Limit Reached ($dailyCount/$dailyLimit). Upgrade to Standard Plan.");
    }

    if (monthlyLimit > 0 && monthlyCount >= monthlyLimit) {
      EventBus.instance.fire(PlanLimitReachedEvent(
        storeId: storeId,
        limitType: 'MONTHLY_ORDER_LIMIT',
        currentCount: monthlyCount,
        maxAllowed: monthlyLimit,
      ));
      throw PlanLimitExceededException(
          "Monthly Order Limit Reached ($monthlyCount/$monthlyLimit). Upgrade to Standard Plan.");
    }
  }

  /// Verifies inventory quota against plan limits.
  /// Throws [PlanLimitExceededException] if inventory limit is reached.
  Future<void> checkInventoryQuota(String storeId, {int? currentCount}) async {
    final entitlement = getEntitlement(storeId);
    if (entitlement.isSuspended) {
      throw PlanLimitExceededException("Store account suspended");
    }
    if (entitlement.isExpired) {
      throw PlanLimitExceededException("Subscription expired");
    }
    final limit = entitlement.limits['inventory'] ?? -1;
    if (limit == -1) return;

    final count = currentCount ?? await _repo.getInventoryCount(storeId);
    if (count >= limit) {
      EventBus.instance.fire(PlanLimitReachedEvent(
        storeId: storeId,
        limitType: 'INVENTORY_LIMIT',
        currentCount: count,
        maxAllowed: limit,
      ));
      throw PlanLimitExceededException(
          "Catalog limit reached ($count/$limit items). Upgrade your plan to add more products.");
    }
  }

  /// Verifies customer quota against plan limits.
  /// Throws [PlanLimitExceededException] if customer limit is reached.
  Future<void> checkCustomerQuota(String storeId, {int? currentCount}) async {
    final entitlement = getEntitlement(storeId);
    if (entitlement.isSuspended) {
      throw PlanLimitExceededException("Store account suspended");
    }
    if (entitlement.isExpired) {
      throw PlanLimitExceededException("Subscription expired");
    }
    final limit = entitlement.limits['customers'] ?? -1;
    if (limit == -1) return;

    final count = currentCount ?? await _repo.getCustomerCount(storeId);
    if (count >= limit) {
      EventBus.instance.fire(PlanLimitReachedEvent(
        storeId: storeId,
        limitType: 'CUSTOMER_LIMIT',
        currentCount: count,
        maxAllowed: limit,
      ));
      throw PlanLimitExceededException(
          "Customer quota reached ($count/$limit customers). Upgrade your plan to expand CRM capacity.");
    }
  }

  /// Verifies employee quota against plan limits.
  /// Throws [PlanLimitExceededException] if employee limit is reached.
  Future<void> checkEmployeeQuota(String storeId, {int? currentCount}) async {
    final entitlement = getEntitlement(storeId);
    if (entitlement.isSuspended) {
      throw PlanLimitExceededException("Store account suspended");
    }
    if (entitlement.isExpired) {
      throw PlanLimitExceededException("Subscription expired");
    }
    final limit = entitlement.limits['employees'] ?? -1;
    if (limit == -1) return;

    final count = currentCount ?? await _repo.getEmployeeCount(storeId);
    if (count >= limit) {
      EventBus.instance.fire(PlanLimitReachedEvent(
        storeId: storeId,
        limitType: 'EMPLOYEE_LIMIT',
        currentCount: count,
        maxAllowed: limit,
      ));
      throw PlanLimitExceededException(
          "Employee quota reached ($count/$limit staff accounts). Upgrade your plan to add more staff.");
    }
  }

  // ─────────────────────────────────────────────────────────────
  // AUDIT & SUBSCRIPTION MANAGEMENT
  // ─────────────────────────────────────────────────────────────

  /// Records an immutable audit entry whenever subscription or entitlements change.
  Future<void> auditSubscriptionChange({
    required String storeId,
    required PlanTier oldPlan,
    required PlanTier newPlan,
    required PlanStatus oldStatus,
    required PlanStatus newStatus,
    required String changedBy,
    String? reason,
    List<String>? addedAddons,
    List<String>? removedAddons,
  }) async {
    final eventId = 'sub_evt_${const Uuid().v4()}';
    final now = DateTime.now();

    // 1. Record in local SQLite business_events
    try {
      final db = await _repo.dbHelper.database;
      await db.insert('business_events', {
        'id': eventId,
        'storeId': storeId,
        'entityType': 'SUBSCRIPTION',
        'entityId': storeId,
        'eventType': 'SUBSCRIPTION_CHANGED',
        'amount': 0.0,
        'quantity': 1,
        'createdAt': now.toIso8601String(),
        'deviceId': 'SYSTEM',
        'synced': 0,
      });
    } catch (e) {
      debugPrint('⚠️ [EntitlementService] SQLite audit failed: $e');
    }

    // 2. Append to Firestore subscription_history if online
    try {
      await _db
          .collection('stores')
          .doc(storeId)
          .collection('subscription_history')
          .add({
        'eventId': eventId,
        'oldPlan': oldPlan.value,
        'newPlan': newPlan.value,
        'oldStatus': oldStatus.value,
        'newStatus': newStatus.value,
        'changedBy': changedBy,
        'reason': reason ?? 'Admin subscription modification',
        'addedAddons': addedAddons ?? [],
        'removedAddons': removedAddons ?? [],
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint(
          '⚠️ [EntitlementService] Cloud subscription audit skipped (offline): $e');
    }

    // 3. Record in AuditService for diagnostics and audit trail
    try {
      await AuditService().recordAction(
        storeId: storeId,
        action: AuditActionType.subscriptionChange,
        actorId: changedBy,
        actorRole: 'admin',
        entityId: storeId,
        entityType: 'SUBSCRIPTION',
        reason:
            reason ?? 'Plan changed from ${oldPlan.value} to ${newPlan.value}',
        previousState: {'plan': oldPlan.value, 'status': oldStatus.value},
        newState: {
          'plan': newPlan.value,
          'status': newStatus.value,
          'addedAddons': addedAddons,
          'removedAddons': removedAddons,
        },
      );
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────────────────────

  StoreEntitlement _buildDefaultEntitlement(String storeId) {
    return StoreEntitlement.create(
      storeId: storeId,
      plan: PlanTier.basic,
      status: PlanStatus.active,
      addons: {},
      limits: defaultPlanLimits[PlanTier.basic]!,
      features: defaultPlanFeatures[PlanTier.basic]!,
      version: 1,
    );
  }

  Future<Map<String, int>> _getLocalOrderCounts(String storeId) async {
    try {
      final db = await _repo.dbHelper.database;
      final now = DateTime.now();
      final todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final monthStr = "${now.year}-${now.month.toString().padLeft(2, '0')}";

      final dailyRes = await db.rawQuery('''
        SELECT COUNT(*) as count FROM orders
        WHERE storeId = ? AND date LIKE '$todayStr%'
      ''', [storeId]);

      final monthlyRes = await db.rawQuery('''
        SELECT COUNT(*) as count FROM orders
        WHERE storeId = ? AND date LIKE '$monthStr%'
      ''', [storeId]);

      return {
        'daily': (dailyRes.first['count'] as num?)?.toInt() ?? 0,
        'monthly': (monthlyRes.first['count'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      return {'daily': 0, 'monthly': 0};
    }
  }
}

/// Thrown when an operation exceeds plan limits.
class PlanLimitExceededException implements Exception {
  final String message;
  PlanLimitExceededException(this.message);

  @override
  String toString() => message;
}
