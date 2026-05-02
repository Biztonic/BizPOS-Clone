import 'package:biztonic_pos/models/order_model.dart';

class DashboardStats {
  final double totalSales;
  final int totalOrders;
  final double todaySales;
  final int todayOrders;
  final double monthSales;
  final int monthOrders;
  final double avgDailySale;
  final double avgOrderValue;
  
  final List<Map<String, dynamic>> weeklySales;
  final List<Map<String, dynamic>> topProducts;
  final List<Map<String, dynamic>> actualSalesData;
  final Map<String, double> categorySales;
  final Map<String, dynamic> salesReport;
  final Map<String, double> paymentStats;
  final int peakHour;
  final int leastHour;

  DashboardStats({
    required this.totalSales,
    required this.totalOrders,
    required this.todaySales,
    required this.todayOrders,
    required this.monthSales,
    required this.monthOrders,
    required this.avgDailySale,
    required this.avgOrderValue,
    required this.weeklySales,
    required this.topProducts,
    required this.actualSalesData,
    required this.categorySales,
    required this.salesReport,
    required this.paymentStats,
    required this.peakHour,
    required this.leastHour,
  });

  factory DashboardStats.empty() {
    return DashboardStats(
      totalSales: 0,
      totalOrders: 0,
      todaySales: 0,
      todayOrders: 0,
      monthSales: 0,
      monthOrders: 0,
      avgDailySale: 0,
      avgOrderValue: 0,
      weeklySales: [],
      topProducts: [],
      actualSalesData: [],
      categorySales: {},
      salesReport: {},
      paymentStats: {},
      peakHour: 0,
      leastHour: 0,
    );
  }
}
