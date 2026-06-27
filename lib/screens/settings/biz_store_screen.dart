import 'dart:math';
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
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'subscription_reminder_dialog.dart';
import 'payment_qr_dialog.dart';
import 'package:fl_chart/fl_chart.dart';
import 'addon_detail_screen.dart';
class BizStoreScreen extends StatefulWidget {
  const BizStoreScreen({super.key});

  @override
  State<BizStoreScreen> createState() => _BizStoreScreenState();
}

class _BizStoreScreenState extends State<BizStoreScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic> _globalStats = {};
  late TabController _tabController;

  List<Map<String, dynamic>> get addonsMetadata => AddonDetailScreen.addonsMetadata;

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
      
      final results = await Future.wait<dynamic>([
        provider.fetchSubscriptionHistory(),
        provider.fetchPendingSubscriptions(),
        if (isSuperAdmin) provider.fetchGlobalSubscriptionStats() else Future.value({}),
      ]);

      if (mounted) {
        setState(() { 
          _globalStats = results[2] is Map ? Map<String, dynamic>.from(results[2] as Map) : {}; 
          _isLoading = false; 
        });
        _checkAndShowReminder();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAddonDetail(Map<String, dynamic> addon, bool isInstalled, bool isLocked, dynamic price) async {
    await context.push('/biz-store/addon-detail?key=${addon['key']}');
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
    final planSelection = await showDialog<Map>(
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
    if (!mounted) return;

    final cycle = (planSelection['cycle'] as String?) ?? 'Monthly';
    final amount = (planSelection['amount'] ?? 0.0).toDouble();

    // Step 2: Select Addons
    final selectedAddons = await _showAddonSelectionDialog(cycle);
    if (!mounted) return;
    if (selectedAddons == null) return; // User cancelled

    // Calculate Total
    double totalAmount = amount;
    final limits = provider.platformLimits; // Use provider data
    for (var key in selectedAddons) {
      final monthlyRate = (limits['rate_$key'] ?? 0).toDouble();
      final addonPrice = cycle == 'Yearly' ? (monthlyRate * 10) : monthlyRate;
      totalAmount += addonPrice;
    }

    // Step 3: Payment QR
    if (mounted) {
      final done = await showDialog<bool?>(
        context: context,
        builder: (ctx) => PaymentQrDialog(
          planType: 'Standard',
          billingCycle: cycle,
          amount: totalAmount,
          adminUpiId: upiId,
          selectedAddons: selectedAddons, // Pass addons to breakdown
          addonRates: provider.platformLimits, // Use provider data
        ),
      );

      if (!mounted) return;
      if (done == true) {
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
    
    return showDialog<List<String>?>(
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
      onTap: () => Navigator.pop(context, <String, dynamic>{'cycle': cycle, 'amount': price}),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: isBestValue ? AppColors.warning : AppColors.border(context)),
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
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: isDark ? Colors.white : AppColors.primary,
                unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: const [
                  Tab(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.apps, size: 18),
                        SizedBox(width: 8),
                        Text("Modules"),
                      ],
                    ),
                  ),
                  Tab(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet, size: 18),
                        SizedBox(width: 8),
                        Text("Subscription"),
                      ],
                    ),
                  ),
                ],
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

    // Grouping helper
    List<Map<String, dynamic>> getByCategory(String category) {
      return visibleAddons.where((a) => a['category'] == category).toList();
    }

    final essentials = getByCategory('Essentials');
    final operations = getByCategory('Operations');
    final scaleAndCloud = getByCategory('Scale & Cloud');

    return CustomScrollView(
      slivers: [
        // Modern Plan Header
        SliverToBoxAdapter(
          child: _buildModernPlanHeader(activeStore, isStandard, isSuperAdmin, isDark, hasPending),
        ),

        // Featured Hero Banner
        SliverToBoxAdapter(
          child: _buildFeaturedHero(context, isDark),
        ),

        // Category 1: Essentials
        if (essentials.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _buildCategoryHeader(
              title: "Essentials for POS",
              subtitle: "Core features to run your store, manage staff, and customers",
              isDark: isDark,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: MediaQuery.of(context).size.width < 500 ? 400 : 350,
                childAspectRatio: MediaQuery.of(context).size.width < 500 ? 3.5 : 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final addon = essentials[index];
                  return _buildAddonCard(addon, provider, activeStore, currentAddons, isStandard, isSuperAdmin, isDark);
                },
                childCount: essentials.length,
              ),
            ),
          ),
        ],

        // Category 2: Operations
        if (operations.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _buildCategoryHeader(
              title: "Operations & Kitchen",
              subtitle: "Optimize table services, orders, and supplier pipelines",
              isDark: isDark,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: MediaQuery.of(context).size.width < 500 ? 400 : 350,
                childAspectRatio: MediaQuery.of(context).size.width < 500 ? 3.5 : 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final addon = operations[index];
                  return _buildAddonCard(addon, provider, activeStore, currentAddons, isStandard, isSuperAdmin, isDark);
                },
                childCount: operations.length,
              ),
            ),
          ),
        ],

        // Category 3: Scale & Cloud
        if (scaleAndCloud.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _buildCategoryHeader(
              title: "Scale & Cloud Integrations",
              subtitle: "Sync across franchises, manage central stocks, and connect aggregator APIs",
              isDark: isDark,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: MediaQuery.of(context).size.width < 500 ? 400 : 350,
                childAspectRatio: MediaQuery.of(context).size.width < 500 ? 3.5 : 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final addon = scaleAndCloud[index];
                  return _buildAddonCard(addon, provider, activeStore, currentAddons, isStandard, isSuperAdmin, isDark);
                },
                childCount: scaleAndCloud.length,
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    );
  }

  Widget _buildCategoryHeader({
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Icon(
                Icons.arrow_forward,
                size: 16,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedHero(BuildContext context, bool isDark) {
    final addon = addonsMetadata.firstWhere((a) => a['key'] == 'employee_management');
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final activeStore = provider.activeStore;
    final isInstalled = activeStore?.addons.contains('employee_management') ?? false;
    final isLocked = !(activeStore?.subscriptionPlan == 'Standard') &&
        !(provider.userProfile?.role == 'Super Admin') &&
        !(activeStore?.purchasedAddons.contains('employee_management') ?? false);
    final price = provider.platformLimits['rate_employee_management'] ?? 0;
    
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark 
            ? [const Color(0xFF4F46E5), const Color(0xFF312E81)] 
            : [const Color(0xFF6366F1), const Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(isDark ? 0.3 : 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              bottom: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 40,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "FEATURED MODULE",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Employee Management",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Streamline your shift tracking, payroll, attendance, and role permissions.",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            const Text("4.8", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(width: 12),
                            const Text("3.2 MB", style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(width: 12),
                            const Text("v1.2", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                          ),
                          child: const Icon(Icons.badge, color: Colors.white, size: 36),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => _openAddonDetail(addon, isInstalled, isLocked, price),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF4F46E5),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            isInstalled ? "Open" : "Details",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernPlanHeader(dynamic activeStore, bool isStandard, bool isSuperAdmin, bool isDark, bool hasPending) {
    final statusColor = isStandard ? AppColors.success : AppColors.primary;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isStandard ? Icons.verified : Icons.stars,
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Store Plan: ${activeStore.subscriptionPlan}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isStandard
                      ? "All premium modules are unlocked."
                      : (isSuperAdmin
                          ? "Super Admin Bypass active."
                          : "Upgrade plan to unlock premium POS modules."),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (!isSuperAdmin)
            ElevatedButton(
              onPressed: hasPending ? null : _upgradeFlow,
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                hasPending ? "PENDING..." : (isStandard ? "BUY COUPON" : "UPGRADE"),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildAddonCard(
    Map<String, dynamic> addon,
    DashboardProvider provider,
    dynamic activeStore,
    Set<String> currentAddons,
    bool isStandard,
    bool isSuperAdmin,
    bool isDark,
  ) {
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
      isEnabled: true,
      remainingDays: provider.getAddonDays(key),
      onToggle: (val) async {
        try {
          await provider.toggleGlobalAddon(key, val);
          _loadData();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      },
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
                // Premium Visa-like Play Pass Card
                _buildPremiumPlayPassCard(provider, activeStore, isStandard, hasPending, isDark),
                const SizedBox(height: AppSpacing.lg),

                // Upgrade Actions
                if (hasPending)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_empty, color: AppColors.warning, size: 20),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            AppLocalizations.t(context, 'Upgrade Request Pending Approval'),
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!isStandard)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _upgradeFlow,
                      icon: const Icon(Icons.flash_on, size: 20),
                      label: Text(
                        AppLocalizations.t(context, 'UPGRADE TO STANDARD'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 1,
                      ),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      AppLocalizations.t(context, 'Enjoy full standard features & cloud sync.'),
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _upgradeFlow,
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: Text(
                        AppLocalizations.t(context, 'PURCHASE ADVANCE COUPON'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),
                // Auto-activate Toggle
                Card(
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (activeStore.autoActivateSubscription ? AppColors.warning : AppColors.textSecondary(context)).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: activeStore.autoActivateSubscription
                            ? AppColors.warning
                            : AppColors.textSecondary(context),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      AppLocalizations.t(context, 'Auto-activate next subscription'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      AppLocalizations.t(context, 'Automatically activate queued coupons when the current plan expires.'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: activeStore.autoActivateSubscription,
                    onChanged: (val) => provider.toggleAutoActivateSub(val),
                    activeColor: AppColors.warning,
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
                Text(
                  AppLocalizations.t(context, 'Ready Coupons (In Queue)'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
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
              child: Text(
                AppLocalizations.t(context, 'Rejected Requests'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
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
            child: Text(
              AppLocalizations.t(context, 'Purchase History'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        if (historyItems.isEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  AppLocalizations.t(context, 'No subscription history found'),
                  style: TextStyle(color: AppColors.textSecondary(context), fontStyle: FontStyle.italic),
                ),
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
                final statusColor = sub.isActive ? AppColors.success : AppColors.textSecondary(context);
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : AppColors.surface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.border(context),
                      width: 0.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: statusColor.withValues(alpha: 0.1),
                        child: Icon(Icons.history, color: statusColor, size: 20),
                      ),
                      title: Text(
                        "${sub.planName} - ${sub.billingCycle}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      subtitle: Text(
                        "Valid: ${df.format(sub.startDate)} - ${df.format(sub.endDate)}",
                        style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          sub.isActive ? "ACTIVE" : "EXPIRED",
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xs)),
      ],
    );
  }

  Widget _buildPremiumPlayPassCard(DashboardProvider provider, dynamic activeStore,
      bool isStandard, bool hasPending, bool isDark) {
    return _AnimatedGoldPlayPassCard(
      provider: provider,
      activeStore: activeStore,
      isStandard: isStandard,
      hasPending: hasPending,
      isDark: isDark,
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
    final rating = addon['rating'] ?? '4.7';
    final size = addon['size'] ?? '2.5 MB';

    return GestureDetector(
      onTap: isSuperAdmin ? null : () => _openAddonDetail(addon, isInstalled, isLocked, price),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isLocked ? 0.6 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isInstalled
                  ? AppColors.success.withValues(alpha: 0.5)
                  : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
              width: isInstalled ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Play Store Styled App Icon Container
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            addonColor.withValues(alpha: 0.9),
                            addonColor.withValues(alpha: 0.6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: addonColor.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        addon['icon'] as IconData? ?? Icons.extension,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    if (hasValidity)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                // Text Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        addon['title'] as String? ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      // Play Store style details row: Rating, Size, Expiry
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber[700], size: 12),
                          const SizedBox(width: 2),
                          Text(
                            rating.toString(),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "•",
                            style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white30 : Colors.black26),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            size.toString(),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          if (hasValidity) ...[
                            const SizedBox(width: 6),
                            Text(
                              "•",
                              style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white30 : Colors.black26),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "$remainingDays d",
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        addon['description'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action Status Badge
                if (isSuperAdmin && onToggle != null)
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: isEnabled,
                      onChanged: onToggle,
                      activeColor: AppColors.success,
                    ),
                  )
                else if (isInstalled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Installed",
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  )
                else if (isLocked)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      color: isDark ? Colors.white38 : Colors.black38,
                      size: 16,
                    ),
                  )
                else if (isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppLocalizations.t(context, 'PENDING'),
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
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
            color: isDark ? const Color(0xFF1E293B) : AppColors.surfaceVariant(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.border(context), width: 0.5),
          ),
          child: Text(
            AppLocalizations.t(context, 'No advance subscriptions in queue.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
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
          return Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B)
                  : AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppColors.warning.withValues(alpha: 0.2)
                    : AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                  child: const Icon(Icons.confirmation_num, color: AppColors.warning, size: 20),
                ),
                title: Text(
                  "${sub.planName} Coupon (${sub.billingCycle})",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  AppLocalizations.t(context, 'Status: QUEUED for later use'),
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                ),
                trailing: ElevatedButton(
                  onPressed: () => provider.activateSubscriptionCoupon(sub.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: Text(
                    AppLocalizations.t(context, 'ACTIVATE NOW'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ),
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
                Text(
                  AppLocalizations.t(context, 'Global Subscription Overview'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
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
                                child: _buildPlanDistributionCard(planDist, isDark),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: _buildTrendCard(isDark)),
                            ],
                          );
                  },
                ),

                const SizedBox(height: AppSpacing.xl),
                Text(
                  AppLocalizations.t(context, 'Search & Quick Activity'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: widget) : Expanded(child: widget);
  }

  Widget _buildPlanDistributionCard(Map<String, dynamic> dist, bool isDark) {
    final List<PieChartSectionData> sections = [];
    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFEF4444), // Red
      const Color(0xFF8B5CF6), // Purple
    ];
    int colorIdx = 0;

    dist.forEach((plan, countValue) {
      sections.add(PieChartSectionData(
        color: colors[colorIdx % colors.length],
        value: countValue.toDouble(),
        title: '$countValue',
        radius: 36,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      colorIdx++;
    });

    return Container(
      padding: const EdgeInsets.all(16),
      height: 320,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.t(context, 'Plan Distribution'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: sections.isEmpty 
              ? Center(
                  child: Text(
                    AppLocalizations.t(context, 'No data'),
                    style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                  ),
                )
              : PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 50,
                    sectionsSpace: 3,
                  ),
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: dist.keys.map((k) {
              final idx = dist.keys.toList().indexOf(k);
              final color = colors[idx % colors.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    k,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              );
            }).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildTrendCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 320,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.t(context, 'Subscription Revenue Trends'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
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
                    color: const Color(0xFF6366F1),
                    barWidth: 4,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.t(context, 'Weekly cumulative growth metrics'),
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black45,
              fontSize: 11,
            ),
          ),
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
            color: isDark ? const Color(0xFF1E293B) : AppColors.surfaceVariant(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.border(context),
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.query_stats,
                color: isDark ? Colors.white38 : AppColors.textSecondary(context),
                size: 32,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppLocalizations.t(context, 'No recent subscription activity found.'),
                style: TextStyle(
                  color: isDark ? Colors.white60 : AppColors.textSecondary(context),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      sliver: SliverList.separated(
        itemCount: history.length,
        separatorBuilder: (ctx, idx) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (ctx, i) {
          final item = history[i];
          final createdAt = item['createdAt'];
          String dateStr = 'Recently';
          if (createdAt is Timestamp) {
            dateStr = DateFormat('dd MMM, hh:mm a').format(createdAt.toDate());
          }

          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  child: const Icon(Icons.receipt_long, color: Color(0xFF6366F1), size: 20),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Store: ${item['storeId'] ?? 'N/A'}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      "₹${item['amount'] ?? 0}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      "${item['plan'] ?? 'Standard'} - ${item['billingCycle'] ?? 'Monthly'}",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : AppColors.textSecondary(context),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item['status']?.toString().toUpperCase() ?? 'ACTIVE',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
        color: isDark ? const Color(0xFF1E293B) : AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.report_problem, color: AppColors.error, size: 32),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppLocalizations.t(context, 'No subscription rejection records found.'),
            style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Animated gold wave subscription card with premium glow effect.
class _AnimatedGoldPlayPassCard extends StatefulWidget {
  final DashboardProvider provider;
  final dynamic activeStore;
  final bool isStandard;
  final bool hasPending;
  final bool isDark;

  const _AnimatedGoldPlayPassCard({
    required this.provider,
    required this.activeStore,
    required this.isStandard,
    required this.hasPending,
    required this.isDark,
  });

  @override
  State<_AnimatedGoldPlayPassCard> createState() => _AnimatedGoldPlayPassCardState();
}

class _AnimatedGoldPlayPassCardState extends State<_AnimatedGoldPlayPassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final activeStore = widget.activeStore;
    final isStandard = widget.isStandard;
    final days = provider.consolidatedStandardDays;
    final activePlan = activeStore.subscriptionPlan;

    // Find final expiry date
    final activeItems = provider.subscriptionHistory.where((h) => h.isActive).toList();
    DateTime? expiryDate;
    if (activeItems.isNotEmpty) {
      expiryDate = activeItems.map((h) => h.endDate).reduce((a, b) => a.isAfter(b) ? a : b);
    }
    final expiryStr = expiryDate != null ? DateFormat('dd MMM yyyy').format(expiryDate) : 'N/A';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E1E38),
            Color(0xFF2E1A47),
            Color(0xFF411554),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF411554).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          // Subtle gold outer glow
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.08),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AnimatedBuilder(
          animation: _waveController,
          builder: (context, child) {
            return Stack(
              children: [
                // Glassmorphic / Glossy Highlights
                Positioned(
                  right: -50,
                  top: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.12),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -80,
                  bottom: -80,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFE2B774).withValues(alpha: 0.15),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Animated gold wave effect
                Positioned.fill(
                  child: CustomPaint(
                    painter: GoldWavePainter(
                      animationValue: _waveController.value,
                    ),
                  ),
                ),
                // Card Content (cached via child parameter)
                child!,
              ],
            );
          },
          // The child is built once and cached across animation frames
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Upper Row: Pass Type & Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2B774).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFFE2B774),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "BIZSTORE PASS",
                              style: TextStyle(
                                color: const Color(0xFFE2B774),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    offset: const Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              "Premium Subscription",
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isStandard
                            ? AppColors.success.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isStandard
                              ? AppColors.success.withValues(alpha: 0.5)
                              : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isStandard ? AppColors.success : Colors.white60,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isStandard ? "ACTIVE" : "INACTIVE",
                            style: TextStyle(
                              color: isStandard ? Colors.greenAccent : Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Middle section: Active Plan & Details
                Text(
                  activePlan.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE2B774),
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Store: ${activeStore.id ?? 'No Store Attached'}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 32),
                // Lower Row: Days Remaining / Expiry
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "VALUED MEMBER SINCE",
                          style: TextStyle(color: Colors.white38, fontSize: 8, letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          provider.userProfile?.createdAt != null
                              ? DateFormat('MM/yy').format(provider.userProfile!.createdAt!)
                              : '05/26',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (isStandard && days > 0) ...[
                          Text(
                            "$days DAYS REMAINING",
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Expires: $expiryStr",
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                        ] else ...[
                          const Text(
                            "NO ACTIVE MEMBERSHIP",
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Upgrade to unlock full features",
                            style: TextStyle(color: Colors.white24, fontSize: 9),
                          ),
                        ]
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints animated glowing gold waves across the card surface.
class GoldWavePainter extends CustomPainter {
  final double animationValue;

  GoldWavePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final phase = animationValue * 2 * pi;

    // --- Wave 1: Deep slow gold wave (bottom region) ---
    _drawWave(
      canvas: canvas,
      size: size,
      phase: phase,
      speed: 1.0,
      amplitude: h * 0.06,
      baseY: h * 0.72,
      color1: const Color(0xFFD4AF37).withValues(alpha: 0.14),
      color2: const Color(0xFFB8860B).withValues(alpha: 0.06),
      glowColor: const Color(0xFFFFD700).withValues(alpha: 0.25),
      frequency: 1.5,
    );

    // --- Wave 2: Medium metallic gold wave ---
    _drawWave(
      canvas: canvas,
      size: size,
      phase: phase,
      speed: 1.4,
      amplitude: h * 0.05,
      baseY: h * 0.78,
      color1: const Color(0xFFFFD700).withValues(alpha: 0.18),
      color2: const Color(0xFFD4AF37).withValues(alpha: 0.08),
      glowColor: const Color(0xFFFFD700).withValues(alpha: 0.35),
      frequency: 2.0,
    );

    // --- Wave 3: Fast bright champagne highlight wave ---
    _drawWave(
      canvas: canvas,
      size: size,
      phase: phase,
      speed: 1.8,
      amplitude: h * 0.035,
      baseY: h * 0.84,
      color1: const Color(0xFFE2B774).withValues(alpha: 0.22),
      color2: const Color(0xFFFFA500).withValues(alpha: 0.05),
      glowColor: const Color(0xFFFFF8DC).withValues(alpha: 0.45),
      frequency: 2.5,
    );

    // --- Ambient gold shimmer at the bottom ---
    final shimmerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFFD4AF37).withValues(alpha: 0.04),
          const Color(0xFFFFD700).withValues(alpha: 0.10),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, h * 0.6, w, h * 0.4));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.6, w, h * 0.4), shimmerPaint);
  }

  void _drawWave({
    required Canvas canvas,
    required Size size,
    required double phase,
    required double speed,
    required double amplitude,
    required double baseY,
    required Color color1,
    required Color color2,
    required Color glowColor,
    required double frequency,
  }) {
    final w = size.width;
    final h = size.height;

    // Build wave path
    final wavePath = Path();
    wavePath.moveTo(0, h); // bottom-left

    // Start at left edge
    final startY = baseY + amplitude * sin(phase * speed);
    wavePath.lineTo(0, startY);

    // Draw the sine wave across the width
    for (double x = 0; x <= w; x += 2) {
      final normalizedX = x / w;
      final y = baseY +
          amplitude * sin(phase * speed + normalizedX * frequency * 2 * pi) +
          amplitude * 0.5 * sin(phase * speed * 1.3 + normalizedX * frequency * 3.2 * pi);
      wavePath.lineTo(x, y);
    }

    wavePath.lineTo(w, h); // bottom-right
    wavePath.close();

    // Fill wave body with gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color1, color2],
      ).createShader(Rect.fromLTWH(0, baseY - amplitude, w, h - baseY + amplitude));
    canvas.drawPath(wavePath, fillPaint);

    // Draw glowing crest line
    final crestPath = Path();
    final crestStartY = baseY + amplitude * sin(phase * speed);
    crestPath.moveTo(0, crestStartY);
    for (double x = 0; x <= w; x += 2) {
      final normalizedX = x / w;
      final y = baseY +
          amplitude * sin(phase * speed + normalizedX * frequency * 2 * pi) +
          amplitude * 0.5 * sin(phase * speed * 1.3 + normalizedX * frequency * 3.2 * pi);
      crestPath.lineTo(x, y);
    }

    final glowPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawPath(crestPath, glowPaint);

    // Sharp thin bright line on top of glow
    final sharpPaint = Paint()
      ..color = glowColor.withValues(alpha: (glowColor.a * 0.6).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(crestPath, sharpPaint);
  }

  @override
  bool shouldRepaint(covariant GoldWavePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

