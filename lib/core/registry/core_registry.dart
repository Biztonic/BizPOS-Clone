import 'package:flutter/widgets.dart';
import 'pos_module.dart';

/// Central registry that manages all plug-and-play BizPOS modules.
///
/// During app bootstrap, [initialize] is called with a list of active modules.
/// Each module is initialized in order, and its routes, sidebar entries,
/// and sync tasks are aggregated for global consumption.
///
/// Usage in main.dart / bootstrap:
/// ```dart
/// await POSCoreRegistry.initialize([
///   SalesModule(),       // Core — always loaded
///   InventoryModule(),   // Core — always loaded
///   TablesModule(),      // Addon — loaded if purchased
///   DataCenterModule(),  // Addon — loaded if purchased
/// ]);
/// ```
class POSCoreRegistry {
  POSCoreRegistry._();

  static final List<POSModule> _registeredModules = [];
  static bool _isInitialized = false;

  /// All currently registered and active modules.
  static List<POSModule> get modules => List.unmodifiable(_registeredModules);

  /// Whether the registry has been initialized.
  static bool get isInitialized => _isInitialized;

  /// Initialize all provided modules in sequence.
  /// Each module will:
  /// 1. Initialize its offline storage
  /// 2. Register its dependencies
  /// 3. Be added to the active modules list
  static Future<void> initialize(List<POSModule> activeModules) async {
    if (_isInitialized) {
      debugPrint('⚠️ [Registry] Already initialized. Skipping.');
      return;
    }

    debugPrint('🔌 [Registry] Initializing ${activeModules.length} modules...');

    for (var module in activeModules) {
      try {
        debugPrint('🔌 [Registry] Connecting: [${module.moduleName.toUpperCase()}] (${module.moduleId})...');
        await module.initializeOffline();
        module.registerDependencies();
        _registeredModules.add(module);
        debugPrint('✅ [Registry] Module connected: [${module.moduleName}]');
      } catch (e, stack) {
        debugPrint('❌ [Registry] Failed to initialize module [${module.moduleName}]: $e');
        debugPrint('$stack');
        // Don't block other modules from loading
      }
    }

    _isInitialized = true;
    debugPrint('🏁 [Registry] ${_registeredModules.length}/${activeModules.length} modules active.');
  }

  /// Get aggregated routes from all registered modules.
  /// These can be merged into GoRouter's route configuration.
  static Map<String, WidgetBuilder> getGlobalRoutes() {
    final Map<String, WidgetBuilder> globalRoutes = {};
    for (var module in _registeredModules) {
      globalRoutes.addAll(module.registerRoutes());
    }
    return globalRoutes;
  }

  /// Get aggregated sidebar entries from all registered modules.
  /// These can be used by PosSidebar to dynamically build menu items.
  static List<Map<String, dynamic>> getSidebarEntries(BuildContext context) {
    final List<Map<String, dynamic>> entries = [];
    for (var module in _registeredModules) {
      entries.addAll(module.getSidebarEntries(context));
    }
    return entries;
  }

  /// Check if a specific module is currently registered and active.
  static bool isModuleActive(String moduleId) {
    return _registeredModules.any((m) => m.moduleId == moduleId);
  }

  /// Get a specific module by its ID (returns null if not registered).
  static POSModule? getModule(String moduleId) {
    try {
      return _registeredModules.firstWhere((m) => m.moduleId == moduleId);
    } catch (_) {
      return null;
    }
  }

  /// Dynamically attach a new module at runtime.
  /// Useful for hot-loading an addon after purchase without app restart.
  static Future<void> attachModule(POSModule module) async {
    if (_registeredModules.any((m) => m.moduleId == module.moduleId)) {
      debugPrint('⚠️ [Registry] Module [${module.moduleName}] already attached.');
      return;
    }

    try {
      debugPrint('🔌 [Registry] Hot-attaching: [${module.moduleName}]...');
      await module.initializeOffline();
      module.registerDependencies();
      _registeredModules.add(module);
      debugPrint('✅ [Registry] Module hot-attached: [${module.moduleName}]');
    } catch (e) {
      debugPrint('❌ [Registry] Failed to hot-attach [${module.moduleName}]: $e');
    }
  }

  /// Dynamically detach a module at runtime.
  /// Useful for disabling an addon when subscription expires.
  static Future<void> detachModule(String moduleId) async {
    final module = getModule(moduleId);
    if (module == null) {
      debugPrint('⚠️ [Registry] Module [$moduleId] not found for detachment.');
      return;
    }

    if (module.isCoreModule) {
      debugPrint('🚫 [Registry] Cannot detach core module: [${module.moduleName}]');
      return;
    }

    try {
      await module.dispose();
      _registeredModules.removeWhere((m) => m.moduleId == moduleId);
      debugPrint('🔌 [Registry] Module detached: [${module.moduleName}]');
    } catch (e) {
      debugPrint('❌ [Registry] Error detaching [${module.moduleName}]: $e');
    }
  }

  /// Reset the registry (primarily for testing purposes).
  @visibleForTesting
  static Future<void> reset() async {
    for (var module in _registeredModules) {
      await module.dispose();
    }
    _registeredModules.clear();
    _isInitialized = false;
  }
}
