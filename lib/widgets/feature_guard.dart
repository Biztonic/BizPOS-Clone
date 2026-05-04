import '../core/design/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/providers/permissions_provider.dart';
import '../features/auth/providers/profile_notifier.dart';

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
    final profile = ref.watch(profileNotifierProvider).profile;
    final permissions = ref.watch(permissionsProvider);

    // Super Admin Bypass
    if (profile?.role == 'Super Admin') {
      return child;
    }

    // Unified Permission & Addon Check
    if (permissions.isFeatureEnabled(featureKey)) {
      return child;
    }

    // Access Denied / Locked UI
    return lockedChild ?? Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person, size: 64, color: AppColors.warning),
            const SizedBox(height: 16),
            const Text("Access Restricted",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("You do not have permission to access: ${featureKey.toUpperCase()}"),
            const SizedBox(height: 8),
            Text("Please contact your Store Owner for access.",
                style: TextStyle(color: AppColors.textSecondary(context))),
            const SizedBox(height: 16),
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
