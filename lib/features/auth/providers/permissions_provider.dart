import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hive/hive.dart';
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
    ].contains(key)) {
      return true;
    }

    String internalAddonKey = key;
    if (key == 'crm') internalAddonKey = 'customer_management';
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
      'loyalty_program'
    ];

    if (addonKeys.contains(internalAddonKey)) {
      if (hasAddon(internalAddonKey)) return true;
      if (activeStore != null &&
          EntitlementService.instance.isFeatureEnabled(
            internalAddonKey,
            storeId: activeStore!.id,
            userRole: activeRole,
          )) {
        return true;
      }
      return false;
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
    if (activeStore == null) return false;

    final entitlement =
        EntitlementService.instance.getEntitlement(activeStore!.id);
    if (!entitlement.isUsable) return false;

    // Check authoritative EntitlementService or store addons
    final hasStoreEntitlement =
        EntitlementService.instance.hasAddon(key, storeId: activeStore!.id) ||
            activeStore!.addons.contains(key) ||
            activeStore!.purchasedAddons.contains(key);

    if (!hasStoreEntitlement) {
      // Resolve feature status based on store type configurations cached in Hive
      final type = activeStore!.storeType;
      final box = Hive.isBoxOpen('store_type_configs')
          ? Hive.box('store_type_configs')
          : null;
      final configs = box?.get('configs') as Map?;
      final config = configs?[type];
      if (config is Map && config.containsKey(key)) {
        if (config[key] != true) return false;
      } else if (type == 'Restaurant') {
        // Default templates if no custom config exists yet
        if (!['table_reservation', 'kds_management', 'employee_management']
            .contains(key)) return false;
      } else if (type == 'Grocery' || type == 'Supermarket') {
        if (![
          'barcode_scanner',
          'customer_management',
          'supplier_management',
          'data_center'
        ].contains(key)) return false;
      } else {
        return false;
      }
    }

    if (profile != null &&
        profile!.role != 'Store Owner' &&
        profile!.role != 'Franchise Owner' &&
        profile!.accessibleAddons != null) {
      if (!profile!.accessibleAddons!.contains(key)) return false;
    }

    return true;
  }
}

@riverpod
PermissionsHelper permissions(Ref ref) {
  final profile = ref.watch(profileNotifierProvider).value;
  final storeState = ref.watch(storeNotifierProvider);
  return PermissionsHelper(profile, storeState.activeStore);
}
