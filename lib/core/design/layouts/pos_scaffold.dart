import 'package:flutter/material.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/auth_provider.dart';
import '../navigation/pos_sidebar.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/sync_status_widget.dart';

enum PosLayoutType { mobile, tablet, desktop }

/// A foundational layout structure specifically designed for POS interactions.
/// Unlike traditional app scaffolds that just scale down, this explicitly changes
/// the structure of the UI based on device type.
class PosScaffold extends StatefulWidget {
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
  final bool showSidebar;

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
    this.showSidebar = true,
  });

  @override
  State<PosScaffold> createState() => _PosScaffoldState();
}

class _PosScaffoldState extends State<PosScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  PosLayoutType _getLayoutType(BoxConstraints constraints) {
    if (constraints.maxWidth < 600) return PosLayoutType.mobile;
    if (constraints.maxWidth < 1100) return PosLayoutType.tablet;
    return PosLayoutType.desktop;
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL: Use context.select instead of Provider.of(context) to prevent
    // rebuilding the entire scaffold on EVERY DashboardProvider change.
    final storeName = context.select<DashboardProvider, String?>((p) => p.activeStore?.name);
    final userRole = context.select<DashboardProvider, String?>((p) => p.userProfile?.role);
    final isDarkMode = context.select<DashboardProvider, bool>((p) => p.isDarkMode);
    final isDevMode = context.select<DashboardProvider, bool>((p) => p.isDeveloperMode);
    
    // AuthProvider is usually stable, listen: false is fine
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutType = _getLayoutType(constraints);
        
        // Define Default AppBar
        final effectiveAppBar = widget.appBar ?? _buildAppBar(context, storeName, userRole, isDarkMode, isDevMode, authProvider, layoutType);

        switch (layoutType) {
          case PosLayoutType.mobile:
            return Scaffold(
              key: _scaffoldKey,
              appBar: effectiveAppBar,
              drawer: widget.drawer ?? const PosSidebar(isDrawer: true),
              body: widget.mainContent,
              floatingActionButton: widget.floatingActionButton,
              bottomNavigationBar: widget.bottomBar,
            );
          
          case PosLayoutType.tablet:
            final showInlineSidebar = widget.showSidebar && widget.rightPanel == null;
            return Scaffold(
              key: _scaffoldKey,
              appBar: effectiveAppBar,
              drawer: showInlineSidebar ? null : (widget.drawer ?? const PosSidebar(isDrawer: true)),
              body: Row(
                children: [
                  if (showInlineSidebar)
                    widget.leftPanel ?? const PosSidebar(),
                  Expanded(
                    flex: 6,
                    child: widget.mainContent,
                  ),
                  if (widget.rightPanel != null) ...[
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 4,
                      child: widget.rightPanel!,
                    ),
                  ],
                ],
              ),
              floatingActionButton: widget.floatingActionButton,
            );

          case PosLayoutType.desktop:
            return Scaffold(
              key: _scaffoldKey,
              body: Row(
                children: [
                  // Automatically include Sidebar on Desktop if leftPanel is not explicitly overridden
                  if (widget.showSidebar)
                    widget.leftPanel ?? const PosSidebar(),
                  Expanded(
                    flex: 8,
                    child: Column(
                      children: [
                        if (effectiveAppBar != null) 
                          PreferredSize(
                            preferredSize: const Size.fromHeight(kToolbarHeight),
                            child: effectiveAppBar,
                          ),
                        Expanded(child: widget.mainContent),
                      ],
                    ),
                  ),
                  if (widget.rightPanel != null) ...[
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 4,
                      child: widget.rightPanel!,
                    ),
                  ],
                ],
              ),
              floatingActionButton: widget.floatingActionButton,
            );
        }
      },
    );
  }

  PreferredSizeWidget? _buildAppBar(
    BuildContext context, 
    String? storeName,
    String? userRole,
    bool isDarkMode,
    bool isDevMode,
    AuthProvider authProvider, 
    PosLayoutType layoutType
  ) {
    if (widget.title == null && widget.actions == null && !widget.showGlobalActions) return null;
    final canPop = Navigator.of(context).canPop();
    // We still need dashboardProvider for non-reactive actions (functions)
    final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);

    return AppBar(
      leading: canPop 
        ? IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          )
        : (layoutType == PosLayoutType.mobile || layoutType == PosLayoutType.tablet)
            ? _buildDrawerMenuButton(context)
            : null,
      title: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.title != null && widget.title!.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.title!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              Text(
                storeName ?? 'BizPOS',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          );
        }
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: layoutType == PosLayoutType.desktop ? AppColors.transparent : null,
      foregroundColor: layoutType == PosLayoutType.desktop ? Theme.of(context).textTheme.bodyLarge?.color : null,
      actions: [
        if (widget.actions != null) ...widget.actions!,
        
        if (widget.showGlobalActions) ...[
          // Sync Status & Manual Sync
          const SyncStatusWidget(),
          
          _buildHeaderIconButton(
            context,
            icon: Icons.refresh,
            tooltip: 'Sync Now',
            onPressed: () {
              dashboardProvider.refreshDashboard();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Refreshing data..."), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)),
              );
            },
          ),

          // Developer Mode Toggle (Super Admin Only)
          if (userRole == 'Super Admin')
            _buildDevModeToggle(context, isDevMode),

          if (layoutType == PosLayoutType.desktop) ...[
            _buildHeaderIconButton(
              context,
              icon: isDarkMode ? Icons.light_mode : Icons.dark_mode,
              tooltip: 'Toggle Theme',
              onPressed: () => dashboardProvider.toggleTheme(),
            ),
          ],

          _buildHeaderIconButton(
            context,
            icon: Icons.logout,
            tooltip: 'Logout',
            onPressed: () {
              final isEmployee = dashboardProvider.activeRole != 'Store Owner' && dashboardProvider.activeRole != 'Admin';
              dashboardProvider.clearSession();
              authProvider.signOut();
              if (isEmployee) context.go('/login');
            },
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _buildHeaderIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final iconColor = color ?? theme.appBarTheme.foregroundColor ?? theme.textTheme.bodyLarge?.color;
    
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.borderSm,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.textPrimaryLight).withValues(alpha: 0.05),
              borderRadius: AppRadius.borderSm,
              border: Border.all(color: (iconColor ?? AppColors.textPrimaryLight).withValues(alpha: 0.1)),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ),
      ),
    );
  }

  Widget _buildDevModeToggle(BuildContext context, bool isDev) {
    final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
    final statusColor = isDev ? AppColors.error : AppColors.success;
    
    return InkWell(
      onTap: () => dashboardProvider.toggleDeveloperMode(),
      borderRadius: AppRadius.borderSm,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: AppRadius.borderSm,
          border: Border.all(color: statusColor),
        ),
        child: Text(
          isDev ? AppLocalizations.t(context, 'developer_mode') : AppLocalizations.t(context, 'normal_mode'),
          style: TextStyle(
            color: statusColor, 
            fontWeight: FontWeight.bold, 
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerMenuButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: () => Scaffold.of(context).openDrawer(),
        borderRadius: AppRadius.borderSm,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.adaptivePrimary(context).withValues(alpha: 0.05),
            borderRadius: AppRadius.borderSm,
            border: Border.all(color: AppColors.adaptivePrimary(context).withValues(alpha: 0.1)),
          ),
          child: Icon(
            Icons.menu_rounded,
            color: AppColors.adaptivePrimary(context),
            size: 20,
          ),
        ),
      ),
    );
  }
}



