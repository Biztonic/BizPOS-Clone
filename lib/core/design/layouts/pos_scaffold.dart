import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/auth_provider.dart';
import '../navigation/pos_sidebar.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import '../../../l10n/app_localizations.dart';

enum PosLayoutType { mobile, tablet, desktop }

/// A foundational layout structure specifically designed for POS interactions.
/// Unlike traditional app scaffolds that just scale down, this explicitly changes
/// the structure of the UI based on device type.
class PosScaffold extends StatelessWidget {
  final Widget? leftPanel; // Categories / Nav
  final Widget mainContent; // Products / Core
  final Widget? rightPanel; // Cart / Order Summary
  final Widget? bottomBar; // Mobile Action Bar
  final List<Widget>? actions; // Page-specific actions
  final String? title;
  final Widget? drawer; // Mobile Drawer
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBar;
  final bool showGlobalActions;
  
  const PosScaffold({
    super.key,
    this.leftPanel,
    required this.mainContent,
    this.rightPanel,
    this.bottomBar,
    this.actions,
    this.title,
    this.drawer,
    this.floatingActionButton,
    this.appBar,
    this.showGlobalActions = true,
  });

  PosLayoutType _getLayoutType(BoxConstraints constraints) {
    if (constraints.maxWidth < 600) return PosLayoutType.mobile;
    if (constraints.maxWidth < 1100) return PosLayoutType.tablet;
    return PosLayoutType.desktop;
  }

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutType = _getLayoutType(constraints);
        
        // Define Default AppBar
        final effectiveAppBar = appBar ?? _buildAppBar(context, dashboardProvider, authProvider, layoutType);

        switch (layoutType) {
          case PosLayoutType.mobile:
            return Scaffold(
              appBar: effectiveAppBar,
              drawer: drawer ?? const PosSidebar(isDrawer: true),
              body: mainContent,
              floatingActionButton: floatingActionButton,
              bottomNavigationBar: bottomBar,
            );
          
          case PosLayoutType.tablet:
            return Scaffold(
              appBar: effectiveAppBar,
              drawer: drawer ?? const PosSidebar(isDrawer: true),
              body: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: mainContent,
                  ),
                  if (rightPanel != null) ...[
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 4,
                      child: rightPanel!,
                    ),
                  ],
                ],
              ),
              floatingActionButton: floatingActionButton,
            );

          case PosLayoutType.desktop:
            return Scaffold(
              body: Row(
                children: [
                  // Automatically include Sidebar on Desktop if leftPanel is not explicitly overridden
                  leftPanel ?? const PosSidebar(),
                  if (leftPanel != null) const VerticalDivider(width: 1),
                  Expanded(
                    flex: 8,
                    child: Column(
                      children: [
                        if (effectiveAppBar != null) effectiveAppBar,
                        Expanded(child: mainContent),
                      ],
                    ),
                  ),
                  if (rightPanel != null) ...[
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 4,
                      child: rightPanel!,
                    ),
                  ],
                ],
              ),
              floatingActionButton: floatingActionButton,
            );
        }
      },
    );
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context, DashboardProvider dashboardProvider, AuthProvider authProvider, PosLayoutType layoutType) {
    if (title == null && actions == null && !showGlobalActions) return null;

    return AppBar(
      title: Text(title ?? dashboardProvider.activeStore?.name ?? 'BizPOS'),
      centerTitle: layoutType == PosLayoutType.mobile,
      elevation: 0,
      backgroundColor: layoutType == PosLayoutType.desktop ? Colors.transparent : null,
      foregroundColor: layoutType == PosLayoutType.desktop ? Theme.of(context).textTheme.bodyLarge?.color : null,
      actions: [
        if (actions != null) ...actions!,
        
        if (showGlobalActions) ...[
           // Developer Mode Toggle (Super Admin Only)
          if (dashboardProvider.userProfile?.role == 'Super Admin')
            _buildDevModeToggle(context, dashboardProvider),

          if (layoutType == PosLayoutType.desktop) ...[
            IconButton(
              icon: Icon(dashboardProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: () => dashboardProvider.toggleTheme(),
              tooltip: 'Toggle Theme',
            ),
            const SizedBox(width: 8),
          ],

          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              final isEmployee = dashboardProvider.activeRole != 'Store Owner' && dashboardProvider.activeRole != 'Admin';
              dashboardProvider.clearSession();
              authProvider.signOut();
              if (isEmployee) context.go('/employee-login');
            },
            tooltip: 'Logout',
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildDevModeToggle(BuildContext context, DashboardProvider dashboardProvider) {
    final isDev = dashboardProvider.isDeveloperMode;
    return InkWell(
      onTap: () => dashboardProvider.toggleDeveloperMode(),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDev ? AppColors.error.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDev ? AppColors.error : AppColors.success),
        ),
        child: Text(
          isDev ? AppLocalizations.t(context, 'developer_mode') : AppLocalizations.t(context, 'normal_mode'),
          style: TextStyle(
            color: isDev ? AppColors.error : AppColors.success, 
            fontWeight: FontWeight.bold, 
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
