import 'package:flutter/material.dart';
import '../../core/registry/pos_module.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../screens/tables/table_management_screen.dart';

/// Tables & Reservation addon module.
///
/// This module provides:
/// - Table floor plan management
/// - Table reservation and booking
/// - Per-seat and per-table billing modes
/// - Visual table status tracking (Available, Occupied, Reserved)
///
/// Firestore addon key: `table_reservation`
class TablesModule implements POSModule {
  @override
  String get moduleId => 'table_reservation';

  @override
  String get moduleName => 'Tables';

  @override
  bool get isCoreModule => false; // This is an addon, can be attached/detached

  @override
  Future<void> initializeOffline() async {
    // Tables data is currently managed by Hive boxes opened during HiveBootstrap.
    // In a future iteration, this module will own its own Hive box initialization.
    debugPrint('🍽️ [TablesModule] Offline storage ready.');
  }

  @override
  void registerDependencies() {
    // Table providers are currently registered globally via DependencyInjector.
    // In a future iteration, this module will register its own Riverpod providers.
    debugPrint('🍽️ [TablesModule] Dependencies registered.');
  }

  @override
  Map<String, WidgetBuilder> registerRoutes() {
    return {
      '/tables': (context) => const TableManagementScreen(),
    };
  }

  @override
  List<Map<String, dynamic>> getSidebarEntries(BuildContext context) {
    return [
      {
        'icon': Icons.table_restaurant,
        'label': AppLocalizations.t(context, 'Tables'),
        'route': '/tables',
        'key': 'table_reservation',
        'color': AppColors.primary,
      },
    ];
  }

  @override
  Future<void> dispose() async {
    debugPrint('🍽️ [TablesModule] Disposed.');
  }
}
