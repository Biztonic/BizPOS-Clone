import 'package:flutter/material.dart';
import '../../core/registry/pos_module.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../screens/display_management_screen.dart';

/// Kitchen Display System (KDS) addon module.
///
/// Firestore addon key: `kds_management`
class KdsModule implements POSModule {
  @override
  String get moduleId => 'kds_management';

  @override
  String get moduleName => 'Display / KDS';

  @override
  bool get isCoreModule => false;

  @override
  Future<void> initializeOffline() async {
    debugPrint('📺 [KdsModule] Offline storage ready.');
  }

  @override
  void registerDependencies() {
    debugPrint('📺 [KdsModule] Dependencies registered.');
  }

  @override
  Map<String, WidgetBuilder> registerRoutes() {
    return {
      '/display': (context) => const DisplayManagementScreen(),
    };
  }

  @override
  List<Map<String, dynamic>> getSidebarEntries(BuildContext context) {
    return [
      {
        'icon': Icons.tv,
        'label': AppLocalizations.t(context, 'Display'),
        'route': '/display',
        'key': 'kds_management',
        'color': AppColors.primary,
      },
    ];
  }

  @override
  Future<void> dispose() async {
    debugPrint('📺 [KdsModule] Disposed.');
  }
}
