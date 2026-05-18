import 'package:flutter/material.dart';
import '../../core/registry/pos_module.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../screens/staff/staff_dashboard_screen.dart';

/// Employee Management addon module.
///
/// Firestore addon key: `employee_management`
class EmployeesModule implements POSModule {
  @override
  String get moduleId => 'employee_management';

  @override
  String get moduleName => 'Employees';

  @override
  bool get isCoreModule => false;

  @override
  Future<void> initializeOffline() async {
    debugPrint('👔 [EmployeesModule] Offline storage ready.');
  }

  @override
  void registerDependencies() {
    debugPrint('👔 [EmployeesModule] Dependencies registered.');
  }

  @override
  Map<String, WidgetBuilder> registerRoutes() {
    return {
      '/employees': (context) => const StaffDashboardScreen(),
    };
  }

  @override
  List<Map<String, dynamic>> getSidebarEntries(BuildContext context) {
    return [
      {
        'icon': Icons.badge,
        'label': AppLocalizations.t(context, 'employees'),
        'route': '/employees',
        'key': 'employee_management',
        'color': AppColors.primary,
      },
    ];
  }

  @override
  Future<void> dispose() async {
    debugPrint('👔 [EmployeesModule] Disposed.');
  }
}
