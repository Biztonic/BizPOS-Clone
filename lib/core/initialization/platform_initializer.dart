import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:url_strategy/url_strategy.dart';

class PlatformInitializer {
  static Future<void> init() async {
    debugPrint('🚀 Initializing Platform...');
    
    // Removes hash from URL for Web
    setPathUrlStrategy();

    // Ensure Flutter is initialized
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('✅ WidgetsFlutterBinding Initialized');

    // Enable Immersive Mode (Hide System Bars)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Initialize FFI for Windows/Linux (SQFlite)
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    
    debugPrint('✅ Platform Initialization Complete');
  }
}
