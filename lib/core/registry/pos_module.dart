import 'package:flutter/widgets.dart';

/// Base contract for all plug-and-play BizPOS modules.
///
/// Every addon (Tables, Data Center, KDS, Suppliers, etc.) must implement
/// this interface to be dynamically loaded by the [POSCoreRegistry].
///
/// A module is a self-contained business feature that:
/// - Owns its own offline storage initialization
/// - Registers its own dependency injection (providers/blocs)
/// - Declares its own navigation routes
/// - Declares its own sidebar menu entries
/// - Declares its own background sync tasks
///
/// Example usage:
/// ```dart
/// class TablesModule implements POSModule {
///   @override
///   String get moduleId => 'table_reservation';
///   @override
///   String get moduleName => 'Tables';
///   // ...
/// }
/// ```
abstract class POSModule {
  /// Unique module identifier — must match the addon key in Firestore
  /// (e.g., 'table_reservation', 'data_center', 'kds_management')
  String get moduleId;

  /// Human-readable display name (e.g., 'Tables', 'Data Center')
  String get moduleName;

  /// Whether this module is a core module (always loaded) or an addon (conditionally loaded)
  bool get isCoreModule => false;

  /// Initialize the module's offline storage (Hive boxes, SQLite tables, etc.)
  /// Called once during app bootstrap.
  Future<void> initializeOffline();

  /// Register the module's dependency injection (Riverpod providers, legacy providers, etc.)
  /// Called after [initializeOffline] completes.
  void registerDependencies();

  /// Return navigation route entries this module adds to the app.
  /// The key is the route path (e.g., '/tables'), and the value is the widget builder.
  /// These will be merged into the global GoRouter configuration.
  Map<String, WidgetBuilder> registerRoutes();

  /// Return sidebar menu entries for this module.
  /// Each entry is a map with 'icon', 'label', 'route', 'key', 'color'.
  List<Map<String, dynamic>> getSidebarEntries(BuildContext context);

  /// Dispose any resources when the module is detached.
  Future<void> dispose() async {}
}
