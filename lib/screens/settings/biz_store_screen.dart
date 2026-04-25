import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  static final List<Map<String, dynamic>> addonsMetadata = [
    // ... items stay same ...
    {
      'key': 'employee_management',
      'title': 'Employee Management',
      'description': 'Manage staff, roles, permissions, and attendance.',
      'icon': Icons.badge,
      'color': Colors.teal,
      'version': '1.2',
      'size': '3.2 MB',
    },
    {
      'key': 'table_reservation',
      'title': 'Table Reservation',
      'description': 'Floor plan, table status, and reservation management.',
      'icon': Icons.table_restaurant,
      'color': Colors.brown,
      'version': '1.1',
      'size': '2.8 MB',
    },
    {
      'key': 'supplier_management',
      'title': 'Supplier Management',
      'description': 'Track suppliers, purchase orders, and incoming stock.',
      'icon': Icons.local_shipping,
      'color': Colors.deepOrange,
      'version': '1.0',
      'size': '2.1 MB',
    },
    {
      'key': 'kds_management',
      'title': 'Display Integration',
      'description': 'Digital kitchen order tickets and status tracking.',
      'icon': Icons.monitor,
      'color': Colors.indigo,
      'version': '1.0',
      'size': '1.8 MB',
    },
    {
      'key': 'franchise_management',
      'title': 'Franchise Management',
      'description': 'Manage multiple locations and franchise partners.',
      'icon': Icons.business_center,
      'color': Colors.purple,
      'version': '1.0',
      'size': '4.5 MB',
    },
    {
      'key': 'central_catalog',
      'title': 'Central Catalogue',
      'description': 'Access global products and scan menus via the standalone Catalogue app. Enables cloud import in Inventory.',
      'icon': Icons.inventory_2,
      'color': Colors.amber,
      'version': '2.0',
      'size': '2.5 MB',
    },
    {
      'key': 'customer_management',
      'title': 'Customer Management',
      'description': 'Customer profiles, loyalty points, and purchase history.',
      'icon': Icons.people,
      'color': Colors.blue,
      'version': '1.1',
      'size': '3.0 MB',
    },
    {
      'key': 'data_center',
      'title': 'Data Center',
      'description': 'Advanced analytics, backups, and sync control.',
      'icon': Icons.storage,
      'color': Colors.blueGrey,
      'version': '1.0',
      'size': '1.5 MB',
    },
    {
      'key': 'integration_hub',
      'title': 'Integration Hub',
      'description': 'Connect with Swiggy, Zomato, Uber Eats & more.',
      'icon': Icons.hub,
      'color': Colors.orange,
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upgrade currently unavailable. Please contact support.")));
      return;
    }

    // Step 1: Select Plan
    final planSelection = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Select Subscription Plan"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPlanOption(ctx, "Monthly", monthlyPrice, Icons.calendar_month),
            const SizedBox(height: 12),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upgrade request submitted! Waiting for Admin approval."), backgroundColor: Colors.green));
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
                  const Text("Enhance your store with these powerful modules.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 16),
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
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Addons Total:", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("₹${addonTotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("SKIP / CANCEL")),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, tempSelected),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                child: const Text("CONTINUE TO PAYMENT"),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: isBestValue ? Colors.orange : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: isBestValue ? Colors.orange.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isBestValue ? Colors.orange : Colors.indigo),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cycle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("₹$price / ${cycle.toLowerCase()}", style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            if (isBestValue)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                child: const Text("BEST VALUE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
    
    if (activeStore == null) return const Scaffold(body: Center(child: Text("No Store Selected")));

    final currentAddons = Set<String>.from(activeStore.addons);
    final plan = activeStore.subscriptionPlan;
    final isStandard = plan == 'Standard';
    final isSuperAdmin = provider.userProfile?.role == 'Super Admin';
    
    // Check for pending request
    final hasPending = provider.pendingSubscriptions.any((r) => r.storeId == activeStore.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text("BizStore"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Modules", icon: Icon(Icons.apps)),
            Tab(text: "Subscription", icon: Icon(Icons.account_balance_wallet)),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: _isLoading 
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
    );
  }

  Widget _buildModulesTab(DashboardProvider provider, dynamic activeStore, Set<String> currentAddons, bool isStandard, bool isSuperAdmin, bool isDark, bool hasPending) {
    return Column(
      children: [
        // Plan Header
        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          decoration: BoxDecoration(
            color: isStandard 
              ? (isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.shade50) 
              : (isDark ? Colors.indigo.withValues(alpha: 0.15) : Colors.indigo.shade50),
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: [
              Icon(isStandard ? Icons.verified : Icons.stars, color: isStandard ? Colors.green : Colors.indigo, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Plan: ${activeStore.subscriptionPlan}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      isStandard ? "All modules unlocked" : (isSuperAdmin ? "Super Admin bypass" : "Upgrade to unlock full features"), 
                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ),
              if (!isSuperAdmin)
                ElevatedButton(
                  onPressed: hasPending ? null : _upgradeFlow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isStandard ? Colors.green : Colors.indigo, 
                    foregroundColor: Colors.white
                  ),
                  child: Text(hasPending ? "PENDING..." : (isStandard ? "BUY COUPON" : "UPGRADE")),
                )
            ],
          ),
        ),
        
        Expanded(
          child: Builder(
            builder: (context) {
              final visibleAddons = addonsMetadata.where((a) {
                final key = a['key'] as String;
                return !provider.globalDisabledAddons.contains(key);
              }).toList();

              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: MediaQuery.of(context).size.width < 500 ? 400 : 300,
                  childAspectRatio: MediaQuery.of(context).size.width < 500 ? 3.5 : 2.4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: visibleAddons.length,
                itemBuilder: (context, index) {
                  final addon = visibleAddons[index];
                  final key = addon['key'] as String;
                  final price = provider.platformLimits['rate_$key'] ?? 0;
                  return Stack(
                    children: [
                        _buildCompactCard(
                        addon: addon,
                        isInstalled: currentAddons.contains(key),
                        isLocked: !isStandard && !isSuperAdmin && !activeStore.purchasedAddons.contains(key),
                        addonColor: addon['color'] as Color,
                        isDark: isDark,
                        price: price,
                        isPending: provider.pendingSubscriptions.any((r) => r.selectedAddons.contains(key)),
                        isSuperAdmin: isSuperAdmin,
                        isEnabled: true, // Always true since we filtered out disabled ones
                        remainingDays: provider.getAddonDays(key),
                        onToggle: (val) async {
                          try {
                            await provider.toggleGlobalAddon(key, val);
                            _loadData();
                          } catch (e) {
                             if (!context.mounted) return;
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                          }
                        },
                      ),
                    ],
                  );
                },
              );
            }
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionTab(DashboardProvider provider, dynamic activeStore, bool isStandard, bool hasPending, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Plan Status Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Active Plan", style: TextStyle(color: Colors.grey, fontSize: 13)),
                            Text(
                              activeStore.subscriptionPlan, 
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isStandard ? Colors.green : Colors.indigo),
                            ),
                          ],
                        ),
                        _buildPlanBadge(isStandard),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isStandard) _buildRemainingDaysInfo(provider, isDark),
                    const SizedBox(height: 16),
                    const Divider(),
                  const SizedBox(height: 16),
                  if (hasPending)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        children: [
                          Icon(Icons.hourglass_empty, color: Colors.orange, size: 20),
                          SizedBox(width: 12),
                          Expanded(child: Text("Upgrade Request Pending Approval", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13))),
                        ],
                      ),
                    )
                  else if (!isStandard)
                    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _upgradeFlow, child: const Text("UPGRADE NOW")))
                  else ...[
                    const Text("Enjoy full standard features & cloud sync.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity, 
                      child: OutlinedButton.icon(
                        onPressed: _upgradeFlow, 
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                        label: const Text("PURCHASE ADVANCE COUPON"),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          // Auto-activate Toggle
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              secondary: Icon(Icons.auto_awesome, color: activeStore.autoActivateSubscription ? Colors.orange : Colors.grey),
              title: const Text("Auto-activate next subscription", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text("Automatically activate queued coupons when the current plan expires.", style: TextStyle(fontSize: 12)),
              value: activeStore.autoActivateSubscription,
              onChanged: (val) => provider.toggleAutoActivateSub(val),
              activeColor: Colors.orange,
            ),
          ),

          const SizedBox(height: 32),
          const Text("Ready Coupons (In Queue)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          _buildQueuedSubs(provider, isDark),
          
          if (provider.rejectedSubscriptions.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Text("Rejected Requests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 16),
            _buildRejectedRequests(provider, isDark),
          ],

          const SizedBox(height: 32),
          const Text("Purchase History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          if (provider.subscriptionHistory.isEmpty)
             const Center(child: Padding(
               padding: EdgeInsets.all(32.0),
               child: Text("No subscription history found", style: TextStyle(color: Colors.grey)),
             ))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.subscriptionHistory.where((s) => s.status != 'QUEUED').length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final historyItems = provider.subscriptionHistory.where((s) => s.status != 'QUEUED').toList();
                final sub = historyItems[idx];
                final df = DateFormat('dd MMM yyyy');
                return ListTile(
                  tileColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: CircleAvatar(
                    backgroundColor: sub.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                    child: Icon(Icons.history, color: sub.isActive ? Colors.green : Colors.grey),
                  ),
                  title: Text("${sub.planName} - ${sub.billingCycle}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Valid: ${df.format(sub.startDate)} - ${df.format(sub.endDate)}"),
                  trailing: Text(
                    sub.isActive ? "ACTIVE" : "EXPIRED",
                    style: TextStyle(color: sub.isActive ? Colors.green : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                );
              },
            ),
        ],
      ),
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
            borderRadius: BorderRadius.circular(12),
            side: isInstalled
              ? BorderSide(color: Colors.green.shade400, width: 1.5)
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(addon['icon'] as IconData, color: addonColor, size: 24),
                    ),
                    if (hasValidity)
                      Positioned(
                        right: -2, top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                          child: const Icon(Icons.check, color: Colors.white, size: 8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
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
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "$remainingDays Days",
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
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
                     activeColor: Colors.green,
                     // scale: 0.7, // Only available in newer flutter versions or via Transform
                   )
                else if (isInstalled)
                  Icon(Icons.check_circle, color: Colors.green.shade500, size: 22)
                else if (isLocked)
                  const Icon(Icons.lock, color: Colors.grey, size: 20)
                else if (isPending)
                  const Text("PENDING", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold))
                else
                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
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
        color: isStandard ? Colors.green.withValues(alpha: 0.1) : Colors.indigo.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isStandard ? "UNLIMITED" : "BASIC", 
        style: TextStyle(fontWeight: FontWeight.bold, color: isStandard ? Colors.green : Colors.indigo, fontSize: 12),
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
    
    Color textColor = Colors.green;
    Color bgColor = Colors.green.withValues(alpha: 0.1);
    IconData icon = Icons.timer;

    if (days <= 0) {
      textColor = Colors.red;
      bgColor = Colors.red.withValues(alpha: 0.1);
      icon = Icons.error_outline;
    } else if (days < 3) {
      textColor = Colors.orange;
      bgColor = Colors.orange.withValues(alpha: 0.1);
      icon = Icons.warning_amber;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Plan Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 28),
              const SizedBox(width: 12),
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
                const Icon(Icons.priority_high, color: Colors.orange, size: 20),
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
                final addonColor = metadata['color'] as Color? ?? Colors.indigo;
                
                return Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: addonColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: addonColor.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(metadata['icon'] as IconData? ?? Icons.extension, color: addonColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              metadata['title'] as String? ?? key,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const Text("Module active", style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("$addonDays", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: addonColor)),
                          Text("days left", style: TextStyle(fontSize: 10, color: addonColor, fontWeight: FontWeight.w500)),
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

  Widget _buildQueuedSubs(DashboardProvider provider, bool isDark) {
    final queued = provider.subscriptionHistory.where((s) => s.status == 'QUEUED').toList();
    if (queued.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
        child: const Text("No advance subscriptions in queue.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: queued.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final sub = queued[idx];
        return ListTile(
          tileColor: isDark ? Colors.orange.withValues(alpha: 0.05) : Colors.orange.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.orange.withValues(alpha: 0.2))),
          leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.confirmation_num, color: Colors.white)),
          title: Text("${sub.planName} Coupon (${sub.billingCycle})", style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text("Status: QUEUED for later use"),
          trailing: ElevatedButton(
            onPressed: () => provider.activateSubscriptionCoupon(sub.id),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text("ACTIVATE NOW"),
          ),
        );
      },
    );
  }

  Widget _buildSuperAdminOverview(DashboardProvider provider, bool isDark) {
    if (_globalStats.isEmpty) return const Center(child: CircularProgressIndicator());
    
    final planDist = Map<String, dynamic>.from(_globalStats['planDistribution'] ?? {});
    final totalValue = (_globalStats['totalValue'] ?? 0.0).toDouble();
    final activeSubs = _globalStats['activeSubs'] ?? 0;
    final totalStores = _globalStats['totalStores'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Global Subscription Overview", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          // KPI CARDS
          Row(
            children: [
              _buildStatCard("Total Stores", totalStores.toString(), Icons.store, Colors.blue, isDark),
              const SizedBox(width: 16),
              _buildStatCard("Active Subs", activeSubs.toString(), Icons.verified, Colors.green, isDark),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatCard("Total Revenue", "₹${totalValue.toStringAsFixed(2)}", Icons.payments, Colors.orange, isDark, fullWidth: true),
          
          const SizedBox(height: 32),
          
          // CHARTS SECTION
          LayoutBuilder(
            builder: (context, constraints) {
              bool narrow = constraints.maxWidth < 600;
              return narrow 
                ? Column(
                    children: [
                      _buildPlanDistributionCard(planDist, isDark),
                      const SizedBox(height: 16),
                      _buildTrendCard(isDark),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildPlanDistributionCard(planDist, isDark)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTrendCard(isDark)),
                    ],
                  );
            },
          ),
          
          const SizedBox(height: 32),
          const Text("Search & Quick Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildGlobalHistory(isDark),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDark, {bool fullWidth = false}) {
    final widget = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 10)],
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.teal];
    int colorIdx = 0;

    dist.forEach((plan, count) {
      sections.add(PieChartSectionData(
        color: colors[colorIdx % colors.length],
        value: count.toDouble(),
        title: '$count',
        radius: 40,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      colorIdx++;
    });

    return Container(
      padding: const EdgeInsets.all(20),
      height: 320,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Column(
        children: [
          const Text("Plan Distribution", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: sections.isEmpty 
              ? const Center(child: Text("No data"))
              : PieChart(PieChartData(sections: sections, centerSpaceRadius: 40, sectionsSpace: 2)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12, runSpacing: 8,
            children: dist.keys.map((k) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[dist.keys.toList().indexOf(k) % colors.length], shape: BoxShape.circle)),
                const SizedBox(width: 6),
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
      padding: const EdgeInsets.all(20),
      height: 320,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D44) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Column(
        children: [
          const Text("Subscription Revenue Trends", style: TextStyle(fontWeight: FontWeight.bold)),
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
                    color: Colors.indigo,
                    barWidth: 4,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: Colors.indigo.withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text("Weekly cumulative growth metrics", style: TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildGlobalHistory(bool isDark) {
    final history = _globalStats['recentHistory'] as List? ?? [];
    
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        child: const Column(
          children: [
            Icon(Icons.query_stats, color: Colors.grey, size: 32),
            SizedBox(height: 12),
            Text("No recent subscription activity found.", style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: Colors.indigo.withValues(alpha: 0.1),
            child: const Icon(Icons.receipt_long, color: Colors.indigo, size: 20),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Store: ${item['storeId'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text("₹${item['amount'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text("${item['plan'] ?? 'Standard'} - ${item['billingCycle'] ?? 'Monthly'}", style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(item['status']?.toString().toUpperCase() ?? 'ACTIVE', style: const TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildRejectedRequests(DashboardProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.red.withValues(alpha: 0.05) : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.red.withValues(alpha: 0.1) : Colors.red.shade100),
      ),
      child: const Column(
        children: [
          Icon(Icons.report_problem, color: Colors.red, size: 32),
          SizedBox(height: 12),
          Text("No subscription rejection records found.", style: TextStyle(color: Colors.red, fontSize: 13)),
        ],
      ),
    );
  }
}
