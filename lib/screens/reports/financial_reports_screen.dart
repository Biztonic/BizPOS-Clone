import '../../core/design/tokens/app_colors.dart';
import '../../core/design/tokens/app_radius.dart';
import '../../core/design/tokens/app_typography.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'package:flutter/material.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/report_stat_card.dart';
import '../../utils/export_utils.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class FinancialReportsScreen extends StatefulWidget {
  const FinancialReportsScreen({super.key});

  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen> {

  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );
  Map<String, dynamic>? _stats;
  bool _isLoading = false;

  String _categorySortBy = 'sales';
  bool _categorySortDescending = true;

  String _daySortBy = 'date';
  bool _daySortDescending = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<OrderProvider>(context, listen: false);
    final activeStoreId = provider.syncService.activeStoreId;
    if (activeStoreId != null) {
      final stats = await provider.fetchStats(
        activeStoreId,
        start: _dateRange.start,
        end: _dateRange.end,
      );
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark 
              ? ColorScheme.dark(
                  primary: Theme.of(context).primaryColor,
                  onPrimary: AppColors.surfaceLight,
                  surface: AppColors.surface(context),
                  onSurface: AppColors.surfaceLight,
                )
              : ColorScheme.light(
                  primary: Theme.of(context).primaryColor,
                  onPrimary: AppColors.surfaceLight,
                  surface: AppColors.surfaceLight,
                  onSurface: AppColors.textPrimaryLight,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dateRange) {
      setState(() => _dateRange = picked);
      _loadStats();
    }
  }

  Future<void> _exportExcel() async {
    if (_stats == null) return;
    final totalRevenue = _stats!['totalSales'] ?? 0.0;
    final cogs = _stats!['totalCogs'] ?? 0.0;
    final grossProfit = _stats!['grossProfit'] ?? 0.0;
    final cashPayments = _stats!['cashSales'] ?? 0.0;
    final cardPayments = _stats!['cardSales'] ?? 0.0;
    try {
      final headers = ['Metric', 'Amount (₹)'];
      final rows = [
        ['Total Revenue', totalRevenue],
        ['Cost of Goods Sold (Est. 70%)', cogs],
        ['Gross Profit', grossProfit],
        [],
        ['Payment Breakdown', ''],
        ['Cash Collected', cashPayments],
        ['Card/Online', cardPayments],
      ];

      await ExportUtils.exportToExcel(
        fileName: 'Financial_Report',
        headers: headers,
        rows: rows,
        context: context,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'Export successful'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _stats == null) {
      return const PosScaffold(showGlobalActions: false, mainContent: Center(child: CircularProgressIndicator()));
    }

    final totalRevenue = _stats?['totalSales'] ?? 0.0;
    final cardPayments = _stats?['cardSales'] ?? 0.0;
    final cashPayments = _stats?['cashSales'] ?? 0.0;
    final cogs = _stats?['totalCogs'] ?? 0.0;
    final grossProfit = _stats?['grossProfit'] ?? 0.0;
    final categoryStats = _stats?['categoryStats'] as List<dynamic>? ?? [];
    final dayStats = _stats?['dayStats'] as List<dynamic>? ?? [];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sort Category Stats
    final List<Map<String, dynamic>> sortedCategoryStats = List.from(
      (categoryStats).map((e) => Map<String, dynamic>.from(e as Map))
    );
    sortedCategoryStats.sort((a, b) {
      int cmp = 0;
      if (_categorySortBy == 'sales') {
        cmp = (a['sales'] as num).compareTo(b['sales'] as num);
      } else if (_categorySortBy == 'profit') {
        cmp = (a['profit'] as num).compareTo(b['profit'] as num);
      } else {
        cmp = (a['category'] as String).compareTo(b['category'] as String);
      }
      return _categorySortDescending ? -cmp : cmp;
    });

    // Sort Day Stats
    final List<Map<String, dynamic>> sortedDayStats = List.from(
      (dayStats).map((e) => Map<String, dynamic>.from(e as Map))
    );
    sortedDayStats.sort((a, b) {
      int cmp = 0;
      if (_daySortBy == 'sales') {
        cmp = (a['sales'] as num).compareTo(b['sales'] as num);
      } else if (_daySortBy == 'profit') {
        cmp = (a['profit'] as num).compareTo(b['profit'] as num);
      } else {
        cmp = (a['day'] as String).compareTo(b['day'] as String);
      }
      return _daySortDescending ? -cmp : cmp;
    });

    return PosScaffold(
      showGlobalActions: false,
      mainContent: Container(
        color: AppColors.background(context),
        child: CustomScrollView(
        slivers: [
          // APP BAR
          SliverAppBar(
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/reports'),
            ),
            title: Text(AppLocalizations.t(context, 'Financial Reports'), style: const TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download),
                tooltip: "Export to Excel",
                onPressed: _exportExcel,
              ),
            ],
          ),

          // DATE RANGE SELECTOR
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: InkWell(
                onTap: _selectDateRange,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.zero,
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: Theme.of(context).primaryColor),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        "${DateFormat('MMM dd, yyyy').format(_dateRange.start)} - ${DateFormat('MMM dd, yyyy').format(_dateRange.end)}",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.surfaceLight : AppColors.textPrimaryLight,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_drop_down, color: isDark ? AppColors.textHintDark : AppColors.textSecondary(context)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // SUMMARY CARDS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                     children: [
                       ReportStatCard(
                         title: "Net Revenue", 
                         value: "₹${totalRevenue.toStringAsFixed(0)}", 
                         icon: Icons.account_balance_wallet,
                         baseColor: AppColors.success,
                       ),
                     ],
                   ),
                   const SizedBox(height: AppSpacing.md),
                   Row(
                     children: [
                       ReportStatCard(
                         title: "Cash Collected", 
                         value: "₹${cashPayments.toStringAsFixed(0)}", 
                         baseColor: AppColors.warning, 
                         icon: Icons.money,
                       ),
                       const SizedBox(width: AppSpacing.md),
                       ReportStatCard(
                         title: "Card / Online", 
                         value: "₹${cardPayments.toStringAsFixed(0)}", 
                         baseColor: AppColors.primaryLight, 
                         icon: Icons.credit_card,
                       ),
                     ],
                   ),
                ],
              ),
            ),
          ),

          // BAR CHART
          if (totalRevenue > 0)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.zero,
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black26 : AppColors.textPrimaryLight.withValues(alpha: 0.03), 
                      blurRadius: 10, 
                      offset: const Offset(0, 4)
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.t(context, 'Revenue vs Costs vs Profit'), 
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.surfaceLight : AppColors.textPrimaryLight,
                      )
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: totalRevenue * 1.2,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                  getTitlesWidget: (double value, TitleMeta meta) {
                                    final style = AppTypography.labelMedium.copyWith(
                                      color: AppColors.textSecondary(context),
                                      fontWeight: FontWeight.bold,
                                    );
                                    Widget text;
                                    switch (value.toInt()) {
                                      case 0: text = Text(AppLocalizations.t(context, 'Revenue'), style: style); break;
                                      case 1: text = Text(AppLocalizations.t(context, 'COGS'), style: style); break;
                                      case 2: text = Text(AppLocalizations.t(context, 'Profit'), style: style); break;
                                      default: text = Text('', style: style); break;
                                    }
                                    return SideTitleWidget(axisSide: meta.axisSide, child: text);
                                  },
                              ),
                            ),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barGroups: [
                            BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: totalRevenue, color: AppColors.primaryLight, width: 22, borderRadius: BorderRadius.zero)]),
                            BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: cogs, color: AppColors.error, width: 22, borderRadius: BorderRadius.zero)]),
                            BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: grossProfit, color: AppColors.success, width: 22, borderRadius: BorderRadius.zero)]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // P&L TABLE
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.t(context, 'Profit & Loss (Estimated)'), 
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.surfaceLight : AppColors.textPrimaryLight,
                    )
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: AppRadius.borderSm,
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black26 : AppColors.textPrimaryLight.withValues(alpha: 0.05), 
                          blurRadius: 10, 
                          offset: const Offset(0, 4)
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildRowItem("Total Revenue", totalRevenue, isPositive: true),
                        const Divider(height: 24),
                        _buildRowItem("Cost of Goods Sold", cogs, isPositive: false),
                        const Divider(height: 24),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.success.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.08),
                            borderRadius: AppRadius.borderSm,
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                          ),
                          child: _buildRowItem("Gross Profit", grossProfit, isPositive: true, isBold: true, isGrossProfit: true),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),

          // Category-wise Profit
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: _buildCategoryStatsCard(sortedCategoryStats),
            ),
          ),

          // Day-wise Profit
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: _buildDayStatsCard(sortedDayStats),
            ),
          ),
        ],
      ),
      )
    );
  }

  Widget _buildRowItem(String label, double amount, {bool isPositive = true, bool isBold = false, bool isGrossProfit = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color labelColor;
    Color amountColor;
    
    if (isGrossProfit) {
      labelColor = AppColors.adaptiveSuccess(context);
      amountColor = AppColors.adaptiveSuccess(context);
    } else {
      labelColor = isBold 
          ? (isDark ? AppColors.surfaceLight : AppColors.textPrimaryLight) 
          : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary(context));
      amountColor = isPositive ? AppColors.success : AppColors.error;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label, 
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isBold ? 16 : 14,
            color: labelColor,
          )
        ),
        Text(
          "${isPositive ? '' : '- '}₹${amount.toStringAsFixed(2)}", 
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 18 : 16,
            color: amountColor,
          )
        ),
      ],
    );
  }

  Widget _buildCategoryStatsCard(List<Map<String, dynamic>> categoryStats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: AppRadius.borderSm,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : AppColors.textPrimaryLight.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.t(context, 'Category-wise Profit'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.surfaceLight : AppColors.textPrimaryLight,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                tooltip: "Sort Categories",
                onSelected: (val) {
                  setState(() {
                    if (val == 'sales') {
                      _categorySortBy = 'sales';
                      _categorySortDescending = !_categorySortDescending;
                    } else if (val == 'profit') {
                      _categorySortBy = 'profit';
                      _categorySortDescending = !_categorySortDescending;
                    } else {
                      _categorySortBy = 'category';
                      _categorySortDescending = !_categorySortDescending;
                    }
                  });
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'sales', child: Text("Sort by Sales (${_categorySortBy == 'sales' && _categorySortDescending ? 'Asc' : 'Desc'})")),
                  PopupMenuItem(value: 'profit', child: Text("Sort by Profit (${_categorySortBy == 'profit' && _categorySortDescending ? 'Asc' : 'Desc'})")),
                  PopupMenuItem(value: 'category', child: Text("Sort by Name (${_categorySortBy == 'category' && _categorySortDescending ? 'Asc' : 'Desc'})")),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (categoryStats.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text("No category data available", style: TextStyle(color: AppColors.textSecondary(context))),
              ),
            )
          else ...[
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  children: [
                    Text("Category", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary(context))),
                    Text("Sales", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary(context)), textAlign: TextAlign.right),
                    Text("Profit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary(context)), textAlign: TextAlign.right),
                  ],
                ),
                ...categoryStats.map((stat) {
                  final sales = stat['sales'] as double;
                  final profit = stat['profit'] as double;
                  final profitPct = sales > 0 ? (profit / sales) * 100 : 0.0;
                  
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(stat['category'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            Text("Margin: ${profitPct.toStringAsFixed(0)}%", style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text("₹${sales.toStringAsFixed(0)}", style: const TextStyle(fontSize: 14), textAlign: TextAlign.right),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          "₹${profit.toStringAsFixed(0)}", 
                          style: TextStyle(
                            fontSize: 14, 
                            fontWeight: FontWeight.w600,
                            color: profit >= 0 ? AppColors.success : AppColors.error,
                          ), 
                          textAlign: TextAlign.right
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayStatsCard(List<Map<String, dynamic>> dayStats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: AppRadius.borderSm,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : AppColors.textPrimaryLight.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.t(context, 'Day-wise Profit'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.surfaceLight : AppColors.textPrimaryLight,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                tooltip: "Sort Days",
                onSelected: (val) {
                  setState(() {
                    if (val == 'sales') {
                      _daySortBy = 'sales';
                      _daySortDescending = !_daySortDescending;
                    } else if (val == 'profit') {
                      _daySortBy = 'profit';
                      _daySortDescending = !_daySortDescending;
                    } else {
                      _daySortBy = 'date';
                      _daySortDescending = !_daySortDescending;
                    }
                  });
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'date', child: Text("Sort by Date (${_daySortBy == 'date' && _daySortDescending ? 'Asc' : 'Desc'})")),
                  PopupMenuItem(value: 'sales', child: Text("Sort by Sales (${_daySortBy == 'sales' && _daySortDescending ? 'Asc' : 'Desc'})")),
                  PopupMenuItem(value: 'profit', child: Text("Sort by Profit (${_daySortBy == 'profit' && _daySortDescending ? 'Asc' : 'Desc'})")),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (dayStats.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text("No daily data available", style: TextStyle(color: AppColors.textSecondary(context))),
              ),
            )
          else ...[
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.5),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  children: [
                    Text("Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary(context))),
                    Text("Sales", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary(context)), textAlign: TextAlign.right),
                    Text("Profit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary(context)), textAlign: TextAlign.right),
                  ],
                ),
                ...dayStats.map((stat) {
                  final sales = stat['sales'] as double;
                  final profit = stat['profit'] as double;
                  String dateDisplay = stat['day'] as String;
                  try {
                    final dt = DateTime.parse(stat['day'] as String);
                    dateDisplay = DateFormat('MMM dd, yyyy').format(dt);
                  } catch (_) {}

                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(dateDisplay, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text("₹${sales.toStringAsFixed(0)}", style: const TextStyle(fontSize: 13), textAlign: TextAlign.right),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          "₹${profit.toStringAsFixed(0)}", 
                          style: TextStyle(
                            fontSize: 13, 
                            fontWeight: FontWeight.w600,
                            color: profit >= 0 ? AppColors.success : AppColors.error,
                          ), 
                          textAlign: TextAlign.right
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

