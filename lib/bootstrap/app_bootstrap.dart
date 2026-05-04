import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../core/initialization/platform_initializer.dart';
import 'firebase_bootstrap.dart';
import 'hive_bootstrap.dart';
import 'service_bootstrap.dart';

class AppBootstrap {
  static Future<void> run(Widget app) async {
    await runZonedGuarded<Future<void>>(() async {
      await PlatformInitializer.init();

      try {
        await FirebaseBootstrap.init();
        await HiveBootstrap.init();
        await ServiceBootstrap.init();
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
