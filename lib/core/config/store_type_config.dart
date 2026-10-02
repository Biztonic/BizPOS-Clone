import 'package:flutter/material.dart';

/// Metadata definition for a configurable peripheral feature of a store type.
class PeripheralFeatureMeta {
  final String id;
  final String configKey;
  final String? canonicalAddonKey;
  final String label;
  final String description;
  final IconData icon;
  final String category; // 'operations', 'management', 'catalog'
  final List<String> relatedKeys;

  const PeripheralFeatureMeta({
    required this.id,
    required this.configKey,
    this.canonicalAddonKey,
    required this.label,
    required this.description,
    required this.icon,
    required this.category,
    required this.relatedKeys,
  });
}

/// Centralized Store Type and Peripheral Feature Configuration.
///
/// Distinguishes Core features (always available for every store type)
/// from Peripheral features (configured by Superadmin per Store Type).
class StoreTypeConfig {
  StoreTypeConfig._();

  // ─── Default Store Types ─────────────────────────────────────
  static const List<String> defaultStoreTypes = [
    'Restaurant',
    'Cafe',
    'Bakery',
    'Grocery',
    'Supermarket',
    'Retail',
    'Clothing',
    'Automotive',
    'Pharmacy',
    'General',
  ];

  // ─── Core Features (Always Allowed for All Store Types) ──────
  static const Set<String> coreFeatureKeys = {
    'dashboard',
    'pos',
    'inventory',
    'reports',
    'sales',
    'settings',
    'biz_store',
    'admin',
    'languages',
    'settings.store',
    'settings.users',
    'settings.products',
    'settings.tax',
    'settings.payment',
    'settings.display',
    'settings.devices',
    'settings.language',
    'settings.announcements',
  };

  // ─── Peripheral Feature Definitions ──────────────────────────
  static const List<PeripheralFeatureMeta> peripheralFeatures = [
    PeripheralFeatureMeta(
      id: 'kitchen',
      configKey: 'enableKitchen',
      canonicalAddonKey: 'kds_management',
      label: 'Kitchen & KDS',
      description: 'Kitchen Display System, order prep routing, and station counters',
      icon: Icons.kitchen_rounded,
      category: 'operations',
      relatedKeys: [
        'kds',
        'kds_management',
        'settings.kds',
        'settings.store.counters',
        'kds_settings',
        'kitchen',
      ],
    ),
    PeripheralFeatureMeta(
      id: 'tables',
      configKey: 'enableTables',
      canonicalAddonKey: 'table_reservation',
      label: 'Tables & Dining',
      description: 'Dining areas, floor plans, table occupancy, and reservations',
      icon: Icons.table_restaurant_rounded,
      category: 'operations',
      relatedKeys: [
        'tables',
        'table_reservation',
        'settings.tables',
        'table_settings',
        'floors',
      ],
    ),
    PeripheralFeatureMeta(
      id: 'barcode',
      configKey: 'enableBarcode',
      canonicalAddonKey: 'barcode_scanner',
      label: 'Barcode Scanner',
      description: 'Hardware barcode scanner compatibility and rapid SKU barcode lookups',
      icon: Icons.qr_code_scanner_rounded,
      category: 'operations',
      relatedKeys: [
        'barcode',
        'barcode_scanner',
        'settings.barcode',
        'barcode_settings',
      ],
    ),
    PeripheralFeatureMeta(
      id: 'customers',
      configKey: 'enableCustomers',
      canonicalAddonKey: 'customer_management',
      label: 'Customer CRM & Khata',
      description: 'Customer credit ledger (Udhari), loyalty points, and profiles',
      icon: Icons.people_alt_rounded,
      category: 'management',
      relatedKeys: [
        'crm',
        'customers',
        'customer_management',
        'settings.customer',
        'customer_settings',
        'udhari',
      ],
    ),
    PeripheralFeatureMeta(
      id: 'employees',
      configKey: 'enableEmployees',
      canonicalAddonKey: 'employee_management',
      label: 'Staff & Attendance',
      description: 'Staff directory, role-based access, and clock-in attendance tracking',
      icon: Icons.badge_rounded,
      category: 'management',
      relatedKeys: [
        'employees',
        'employee_management',
        'settings.employees',
        'employee_settings',
        'staff',
      ],
    ),
    PeripheralFeatureMeta(
      id: 'suppliers',
      configKey: 'enableSuppliers',
      canonicalAddonKey: 'supplier_management',
      label: 'Suppliers & Purchase',
      description: 'Vendor directory, purchase order management, and payables',
      icon: Icons.local_shipping_rounded,
      category: 'management',
      relatedKeys: [
        'suppliers',
        'supplier_management',
        'settings.suppliers',
        'supplier_settings',
      ],
    ),
    PeripheralFeatureMeta(
      id: 'data_sync',
      configKey: 'enableDataSync',
      canonicalAddonKey: 'data_center',
      label: 'Data Center & Sync',
      description: 'Offline data synchronization, conflict management, and cloud backups',
      icon: Icons.cloud_sync_rounded,
      category: 'management',
      relatedKeys: [
        'data_center',
        'settings.datacenter',
        'sync_settings',
      ],
    ),
    PeripheralFeatureMeta(
      id: 'dietary',
      configKey: 'enableDietary',
      label: 'Dietary (Veg/Non-Veg)',
      description: 'Dietary classification indicators for food and beverage items',
      icon: Icons.eco_rounded,
      category: 'catalog',
      relatedKeys: [
        'dietary',
        'enableDietary',
      ],
    ),
    PeripheralFeatureMeta(
      id: 'packaging',
      configKey: 'enablePackaging',
      label: 'Packaging Types',
      description: 'Custom packaging charge rules and takeaway packing options',
      icon: Icons.takeout_dining_rounded,
      category: 'catalog',
      relatedKeys: [
        'packaging',
        'enablePackaging',
      ],
    ),
    PeripheralFeatureMeta(
      id: 'variants',
      configKey: 'enableVariants',
      label: 'Product Variants',
      description: 'Size, portion, color, and custom variant category matrices',
      icon: Icons.style_rounded,
      category: 'catalog',
      relatedKeys: [
        'variants',
        'enableVariants',
      ],
    ),
  ];

