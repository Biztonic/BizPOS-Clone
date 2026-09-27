import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Lifecycle states for store subscription plans.
enum PlanStatus {
  trial,
  active,
  grace,
  suspended,
  expired,
  cancelled;

  String toValue() {
    switch (this) {
      case PlanStatus.trial:
        return 'TRIAL';
      case PlanStatus.active:
        return 'ACTIVE';
      case PlanStatus.grace:
        return 'GRACE';
      case PlanStatus.suspended:
        return 'SUSPENDED';
      case PlanStatus.expired:
        return 'EXPIRED';
      case PlanStatus.cancelled:
        return 'CANCELLED';
    }
  }

  String get value => toValue();

  static PlanStatus fromValue(String? value) {
    switch (value?.toUpperCase()) {
      case 'TRIAL':
        return PlanStatus.trial;
      case 'ACTIVE':
        return PlanStatus.active;
      case 'GRACE':
        return PlanStatus.grace;
      case 'SUSPENDED':
        return PlanStatus.suspended;
      case 'EXPIRED':
        return PlanStatus.expired;
      case 'CANCELLED':
        return PlanStatus.cancelled;
      default:
        return PlanStatus.active;
    }
  }

  static PlanStatus fromString(String? value) => fromValue(value);
}

/// Plan tiers recognized across BizPOS.
enum PlanTier {
  starting,
  basic,
  standard,
  professional,
  enterprise;

  String toValue() {
    switch (this) {
      case PlanTier.starting:
        return 'Starting';
      case PlanTier.basic:
        return 'Basic';
      case PlanTier.standard:
        return 'Standard';
      case PlanTier.professional:
        return 'Professional';
      case PlanTier.enterprise:
        return 'Enterprise';
    }
  }

  String get value => toValue();

  static PlanTier fromValue(String? value) {
    switch (value?.toLowerCase()) {
      case 'starting':
        return PlanTier.starting;
      case 'basic':
        return PlanTier.basic;
      case 'standard':
        return PlanTier.standard;
      case 'professional':
        return PlanTier.professional;
      case 'enterprise':
        return PlanTier.enterprise;
      default:
        return PlanTier.basic;
    }
  }

  static PlanTier fromString(String? value) => fromValue(value);
}

/// Immutable, authoritative entitlement snapshot for a store.
class StoreEntitlement {
  final String storeId;
  final PlanTier plan;
  final PlanStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final int gracePeriodDays;
  final Set<String> addons;
  final Set<String> purchasedAddons;
  final Map<String, int> limits;
  final Set<String> features;
  final int version;
  final String tamperHash;
  final DateTime updatedAt;
  final DateTime? serverTimestamp;

  const StoreEntitlement({
    required this.storeId,
    required this.plan,
    required this.status,
    this.startDate,
    this.endDate,
    this.gracePeriodDays = 7,
    required this.addons,
    this.purchasedAddons = const {},
    required this.limits,
    required this.features,
    required this.version,
    required this.tamperHash,
    required this.updatedAt,
    this.serverTimestamp,
  });

