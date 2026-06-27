import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as legacy_provider;
import 'package:fl_chart/fl_chart.dart';
import '../providers/dashboard_provider.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/components/atoms/app_card.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';
import '../core/design/tokens/app_colors.dart';
import '../core/design/tokens/app_radius.dart';
import '../core/design/tokens/app_iconography.dart';
import '../core/design/density/app_density.dart';
import '../l10n/app_localizations.dart';
import '../utils/theme.dart';
import '../utils/responsive.dart';

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
    final dashboardProvider = legacy_provider.Provider.of<DashboardProvider>(context, listen: false);

    return PosScaffold(
      title: AppLocalizations.t(context, 'overview'),
      actions: [
        _buildPeriodSelector(context, reportingState.selectedPeriod),
        if (!Responsive.isMobile(context))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: InkWell(
              onTap: () => dashboardProvider.setUIStyle(UIStyle.car_dashboard),
              borderRadius: AppRadius.borderMd,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.8),
                  borderRadius: AppRadius.borderMd,
                  border: Border.all(color: Theme.of(context).colorScheme.onSecondaryContainer.withValues(alpha: 0.1)),
                ),
                child: Icon(Icons.speed, size: AppIconography.md, color: Theme.of(context).colorScheme.onSecondaryContainer),
              ),
            ),
          ),
      ],
      mainContent: reportingState.isComputing && stats == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(reportingProvider.notifier).computeStats(),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.all(AppDensityProvider.configOf(context).cardPadding),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (reportingState.smartInsights.isNotEmpty)
                          _buildInsightsCarousel(context, reportingState.smartInsights),
                        
                        const SizedBox(height: AppSpacing.lg),
                      ]),
                    ),
                  ),

                  // 1. KPI Grid
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: AppDensityProvider.configOf(context).cardPadding),
                    sliver: _buildKpiSliverGrid(context, stats),
                  ),

                  SliverPadding(
                    padding: EdgeInsets.all(AppDensityProvider.configOf(context).cardPadding),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: AppSpacing.xl),
                        
                        // 2. Weekly Trend
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppColors.adaptivePrimary(context),
                                borderRadius: AppRadius.borderSm,
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
                                color: AppColors.adaptiveWarning(context),
                                borderRadius: AppRadius.borderSm,
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
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context, ReportPeriod current) {
    final theme = Theme.of(context);
    final iconColor = theme.appBarTheme.foregroundColor ?? theme.textTheme.bodyLarge?.color;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.textPrimaryLight).withValues(alpha: 0.05),
          borderRadius: AppRadius.borderMd,
          border: Border.all(color: (iconColor ?? AppColors.textPrimaryLight).withValues(alpha: 0.1)),
        ),
        child: PopupMenuButton<ReportPeriod>(
          icon: Icon(Icons.calendar_today_rounded, size: AppIconography.md, color: iconColor),
          padding: EdgeInsets.zero,
          initialValue: current,
          onSelected: (period) => ref.read(reportingProvider.notifier).setPeriod(period),
          itemBuilder: (context) => ReportPeriod.values.map((p) => PopupMenuItem(
            value: p,
            child: Text(p.toString().split('.').last.toUpperCase()),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildInsightsCarousel(BuildContext context, List<String> insights) {
    final primaryColor = AppColors.adaptivePrimary(context);
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
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: AppRadius.borderMd,
            border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: primaryColor, size: AppIconography.sm),
              const SizedBox(width: AppSpacing.sm),
              Text(insights[index], style: AppTypography.labelMedium.copyWith(color: primaryColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiSliverGrid(BuildContext context, dynamic stats) {
    final cards = [
      _KpiData(
        title: AppLocalizations.t(context, 'period_sales'), 
        value: "₹${stats?.totalSales.toStringAsFixed(0) ?? '0'}", 
        icon: Icons.payments_rounded, 
        color: const Color(0xFF6366F1), 
        gradient: const [Color(0xFF6366F1), Color(0xFF4F46E5)]
      ),
      _KpiData(
        title: AppLocalizations.t(context, 'orders'), 
        value: "${stats?.totalOrders ?? '0'}", 
        icon: Icons.shopping_basket_rounded, 
        color: const Color(0xFFF97316), 
        gradient: const [Color(0xFFF97316), Color(0xFFEA580C)]
      ),
      _KpiData(
        title: AppLocalizations.t(context, 'avg_order'), 
        value: "₹${stats?.avgOrderValue.toStringAsFixed(0) ?? '0'}", 
        icon: Icons.pie_chart_rounded, 
        color: const Color(0xFFD946EF), 
        gradient: const [Color(0xFFD946EF), Color(0xFF8B5CF6)]
      ),
      _KpiData(
        title: AppLocalizations.t(context, 'today_sales'), 
        value: "₹${stats?.todaySales.toStringAsFixed(0) ?? '0'}", 
        icon: Icons.today_rounded, 
        color: const Color(0xFF10B981), 
        gradient: const [Color(0xFF10B981), Color(0xFF059669)]
      ),
    ];

    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 4;
    if (width < 600) {
      crossAxisCount = 1;
    } else if (width < 900) {
      crossAxisCount = 2;
    } else if (width < 1200) {
      crossAxisCount = 3;
    }

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        mainAxisExtent: 160,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _PremiumKpiCard(data: cards[index], index: index),
        childCount: cards.length,
      ),
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

    final maxVal = items.isNotEmpty ? ((items[0]['value'] as num?)?.toDouble() ?? (items[0]['quantity'] as num?)?.toDouble() ?? 1.0) : 1.0;

    return AppCard(
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final double itemValue = (item['value'] as num?)?.toDouble() ?? (item['quantity'] as num?)?.toDouble() ?? 0.0;
          final double percent = maxVal > 0 ? itemValue / maxVal : 0.0;

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
                      shape: BoxShape.rectangle,
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
                              "₹${itemValue.toStringAsFixed(0)}",
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold, 
                                color: AppColors.adaptivePrimary(context)
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
                                borderRadius: AppRadius.borderCircular,
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: percent,
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      index == 0 ? AppColors.adaptiveWarning(context) : AppColors.adaptivePrimary(context),
                                      index == 0 ? AppColors.adaptiveWarning(context).withValues(alpha: 0.6) : AppColors.adaptivePrimary(context).withValues(alpha: 0.6),
                                    ],
                                  ),
                                  borderRadius: AppRadius.borderCircular,
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

  _KpiData({
    required this.title, 
    required this.value, 
    required this.icon, 
    required this.color, 
    required this.gradient,
  });
}

class _PremiumKpiCard extends StatefulWidget {
  final _KpiData data;
  final int index;

  const _PremiumKpiCard({required this.data, required this.index});

  @override
  State<_PremiumKpiCard> createState() => _PremiumKpiCardState();
}

class _PremiumKpiCardState extends State<_PremiumKpiCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final density = AppDensityProvider.configOf(context);
    
    final gradient = LinearGradient(
      colors: widget.data.gradient,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (widget.index * 100)),
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
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..translate(0.0, _isHovered ? -6.0 : 0.0)
            ..scale(_isHovered ? 1.03 : 1.0),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: AppRadius.borderLg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              if (_isHovered)
                BoxShadow(
                  color: widget.data.color.withOpacity(0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(_isHovered ? 0.35 : 0.15),
              width: _isHovered ? 1.5 : 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.borderLg,
            child: Stack(
              children: [
                // Background Decorative Gradient Icon
                Positioned(
                  right: -15,
                  bottom: -15,
                  child: AnimatedScale(
                    scale: _isHovered ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: AnimatedRotation(
                      turns: _isHovered ? -0.04 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        widget.data.icon,
                        size: 90,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ),
                ),
                // Glass overlay on hover
                if (_isHovered)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.06),
                            Colors.white.withOpacity(0.0),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(density.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(_isHovered ? 0.25 : 0.15),
                              borderRadius: AppRadius.borderMd,
                            ),
                            child: Icon(
                              widget.data.icon, 
                              color: Colors.white, 
                              size: AppIconography.md
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        widget.data.value,
                        style: AppTypography.headlineMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.data.title.toUpperCase(),
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.7),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
    final primaryColor = AppColors.adaptivePrimary(context);

    return AppCard(
      height: 300,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
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
                reservedSize: 64,
                getTitlesWidget: (value, meta) {
                  String formattedText;
                  final double val = value;
                  if (val >= 10000000) {
                    formattedText = '₹${(val / 10000000).toStringAsFixed(1)}Cr';
                  } else if (val >= 100000) {
                    formattedText = '₹${(val / 100000).toStringAsFixed(1)}L';
                  } else if (val >= 1000) {
                    final double kVal = val / 1000;
                    formattedText = '₹${kVal % 1 == 0 ? kVal.toInt().toString() : kVal.toStringAsFixed(1)}K';
                  } else {
                    formattedText = '₹${val.toInt()}';
                  }
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8,
                    child: Text(
                      formattedText,
                      style: AppTypography.labelMedium.copyWith(
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
              tooltipBgColor: isDark ? AppColors.surfaceVariant(context) : AppColors.surfaceLight,
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  final flSpot = barSpot;
                  return LineTooltipItem(
                    '${data[flSpot.x.toInt()]['day']}\n',
                    AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary(context),
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: '₹${flSpot.y.toStringAsFixed(0)}',
                        style: AppTypography.titleMedium.copyWith(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['sales'] as num?)?.toDouble() ?? 0.0)).toList(),
              isCurved: true,
              gradient: LinearGradient(colors: [primaryColor, primaryColor.withValues(alpha: 0.6)]),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.surfaceLight,
                  strokeWidth: 3,
                  strokeColor: primaryColor,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withValues(alpha: 0.3),
                    primaryColor.withValues(alpha: 0.0),
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




