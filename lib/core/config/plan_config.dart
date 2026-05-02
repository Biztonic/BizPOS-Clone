/// Centralized subscription plan configuration.
///
/// Consolidates plan limits that were previously scattered across
/// SyncService, DashboardProvider, and various UI files.
class PlanConfig {
  PlanConfig._();

  // ─── Plan Names ─────────────────────────────────────────────
  static const String planStarting = 'Starting';
  static const String planBasic = 'Basic';
  static const String planStandard = 'Standard';
  static const String planProfessional = 'Professional';
  static const String planEnterprise = 'Enterprise';

  // ─── Default Limits (Starting Plan) ─────────────────────────
  static const int startingMaxOrders = 50;
  static const int startingMaxInventory = 30;
  static const int startingMaxCustomers = 20;
  static const int startingMaxEmployees = 2;
  static const int startingMaxStores = 1;

  // ─── Basic Plan Limits ──────────────────────────────────────
  static const int basicMaxOrders = 500;
  static const int basicMaxInventory = 200;
  static const int basicMaxCustomers = 100;
  static const int basicMaxEmployees = 5;
  static const int basicMaxStores = 1;
  static const int basicCloudRetentionDays = 30;
  static const String basicSyncFrequency = '1_DAY';

  // ─── Standard Plan Limits ───────────────────────────────────
  static const int standardMaxOrders = -1; // Unlimited
  static const int standardMaxInventory = -1;
  static const int standardMaxCustomers = -1;
  static const int standardMaxEmployees = 15;
  static const int standardMaxStores = 3;

  // ─── Feature Flags by Plan ──────────────────────────────────
  static const Map<String, List<String>> planFeatures = {
    planStarting: ['billing', 'basic_inventory'],
    planBasic: ['billing', 'inventory', 'customers', 'basic_reports'],
    planStandard: [
      'billing', 'inventory', 'customers', 'employees',
      'reports', 'tables', 'floors', 'suppliers',
    ],
    planProfessional: [
      'billing', 'inventory', 'customers', 'employees',
      'reports', 'tables', 'floors', 'suppliers',
      'advanced_reports', 'multi_store', 'api_access',
    ],
    planEnterprise: ['*'], // All features
  };

  /// Get the limit for a specific resource in a specific plan.
  static int getLimit(String plan, String resource) {
    final limits = _planLimits[plan] ?? _planLimits[planStarting]!;
    return limits[resource] ?? 0;
  }

  /// Check if a feature is available in a plan.
  static bool isFeatureAvailable(String plan, String feature) {
    final features = planFeatures[plan];
    if (features == null) return false;
    if (features.contains('*')) return true;
    return features.contains(feature);
  }

  static const Map<String, Map<String, int>> _planLimits = {
    planStarting: {
      'orders': startingMaxOrders,
      'inventory': startingMaxInventory,
      'customers': startingMaxCustomers,
      'employees': startingMaxEmployees,
      'stores': startingMaxStores,
    },
    planBasic: {
      'orders': basicMaxOrders,
      'inventory': basicMaxInventory,
      'customers': basicMaxCustomers,
      'employees': basicMaxEmployees,
      'stores': basicMaxStores,
    },
    planStandard: {
      'orders': standardMaxOrders,
      'inventory': standardMaxInventory,
      'customers': standardMaxCustomers,
      'employees': standardMaxEmployees,
      'stores': standardMaxStores,
    },
    planProfessional: {
      'orders': -1,
      'inventory': -1,
      'customers': -1,
      'employees': -1,
      'stores': 10,
    },
    planEnterprise: {
      'orders': -1,
      'inventory': -1,
      'customers': -1,
      'employees': -1,
      'stores': -1,
    },
  };
}
