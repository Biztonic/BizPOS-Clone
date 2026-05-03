import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/demo_target.dart';
import '../tokens/app_colors.dart';

class PosSidebar extends StatelessWidget {
  final bool isDrawer;

  const PosSidebar({
    super.key,
    this.isDrawer = false,
  });

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final role = dashboardProvider.activeRole;

    // 1. Generate Menu Items (Consolidated logic from DashboardScreen)
    final List<Map<String, dynamic>> allMenuItems = [
      {'icon': Icons.dashboard, 'label': AppLocalizations.t(context, 'dashboard'), 'route': '/dashboard', 'key': 'dashboard', 'color': AppColors.primary},
      {'icon': Icons.point_of_sale, 'label': AppLocalizations.t(context, 'pos'), 'route': '/pos', 'key': 'pos', 'color': AppColors.success}, 
      {'icon': Icons.inventory, 'label': AppLocalizations.t(context, 'inventory'), 'route': '/inventory', 'key': 'inventory', 'color': AppColors.warning},
      {'icon': Icons.shopping_cart, 'label': AppLocalizations.t(context, 'sales'), 'route': '/sales', 'key': 'reports', 'color': AppColors.primaryLight}, 
      {'icon': Icons.people, 'label': AppLocalizations.t(context, 'customers'), 'route': '/customers', 'key': 'customer_management', 'enabled': (role == 'Store Owner' || role == 'Admin' || dashboardProvider.userProfile?.role == 'Super Admin') && dashboardProvider.hasAddon('customer_management'), 'color': AppColors.primary},
      {'icon': Icons.store, 'label': AppLocalizations.t(context, 'franchises'), 'route': '/franchises', 'key': 'franchises', 'enabled': role == 'Franchise Owner' || dashboardProvider.hasAddon('franchise_management'), 'color': AppColors.primary},
      {'icon': Icons.badge, 'label': AppLocalizations.t(context, 'employees'), 'route': '/employees', 'key': 'employees', 'enabled': (role == 'Store Owner' || role == 'Admin' || dashboardProvider.userProfile?.role == 'Super Admin') && dashboardProvider.hasAddon('employee_management'), 'color': AppColors.error},
      {'icon': Icons.bar_chart, 'label': AppLocalizations.t(context, 'reports'), 'route': '/reports', 'key': 'reports', 'color': AppColors.error},
      {'icon': Icons.local_shipping, 'label': AppLocalizations.t(context, 'suppliers'), 'route': '/suppliers', 'key': 'inventory', 'enabled': (role == 'Store Owner' || role == 'Admin' || dashboardProvider.userProfile?.role == 'Super Admin') && dashboardProvider.hasAddon('supplier_management'), 'color': AppColors.textSecondary(context)},
      {'icon': Icons.tv, 'label': AppLocalizations.t(context, 'display'), 'route': '/display', 'key': 'kds_management', 'enabled': (role == 'Store Owner' || role == 'Admin' || dashboardProvider.userProfile?.role == 'Super Admin') && dashboardProvider.hasAddon('kds_management'), 'color': AppColors.primaryLight},
      {'icon': Icons.table_restaurant, 'label': AppLocalizations.t(context, 'tables'), 'route': '/tables', 'key': 'pos', 'enabled': (role == 'Store Owner' || role == 'Admin' || dashboardProvider.userProfile?.role == 'Super Admin') && dashboardProvider.hasAddon('table_reservation'), 'color': AppColors.primary},
      {'icon': Icons.sync_alt, 'label': AppLocalizations.t(context, 'data_center'), 'route': '/data-sync', 'key': 'data_center', 'enabled': (role == 'Store Owner' || role == 'Admin' || dashboardProvider.userProfile?.role == 'Super Admin') && dashboardProvider.hasAddon('data_center'), 'color': AppColors.success},
      {'icon': Icons.hub, 'label': 'Integrations', 'route': '/integrations', 'key': 'integration_hub', 'enabled': (role == 'Store Owner' || role == 'Admin' || dashboardProvider.userProfile?.role == 'Super Admin') && dashboardProvider.hasAddon('integration_hub'), 'color': AppColors.warning},
      {'icon': Icons.settings, 'label': AppLocalizations.t(context, 'setting'), 'route': '/settings', 'key': 'settings', 'color': AppColors.textSecondary(context)},
      {'icon': Icons.admin_panel_settings, 'label': AppLocalizations.t(context, 'admin'), 'route': '/admin', 'key': 'admin', 'enabled': dashboardProvider.userProfile?.role == 'Super Admin' && dashboardProvider.isDeveloperMode, 'color': AppColors.textPrimary(context)},
      {'icon': Icons.extension, 'label': 'BizStore', 'route': '/biz-store', 'key': 'biz_store', 'enabled': dashboardProvider.userProfile?.role != 'Super Admin', 'color': AppColors.primary},
      {'icon': Icons.translate, 'label': AppLocalizations.t(context, 'languages'), 'route': '/languages', 'key': 'admin', 'color': AppColors.primaryLight},
    ];

    final menuItems = allMenuItems.where((item) {
       if (item.containsKey('enabled') && item['enabled'] == false) return false;
       if (item.containsKey('key')) {
         final isEnabled = dashboardProvider.isFeatureEnabled(item['key'] as String);
         if (role != 'Store Owner' && role != 'Admin' && role != 'Super Admin' && !isEnabled) return false;
       }
       return true;
    }).toList();

