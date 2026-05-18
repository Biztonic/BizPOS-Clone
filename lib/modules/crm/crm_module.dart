import 'package:flutter/material.dart';
import '../../core/registry/pos_module.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../screens/customers_screen.dart';

/// Customer Management / CRM addon module.
///
/// Firestore addon key: `customer_management`
class CrmModule implements POSModule {
  @override
  String get moduleId => 'customer_management';

  @override
  String get moduleName => 'Customers';

  @override
  bool get isCoreModule => false;

  @override
  Future<void> initializeOffline() async {
    debugPrint('👥 [CrmModule] Offline storage ready.');
  }

  @override
  void registerDependencies() {
    debugPrint('👥 [CrmModule] Dependencies registered.');
  }

  @override
  Map<String, WidgetBuilder> registerRoutes() {
    return {
      '/customers': (context) => const CustomersScreen(),
    };
  }

  @override
  List<Map<String, dynamic>> getSidebarEntries(BuildContext context) {
    return [
      {
        'icon': Icons.people,
        'label': AppLocalizations.t(context, 'customers'),
        'route': '/customers',
        'key': 'customer_management',
        'color': AppColors.primary,
      },
    ];
  }

  @override
  Future<void> dispose() async {
    debugPrint('👥 [CrmModule] Disposed.');
  }
}
