import 'package:flutter/material.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import 'widgets/holo_menu_card.dart';

class DashboardGridMenu extends StatelessWidget {
  const DashboardGridMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final role = provider.activeRole;
    final isSuperAdmin = provider.userProfile?.role == 'Super Admin';
    final isOwnerOrAdmin = role == 'Store Owner' || role == 'Admin' || isSuperAdmin;

    // Define Menu Actions – core items always visible
    final menuItems = <Map<String, dynamic>>[
       {'label': 'POS TERMINAL', 'icon': Icons.point_of_sale, 'route': '/pos', 'size': 2}, // Large
       {'label': 'INVENTORY', 'icon': Icons.inventory, 'route': '/inventory', 'size': 1},
       {'label': 'SALES LOG', 'icon': Icons.receipt_long, 'route': '/sales', 'size': 1},
    ];

    // Addon-gated items
    if (provider.hasAddon('customer_management') && isOwnerOrAdmin) {
      menuItems.add({'label': 'CUSTOMERS', 'icon': Icons.people, 'route': '/customers', 'size': 1});
    }
    if (provider.hasAddon('employee_management') && isOwnerOrAdmin) {
      menuItems.add({'label': 'EMPLOYEES', 'icon': Icons.badge, 'route': '/employees', 'size': 1});
    }

    // Always visible
    menuItems.addAll([
       {'label': 'REPORTS', 'icon': Icons.bar_chart, 'route': '/reports', 'size': 1},
       {'label': 'SETTINGS', 'icon': Icons.settings_applications, 'route': '/settings', 'size': 2}, // Large
    ]);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, 
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: 1.2,
            ),
            itemCount: menuItems.length,
            itemBuilder: (ctx, i) {
              final item = menuItems[i];
              return HoloMenuCard(
                label: item['label'] as String,
                icon: item['icon'] as IconData,
                onTap: () => context.go(item['route'] as String),
                isLarge: (item['size'] as int) == 2,
              );
            },
          ),
        ),
      ),
    );
  }
}
