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
      final dashboard = legacy_provider.Provider.of<legacy.DashboardProvider>(context, listen: false);
      if (dashboard.activeStoreId != null) {
        ref.read(storeNotifierProvider.notifier).setActiveStoreId(dashboard.activeStoreId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionsProvider);

    // Define Menu Items with Role Visibility
    final List<Map<String, dynamic>> allMenuItems = [
      {
        'icon': Icons.store,
        'label': AppLocalizations.t(context, 'store'),
        'widgetBuilder': () => const StoreSettingsSection(isSubView: true),
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
    ];

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
            contentPadding: EdgeInsets.zero,
            selected: isSelected,
            selectedTileColor: color.withValues(alpha: 0.1),
            leading: AppIconography.iconContainer(
              icon: item['icon'] as IconData,
              color: isRestricted ? AppColors.adaptiveSecondary(context) : color,
              size: AppIconography.lg,
              containerSize: AppIconography.containerLg,
              borderRadius: AppRadius.md,
            ),
            title: Text(item['label'],
                style: AppTypography.bodyLarge
                    .copyWith(fontWeight: FontWeight.bold)),
            trailing: isDesktop ? null : const Icon(Icons.chevron_right, size: AppIconography.md),
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