  /// Checks if a feature key is a core feature that must never be blocked by store type.
  static bool isCoreFeature(String key) {
    if (coreFeatureKeys.contains(key)) return true;
    if (key.startsWith('dashboard.') ||
        key.startsWith('card.') ||
        key.startsWith('feature.pos.') ||
        key.startsWith('reports.')) {
      return true;
    }
    return false;
  }

  /// Maps any incoming feature/addon key to its corresponding PeripheralFeatureMeta (if any).
  static PeripheralFeatureMeta? findPeripheralMeta(String key) {
    for (final meta in peripheralFeatures) {
      if (meta.id == key ||
          meta.configKey == key ||
          meta.canonicalAddonKey == key ||
          meta.relatedKeys.contains(key)) {
        return meta;
      }
    }
    return null;
  }

  /// Returns default configuration presets for standard store types.
  static Map<String, bool> getDefaultConfig(String storeType) {
    final lower = storeType.toLowerCase().trim();

    if (lower.contains('restaurant') ||
        lower.contains('cafe') ||
        lower.contains('food') ||
        lower.contains('bakery') ||
        lower.contains('bar') ||
        lower.contains('dining') ||
        lower.contains('kitchen')) {
      return {
        'enableKitchen': true,
        'enableTables': true,
        'enableCustomers': true,
        'enableEmployees': true,
        'enableSuppliers': true,
        'enableDietary': true,
        'enablePackaging': true,
        'enableVariants': true,
        'enableBarcode': false,
        'enableDataSync': false,
        'kds_management': true,
        'table_reservation': true,
        'customer_management': true,
        'employee_management': true,
        'supplier_management': true,
        'barcode_scanner': false,
        'data_center': false,
      };
    }

    if (lower.contains('grocery') ||
        lower.contains('supermarket') ||
        lower.contains('mart')) {
      return {
        'enableKitchen': false,
        'enableTables': false,
        'enableCustomers': true,
        'enableEmployees': true,
        'enableSuppliers': true,
        'enableDietary': false,
        'enablePackaging': false,
        'enableVariants': true,
        'enableBarcode': true,
        'enableDataSync': true,
        'kds_management': false,
        'table_reservation': false,
        'customer_management': true,
        'employee_management': true,
        'supplier_management': true,
        'barcode_scanner': true,
        'data_center': true,
      };
    }

    // Default for Retail, Clothing, Automotive, Hardware, Pharmacy, etc.
    return {
      'enableKitchen': false,
      'enableTables': false,
      'enableCustomers': true,
      'enableEmployees': true,
      'enableSuppliers': true,
      'enableDietary': false,
      'enablePackaging': false,
      'enableVariants': true,
      'enableBarcode': true,
      'enableDataSync': false,
      'kds_management': false,
      'table_reservation': false,
      'customer_management': true,
      'employee_management': true,
      'supplier_management': true,
      'barcode_scanner': true,
      'data_center': false,
    };
  }

