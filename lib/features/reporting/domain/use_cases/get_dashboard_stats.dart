import 'package:flutter/foundation.dart';
import 'package:biztonic_pos/core/base/use_case.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/features/reporting/domain/entities/report_period.dart';
import 'package:biztonic_pos/features/reporting/domain/entities/dashboard_stats.dart';
import 'package:biztonic_pos/services/repository.dart';

class GetDashboardStatsParams {
  final List<OrderModel> orders;
  final String? activeStoreId;
  final ReportPeriod period;
  final bool isNative;

  GetDashboardStatsParams({
    required this.orders,
    this.activeStoreId,
    required this.period,
    this.isNative = false,
  });
}

class GetDashboardStatsUseCase extends UseCase<GetDashboardStatsParams, DashboardStats> {
  final Repository repository;

  GetDashboardStatsUseCase(this.repository);

  @override
  Future<DashboardStats> execute(GetDashboardStatsParams params) async {
    final orders = params.orders;
    final storeId = params.activeStoreId;
    final period = params.period;

    // 1. Calculate Smart Stats (Top level metrics)
    int sqlTodayCount = 0;
    int sqlMonthCount = 0;
    
    if (params.isNative && storeId != null) {
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final yearMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";
      sqlTodayCount = await repository.getDailyOrderCount(storeId, dateStr);
      sqlMonthCount = await repository.getMonthlyOrderCount(storeId, yearMonth);
    }

    final smartStats = await compute(_calcSmartStatsTask, {
      'orders': orders,
      'sqlTodayCount': sqlTodayCount,
      'sqlMonthCount': sqlMonthCount,
      'isNative': params.isNative,
    });

    // 2. Calculate Weekly Sales
    final weeklySales = await compute(_calcWeeklySalesTask, {'orders': orders, 'period': period});

    // 3. Calculate Top Products
    final topProducts = await compute(_calcTopProductsTask, {'orders': orders, 'period': period});

    // 4. Calculate Actual Sales Data
    final actualSalesData = await compute(_calcActualSalesTask, {'orders': orders, 'period': period});

    final startDate = _getStartDateForPeriod(period);

    // 5. Calculate Category Stats
    final categorySales = await compute(_calcCategorySalesTask, {'orders': orders, 'startDate': startDate});

    // 6. Calculate Sales Report
    final salesReport = await compute(_calcSalesReportTask, {'orders': orders, 'startDate': startDate});

    // 7. Calculate Payment Stats
    final paymentStats = await compute(_calcPaymentStatsTask, {'orders': orders, 'startDate': startDate});

    // 8. Calculate Rushed Hours
    final rushedHours = await compute(_calcRushedHoursTask, {'orders': orders});

    return DashboardStats(
      totalSales: (smartStats['totalSales'] as num?)?.toDouble() ?? 0.0,
      totalOrders: (smartStats['totalOrders'] as num?)?.toInt() ?? 0,
      todaySales: (smartStats['todaySales'] as num?)?.toDouble() ?? 0.0,
      todayOrders: (smartStats['todayOrders'] as num?)?.toInt() ?? 0,
      monthSales: (smartStats['monthSales'] as num?)?.toDouble() ?? 0.0,
      monthOrders: (smartStats['monthOrders'] as num?)?.toInt() ?? 0,
      avgDailySale: (smartStats['avgDailySale'] as num?)?.toDouble() ?? 0.0,
      avgOrderValue: (smartStats['avgOrderValue'] as num?)?.toDouble() ?? 0.0,
      weeklySales: weeklySales,
      topProducts: topProducts,
      actualSalesData: actualSalesData,
      categorySales: categorySales,
      salesReport: salesReport,
      paymentStats: paymentStats,
      peakHour: rushedHours['peakHour'] ?? 0,
      leastHour: rushedHours['leastHour'] ?? 0,
    );
  }

