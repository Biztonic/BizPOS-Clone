import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/providers/permissions_provider.dart';
import '../features/auth/providers/profile_notifier.dart';
import '../features/store/providers/store_notifier.dart';
import 'settings/devices_settings_section.dart';
import '../widgets/feature_guard.dart';
import '../l10n/app_localizations.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/components/atoms/app_card.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';
import '../core/design/tokens/app_colors.dart';

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
  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionsProvider);

    // Define Menu Items with Role Visibility
    final List<Map<String, dynamic>> allMenuItems = [
      {
        'icon': Icons.store,
        'label': AppLocalizations.t(context, 'store'),
        'widgetBuilder': () => const StoreSettingsSection(),
        'color': AppColors.primary,
        'roles': ['Super Admin', 'Franchise Owner', 'Store Owner', 'Admin'],
        'key': 'settings.store'
      },
      {
        'icon': Icons.person,
        'label': AppLocalizations.t(context, 'user'),
        'widgetBuilder': () => const UserSettingsSection(),
        'color': AppColors.warning,
        'roles': null, // All
        'key': 'settings.users'
      },
      {
        'icon': Icons.inventory_2,
        'label': AppLocalizations.t(context, 'products'),
        'widgetBuilder': () => const ProductSettingsSection(),
        'color': AppColors.success,
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
        'widgetBuilder': () => const TaxSettingsSection(),
        'color': AppColors.error,
        'roles': ['Super Admin', 'Franchise Owner', 'Store Owner'],
        'key': 'settings.tax'
      },
      {
        'icon': Icons.payment,
        'label': 'Payment', // TODO: Add to localization
        'widgetBuilder': () => const PaymentSettingsSection(),
        'color': AppColors.primary,
        'roles': ['Super Admin', 'Franchise Owner', 'Store Owner'],
        'key': 'settings.payment'
      },
      {
        'icon': Icons.palette,
        'label': AppLocalizations.t(context, 'display_settings'),
        'widgetBuilder': () => const DisplaySettingsSection(),
        'color': AppColors.primary,
        'roles': null, // All
        'key': 'settings.display'
      },
      {
        'icon': Icons.devices_other,
        'label': AppLocalizations.t(context, 'devices'),
        'widgetBuilder': () => const DevicesSettingsSection(),
        'color': AppColors.secondary,
        'roles': null, // All
        'key': 'settings.devices'
      },
    ];

    return PosScaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t(context, 'settings')),
      ),
      mainContent: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: allMenuItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final item = allMenuItems[index];
          final color = item['color'] as Color;
          final isRestricted = item.containsKey('key') &&
              !permissions.isFeatureEnabled(item['key'] as String);

          return AppCard(
            child: ListTile(
              key: Key(item['key'] as String),
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: (isRestricted ? AppColors.secondary : color)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item['icon'] as IconData,
                    color: isRestricted ? AppColors.secondary : color),
              ),
              title: Text(item['label'],
                  style: AppTypography.bodyLarge
                      .copyWith(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                final widget = item.containsKey('key')
                    ? FeatureGuard(
                        featureKey: item['key'] as String,
                        child: (item['widgetBuilder'] as Widget Function())())
                    : (item['widgetBuilder'] as Widget Function())();

                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => widget,
                    ));
              },
            ),
          );
        },
      ),
    );
  }
}
