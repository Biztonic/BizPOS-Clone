import '../core/design/design_system.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import 'package:biztonic_pos/providers/auth_provider.dart';
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
      child: (dashboardProvider.activeStoreId == null && !dashboardProvider.isLoading) && 
             !(dashboardProvider.userProfile?.role == 'Super Admin' && dashboardProvider.isDeveloperMode)
          ? _buildStoreSelectionScreen(context, dashboardProvider)
          : widget.child,
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
              mainAxisSize: MainAxisSize.min,
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
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.stores.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final store = provider.stores[index];
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



