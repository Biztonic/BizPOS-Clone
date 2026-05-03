import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
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
 


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final store = provider.activeStore;

    // Store Check Removed - We allow viewing settings but warn if no store active
    // The previous blocking code is removed.


    // Define Menu Items with Role Visibility
    final role = provider.activeRole;
    
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
        'roles': ['Super Admin', 'Franchise Owner', 'Store Owner', 'Admin', 'Manager'],
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

    // Filter Items
    final List<Map<String, dynamic>> menuItems = allMenuItems.where((item) {
       // 1. Role Check - REMOVED to show all items (locked if disabled)
       // final roles = item['roles'] as List<String>?;
       // if (roles != null && roles.isNotEmpty) {
       //    if (!roles.contains(role)) return false;
       // }
       
       // 2. Plan/Feature Check - NO LONGER HIDE
       // We allow them to show, but we will lock them in the UI
       

       return true;
    }).toList();
    
    // Safety check for selected index
    if(_selectedIndex >= menuItems.length) {
       _selectedIndex = 0;
    }


    

    return PosScaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t(context, 'settings')),
      ),
      mainContent: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: menuItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final item = menuItems[index];
          final color = item['color'] as Color;
          final isRestricted = item.containsKey('key') && !provider.isFeatureEnabled(item['key'] as String);

          return AppCard(
            child: ListTile(
              key: Key(item['key'] as String),
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: (isRestricted ? AppColors.secondary : color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item['icon'] as IconData, color: isRestricted ? AppColors.secondary : color),
              ),
              title: Text(item['label'], style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                final widget = item.containsKey('key') 
                    ? FeatureGuard(featureKey: item['key'] as String, child: (item['widgetBuilder'] as Widget Function())())
                    : (item['widgetBuilder'] as Widget Function())();

                Navigator.push(context, MaterialPageRoute(
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