    return Container(
      width: isDrawer ? null : 280,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: isDrawer ? null : Border(right: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      child: Column(
        children: [
          if (isDrawer)
            _buildDrawerHeader(context, dashboardProvider, authProvider)
          else
            _buildSidebarHeader(context, dashboardProvider),
          
          // Store Selector (if multiple stores)
          if ((role == 'Admin' || role == 'Franchise Owner' || role == 'Super Admin') && dashboardProvider.stores.length > 1)
            _buildStoreSelector(context, dashboardProvider, authProvider),

          Expanded(
            child: _buildMenuList(context, menuItems, dashboardProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context, DashboardProvider dashboardProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.storefront, color: Theme.of(context).primaryColor, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dashboardProvider.activeStore?.name ?? 'BizPOS', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                if (dashboardProvider.userProfile?.name != null)
                  Text(
                    dashboardProvider.userProfile!.name,
                    style: TextStyle(
                      fontSize: 12, 
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontWeight: FontWeight.w500
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                _buildStatusBadge(context, dashboardProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, DashboardProvider dashboardProvider, AuthProvider authProvider) {
    return UserAccountsDrawerHeader(
      accountName: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(dashboardProvider.userProfile?.name ?? authProvider.user?.displayName ?? 'User'),
          if (dashboardProvider.activeStore?.name != null)
            Text(
              dashboardProvider.activeStore!.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.white70),
            ),
        ],
      ),
      accountEmail: Text(dashboardProvider.userProfile?.email ?? authProvider.user?.email ?? ''),
      currentAccountPicture: CircleAvatar(
        backgroundColor: Colors.white24,
        backgroundImage: (dashboardProvider.userProfile?.photoBase64 != null && dashboardProvider.userProfile!.photoBase64!.isNotEmpty)
            ? MemoryImage(base64Decode(dashboardProvider.userProfile!.photoBase64!))
            : null,
        child: (dashboardProvider.userProfile?.photoBase64 == null || dashboardProvider.userProfile!.photoBase64!.isEmpty)
            ? const Icon(Icons.person, size: 40, color: Colors.white)
            : null,
      ),
      decoration: BoxDecoration(color: Theme.of(context).primaryColor),
    );
  }

  Widget _buildStatusBadge(BuildContext context, DashboardProvider dashboardProvider) {
    final isOnline = dashboardProvider.isOnline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isOnline ? AppColors.success.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isOnline ? AppColors.success.withValues(alpha: 0.5) : AppColors.warning.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isOnline ? Icons.wifi : Icons.wifi_off, size: 10, color: isOnline ? AppColors.success : AppColors.warning),
          const SizedBox(width: 4),
          Text(
            isOnline ? "Online" : "Offline Mode",
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isOnline ? AppColors.success : AppColors.warning),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSelector(BuildContext context, DashboardProvider dashboardProvider, AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.textSecondary(context).withValues(alpha: 0.2) : AppColors.textSecondary(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: dashboardProvider.activeStoreId,
          hint: const Text("Select Store"),
          items: dashboardProvider.stores.map((store) {
             return DropdownMenuItem(value: store.id, child: Text(store.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)));
          }).toList(),
          onChanged: (val) {
             if (val != null) {
               dashboardProvider.setActiveStoreId(val);
               dashboardProvider.linkUserToStore(authProvider.user!.uid, val);
               if (isDrawer) Navigator.pop(context); 
             }
          },
        ),
      ),
    );
  }

  Widget _buildMenuList(BuildContext context, List<Map<String, dynamic>> menuItems, DashboardProvider dashboardProvider) {
    return ListView.builder(
      itemCount: menuItems.length,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      itemBuilder: (context, index) {
        final item = menuItems[index];
        final currentUri = GoRouterState.of(context).uri.toString();
        // Exact match or sub-route match (e.g. /customers/detail matches /customers)
        final isSelected = currentUri == item['route'] || (item['route'] != '/dashboard' && currentUri.startsWith(item['route']));
        final color = item['color'] as Color? ?? AppColors.textSecondary(context);
        final isRestricted = item.containsKey('key') && !dashboardProvider.isFeatureEnabled(item['key'] as String);
        
        return DemoTarget(
          step: item['key'] == 'pos' ? 'nav_pos' : (item['key'] == 'reports' ? 'nav_reports' : 'none'),
          instruction: item['key'] == 'pos' ? "Click POS to start selling" : "Check Reports here",
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              key: Key('menu_${item['key']}'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item['icon'], color: isSelected ? Colors.white : color, size: 20),
              ),
              title: Text(
                item['label'],
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isRestricted ? AppColors.textSecondary(context) : (isSelected ? color : (Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.textPrimary(context))),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              trailing: isRestricted ? const Icon(Icons.lock, size: 14, color: AppColors.warning) : null,
              selected: isSelected,
              selectedTileColor: color.withValues(alpha: 0.05),
              onTap: () {
                if (item['key'] == 'pos') dashboardProvider.nextDemoStep();
                context.go(item['route']);
                if (isDrawer) Navigator.pop(context);
              },
            ),
          ),
        );
      },
    );
  }
}
