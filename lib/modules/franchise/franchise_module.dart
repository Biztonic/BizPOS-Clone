import 'package:flutter/material.dart';
import '../../core/registry/pos_module.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../screens/admin/franchise_screen.dart';

/// Franchise Management addon module.
///
/// Firestore addon key: `franchise_management`
class FranchiseModule implements POSModule {
  @override
  String get moduleId => 'franchise_management';

  @override
  String get moduleName => 'Franchises';

  @override
  bool get isCoreModule => false;

  @override
  Future<void> initializeOffline() async {
    debugPrint('🏪 [FranchiseModule] Offline storage ready.');
  }

  @override
  void registerDependencies() {
    debugPrint('🏪 [FranchiseModule] Dependencies registered.');
  }

  @override
  Map<String, WidgetBuilder> registerRoutes() {
    return {
      '/franchises': (context) => const FranchiseScreen(),
    };
  }

  @override
  List<Map<String, dynamic>> getSidebarEntries(BuildContext context) {
    return [
      {
        'icon': Icons.store,
        'label': AppLocalizations.t(context, 'franchises'),
        'route': '/franchises',
        'key': 'franchise_management',
        'color': AppColors.primary,
      },
    ];
  }

  @override
  Future<void> dispose() async {
    debugPrint('🏪 [FranchiseModule] Disposed.');
  }
}
