import '../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/density/app_density.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';


import 'admin/manage_roles_screen.dart';
import 'admin/store_management_screen.dart';
import 'admin/other_settings_screen.dart';
import 'admin/release_management_screen.dart';
import 'admin/basic_plan_settings_screen.dart'; // NEW
import 'user_management_screen.dart';
import 'auth/station_lock_screen.dart';
import 'admin/subscription_approval_screen.dart';
import 'admin/subscriptions_overview_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final density = AppDensityProvider.configOf(context);
    // Admin Menu Items
    final List<Map<String, dynamic>> adminMenuItems = [
      {
        'icon': Icons.store,
        'label': 'Store Management',
        'description': 'Manage all client stores and subscriptions',
        'widgetBuilder': () => const StoreManagementScreen(),
        'color': AppColors.warning,
      },
      {
        'icon': Icons.people,
        'label': 'User Management',
        'description': 'Manage system users and access',
        'widgetBuilder': () => const UserManagementScreen(),
        'color': AppColors.primary,
      },

      {
        'icon': Icons.shield,
        'label': 'Roles & Permissions',
        'description': 'Define user roles and access control',
        'widgetBuilder': () => const ManageRolesScreen(),
        'color': AppColors.primaryLight,
      },
      {
        'icon': Icons.tune,
        'label': 'Other Settings',
        'description': 'Configure store types and misc settings',
        'widgetBuilder': () => const OtherSettingsScreen(),
        'color': AppColors.primaryLightGrey,
      },
      {
        'icon': Icons.system_update,
        'label': 'App Releases',
        'description': 'Manage versions and force updates',
        'widgetBuilder': () => const ReleaseManagementScreen(),
        'color': AppColors.error,
      },
      // HANDOVER
      {
        'icon': Icons.phonelink_lock,
        'label': 'Handover System',
        'description': 'Lock station for employee use',
        'widgetBuilder': () => const StationLockScreen(),
        'color': AppColors.warning,
      },
      {
        'icon': Icons.lock_clock, 
        'label': 'Basic Plan Limits',
        'description': 'Set daily/monthly order quotas',
        'widgetBuilder': () => const BasicPlanSettingsScreen(),
        'color': AppColors.primaryLight,
      },
      {
        'icon': Icons.account_balance_wallet,
        'label': 'Subscriptions',
        'description': 'View revenue, active plans and history',
        'widgetBuilder': () => const SubscriptionsOverviewScreen(),
        'color': AppColors.primary,
      },
      {
        'icon': Icons.approval,
        'label': 'Subscription Approvals',
        'description': 'Verify and approve plan upgrade requests',
        'widgetBuilder': () => const SubscriptionApprovalScreen(),
        'color': AppColors.success,
      }
    ];

    

    return PosScaffold(
      mainContent: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(density.cardPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildModernHeader(context),
                const SizedBox(height: AppSpacing.lg),
              ]),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: density.cardPadding),
            sliver: _buildAdminToolsSliverGrid(context, adminMenuItems),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: density.cardPadding),
          ),
        ],
      ),
    );
  }

  // --- TOP HEADER ---
  Widget _buildModernHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.t(context, 'Admin Dashboard'), style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        const SizedBox(height: AppSpacing.xs),
        Text(AppLocalizations.t(context, 'Super Admin tools and system configuration.'), style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
      ],
    );
  }

  // --- ADMIN TOOLS GRID ---
  Widget _buildAdminToolsSliverGrid(BuildContext context, List<Map<String, dynamic>> items) {
    final width = MediaQuery.of(context).size.width;
    
    // Responsive grid
    int crossAxisCount = 2;
    if (width > 1200) {
      crossAxisCount = 4;
    } else if (width > 800) {
      crossAxisCount = 3;
    } else if (width < 400) {
      crossAxisCount = 1; 
    }

    // Responsive Aspect Ratio
    double aspectRatio = 1.2;
    bool isHorizontal = false;
    if (crossAxisCount == 1) {
      aspectRatio = 3.2; 
      isHorizontal = true;
    } else if (crossAxisCount <= 2) {
      aspectRatio = 1.0; 
    }

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: aspectRatio,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = items[index];
          return _buildAdminCard(
            context,
            icon: item['icon'] as IconData,
            label: item['label'] as String,
            description: item['description'] as String,
            color: item['color'] as Color,
            horizontal: isHorizontal,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => item['widgetBuilder'](),
                ),
              );
            },
          );
        },
        childCount: items.length,
      ),
    );
  }

  Widget _buildAdminCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
    bool horizontal = false,
  }) {
    final density = AppDensityProvider.configOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        padding: EdgeInsets.all(density.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.zero,
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimaryLight.withValues(alpha: isDark ? 0.3 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: AppColors.outline(context)),
        ),
        child: horizontal 
          ? Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: AppSpacing.md),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        description,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary(context).withValues(alpha: 0.5)),
              ],
            )
          : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.zero,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            
            // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        description,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}



