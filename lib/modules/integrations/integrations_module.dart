import 'package:flutter/material.dart';
import '../../core/registry/pos_module.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../screens/integration/integration_hub_screen.dart';

/// Integration Hub addon module.
///
/// Firestore addon key: `integration_hub`
class IntegrationsModule implements POSModule {
  @override
  String get moduleId => 'integration_hub';

  @override
  String get moduleName => 'Integrations';

  @override
  bool get isCoreModule => false;

  @override
  Future<void> initializeOffline() async {
    debugPrint('🔗 [IntegrationsModule] Offline storage ready.');
  }

  @override
  void registerDependencies() {
    debugPrint('🔗 [IntegrationsModule] Dependencies registered.');
  }

  @override
  Map<String, WidgetBuilder> registerRoutes() {
    return {
      '/integrations': (context) => const IntegrationHubScreen(),
    };
  }

  @override
  List<Map<String, dynamic>> getSidebarEntries(BuildContext context) {
    return [
      {
        'icon': Icons.hub,
        'label': AppLocalizations.t(context, 'Integrations'),
        'route': '/integrations',
        'key': 'integration_hub',
        'color': AppColors.warning,
      },
    ];
  }

  @override
  Future<void> dispose() async {
    debugPrint('🔗 [IntegrationsModule] Disposed.');
  }
}
