import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../core/initialization/platform_initializer.dart';
import '../core/registry/registry.dart';
import 'firebase_bootstrap.dart';
import 'hive_bootstrap.dart';
import 'service_bootstrap.dart';

// --- All Addon Modules ---
import '../modules/tables/tables_module.dart';
import '../modules/data_center/data_center_module.dart';
import '../modules/suppliers/suppliers_module.dart';
import '../modules/kds/kds_module.dart';
import '../modules/integrations/integrations_module.dart';
import '../modules/crm/crm_module.dart';
import '../modules/employees/employees_module.dart';
import '../modules/franchise/franchise_module.dart';

class AppBootstrap {
  /// Master registry of ALL available modules.
  /// Each module is self-contained and implements POSModule.
  /// To add a new addon: create folder in lib/modules/, implement POSModule, add here.
  static List<POSModule> get allAvailableModules => [
    TablesModule(),
    DataCenterModule(),
    SuppliersModule(),
    KdsModule(),
    IntegrationsModule(),
    CrmModule(),
    EmployeesModule(),
    FranchiseModule(),
  ];

  static Future<void> run(Widget app) async {
    await runZonedGuarded<Future<void>>(() async {
      await PlatformInitializer.init();

      try {
        await FirebaseBootstrap.init();
        await HiveBootstrap.init();
        await ServiceBootstrap.init();

        // Initialize ALL addon modules via the registry.
        // The sidebar and router will only show modules that match
        // the store's purchased addons (via DashboardProvider.hasAddon()).
        await POSCoreRegistry.initialize(allAvailableModules);
      } catch (e, stack) {
        debugPrint('❌ Initialization Error: $e');
        if (!kIsWeb) {
          FirebaseCrashlytics.instance.recordError(e, stack, fatal: true);
        }
        // Continue anyway to allow offline mode/error recovery
      }

      runApp(app);
    }, (error, stack) {
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
      debugPrint('❌ Fatal Error: $error');
    });
  }
}
