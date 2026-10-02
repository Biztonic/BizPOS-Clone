import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as legacy_provider;
import '../providers/dashboard_provider.dart' as legacy;
import '../features/store/providers/store_notifier.dart';
import '../features/auth/providers/permissions_provider.dart';
import 'settings/devices_settings_section.dart';
import 'language_screen.dart';
import '../widgets/feature_guard.dart';
import '../l10n/app_localizations.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/components/atoms/app_card.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';
import '../core/design/tokens/app_colors.dart';
import '../core/design/tokens/app_radius.dart';
import '../core/design/tokens/app_iconography.dart';

// Sections
import 'settings/store_settings_section.dart';
import 'settings/tax_settings_section.dart';
import 'settings/product_settings_section.dart';
import 'settings/user_settings_section.dart';
import 'settings/payment_settings_section.dart';
import 'settings/display_settings_section.dart';
import 'settings/audio_settings_section.dart';

// Addon Settings Sections
import 'settings/customer_settings_section.dart';
import 'settings/kds_settings_screen.dart';
import 'settings/barcode_scanner_settings_screen.dart';
import 'settings/data_sync_control_screen.dart';
import 'settings/table_settings_section.dart';
import 'settings/franchise_settings_section.dart';
import 'settings/employee_settings_section.dart';
import 'settings/supplier_settings_section.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _syncStoreId();
  }

  void _syncStoreId() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dashboard = legacy_provider.Provider.of<legacy.DashboardProvider>(
          context,
          listen: false);
      if (dashboard.activeStoreId != null) {
        ref
            .read(storeNotifierProvider.notifier)
            .setActiveStoreId(
              dashboard.activeStoreId,
              initialStore: dashboard.activeStore,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionsProvider);
    final dashboard =
        legacy_provider.Provider.of<legacy.DashboardProvider>(context);

    // 1. Core Store Settings (Always present)
    final List<Map<String, dynamic>> coreMenuItems = [
      {
        'icon': Icons.store,
        'label': AppLocalizations.t(context, 'store'),
        'widgetBuilder': () => StoreSettingsSection(
              isSubView: true,
              store: dashboard.activeStore,
            ),
        'color': AppColors.adaptivePrimary(context),
        'roles': ['Super Admin', 'Franchise Owner', 'Store Owner', 'Admin'],
        'key': 'settings.store'
      },
      {
        'icon': Icons.person,
        'label': AppLocalizations.t(context, 'user'),
        'widgetBuilder': () => const UserSettingsSection(isSubView: true),
        'color': AppColors.adaptiveWarning(context),
        'roles': null, // All
        'key': 'settings.users'
      },
      {
        'icon': Icons.inventory_2,
        'label': AppLocalizations.t(context, 'products'),
        'widgetBuilder': () => const ProductSettingsSection(isSubView: true),
        'color': AppColors.adaptiveSuccess(context),
        'roles': [
          'Super Admin',
          'Franchise Owner',
          'Store Owner',
          'Admin',
          'Manager'
        ],
        'key': 'settings.products'
      },
      {
        'icon': Icons.percent,
        'label': AppLocalizations.t(context, 'tax'),
        'widgetBuilder': () => const TaxSettingsSection(isSubView: true),
        'color': AppColors.adaptiveError(context),
        'roles': ['Super Admin', 'Franchise Owner', 'Store Owner'],
        'key': 'settings.tax'
      },
      {
        'icon': Icons.payment,
        'label': AppLocalizations.t(context, 'Payment'),
        'widgetBuilder': () => const PaymentSettingsSection(isSubView: true),
        'color': AppColors.adaptivePrimary(context),
        'roles': ['Super Admin', 'Franchise Owner', 'Store Owner'],
        'key': 'settings.payment'
      },
      {
        'icon': Icons.palette,
        'label': AppLocalizations.t(context, 'display_settings'),
        'widgetBuilder': () => const DisplaySettingsSection(isSubView: true),
        'color': AppColors.adaptivePrimary(context),
        'roles': null, // All
        'key': 'settings.display'
      },
      {
        'icon': Icons.devices_other,
        'label': AppLocalizations.t(context, 'devices'),
        'widgetBuilder': () => const DevicesSettingsSection(isSubView: true),
        'color': AppColors.adaptiveSecondary(context),
        'roles': null, // All
        'key': 'settings.devices'
      },
      {
        'icon': Icons.translate,
        'label': AppLocalizations.t(context, 'language_settings'),
        'widgetBuilder': () => const LanguageScreen(isSubView: true),
        'color': AppColors.adaptivePrimary(context),
        'roles': null, // All
        'key': 'settings.language'
      },
      {
        'icon': Icons.volume_up,
        'label': 'Audio Announcements',
        'widgetBuilder': () => const AudioSettingsSection(isSubView: true),
        'color': AppColors.adaptiveSuccess(context),
        'roles': null, // All
        'key': 'settings.announcements'
      },
    ];

    // 2. Purchased Add-on Settings (Appears ONLY if addon is active/purchased)
    final List<Map<String, dynamic>> addonMenuItems = [];

    // Customer & Khata Add-on
    if (dashboard.hasAddon('customer_management')) {
      addonMenuItems.add({
        'icon': Icons.people_alt_rounded,
        'label': 'Customer & Khata',
        'widgetBuilder': () => const CustomerSettingsSection(isSubView: true),
        'color': AppColors.adaptivePrimary(context),
        'roles': null,
        'key': 'settings.customer',
        'isAddon': true,
      });
    }

    // Kitchen Display System (KDS) Add-on
    if (dashboard.hasAddon('kds_management')) {
      addonMenuItems.add({
        'icon': Icons.kitchen_rounded,
        'label': 'Kitchen Display (KDS)',
        'widgetBuilder': () => const KdsSettingsScreen(isSubView: true),
        'color': AppColors.adaptiveWarning(context),
        'roles': null,
        'key': 'settings.kds',
        'isAddon': true,
      });
    }

    // Table & Dining Area Add-on
    if (dashboard.hasAddon('table_reservation')) {
      addonMenuItems.add({
        'icon': Icons.table_restaurant_rounded,
        'label': 'Table & Dining',
        'widgetBuilder': () => const TableSettingsSection(isSubView: true),
        'color': AppColors.adaptiveSecondary(context),
        'roles': null,
        'key': 'settings.tables',
        'isAddon': true,
      });
    }

    // Barcode Scanner Hardware Add-on
    if (dashboard.hasAddon('barcode_scanner')) {
      addonMenuItems.add({
        'icon': Icons.qr_code_scanner_rounded,
        'label': 'Barcode Scanner',
        'widgetBuilder': () =>
            const BarcodeScannerSettingsScreen(isSubView: true),
        'color': AppColors.adaptiveSuccess(context),
        'roles': null,
        'key': 'settings.barcode',
        'isAddon': true,
      });
    }

    // Data Center & Sync Control Add-on
    if (dashboard.hasAddon('data_center')) {
      addonMenuItems.add({
        'icon': Icons.cloud_sync_rounded,
        'label': 'Data Center & Sync',
        'widgetBuilder': () => const DataSyncControlScreen(isSubView: true),
        'color': AppColors.adaptivePrimary(context),
        'roles': null,
        'key': 'settings.datacenter',
        'isAddon': true,
      });
    }

    // Franchise & Multi-Store Management Add-on
    if (dashboard.hasAddon('franchise_management') ||
        dashboard.hasFranchiseAddon) {
      addonMenuItems.add({
        'icon': Icons.business_rounded,
        'label': 'Franchise & Multi-Store',
        'widgetBuilder': () => const FranchiseSettingsSection(isSubView: true),
        'color': AppColors.adaptivePrimary(context),
        'roles': null,
        'key': 'settings.franchise',
        'isAddon': true,
      });
    }

    // Staff & Attendance Add-on
    if (dashboard.hasAddon('employee_management')) {
      addonMenuItems.add({
        'icon': Icons.badge_rounded,
        'label': 'Staff & Attendance',
        'widgetBuilder': () => const EmployeeSettingsSection(isSubView: true),
        'color': AppColors.adaptiveWarning(context),
        'roles': null,
        'key': 'settings.employees',
        'isAddon': true,
      });
    }

    // Supplier & Purchase Add-on
    if (dashboard.hasAddon('supplier_management')) {
      addonMenuItems.add({
        'icon': Icons.local_shipping_rounded,
        'label': 'Supplier & Purchase',
        'widgetBuilder': () => const SupplierSettingsSection(isSubView: true),
        'color': AppColors.adaptiveSuccess(context),
        'roles': null,
        'key': 'settings.suppliers',
        'isAddon': true,
      });
    }

    final List<Map<String, dynamic>> allMenuItems = [
      ...coreMenuItems,
      ...addonMenuItems,
    ];

    if (_selectedIndex >= allMenuItems.length) {
      _selectedIndex = 0;
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;

    final Widget menuList = ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: allMenuItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final item = allMenuItems[index];
        final color = item['color'] as Color;
        final isRestricted = item.containsKey('key') &&
            !permissions.isFeatureEnabled(item['key'] as String);
        final isSelected = isDesktop && _selectedIndex == index;

        return AppCard(
          child: ListTile(
            key: Key(item['key'] as String),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            selected: isSelected,
            selectedTileColor: color.withValues(alpha: 0.1),
            leading: AppIconography.iconContainer(
              icon: item['icon'] as IconData,
              color:
                  isRestricted ? AppColors.adaptiveSecondary(context) : color,
              size: AppIconography.lg,
              containerSize: AppIconography.containerLg,
              borderRadius: AppRadius.md,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(item['label'],
                      style: AppTypography.bodyLarge
                          .copyWith(fontWeight: FontWeight.bold)),
                ),
                if (item['isAddon'] == true) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'ADD-ON',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: isDesktop
                ? null
                : const Icon(Icons.chevron_right, size: AppIconography.md),
            onTap: () {
              if (isDesktop) {
                setState(() => _selectedIndex = index);
              } else {
                final widget = item.containsKey('key')
                    ? FeatureGuard(
                        featureKey: item['key'] as String,
                        child: (item['widgetBuilder'] as Widget Function())())
                    : (item['widgetBuilder'] as Widget Function())();

                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PosScaffold(
                        title: item['label'],
                        showSidebar: false,
                        mainContent: widget,
                      ),
                    ));
              }
            },
          ),
        );
      },
    );

    Widget getSelectedWidget() {
      final item = allMenuItems[_selectedIndex];
      final widget = item.containsKey('key')
          ? FeatureGuard(
              featureKey: item['key'] as String,
              child: (item['widgetBuilder'] as Widget Function())())
          : (item['widgetBuilder'] as Widget Function())();
      return widget;
    }

    return PosScaffold(
      title: AppLocalizations.t(context, 'settings'),
      mainContent: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 350, child: menuList),
                const VerticalDivider(width: 1),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: KeyedSubtree(
                      key: ValueKey(_selectedIndex),
                      child: getSelectedWidget(),
                    ),
                  ),
                ),
              ],
            )
          : menuList,
    );
  }
}
