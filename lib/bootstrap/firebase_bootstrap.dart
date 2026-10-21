import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import '../../firebase_options.dart';
import '../../core/design/tokens/app_colors.dart';
import '../utils/web_cache_cleaner_stub.dart'
    if (dart.library.html) '../utils/web_cache_cleaner_web.dart' as cache_cleaner;

class FirebaseBootstrap {
  static Future<void> init() async {
    if (kIsWeb) {
      cache_cleaner.purgeStaleAppCheckWebStorage();
    }
    debugPrint('🔥 Initializing Firebase...');

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase Initialized');

    await _setupAppCheck();
    _setupCrashlytics();
    _setupFirestore();
  }

  static Future<void> _setupAppCheck() async {
    try {
      if (kIsWeb) {
        // Bypass dummy AppCheck key on web to prevent 400 Bad Request & token rejection on Chrome
        debugPrint('🛡️ Firebase App Check bypassed for web');
        return;
      }
      // ignore: deprecated_member_use
      await FirebaseAppCheck.instance.activate(
        // ignore: deprecated_member_use
        androidProvider: kReleaseMode
            ? AndroidProvider.playIntegrity
            : AndroidProvider.debug,
        // ignore: deprecated_member_use
        appleProvider:
            kReleaseMode ? AppleProvider.deviceCheck : AppleProvider.debug,
      );
      debugPrint('🛡️ Firebase App Check Activated');
    } catch (e) {
      debugPrint('⚠️ Firebase App Check bypassed or unsupported: $e');
    }
  }

  static void _setupCrashlytics() {
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
        child: Material(
          color: AppColors.surfaceLight,
          child: Center(
            child: Card(
              color: AppColors.error,
              margin: const EdgeInsets.all(AppSpacing.md),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 50),
                    const SizedBox(height: AppSpacing.md),
                    const Text("Something went wrong!",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error)),
                    const SizedBox(height: AppSpacing.sm),
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
  }

  static void _setupFirestore() {
    final db = FirebaseFirestore.instance;
    if (kIsWeb) {
      db.settings = const Settings(
        persistenceEnabled: false,
        sslEnabled: true,
      );
    } else {
      db.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
  }
}
