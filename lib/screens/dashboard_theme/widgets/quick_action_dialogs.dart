import '../../../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

// ignore_for_file: dead_null_aware_expression
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../models/order_model.dart';
import '../../../utils/car_dashboard_theme.dart';
import 'neon_button.dart';

// --- LAST BILL DIALOG ---
class LastFiveBillsDialog extends StatelessWidget {
  const LastFiveBillsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    // Get last 5 orders, assuming they are ordered by date? Usually they are added in order.
    // If not, we should sort. For now assume list order is chronological, so reverse it.
    final orders = provider.orders.reversed.take(5).toList();

    return Dialog(
      backgroundColor: CarDashboardTheme.panelColor(true).withValues(alpha: 0.95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: CarDashboardTheme.neonBlue, width: 2),
      ),
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: CarDashboardTheme.neonBlue, size: 28),
                const SizedBox(width: AppSpacing.md),
                Text(AppLocalizations.t(context, 'LAST 5 BILLS'), style: const TextStyle(color: AppColors.surfaceLight, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, color: AppColors.textHintDark), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(color: Colors.white24, height: 30),
            Expanded(
              child: orders.isEmpty 
                  ? Center(child: Text(AppLocalizations.t(context, 'No Sales History Found'), style: const TextStyle(color: AppColors.textHintDark)))
                  : ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (ctx, i) => _buildOrderTile(context, orders[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTile(BuildContext context, OrderModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.05),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("#${order.shortId}", style: const TextStyle(color: CarDashboardTheme.neonBlue, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.xs),
              Text(DateFormat('hh:mm a').format(order.date), style: const TextStyle(color: AppColors.textHintDark, fontSize: 12)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("?${order.total.toStringAsFixed(2)}", style: const TextStyle(color: CarDashboardTheme.electricGreen, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: AppSpacing.xs),
              Text("${order.items.length} Items", style: const TextStyle(color: AppColors.textHintDark, fontSize: 12)),
            ],
          ),
          
          // Reprint Action? (User didn't explicitly ask for action, but typical 'Last Bill' implies Reprint or View)
          // We'll just standard view for now.
        ],
      ),
    );
  }
}


// --- REFUND DIALOG ---
class RefundDialog extends StatelessWidget {
  const RefundDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final orders = provider.orders.reversed.take(5).toList();

    return Dialog(
      backgroundColor: CarDashboardTheme.panelColor(true).withValues(alpha: 0.95),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: CarDashboardTheme.alertRed, width: 2),
      ),
      child: Container(
        width: 700,
        height: 600,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.restart_alt, color: CarDashboardTheme.alertRed, size: 28),
                const SizedBox(width: AppSpacing.md),
                Text(AppLocalizations.t(context, 'QUICK REFUND (LAST 5)'), style: const TextStyle(color: AppColors.surfaceLight, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, color: AppColors.textHintDark), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(color: Colors.white24, height: 30),
            Expanded(
              child: orders.isEmpty 
                  ? Center(child: Text(AppLocalizations.t(context, 'No Orders Found'), style: const TextStyle(color: AppColors.textHintDark)))
                  : ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (ctx, i) => _buildRefundTile(context, orders[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefundTile(BuildContext context, OrderModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.05),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Order #${order.shortId}", style: const TextStyle(color: AppColors.surfaceLight, fontWeight: FontWeight.bold)),
                Text("${order.items.length} Items ï¿½ ${DateFormat('hh:mm a').format(order.date)}", style: const TextStyle(color: AppColors.textHintDark, fontSize: 12)),
              ],
            ),
          ),
          
          Text("?${order.total.toStringAsFixed(2)}", style: const TextStyle(color: AppColors.surfaceLight, fontWeight: FontWeight.bold, fontSize: 18)),
          
          const SizedBox(width: AppSpacing.lg),
          
          NeonButton(
            label: "REFUND",
            color: CarDashboardTheme.alertRed,
            isLarge: false,
            onPressed: () {
              // Action: Confirm Refund
              // For now show snackbar as full refund logic might be complex
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'Refund Requested (Feature Placeholder)')), backgroundColor: CarDashboardTheme.alertRed));
            },
          )
        ],
      ),
    );
  }
}