  /// Computes a tamper-evident cryptographic hash of the entitlement data.
  static String computeHash({
    required String storeId,
    required String plan,
    required String status,
    required int version,
    required List<String> addons,
    List<String> purchasedAddons = const [],
    required Map<String, int> limits,
    required List<String> features,
    DateTime? endDate,
    DateTime? serverTimestamp,
  }) {
    final sortedAddons = List<String>.from(addons)..sort();
    final sortedPurchased = List<String>.from(purchasedAddons)..sort();
    final sortedFeatures = List<String>.from(features)..sort();
    final sortedLimitsKeys = limits.keys.toList()..sort();
    final limitsStr = sortedLimitsKeys.map((k) => '$k:${limits[k]}').join(',');

    final payload = [
      storeId,
      plan,
      status,
      version.toString(),
      sortedAddons.join(','),
      sortedPurchased.join(','),
      limitsStr,
      sortedFeatures.join(','),
      endDate?.millisecondsSinceEpoch.toString() ?? 'none',
      serverTimestamp?.millisecondsSinceEpoch.toString() ?? 'none',
      'BIZPOS_ENTITLEMENT_SALT_V1',
    ].join('|');

    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// Legacy compute hash for backward compatibility.
  static String computeLegacyHash({
    required String storeId,
    required String plan,
    required String status,
    required int version,
    required List<String> addons,
    required Map<String, int> limits,
    required List<String> features,
    DateTime? endDate,
  }) {
    final sortedAddons = List<String>.from(addons)..sort();
    final sortedFeatures = List<String>.from(features)..sort();
    final sortedLimitsKeys = limits.keys.toList()..sort();
    final limitsStr = sortedLimitsKeys.map((k) => '$k:${limits[k]}').join(',');

    final payload = [
      storeId,
      plan,
      status,
      version.toString(),
      sortedAddons.join(','),
      limitsStr,
      sortedFeatures.join(','),
      endDate?.millisecondsSinceEpoch.toString() ?? 'none',
      'BIZPOS_ENTITLEMENT_SALT_V1',
    ].join('|');

    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// Verifies whether this entitlement's hash matches its contents.
  bool verifyIntegrity() {
    final expected = computeHash(
      storeId: storeId,
      plan: plan.value,
      status: status.value,
      version: version,
      addons: addons.toList(),
      purchasedAddons: purchasedAddons.toList(),
      limits: limits,
      features: features.toList(),
      endDate: endDate,
      serverTimestamp: serverTimestamp,
    );
    if (tamperHash == expected) return true;

    // Fallback to check legacy hash
    final legacyExpected = computeLegacyHash(
      storeId: storeId,
      plan: plan.value,
      status: status.value,
      version: version,
      addons: addons.toList(),
      limits: limits,
      features: features.toList(),
      endDate: endDate,
    );
    return tamperHash == legacyExpected;
  }

  /// Checks if an addon is permitted based on purchases or plan tier.
  bool isAddonAllowed(String addonKey) {
    if (plan == PlanTier.enterprise) return true;
    return purchasedAddons.contains(addonKey) || features.contains(addonKey);
  }

  /// Whether the entitlement permits standard daily POS operations.
  bool get isUsable {
    return status == PlanStatus.active ||
        status == PlanStatus.trial ||
        status == PlanStatus.grace;
  }

  /// Whether the plan is currently in its post-expiry grace period.
  bool get isInGracePeriod => status == PlanStatus.grace;

  /// Whether the plan is expired past grace.
  bool get isExpired => status == PlanStatus.expired;

  /// Whether the store is administratively suspended.
  bool get isSuspended => status == PlanStatus.suspended;

  /// Remaining days until formal end date (negative if passed).
  int? get daysRemaining {
    if (endDate == null) return null;
    return endDate!.difference(DateTime.now()).inDays;
  }

  /// Remaining days of grace period if expired.
  int? get graceDaysRemaining {
    if (endDate == null) return null;
    final now = DateTime.now();
    if (now.isBefore(endDate!)) return gracePeriodDays;
    final graceCutoff = endDate!.add(Duration(days: gracePeriodDays));
    final diff = graceCutoff.difference(now).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Factory helper for creating an entitlement with auto-computed integrity hash.
  factory StoreEntitlement.create({
    required String storeId,
    required PlanTier plan,
    required PlanStatus status,
    DateTime? startDate,
    DateTime? endDate,
    int gracePeriodDays = 7,
    Set<String> addons = const {},
    Set<String>? purchasedAddons,
    required Map<String, int> limits,
    required Set<String> features,
    int version = 1,
    DateTime? updatedAt,
    DateTime? serverTimestamp,
  }) {
    final updated = updatedAt ?? DateTime.now();
    final Set<String> effectivePurchased = purchasedAddons ??
        ((plan == PlanTier.basic || plan == PlanTier.starting)
            ? const <String>{}
            : addons);

    final hash = computeHash(
      storeId: storeId,
      plan: plan.value,
      status: status.value,
      version: version,
      addons: addons.toList(),
      purchasedAddons: effectivePurchased.toList(),
      limits: limits,
      features: features.toList(),
      endDate: endDate,
      serverTimestamp: serverTimestamp,
    );

    return StoreEntitlement(
      storeId: storeId,
      plan: plan,
      status: status,
      startDate: startDate,
      endDate: endDate,
      gracePeriodDays: gracePeriodDays,
      addons: addons,
      purchasedAddons: effectivePurchased,
      limits: limits,
      features: features,
      version: version,
      tamperHash: hash,
      updatedAt: updated,
      serverTimestamp: serverTimestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'plan': plan.value,
      'status': status.value,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'gracePeriodDays': gracePeriodDays,
      'addons': addons.toList(),
      'purchasedAddons': purchasedAddons.toList(),
      'limits': limits,
      'features': features.toList(),
      'version': version,
      'tamperHash': tamperHash,
      'updatedAt': updatedAt.toIso8601String(),
      'serverTimestamp': serverTimestamp?.toIso8601String(),
    };
  }

  factory StoreEntitlement.fromMap(Map<dynamic, dynamic> map) {
    return StoreEntitlement(
      storeId: map['storeId']?.toString() ?? '',
      plan: PlanTier.fromValue(map['plan']?.toString()),
      status: PlanStatus.fromValue(map['status']?.toString()),
      startDate: map['startDate'] != null
          ? DateTime.tryParse(map['startDate'].toString())
          : null,
      endDate: map['endDate'] != null
          ? DateTime.tryParse(map['endDate'].toString())
          : null,
      gracePeriodDays: (map['gracePeriodDays'] as num?)?.toInt() ?? 7,
      addons:
          (map['addons'] as List<dynamic>?)?.map((e) => e.toString()).toSet() ??
              {},
      purchasedAddons: (map['purchasedAddons'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          {},
      limits: (map['limits'] as Map<dynamic, dynamic>?)?.map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          ) ??
          {},
      features: (map['features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          {},
      version: (map['version'] as num?)?.toInt() ?? 1,
      tamperHash: map['tamperHash']?.toString() ?? '',
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      serverTimestamp: map['serverTimestamp'] != null
          ? DateTime.tryParse(map['serverTimestamp'].toString())
          : null,
    );
  }

  StoreEntitlement copyWith({
    String? storeId,
    PlanTier? plan,
    PlanStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    int? gracePeriodDays,
    Set<String>? addons,
    Set<String>? purchasedAddons,
    Map<String, int>? limits,
    Set<String>? features,
    int? version,
    String? tamperHash,
    DateTime? updatedAt,
    DateTime? serverTimestamp,
  }) {
    return StoreEntitlement(
      storeId: storeId ?? this.storeId,
      plan: plan ?? this.plan,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
      addons: addons ?? this.addons,
      purchasedAddons: purchasedAddons ?? this.purchasedAddons,
      limits: limits ?? this.limits,
      features: features ?? this.features,
      version: version ?? this.version,
      tamperHash: tamperHash ?? this.tamperHash,
      updatedAt: updatedAt ?? this.updatedAt,
      serverTimestamp: serverTimestamp ?? this.serverTimestamp,
    );
  }
}
