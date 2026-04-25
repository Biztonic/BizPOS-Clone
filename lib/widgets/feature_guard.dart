import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';

class FeatureGuard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        // Super Admin Bypass
        if (provider.userProfile?.role == 'Super Admin') {
           return child;
        }

        // Unified Permission & Addon Check
        if (provider.isFeatureEnabled(featureKey)) {
           return child;
        }

        // Access Denied / Locked UI
        return lockedChild ?? Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_person, size: 64, color: Colors.amber),
                const SizedBox(height: 16),
                const Text("Access Restricted", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("You do not have permission to access: ${featureKey.toUpperCase()}"),
                const SizedBox(height: 8),
                const Text("Please contact your Store Owner for access.", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("GO BACK"),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