// --- QUICK DAY REPORT DIALOG ---
class QuickDayReportDialog extends StatelessWidget {
  const QuickDayReportDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    // Calculate Day Stats
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    final todayOrders = provider.orders.where((o) => o.date.isAfter(todayStart)).toList();
    final totalSales = todayOrders.fold(0.0, (sum, o) => sum + o.total);
    final totalCount = todayOrders.length;
    
    // Simple Category Pie Chart Data
    // We'll aggregate sales by 'category' (assuming items have categories)
    // Actually items in OrderModel are OrderItem
    // OrderItem: name, price, quantity. Category might not be directly on OrderItem unless we look up inventory?
    // Let's check OrderItem definition. Usually it has minimal data.
    // If not available, we will chart Payment Methods (Cash vs UPI) which is usually on Order.
    bool hasPaymentMethod = todayOrders.isNotEmpty;
    
    Map<String, double> pieData = {};
    if (hasPaymentMethod) {
       for (var o in todayOrders) {
         final method = o.paymentMethod ?? 'Unknown';
         pieData[method] = (pieData[method] ?? 0) + o.total;
       }
    } else {
        pieData = {'Sales': totalSales};
    }

    return Dialog(
       backgroundColor: CarDashboardTheme.panelColor(true).withValues(alpha: 0.95),
       shape: const RoundedRectangleBorder(
         borderRadius: BorderRadius.zero,
         side: BorderSide(color: CarDashboardTheme.electricGreen, width: 2),
       ),
       child: Container(
         width: 800,
         height: 600,
         padding: const EdgeInsets.all(AppSpacing.lg),
         child: Column(
           children: [
             Row(
               children: [
                 const Icon(Icons.bar_chart, color: CarDashboardTheme.electricGreen, size: 28),
                 const SizedBox(width: AppSpacing.md),
                 Text(AppLocalizations.t(context, 'DAY REPORT (QUICK VIEW)'), style: const TextStyle(color: AppColors.surfaceLight, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                 const Spacer(),
                 IconButton(icon: const Icon(Icons.close, color: AppColors.textHintDark), onPressed: () => Navigator.pop(context)),
               ],
             ),
             
             const Divider(color: Colors.white24, height: 30),
             
             Expanded(
               child: Row(
                 children: [
                   // Left: Stats
                   Expanded(
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         _buildStatBox("TOTAL SALES", "?${totalSales.toStringAsFixed(0)}", CarDashboardTheme.electricGreen),
                         const SizedBox(height: AppSpacing.lg),
                         _buildStatBox("TOTAL ORDERS", "$totalCount", CarDashboardTheme.neonBlue),
                         const SizedBox(height: AppSpacing.lg),
                         _buildStatBox("AVG BILL", "?${totalCount > 0 ? (totalSales/totalCount).toStringAsFixed(0) : '0'}", AppColors.warning),
                       ],
                     ),
                   ),
                   
                   // Right: Pie Chart
                   Expanded(
                     child: todayOrders.isEmpty 
                         ? Center(child: Text(AppLocalizations.t(context, 'No Data Today'), style: const TextStyle(color: AppColors.textHintDark)))
                         : PieChart(
                             PieChartData(
                               sectionsSpace: 4,
                               centerSpaceRadius: 50,
                               sections: pieData.entries.map((e) {
                                 final color = e.key.toLowerCase().contains('cash') ? CarDashboardTheme.electricGreen : 
                                               e.key.toLowerCase().contains('upi') ? CarDashboardTheme.neonBlue : AppColors.warning;
                                 return PieChartSectionData(
                                   color: color,
                                   value: e.value,
                                   title: "${e.key}\n${((e.value/totalSales)*100).toStringAsFixed(0)}%",
                                   radius: 80,
                                   titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.surfaceLight),
                                 );
                               }).toList(),
                             ),
                           ),
                   ),
                 ],
               ),
             )
           ],
         ),
       ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 14)),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
        ],
      ),
    );
  }
}

