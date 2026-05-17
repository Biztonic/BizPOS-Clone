import '../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as legacy;
import '../features/auth/providers/permissions_provider.dart';
import '../features/auth/providers/profile_notifier.dart';
import '../providers/dashboard_provider.dart';

class FeatureGuard extends ConsumerWidget {
  final String featureKey;
  final Widget child;
  final Widget? lockedChild;

  const FeatureGuard({
    super.key,
    required this.featureKey,
    required this.child,
    this.lockedChild,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileNotifierProvider).value;
    final permissions = ref.watch(permissionsProvider);

    // 1. Check for DashboardProvider availability and initialization
    DashboardProvider? dashboard;
    try {
      dashboard = legacy.Provider.of<DashboardProvider>(context, listen: true);
      if (!dashboard.isInitialized) {
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: AppSpacing.md),
                Text("Initializing features..."),
              ],
            ),
          ),
        );
      }
    } catch (_) {
      // DashboardProvider not available - continue to other checks
    }

    // 2. Super Admin Bypass (Riverpod profile)
    if (profile?.role == 'Super Admin') {
      return child;
    }

    // 3. Super Admin Bypass (Legacy DashboardProvider fallback)
    if (dashboard != null && dashboard.isSuperAdmin) {
      return child;
    }

    // Unified Permission & Addon Check
    if (permissions.isFeatureEnabled(featureKey)) {
      return child;
    }

    // Fallback to legacy DashboardProvider logic for smooth migration
    if (dashboard != null && dashboard.isFeatureEnabled(featureKey)) {
      return child;
    }

    // Access Denied / Locked UI
    return lockedChild ?? Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person, size: 64, color: AppColors.warning),
            const SizedBox(height: AppSpacing.md),
            const Text("Access Restricted",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            Text("You do not have permission to access: ${featureKey.toUpperCase()}"),
            const SizedBox(height: AppSpacing.sm),
            Text("Please contact your Store Owner for access.",
                style: TextStyle(color: AppColors.textSecondary(context))),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("GO BACK"),
            )
          ],
        ),
      ),
    );
  }
}
