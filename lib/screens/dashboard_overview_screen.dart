import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/dashboard_provider.dart';
import '../providers/smart_insights_provider.dart';
import '../widgets/sync_status_widget.dart';
import '../utils/theme.dart';

class DashboardOverviewScreen extends StatelessWidget {
  const DashboardOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch SmartInsightsProvider for data updates
    final insights = Provider.of<SmartInsightsProvider>(context);
    final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overview', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          const SyncStatusWidget(),
          IconButton(
            icon: const Icon(Icons.speed),
            tooltip: "Switch to Smart Dashboard",
            onPressed: () {
              dashboardProvider.setUIStyle(UIStyle.car_dashboard);
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. KPI Grid (Responsive & Premium)
            _buildKpiGrid(context, insights),
            
            const SizedBox(height: 32),
            
            // 2. Enhanced Trend Chart
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                const Text("Weekly Performance", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              ],
            ),
            const SizedBox(height: 16),
            _EnhancedTrendChart(data: insights.weeklyTrend),

            const SizedBox(height: 32),
            
            // 3. Top Items Leaderboard
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                const Text("Top Selling Products", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              ],
            ),
            const SizedBox(height: 16),
            _buildTopItemsLeaderboard(context, insights.topItems),

             const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiGrid(BuildContext context, SmartInsightsProvider insights) {
    final cards = [
      _KpiData(title: "Today Sales", value: "₹${insights.todaySales.toStringAsFixed(0)}", icon: Icons.payments_rounded, color: Colors.blue, gradient: const [Color(0xFF2563EB), Color(0xFF3B82F6)]),
      _KpiData(title: "Orders", value: "${insights.todayOrders}", icon: Icons.shopping_basket_rounded, color: Colors.indigo, gradient: const [Color(0xFF4F46E5), Color(0xFF6366F1)]),
      _KpiData(title: "Gross Profit", value: "₹${insights.grossProfit.toStringAsFixed(0)}", icon: Icons.auto_graph_rounded, color: Colors.teal, gradient: const [Color(0xFF059669), Color(0xFF10B981)]),
      _KpiData(title: "Cash in Hand", value: "₹${insights.cashInHand.toStringAsFixed(0)}", icon: Icons.account_balance_wallet_rounded, color: Colors.amber, gradient: const [Color(0xFFD97706), Color(0xFFF59E0B)]),
      _KpiData(title: "Low Stock", value: "${insights.lowStockCount}", icon: Icons.inventory_2_rounded, color: Colors.orange, gradient: const [Color(0xFFEA580C), Color(0xFFFB923C)], isAlert: insights.lowStockCount > 0),
      _KpiData(title: "Credit Due", value: "₹${insights.creditOutstanding.toStringAsFixed(0)}", icon: Icons.credit_score_rounded, color: Colors.pink, gradient: const [Color(0xFFE11D48), Color(0xFFF43F5E)]),
      _KpiData(title: "Growth", value: "${insights.salesVsYesterdayPercent.toStringAsFixed(1)}%", icon: Icons.analytics_rounded, color: Colors.cyan, gradient: const [Color(0xFF0891B2), Color(0xFF06B6D4)]),
      _KpiData(title: "Avg Order", value: "₹${insights.todayOrders > 0 ? (insights.todaySales / insights.todayOrders).toStringAsFixed(0) : '0'}", icon: Icons.pie_chart_rounded, color: Colors.deepPurple, gradient: const [Color(0xFF7C3AED), Color(0xFF8B5CF6)]),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 4;
        if (constraints.maxWidth < 600) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth < 900) {
          crossAxisCount = 2;
        } else if (constraints.maxWidth < 1200) {
          crossAxisCount = 3;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.0,
          ),
          itemBuilder: (context, index) {
            return _PremiumKpiCard(data: cards[index], index: index);
          },
        );
      },
    );
  }

  Widget _buildTopItemsLeaderboard(BuildContext context, List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text("No product sales recorded for today.", style: TextStyle(color: Colors.grey))),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxVal = items.isNotEmpty ? (items[0]['value'] as double) : 1.0;

    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final double percent = (item['value'] as double) / maxVal;

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 600 + (index * 150)),
          tween: Tween(begin: 0, end: 1),
          builder: (context, animValue, child) {
            return Opacity(
              opacity: animValue,
              child: Transform.translate(
                offset: Offset(30 * (1 - animValue), 0),
                child: child,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Rank Circle
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: index == 0 ? Colors.orange.withValues(alpha: 0.1) : (isDark ? Colors.grey[800] : Colors.grey[100]),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      "${index + 1}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: index == 0 ? Colors.orange : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Info & Progress
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item['name'],
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          Text(
                            "₹${(item['value'] as double).toStringAsFixed(0)}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(
                            height: 6,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: percent,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    index == 0 ? Colors.orange : Colors.blueAccent,
                                    index == 0 ? Colors.orangeAccent : Colors.lightBlueAccent,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

}

class _KpiData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final List<Color> gradient;
  final bool isAlert;

  _KpiData({
    required this.title, 
    required this.value, 
    required this.icon, 
    required this.color, 
    required this.gradient,
    this.isAlert = false
  });
}

class _PremiumKpiCard extends StatelessWidget {
  final _KpiData data;
  final int index;

  const _PremiumKpiCard({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 100)),
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: data.color.withValues(alpha: isDark ? 0.2 : 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: data.isAlert 
                ? Colors.red.withValues(alpha: 0.5) 
                : (isDark ? Colors.grey[800]! : Colors.grey[100]!),
            width: data.isAlert ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Background Decorative Gradient Icon
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                data.icon,
                size: 60,
                color: data.color.withValues(alpha: 0.05),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: data.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(data.icon, color: Colors.white, size: 20),
                    ),
                    if (data.isAlert)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "ALERT",
                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  data.value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  data.title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EnhancedTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _EnhancedTrendChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text("No Sales Data Available", style: TextStyle(color: Colors.grey))),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(16, 32, 24, 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < data.length) {
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 8,
                      child: Text(
                        data[value.toInt()]['day'].toString().substring(0, 3),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 500, // Adjust based on data scale
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8,
                    child: Text(
                      '₹${value.toInt()}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: data.length.toDouble() - 1,
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: isDark ? Colors.grey[800]! : Colors.white,
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  final flSpot = barSpot;
                  return LineTooltipItem(
                    '${data[flSpot.x.toInt()]['day']}\n',
                    const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 10),
                    children: [
                      TextSpan(
                        text: '₹${flSpot.y.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['sales'] as double))).toList(),
              isCurved: true,
              gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF6366F1)]),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 3,
                  strokeColor: const Color(0xFF2563EB),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2563EB).withValues(alpha: 0.3),
                    const Color(0xFF2563EB).withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
