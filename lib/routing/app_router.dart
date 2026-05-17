import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../models/table_model.dart';
import '../utils/theme.dart';

// Screens
import '../screens/splash_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/auth/employee_login_screen.dart';
import '../screens/auth/create_store_screen.dart';
import '../screens/auth/store_select_screen.dart';
import '../screens/auth/set_password_screen.dart';
import '../screens/dashboard_overview_screen.dart';
import '../screens/dashboard_theme/dashboard_insights_screen.dart';
import '../screens/pos_screen.dart';
import '../screens/dashboard_theme/car_dashboard_pos_screen.dart';
import '../screens/inventory_screen.dart';
import '../screens/printer_screen.dart';
import '../screens/sales_screen.dart';
import '../screens/customers_screen.dart';
import '../screens/staff/staff_dashboard_screen.dart';
import '../screens/employees_screen.dart';
import '../screens/user_management_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/supplier_screen.dart';
import '../screens/kitchen_display_screen.dart';
import '../screens/display_management_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/admin/store_management_screen.dart';
import '../screens/admin/user_role_management_screen.dart';
import '../screens/settings/data_sync_control_screen.dart';
import '../screens/admin/franchise_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/admin/basic_plan_settings_screen.dart';
import '../screens/language_screen.dart';
import '../screens/integration/integration_hub_screen.dart';
import '../screens/settings/biz_store_screen.dart';
import '../screens/reports/unified_sales_report_screen.dart';
import '../screens/reports/inventory_reports_screen.dart';
import '../screens/reports/customer_reports_screen.dart';
import '../screens/reports/financial_reports_screen.dart';
import '../screens/reports/audit_log_screen.dart';
import '../screens/tables/table_management_screen.dart';

import '../screens/universal_shell.dart';
import '../widgets/feature_guard.dart';
import '../widgets/demo_overlay_widget.dart';

