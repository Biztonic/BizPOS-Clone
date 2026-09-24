import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_model.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_service.dart';
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

    if ([
          'dashboard',
          'pos',
          'inventory',
          'reports',
          'sales',
          'settings',
          'biz_store'
        ].contains(key) ||
        key.startsWith('settings.') ||
        key.startsWith('dashboard.') ||
        key.startsWith('card.') ||
        key.startsWith('feature.pos.')) {
      return true;
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

    // Basic and Starting plans NEVER enable addon modules
    final planTier = PlanTier.fromString(activeStore!.subscriptionPlan);
    if (planTier == PlanTier.basic || planTier == PlanTier.starting) {
      return false;
    }

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

    if (activeStore!.addons.contains(key) ||
        activeStore!.addons.contains(canonicalKey)) {
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
