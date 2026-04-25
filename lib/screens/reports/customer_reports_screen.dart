import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/customer_provider.dart';
import '../../models/customer.dart';
import 'package:intl/intl.dart';
import '../../widgets/report_stat_card.dart';
import '../../utils/export_utils.dart';
import 'package:fl_chart/fl_chart.dart';

class CustomerReportsScreen extends StatefulWidget {
  const CustomerReportsScreen({super.key});

  @override
  State<CustomerReportsScreen> createState() => _CustomerReportsScreenState();
}

class _CustomerReportsScreenState extends State<CustomerReportsScreen> {

  Future<void> _exportExcel(List<Customer> customers) async {
    try {
      final headers = ['Customer Name', 'Phone', 'Loyalty Points', 'Last Visit'];
      
      final rows = customers.map((c) {
        return [
          c.name,
          c.phone ?? 'N/A',
          c.loyaltyPoints,
          c.lastVisit != null ? DateFormat('yyyy-MM-dd HH:mm').format(c.lastVisit!) : 'Never',
        ];
      }).toList();
      
      rows.add([]);
      rows.add(['Summary', '', '', '']);
      rows.add(['Total Customers', customers.length, '', '']);
      final activeThisMonth = customers.where((c) => c.lastVisit != null && c.lastVisit!.month == DateTime.now().month).length;
      rows.add(['Active This Month', activeThisMonth, '', '']);

      await ExportUtils.exportToExcel(
        fileName: 'Customer_Report',
        headers: headers,
        rows: rows,
        context: context,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export successful')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = Provider.of<CustomerProvider>(context);
    final customers = customerProvider.customers;
    
    // Sort by last visit
    final activeCustomers = List<Customer>.from(customers)
      ..sort((a, b) => (b.lastVisit ?? DateTime(0)).compareTo(a.lastVisit ?? DateTime(0)));

    final activeThisMonth = customers.where((c) => c.lastVisit != null && c.lastVisit!.month == DateTime.now().month).length;

    // Chart Data: Visits in the last 7 days
    final now = DateTime.now();
    final Map<int, int> visitsPerDay = {};
    for (int i = 6; i >= 0; i--) {
      // 0 is today, 6 is 6 days ago
      visitsPerDay[i] = 0;
    }
    
    for (var c in customers.where((c) => c.lastVisit != null)) {
       final diff = now.difference(c.lastVisit!).inDays;
       if (diff >= 0 && diff < 7) {
          visitsPerDay[diff] = (visitsPerDay[diff] ?? 0) + 1;
       }
    }

    double maxVisits = 0;
    for (var v in visitsPerDay.values) {
      if (v > maxVisits) maxVisits = v.toDouble();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // APP BAR
          SliverAppBar(
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/reports'),
            ),
            title: const Text('Customer Reports', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download),
                tooltip: "Export to Excel",
                onPressed: () => _exportExcel(activeCustomers),
              ),
            ],
          ),

          // SUMMARY CARDS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ReportStatCard(
                    title: "Total Customers", 
                    value: "${customers.length}", 
                    icon: Icons.people,
                    baseColor: Colors.blue.shade600
                  ),
                  const SizedBox(width: 16),
                  ReportStatCard(
                    title: "Active this Month", 
                    value: "$activeThisMonth", 
                    icon: Icons.how_to_reg,
                    baseColor: Colors.green.shade600
                  ),
                ],
              ),
            ),
          ),
          
          // BAR CHART
          if (maxVisits > 0)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.03), 
                      blurRadius: 10, 
                      offset: const Offset(0, 4)
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Customer Visits (Last 7 Days)", 
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      )
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: (maxVisits + (maxVisits * 0.2)).ceilToDouble() == 0 ? 5 : (maxVisits + (maxVisits * 0.2)).ceilToDouble(),
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              tooltipBgColor: Colors.blueGrey,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                return BarTooltipItem(
                                  '${rod.toY.toInt()} visits',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (double value, TitleMeta meta) {
                                  final daysAgo = 6 - value.toInt(); // 0 is 6 days ago, 6 is today
                                  final date = now.subtract(Duration(days: daysAgo));
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    child: Text(
                                      DateFormat('E').format(date), 
                                      style: TextStyle(
                                        color: isDark ? Colors.white54 : Colors.black54, 
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 12
                                      )
                                    )
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: maxVisits > 5 ? (maxVisits/5).ceilToDouble() : 1,
                                  reservedSize: 28,
                                  getTitlesWidget: (value, meta) => Text(
                                    value.toInt().toString(), 
                                    style: TextStyle(
                                      color: isDark ? Colors.white54 : Colors.black54, 
                                      fontSize: 10
                                    )
                                  ),
                                )
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: maxVisits > 5 ? (maxVisits/5).ceilToDouble() : 1,
                            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(7, (i) { // i = 0 to 6 (left to right)
                             final daysAgo = 6 - i; // daysAgo: 6 to 0
                             final count = visitsPerDay[daysAgo]?.toDouble() ?? 0;
                             bool isToday = daysAgo == 0;
                             return BarChartGroupData(
                               x: i, 
                               barRods: [
                                 BarChartRodData(
                                   toY: count, 
                                   color: isToday ? Colors.blue : Colors.blue.shade300, 
                                   width: 20, 
                                   borderRadius: BorderRadius.circular(4)
                                 )
                               ]
                             );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.history, color: isDark ? Colors.white54 : Colors.grey.shade600, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Recent Activity", 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 16, 
                      color: isDark ? Colors.white70 : Colors.grey.shade800
                    )
                  ),
                ],
              ),
            ),
          ),
          
          // LIST
          if (activeCustomers.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_off, size: 64, color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      "No customers found.", 
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade600 : Colors.grey, 
                        fontSize: 16
                      )
                    ),
                  ],
                )
              )
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final customer = activeCustomers[index];
                    return Card(
                      elevation: 0,
                      color: isDark ? Colors.grey.shade900 : Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: isDark ? Colors.teal.withValues(alpha: 0.1) : Colors.teal.shade50,
                              child: Text(
                                customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?', 
                                style: TextStyle(
                                  color: isDark ? Colors.teal.shade300 : Colors.teal.shade700, 
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 20
                                )
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 16,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.phone, size: 14, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Text(
                                        customer.phone ?? 'N/A',
                                        style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Text(
                                        customer.lastVisit != null ? DateFormat('MMM dd, yyyy • HH:mm').format(customer.lastVisit!) : 'Never visited',
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.amber.withValues(alpha: 0.1) : Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${customer.loyaltyPoints} Pts", 
                                        style: TextStyle(
                                          fontSize: 13, 
                                          color: Colors.amber.shade800, 
                                          fontWeight: FontWeight.bold
                                        )
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: activeCustomers.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
