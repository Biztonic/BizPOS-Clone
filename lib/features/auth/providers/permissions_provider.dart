import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_model.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_service.dart';
import 'package:biztonic_pos/core/config/store_type_config.dart';
import '../../auth/domain/entities/user_profile.dart';
import '../../store/domain/entities/store.dart';
import '../../auth/providers/profile_notifier.dart';
import '../../store/providers/store_notifier.dart';

part 'permissions_provider.g.dart';

class PermissionsHelper {
  final UserProfile? profile;
  final Store? activeStore;

  PermissionsHelper(this.profile, this.activeStore);

  bool isFeatureEnabled(String key) {
    if (profile?.role == 'Super Admin') return true;

    final activeRole = profile?.role;
    if (activeRole != 'Store Owner' &&
        activeRole != 'Admin' &&
        activeRole != 'Super Admin' &&
        activeRole != 'Franchise Owner') {
      if (key == 'admin') return false;
      if (activeStore != null &&
          activeRole != null &&
          activeStore!.rolePermissions.containsKey(activeRole)) {
        final perms = activeStore!.rolePermissions[activeRole]!;
        if (perms.containsKey(key)) {
          return perms[key] == true;
        }
        return false;
      }
      return false; // BUG FIX: Do not grant access by default to unmapped roles
    }

    if (activeStore != null) {
      final entitlement =
          EntitlementService.instance.getEntitlement(activeStore!.id);
      if (entitlement.isSuspended || entitlement.isExpired) {
        return false;
      }
    }

    // Core features are always allowed
    if (StoreTypeConfig.isCoreFeature(key)) {
      return true;
    }

    // Peripheral features restricted by store type
    if (activeStore != null &&
        !StoreTypeConfig.isFeatureAllowed(activeStore!.storeType, key)) {
      return false;
    }

    String internalAddonKey = key;
    if (key == 'crm' || key == 'customers') {
      internalAddonKey = 'customer_management';
    }
    if (key == 'employees') internalAddonKey = 'employee_management';
    if (key == 'kds') internalAddonKey = 'kds_management';
    if (key == 'tables') internalAddonKey = 'table_reservation';
    if (key == 'suppliers') internalAddonKey = 'supplier_management';
    if (key == 'franchise') internalAddonKey = 'franchise_management';

    const addonKeys = [
      'customer_management',
      'franchise_management',
      'central_catalog',
      'employee_management',
      'supplier_management',
      'kds_management',
      'table_reservation',
      'data_center',
      'integration_hub',
      'loyalty_program',
      'barcode_scanner',
    ];

    if (addonKeys.contains(internalAddonKey)) {
      return hasAddon(internalAddonKey);
    }

    if (activeStore != null) {
      return EntitlementService.instance.isFeatureEnabled(
        key,
        storeId: activeStore!.id,
        userRole: activeRole,
      );
    }

    return true;
  }

  bool hasAddon(String key) {
    if (profile?.role == 'Super Admin') return true;
    if (activeStore == null) return false;

    // Check store type feature configuration first
    if (!StoreTypeConfig.isFeatureAllowed(activeStore!.storeType, key)) {
      return false;
    }

    String canonicalKey = key;
    if (key == 'crm' || key == 'customers') {
      canonicalKey = 'customer_management';
    } else if (key == 'employees') {
      canonicalKey = 'employee_management';
    } else if (key == 'kds') {
      canonicalKey = 'kds_management';
    } else if (key == 'tables') {
      canonicalKey = 'table_reservation';
    } else if (key == 'suppliers') {
      canonicalKey = 'supplier_management';
    } else if (key == 'franchise') {
      canonicalKey = 'franchise_management';
    }

    final entitlement =
        EntitlementService.instance.getEntitlement(activeStore!.id);
    if (!entitlement.isUsable) return false;

    final planTier = PlanTier.fromString(activeStore!.subscriptionPlan);

    if (profile != null &&
        profile!.role != 'Store Owner' &&
        profile!.role != 'Franchise Owner' &&
        profile!.role != 'Admin' &&
        profile!.role != 'Super Admin' &&
        profile!.accessibleAddons != null) {
      if (!profile!.accessibleAddons!.contains(key) &&
          !profile!.accessibleAddons!.contains(canonicalKey)) {
        return false;
      }
    }

    if (planTier == PlanTier.enterprise) {
      return true;
    }

    final storeAddonsCanonical = activeStore!.addons
        .map(EntitlementService.canonicalizeAddonKey)
        .toSet();
    final storePurchasedCanonical = activeStore!.purchasedAddons
        .map(EntitlementService.canonicalizeAddonKey)
        .toSet();

    if (storeAddonsCanonical.contains(canonicalKey) &&
        storePurchasedCanonical.contains(canonicalKey)) {
      return true;
    }

    return EntitlementService.instance
        .hasAddon(canonicalKey, storeId: activeStore!.id);
  }
}

@riverpod
PermissionsHelper permissions(Ref ref) {
  final profile = ref.watch(profileNotifierProvider).value;
  final storeState = ref.watch(storeNotifierProvider);
  return PermissionsHelper(profile, storeState.activeStore);
}
