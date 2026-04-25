// ignore_for_file: unused_local_variable
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import 'settings/devices_settings_section.dart';
// import 'admin/manage_roles_screen.dart';
import '../widgets/feature_guard.dart'; // Import Upgrade Dialog // Moved to Admin
import '../l10n/app_localizations.dart'; // LOCALIZATION

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
        'color': Colors.blue,
        'roles': ['Super Admin', 'Franchise Owner', 'Store Owner', 'Admin'],
        'key': 'settings.store'
      },
      {
        'icon': Icons.person, 
        'label': AppLocalizations.t(context, 'user'), 
        'widgetBuilder': () => const UserSettingsSection(), 
        'color': Colors.orange,
        'roles': null, // All
        'key': 'settings.users'
      },
      {
        'icon': Icons.inventory_2, 
        'label': AppLocalizations.t(context, 'products'), 
        'widgetBuilder': () => const ProductSettingsSection(), 
        'color': Colors.green,
        'roles': ['Super Admin', 'Franchise Owner', 'Store Owner', 'Admin', 'Manager'],
        'key': 'settings.products'
      },
      {
        'icon': Icons.percent, 
        'label': AppLocalizations.t(context, 'tax'), 
        'widgetBuilder': () => const TaxSettingsSection(), 
        'color': Colors.red,
        'roles': ['Super Admin', 'Franchise Owner', 'Store Owner'],
        'key': 'settings.tax'
      },



      {
        'icon': Icons.payment,
        'label': 'Payment', // TODO: Add to localization
        'widgetBuilder': () => const PaymentSettingsSection(),
        'color': Colors.indigo,
        'roles': ['Super Admin', 'Franchise Owner', 'Store Owner'],
        'key': 'settings.payment'
      },
      {
        'icon': Icons.palette, 
        'label': AppLocalizations.t(context, 'display_settings'), 
        'widgetBuilder': () => const DisplaySettingsSection(), 
        'color': Colors.teal,
        'roles': null, // All
        'key': 'settings.display'
      },

      {
        'icon': Icons.devices_other, 
        'label': AppLocalizations.t(context, 'devices'), 
        'widgetBuilder': () => const DevicesSettingsSection(), 
        'color': Colors.grey,
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


    

    // Explicitly non-const Scaffold
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), elevation: 1), // No const
      body: ListView.separated( // Removed Responsive
           padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
           itemCount: menuItems.length,
           separatorBuilder: (_, __) => const SizedBox(height: 10),
           itemBuilder: (context, index) {
             final item = menuItems[index];
             final color = item['color'] as Color;
             final isRestricted = item.containsKey('key') && !provider.isFeatureEnabled(item['key'] as String);

             return Card( // No const
               elevation: 2,
               child: ListTile(
                 key: Key(item['key'] as String),
                 leading: Icon(item['icon'] as IconData, color: isRestricted ? Colors.grey : color), // No const
                 title: Text(item['label'], style: const TextStyle(fontWeight: FontWeight.bold)), // No const
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
