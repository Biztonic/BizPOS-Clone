// ignore_for_file: unused_local_variable
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:biztonic_pos/widgets/demo_target.dart'; // Import
// Import Upgrade Dialog
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import 'package:biztonic_pos/providers/auth_provider.dart';
import '../l10n/app_localizations.dart'; // LOCALIZATION

import '../services/update_service.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'settings/subscription_reminder_dialog.dart';

// Responsive Utility

class DashboardScreen extends StatefulWidget {
  final Widget child;

  const DashboardScreen({super.key, required this.child});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Enforce Immersive Mode on Dashboard load
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Check for In-App Updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
       UpdateService.checkUpdate(context);
       _checkSubscriptionReminder();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
       // Automatically logout when the app is completely detached (swiped away/killed)
       final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
       final authProvider = Provider.of<AuthProvider>(context, listen: false);
       dashboardProvider.clearSession();
       authProvider.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Use Selector to only rebuild when shell-relevant properties change
    return Selector<DashboardProvider, _DashboardShellData>(
      selector: (_, p) => _DashboardShellData(
        storeName: p.activeStore?.name,
        activeStoreId: p.activeStoreId,
        role: p.activeRole,
        isOnline: p.isOnline,
        isDarkMode: p.isDarkMode,
        isDeveloperMode: p.isDeveloperMode,
        userProfile: p.userProfile,
        storesCount: p.stores.length,
        isLoading: p.isLoading,
        pendingRecoveriesCount: p.pendingRecoveries.length,
      ),
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, shellData, child) {
        final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
        return _buildShellContent(context, authProvider, dashboardProvider, shellData);
      },
    );
  }

  Widget _buildShellContent(BuildContext context, AuthProvider authProvider, DashboardProvider dashboardProvider, _DashboardShellData shellData) {
    final role = dashboardProvider.activeRole;

    // Define All Menu Items
    final List<Map<String, dynamic>> allMenuItems = [
      {'icon': Icons.dashboard, 'label': AppLocalizations.t(context, 'dashboard'), 'route': '/dashboard', 'key': 'dashboard', 'color': Colors.blue},
      {'icon': Icons.point_of_sale, 'label': AppLocalizations.t(context, 'pos'), 'route': '/pos', 'key': 'pos', 'color': Colors.green}, 
      {'icon': Icons.inventory, 'label': AppLocalizations.t(context, 'inventory'), 'route': '/inventory', 'key': 'inventory', 'color': Colors.orange},
      {'icon': Icons.shopping_cart, 'label': AppLocalizations.t(context, 'sales'), 'route': '/sales', 'key': 'reports', 'color': Colors.purple}, 
      {'icon': Icons.people, 'label': AppLocalizations.t(context, 'customers'), 'route': '/customers', 'key': 'customer_management', 'enabled': (role == 'Store Owner' || role == 'Admin' || dashboardProvider.userProfile?.role == 'Super Admin') && dashboardProvider.hasAddon('customer_management'), 'color': Colors.teal},
      
      // SUPER ADMIN / ADMIN TOOLS
      {'icon': Icons.store, 'label': AppLocalizations.t(context, 'franchises'), 'route': '/franchises', 'key': 'franchises', 'enabled': role == 'Franchise Owner' || dashboardProvider.hasAddon('franchise_management'), 'color': Colors.brown},

      
      {'icon': Icons.badge, 'label': AppLocalizations.t(context, 'employees'), 'route': '/employees', 'key': 'employees', 'enabled': (role == 'Store Owner' || role == 'Admin' || dashboardProvider.userProfile?.role == 'Super Admin') && dashboardProvider.hasAddon('employee_management'), 'color': Colors.pink},
      {'icon': Icons.bar_chart, 'label': AppLocalizations.t(context, 'reports'), 'route': '/reports', 'key': 'reports', 'color': Colors.red},
      {'icon': Icons.local_shipping, 'label': AppLocalizations.t(context, 'suppliers'), 'route': '/suppliers', 'key': 'inventory', 'enabled': (role == 'Store Owner' || role == 'Admin' || dashboardProvider.userProfile?.role == 'Super Admin') && dashboardProvider.hasAddon('supplier_management'), 'color': Colors.blueGrey},

      {'icon': Icons.tv, 'label': AppLocalizations.t(context, 'display'), 'route': '/display', 'key': 'kds_management', 'enabled': (role == 'Store Owner' || role == 'Admin' || dashboardProvider.userProfile?.role == 'Super Admin') && dashboardProvider.hasAddon('kds_management'), 'color': Colors.lightBlue},
      {'icon': Icons.table_restaurant, 'label': AppLocalizations.t(context, 'tables'), 'route': '/tables', 'key': 'pos', 'enabled': (role == 'Store Owner' || role == 'Admin' || dashboardProvider.userProfile?.role == 'Super Admin') && dashboardProvider.hasAddon('table_reservation'), 'color': Colors.deepPurple},
      
      {'icon': Icons.sync_alt, 'label': AppLocalizations.t(context, 'data_center'), 'route': '/data-sync', 'key': 'data_center', 'enabled': (role == 'Store Owner' || role == 'Admin' || dashboardProvider.userProfile?.role == 'Super Admin') && dashboardProvider.hasAddon('data_center'), 'color': Colors.lightGreen},
      {'icon': Icons.hub, 'label': 'Integrations', 'route': '/integrations', 'key': 'integration_hub', 'enabled': (role == 'Store Owner' || role == 'Admin' || dashboardProvider.userProfile?.role == 'Super Admin') && dashboardProvider.hasAddon('integration_hub'), 'color': Colors.orangeAccent},
      {'icon': Icons.settings, 'label': AppLocalizations.t(context, 'setting'), 'route': '/settings', 'key': 'settings', 'color': Colors.blueGrey},
      {'icon': Icons.admin_panel_settings, 'label': AppLocalizations.t(context, 'admin'), 'route': '/admin', 'key': 'admin', 'enabled': dashboardProvider.userProfile?.role == 'Super Admin' && dashboardProvider.isDeveloperMode, 'color': Colors.black},
      {'icon': Icons.extension, 'label': 'BizStore', 'route': '/biz-store', 'key': 'biz_store', 'enabled': dashboardProvider.userProfile?.role != 'Super Admin', 'color': Colors.indigo},
      {'icon': Icons.translate, 'label': AppLocalizations.t(context, 'languages'), 'route': '/languages', 'key': 'admin', 'color': Colors.indigoAccent},
    ];

    // Filter enabled items
    final menuItems = allMenuItems.where((item) {
       // 1. Hard-hide logic (Roles/Addons)
       if (item.containsKey('enabled')) {
          if (item['enabled'] == false) return false;
       }

       // 2. Permission-based hide logic (restricted for non-owners)
       if (item.containsKey('key')) {
         final isEnabled = dashboardProvider.isFeatureEnabled(item['key'] as String);
         // If NOT Store Owner/Admin/Super Admin and feature is disabled, HIDE IT.
         if (dashboardProvider.activeRole != 'Store Owner' && dashboardProvider.activeRole != 'Admin' && dashboardProvider.activeRole != 'Super Admin') {
            // For Employees, we hide strictly if not enabled
            if (!isEnabled) return false;
         }
       }
       return true;
    }).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        // As requested: Automatically logout from current user on exit/back press
        final isEmployee = dashboardProvider.activeRole != 'Store Owner' && dashboardProvider.activeRole != 'Admin';
        dashboardProvider.clearSession();
        authProvider.signOut();

        if (Theme.of(context).platform == TargetPlatform.android) {
           // Provide a brief moment for signout to register before killing app
           Future.delayed(const Duration(milliseconds: 200), () {
              SystemNavigator.pop();
           });
        } else {
           SystemNavigator.pop();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Use standard breakpoint from Responsive class logic
          // We use 1024 (isDesktop) for permanent sidebar
          final isDesktop = constraints.maxWidth >= 1024;

          if (isDesktop) {
            // DESKTOP LAYOUT (Permanent Sidebar)
            return Scaffold(
              body: Row(
                children: [
                  // SIDEBAR
                  Container(
                    width: 280,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border(right: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                    ),
                    child: Column(
                      children: [
                        // Sidebar Header (Logo/User) - Simplified 
                        Container(
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
                                    // Offline Status Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: dashboardProvider.isOnline ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: dashboardProvider.isOnline ? Colors.green.withValues(alpha: 0.5) : Colors.orange.withValues(alpha: 0.5), width: 0.5),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            dashboardProvider.isOnline ? Icons.wifi : Icons.wifi_off,
                                            size: 10,
                                            color: dashboardProvider.isOnline ? Colors.green : Colors.orange,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            dashboardProvider.isOnline ? "Online" : "Offline Mode",
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: dashboardProvider.isOnline ? Colors.green : Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Reuse existing drawer content logic but adapted for sidebar (remove user header if desired, or keep)
                        // We'll reuse _buildDrawerContent but it has a specific header. Let's make a _buildSidebarMenu
                        Expanded(
                          child: _buildSidebarMenu(context, menuItems, authProvider, dashboardProvider),
                        ),
                      ],
                    ),
                  ),
                  
                  // MAIN CONTENT
                  Expanded(
                    child: Scaffold(
                      appBar: AppBar(
                        // Minimal Appbar for Desktop (mostly for Actions)
                        // title: Text(dashboardProvider.activeStore?.name ?? 'BizPOS'), // Already in sidebar
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
                        actions: [
                          // Developer Mode Toggle (Super Admin Only)
                          if (dashboardProvider.userProfile?.role == 'Super Admin')
                             InkWell(
                               onTap: () => dashboardProvider.toggleDeveloperMode(),
                               borderRadius: BorderRadius.circular(20),
                               child: Container(
                                 margin: const EdgeInsets.symmetric(horizontal: 8), // Spacing
                                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                 decoration: BoxDecoration(
                                   color: dashboardProvider.isDeveloperMode ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                   borderRadius: BorderRadius.circular(20),
                                   border: Border.all(color: dashboardProvider.isDeveloperMode ? Colors.red : Colors.green),
                                 ),
                                 child: Text(
                                   dashboardProvider.isDeveloperMode ? AppLocalizations.t(context, 'developer_mode') : AppLocalizations.t(context, 'normal_mode'),
                                   style: TextStyle(
                                     color: dashboardProvider.isDeveloperMode ? Colors.red : Colors.green, 
                                     fontWeight: FontWeight.bold, 
                                     fontSize: 11,
                                     letterSpacing: 0.5
                                   ),
                                 ),
                               ),
                             ),


                          const SizedBox(width: 16),
                          IconButton(
                            icon: Icon(dashboardProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
                            onPressed: () => dashboardProvider.toggleTheme(),
                            tooltip: dashboardProvider.isDarkMode ? 'Light Mode' : 'Dark Mode',
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.logout),
                            onPressed: () {
                               final isEmployee = dashboardProvider.activeRole != 'Store Owner' && dashboardProvider.activeRole != 'Admin';
                               dashboardProvider.clearSession();
                               authProvider.signOut();
                               if (isEmployee) {
                                  context.go('/employee-login');
                               }
                            },
                            tooltip: 'Logout',
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                      body: Column(
                        children: [
                          if (shellData.pendingRecoveriesCount > 0)
                            _buildRecoveryBanner(context, dashboardProvider),
                          Expanded(
                            child: (dashboardProvider.activeStoreId == null && !dashboardProvider.isLoading) && !(dashboardProvider.userProfile?.role == 'Super Admin' && dashboardProvider.isDeveloperMode)
                                ? _buildStoreSelectionScreen(context, dashboardProvider)
                                : widget.child,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // MOBILE LAYOUT (Standard Drawer)
          return Scaffold(
            appBar: AppBar(
              title: Text(dashboardProvider.activeStore?.name ?? 'BizPOS'),
              centerTitle: true,
              actions: [
                 if (dashboardProvider.userProfile?.role == 'Super Admin')
                     InkWell(
                       onTap: () => dashboardProvider.toggleDeveloperMode(),
                       borderRadius: BorderRadius.circular(20),
                       child: Container(
                         margin: const EdgeInsets.symmetric(horizontal: 8),
                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                         decoration: BoxDecoration(
                           color: dashboardProvider.isDeveloperMode ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                           borderRadius: BorderRadius.circular(20),
                           border: Border.all(color: dashboardProvider.isDeveloperMode ? Colors.red : Colors.green),
                         ),
                         child: Text(
                           dashboardProvider.isDeveloperMode ? AppLocalizations.t(context, 'developer_mode').substring(0, 3) : AppLocalizations.t(context, 'normal_mode').substring(0, 6),
                           style: TextStyle(
                             color: dashboardProvider.isDeveloperMode ? Colors.red : Colors.green, 
                             fontWeight: FontWeight.bold, 
                             fontSize: 11
                           ),
                         ),
                       ),
                     ),

                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () {
                     final isEmployee = dashboardProvider.activeRole != 'Store Owner' && dashboardProvider.activeRole != 'Admin';
                     dashboardProvider.clearSession();
                     authProvider.signOut();
                     if (isEmployee) {
                        context.go('/employee-login');
                     }
                  },
                ),
              ],
            ),
            drawer: Drawer(
              child: _buildDrawerContent(context, menuItems, authProvider, dashboardProvider),
            ),
            body: Column(
              children: [
                if (shellData.pendingRecoveriesCount > 0)
                  _buildRecoveryBanner(context, dashboardProvider),
                Expanded(
                  child: (dashboardProvider.activeStoreId == null && !dashboardProvider.isLoading) && !(dashboardProvider.userProfile?.role == 'Super Admin' && dashboardProvider.isDeveloperMode)
                      ? _buildStoreSelectionScreen(context, dashboardProvider)
                      : widget.child,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Refactored helper for just the list, shared between Drawer and Sidebar
  Widget _buildSidebarMenu(BuildContext context, List<Map<String, dynamic>> menuItems, AuthProvider authProvider, DashboardProvider dashboardProvider) {
      return ListView.builder(
            itemCount: menuItems.length,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            itemBuilder: (context, index) {
              final item = menuItems[index];
              final isSelected = GoRouterState.of(context).uri.toString().startsWith(item['route']);
              final color = item['color'] as Color? ?? Colors.grey;
              final isRestricted = item.containsKey('key') && !dashboardProvider.isFeatureEnabled(item['key'] as String);
              
              return DemoTarget(
                step: item['key'] == 'pos' ? 'nav_pos' : (item['key'] == 'reports' ? 'nav_reports' : 'none'),
                instruction: item['key'] == 'pos' ? "Click POS to start selling" : "Check Reports here",
                child: ListTile(
                  key: Key('menu_${item['key']}'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? color : color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item['icon'], color: isSelected ? Colors.white : color, size: 20),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          item['label'],
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isRestricted ? Colors.grey : (isSelected ? color : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (isRestricted) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.lock, size: 14, color: Colors.amber),
                      ],
                      if (!dashboardProvider.isOnline && (item['key'] == 'data_center' || item['key'] == 'central_catalog')) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.cloud_off, size: 14, color: Colors.orange),
                      ],
                    ],
                  ),
                  selected: isSelected,
                  selectedTileColor: color.withValues(alpha: 0.05),
                  onTap: () {
                     if (item['key'] == 'pos') dashboardProvider.nextDemoStep();
                     
                     // Check Plan Restriction: Navigation is allowed, FeatureGuard handles the rest.
                     context.go(item['route']);
                     // No pop needed for desktop sidebar
                  },
                ),
              );
            },
          );
  }

  Widget _buildStoreSelectionScreen(BuildContext context, DashboardProvider provider) {
    if (provider.stores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.store, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("No Stores Found", style: TextStyle(fontSize: 20, color: Colors.grey)),
            const SizedBox(height: 8),
            Text("You are logged in as ${provider.activeRole}, but no stores are available.", style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.store, size: 64, color: Colors.blue),
            const SizedBox(height: 24),
            const Text("Select a Store", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Please select a store to manage from the list below.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.stores.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final store = provider.stores[index];
                  return ListTile(
                    title: Text(store.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(store.status, style: TextStyle(color: store.status == 'Active' ? Colors.green : Colors.orange)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      provider.setActiveStoreId(store.id);
                      provider.linkUserToStore(Provider.of<AuthProvider>(context, listen: false).user!.uid, store.id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildDrawerContent(BuildContext context, List<Map<String, dynamic>> menuItems, AuthProvider authProvider, DashboardProvider dashboardProvider) {
    return Column(
      children: [
        UserAccountsDrawerHeader(
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
            backgroundImage: (dashboardProvider.userProfile?.photoBase64 != null && dashboardProvider.userProfile!.photoBase64!.isNotEmpty)
                ? MemoryImage(base64Decode(dashboardProvider.userProfile!.photoBase64!))
                : null,
            child: (dashboardProvider.userProfile?.photoBase64 == null || dashboardProvider.userProfile!.photoBase64!.isEmpty)
                ? const Icon(Icons.person, size: 40)
                : null,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
          ),
        ),
        // Store Selector
        if ((dashboardProvider.activeRole == 'Admin' || dashboardProvider.activeRole == 'Franchise Owner' || dashboardProvider.superAdmins.any((a) => a.uid == authProvider.user?.uid)) && dashboardProvider.stores.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200,
            child: DropdownButton<String>(
              isExpanded: true,
              value: dashboardProvider.activeStoreId,
              hint: const Text("Select Store"),
              underline: Container(), 
              items: dashboardProvider.stores.map((store) {
                 return DropdownMenuItem(
                   value: store.id,
                   child: Text(store.name, overflow: TextOverflow.ellipsis),
                 );
              }).toList(),
              onChanged: (val) {
                 if (val != null) {
                   dashboardProvider.setActiveStoreId(val);
                   dashboardProvider.linkUserToStore(authProvider.user!.uid, val);
                   Navigator.pop(context); 
                 }
              },
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: menuItems.length,
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemBuilder: (context, index) {
              final item = menuItems[index];
              final isSelected = GoRouterState.of(context).uri.toString().startsWith(item['route']);
              final color = item['color'] as Color? ?? Colors.grey;
              
              return ListTile(
                key: Key('menu_${item['key']}'),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item['icon'], color: color),
                ),
                title: Text(
                  item['label'],
                  style: TextStyle(
                    color: isSelected ? color : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                selected: isSelected,
                selectedTileColor: color.withValues(alpha: 0.05),
                onTap: () {
                  context.go(item['route']);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecoveryBanner(BuildContext context, DashboardProvider provider) {
    return MaterialBanner(
      backgroundColor: Colors.amber.shade100,
      leading: const Icon(Icons.warning_amber_rounded, color: Colors.amber),
      content: Text(
        "Found ${provider.pendingRecoveries.length} incomplete transactions from a previous session.",
        style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold),
      ),
      actions: [
        TextButton(
          onPressed: () => _showRecoveryDialog(context, provider),
          child: const Text("REVIEW"),
        ),
      ],
    );
  }

  void _showRecoveryDialog(BuildContext context, DashboardProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history, color: Colors.blue),
            SizedBox(width: 10),
            Text("Transaction Recovery"),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: provider.pendingRecoveries.length,
            itemBuilder: (context, index) {
              final recovery = provider.pendingRecoveries[index];
              final payload = recovery['payload'];
              final orderId = payload['order']['id'];
              
              return ListTile(
                title: Text("Order #$orderId"),
                subtitle: Text("Time: ${recovery['createdAt']}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.green),
                      tooltip: "Recover Transaction",
                      onPressed: () {
                        provider.resolveRecovery(recovery['txId'], context);
                        if (provider.pendingRecoveries.length <= 1) Navigator.pop(context);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: "Discard",
                      onPressed: () {
                        provider.discardRecovery(recovery['txId']);
                        if (provider.pendingRecoveries.length <= 1) Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          if (provider.pendingRecoveries.length > 1)
            TextButton(
              onPressed: () async {
                final ids = provider.pendingRecoveries.map((r) => r['txId'] as String).toList();
                for (var id in ids) {
                   await provider.resolveRecovery(id, context);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("RECOVER ALL", style: TextStyle(color: Colors.green)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE"),
          ),
        ],
      ),
    );
  }

  void _checkSubscriptionReminder() {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final days = provider.consolidatedStandardDays;

    if (days > 0 && days <= 3) {
      final lastShown = Hive.box('settings').get('last_reminder_shown');
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      if (lastShown != today) {
        showDialog(
          context: context,
          builder: (ctx) => SubscriptionReminderDialog(
            daysRemaining: days,
            onUpgrade: () => context.push('/biz-store'),
          ),
        );
        Hive.box('settings').put('last_reminder_shown', today);
      }
    }
  }
}

/// Lightweight data class for Selector-based shell rebuilds.
/// Only changes to these fields trigger a DashboardScreen rebuild.
class _DashboardShellData {
  final String? storeName;
  final String? activeStoreId;
  final String? role;
  final bool isOnline;
  final bool isDarkMode;
  final bool isDeveloperMode;
  final dynamic userProfile; // identity check is fine
  final int storesCount;
  final bool isLoading;
  final int pendingRecoveriesCount;

  const _DashboardShellData({
    this.storeName,
    this.activeStoreId,
    this.role,
    this.isOnline = false,
    this.isDarkMode = false,
    this.isDeveloperMode = false,
    this.userProfile,
    this.storesCount = 0,
    this.isLoading = false,
    this.pendingRecoveriesCount = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _DashboardShellData &&
          storeName == other.storeName &&
          activeStoreId == other.activeStoreId &&
          role == other.role &&
          isOnline == other.isOnline &&
          isDarkMode == other.isDarkMode &&
          isDeveloperMode == other.isDeveloperMode &&
          identical(userProfile, other.userProfile) &&
          storesCount == other.storesCount &&
          isLoading == other.isLoading &&
          pendingRecoveriesCount == other.pendingRecoveriesCount;

  @override
  int get hashCode => Object.hash(
        storeName,
        activeStoreId,
        role,
        isOnline,
        isDarkMode,
        isDeveloperMode,
        identityHashCode(userProfile),
        storesCount,
        isLoading,
        pendingRecoveriesCount,
      );
}
