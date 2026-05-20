import '../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/density/app_density.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';
import '../core/design/tokens/app_radius.dart';
import '../core/design/tokens/app_shadows.dart';

import 'admin/manage_roles_screen.dart';
import 'admin/store_management_screen.dart';
import 'admin/other_settings_screen.dart';
import 'admin/release_management_screen.dart';
import 'admin/basic_plan_settings_screen.dart';
import 'user_management_screen.dart';
import 'auth/station_lock_screen.dart';
import 'admin/subscription_approval_screen.dart';
import 'admin/subscriptions_overview_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final density = AppDensityProvider.configOf(context);
    final isDark = AppColors.isDark(context);

    final List<_AdminMenuItem> adminMenuItems = [
      _AdminMenuItem(
        icon: Icons.store_rounded,
        label: 'Store Management',
        description: 'Manage all client stores and subscriptions',
        widgetBuilder: () => const StoreManagementScreen(),
        gradient: const [Color(0xFFF59E0B), Color(0xFFF97316)],
      ),
      _AdminMenuItem(
        icon: Icons.people_alt_rounded,
        label: 'User Management',
        description: 'Manage system users and access',
        widgetBuilder: () => const UserManagementScreen(),
        gradient: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      ),
      _AdminMenuItem(
        icon: Icons.shield_rounded,
        label: 'Roles & Permissions',
        description: 'Define user roles and access control',
        widgetBuilder: () => const ManageRolesScreen(),
        gradient: const [Color(0xFF3B82F6), Color(0xFF06B6D4)],
      ),
      _AdminMenuItem(
        icon: Icons.tune_rounded,
        label: 'Other Settings',
        description: 'Configure store types and misc settings',
        widgetBuilder: () => const OtherSettingsScreen(),
        gradient: const [Color(0xFF64748B), Color(0xFF94A3B8)],
      ),
      _AdminMenuItem(
        icon: Icons.rocket_launch_rounded,
        label: 'App Releases',
        description: 'Manage versions and force updates',
        widgetBuilder: () => const ReleaseManagementScreen(),
        gradient: const [Color(0xFFEF4444), Color(0xFFF97316)],
      ),
      _AdminMenuItem(
        icon: Icons.phonelink_lock_rounded,
        label: 'Handover System',
        description: 'Lock station for employee use',
        widgetBuilder: () => const StationLockScreen(),
        gradient: const [Color(0xFFF59E0B), Color(0xFFEAB308)],
      ),
      _AdminMenuItem(
        icon: Icons.speed_rounded,
        label: 'Basic Plan Limits',
        description: 'Set daily/monthly order quotas',
        widgetBuilder: () => const BasicPlanSettingsScreen(),
        gradient: const [Color(0xFF8B5CF6), Color(0xFFA855F7)],
      ),
      _AdminMenuItem(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Subscriptions',
        description: 'View revenue, active plans and history',
        widgetBuilder: () => const SubscriptionsOverviewScreen(),
        gradient: const [Color(0xFF10B981), Color(0xFF14B8A6)],
      ),
      _AdminMenuItem(
        icon: Icons.verified_rounded,
        label: 'Subscription Approvals',
        description: 'Verify and approve plan upgrade requests',
        widgetBuilder: () => const SubscriptionApprovalScreen(),
        gradient: const [Color(0xFF06B6D4), Color(0xFF3B82F6)],
      ),
    ];

    return PosScaffold(
      mainContent: CustomScrollView(
        slivers: [
          // ── Premium Header ──
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.all(density.cardPadding),
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: AppRadius.borderLg,
                boxShadow: isDark ? AppShadows.darkMd : AppShadows.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: AppRadius.borderSm,
                              ),
                              child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.t(context, 'Admin Dashboard'),
                                  style: AppTypography.headlineMedium.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppLocalizations.t(context, 'Super Admin tools and system configuration.'),
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Decorative element
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: AppRadius.borderLg,
                    ),
                    child: Icon(Icons.settings_rounded, color: Colors.white.withValues(alpha: 0.2), size: 48),
                  ),
                ],
              ),
            ),
          ),

          // ── Section Title ──
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: density.cardPadding).copyWith(bottom: AppSpacing.md),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.adaptivePrimary(context),
                      borderRadius: AppRadius.borderXs,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'System Tools',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.border(context),
                            AppColors.border(context).withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Grid ──
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: density.cardPadding),
            sliver: _buildGrid(context, adminMenuItems),
          ),
          SliverToBoxAdapter(child: SizedBox(height: density.cardPadding)),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<_AdminMenuItem> items) {
    final width = MediaQuery.of(context).size.width;

    int crossAxisCount = 2;
    if (width > 1200) {
      crossAxisCount = 4;
    } else if (width > 800) {
      crossAxisCount = 3;
    } else if (width < 400) {
      crossAxisCount = 1;
    }

    double aspectRatio = 1.35;
    if (crossAxisCount == 1) {
      aspectRatio = 3.5;
    } else if (crossAxisCount <= 2) {
      aspectRatio = 1.1;
    }

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: aspectRatio,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _PremiumAdminCard(
          item: items[index],
          isHorizontal: crossAxisCount == 1,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => items[index].widgetBuilder()),
            );
          },
        ),
        childCount: items.length,
      ),
    );
  }
}

