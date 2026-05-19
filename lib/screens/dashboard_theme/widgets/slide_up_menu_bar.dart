import 'package:flutter/material.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../utils/car_dashboard_theme.dart';
import 'glass_panel.dart';
import 'quick_action_dialogs.dart'; // Added

class SlideUpMenuBar extends StatefulWidget {
  final VoidCallback onClose;

  const SlideUpMenuBar({super.key, required this.onClose});

  @override
  State<SlideUpMenuBar> createState() => _SlideUpMenuBarState();
}

class _SlideUpMenuBarState extends State<SlideUpMenuBar> {
  late PageController _pageController;
  

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.14, 
      initialPage: 0, 
    );
  }

  List<Map<String, dynamic>> _buildMenuData(DashboardProvider provider) {
    final role = provider.activeRole;
    final isSuperAdmin = provider.userProfile?.role == 'Super Admin';
    final isOwnerOrAdmin = role == 'Store Owner' || role == 'Admin' || isSuperAdmin;
    
    // Core features always visible
    final items = <Map<String, dynamic>>[
      {'icon': Icons.point_of_sale, 'label': 'POS', 'route': '/pos'},
      {'icon': Icons.bar_chart, 'label': 'REPORTS', 'route': '/reports'},
      {'icon': Icons.history, 'label': 'SALES HISTORY', 'route': '/sales'}, 
      {'icon': Icons.dashboard, 'label': 'DASHBOARD', 'route': '/dashboard'},
    ];

    // Addon-gated features â€“ only show if addon is active
    if (provider.hasAddon('customer_management') && isOwnerOrAdmin) {
      items.add({'icon': Icons.people, 'label': 'CUSTOMERS', 'route': '/customers'});
    }
    if (provider.hasAddon('employee_management') && isOwnerOrAdmin) {
      items.add({'icon': Icons.badge, 'label': 'EMPLOYEES', 'route': '/employees'});
    }
    if (provider.hasAddon('kds_management') && isOwnerOrAdmin) {
      items.add({'icon': Icons.tv, 'label': 'DISPLAY', 'route': '/display'});
    }
    if (provider.hasAddon('table_reservation') && isOwnerOrAdmin) {
      items.add({'icon': Icons.table_restaurant, 'label': 'TABLES', 'route': '/tables'});
    }
    if (provider.hasAddon('franchise_management') || role == 'Franchise Owner') {
      items.add({'icon': Icons.store, 'label': 'FRANCHISES', 'route': '/franchises'});
    }
    if (provider.hasAddon('data_center') && isOwnerOrAdmin) {
      items.add({'icon': Icons.sync_alt, 'label': 'DATA CENTER', 'route': '/data-sync'});
    }

    // Printer â€“ always available as a utility
    items.add({'icon': Icons.print, 'label': 'PRINTER', 'route': '/printer'});
    
    // Settings
    items.add({'icon': Icons.settings, 'label': 'SETTINGS', 'route': '/settings'});
    
    // Logout always last
    items.add({'icon': Icons.logout, 'label': 'LOGOUT', 'action': 'logout'});
    
    return items;
  }

  void _onItemTap(Map<String, dynamic> item) {
    if (item.containsKey('action')) {
      final action = item['action'];
      if (action == 'logout') {
          // Fix: Ensure Demo Mode and all Data is cleared
          Provider.of<DashboardProvider>(context, listen: false).clearSession();
          Provider.of<AuthProvider>(context, listen: false).signOut();
          GoRouter.of(context).go('/login');
      } else if (action == 'last_bill') {
          showDialog(context: context, builder: (_) => const LastFiveBillsDialog());
      } else if (action == 'refund') {
          showDialog(context: context, builder: (_) => const RefundDialog());
      } else if (action == 'day_report') {
          showDialog(context: context, builder: (_) => const QuickDayReportDialog());
      }
    } else if (item.containsKey('route')) {
        context.push(item['route']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context); // Listen to changes
    final isDarkMode = provider.isDarkMode;
    final currentUri = GoRouterState.of(context).uri.toString();
    
    // Rebuild menu data on every build so it reacts to addon changes
    final menuItems = _buildMenuData(provider);
    
    return GlassPanel(
      borderRadius: 24,
      withGlow: false, 
      opacity: 1.0, // Solid Background
      color: CarDashboardTheme.panelColor(isDarkMode), // No opacity, strictly solid
      borderColor: CarDashboardTheme.textColor(isDarkMode).withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: CarDashboardTheme.subTextColor(isDarkMode).withValues(alpha: 0.5),
              borderRadius: BorderRadius.zero
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          
          // Scrollable Menu List
          SizedBox(
            height: 130, // Increased height to fit larger items
            child: PageView.builder(
              controller: _pageController,
              itemCount: menuItems.length,
              physics: const ClampingScrollPhysics(),
              padEnds: false, // Start from the edge
              itemBuilder: (context, index) {
                final item = menuItems[index];
                return _buildMenuItem(item, isDarkMode, currentUri);
              },
            ),
          ),
          

        ],
      ),
    );
  }

  Widget _buildMenuItem(Map<String, dynamic> item, bool isDarkMode, String currentUri) {
    final bool isSelected = item['route'] != null && currentUri.startsWith(item['route']);
    
    final itemColor = CarDashboardTheme.getIconColor(item['label'], isDarkMode);
    final borderColor = isSelected ? itemColor : itemColor.withValues(alpha: 0.3);

    return GestureDetector(
      onTap: () => _onItemTap(item),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md), // Increased padding
            decoration: BoxDecoration(
              color: isSelected ? itemColor.withValues(alpha: 0.2) : itemColor.withValues(alpha: 0.05),
              shape: BoxShape.rectangle,
              border: Border.all(
                color: borderColor,
                width: isSelected ? 2 : 1
              ),
              boxShadow: isSelected ? [BoxShadow(color: itemColor.withValues(alpha: 0.4), blurRadius: 10)] : null, 
            ),
            child: Icon(item['icon'], color: itemColor, size: 36), // Increased Size from 28 to 36
          ),
          const SizedBox(height: AppSpacing.md), 
          Text(
            item['label'],
            textAlign: TextAlign.center,
            style: CarDashboardTheme.labelStyle.copyWith(
              color: isSelected ? itemColor : CarDashboardTheme.textColor(isDarkMode), 
              fontWeight: FontWeight.bold,
              fontSize: 12 // Increased font size from 10 to 12
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}



