import '../core/design/design_system.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import 'package:biztonic_pos/providers/auth_provider.dart';
import 'package:biztonic_pos/models/store.dart';
import 'package:biztonic_pos/services/update_service.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'settings/subscription_reminder_dialog.dart';

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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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
       final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
       final authProvider = Provider.of<AuthProvider>(context, listen: false);
       dashboardProvider.clearSession();
       authProvider.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        dashboardProvider.clearSession();
        authProvider.signOut();

        if (Theme.of(context).platform == TargetPlatform.android) {
           Future.delayed(const Duration(milliseconds: 200), () => SystemNavigator.pop());
        } else {
           SystemNavigator.pop();
        }
      },
      child: dashboardProvider.isInitialSyncing
          ? _buildInitialSyncScreen(context, dashboardProvider)
          : (dashboardProvider.activeStoreId == null && !dashboardProvider.isLoading) && 
                 !(dashboardProvider.userProfile?.role == 'Super Admin' && dashboardProvider.isDeveloperMode)
              ? _buildStoreSelectionScreen(context, dashboardProvider)
              : widget.child,
    );
  }

  Widget _buildInitialSyncScreen(BuildContext context, DashboardProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary;
    final progress = provider.initialSyncProgress;
    final status = provider.initialSyncStatus;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)] 
              : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PulsingStoreIcon(color: primaryColor),
                const SizedBox(height: AppSpacing.lg),

                Text(
                  AppLocalizations.t(context, 'Setting Up Your Store'),
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppLocalizations.t(context, 'Please wait while we sync your cloud database.'),
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),

                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: AppRadius.borderMd,
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              status,
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            "${(progress * 100).toInt()}%",
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                _buildSyncSteps(context, progress, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncSteps(BuildContext context, double progress, bool isDark) {
    final steps = [
      {'name': 'Settings & Catalog', 'threshold': 0.1},
      {'name': 'Employees & Security', 'threshold': 0.3},
      {'name': 'Store Floor Layout', 'threshold': 0.5},
      {'name': 'Suppliers & CRM', 'threshold': 0.7},
      {'name': 'Inventory Stock', 'threshold': 0.9},
      {'name': 'Finalizing Config', 'threshold': 1.0},
    ];

    return Column(
      children: steps.map((step) {
        final threshold = step['threshold'] as double;
        final name = step['name'] as String;
        
        final isCompleted = progress >= threshold;
        final isCurrent = progress < threshold && (progress >= (threshold - 0.2));

        Color iconColor = Colors.grey;
        IconData icon = Icons.circle_outlined;

        if (isCompleted) {
          iconColor = AppColors.success;
          icon = Icons.check_circle_rounded;
        } else if (isCurrent) {
          iconColor = AppColors.primary;
          icon = Icons.sync;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  icon,
                  key: ValueKey(icon),
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                AppLocalizations.t(context, name),
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted
                      ? AppColors.textSecondary(context)
                      : (isCurrent ? AppColors.textPrimary(context) : AppColors.textHint(context)),
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStoreSelectionScreen(BuildContext context, DashboardProvider provider) {
    if (provider.stores.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.store, size: 64, color: AppColors.textSecondary(context)),
              const SizedBox(height: AppSpacing.md),
              Text(AppLocalizations.t(context, 'No Stores Found'), style: AppTypography.titleLarge.copyWith(color: AppColors.textSecondary(context))),
              const SizedBox(height: AppSpacing.sm),
              Text("You are logged in as ${provider.activeRole}, but no stores are available.", style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.store, size: 64, color: AppColors.adaptivePrimary(context)),
                const SizedBox(height: AppSpacing.lg),
                Text(AppLocalizations.t(context, 'Select a Store'), textAlign: TextAlign.center, style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.sm),
                Text(AppLocalizations.t(context, 'Please select a store to manage from the list below.'), textAlign: TextAlign.center, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border(context)),
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: Builder(
                    builder: (context) {
                      List<Store> allowedStores = provider.stores;
                      if (provider.activeRole == 'Franchise Owner') {
                        final uid = provider.userProfile?.uid;
                        final email = provider.userProfile?.email;
                        allowedStores = allowedStores.where((store) {
                          return store.owner == uid || (email != null && store.ownerEmail == email);
                        }).toList();
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: allowedStores.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final store = allowedStores[index];
                          return ListTile(
                            title: Text(store.name, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                            subtitle: Text(store.status, style: AppTypography.labelMedium.copyWith(color: store.status == 'Active' ? AppColors.adaptiveSuccess(context) : AppColors.adaptiveWarning(context))),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              provider.setActiveStoreId(store.id);
                              provider.linkUserToStore(Provider.of<AuthProvider>(context, listen: false).user!.uid, store.id);
                            },
                          );
                        },
                      );
                    }
                  ),
                ),
              ],
            ),
          ),
        ),
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

class _PulsingStoreIcon extends StatefulWidget {
  final Color color;
  const _PulsingStoreIcon({required this.color});

  @override
  State<_PulsingStoreIcon> createState() => _PulsingStoreIconState();
}

class _PulsingStoreIconState extends State<_PulsingStoreIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: widget.color.withValues(alpha: 0.2), width: 4),
        ),
        child: Icon(Icons.storefront_rounded, size: 64, color: widget.color),
      ),
    );
  }
}



