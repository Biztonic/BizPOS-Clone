import 'package:flutter/material.dart';
import '../../core/registry/pos_module.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../screens/supplier_screen.dart';

/// Supplier Management addon module.
///
/// Firestore addon key: `supplier_management`
class SuppliersModule implements POSModule {
  @override
  String get moduleId => 'supplier_management';

  @override
  String get moduleName => 'Suppliers';

  @override
  bool get isCoreModule => false;

  @override
  Future<void> initializeOffline() async {
    debugPrint('📦 [SuppliersModule] Offline storage ready.');
  }

  @override
  void registerDependencies() {
    debugPrint('📦 [SuppliersModule] Dependencies registered.');
  }

  @override
  Map<String, WidgetBuilder> registerRoutes() {
    return {
      '/suppliers': (context) => const SupplierScreen(),
    };
  }

  @override
  List<Map<String, dynamic>> getSidebarEntries(BuildContext context) {
    return [
      {
        'icon': Icons.local_shipping,
        'label': AppLocalizations.t(context, 'Suppliers'),
        'route': '/suppliers',
        'key': 'supplier_management',
        'color': AppColors.warning,
      },
    ];
  }

  @override
  Future<void> dispose() async {
    debugPrint('📦 [SuppliersModule] Disposed.');
  }
}