import 'router_notifier.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static GoRouter createRouter(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final routerNotifier = Provider.of<RouterNotifier>(context, listen: false);
    final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);

    return GoRouter(
      navigatorKey: appNavigatorKey,
      initialLocation: '/splash',
      refreshListenable: Listenable.merge([authProvider, routerNotifier, dashboardProvider]),
      redirect: (context, state) => _handleRedirect(context, state, authProvider),
      routes: _routes,
    );
  }

  static String? _handleRedirect(BuildContext context, GoRouterState state, AuthProvider authProvider) {
    final isLoggedIn = authProvider.isLoggedIn;
    final isLoggingIn = state.uri.path == '/login';
    final isEmployeeLogin = state.uri.path == '/employee-login';
    final isSetPassword = state.uri.path == '/set-password';
    final isSplash = state.uri.path == '/splash';

    if (isSplash) return null;

    final isRoot = state.uri.path == '/';
    if (isRoot) {
      if (!isLoggedIn) return '/login';
      return '/dashboard';
    }

    if (!isLoggedIn && !isLoggingIn && !isEmployeeLogin && !isSetPassword) return '/login';

    if (isLoggedIn) {
      if (isEmployeeLogin) return null;

      final dashboard = Provider.of<DashboardProvider>(context, listen: false);

      if (authProvider.isLoggedIn && !dashboard.isInitialized) {
        return null;
      }

      if (authProvider.isOfflineLoggedIn) {
        if (isLoggingIn) return '/dashboard';
        return null;
      }

      final isCreateStore = state.uri.path == '/create-store';
      final isSelectStore = state.uri.path == '/select-store';

      final isAdminPath = state.uri.path.startsWith('/admin');
      if (dashboard.activeStoreId == null && !isCreateStore && !isSelectStore && !isAdminPath) {
        final isSuperAdmin = dashboard.isSuperAdmin;
        final hasStores = dashboard.hasAnyStore;
        final hasChecked = dashboard.hasCheckedStores;
        final storeCount = dashboard.stores.length;

        if (storeCount == 1 && !isSuperAdmin) {
          return '/dashboard';
        }

        if (isSuperAdmin || hasStores) {
          return '/select-store';
        } else if (dashboard.activeRole == 'Store Owner' && hasChecked) {
          return '/select-store';
        }
        return null;
      }

      if (dashboard.activeStoreId != null && (isCreateStore || isSelectStore)) {
        return '/dashboard';
      }

      if (state.uri.path == '/complete-profile') {
        return '/dashboard';
      }
    }

    if (isLoggedIn && isLoggingIn) return '/dashboard';
    return null;
  }

  static List<RouteBase> get _routes => [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/',
          redirect: (_, __) => '/dashboard',
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const AuthScreen(),
        ),
        GoRoute(
          path: '/employee-login',
          builder: (context, state) => const EmployeeLoginScreen(),
        ),
        GoRoute(
          path: '/create-store',
          builder: (context, state) => const CreateStoreScreen(),
        ),
        GoRoute(
          path: '/select-store',
          builder: (context, state) => const StoreSelectScreen(),
        ),
        GoRoute(
          path: '/set-password',
          builder: (context, state) {
            final email = state.uri.queryParameters['email'] ?? '';
            return SetPasswordScreen(email: email);
          },
        ),
        ShellRoute(
          builder: (context, state, child) {
            return DemoOverlayWidget(child: UniversalShell(child: child));
          },
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) {
                final provider = Provider.of<DashboardProvider>(context, listen: false);
                if (provider.uiStyle == UIStyle.car_dashboard) {
                  return const DashboardInsightsScreen();
                }
                return const DashboardOverviewScreen();
              },
            ),
            GoRoute(
              path: '/pos',
              builder: (context, state) => FeatureGuard(
                featureKey: 'pos',
                child: Builder(
                  builder: (context) {
                    final provider = Provider.of<DashboardProvider>(context, listen: false);
                    if (provider.uiStyle == UIStyle.car_dashboard) {
                      return const CarDashboardPOSScreen();
                    }
                    TableModel? table;
                    if (state.extra is TableModel) {
                      table = state.extra as TableModel;
                    }
                    return POSScreen(preSelectedTable: table);
                  },
                ),
              ),
            ),
            GoRoute(
              path: '/inventory',
              builder: (context, state) => const FeatureGuard(featureKey: 'inventory', child: InventoryScreen()),
            ),
            GoRoute(
              path: '/printer',
              builder: (context, state) => const PrinterScreen(),
            ),
            GoRoute(
              path: '/sales',
              builder: (context, state) => const FeatureGuard(featureKey: 'reports', child: SalesScreen()),
            ),
            GoRoute(
              path: '/customers',
              builder: (context, state) => const FeatureGuard(featureKey: 'crm', child: CustomersScreen()),
            ),
            GoRoute(
              path: '/employees',
              builder: (context, state) => const FeatureGuard(featureKey: 'employees', child: StaffDashboardScreen()),
            ),
            GoRoute(
              path: '/staff-list',
              builder: (context, state) {
                int tabIndex = 0;
                if (state.extra is int) {
                  tabIndex = state.extra as int;
                }
                return FeatureGuard(featureKey: 'employees', child: EmployeesScreen(initialTabIndex: tabIndex));
              },
            ),
            GoRoute(path: '/users', builder: (context, state) => const UserManagementScreen()),
            GoRoute(
              path: '/reports',
              builder: (context, state) => const FeatureGuard(featureKey: 'reports', child: ReportsScreen()),
            ),
            GoRoute(
              path: '/suppliers',
              builder: (context, state) => const FeatureGuard(featureKey: 'inventory', child: SupplierScreen()),
            ),
            GoRoute(
              path: '/kds',
              builder: (context, state) => const FeatureGuard(featureKey: 'kds_management', child: KitchenDisplayScreen()),
            ),
            GoRoute(
              path: '/display',
              builder: (context, state) => const FeatureGuard(featureKey: 'kds_management', child: DisplayManagementScreen()),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const FeatureGuard(featureKey: 'settings', child: SettingsScreen()),
            ),
            GoRoute(
              path: '/stores',
              builder: (context, state) => const FeatureGuard(featureKey: 'admin', child: StoreManagementScreen()),
            ),
            GoRoute(
              path: '/roles',
              builder: (context, state) => const FeatureGuard(featureKey: 'admin', child: UserRoleManagementScreen()),
            ),
            GoRoute(
              path: '/data-sync',
              builder: (context, state) => const FeatureGuard(featureKey: 'settings', child: DataSyncControlScreen()),
            ),
            GoRoute(
              path: '/franchises',
              builder: (context, state) => const FeatureGuard(featureKey: 'franchises', child: FranchiseScreen()),
            ),
            GoRoute(
              path: '/admin',
              builder: (context, state) => const FeatureGuard(featureKey: 'admin', child: AdminDashboardScreen()),
            ),
            GoRoute(
              path: '/admin/limits',
              builder: (context, state) => const FeatureGuard(featureKey: 'admin', child: BasicPlanSettingsScreen()),
            ),
            GoRoute(
              path: '/languages',
              builder: (context, state) => const FeatureGuard(featureKey: 'admin', child: LanguageScreen()),
            ),
            GoRoute(
              path: '/integrations',
              builder: (context, state) => const FeatureGuard(featureKey: 'integration_hub', child: IntegrationHubScreen()),
            ),
            GoRoute(
              path: '/biz-store',
              builder: (context, state) => const FeatureGuard(featureKey: 'admin', child: BizStoreScreen()),
            ),
            GoRoute(path: '/reports/sales', builder: (context, state) => const UnifiedSalesReportScreen()),
            GoRoute(path: '/reports/inventory', builder: (context, state) => const InventoryReportsScreen()),
            GoRoute(path: '/reports/customers', builder: (context, state) => const CustomerReportsScreen()),
            GoRoute(
              path: '/reports/financials',
              builder: (context, state) => const FeatureGuard(featureKey: 'reports', child: FinancialReportsScreen()),
            ),
            GoRoute(path: '/reports/audit', builder: (context, state) => const AuditLogScreen()),
            GoRoute(
              path: '/tables',
              builder: (context, state) => const FeatureGuard(featureKey: 'pos', child: TableManagementScreen()),
            ),
          ],
        ),
      ];
}