  /// Sanitizes a raw config map to ensure both semantic flags (`enable*`)
  /// and canonical keys (`kds_management`, etc.) are synchronized.
  static Map<String, dynamic> sanitizeConfig(Map<String, dynamic>? raw) {
    final Map<String, dynamic> clean = {};
    if (raw == null) return clean;

    for (final meta in peripheralFeatures) {
      bool val = false;
      if (raw.containsKey(meta.configKey)) {
        val = raw[meta.configKey] == true;
      } else if (meta.canonicalAddonKey != null &&
          raw.containsKey(meta.canonicalAddonKey)) {
        val = raw[meta.canonicalAddonKey] == true;
      }
      clean[meta.configKey] = val;
      if (meta.canonicalAddonKey != null) {
        clean[meta.canonicalAddonKey!] = val;
      }
    }
    return clean;
  }

  /// Determines whether a feature or addon key is allowed for a given store type.
  ///
  /// - Core features always return `true`.
  /// - If [storeType] is null or empty, returns `true` (standard entitlement rules apply).
  /// - Looks up [storeType] in [storeTypeConfigs]. If unconfigured, falls back to default preset.
  /// - Returns `true` if the corresponding peripheral feature flag is enabled, otherwise `false`.
  static bool isFeatureAllowed(
    String? storeType,
    String key, {
    Map<String, dynamic>? storeTypeConfigs,
  }) {
    // 1. Core features are never restricted by store type
    if (isCoreFeature(key)) {
      return true;
    }

    if (storeType == null || storeType.trim().isEmpty) {
      return true;
    }

    // 2. Identify the peripheral feature
    final meta = findPeripheralMeta(key);
    if (meta == null) {
      // Unmapped or custom key: do not block unless explicitly configured in store type
      if (storeTypeConfigs != null && storeTypeConfigs.containsKey(storeType)) {
        final cfg = storeTypeConfigs[storeType];
        if (cfg is Map && cfg.containsKey(key)) {
          return cfg[key] == true;
        }
      }
      return true;
    }

    // 3. Resolve active config
    Map<String, dynamic>? config;
    if (storeTypeConfigs != null && storeTypeConfigs.containsKey(storeType)) {
      final raw = storeTypeConfigs[storeType];
      if (raw is Map) {
        config = Map<String, dynamic>.from(raw);
      }
    }

    // Fall back to default presets if type has no explicit config saved
    config ??= getDefaultConfig(storeType);

    // 4. Check semantic config key or canonical addon key
    if (config.containsKey(meta.configKey)) {
      return config[meta.configKey] == true;
    }
    if (meta.canonicalAddonKey != null &&
        config.containsKey(meta.canonicalAddonKey)) {
      return config[meta.canonicalAddonKey] == true;
    }

    return false;
  }

  /// Returns list of all peripheral features enabled for a given store type.
  static List<PeripheralFeatureMeta> getAllowedFeatures(
    String storeType, {
    Map<String, dynamic>? storeTypeConfigs,
  }) {
    return peripheralFeatures
        .where((meta) => isFeatureAllowed(
              storeType,
              meta.configKey,
              storeTypeConfigs: storeTypeConfigs,
            ))
        .toList();
  }
}
