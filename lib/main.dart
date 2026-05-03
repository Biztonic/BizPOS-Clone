import 'core/design/tokens/app_colors.dart';
// ignore_for_file: unused_shown_name

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart'; // Crashlytics
import 'dart:async'; // For runZonedGuarded
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_strategy/url_strategy.dart'; // NEW
import 'package:biztonic_pos/screens/display_management_screen.dart'; // NEW
import 'package:biztonic_pos/screens/kitchen_display_screen.dart'; // NEW
import 'package:biztonic_pos/screens/dashboard_theme/dashboard_insights_screen.dart'; // NEW
import 'package:biztonic_pos/screens/dashboard_theme/car_dashboard_pos_screen.dart';
import 'package:biztonic_pos/utils/car_dashboard_theme.dart';
import 'package:biztonic_pos/screens/universal_shell.dart';
import 'package:biztonic_pos/core/design/density/app_density.dart'; // NEW
import 'package:biztonic_pos/providers/auth_provider.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import 'package:biztonic_pos/providers/inventory_provider.dart'; 
import 'package:biztonic_pos/providers/order_provider.dart';
import 'package:biztonic_pos/providers/customer_provider.dart';
import 'package:biztonic_pos/providers/store_provider.dart';
import 'package:biztonic_pos/providers/table_provider.dart';
import 'package:biztonic_pos/providers/smart_insights_provider.dart'; // NEW
import 'package:biztonic_pos/services/sync_service.dart';

import 'package:biztonic_pos/screens/auth_screen.dart';
import 'package:biztonic_pos/screens/auth/employee_login_screen.dart'; // NEW
import 'package:biztonic_pos/screens/splash_screen.dart'; // NEW
import 'package:biztonic_pos/screens/auth/create_store_screen.dart';
import 'package:biztonic_pos/screens/auth/store_select_screen.dart';
import 'package:biztonic_pos/screens/auth/set_password_screen.dart'; // NEW
import 'package:biztonic_pos/screens/printer_screen.dart';
import 'package:biztonic_pos/screens/pos_screen.dart';
import 'package:biztonic_pos/screens/inventory_screen.dart';
import 'package:biztonic_pos/screens/sales_screen.dart';
import 'package:biztonic_pos/screens/customers_screen.dart';
import 'package:biztonic_pos/screens/employees_screen.dart';
import 'package:biztonic_pos/screens/staff/staff_dashboard_screen.dart'; // NEW
import 'package:biztonic_pos/screens/reports_screen.dart';
import 'package:biztonic_pos/screens/settings_screen.dart';
import 'package:biztonic_pos/screens/dashboard_overview_screen.dart';
import 'package:biztonic_pos/screens/user_management_screen.dart';
import 'package:biztonic_pos/screens/admin/store_management_screen.dart';
import 'package:biztonic_pos/screens/admin/user_role_management_screen.dart';

import 'package:biztonic_pos/screens/admin/franchise_screen.dart';
import 'package:biztonic_pos/screens/admin/basic_plan_settings_screen.dart'; // NEW
import 'package:biztonic_pos/screens/supplier_screen.dart';
import 'package:biztonic_pos/screens/admin_dashboard_screen.dart'; // Admin Dashboard
import 'package:biztonic_pos/screens/settings/biz_store_screen.dart'; // NEW
import 'package:biztonic_pos/screens/language_screen.dart';
import 'package:biztonic_pos/screens/settings/data_sync_control_screen.dart'; // Dedicated Sync Screen
import 'package:biztonic_pos/screens/integration/integration_hub_screen.dart'; // NEW
import 'package:biztonic_pos/screens/reports/unified_sales_report_screen.dart'; // NEW
import 'package:biztonic_pos/screens/reports/inventory_reports_screen.dart'; // NEW
import 'package:biztonic_pos/screens/reports/customer_reports_screen.dart'; // NEW
import 'package:biztonic_pos/screens/reports/financial_reports_screen.dart'; // NEW
import 'package:biztonic_pos/screens/reports/audit_log_screen.dart'; // NEW
import 'package:biztonic_pos/utils/theme.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // SQFlite Windows
// import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'; // SQFlite Web
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform; // Platform Checks

