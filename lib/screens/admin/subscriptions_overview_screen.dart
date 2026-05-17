import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/dashboard_provider.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_colors.dart';

class SubscriptionsOverviewScreen extends StatefulWidget {
  const SubscriptionsOverviewScreen({super.key});

  @override
  State<SubscriptionsOverviewScreen> createState() => _SubscriptionsOverviewScreenState();
}

class _SubscriptionsOverviewScreenState extends State<SubscriptionsOverviewScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  
  // Filtering & Sorting State
  String? _selectedAddonFilter;
  
  

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final stats = await provider.fetchGlobalSubscriptionStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PosScaffold(
      title: "Subscriptions Overview",
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refresh,
          tooltip: "Refresh",
        ),
      ],
      mainContent: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final bool isMobile = constraints.maxWidth < 600;
                
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCards(isMobile),
                      const SizedBox(height: AppSpacing.lg),
                      
                      // Responsive Charts
                      if (isMobile) ...[
                        _buildPlanDistributionChart(),
                        const SizedBox(height: AppSpacing.md),
                        _buildAddonAdoptionChart(),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildPlanDistributionChart()),
                            AppSpacing.hMd,
                            Expanded(child: _buildAddonAdoptionChart()),
                          ],
                        ),
                      
                      AppSpacing.vLg,
                      _buildDetailedStoreTable(isMobile),
                      AppSpacing.vLg,
                      _buildStoreRevenueList(),
                      AppSpacing.vLg,
                      Text(AppLocalizations.t(context, 'Recent Transactions / Coupons'), style: AppTypography.h2),
                      AppSpacing.vMd,
                      _buildRecentHistoryList(),
                      AppSpacing.vXl,
                    ],
                  ),
                );
              }
            ),
    );
  }

  Widget _buildSummaryCards(bool isMobile) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final totalValue = _stats['totalValue'] ?? 0.0;
    final activeSubs = _stats['activeSubs'] ?? 0;
    final totalStores = _stats['totalStores'] ?? 0;
    final activeAddons = _stats['activeAddons'] as Map? ?? {};
    int totalAddonCount = 0;
    activeAddons.forEach((k, v) => totalAddonCount += (v as int));

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        _buildResponsiveStatCard("Total Revenue", currencyFormat.format(totalValue), Icons.payments, AppColors.success, isMobile),
        _buildResponsiveStatCard("Active Standard", activeSubs.toString(), Icons.star, AppColors.warning, isMobile),
        _buildResponsiveStatCard("Active Addons", totalAddonCount.toString(), Icons.extension, AppColors.primary, isMobile),
        _buildResponsiveStatCard("Total Stores", totalStores.toString(), Icons.store, AppColors.primary, isMobile),
      ],
    );
  }

  Widget _buildResponsiveStatCard(String label, String value, IconData icon, Color color, bool isMobile) {
    final cardWidth = isMobile ? (MediaQuery.of(context).size.width - 48) / 2 : 240.0;
    
    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: AppSpacing.md),
          Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context))),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AppTypography.displaySmall)),
        ],
      ),
    );
  }

  Widget _buildPlanDistributionChart() {
    final Map<String, int> distribution = Map<String, int>.from(_stats['planDistribution'] ?? {});
    if (distribution.isEmpty) return const SizedBox();

    List<PieChartSectionData> sections = [];
    int i = 0;
    final colors = [AppColors.primary, AppColors.warning, AppColors.primary, AppColors.error, AppColors.primaryLight];
    
    distribution.forEach((plan, planCount) {
      sections.add(PieChartSectionData(
        color: colors[i % colors.length],
        value: planCount.toDouble(),
        title: '$planCount',
        radius: 60,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      i++;
    });

    return AppCard(
      child: Column(
        children: [
          Text(AppLocalizations.t(context, 'Plan Distribution'), style: AppTypography.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(height: 180, child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 40))),
          const SizedBox(height: AppSpacing.lg),
          _buildPlanLegend(),
        ],
      ),
    );
  }

  Widget _buildStoreRevenueList() {
    final Map<String, double> revenueMap = Map<String, double>.from(_stats['storeRevenue'] ?? {});
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.t(context, 'Top Stores by Revenue'), style: AppTypography.titleLarge),
          const SizedBox(height: AppSpacing.md),
          if (revenueMap.isEmpty)
            Center(child: Text(AppLocalizations.t(context, 'No data available'), style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))))
          else
            ...revenueMap.entries.take(5).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(e.key, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500))),
                  Text(currencyFormat.format(e.value), style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.success)),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildPlanLegend() {
    final Map<String, int> distribution = Map<String, int>.from(_stats['planDistribution'] ?? {});
    final colors = [AppColors.primary, AppColors.warning, AppColors.primary, AppColors.error, AppColors.primaryLight];
    int i = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: distribution.keys.map((plan) {
        final color = colors[i++ % colors.length];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.rectangle)),
              const SizedBox(width: AppSpacing.sm),
              Text(plan, style: AppTypography.bodyMedium),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentHistoryList() {
    final List history = _stats['recentHistory'] ?? [];
    if (history.isEmpty) {
      return AppCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(AppLocalizations.t(context, 'No subscription history available'), style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
          ),
        ),
      );
    }

    final df = DateFormat('dd MMM yyyy');

    return AppCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: history.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = history[index];
          final amount = (item['amount'] ?? 0.0).toDouble();
          final plan = item['planName'] ?? 'Standard';
          final cycle = item['billingCycle'] ?? 'Monthly';
          DateTime createdAt;
          final rawDate = item['createdAt'];
          if (rawDate is Timestamp) {
            createdAt = rawDate.toDate();
          } else if (rawDate is DateTime) {
            createdAt = rawDate;
          } else if (rawDate is String) {
            createdAt = DateTime.tryParse(rawDate) ?? DateTime.now();
          } else {
            createdAt = DateTime.now();
          }

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
            ),
            title: Row(
              children: [
                Expanded(child: Text(item['storeName'] ?? (item['ownerEmail'] ?? 'New Request'), style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold))),
                _buildStatusBadge(item['status']),
              ],
            ),
            subtitle: Text("${df.format(createdAt)} â€¢ $plan ($cycle)", style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context))),
            trailing: Text("₹$amount", style: AppTypography.titleLarge.copyWith(color: AppColors.success)),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(dynamic status) {
    final String statusStr = (status?.toString() ?? 'PENDING').toUpperCase();
    Color color = AppColors.textSecondary(context);
    
    switch (statusStr) {
      case 'APPROVED':
      case 'COMPLETED':
        color = AppColors.success;
        break;
      case 'PENDING':
        color = AppColors.warning;
        break;
      case 'FAILED':
      case 'CANCELLED':
        color = AppColors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(statusStr, style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildAddonAdoptionChart() {
    final Map<String, int> activeAddons = Map<String, int>.from(_stats['activeAddons'] ?? {});
    if (activeAddons.isEmpty) return const SizedBox();

    List<PieChartSectionData> sections = [];
    int i = 0;
    final colors = [AppColors.primary, AppColors.primaryLight, AppColors.primaryLight, AppColors.primaryLightGrey, AppColors.success];
    
    activeAddons.forEach((addon, addonCount) {
      sections.add(PieChartSectionData(
        color: colors[i % colors.length],
        value: addonCount.toDouble(),
        title: '$addonCount',
        radius: 60,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      i++;
    });

    return AppCard(
      child: Column(
        children: [
          Text(AppLocalizations.t(context, 'Addon Adoption'), style: AppTypography.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(height: 180, child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 40))),
          const SizedBox(height: AppSpacing.lg),
          _buildAddonLegend(activeAddons, colors),
        ],
      ),
    );
  }

  Widget _buildAddonLegend(Map<String, int> distribution, List<Color> colors) {
    int i = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: distribution.keys.map((addon) {
        final color = colors[i++ % colors.length];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.rectangle)),
              const SizedBox(width: AppSpacing.sm),
              Text(addon.replaceAll('_', ' ').toUpperCase(), style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailedStoreTable(bool isMobile) {
    List storeDetails = List.from(_stats['storeDetails'] ?? []);
    if (storeDetails.isEmpty) return const SizedBox();

    final allAddons = _getAllUniqueAddons(storeDetails);
    final limits = _stats['platformLimits'] ?? {};
    final globalDaily = limits['daily'] ?? 2000;

    if (_selectedAddonFilter != null) {
      storeDetails = storeDetails.where((s) {
        final addons = s['addons'] as List? ?? [];
        return addons.contains(_selectedAddonFilter);
      }).toList();
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.t(context, 'Detailed Overview'), style: AppTypography.titleLarge),
              if (_selectedAddonFilter != null)
                IconButton(
                  onPressed: () => setState(() => _selectedAddonFilter = null),
                  icon: const Icon(Icons.filter_list_off, size: 20),
                  tooltip: "Clear Filter",
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Addon Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text(AppLocalizations.t(context, 'All'), style: AppTypography.labelSmall),
                  selected: _selectedAddonFilter == null,
                  onSelected: (_) => setState(() => _selectedAddonFilter = null),
                  selectedColor: AppColors.primary.withValues(alpha: 0.1),
                ),
                const SizedBox(width: AppSpacing.sm),
                ...allAddons.map((addon) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: FilterChip(
                    label: Text(addon.replaceAll('_', ' '), style: AppTypography.labelSmall),
                    selected: _selectedAddonFilter == addon,
                    onSelected: (val) => setState(() => _selectedAddonFilter = val ? addon : null),
                    selectedColor: AppColors.primary.withValues(alpha: 0.1),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(2.5),
              3: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.textSecondary(context).withValues(alpha: 0.1)))),
                children: [
                  _buildHeaderCell('STORE NAME'),
                  _buildHeaderCell('PLAN'),
                  _buildHeaderCell('ADDONS / USAGE'),
                  _buildHeaderCell('VALIDITY'),
                ],
              ),
              ...storeDetails.map((s) {
                final plan = s['plan'] ?? 'Basic';
                final addonList = s['addons'] as List? ?? [];
                final expiry = s['expiry'];
                
                Widget addonContent;
                if (plan == 'Basic') {
                   final dCount = s['dailyOrders'] ?? 0;
                   final dLimit = s['dailyLimit'] ?? globalDaily;
                   
                   

                   final dProgress = (dLimit > 0) ? (dCount / dLimit).clamp(0.0, 1.0) : 0.0;

                   addonContent = Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Row(
                         children: [
                           Text("Day: $dCount / $dLimit", 
                              style: AppTypography.labelSmall.copyWith(
                                color: dCount > dLimit * 0.9 ? AppColors.error : AppColors.primary,
                                fontWeight: FontWeight.bold)),
                           const Spacer(),
                           Text("${(dProgress * 100).toInt()}%", style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context))),
                         ],
                       ),
                       const SizedBox(height: AppSpacing.xs),
                       ClipRRect(
                         borderRadius: BorderRadius.zero,
                         child: LinearProgressIndicator(
                           value: dProgress,
                           minHeight: 4,
                           backgroundColor: AppColors.textSecondary(context).withValues(alpha: 0.1),
                           valueColor: AlwaysStoppedAnimation<Color>(dCount > dLimit * 0.9 ? AppColors.error : AppColors.primary),
                         ),
                       ),
                     ],
                   );
                } else {
                   final addons = addonList.isEmpty ? 'None' : addonList.join(', ').toUpperCase();
                   addonContent = Text(addons, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context)));
                }

                String validity = 'N/A';
                if (expiry != null) {
                  final dt = _getExpiryDate(expiry);
                  if (dt != null) {
                    final diff = dt.difference(DateTime.now()).inDays;
                    validity = diff > 0 ? "$diff days left" : (diff == 0 ? "Expires today" : "Expired");
                  }
                }

                return TableRow(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.textSecondary(context).withValues(alpha: 0.05)))),
                  children: [
                    _buildDataCell(Text(s['name'] ?? 'Unknown', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold))),
                    _buildDataCell(_buildPlanChip(plan)),
                    _buildDataCell(addonContent),
                    _buildDataCell(Text(validity, 
                      style: AppTypography.labelSmall.copyWith(
                        color: (validity.contains('Expired') || validity.contains('today')) ? AppColors.error : AppColors.textSecondary(context),
                        fontWeight: (validity.contains('Expired') || validity.contains('today')) ? FontWeight.bold : FontWeight.normal
                      )
                    )),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xs),
       child: Text(text, style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary(context))),
     );
  }

  Widget _buildDataCell(Widget child) {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xs),
       child: child,
     );
  }

  List<String> _getAllUniqueAddons(List storeDetails) {
    Set<String> addons = {};
    for (var s in storeDetails) {
      final list = s['addons'] as List? ?? [];
      for (var a in list) {
        addons.add(a.toString());
      }
    }
    return addons.toList()..sort();
  }

  DateTime? _getExpiryDate(dynamic expiry) {
    if (expiry == null) return null;
    if (expiry is Timestamp) return expiry.toDate();
    if (expiry is DateTime) return expiry;
    if (expiry is int) return DateTime.fromMillisecondsSinceEpoch(expiry);
    return null;
  }

  Widget _buildPlanChip(String plan) {
    Color color = AppColors.textSecondary(context);
    if (plan == 'Standard') color = AppColors.success;
    if (plan == 'Basic') color = AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(plan.toUpperCase(), style: AppTypography.bodySmall.copyWith(color: color, fontWeight: FontWeight.bold)),
    );
  }
}




