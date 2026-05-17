import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import 'package:biztonic_pos/providers/order_provider.dart';
import 'package:biztonic_pos/features/inventory/presentation/providers/inventory_provider.dart';

class SmartInsightsProvider with ChangeNotifier {
  final DashboardProvider _dashboardProvider;
  final OrderProvider _orderProvider;
  final InventoryProvider _inventoryProvider;
  Timer? _debounceTimer;

  SmartInsightsProvider(
    this._dashboardProvider,
    this._orderProvider,
    this._inventoryProvider,
  ) {
    _dashboardProvider.addListener(_recalculate);
    _orderProvider.addListener(_recalculate);
    _inventoryProvider.addListener(_recalculate);
  }

  // --- Level 1: Overview Metrics ---
  double get todaySales => _calculateTodaySales();
  int get todayOrders => _calculateTodayOrders();
  double get grossProfit => _calculateGrossProfit();
  double get cashInHand => _calculateCashInHand();
  int get lowStockCount => _calculateLowStockCount();
  double get creditOutstanding => _calculateCreditOutstanding();
  List<Map<String, dynamic>> get topItems => _calculateTopItems(limit: 3);
  double get salesVsYesterdayPercent => _calculateSalesGrowth();
  List<Map<String, dynamic>> get weeklyTrend => _calculateWeeklyTrend();

  // --- Level 2: Smart Insights ---
  List<String> get smartInsights => _generateSmartInsights();

  // --- Internal Calculation Logic ---

  void _recalculate() {
    // Debounce: wait 500ms after last change before notifying
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      notifyListeners();
    });
  }

  double _calculateTodaySales() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    return _orderProvider.orders
        .where((o) => o.date.isAfter(todayStart) && !['Cancelled', 'VOID', 'Refunded'].contains(o.status))
        .fold(0.0, (sum, order) => sum + order.total);
  }

  int _calculateTodayOrders() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    return _orderProvider.orders
        .where((o) => o.date.isAfter(todayStart) && !['Cancelled', 'VOID', 'Refunded'].contains(o.status))
        .length;
  }

  double _calculateGrossProfit() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    double totalRevenue = 0;
    double totalCost = 0;

    for (final order in _orderProvider.orders) {
      if (order.date.isBefore(todayStart) || ['Cancelled', 'VOID', 'Refunded'].contains(order.status)) continue;
      
      totalRevenue += order.total;
      // Estimate cost at 70% of revenue (30% margin) if not tracked
      totalCost += order.total * 0.7; 
    }
    
    return totalRevenue - totalCost;
  }

  double _calculateCashInHand() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return _orderProvider.orders
        .where((o) => o.date.isAfter(todayStart) && !['Cancelled', 'VOID', 'Refunded'].contains(o.status) && o.paymentMethod == 'Cash')
        .fold(0.0, (sum, order) => sum + order.total);
  }

  int _calculateLowStockCount() {
    return _inventoryProvider.storeInventory
        .where((i) => _inventoryProvider.getItemStock(i.id) <= (i.lowStockThreshold ?? 10))
        .length;
  }

  double _calculateCreditOutstanding() {
    return _orderProvider.orders
        .where((o) => o.paymentMethod == 'Credit' && !['Cancelled', 'VOID', 'Refunded'].contains(o.status))
         .fold(0.0, (sum, order) => sum + order.total);
  }

  List<Map<String, dynamic>> _calculateTopItems({int limit = 3}) {
    final Map<String, double> itemSales = {};
    
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    for (final order in _orderProvider.orders) {
       if (order.date.isBefore(todayStart) || !['Completed', 'Processing', 'Delivered'].contains(order.status)) continue;
       
       for (final orderItem in order.items) {
         final price = orderItem.priceSnapshot ?? orderItem.item.price;
         final total = price * orderItem.quantity;
         itemSales[orderItem.item.name] = (itemSales[orderItem.item.name] ?? 0) + total;
       }
    }

    final sorted = itemSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => {'name': e.key, 'value': e.value}).toList();
  }

  double _calculateSalesGrowth() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final yesterdayEnd = todayStart;

    double today = 0;
    double yesterday = 0;

    for (final order in _orderProvider.orders) {
      if (['Cancelled', 'VOID', 'Refunded'].contains(order.status)) continue;
      
      if (order.date.isAfter(todayStart)) {
        today += order.total;
      } else if (order.date.isAfter(yesterdayStart) && order.date.isBefore(yesterdayEnd)) {
        yesterday += order.total;
      }
    }

    if (yesterday == 0) return 100.0;
    return ((today - yesterday) / yesterday) * 100;
  }

  List<Map<String, dynamic>> _calculateWeeklyTrend() {
     final Map<int, double> dailyTotals = {};
     final now = DateTime.now();
     
     for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        final key = date.day; 
        dailyTotals[key] = 0.0;
     }

     for (final order in _orderProvider.orders) {
        if (['Cancelled', 'VOID', 'Refunded'].contains(order.status)) continue;
        final diff = now.difference(order.date).inDays;
        if (diff < 7) {
           final key = order.date.day;
           dailyTotals[key] = (dailyTotals[key] ?? 0) + order.total;
        }
     }
     
     return List.generate(7, (index) {
        final date = now.subtract(Duration(days: 6 - index));
        return {
          'day': _getDayName(date.weekday),
          'sales': dailyTotals[date.day] ?? 0.0,
        };
     });
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  List<String> _generateSmartInsights() {
    final insights = <String>[];
    
    // 1. Growth
    final growth = _calculateSalesGrowth();
    if (growth > 10) insights.add("ðŸ“ˆ Sales increasing ${growth.toStringAsFixed(1)}% vs yesterday");
    
    // 2. Dead Stock (Mock logic for now, relies on 'lastSold' tracking which might not be in Item yet)
    // We can infer it by checking items NOT in recent orders
    // expensive check, maybe simplify?
    // insights.add("âš ï¸ 5 products not sold in 30 days"); 

    // 3. High Value
    // insights.add("ðŸ’° 3 items generating 60% revenue");

    // 4. Credit Risk
    final credit = _calculateCreditOutstanding();
    if (credit > 1000) insights.add("ðŸ’³ High credit outstanding: ₹${credit.toStringAsFixed(0)}");

    return insights;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _dashboardProvider.removeListener(_recalculate);
    _orderProvider.removeListener(_recalculate);
    _inventoryProvider.removeListener(_recalculate);
    super.dispose();
  }
}