  DateTime _getStartDateForPeriod(ReportPeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case ReportPeriod.today: return today;
      case ReportPeriod.yesterday: return today.subtract(const Duration(days: 1));
      case ReportPeriod.last7Days: return today.subtract(const Duration(days: 7));
      case ReportPeriod.last30Days: return today.subtract(const Duration(days: 30));
      case ReportPeriod.custom: return today.subtract(const Duration(days: 7));
    }
  }

  // --- STATIC CALCULATORS ---

  static Map<String, dynamic> _calcSmartStatsTask(Map<String, dynamic> params) {
    final List<OrderModel> data = params['orders'];
    final int sqlTodayCount = params['sqlTodayCount'];
    final int sqlMonthCount = params['sqlMonthCount'];
    final bool isNative = params['isNative'];
    
    double totalSales = 0;
    double todaySales = 0;
    int todayCount = 0;
    int monthCount = 0;
    double monthSales = 0;
    final now = DateTime.now();

    for (var o in data) {
        if (o.status == 'Cancelled' || o.status == 'VOID') continue;
        
        double orderTotal = o.status == 'Refunded' ? 0 : o.total;
        totalSales += orderTotal;

        if (o.date.day == now.day && o.date.month == now.month && o.date.year == now.year) {
            todaySales += orderTotal;
            if (o.status != 'Refunded') todayCount++;
        }
        if (o.date.month == now.month && o.date.year == now.year) {
            monthSales += orderTotal;
            if (o.status != 'Refunded') monthCount++;
        }
    }
    
    final finalTodayCount = isNative ? sqlTodayCount : todayCount;
    final finalMonthCount = isNative ? sqlMonthCount : monthCount;

    return {
       'totalSales': totalSales,
       'totalOrders': data.length,
       'todaySales': todaySales,
       'todayOrders': finalTodayCount,
       'monthSales': monthSales,
       'monthOrders': finalMonthCount,
       'avgDailySale': monthSales / 30,
       'avgOrderValue': data.isNotEmpty ? totalSales / data.length : 0.0
    };
  }

  static List<Map<String, dynamic>> _calcWeeklySalesTask(Map<String, dynamic> params) {
      final List<OrderModel> dataOrders = params['orders'];
      final ReportPeriod selectedPeriod = params['period'];
      
      int days = 7;
      if (selectedPeriod == ReportPeriod.today) {
        days = 1;
      } else if (selectedPeriod == ReportPeriod.yesterday) {
        days = 2; 
      } else if (selectedPeriod == ReportPeriod.last30Days) {
        days = 30;
      }

      final now = DateTime.now();
      List<Map<String, dynamic>> data = [];
      for (int i = days - 1; i >= 0; i--) {
          final day = now.subtract(Duration(days: i));
          final dayOrders = dataOrders.where((o) => 
            o.date.day == day.day && 
            o.date.month == day.month && 
            o.date.year == day.year && 
            o.status != 'Cancelled' && 
            o.status != 'VOID' && 
            o.status != 'Refunded'
          ).toList();
          double sum = 0;
          for(var o in dayOrders) {
            sum += o.total;
          }
          data.add({'day': "${day.day}/${day.month}", 'sales': sum});
      }
      return data;
  }

  static List<Map<String, dynamic>> _calcTopProductsTask(Map<String, dynamic> params) {
      final List<OrderModel> dataOrders = params['orders'];
      final ReportPeriod selectedPeriod = params['period'];
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      DateTime startDate;
      switch (selectedPeriod) {
          case ReportPeriod.today: startDate = today; break;
          case ReportPeriod.yesterday: startDate = today.subtract(const Duration(days: 1)); break;
          case ReportPeriod.last7Days: startDate = today.subtract(const Duration(days: 7)); break;
          case ReportPeriod.last30Days: startDate = today.subtract(const Duration(days: 30)); break;
          case ReportPeriod.custom: startDate = today.subtract(const Duration(days: 7)); break;
      }

      final sales = <String, int>{};
      for (var o in dataOrders) {
          if (o.status == 'Cancelled' || o.status == 'VOID' || o.status == 'Refunded') continue;
          if (o.date.isBefore(startDate)) continue;
          for (var item in o.items) {
             final int qty = item.quantity.toInt();
             sales[item.item.name] = (sales[item.item.name] ?? 0) + qty;
          }
      }
      final sortedKeys = sales.keys.toList()..sort((a,b) => sales[b]!.compareTo(sales[a]!));
      return sortedKeys.take(5).map((k) => {'name': k, 'quantity': sales[k], 'revenue': 0.0}).toList();
  }

  static List<Map<String, dynamic>> _calcActualSalesTask(Map<String, dynamic> params) {
      final List<OrderModel> orders = params['orders'];
      final ReportPeriod selectedPeriod = params['period'];
      
      int days = 7;
      if (selectedPeriod == ReportPeriod.today) {
        days = 1;
      } else if (selectedPeriod == ReportPeriod.yesterday) {
        days = 2;
      } else if (selectedPeriod == ReportPeriod.last30Days) {
        days = 30;
      }

      final now = DateTime.now();
      final Map<String, double> salesMap = {};
      final List<String> orderedKeys = [];
      for (int i = days - 1; i >= 0; i--) {
          final day = now.subtract(Duration(days: i));
          final key = "${day.day}/${day.month}";
          salesMap[key] = 0.0;
          orderedKeys.add(key);
      }
      for (var o in orders) {
          if (o.status == 'Cancelled' || o.status == 'VOID' || o.status == 'Refunded') continue;
          final diff = now.difference(o.date).inDays;
          if (diff < days && diff >= 0) {
             final key = "${o.date.day}/${o.date.month}";
             if (salesMap.containsKey(key)) {
                salesMap[key] = (salesMap[key] ?? 0) + o.total;
             }
          }
      }
      return orderedKeys.map((key) => {'day': key, 'sales': salesMap[key]!, 'isForecast': false}).toList();
  }

  static Map<String, double> _calcCategorySalesTask(Map<String, dynamic> params) {
      final List<OrderModel> orders = params['orders'];
      final DateTime startDate = params['startDate'];
      
      Map<String, double> stats = {};
      double grossSales = 0;
      bool hasRecentOrders = false;

      for (var o in orders) {
         if (o.status == 'Cancelled' || o.status == 'VOID' || o.status == 'Refunded') continue;
         if (o.date.isBefore(startDate)) continue;
         
         hasRecentOrders = true;
         grossSales += o.total;
         
         for (var orderItem in o.items) {
            final category = orderItem.category ?? orderItem.item.category;
            stats[category] = (stats[category] ?? 0.0) + (orderItem.item.price * orderItem.quantity);
         }
      }
      
      if (stats.isEmpty && hasRecentOrders) {
          stats['Uncategorized'] = grossSales;
      }
      return stats;
  }

  static Map<String, dynamic> _calcSalesReportTask(Map<String, dynamic> params) {
      final List<OrderModel> orders = params['orders'];
      final DateTime startDate = params['startDate'];
      
      final periodOrders = orders.where((o) => o.date.isAfter(startDate)).toList();
      final activeOrders = periodOrders.where((o) => o.status != 'Cancelled' && o.status != 'VOID' && o.status != 'Refunded').toList();
      final totalSales = activeOrders.fold(0.0, (sum, o) => sum + o.total);
      
      final refundedCount = periodOrders.where((o) => o.status == 'Refunded').length;
      
      return {
         'totalSales': totalSales, 
         'totalOrders': activeOrders.length,
         'cancelled': periodOrders.where((o) => o.status == 'Cancelled').length,
         'refunded': refundedCount,
         'averageOrderValue': activeOrders.isNotEmpty ? totalSales / activeOrders.length : 0.0,
      };
  }

  static Map<String, double> _calcPaymentStatsTask(Map<String, dynamic> params) {
    final List<OrderModel> orders = params['orders'];
    final DateTime startDate = params['startDate'];
    
    Map<String, double> stats = {};
    for (var o in orders) {
      if (o.status == 'Cancelled' || o.status == 'VOID') continue;
      if (o.date.isBefore(startDate)) continue;

      final method = o.paymentMethod.isEmpty ? 'Unknown' : o.paymentMethod;
      final double orderValue = o.status == 'Refunded' ? 0.0 : o.total;
      
      stats[method] = (stats[method] ?? 0.0) + orderValue;
    }
    return stats;
  }

  static Map<String, int> _calcRushedHoursTask(Map<String, dynamic> params) {
    final List<OrderModel> orders = params['orders'];
    Map<int, int> hourlyCounts = {};
    for (var o in orders) {
      int hour = o.date.hour;
      hourlyCounts[hour] = (hourlyCounts[hour] ?? 0) + 1;
    }

    int peakHour = 0;
    int peakCount = -1;
    int leastHour = 0;
    int leastCount = 999999;

    for (int h = 0; h < 24; h++) {
      int count = hourlyCounts[h] ?? 0;
      if (count > peakCount) {
        peakCount = count;
        peakHour = h;
      }
      if (h >= 9 && h <= 21) {
         if (count < leastCount) {
            leastCount = count;
            leastHour = h;
         }
      }
    }
    return {'peakHour': peakHour, 'leastHour': leastHour};
  }
}
