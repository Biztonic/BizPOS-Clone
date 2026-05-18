import 'package:flutter/material.dart';
import '../../core/registry/pos_module.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../screens/settings/data_sync_control_screen.dart';

/// Data Center & Cloud Sync addon module.
///
/// This module provides:
/// - Manual and automatic sync controls
/// - Sync conflict resolution UI
/// - Real-time sync status monitoring
///
/// Firestore addon key: `data_center`
class DataCenterModule implements POSModule {
  @override
  String get moduleId => 'data_center';

  @override
  String get moduleName => 'Data Center';

  @override
  bool get isCoreModule => false;

  @override
  Future<void> initializeOffline() async {
    debugPrint('☁️ [DataCenterModule] Offline storage ready.');
  }

  @override
  void registerDependencies() {
    debugPrint('☁️ [DataCenterModule] Dependencies registered.');
  }

  @override
  Map<String, WidgetBuilder> registerRoutes() {
    return {
      '/data-sync': (context) => const DataSyncControlScreen(),
    };
  }

  @override
  List<Map<String, dynamic>> getSidebarEntries(BuildContext context) {
    return [
      {
        'icon': Icons.sync_alt,
        'label': AppLocalizations.t(context, 'Data Center'),
        'route': '/data-sync',
        'key': 'data_center',
        'color': AppColors.primary,
      },
    ];
  }

  @override
  Future<void> dispose() async {
    debugPrint('☁️ [DataCenterModule] Disposed.');
  }
}
