import '../../core/design/tokens/app_colors.dart';
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
                  onPrimary: Colors.white,
                  surface: AppColors.surface(context),
                  onSurface: Colors.white,
                )
              : ColorScheme.light(
                  primary: Theme.of(context).primaryColor,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                      const SizedBox(width: 12),
                      Text(
                        "${DateFormat('MMM dd, yyyy').format(_dateRange.start)} - ${DateFormat('MMM dd, yyyy').format(_dateRange.end)}",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_drop_down, color: isDark ? Colors.white54 : AppColors.textSecondary(context)),
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
                      color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.03), 
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
                        color: isDark ? Colors.white : Colors.black87,
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
                                    final style = TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black, 
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 12
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
                      color: isDark ? Colors.white : Colors.black87,
                    )
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.zero,
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.05), 
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
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.zero,
                          ),
                          child: _buildRowItem("Gross Profit", grossProfit, isPositive: true, isBold: true),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
      )
    );
  }

  Widget _buildRowItem(String label, double amount, {bool isPositive = true, bool isBold = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label, 
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isBold ? 16 : 14,
            color: isBold 
              ? (isDark ? Colors.white : Colors.black87) 
              : (isDark ? Colors.white70 : AppColors.textSecondary(context)),
          )
        ),
        Text(
          "${isPositive ? '' : '- '}₹${amount.toStringAsFixed(2)}", 
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isBold ? 18 : 16,
            color: isPositive ? AppColors.success : AppColors.error,
          )
        ),
      ],
    );
  }
}

