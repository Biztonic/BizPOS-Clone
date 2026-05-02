import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/dashboard_provider.dart';
import 'package:intl/intl.dart';

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
  int? _sortColumnIndex;
  final bool _sortAscending = true;


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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Subscriptions Overview"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final bool isMobile = constraints.maxWidth < 600;
                
                return SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 12 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCards(isMobile),
                      const SizedBox(height: 24),
                      
                      // Responsive Charts Row/Column
                      if (isMobile) ...[
                        _buildPlanDistributionChart(),
                        const SizedBox(height: 16),
                        _buildAddonAdoptionChart(),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildPlanDistributionChart()),
                            const SizedBox(width: 16),
                            Expanded(child: _buildAddonAdoptionChart()),
                          ],
                        ),
                      
                      const SizedBox(height: 24),
                      _buildDetailedStoreTable(isMobile),
                      const SizedBox(height: 24),
                      _buildStoreRevenueList(),
                      const SizedBox(height: 32),
                      const Text("Recent Transactions / Coupons", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _buildRecentHistoryList(),
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
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildResponsiveStatCard("Total Revenue", currencyFormat.format(totalValue), Icons.payments, Colors.green, isMobile),
        _buildResponsiveStatCard("Active Standard", activeSubs.toString(), Icons.star, Colors.orange, isMobile),
        _buildResponsiveStatCard("Active Addons", totalAddonCount.toString(), Icons.extension, Colors.teal, isMobile),
        _buildResponsiveStatCard("Total Stores", totalStores.toString(), Icons.store, Colors.blue, isMobile),
      ],
    );
  }

  Widget _buildResponsiveStatCard(String label, String value, IconData icon, Color color, bool isMobile) {
    return Container(
      width: isMobile ? (MediaQuery.of(context).size.width - 36) / 2 : 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }


  Widget _buildPlanDistributionChart() {
    final Map<String, int> distribution = Map<String, int>.from(_stats['planDistribution'] ?? {});
    if (distribution.isEmpty) return const SizedBox();

    List<PieChartSectionData> sections = [];
    int i = 0;
    final colors = [Colors.indigo, Colors.orange, Colors.teal, Colors.red, Colors.purple];
    
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          const Text("Plan Distribution", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          SizedBox(height: 180, child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 40))),
          const SizedBox(height: 20),
          _buildPlanLegend(),
        ],
      ),
    );
  }

  Widget _buildStoreRevenueList() {
    final Map<String, double> revenueMap = Map<String, double>.from(_stats['storeRevenue'] ?? {});
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Top Stores by Revenue", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          if (revenueMap.isEmpty)
            const Center(child: Text("No data"))
          else
            ...revenueMap.entries.take(5).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                  Text(currencyFormat.format(e.value), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildPlanLegend() {
    final Map<String, int> distribution = Map<String, int>.from(_stats['planDistribution'] ?? {});
    final colors = [Colors.indigo, Colors.orange, Colors.teal, Colors.red, Colors.purple];
    int i = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: distribution.keys.map((plan) {
        final color = colors[i++ % colors.length];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(plan, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentHistoryList() {
    final List history = _stats['recentHistory'] ?? [];
    if (history.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text("No subscription history available")));
    }

    final df = DateFormat('dd MMM yyyy');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.indigo.withValues(alpha: 0.1),
              child: const Icon(Icons.receipt_long, color: Colors.indigo, size: 20),
            ),
            title: Row(
              children: [
                Expanded(child: Text(item['storeName'] ?? (item['ownerEmail'] ?? 'New Request'), style: const TextStyle(fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(item['status']).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _getStatusColor(item['status']).withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    (item['status'] ?? 'PENDING').toString().toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(item['status'])),
                  ),
                ),
              ],
            ),
            subtitle: Text("${df.format(createdAt)} • $plan ($cycle)"),
            trailing: Text("₹$amount", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
          );
        },
      ),
    );
  }

  Color _getStatusColor(dynamic status) {
    switch (status?.toString().toUpperCase()) {
      case 'APPROVED':
      case 'COMPLETED':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'FAILED':
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildAddonAdoptionChart() {
    final Map<String, int> activeAddons = Map<String, int>.from(_stats['activeAddons'] ?? {});
    if (activeAddons.isEmpty) return const SizedBox();

    List<PieChartSectionData> sections = [];
    int i = 0;
    final colors = [Colors.teal, Colors.cyan, Colors.lightBlue, Colors.blueGrey, Colors.green];
    
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          const Text("Addon Adoption", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          SizedBox(height: 180, child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 40))),
          const SizedBox(height: 20),
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
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(addon.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
    
    // Limits header if we want to show global context
    final limits = _stats['platformLimits'] ?? {};
    final globalDaily = limits['daily'] ?? 2000;
    final globalMonthly = limits['monthly'] ?? 50000;

    if (_selectedAddonFilter != null) {
      storeDetails = storeDetails.where((s) {
        final addons = s['addons'] as List? ?? [];
        return addons.contains(_selectedAddonFilter);
      }).toList();
    }

    // 2. SORTING
    if (_sortColumnIndex != null) {
      storeDetails.sort((a, b) {
        dynamic valA;
        dynamic valB;
        
        switch (_sortColumnIndex) {
          case 0: // Name
            valA = a['name']?.toString().toLowerCase();
            valB = b['name']?.toString().toLowerCase();
            break;
          case 1: // Plan
            valA = a['plan']?.toString().toLowerCase();
            valB = b['plan']?.toString().toLowerCase();
            break;
          case 3: // Validity
            valA = _getExpiryDate(a['expiry']);
            valB = _getExpiryDate(b['expiry']);
            break;
          default:
            valA = '';
            valB = '';
        }
        
        if (valA == null && valB == null) return 0;
        if (valA == null) return 1;
        if (valB == null) return -1;
        
        final cmp = (valA is Comparable) ? valA.compareTo(valB) : 0;
        return _sortAscending ? cmp : -cmp;
      });
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 20),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text("Detailed Overview", style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold))),
              if (_selectedAddonFilter != null || _sortColumnIndex != null)
                IconButton(
                  onPressed: () => setState(() { _selectedAddonFilter = null; _sortColumnIndex = null; }),
                  icon: const Icon(Icons.clear_all, size: 20, color: Colors.blue),
                  tooltip: "Clear Filters",
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // ADDON FILTERS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text("All"),
                  selected: _selectedAddonFilter == null,
                  onSelected: (val) => setState(() => _selectedAddonFilter = null),
                  selectedColor: Colors.indigo.withValues(alpha: 0.2),
                  checkmarkColor: Colors.indigo,
                ),
                const SizedBox(width: 8),
                ...allAddons.map((addon) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(addon.replaceAll('_', ' ')),
                    selected: _selectedAddonFilter == addon,
                    onSelected: (val) => setState(() => _selectedAddonFilter = val ? addon : null),
                    selectedColor: Colors.indigo.withValues(alpha: 0.2),
                    checkmarkColor: Colors.indigo,
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // RESPONSIVE TABLE (Full Width)
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(2.5),
              3: FlexColumnWidth(1.5),
            },
            children: [
              // HEADER
              TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                children: [
                  _buildHeaderCell('STORE NAME'),
                  _buildHeaderCell('PLAN'),
                  _buildHeaderCell('ADDONS / USAGE'),
                  _buildHeaderCell('VALIDITY'),
                ],
              ),
              // ROWS
              ...storeDetails.map((s) {
                final plan = s['plan'] ?? 'Basic';
                final addonList = s['addons'] as List? ?? [];
                final expiry = s['expiry'];
                
                Widget addonContent;
                if (plan == 'Basic') {
                   final dCount = s['dailyOrders'] ?? 0;
                   final dLimit = s['dailyLimit'] ?? globalDaily;
                   final mCount = s['monthlyOrders'] ?? 0;
                   final mLimit = s['monthlyLimit'] ?? globalMonthly;

                   final dProgress = (dLimit > 0) ? (dCount / dLimit).clamp(0.0, 1.0) : 0.0;
                   final mProgress = (mLimit > 0) ? (mCount / mLimit).clamp(0.0, 1.0) : 0.0;


                   addonContent = Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       // Day Progress
                       Row(
                         children: [
                           Text("Day: $dCount / $dLimit", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: dCount > dLimit * 0.9 ? Colors.red : (dCount > dLimit * 0.7 ? Colors.orange : Colors.indigo))),
                           const Spacer(),
                           Text("${(dProgress * 100).toInt()}%", style: const TextStyle(fontSize: 8, color: Colors.grey)),
                         ],
                       ),
                       const SizedBox(height: 2),
                       ClipRRect(
                         borderRadius: BorderRadius.circular(2),
                         child: LinearProgressIndicator(
                           value: dProgress,
                           minHeight: 4,
                           backgroundColor: Colors.grey.shade200,
                           valueColor: AlwaysStoppedAnimation<Color>(dCount > dLimit * 0.9 ? Colors.red : (dCount > dLimit * 0.7 ? Colors.orange : Colors.indigo)),
                         ),
                       ),
                       const SizedBox(height: 8),
                       // Month Progress
                       Row(
                         children: [
                           Text("Month: $mCount / $mLimit", style: TextStyle(fontSize: 9, color: mCount > mLimit * 0.9 ? Colors.red : Colors.grey)),
                           const Spacer(),
                           Text("${(mProgress * 100).toInt()}%", style: const TextStyle(fontSize: 8, color: Colors.grey)),
                         ],
                       ),
                       const SizedBox(height: 2),
                       ClipRRect(
                         borderRadius: BorderRadius.circular(2),
                         child: LinearProgressIndicator(
                           value: mProgress,
                           minHeight: 4,
                           backgroundColor: Colors.grey.shade200,
                           valueColor: AlwaysStoppedAnimation<Color>(mCount > mLimit * 0.9 ? Colors.red : Colors.grey),
                         ),
                       ),
                     ],
                   );

                } else {
                   final addons = addonList.isEmpty ? 'None' : addonList.join(', ').toUpperCase();
                   addonContent = Text(addons, style: const TextStyle(fontSize: 11, color: Colors.blueGrey), overflow: TextOverflow.ellipsis);
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
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                  ),
                  children: [
                    _buildDataCell(Text(s['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    _buildDataCell(_buildPlanChip(plan)),
                    _buildDataCell(addonContent),
                    _buildDataCell(Text(validity, style: TextStyle(
                      fontSize: 11,
                      color: (validity.contains('Expired') || validity.contains('today')) ? Colors.red : Colors.blueGrey,
                      fontWeight: (validity.contains('Expired') || validity.contains('today')) ? FontWeight.bold : FontWeight.normal
                    ))),
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
       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
       child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey)),
     );
  }

  Widget _buildDataCell(Widget child) {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
       child: child,
     );
  }



  // Helper Methods for filtering/sorting
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
    Color color = Colors.grey;
    if (plan == 'Standard') color = Colors.green;
    if (plan == 'Basic') color = Colors.indigo;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Text(plan.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
