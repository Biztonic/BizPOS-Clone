import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import '../../core/design/tokens/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/store.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';

class StoreSelectScreen extends StatefulWidget {
  const StoreSelectScreen({super.key});

  @override
  State<StoreSelectScreen> createState() => _StoreSelectScreenState();
}

class _StoreSelectScreenState extends State<StoreSelectScreen> {
  String? _expandedStoreId;
  final Map<String, List<Map<String, dynamic>>> _storeEmployees = {};
  bool _isLoadingEmployees = false;
  Future<Map<String, dynamic>>? _statsFuture;
  bool _statsInitialized = false;
  String _selectedPlanFilter = 'All';
  String _selectedAddonFilter = 'All';
  bool _isInitSyncing = true; 


  @override
  void initState() {
    super.initState();
    // SAFETY NET: If we land on this screen with no stores, trigger a fresh fetch.
    // This handles edge cases where the DashboardProvider state wasn't fully
    // hydrated before the router redirected here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dashboard = Provider.of<DashboardProvider>(context, listen: false);
      if (dashboard.stores.isEmpty && !dashboard.isLoading) {
        debugPrint('??? StoreSelectScreen: No stores on mount. Triggering safety-net fetch...');
        _triggerStoreFetch(dashboard);
      }
      
      // Add a minimum 3-second grace period for initial sync to avoid "jumping" to No Stores view
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
           setState(() => _isInitSyncing = false);
        }
      });
    });
  }

  Future<void> _triggerStoreFetch(DashboardProvider dashboard) async {
    try {
      dashboard.setLoading(true);
      // Try to fetch stores directly via StoreProvider if available
      await dashboard.fetchStoresDirectly();
    } finally {
      if (mounted) {
        dashboard.setLoading(false);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_statsInitialized) {
       final dashboard = Provider.of<DashboardProvider>(context, listen: false);
       if (dashboard.activeRole == 'Super Admin') {
          _statsFuture = dashboard.fetchGlobalSubscriptionStats();
       } else if (dashboard.stores.length == 1 && _expandedStoreId == null) {
          // Auto-expand only if store supports employees
          final store = dashboard.stores.first;
          final canShowEmployees = store.subscriptionPlan == 'Standard' || store.purchasedAddons.contains('employee_management');
          if (canShowEmployees) {
            _expandedStoreId = store.id;
            _fetchEmployees(_expandedStoreId!, dashboard);
          }
       }
       _statsInitialized = true;
    }
  }

  Future<void> _fetchEmployees(String storeId, DashboardProvider provider) async {
    setState(() => _isLoadingEmployees = true);
    final employees = await provider.fetchEmployeesForStore(storeId);
    if (mounted) {
      setState(() {
        _storeEmployees[storeId] = employees;
        _isLoadingEmployees = false;
      });
    }
  }

  Future<void> _handleStoreClick(Store store, DashboardProvider provider) async {
    final canShowEmployees = store.subscriptionPlan == 'Standard' || store.purchasedAddons.contains('employee_management');
    
    if (!canShowEmployees) {
      _enterStoreDirectly(store, provider);
      return;
    }

    if (_expandedStoreId == store.id) {
      setState(() => _expandedStoreId = null);
    } else {
      setState(() {
        _expandedStoreId = store.id;
      });
      await _fetchEmployees(store.id, provider);
    }
  }

  Future<void> _enterStoreDirectly(Store store, DashboardProvider provider) async {
    await provider.setActiveStoreId(store.id);
    if (mounted) context.go('/dashboard');
  }

  void _navigateToEmployeeLogin(Store store, Map<String, dynamic> employee) {
    context.push('/employee-login', extra: {
      'store': store,
      'employee': employee,
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = Provider.of<DashboardProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final isDark = AppColors.isDark(context);
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.surface(context),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: AppSpacing.lg, bottom: AppSpacing.md),
              title: Text(AppLocalizations.t(context, 'Select Your Store'),
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.textPrimary(context),
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.authGradient(context),
                ),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.rectangle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.logout, color: AppColors.error, size: 20),
                  onPressed: () => auth.signOut(),
                  tooltip: 'Logout',
                ),
              )
            ],
          ),
          
          if (dashboard.isLoading || (_isInitSyncing && dashboard.stores.isEmpty))
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: AppSpacing.lg),
                    Text(AppLocalizations.t(context, 'Syncing your stores...'), style: TextStyle(color: AppColors.textSecondary(context), fontWeight: FontWeight.w500)),
                  ],
                )
              )
            )
          else if (dashboard.stores.isEmpty)
            SliverFillRemaining(child: _buildNoStoresView(context, dashboard))
          else if (dashboard.activeRole == 'Super Admin')
            SliverToBoxAdapter(child: _buildSuperAdminDashboard(context, dashboard, isDark))
          else
            SliverToBoxAdapter(child: _buildOwnerHeader(dashboard, isDark)),

          if (!dashboard.isLoading && dashboard.stores.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: _buildStoreListSliver(context, dashboard, isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildOwnerHeader(DashboardProvider dashboard, bool isDark) {
     return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              Text(AppLocalizations.t(context, 'Welcome back!'),
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(AppLocalizations.t(context, 'Choose a store to manage'),
                style: AppTypography.headlineSmall.copyWith(color: AppColors.textPrimary(context)),
              ),
           ],
        ),
     );
  }

  Widget _buildSuperAdminDashboard(BuildContext context, DashboardProvider dashboard, bool isDark) {
     return FutureBuilder<Map<String, dynamic>>(
       future: _statsFuture,
       builder: (context, snapshot) {
          final stats = snapshot.data ?? {};
          final isStatsLoading = snapshot.connectionState == ConnectionState.waiting;
          
          return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                if (isStatsLoading) const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: AppSpacing.md),
                if (stats.isNotEmpty) ...[
                  _buildInsightsGrid(stats, isDark),
                  _buildFilterSection(stats, isDark),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Text(AppLocalizations.t(context, 'All Active Stores'),
                    style: AppTypography.titleLarge.copyWith(color: AppColors.textPrimary(context)),
                  ),
                ),
             ],
          );
       }
     );
  }

  Widget _buildInsightsGrid(Map<String, dynamic> stats, bool isDark) {
    final totalStores = stats['totalStores'] ?? 0;
    final activeSubs = stats['activeSubs'] ?? 0;
    final planDistribution = stats['planDistribution'] as Map<String, int>? ?? {};
    final activeAddonsMap = stats['activeAddons'] as Map<String, int>? ?? {};
    final totalAddons = activeAddonsMap.values.fold(0, (a, b) => a + b);

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 2);
        final padding = constraints.maxWidth > 600 ? 24.0 : 16.0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Column(
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.6,
                children: [
                  _buildInsightCard("Total Stores", totalStores.toString(), Icons.store_rounded, AppColors.primary),
                  _buildInsightCard("Active Subs", activeSubs.toString(), Icons.verified_user_rounded, AppColors.success),
                  _buildInsightCard("Standard Plans", (planDistribution['Standard'] ?? 0).toString(), Icons.star_rounded, AppColors.warning),
                  _buildInsightCard("Total Add-ons", totalAddons.toString(), Icons.extension_rounded, AppColors.primary),
                ],
              ),
              if (constraints.maxWidth > 700) ...[
                const SizedBox(height: AppSpacing.lg),
                _buildPlanDistributionCard(planDistribution, totalStores, isDark),
              ],
            ],
          ),
        );
      }
    );
  }

  Widget _buildInsightCard(String title, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Theme.of(context).colorScheme.onPrimary,
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 20, offset: const Offset(0, 8))
        ],
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           Container(
             padding: const EdgeInsets.all(AppSpacing.sm),
             decoration: BoxDecoration(
               color: color.withValues(alpha: 0.1),
               borderRadius: BorderRadius.zero,
             ),
             child: Icon(icon, color: color, size: 24),
           ),
           const Spacer(),
           Text(value, style: AppTypography.headlineMedium.copyWith(color: AppColors.textPrimary(context))),
           Text(title, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context))),
        ]
      ),
    );
  }

  Widget _buildPlanDistributionCard(Map<String, int> distribution, int total, bool isDark) {
    List<PieChartSectionData> pieSections = [];
    int colorIndex = 0;
    final colors = [AppColors.primary, AppColors.warning, AppColors.success, AppColors.error, AppColors.primaryLight];
    
    distribution.forEach((plan, count) {
      if (count > 0) {
        pieSections.add(PieChartSectionData(
          color: colors[colorIndex % colors.length],
          value: count.toDouble(),
          title: '$count',
          radius: 40,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ));
        colorIndex++;
      }
    });

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.zero,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.t(context, 'Plan Overview'), style: AppTypography.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(AppLocalizations.t(context, 'Distribution of active subscriptions across all stores'), style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: 16,
                  children: distribution.entries.map((e) {
                     final idx = distribution.keys.toList().indexOf(e.key);
                     return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[idx % colors.length], shape: BoxShape.rectangle)),
                           const SizedBox(width: AppSpacing.sm),
                           Text("${e.key}: ${e.value}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                     );
                  }).toList(),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 140, height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(PieChartData(sectionsSpace: 4, centerSpaceRadius: 35, sections: pieSections)),
                Text("$total", style: AppTypography.headlineSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(Map<String, dynamic> stats, bool isDark) {
    final activeAddonsMap = stats['activeAddons'] as Map<String, int>? ?? {};
    final addonList = ['All', ...activeAddonsMap.keys];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterRow("Active Plan", ['All', 'Standard', 'Basic'], _selectedPlanFilter, (v) => setState(() => _selectedPlanFilter = v), isDark),
          const SizedBox(height: AppSpacing.md),
          _buildFilterRow("Add-on Feature", addonList, _selectedAddonFilter, (v) => setState(() => _selectedAddonFilter = v), isDark),
          const Divider(height: 48),
        ],
      ),
    );
  }

  Widget _buildFilterRow(String title, List<String> options, String current, Function(String) onSelect, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context), letterSpacing: 0.5)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: options.map((opt) {
              final isSelected = current == opt;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: InkWell(
                  onTap: () => onSelect(opt),
                  borderRadius: BorderRadius.zero,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface(context),
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.border(context)),
                      boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))] : null,
                    ),
                    child: Text(
                      opt.replaceAll('_', ' ').toUpperCase(),
                      style: AppTypography.labelSmall.copyWith(
                        color: isSelected ? Theme.of(context).colorScheme.onPrimary : AppColors.textSecondary(context)
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildNoStoresView(BuildContext context, DashboardProvider dashboard) {
     return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_outlined, size: 80, color: AppColors.textHint(context)),
          const SizedBox(height: AppSpacing.lg),
          Text(AppLocalizations.t(context, 'No stores found'), style: AppTypography.titleLarge.copyWith(color: AppColors.textHint(context))),
          const SizedBox(height: AppSpacing.sm),
          Text(AppLocalizations.t(context, 'Get started by creating your first store'), style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
          const SizedBox(height: AppSpacing.xl),
          if (dashboard.activeRole == 'Store Owner')
            ElevatedButton(
              onPressed: () => context.go('/create-store'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                elevation: 0,
              ),
              child: Text(AppLocalizations.t(context, 'Create Store'), style: AppTypography.labelLarge.copyWith(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
             onPressed: () async {
                setState(() => _isInitSyncing = true);
                try {
                  await _triggerStoreFetch(dashboard);
                } finally {
                  if (mounted) setState(() => _isInitSyncing = false);
                }
             }, 
             icon: const Icon(Icons.refresh, size: 18), 
             label: Text(AppLocalizations.t(context, 'Refresh Stores'))
          ),
        ],
      ),
    );
  }

  Widget _buildStoreListSliver(BuildContext context, DashboardProvider dashboard, bool isDark) {
    List<Store> displayedStores = dashboard.stores;

    if (dashboard.activeRole == 'Super Admin') {
      displayedStores = displayedStores.where((store) {
        bool planMatches = _selectedPlanFilter == 'All' || store.subscriptionPlan == _selectedPlanFilter;
        bool addonMatches = _selectedAddonFilter == 'All' || store.addons.contains(_selectedAddonFilter);
        return planMatches && addonMatches;
      }).toList();
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final store = displayedStores[index];
          final isExpanded = _expandedStoreId == store.id;
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.zero,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isExpanded ? 0.1 : 0.05),
                  blurRadius: isExpanded ? 30 : 15,
                  offset: isExpanded ? const Offset(0, 12) : const Offset(0, 6)
                )
              ],
              border: isExpanded ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2) : null,
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.all(AppSpacing.xxs),
                  leading: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: store.image != null 
                      ? ClipRRect(
                          borderRadius: BorderRadius.zero,
                          child: CachedNetworkImage(imageUrl: store.image!, fit: BoxFit.cover, placeholder: (_, __) => const Icon(Icons.store, color: AppColors.primary)),
                        )
                      : const Icon(Icons.store, color: AppColors.primary, size: 30),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                         child: Text(store.name, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      _buildPlanBadge(store.subscriptionPlan),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      "Owner ID: ${store.owner.substring(0, 8)}... ï¿½ ${store.storeType}",
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context)),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dashboard.activeRole == 'Super Admin')
                        _buildActionButton(Icons.login_rounded, "ENTER", () => _enterStoreDirectly(store, dashboard), AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.textHint(context)),
                    ],
                  ),
                  onTap: () => _handleStoreClick(store, dashboard),
                ),
                if (isExpanded) _buildEmployeeSection(store),
              ],
            ),
          );
        },
        childCount: displayedStores.length,
      ),
    );
  }

  Widget _buildPlanBadge(String plan) {
     final color = plan == 'Standard' ? AppColors.warning : AppColors.success;
     return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.zero,
        ),
        child: Text(
          plan.toUpperCase(),
          style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.bold, letterSpacing: 0.5)
        ),
     );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, Color color) {
     return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Container(
           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: AppSpacing.sm),
           decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.zero,
           ),
           child: Row(
              children: [
                 Icon(icon, size: 16, color: color),
                 const SizedBox(width: 6),
                 Text(label, style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.bold, color: color)),
              ],
           ),
        ),
     );
  }

  Widget _buildEmployeeSection(Store store) {
    if (_isLoadingEmployees) {
      return const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }

    final employees = _storeEmployees[store.id] ?? [];
    final dashboard = Provider.of<DashboardProvider>(context, listen: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(bottomLeft: Radius.zero, bottomRight: Radius.zero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.t(context, 'EMPLOYEE PROFILES'), style: AppTypography.labelSmall.copyWith(color: AppColors.textHint(context), letterSpacing: 1)),
                if (dashboard.activeRole != 'Employee')
                  _buildActionButton(Icons.admin_panel_settings_rounded, "Enter as Admin", () => _enterStoreDirectly(store, dashboard), AppColors.textSecondary(context)),
              ],
            ),
          ),
          if (employees.isEmpty)
            Text(AppLocalizations.t(context, 'No employee profiles found.'), style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context)))
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: employees.map((emp) {
                final name = emp['name'] ?? 'Employee';
                return InkWell(
                  onTap: () => _navigateToEmployeeLogin(store, emp),
                  borderRadius: BorderRadius.zero,
                  child: Container(
                    width: 110,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary(context).withValues(alpha: 0.03),
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: AppColors.textSecondary(context).withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Text(name[0].toUpperCase(), style: AppTypography.titleLarge.copyWith(color: AppColors.primary)),
                        ),
                        const SizedBox(height: 12),
                        Text(name, style: AppTypography.labelLarge, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                        Text(emp['role'] ?? 'Staff', style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context))),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}







