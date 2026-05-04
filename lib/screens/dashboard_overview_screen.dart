import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/dashboard_provider.dart';
import '../providers/smart_insights_provider.dart';
import '../widgets/sync_status_widget.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/components/atoms/app_card.dart';
import '../core/design/components/atoms/app_button.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';
import '../core/design/tokens/app_colors.dart';
import '../core/design/density/app_density.dart';
import '../l10n/app_localizations.dart';
import '../utils/theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/reporting/reporting_provider.dart';
import '../features/reporting/domain/entities/report_period.dart';

class DashboardOverviewScreen extends ConsumerStatefulWidget {
  const DashboardOverviewScreen({super.key});

  @override
  ConsumerState<DashboardOverviewScreen> createState() => _DashboardOverviewScreenState();
}

class _DashboardOverviewScreenState extends ConsumerState<DashboardOverviewScreen> {
  @override
  void initState() {
    super.initState();
    // Initial compute
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reportingProvider.notifier).computeStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reportingState = ref.watch(reportingProvider);
    final stats = reportingState.stats;
    final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);

    return PosScaffold(
      title: AppLocalizations.t(context, 'overview'),
      actions: [
        const SyncStatusWidget(),
        _buildPeriodSelector(context, reportingState.selectedPeriod),
        AppButton.secondary(
          icon: Icons.speed,
          onPressed: () {
            dashboardProvider.setUIStyle(UIStyle.car_dashboard);
          },
        ),
      ],
      mainContent: reportingState.isComputing && stats == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(reportingProvider.notifier).computeStats(),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppDensityProvider.configOf(context).cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reportingState.smartInsights.isNotEmpty)
                      _buildInsightsCarousel(context, reportingState.smartInsights),
                    
                    const SizedBox(height: AppSpacing.lg),

                    // 1. KPI Grid
                    _buildKpiGrid(context, stats),
                    
                    const SizedBox(height: AppSpacing.xl),
                    
                    // 2. Weekly Trend
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          AppLocalizations.t(context, 'sales_performance'), 
                          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _EnhancedTrendChart(data: stats?.weeklySales ?? []),

                    const SizedBox(height: AppSpacing.xl),
                    
                    // 3. Top Items Leaderboard
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          AppLocalizations.t(context, 'top_selling_products'), 
                          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildTopItemsLeaderboard(context, stats?.topProducts ?? []),

                     const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context, ReportPeriod current) {
    return PopupMenuButton<ReportPeriod>(
      icon: const Icon(Icons.calendar_today_rounded),
      initialValue: current,
      onSelected: (period) => ref.read(reportingProvider.notifier).setPeriod(period),
      itemBuilder: (context) => ReportPeriod.values.map((p) => PopupMenuItem(
        value: p,
        child: Text(p.toString().split('.').last.toUpperCase()),
      )).toList(),
    );
  }

  Widget _buildInsightsCarousel(BuildContext context, List<String> insights) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: insights.length,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(right: AppSpacing.md),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(insights[index], style: AppTypography.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiGrid(BuildContext context, dynamic stats) {
    final cards = [
      _KpiData(title: AppLocalizations.t(context, 'period_sales'), value: "₹${stats?.totalSales.toStringAsFixed(0) ?? '0'}", icon: Icons.payments_rounded, color: AppColors.primary, gradient: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)]),
      _KpiData(title: AppLocalizations.t(context, 'orders'), value: "${stats?.totalOrders ?? '0'}", icon: Icons.shopping_basket_rounded, color: AppColors.primary, gradient: const [Color(0xFF4F46E5), Color(0xFF6366F1)]),
      _KpiData(title: AppLocalizations.t(context, 'avg_order'), value: "₹${stats?.avgOrderValue.toStringAsFixed(0) ?? '0'}", icon: Icons.pie_chart_rounded, color: AppColors.primary, gradient: const [Color(0xFF7C3AED), Color(0xFF8B5CF6)]),
      _KpiData(title: AppLocalizations.t(context, 'today_sales'), value: "₹${stats?.todaySales.toStringAsFixed(0) ?? '0'}", icon: Icons.today_rounded, color: AppColors.success, gradient: [AppColors.success, AppColors.success.withValues(alpha: 0.7)]),
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
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: crossAxisCount == 1 ? 2.5 : 2.0,
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
      return AppCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              AppLocalizations.t(context, 'no_data'), 
              style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary(context))
            ),
          )
        ),
      );
    }

    final maxVal = items.isNotEmpty ? (items[0]['value'] as double) : 1.0;

    return AppCard(
      child: Column(
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
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                border: index != items.length - 1 
                    ? Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5))) 
                    : null,
              ),
              child: Row(
                children: [
                  // Rank Badge
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: index == 0 ? AppColors.warning.withValues(alpha: 0.1) : AppColors.surfaceVariant(context),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        "${index + 1}",
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: index == 0 ? AppColors.warning : AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  
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
                              style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              "₹${(item['value'] as double).toStringAsFixed(0)}",
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold, 
                                color: AppColors.primary
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Stack(
                          children: [
                            Container(
                              height: 6,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant(context),
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
                                      index == 0 ? AppColors.warning : AppColors.primary,
                                      index == 0 ? AppColors.warning.withValues(alpha: 0.6) : AppColors.primary.withValues(alpha: 0.6),
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
      ),
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
    final density = AppDensityProvider.configOf(context);
    
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
      child: AppCard(
        padding: EdgeInsets.all(density.cardPadding),
        borderColor: data.isAlert ? AppColors.error : null,
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
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: data.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                      ),
                      child: Icon(data.icon, color: Colors.white, size: 20),
                    ),
                    if (data.isAlert)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          AppLocalizations.t(context, 'alert'),
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  data.value,
                  style: AppTypography.displaySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  data.title.toUpperCase(),
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary(context),
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
      return AppCard(
        height: 250,
        child: Center(
          child: Text(
            AppLocalizations.t(context, 'no_data'), 
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary(context))
          )
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      height: 300,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
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
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary(context),
                          fontWeight: FontWeight.bold,
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
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary(context),
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
              tooltipBgColor: isDark ? AppColors.textSecondary(context) : Colors.white,
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  final flSpot = barSpot;
                  return LineTooltipItem(
                    '${data[flSpot.x.toInt()]['day']}\n',
                    TextStyle(color: AppColors.textSecondary(context), fontWeight: FontWeight.bold, fontSize: 10),
                    children: [
                      TextSpan(
                        text: '₹${flSpot.y.toStringAsFixed(0)}',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
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
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.6)]),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 3,
                  strokeColor: AppColors.primary,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.3),
                    AppColors.primary.withValues(alpha: 0.0),
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
