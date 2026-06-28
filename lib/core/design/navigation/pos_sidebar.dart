import 'dart:convert';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/demo_target.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_iconography.dart';
import '../tokens/app_typography.dart';
import '../../registry/registry.dart';

class PosSidebar extends StatefulWidget {
  final bool isDrawer;

  const PosSidebar({
    super.key,
    this.isDrawer = false,
  });

  @override
  State<PosSidebar> createState() => _PosSidebarState();
}

class _PosSidebarState extends State<PosSidebar> {
  @override
  Widget build(BuildContext context) {
    // Use selective watches to prevent redundant rebuilds
    final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final role = context.select<DashboardProvider, String?>((p) => p.activeRole);
    final isDeveloperMode = context.select<DashboardProvider, bool>((p) => p.isDeveloperMode);
    final isSuperAdmin = context.select<DashboardProvider, bool>((p) => p.isSuperAdmin);
    
    final activeStoreName = context.select<DashboardProvider, String?>((p) => p.activeStore?.name);
    final userName = context.select<DashboardProvider, String?>((p) => p.userProfile?.name);
    final userEmail = context.select<DashboardProvider, String?>((p) => p.userProfile?.email);
    final userPhoto = context.select<DashboardProvider, String?>((p) => p.userProfile?.photoBase64);
    final isOnline = context.select<DashboardProvider, bool>((p) => p.isOnline);
    final hasMultipleStores = context.select<DashboardProvider, int>((p) => p.stores.length) > 1;
    final isCollapsed = context.select<DashboardProvider, bool>((p) => p.isSidebarCollapsed);

    // Force rebuild if addons or plan change
    // ignore: unused_local_variable
    final activeAddonsCount = context.select<DashboardProvider, int>((p) => p.activeStore?.addons.length ?? 0);
    // ignore: unused_local_variable
    final purchasedAddonsCount = context.select<DashboardProvider, int>((p) => p.activeStore?.purchasedAddons.length ?? 0);
    // ignore: unused_local_variable
    final subscriptionPlan = context.select<DashboardProvider, String?>((p) => p.activeStore?.subscriptionPlan);

    // 1. Generate Core Menu Items (always present)
    final List<Map<String, dynamic>> allMenuItems = [
      {'icon': Icons.dashboard, 'label': AppLocalizations.t(context, 'dashboard'), 'route': '/dashboard', 'key': 'dashboard', 'color': AppColors.primary},
      {'icon': Icons.point_of_sale, 'label': AppLocalizations.t(context, 'pos'), 'route': '/pos', 'key': 'pos', 'color': AppColors.success}, 
      {'icon': Icons.inventory, 'label': AppLocalizations.t(context, 'inventory'), 'route': '/inventory', 'key': 'inventory', 'color': AppColors.warning},
      {'icon': Icons.shopping_cart, 'label': AppLocalizations.t(context, 'sales'), 'route': '/sales', 'key': 'reports', 'color': AppColors.primaryLight}, 
      {'icon': Icons.bar_chart, 'label': AppLocalizations.t(context, 'Reports'), 'route': '/reports', 'key': 'reports', 'color': AppColors.primary},
      // --- Dynamic addon entries injected below ---
      // --- System items (always at bottom) ---
      {'icon': Icons.settings, 'label': AppLocalizations.t(context, 'setting'), 'route': '/settings', 'key': 'settings', 'color': AppColors.textSecondary(context)},
      {'icon': Icons.admin_panel_settings, 'label': AppLocalizations.t(context, 'admin'), 'route': '/admin', 'key': 'admin', 'enabled': isSuperAdmin && isDeveloperMode, 'color': AppColors.textPrimary(context)},
      {'icon': Icons.extension, 'label': 'BizStore', 'route': '/biz-store', 'key': 'biz_store', 'enabled': role != 'Super Admin', 'color': AppColors.primary},
      {'icon': Icons.translate, 'label': AppLocalizations.t(context, 'languages'), 'route': '/languages', 'key': 'admin', 'enabled': isSuperAdmin && isDeveloperMode, 'color': AppColors.primaryLight},
    ];

    // --- Inject Dynamic Module Sidebar Entries (after core, before system items) ---
    final dynamicEntries = POSCoreRegistry.getSidebarEntries(context);
    allMenuItems.insertAll(5, dynamicEntries); // Insert after Reports

    final menuItems = allMenuItems.where((item) {
      // 1. Check explicit enabled flag (e.g. Admin menu gated by dev mode)
      if (item.containsKey('enabled') && item['enabled'] == false) return false;

      // 2. Check feature-level enablement from provider
      if (item.containsKey('key')) {
        final key = item['key'] as String;
        final isFeatureActive = dashboardProvider.isFeatureEnabled(key);
        
      // Super Admins see almost everything unless explicitly disabled (like Admin menu in normal mode)
      if (isSuperAdmin) {
        // If it's a feature-gated item, still check if it's active
        if (item.containsKey('enabled')) return item['enabled'] == true;
        return isFeatureActive;
      }


        // For regular roles, check both activeRole permissions and feature activation
        if (!isFeatureActive) return false;
        
        // Additional role-based filtering if needed
        if (key == 'admin' && role != 'Super Admin') return false;
      }
      
      return true;
    }).toList();

    final sidebarContent = Container(
      width: widget.isDrawer ? null : (isCollapsed ? 80 : 280),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
      ),
      child: Column(
        children: [
          if (widget.isDrawer)
            _buildDrawerHeader(context, userName, userEmail, activeStoreName, userPhoto, authProvider)
          else
            _buildSidebarHeader(context, activeStoreName, userName, userPhoto, isOnline, isCollapsed, dashboardProvider),
          
          // Store Selector (if multiple stores - include Store Owner)
          if (!isCollapsed && (role == 'Store Owner' || role == 'Admin' || role == 'Franchise Owner' || role == 'Super Admin') && hasMultipleStores)
            _buildStoreSelector(context, dashboardProvider, authProvider),


          Expanded(
            child: _buildMenuList(context, menuItems, dashboardProvider, isCollapsed),
          ),
        ],
      ),
    );