import 'services/printer_manager_service.dart';
// import 'models/user_model.dart'; // Removed
import 'models/table_model.dart'; // Added
import 'services/offline_service.dart';

import 'widgets/feature_guard.dart';
// Import Mock Screen
// Import FeatureGuard
// NEW
import 'widgets/demo_overlay_widget.dart'; // NEW
import 'providers/locale_provider.dart'; // LOCALIZATION
import 'l10n/app_localizations.dart'; // LOCALIZATION
import 'package:flutter_localizations/flutter_localizations.dart'; // LOCALIZATION
import 'screens/tables/table_management_screen.dart'; // NEW

/// Global Navigator Key to allow showing generic dialogs/snackbars from outside widgets (like Providers)
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class RouterNotifier extends ChangeNotifier {
  void notify() {
    debugPrint('🔔 RouterNotifier: Notifying listeners...');
    notifyListeners();
  }
}

Future<void> main() async {
  debugPrint('🚀 APP STARTING - MAIN');
  setPathUrlStrategy(); // NEW: Removes hash from URL
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('✅ WidgetsFlutterBinding Initialized');

    // Enable Immersive Mode (Hide System Bars)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

 

    // Initialize FFI for Windows/Linux (SQFlite)
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    
    if (kIsWeb) {
      // Initialize Web DB
      // databaseFactory = databaseFactoryFfiWeb;
    }

    try {
      debugPrint('🔥 Initializing Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase Initialized');

      // Pass all uncaught 'fatal' errors from the framework to Crashlytics
      FlutterError.onError = (FlutterErrorDetails details) {
         if (!kIsWeb) {
           FirebaseCrashlytics.instance.recordFlutterFatalError(details);
         }

      };

      // Global Error Widget (Replace Red Screen of Death)
      ErrorWidget.builder = (FlutterErrorDetails details) {
        if (!kIsWeb) {
          FirebaseCrashlytics.instance.recordFlutterError(details);
        }

        return Directionality(
          textDirection: TextDirection.ltr,
          child: Material( // Use Material, not MaterialApp/Scaffold
            color: Colors.white, // Use solid white for crash view
            child: Center(
              child: Card(
                color: AppColors.error,
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Constrain height
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 50),
                      const SizedBox(height: 10),
                      const Text("Something went wrong!",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.error)),
                      const SizedBox(height: 5),
                      Text(details.exception.toString(),
                          textAlign: TextAlign.center, maxLines: 3),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      };

      // Initialize Firestore with default database and offline persistence
      final db = FirebaseFirestore.instance;
      
      if (kIsWeb) {
        db.settings = const Settings(
          persistenceEnabled: false, // DISABLE OFF-LINE PERSISTENCE ON WEB TO FIX QUIC/INDEXEDDB ISSUES
          sslEnabled: true,
        );
      } else {
        db.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      }

      // Initialize Hive for local storage
      debugPrint('🐝 Initializing Hive...');
      await Hive.initFlutter();
      debugPrint('✅ Hive Initialized');

      // Parallel initialization for optimal startup speed
      debugPrint('⏳ Starting Parallel Init...');
      await Future.wait([
        if (!kIsWeb) PrinterManagerService().init().then((_) => debugPrint('🖨️ Printer Service Init Done')),
        OfflineService().init().then((_) => debugPrint('🌐 Offline Service Init Done')),
        SyncService().init().then((_) => debugPrint('🔄 Sync Service Init Done')), // NEW
        Future.wait([
          Hive.openBox('settings'),
          Hive.openBox('sync_queue'),
          Hive.openBox('cache_inventory'),
          Hive.openBox('cache_orders'),
          Hive.openBox('cache_customers'),
          Hive.openBox('auth_cache'),
          Hive.openBox('cache_employees'), 
          Hive.openBox('cache_stores'),
          Hive.openBox('cache_floors'),
          Hive.openBox('cache_tables'),
          Hive.openBox('cache_suppliers'),
          Hive.openBox('cache_notes'),
          Hive.openBox('error_logs'),
        ]).then((_) => debugPrint('📦 Hive Boxes Opened')),
      ]);
      debugPrint('✅ Parallel Init Complete');

    } catch (e) {
      debugPrint('❌ Initialization Error: $e');
      if (!kIsWeb) {
        // FirebaseCrashlytics.instance.recordError(e, stack, fatal: true); // Might be null if init failed
      }
      // Continue to runApp even if init fails (Offline Mode / Error State)
    }

    debugPrint('🚀 Calling runApp(MyApp)');
    runApp(const MyApp());
  }, (error, stack) {

    // Pass all uncaught async errors to Crashlytics
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    debugPrint('❌ Fatal Error: $error');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ MyApp.build called');

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RouterNotifier()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        
        // NEW: Order Provider (Needs SyncService from Dashboard? No, SyncService is internal or detached?)
        // Wait, OrderProvider needs SyncService. 
        // DashboardProvider instantiates SyncService internally: `final SyncService _syncService = SyncService();`
        // We need to share the SAME SyncService instance or make it a singleton/provider.
        // Currently SyncService is a factory singleton in its file? Let's check.
// ...

// ...

        ChangeNotifierProvider(create: (_) => OrderProvider(SyncService())), 
        ChangeNotifierProvider(create: (_) => CustomerProvider(SyncService())), 
        ChangeNotifierProvider(create: (_) => StoreProvider(SyncService())), // NEW
        ChangeNotifierProxyProvider6<AuthProvider, InventoryProvider, OrderProvider, CustomerProvider, StoreProvider, RouterNotifier, DashboardProvider>(
          create: (_) => DashboardProvider(),
          update: (_, auth, inventory, orders, customers, stores, router, dashboard) => dashboard!
            ..updateAuthStatus(auth.isOfflineLoggedIn)
            ..init()
            ..injectInventory(inventory)
            ..injectOrderProvider(orders)
            ..injectCustomerProvider(customers)
            ..injectStoreProvider(stores)
            ..injectRouterNotifier(router), // Inject RouterNotifier
        ),
        
        ChangeNotifierProxyProvider<DashboardProvider, TableProvider>(
          create: (_) => TableProvider(),
          update: (_, dashboard, tableProvider) => tableProvider!..setActiveStoreId(dashboard.activeStoreId),
        ),
        
        ChangeNotifierProxyProvider3<DashboardProvider, OrderProvider, InventoryProvider, SmartInsightsProvider>(
          create: (context) => SmartInsightsProvider(
            Provider.of<DashboardProvider>(context, listen: false),
            Provider.of<OrderProvider>(context, listen: false),
            Provider.of<InventoryProvider>(context, listen: false),
          ),
          update: (_, dashboard, orders, inventory, prev) => 
            prev ?? SmartInsightsProvider(dashboard, orders, inventory), // Ensure updates if refs change (unlikely but safe)
        ),
      ],
      child: const BizPOSApp(),
    );
  }
}