// ── Data Model ──
class _AdminMenuItem {
  final IconData icon;
  final String label;
  final String description;
  final Widget Function() widgetBuilder;
  final List<Color> gradient;

  const _AdminMenuItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.widgetBuilder,
    required this.gradient,
  });
}

// ── Premium Card Widget (StatefulWidget for hover animation) ──
class _PremiumAdminCard extends StatefulWidget {
  final _AdminMenuItem item;
  final bool isHorizontal;
  final VoidCallback onTap;

  const _PremiumAdminCard({
    required this.item,
    required this.isHorizontal,
    required this.onTap,
  });

  @override
  State<_PremiumAdminCard> createState() => _PremiumAdminCardState();
}

class _PremiumAdminCardState extends State<_PremiumAdminCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(bool hovering) {
    setState(() => _isHovered = hovering);
    if (hovering) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final item = widget.item;
    final gradientColor = item.gradient.first;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: MouseRegion(
            onEnter: (_) => _onHover(true),
            onExit: (_) => _onHover(false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _isHovered
                      ? (isDark
                          ? gradientColor.withValues(alpha: 0.08)
                          : gradientColor.withValues(alpha: 0.04))
                      : AppColors.surface(context),
                  borderRadius: AppRadius.borderMd,
                  border: Border.all(
                    color: _isHovered
                        ? gradientColor.withValues(alpha: 0.3)
                        : AppColors.border(context),
                    width: _isHovered ? 1.5 : 1,
                  ),
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: gradientColor.withValues(alpha: isDark ? 0.15 : 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                          ...AppShadows.adaptive(context, light: AppShadows.md),
                        ]
                      : AppShadows.adaptive(context, light: AppShadows.sm),
                ),
                child: widget.isHorizontal
                    ? _buildHorizontalLayout(context, item, gradientColor)
                    : _buildVerticalLayout(context, item, gradientColor),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerticalLayout(BuildContext context, _AdminMenuItem item, Color gradientColor) {

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon with gradient background
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: item.gradient,
              ),
              borderRadius: AppRadius.borderSm,
              boxShadow: [
                BoxShadow(
                  color: gradientColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(item.icon, color: Colors.white, size: 26),
          ),

          const Spacer(),

          // Title
          Text(
            item.label,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xxs),

          // Description
          Text(
            item.description,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary(context),
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: AppSpacing.sm),

          // Arrow indicator
          Row(
            children: [
              Container(
                width: 24,
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: item.gradient),
                  borderRadius: AppRadius.borderCircular,
                ),
              ),
              const Spacer(),
              AnimatedOpacity(
                opacity: _isHovered ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: AnimatedSlide(
                  offset: _isHovered ? Offset.zero : const Offset(-0.2, 0),
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: _isHovered ? gradientColor : AppColors.textHint(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalLayout(BuildContext context, _AdminMenuItem item, Color gradientColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: item.gradient,
              ),
              borderRadius: AppRadius.borderSm,
              boxShadow: [
                BoxShadow(
                  color: gradientColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(item.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.label,
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          AnimatedOpacity(
            opacity: _isHovered ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: gradientColor),
          ),
        ],
      ),
    );
  }
}