    return widget.isDrawer ? Drawer(child: sidebarContent) : sidebarContent;
  }

  Widget _buildSidebarHeader(BuildContext context, String? storeName, String? userName, String? userPhoto, bool isOnline, bool isCollapsed, DashboardProvider provider) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: isCollapsed ? AppSpacing.sm : AppSpacing.md),
      child: isCollapsed ? Column(
        children: [
          _buildToggleButton(context, isCollapsed, provider),
          const SizedBox(height: AppSpacing.md),
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            backgroundImage: (userPhoto != null && userPhoto.isNotEmpty)
                ? MemoryImage(base64Decode(userPhoto))
                : null,
            child: (userPhoto == null || userPhoto.isEmpty)
                ? Icon(Icons.person, color: Theme.of(context).primaryColor, size: 18)
                : null,
          ),
        ]
      ) : Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            backgroundImage: (userPhoto != null && userPhoto.isNotEmpty)
                ? MemoryImage(base64Decode(userPhoto))
                : null,
            child: (userPhoto == null || userPhoto.isEmpty)
                ? Icon(Icons.person, color: Theme.of(context).primaryColor, size: 20)
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName ?? 'BizPOS', 
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                if (userName != null)
                  Text(
                    userName,
                    style: TextStyle(
                      fontSize: 12, 
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontWeight: FontWeight.w500
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: AppSpacing.xs),
                _buildStatusBadge(context, isOnline),
              ],
            ),
          ),
          _buildToggleButton(context, isCollapsed, provider),
        ],
      ),
    );
  }

  Widget _buildToggleButton(BuildContext context, bool isCollapsed, DashboardProvider provider) {
    return InkWell(
      onTap: () => provider.toggleSidebar(),
      borderRadius: AppRadius.borderSm,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
          borderRadius: AppRadius.borderSm,
          border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.1)),
        ),
        child: Icon(
          isCollapsed ? Icons.menu_rounded : Icons.menu_open_rounded,
          color: Theme.of(context).primaryColor,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, String? userName, String? userEmail, String? storeName, String? userPhoto, AuthProvider authProvider) {
    return UserAccountsDrawerHeader(
      accountName: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(userName ?? authProvider.user?.displayName ?? 'User'),
          if (storeName != null)
            Text(
              storeName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: AppColors.textSecondaryDark),
            ),
        ],
      ),
      accountEmail: Text(userEmail ?? authProvider.user?.email ?? ''),
      currentAccountPicture: CircleAvatar(
        backgroundColor: Colors.white24,
        backgroundImage: (userPhoto != null && userPhoto.isNotEmpty)
            ? MemoryImage(base64Decode(userPhoto))
            : null,
        child: (userPhoto == null || userPhoto.isEmpty)
            ? const Icon(Icons.person, size: 40, color: AppColors.surfaceLight)
            : null,
      ),
      decoration: BoxDecoration(color: Theme.of(context).primaryColor),
    );
  }

  Widget _buildStatusBadge(BuildContext context, bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: isOnline ? AppColors.success.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: isOnline ? AppColors.success.withValues(alpha: 0.5) : AppColors.warning.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isOnline ? Icons.wifi : Icons.wifi_off, size: 10, color: isOnline ? AppColors.success : AppColors.warning),
          const SizedBox(width: AppSpacing.xs),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.textSecondary(context).withValues(alpha: 0.2) : AppColors.textSecondary(context).withValues(alpha: 0.1),
        borderRadius: AppRadius.borderMd,
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
               if (widget.isDrawer) Navigator.pop(context); 
             }
          },
        ),
      ),
    );
  }

  Color _getMenuItemColor(BuildContext context, Map<String, dynamic> item) {
    final key = item['key'] as String?;
    final route = item['route'] as String?;

    if (key == 'dashboard') return const Color(0xFF6366F1); // Indigo
    if (key == 'pos') return const Color(0xFF10B981); // Emerald
    if (key == 'inventory') return const Color(0xFFF59E0B); // Amber
    if (key == 'customer_management') return const Color(0xFF0EA5E9); // Sky Blue
    if (key == 'employee_management') return const Color(0xFF8B5CF6); // Purple
    if (key == 'franchise_management') return const Color(0xFFF43F5E); // Rose
    if (key == 'integration_hub') return const Color(0xFFD946EF); // Fuchsia
    if (key == 'kds_management') return const Color(0xFF0D9488); // Teal
    if (key == 'supplier_management') return const Color(0xFFEA580C); // Warm Orange
    if (key == 'table_reservation') return const Color(0xFFEAB308); // Yellow
    if (key == 'data_center') return const Color(0xFF8B5CF6); // Violet
    if (key == 'biz_store') return const Color(0xFF06B6D4); // Cyan

    if (route == '/sales') return const Color(0xFFEC4899); // Pink
    if (route == '/reports') return const Color(0xFF3B82F6); // Blue
    if (route == '/settings') return const Color(0xFF64748B); // Slate
    if (route == '/admin') return const Color(0xFFEF4444); // Crimson
    if (route == '/languages') return const Color(0xFF14B8A6); // Teal

    return item['color'] as Color? ?? AppColors.primary;
  }

  Widget _buildMenuList(BuildContext context, List<Map<String, dynamic>> menuItems, DashboardProvider dashboardProvider, bool isCollapsed) {
    return ScrollConfiguration(
      behavior: const _NoScrollbarBehavior(),
      child: ListView.builder(
        itemCount: menuItems.length,
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: isCollapsed ? 8 : 12),
        itemBuilder: (context, index) {
          final item = menuItems[index];
          // Safely get current URI from GoRouter or fallback to empty
          String currentUri = '';
          try {
            currentUri = GoRouterState.of(context).uri.toString();
          } catch (_) {
            // Fallback for cases where Navigator is used instead of GoRouter
          }
          
          // Exact match or sub-route match (e.g. /customers/detail matches /customers)
          final isSelected = currentUri.isNotEmpty && (currentUri == item['route'] || (item['route'] != '/dashboard' && currentUri.startsWith(item['route'])));
          final color = _getMenuItemColor(context, item);
          final isRestricted = item.containsKey('key') && !dashboardProvider.isFeatureEnabled(item['key'] as String);
          
          bool isHovered = false;
          return DemoTarget(
            step: item['key'] == 'pos' ? 'nav_pos' : (item['key'] == 'reports' ? 'nav_reports' : 'none'),
            instruction: item['key'] == 'pos' ? "Click POS to start selling" : "Check Reports here",
            child: StatefulBuilder(
              builder: (context, setState) {
                return MouseRegion(
                  onEnter: (_) => setState(() => isHovered = true),
                  onExit: (_) => setState(() => isHovered = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.1) : (isHovered ? color.withValues(alpha: 0.05) : AppColors.transparent),
                      borderRadius: AppRadius.borderMd,
                      border: Border(left: BorderSide(color: isSelected ? color : (isHovered ? color.withValues(alpha: 0.5) : AppColors.transparent), width: 4)),
                    ),
                    child: Material(
                      color: AppColors.transparent,
                      child: InkWell(
                        borderRadius: AppRadius.borderMd,
                        onTap: () {
                          if (item['key'] == 'pos') dashboardProvider.nextDemoStep();
                          
                          final route = item['route'] as String;
                          if (widget.isDrawer) {
                            // Safely close the drawer before navigating to prevent hangs
                            Navigator.pop(context);
                            // Short delay to allow drawer animation to start closing before navigation
                            Future.delayed(const Duration(milliseconds: 100), () {
                              if (context.mounted) {
                                context.go(route);
                              }
                            });
                          } else {
                            context.go(route);
                          }
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 12, vertical: 10),
                          child: Row(
                            mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                            children: [
                              _AnimatedSidebarIcon(
                                icon: item['icon'] as IconData,
                                color: color,
                                isSelected: isSelected,
                                isHovered: isHovered,
                                size: AppIconography.md,
                                containerSize: AppIconography.containerMd,
                                borderRadius: AppRadius.md,
                              ),
                              if (!isCollapsed) ...[
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    item['label'],
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyLarge.copyWith(
                                      color: isRestricted ? AppColors.textSecondary(context) : (isSelected ? color : (Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceLight : AppColors.textPrimary(context))),
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isRestricted) const Icon(Icons.lock, size: AppIconography.xs, color: AppColors.warning),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedSidebarIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isHovered;
  final double size;
  final double containerSize;
  final double borderRadius;

  const _AnimatedSidebarIcon({
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.isHovered,
    this.size = AppIconography.md,
    this.containerSize = AppIconography.containerMd,
    this.borderRadius = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: isSelected
            ? color.withValues(alpha: 0.16)
            : (isHovered ? color.withValues(alpha: 0.1) : color.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.all(Radius.circular(isHovered ? borderRadius * 1.25 : borderRadius)),
        border: Border.all(
          color: isSelected
              ? color.withValues(alpha: 0.4)
              : (isHovered ? color.withValues(alpha: 0.3) : color.withValues(alpha: 0.1)),
          width: 1.0,
        ),
        boxShadow: isHovered
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                )
              ]
            : [],
      ),
      child: Center(
        child: AnimatedScale(
          scale: isHovered ? 1.18 : 1.0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
          child: AnimatedRotation(
            turns: isHovered ? -0.03 : 0.0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            child: Icon(
              icon,
              color: isSelected
                  ? color
                  : (isHovered ? color.withValues(alpha: 1.0) : color.withValues(alpha: 0.75)),
              size: size,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}