class BizPOSApp extends StatefulWidget {
  const BizPOSApp({super.key});

  @override
  State<BizPOSApp> createState() => _BizPOSAppState();
}

class _BizPOSAppState extends State<BizPOSApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final routerNotifier =
        Provider.of<RouterNotifier>(context, listen: false);

    _router = GoRouter(
      navigatorKey: appNavigatorKey,
      initialLocation: '/splash',
      refreshListenable: Listenable.merge([authProvider, routerNotifier]),
      redirect: (context, state) {

        final isLoggedIn = authProvider.isLoggedIn;
        final isLoggingIn = state.uri.path == '/login';
        final isEmployeeLogin = state.uri.path == '/employee-login'; // FIXED: use path to ignore query params
        final isSetPassword = state.uri.path == '/set-password'; // NEW
        final isSplash = state.uri.path == '/splash';

        if (isSplash) return null; // Allow splash to show
        
        final isRoot = state.uri.path == '/';
        if (isRoot) {
           if (!isLoggedIn) return '/login';
           return '/dashboard'; // Let the main logic decide the final destination
        }
        if (!isLoggedIn && !isLoggingIn && !isEmployeeLogin && !isSetPassword) return '/login';        

        // Onboarding Logic
        if (isLoggedIn) {
          // Allow Employee Login flow to complete without interference
          if (isEmployeeLogin) return null;

          final dashboard =
              Provider.of<DashboardProvider>(context, listen: false);

          debugPrint('🧭 main.dart: Redirect Check - Path: ${state.uri.path}, Role: ${dashboard.activeRole}, Initialized: ${dashboard.isInitialized}, Stores: ${dashboard.stores.length}, ActiveStoreId: ${dashboard.activeStoreId}');

          // Wait for DashboardProvider to finish initial fetch before redirecting
          if (authProvider.isLoggedIn && !dashboard.isInitialized) {
             debugPrint('⏳ main.dart: Waiting for DashboardProvider initialization...');
             return null; 
          }
          
          // Bypass for Offline/Employee Login (Employees cannot create stores here)
          if (authProvider.isOfflineLoggedIn) {
             final isLoggingIn = state.uri.path == '/login';
             if (isLoggingIn) {
                debugPrint('🚀 main.dart: Offline login detected, redirecting to /dashboard');
                return '/dashboard'; 
             }
             return null; 
          }

          // NEW: Redirect to Selection or Create Store if no store active
          final isCreateStore = state.uri.path == '/create-store';
          final isSelectStore = state.uri.path == '/select-store';

          if (dashboard.activeStoreId == null && !isCreateStore && !isSelectStore) {
             final role = dashboard.activeRole;
             final isSuperAdmin = dashboard.isSuperAdmin;
             final hasStores = dashboard.hasAnyStore;
             final hasChecked = dashboard.hasCheckedStores;
             final storeCount = dashboard.stores.length;

             // SKIP SELECTION if only one store exists
             if (storeCount == 1 && !isSuperAdmin) {
                final soloStoreId = dashboard.stores.first.id;
                debugPrint('🎯 main.dart: Only one store found ($soloStoreId). Auto-selecting and skipping list.');
                return '/dashboard';
             }

             if (isSuperAdmin || hasStores) {
                debugPrint('🏪 main.dart: Redirecting to /select-store (SuperAdmin: $isSuperAdmin, HasStores: $hasStores, Count: $storeCount)');
                return '/select-store';
             } else if (role == 'Store Owner' && hasChecked) {
                // REDIRECT TO SELECTION: We no longer auto-redirect to /create-store based on user age.
                // Existing users with slow sync were being mistakenly redirected to "New Store" flow.
                debugPrint('🔄 main.dart: Redirecting owner to /select-store (Checked: $hasChecked)');
                return '/select-store';
             }
             
             debugPrint('⏳ main.dart: Waiting for role/store check (Role: $role, Checked: $hasChecked)');
             return null;
          }
          
          // If on Create/Select but already has active store, go to dashboard
          if (dashboard.activeStoreId != null && (isCreateStore || isSelectStore)) {
             debugPrint('🚀 main.dart: Active store found, moving from ${state.uri.path} to /dashboard');
             return '/dashboard'; 
          }

          // DISABLED: Profile completion step removed per user request
          // Redirect any attempts to go to complete-profile to dashboard
          if (state.uri.path == '/complete-profile') {
            return '/dashboard';
          }
          
          // Users can proceed directly to dashboard after login
          // If logged in but NO store and NOT in Demo Mode -> Plan Selection
          // (This logic can be added here if needed in the future)
        }

        if (isLoggedIn && isLoggingIn) return '/dashboard';
        return null;
      },
      routes: [
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

        // REMOVED: Complete profile route (mobile number requirement)
        // GoRoute(
        //   path: '/complete-profile',
        //   builder: (context, state) => const CompleteProfileScreen(),
        // ),

        ShellRoute(
          builder: (context, state, child) {

            return DemoOverlayWidget(child: UniversalShell(child: child));
          },
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) {
                final provider =
                    Provider.of<DashboardProvider>(context, listen: false);
                if (provider.uiStyle == UIStyle.car_dashboard) {
                  return const DashboardInsightsScreen(); // Changed from DashboardGridMenu
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
                    final provider =
                        Provider.of<DashboardProvider>(context, listen: false);
                    if (provider.uiStyle == UIStyle.car_dashboard) {
                      return const CarDashboardPOSScreen();
                    }
                    // Handle Table Selection from TableManagementScreen
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
              builder: (context, state) => const FeatureGuard(
                  featureKey: 'inventory', child: InventoryScreen()),
            ),
            GoRoute(
              path: '/printer',
              builder: (context, state) => const PrinterScreen(),
            ),
            // Functional Screens (Connected to Backend)
            GoRoute(
                path: '/sales',
                builder: (context, state) => const FeatureGuard(
                    featureKey: 'reports', child: SalesScreen())),
            GoRoute(
                path: '/customers',
                builder: (context, state) => const FeatureGuard(
                    featureKey: 'crm', child: CustomersScreen())),
            GoRoute(
                path: '/employees',
                builder: (context, state) => const FeatureGuard(
                    featureKey: 'employees', child: StaffDashboardScreen())),
            GoRoute(
                path: '/staff-list',
                builder: (context, state) {
                   int tabIndex = 0;
                   if (state.extra is int) {
                      tabIndex = state.extra as int;
                   }
                   return FeatureGuard(
                    featureKey: 'employees', child: EmployeesScreen(initialTabIndex: tabIndex));
                }),
            GoRoute(
                path: '/users',
                builder: (context, state) => const UserManagementScreen()),
            GoRoute(
                path: '/reports',
                builder: (context, state) => const FeatureGuard(
                    featureKey: 'reports', child: ReportsScreen())),
            GoRoute(
                path: '/suppliers',
                builder: (context, state) => const FeatureGuard(
                    featureKey: 'inventory', child: SupplierScreen())),
            // Removed route for 'Expenses' feature configuration
            GoRoute(
                path: '/kds',
                builder: (context, state) => const FeatureGuard(
                    featureKey: 'kds_management', child: KitchenDisplayScreen())),
            GoRoute(
                path: '/display',
                builder: (context, state) => const FeatureGuard(
                    featureKey: 'kds_management', child: DisplayManagementScreen())),
            // Removed route for 'Tables' feature configuration
            GoRoute(
                path: '/settings',
                builder: (context, state) => const FeatureGuard(
                    featureKey: 'settings', child: SettingsScreen())),
            GoRoute(
                path: '/printer',
                builder: (context, state) => const PrinterScreen()),
            GoRoute(
                path: '/stores',
                builder: (context, state) => const FeatureGuard(
                    featureKey: 'admin', child: StoreManagementScreen())),
            GoRoute(
                path: '/roles',
                builder: (context, state) => const FeatureGuard(
                    featureKey: 'admin', child: UserRoleManagementScreen())),

            // Dedicated Data Control Center
            GoRoute(
                path: '/data-sync',
                builder: (context, state) => const FeatureGuard(
                    featureKey: 'settings', child: DataSyncControlScreen())),

            // Web Parity
            GoRoute(
                path: '/franchises',
                builder: (context, state) => const FeatureGuard(
                    featureKey: 'franchises', child: FranchiseScreen())),

            GoRoute(
                path: '/admin',
                builder: (context, state) => const FeatureGuard(
                    featureKey: 'admin', child: AdminDashboardScreen())),
            GoRoute(
                path: '/admin/limits',
                builder: (context, state) => const FeatureGuard(
                    featureKey: 'admin', child: BasicPlanSettingsScreen())),
            GoRoute(
                path: '/languages',
                builder: (context, state) => const FeatureGuard(
                    featureKey: 'admin', child: LanguageScreen())),
            GoRoute(
                path: '/integrations',
                builder: (context, state) => const FeatureGuard(
                    featureKey: 'integration_hub', child: IntegrationHubScreen())),
            GoRoute(
                path: '/biz-store',
                builder: (context, state) => const FeatureGuard(
                    featureKey: 'admin', child: BizStoreScreen())),
            
            GoRoute(
                path: '/reports/sales',
                builder: (context, state) => const UnifiedSalesReportScreen()), // NEW
            
            GoRoute(
                path: '/reports/inventory',
                builder: (context, state) => const InventoryReportsScreen()), // NEW
            
            GoRoute(
                path: '/reports/customers',
                builder: (context, state) => const CustomerReportsScreen()), // NEW
            
            GoRoute(
                path: '/reports/financials',
                builder: (context, state) => const FeatureGuard(featureKey: 'reports', child: FinancialReportsScreen())), // NEW
            
            GoRoute(
                path: '/reports/audit',
                builder: (context, state) => const AuditLogScreen()), // NEW
                
            GoRoute(
                path: '/tables',
                builder: (context, state) => const FeatureGuard(
                    featureKey: 'pos', child: TableManagementScreen())),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {

    return Selector<DashboardProvider, _RootThemeData>(
      selector: (_, p) => _RootThemeData(
        uiStyle: p.uiStyle,
        isDarkMode: p.isDarkMode,
        currentTheme: p.currentTheme,
        customThemeColor: p.customThemeColor,
      ),
      builder: (context, themeData, _) {
        return Consumer<LocaleProvider>(
          builder: (context, localeProvider, _) {
            final appDensity = themeData.uiStyle == UIStyle.car_dashboard 
                ? AppDensity.touch 
                : AppDensity.comfortable; // Default or fetched from settings later

            // Overlay Automotive Theme if active
            if (themeData.uiStyle == UIStyle.car_dashboard) {
              return AppDensityProvider(
                density: appDensity,
                child: MaterialApp.router(
                  title: 'BizPOS Auto',
                  theme: CarDashboardTheme.getThemeData(isDark: themeData.isDarkMode),
                  themeMode: themeData.isDarkMode ? ThemeMode.dark : ThemeMode.light,
                  locale: localeProvider.locale,
                  localizationsDelegates: const [
                    AppLocalizationsDelegate(),
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [
                    Locale('en'), // English
                    Locale('hi'), // Hindi
                    Locale('mr'), // Marathi
                  ],
                  routerConfig: _router,
                  debugShowCheckedModeBanner: false,
                ),
              );
            }

            return AppDensityProvider(
              density: appDensity,
              child: MaterialApp.router(
                title: 'BizPOS',
                theme: AppTheme.getTheme(themeData.currentTheme, false,
                    customSeed: themeData.customThemeColor != null
                        ? Color(themeData.customThemeColor!)
                        : null),
                darkTheme: AppTheme.getTheme(themeData.currentTheme, true,
                    customSeed: themeData.customThemeColor != null
                        ? Color(themeData.customThemeColor!)
                        : null),
                themeMode: themeData.isDarkMode ? ThemeMode.dark : ThemeMode.light,
                locale: localeProvider.locale,
                localizationsDelegates: const [
                  AppLocalizationsDelegate(),
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('en'), // English
                  Locale('hi'), // Hindi
                  Locale('mr'), // Marathi
                ],
                routerConfig: _router,
                debugShowCheckedModeBanner: false,
              ),
            );
          },
        );
      },
    );
  }
}

class _RootThemeData {
  final UIStyle uiStyle;
  final bool isDarkMode;
  final AppColorTheme currentTheme;
  final int? customThemeColor;

  _RootThemeData({
    required this.uiStyle,
    required this.isDarkMode,
    required this.currentTheme,
    this.customThemeColor,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _RootThemeData &&
          runtimeType == other.runtimeType &&
          uiStyle == other.uiStyle &&
          isDarkMode == other.isDarkMode &&
          currentTheme == other.currentTheme &&
          customThemeColor == other.customThemeColor;

  @override
  int get hashCode => Object.hash(uiStyle, isDarkMode, currentTheme, customThemeColor);
}
