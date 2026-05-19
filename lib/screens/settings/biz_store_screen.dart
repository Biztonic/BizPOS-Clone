import '../../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:biztonic_pos/core/design/layouts/pos_scaffold.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import 'addon_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'subscription_reminder_dialog.dart';
import 'payment_qr_dialog.dart';
import 'package:fl_chart/fl_chart.dart';
class BizStoreScreen extends StatefulWidget {
  const BizStoreScreen({super.key});

  @override
  State<BizStoreScreen> createState() => _BizStoreScreenState();
}

class _BizStoreScreenState extends State<BizStoreScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic> _globalStats = {};
  late TabController _tabController;

  List<Map<String, dynamic>> get addonsMetadata => [
    // ... items stay same ...
    {
      'key': 'employee_management',
      'title': 'Employee Management',
      'description': 'Manage staff, roles, permissions, and attendance.',
      'icon': Icons.badge,
      'color': AppColors.primary,
      'version': '1.2',
      'size': '3.2 MB',
    },
    {
      'key': 'table_reservation',
      'title': 'Table Reservation',
      'description': 'Floor plan, table status, and reservation management.',
      'icon': Icons.table_restaurant,
      'color': AppColors.textSecondary(context),
      'version': '1.1',
      'size': '2.8 MB',
    },
    {
      'key': 'supplier_management',
      'title': 'Supplier Management',
      'description': 'Track suppliers, purchase orders, and incoming stock.',
      'icon': Icons.local_shipping,
      'color': AppColors.warning,
      'version': '1.0',
      'size': '2.1 MB',
    },
    {
      'key': 'kds_management',
      'title': 'Display Integration',
      'description': 'Digital kitchen order tickets and status tracking.',
      'icon': Icons.monitor,
      'color': AppColors.primary,
      'version': '1.0',
      'size': '1.8 MB',
    },
    {
      'key': 'franchise_management',
      'title': 'Franchise Management',
      'description': 'Manage multiple locations and franchise partners.',
      'icon': Icons.business_center,
      'color': AppColors.primaryLight,
      'version': '1.0',
      'size': '4.5 MB',
    },
    {
      'key': 'central_catalog',
      'title': 'Central Catalogue',
      'description': 'Access global products and scan menus via the standalone Catalogue app. Enables cloud import in Inventory.',
      'icon': Icons.inventory_2,
      'color': AppColors.warning,
      'version': '2.0',
      'size': '2.5 MB',
    },
    {
      'key': 'customer_management',
      'title': 'Customer Management',
      'description': 'Customer profiles, loyalty points, and purchase history.',
      'icon': Icons.people,
      'color': AppColors.primaryLight,
      'version': '1.1',
      'size': '3.0 MB',
    },
    {
      'key': 'data_center',
      'title': 'Data Center',
      'description': 'Advanced analytics, backups, and sync control.',
      'icon': Icons.storage,
      'color': AppColors.primaryLightGrey,
      'version': '1.0',
      'size': '1.5 MB',
    },
    {
      'key': 'integration_hub',
      'title': 'Integration Hub',
      'description': 'Connect with Swiggy, Zomato, Uber Eats & more.',
      'icon': Icons.hub,
      'color': AppColors.warning,
      'version': '1.0',
      'size': '3.8 MB',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      final isSuperAdmin = provider.userProfile?.role == 'Super Admin';
      
      final results = await Future.wait([
        provider.fetchSubscriptionHistory(),
        provider.fetchPendingSubscriptions(),
        if (isSuperAdmin) provider.fetchGlobalSubscriptionStats() else Future.value({}),
      ]);

      if (mounted) {
        setState(() { 
          _globalStats = results[2] as Map<String, dynamic>; 
          _isLoading = false; 
        });
        _checkAndShowReminder();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAddonDetail(Map<String, dynamic> addon, bool isInstalled, bool isLocked, dynamic price) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddonDetailScreen(
        addon: addon,
        isInstalled: isInstalled,
        isLocked: isLocked,
        price: price,
      ),
    ));
    if (mounted) setState(() {}); // Refresh on return
  }

  void _checkAndShowReminder() {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final days = provider.consolidatedStandardDays;
    
    // Show reminder if 3 days or less remaining, but not if already expired or if no Standard plan ever active
    if (days > 0 && days <= 3) {
      final lastShown = Hive.box('settings').get('last_reminder_shown');
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      if (lastShown != today) {
        _showExpiryReminder(days);
        Hive.box('settings').put('last_reminder_shown', today);
      }
    }
  }

  void _showExpiryReminder(int days) {
    showDialog(
      context: context,
      builder: (ctx) => SubscriptionReminderDialog(
        daysRemaining: days,
        onUpgrade: _upgradeFlow,
      ),
    );
  }

  void _upgradeFlow() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final adminConfig = provider.adminConfig;
    final monthlyPrice = (adminConfig['standardPlanMonthlyPrice'] ?? 499.0).toDouble();
    final yearlyPrice = (adminConfig['standardPlanYearlyPrice'] ?? 4999.0).toDouble();
    final upiId = (adminConfig['adminUpiId'] ?? 'biztonicautomation@okaxis').toString();

    if (upiId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'Upgrade currently unavailable. Please contact support.'))));
      return;
    }

    // Step 1: Select Plan
    final planSelection = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t(context, 'Select Subscription Plan')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPlanOption(ctx, "Monthly", monthlyPrice, Icons.calendar_month),
            const SizedBox(height: AppSpacing.md),
            _buildPlanOption(ctx, "Yearly", yearlyPrice, Icons.event_available, isBestValue: true),
          ],
        ),
      ),
    );

    if (planSelection == null) return;

    // Step 2: Select Addons
    final selectedAddons = await _showAddonSelectionDialog(planSelection['cycle']);
    if (selectedAddons == null) return; // User cancelled

    // Calculate Total
    double totalAmount = (planSelection['amount'] ?? 0.0).toDouble();
    final limits = provider.platformLimits; // Use provider data
    for (var key in selectedAddons) {
      final monthlyRate = (limits['rate_$key'] ?? 0).toDouble();
      final addonPrice = planSelection['cycle'] == 'Yearly' ? (monthlyRate * 10) : monthlyRate;
      totalAmount += addonPrice;
    }

    // Step 3: Payment QR
    if (mounted) {
      final done = await showDialog<bool>(
        context: context,
        builder: (ctx) => PaymentQrDialog(
          planType: 'Standard',
          billingCycle: planSelection['cycle'],
          amount: totalAmount,
          adminUpiId: upiId,
          selectedAddons: selectedAddons, // Pass addons to breakdown
          addonRates: provider.platformLimits, // Use provider data
        ),
      );

      if (done == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'Upgrade request submitted! Waiting for Admin approval.')), backgroundColor: AppColors.success));
        _loadData();
      }
    }
  }

  Future<List<String>?> _showAddonSelectionDialog(String billingCycle) async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final activeStore = provider.activeStore;
    final alreadyInstalled = Set<String>.from(activeStore?.addons ?? []);
    
    List<String> tempSelected = [];
    
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final limits = provider.platformLimits;
          double addonTotal = 0;
          for (var key in tempSelected) {
            final monthlyRate = (limits['rate_$key'] ?? 0).toDouble();
            addonTotal += billingCycle == 'Yearly' ? (monthlyRate * 10) : monthlyRate;
          }

          return AlertDialog(
            title: Text("Select Addons ($billingCycle)"),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(AppLocalizations.t(context, 'Enhance your store with these powerful modules.'), style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
                  const SizedBox(height: AppSpacing.md),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: addonsMetadata.length,
                      itemBuilder: (context, index) {
                        final addon = addonsMetadata[index];
                        final key = addon['key'] as String;
                        final limits = provider.platformLimits;
                        final isInstalled = alreadyInstalled.contains(key);
                        final isDisabled = provider.globalDisabledAddons.contains(key);
                        final monthlyPrice = (limits['rate_$key'] ?? 0).toDouble();
                        final displayPrice = billingCycle == 'Yearly' ? (monthlyPrice * 10) : monthlyPrice;
                        
                        if (isInstalled || isDisabled) return const SizedBox.shrink();

                        final isSelected = tempSelected.contains(key);
                        
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                tempSelected.add(key);
                              } else {
                                tempSelected.remove(key);
                              }
                            });
                          },
                          secondary: Icon(addon['icon'] as IconData, color: addon['color'] as Color),
                          title: Text(addon['title'] as String),
                          subtitle: Text("₹$displayPrice / ${billingCycle.toLowerCase()}"),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppLocalizations.t(context, 'Addons Total:'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("₹${addonTotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t(context, 'SKIP / CANCEL'))),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, tempSelected),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.surfaceLight),
                child: Text(AppLocalizations.t(context, 'CONTINUE TO PAYMENT')),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildPlanOption(BuildContext context, String cycle, double price, IconData icon, {bool isBestValue = false}) {
    return InkWell(
      onTap: () => Navigator.pop(context, {'cycle': cycle, 'amount': price}),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: isBestValue ? AppColors.warning : AppColors.textSecondary(context)),
          borderRadius: BorderRadius.zero,
          color: isBestValue ? AppColors.warning.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isBestValue ? AppColors.warning : AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cycle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("₹$price / ${cycle.toLowerCase()}", style: TextStyle(color: AppColors.textSecondary(context))),
                ],
              ),
            ),
            if (isBestValue)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: const BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.zero),
                child: Text(AppLocalizations.t(context, 'BEST VALUE'), style: const TextStyle(color: AppColors.surfaceLight, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final activeStore = provider.activeStore;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (activeStore == null) return Scaffold(body: Center(child: Text(AppLocalizations.t(context, 'No Store Selected'))));

    final currentAddons = Set<String>.from(activeStore.addons);
    final plan = activeStore.subscriptionPlan;
    final isStandard = plan == 'Standard';
    final isSuperAdmin = provider.userProfile?.role == 'Super Admin';
    
    // Check for pending request
    final hasPending = provider.pendingSubscriptions.any((r) => r.storeId == activeStore.id);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/dashboard');
        }
      },
      child: PosScaffold(
        title: AppLocalizations.t(context, 'BizStore'),
        mainContent: Column(
          children: [
            Container(
              color: AppColors.primary,
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: "Modules", icon: Icon(Icons.apps)),
                  Tab(text: "Subscription", icon: Icon(Icons.account_balance_wallet)),
                ],
                indicatorColor: AppColors.surfaceLight,
                labelColor: AppColors.surfaceLight,
                unselectedLabelColor: AppColors.textSecondaryDark,
              ),
            ),
            Expanded(
              child: _isLoading 
                  ? const Center(child: CircularProgressIndicator()) 
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildModulesTab(provider, activeStore, currentAddons, isStandard, isSuperAdmin, isDark, hasPending),
                        isSuperAdmin 
                          ? _buildSuperAdminOverview(provider, isDark)
                          : _buildSubscriptionTab(provider, activeStore, isStandard, hasPending, isDark),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModulesTab(DashboardProvider provider, dynamic activeStore,
      Set<String> currentAddons, bool isStandard, bool isSuperAdmin, bool isDark,
      bool hasPending) {
    final visibleAddons = addonsMetadata.where((a) {
      final key = a['key'] as String;
      return !provider.globalDisabledAddons.contains(key);
    }).toList();

    return CustomScrollView(
      slivers: [
        // Plan Header
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isStandard
                  ? (isDark
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.success)
                  : (isDark
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.primary),
              border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              children: [
                Icon(isStandard ? Icons.verified : Icons.stars,
                    color: isStandard ? AppColors.success : AppColors.primary,
                    size: 28),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Plan: ${activeStore.subscriptionPlan}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        isStandard
                            ? "All modules unlocked"
                            : (isSuperAdmin
                                ? "Super Admin bypass"
                                : "Upgrade to unlock full features"),
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color),
                      ),
                    ],
                  ),
                ),
                if (!isSuperAdmin)
                  ElevatedButton(
                    onPressed: hasPending ? null : _upgradeFlow,
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isStandard ? AppColors.success : AppColors.primary,
                        foregroundColor: AppColors.surfaceLight),
                    child: Text(
                        hasPending ? "PENDING..." : (isStandard ? "BUY COUPON" : "UPGRADE")),
                  )
              ],
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.md),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent:
                  MediaQuery.of(context).size.width < 500 ? 400 : 300,
              childAspectRatio:
                  MediaQuery.of(context).size.width < 500 ? 3.5 : 2.4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final addon = visibleAddons[index];
                final key = addon['key'] as String;
                final price = provider.platformLimits['rate_$key'] ?? 0;
                return _buildCompactCard(
                  addon: addon,
                  isInstalled: currentAddons.contains(key),
                  isLocked: !isStandard &&
                      !isSuperAdmin &&
                      !activeStore.purchasedAddons.contains(key),
                  addonColor: addon['color'] as Color,
                  isDark: isDark,
                  price: price,
                  isPending: provider.pendingSubscriptions
                      .any((r) => r.selectedAddons.contains(key)),
                  isSuperAdmin: isSuperAdmin,
                  isEnabled: true, // Always true since we filtered out disabled ones
                  remainingDays: provider.getAddonDays(key),
                  onToggle: (val) async {
                    try {
                      await provider.toggleGlobalAddon(key, val);
                      _loadData();
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text("Error: $e")));
                    }
                  },
                );
              },
              childCount: visibleAddons.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionTab(DashboardProvider provider, dynamic activeStore,
      bool isStandard, bool hasPending, bool isDark) {
    final historyItems =
        provider.subscriptionHistory.where((s) => s.status != 'QUEUED').toList();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.md),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Plan Status Card
                Card(
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxs),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(AppLocalizations.t(context, 'Active Plan'),
                                    style: TextStyle(
                                        color: AppColors.textSecondary(context),
                                        fontSize: 13)),
                                Text(
                                  activeStore.subscriptionPlan,
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: isStandard
                                          ? AppColors.success
                                          : AppColors.primary),
                                ),
                              ],
                            ),
                            _buildPlanBadge(isStandard),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (isStandard) _buildRemainingDaysInfo(provider, isDark),
                        const SizedBox(height: AppSpacing.md),
                        const Divider(),
                        const SizedBox(height: AppSpacing.md),
                        if (hasPending)
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.zero),
                            child: Row(
                              children: [
                                const Icon(Icons.hourglass_empty,
                                    color: AppColors.warning, size: 20),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                    child: Text(AppLocalizations.t(context, 'Upgrade Request Pending Approval'),
                                        style: const TextStyle(
                                            color: AppColors.warning,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13))),
                              ],
                            ),
                          )
                        else if (!isStandard)
                          SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                  onPressed: _upgradeFlow,
                                  child: Text(AppLocalizations.t(context, 'UPGRADE NOW'))))
                        else ...[
                          Text(AppLocalizations.t(context, 'Enjoy full standard features & cloud sync.'),
                              style: TextStyle(
                                  color: AppColors.textSecondary(context),
                                  fontStyle: FontStyle.italic)),
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _upgradeFlow,
                              icon: const Icon(Icons.add_shopping_cart, size: 18),
                              label: Text(AppLocalizations.t(context, 'PURCHASE ADVANCE COUPON')),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                // Auto-activate Toggle
                Card(
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero),
                  child: SwitchListTile(
                    secondary: Icon(Icons.auto_awesome,
                        color: activeStore.autoActivateSubscription
                            ? AppColors.warning
                            : AppColors.textSecondary(context)),
                    title: Text(AppLocalizations.t(context, 'Auto-activate next subscription'),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(AppLocalizations.t(context, 'Automatically activate queued coupons when the current plan expires.'),
                        style: const TextStyle(fontSize: 12)),
                    value: activeStore.autoActivateSubscription,
                    onChanged: (val) => provider.toggleAutoActivateSub(val),
                    activeColor: AppColors.warning,
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
                Text(AppLocalizations.t(context, 'Ready Coupons (In Queue)'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),

        // Queued Subs Sliver
        _buildQueuedSubsSliver(provider, isDark),

        if (provider.rejectedSubscriptions.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
              child: Text(AppLocalizations.t(context, 'Rejected Requests'),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverToBoxAdapter(
              child: _buildRejectedRequests(provider, isDark),
            ),
          ),
        ],

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
            child: Text(AppLocalizations.t(context, 'Purchase History'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),

        if (historyItems.isEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(AppLocalizations.t(context, 'No subscription history found')),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverList.separated(
              itemCount: historyItems.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (ctx, idx) {
                final sub = historyItems[idx];
                final df = DateFormat('dd MMM yyyy');
                return ListTile(
                  tileColor: isDark
                      ? AppColors.surfaceLight.withValues(alpha: 0.05)
                      : AppColors.textSecondary(context),
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero),
                  leading: CircleAvatar(
                    backgroundColor: sub.isActive
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.textSecondary(context).withValues(alpha: 0.1),
                    child: Icon(Icons.history,
                        color: sub.isActive
                            ? AppColors.success
                            : AppColors.textSecondary(context)),
                  ),
                  title: Text("${sub.planName} - ${sub.billingCycle}",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      "Valid: ${df.format(sub.startDate)} - ${df.format(sub.endDate)}"),
                  trailing: Text(
                    sub.isActive ? "ACTIVE" : "EXPIRED",
                    style: TextStyle(
                        color:
                            sub.isActive ? AppColors.success : AppColors.textSecondary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                );
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xs)),
      ],
    );
  }

  Widget _buildCompactCard({
    required Map<String, dynamic> addon,
    required bool isInstalled,
    required bool isLocked,
    required Color addonColor,
    required bool isDark,
    required dynamic price,
    bool isPending = false,
    bool isSuperAdmin = false,
    bool isEnabled = true,
    int remainingDays = 0,
    Function(bool)? onToggle,
  }) {
    final hasValidity = remainingDays > 0;
    
    return GestureDetector(
      onTap: isSuperAdmin ? null : () => _openAddonDetail(addon, isInstalled, isLocked, price),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isLocked ? 0.5 : 1.0,
        child: Card(
          elevation: isInstalled ? 2 : 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: isInstalled
              ? const BorderSide(color: AppColors.success, width: 1.5)
              : BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: addonColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Icon(addon['icon'] as IconData, color: addonColor, size: 24),
                    ),
                    if (hasValidity)
                      Positioned(
                        right: -2, top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                          child: const Icon(Icons.check, color: AppColors.surfaceLight, size: 8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              addon['title'] as String,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasValidity)
                            Container(
                              margin: const EdgeInsets.only(left: AppSpacing.xs),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: AppSpacing.xxs),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.zero,
                              ),
                              child: Text(
                                "$remainingDays Days",
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.success),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        addon['description'] as String,
                        style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSuperAdmin && onToggle != null)
                   Switch(
                     value: isEnabled, 
                     onChanged: onToggle,
                     activeColor: AppColors.success,
                     // scale: 0.7, // Only available in newer flutter versions or via Transform
                   )
                else if (isInstalled)
                  const Icon(Icons.check_circle, color: AppColors.success, size: 22)
                else if (isLocked)
                  Icon(Icons.lock, color: AppColors.textSecondary(context), size: 20)
                else if (isPending)
                  Text(AppLocalizations.t(context, 'PENDING'), style: const TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold))
                else
                  Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanBadge(bool isStandard) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isStandard ? AppColors.success.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        isStandard ? "UNLIMITED" : "BASIC", 
        style: TextStyle(fontWeight: FontWeight.bold, color: isStandard ? AppColors.success : AppColors.primary, fontSize: 12),
      ),
    );
  }

  Widget _buildRemainingDaysInfo(DashboardProvider provider, bool isDark) {
    final days = provider.consolidatedStandardDays;
    if (days <= 0 && provider.activeStore?.subscriptionPlan == 'Basic') return const SizedBox.shrink();

    // Get the final expiry date for display
    final activeItems = provider.subscriptionHistory.where((h) => h.isActive).toList();
    if (activeItems.isEmpty && days <= 0) return const SizedBox.shrink();
    
    DateTime maxEnd = DateTime.now();
    for (var h in activeItems) {
      if (h.endDate.isAfter(maxEnd)) maxEnd = h.endDate;
    }
    
    Color textColor = AppColors.success;
    Color bgColor = AppColors.success.withValues(alpha: 0.1);
    IconData icon = Icons.timer;

    if (days <= 0) {
      textColor = AppColors.error;
      bgColor = AppColors.error.withValues(alpha: 0.1);
      icon = Icons.error_outline;
    } else if (days < 3) {
      textColor = AppColors.warning;
      bgColor = AppColors.warning.withValues(alpha: 0.1);
      icon = Icons.warning_amber;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Plan Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.zero,
          ),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 28),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      days <= 0 ? "Expired" : "Total: $days Days Remaining",
                      style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16),
                    ),
                    if (days > 0)
                      Text(
                        "Ultimate expiry: ${DateFormat('dd MMM yyyy').format(maxEnd)}",
                        style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 13),
                      ),
                  ],
                ),
              ),
              if (days < 3 && days > 0)
                const Icon(Icons.priority_high, color: AppColors.warning, size: 20),
            ],
          ),
        ),

        // Prominent Addon Cards
        Builder(
          builder: (context) {
            final purchasedKeys = provider.activeStore?.purchasedAddons ?? [];
            if (purchasedKeys.isEmpty) return const SizedBox.shrink();
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: purchasedKeys.map((key) {
                final addonDays = provider.getAddonDays(key);
                if (addonDays <= 0) return const SizedBox.shrink();
                
                final metadata = addonsMetadata.firstWhere((a) => a['key'] == key, orElse: () => {'title': key});
                final addonColor = metadata['color'] as Color? ?? AppColors.primary;
                
                return Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: addonColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.zero,
                    border: Border.all(color: addonColor.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(metadata['icon'] as IconData? ?? Icons.extension, color: addonColor, size: 24),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              metadata['title'] as String? ?? key,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(AppLocalizations.t(context, 'Module active'), style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("$addonDays", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: addonColor)),
                          Text(AppLocalizations.t(context, 'days left'), style: TextStyle(fontSize: 10, color: addonColor, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }
        ),
      ],
    );
  }

  Widget _buildQueuedSubsSliver(DashboardProvider provider, bool isDark) {
    final queued =
        provider.subscriptionHistory.where((s) => s.status == 'QUEUED').toList();
    if (queued.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          width: double.infinity,
          decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceLight.withValues(alpha: 0.03)
                  : AppColors.textSecondary(context),
              borderRadius: BorderRadius.zero),
          child: Text(AppLocalizations.t(context, 'No advance subscriptions in queue.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 13,
                  fontStyle: FontStyle.italic)),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      sliver: SliverList.separated(
        itemCount: queued.length,
        separatorBuilder: (ctx, idx) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (ctx, idx) {
          final sub = queued[idx];
          return ListTile(
            tileColor: isDark
                ? AppColors.warning.withValues(alpha: 0.05)
                : AppColors.warning,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide(
                    color: AppColors.warning.withValues(alpha: 0.2))),
            leading: const CircleAvatar(
                backgroundColor: AppColors.warning,
                child: Icon(Icons.confirmation_num, color: AppColors.surfaceLight)),
            title: Text("${sub.planName} Coupon (${sub.billingCycle})",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(AppLocalizations.t(context, 'Status: QUEUED for later use')),
            trailing: ElevatedButton(
              onPressed: () => provider.activateSubscriptionCoupon(sub.id),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: AppColors.surfaceLight),
              child: Text(AppLocalizations.t(context, 'ACTIVATE NOW')),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuperAdminOverview(DashboardProvider provider, bool isDark) {
    if (_globalStats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final planDist =
        Map<String, dynamic>.from(_globalStats['planDistribution'] ?? {});
    final totalValue = (_globalStats['totalValue'] ?? 0.0).toDouble();
    final activeSubs = _globalStats['activeSubs'] ?? 0;
    final totalStores = _globalStats['totalStores'] ?? 0;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.t(context, 'Global Subscription Overview'),
                    style:
                        const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.lg),

                // KPI CARDS
                Row(
                  children: [
                    _buildStatCard("Total Stores", totalStores.toString(),
                        Icons.store, AppColors.primaryLight, isDark),
                    const SizedBox(width: AppSpacing.md),
                    _buildStatCard("Active Subs", activeSubs.toString(),
                        Icons.verified, AppColors.success, isDark),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _buildStatCard(
                    "Total Revenue",
                    "₹${totalValue.toStringAsFixed(2)}",
                    Icons.payments,
                    AppColors.warning,
                    isDark,
                    fullWidth: true),

                const SizedBox(height: AppSpacing.xl),

                // CHARTS SECTION
                LayoutBuilder(
                  builder: (context, constraints) {
                    bool narrow = constraints.maxWidth < 600;
                    return narrow
                        ? Column(
                            children: [
                              _buildPlanDistributionCard(planDist, isDark),
                              const SizedBox(height: AppSpacing.md),
                              _buildTrendCard(isDark),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: _buildPlanDistributionCard(
                                      planDist, isDark)),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: _buildTrendCard(isDark)),
                            ],
                          );
                  },
                ),

                const SizedBox(height: AppSpacing.xl),
                Text(AppLocalizations.t(context, 'Search & Quick Activity'),
                    style:
                        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
        _buildGlobalHistorySliver(isDark),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xs)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDark, {bool fullWidth = false}) {
    final widget = Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D44) : AppColors.surfaceLight,
        borderRadius: BorderRadius.zero,
        boxShadow: [BoxShadow(color: AppColors.textPrimaryLight.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 10)],
        border: Border.all(color: isDark ? Colors.white10 : AppColors.textSecondary(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.zero),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: widget) : Expanded(child: widget);
  }

  Widget _buildPlanDistributionCard(Map<String, dynamic> dist, bool isDark) {
    final List<PieChartSectionData> sections = [];
    final colors = [AppColors.primaryLight, AppColors.success, AppColors.warning, AppColors.primaryLight, AppColors.error, AppColors.primary];
    int colorIdx = 0;

    dist.forEach((plan, countValue) {
      sections.add(PieChartSectionData(
        color: colors[colorIdx % colors.length],
        value: countValue.toDouble(),
        title: '$countValue',
        radius: 40,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.surfaceLight),
      ));
      colorIdx++;
    });

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      height: 320,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D44) : AppColors.surfaceLight,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: isDark ? Colors.white10 : AppColors.textSecondary(context)),
      ),
      child: Column(
        children: [
          Text(AppLocalizations.t(context, 'Plan Distribution'), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.xxs),
          Expanded(
            child: sections.isEmpty 
              ? Center(child: Text(AppLocalizations.t(context, 'No data')))
              : PieChart(PieChartData(sections: sections, centerSpaceRadius: 40, sectionsSpace: 2)),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 12, runSpacing: 8,
            children: dist.keys.map((k) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[dist.keys.toList().indexOf(k) % colors.length], shape: BoxShape.circle)),
                const SizedBox(width: AppSpacing.sm),
                Text(k, style: const TextStyle(fontSize: 11)),
              ],
            )).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildTrendCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      height: 320,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D44) : AppColors.surfaceLight,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: isDark ? Colors.white10 : AppColors.textSecondary(context)),
      ),
      child: Column(
        children: [
          Text(AppLocalizations.t(context, 'Subscription Revenue Trends'), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 2), FlSpot(1, 4), FlSpot(2, 3), FlSpot(3, 7),
                      FlSpot(4, 5), FlSpot(5, 8), FlSpot(6, 6),
                    ],
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 4,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(AppLocalizations.t(context, 'Weekly cumulative growth metrics'), style: TextStyle(color: AppColors.textSecondary(context), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildGlobalHistorySliver(bool isDark) {
    final history = _globalStats['recentHistory'] as List? ?? [];

    if (history.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceLight.withValues(alpha: 0.03)
                : AppColors.textSecondary(context),
            borderRadius: BorderRadius.zero,
            border: Border.all(
                color: isDark ? Colors.white10 : AppColors.textSecondary(context)),
          ),
          child: Column(
            children: [
              Icon(Icons.query_stats,
                  color: AppColors.textSecondary(context), size: 32),
              const SizedBox(height: AppSpacing.md),
              Text(AppLocalizations.t(context, 'No recent subscription activity found.'),
                  style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 13,
                      fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      sliver: SliverList.separated(
        itemCount: history.length,
        separatorBuilder: (ctx, i) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final item = history[i];
          final createdAt = item['createdAt'];
          String dateStr = 'Recently';
          if (createdAt is Timestamp) {
            dateStr = DateFormat('dd MMM, hh:mm a').format(createdAt.toDate());
          }

          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.receipt_long,
                  color: AppColors.primary, size: 20),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Store: ${item['storeId'] ?? 'N/A'}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text("₹${item['amount'] ?? 0}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.success)),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xs),
                Text(
                    "${item['plan'] ?? 'Standard'} - ${item['billingCycle'] ?? 'Monthly'}",
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: [
                    Text(dateStr,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context))),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: AppSpacing.xxs),
                      decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.zero),
                      child: Text(
                          item['status']?.toString().toUpperCase() ?? 'ACTIVE',
                          style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.success,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  Widget _buildRejectedRequests(DashboardProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.error.withValues(alpha: 0.05) : AppColors.error,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: isDark ? AppColors.error.withValues(alpha: 0.1) : AppColors.error),
      ),
      child: Column(
        children: [
          const Icon(Icons.report_problem, color: AppColors.error, size: 32),
          const SizedBox(height: AppSpacing.md),
          Text(AppLocalizations.t(context, 'No subscription rejection records found.'), style: const TextStyle(color: AppColors.error, fontSize: 13)),
        ],
      ),
    );
  }
}

