import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
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

    String internalAddonKey = key;
    if (key == 'crm') internalAddonKey = 'customer_management';
    if (key == 'employees') internalAddonKey = 'employee_management';
    if (key == 'inventory') internalAddonKey = 'inventory_management';

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
      if (!hasAddon(internalAddonKey)) return false;
    }

    final activeRole = profile?.role;
    if (activeRole != 'Store Owner' && activeRole != 'Admin' && activeRole != 'Super Admin') {
      if (key == 'admin') return false;
      if (activeStore != null && activeRole != null && activeStore!.rolePermissions.containsKey(activeRole)) {
        final perms = activeStore!.rolePermissions[activeRole]!;
        if (perms.containsKey(key)) {
          return perms[key] == true;
        }
        return false;
      }
      return true;
    }
    return true;
  }

  bool hasAddon(String key) {
    // Note: globalDisabledAddons logic skipped for now as it seems to be hardcoded in DashboardProvider or fetched from RemoteConfig
    // For now, let's stick to store and profile checks.
    
    if (activeStore == null) return false;
    
    if (profile != null && profile!.role != 'Store Owner' && profile!.accessibleAddons != null) {
      if (!profile!.accessibleAddons!.contains(key)) return false;
    }
    
    return activeStore!.addons.contains(key);
  }
}

@riverpod
PermissionsHelper permissions(Ref ref) {
  final profile = ref.watch(profileNotifierProvider).profile;
  final storeState = ref.watch(storeNotifierProvider);
  return PermissionsHelper(profile, storeState.activeStore);
}
