import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/dashboard_provider.dart'; // NEW
import 'package:intl/intl.dart';
import '../../widgets/report_stat_card.dart';
import '../../utils/export_utils.dart';
import 'package:fl_chart/fl_chart.dart';

class UnifiedSalesReportScreen extends StatefulWidget {
  const UnifiedSalesReportScreen({super.key});

  @override
  State<UnifiedSalesReportScreen> createState() => _UnifiedSalesReportScreenState();
}

class _UnifiedSalesReportScreenState extends State<UnifiedSalesReportScreen> {
  bool _showFilters = true;
  DateTimeRange? _dateRange; // NEW
  String? _selectedStatus; // NEW
  String? _selectedPaymentMethod; // NEW
  
  // Real Stats from Database
  double _totalSales = 0;
  int _totalCount = 0;
  double _avgOrder = 0;

  @override
  void initState() {
    super.initState();
    // Default to this month
    final now = DateTime.now();
    _dateRange = DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAggregatedStats();
    });
  }

  Future<void> _fetchAggregatedStats() async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);

    final stats = await orderProvider.fetchStats(
      dashboardProvider.activeStoreId,
      start: _dateRange?.start,
      end: _dateRange?.end,
      status: _selectedStatus,
      paymentMethod: _selectedPaymentMethod, // NEW
    );

    if (mounted) {
      setState(() {
        _totalSales = stats['totalSales'] ?? 0.0;
        _totalCount = stats['orderCount'] ?? 0;
        _avgOrder = stats['avgOrderValue'] ?? 0.0;
      });
    }
  }

  Future<void> _exportExcel(List<dynamic> filteredOrders, double totalSales, int totalCount, double avgOrder) async {
    try {
      final headers = ['Order ID', 'Date', 'Amount', 'Payment Method', 'Status'];
      final rows = filteredOrders.map((o) => [
        o.id,
        DateFormat('yyyy-MM-dd HH:mm').format(o.date),
        o.total,
        o.paymentMethod,
        o.status,
      ]).toList();
      
      // Add summary rows at the end
      rows.add([]);
      rows.add(['Summary', '', '', '', '']);
      rows.add(['Total Sales', totalSales, '', '', '']);
      rows.add(['Total Orders', totalCount, '', '', '']);
      rows.add(['Avg Order', avgOrder, '', '', '']);

      await ExportUtils.exportToExcel(
        fileName: 'Sales_Report',
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
    final orderProvider = Provider.of<OrderProvider>(context);
    final allOrders = orderProvider.orders;

    // 1. Apply Filters
    final filteredOrders = allOrders.where((order) {
      if (_dateRange != null) {
        if (order.date.isBefore(_dateRange!.start) || order.date.isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }
      if (_selectedPaymentMethod != null && order.paymentMethod != _selectedPaymentMethod) {
        return false;
      }
      if (_selectedStatus != null && order.status != _selectedStatus) {
        return false;
      }
      return true;
    }).toList();

    // 2. Calculate Chart-Specific Stats (Derived from filtered list)
    double cashSales = 0;
    double cardSales = 0;
    double upiSales = 0;

    double completedSales = 0;
    double refundedSales = 0;
    double cancelledSales = 0;

    for (var o in filteredOrders) {
      // All orders regardless of status contribute to the status chart
      if (o.status == 'Completed') {
        completedSales += o.total;
      } else if (o.status == 'Refunded') {
        refundedSales += o.total;
      } else if (o.status == 'Cancelled') {
        cancelledSales += o.total;
      }

      // --- ROBUST REVENUE MATH ---
      if (o.status != 'Cancelled' && o.status != 'VOID') {
         double amt = (o.status == 'Refunded') ? 0.0 : o.total;
         if (o.paymentMethod == 'Cash') {
           cashSales += amt;
         } else if (o.paymentMethod == 'Card') {
           cardSales += amt;
         } else if (o.paymentMethod == 'UPI') {
           upiSales += amt;
         }
      }
    }
    
    // Stats remain as fetched from DB/Provider
    double avgOrder = _avgOrder;
    double totalSales = _totalSales;
    int totalCount = _totalCount;

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
            title: const Text('Sales Report', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download),
                tooltip: "Export to Excel",
                onPressed: () => _exportExcel(filteredOrders, totalSales, totalCount, avgOrder),
              ),
              IconButton(
                icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
                onPressed: () => setState(() => _showFilters = !_showFilters),
              )
            ],
          ),
          
          // FILTERS
          SliverToBoxAdapter(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _showFilters ? 160 : 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: isDark ? Colors.grey.shade900 : Colors.white,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    
                    // Date Range Picker
                    const Text("Date Range", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context, 
                          firstDate: DateTime(2020), 
                          lastDate: DateTime.now()
                        );
                        if (picked != null) {
                           setState(() => _dateRange = picked);
                           _fetchAggregatedStats();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.white,
                          border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today, size: 18, color: Colors.blue),
                            const SizedBox(width: 12),
                            Text(_dateRange == null 
                              ? "Select Date Range" 
                              : "${DateFormat('MMM dd, yyyy').format(_dateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_dateRange!.end)}",
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Dropdowns
                    Row(
                      children: [
                        // Status
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedStatus,
                            decoration: InputDecoration(
                              labelText: "Status", 
                              filled: true,
                              fillColor: isDark ? Colors.black26 : Colors.transparent,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), 
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            dropdownColor: isDark ? Colors.grey.shade900 : Colors.white,
                            items: const [
                               DropdownMenuItem(value: null, child: Text("All Statuses")),
                               DropdownMenuItem(value: 'Completed', child: Text("Completed")),
                               DropdownMenuItem(value: 'Refunded', child: Text("Refunded")),
                               DropdownMenuItem(value: 'Cancelled', child: Text("Cancelled")),
                            ],
                            onChanged: (v) {
                               setState(() => _selectedStatus = v);
                               _fetchAggregatedStats();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Payment
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedPaymentMethod,
                            decoration: InputDecoration(
                              labelText: "Payment", 
                              filled: true,
                              fillColor: isDark ? Colors.black26 : Colors.transparent,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), 
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            dropdownColor: isDark ? Colors.grey.shade900 : Colors.white,
                            items: const [
                               DropdownMenuItem(value: null, child: Text("All Methods")),
                               DropdownMenuItem(value: 'Cash', child: Text("Cash")),
                               DropdownMenuItem(value: 'Card', child: Text("Card")),
                               DropdownMenuItem(value: 'UPI', child: Text("UPI")),
                            ],
                            onChanged: (v) {
                               setState(() => _selectedPaymentMethod = v);
                               _fetchAggregatedStats();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          if (_showFilters)
            SliverToBoxAdapter(child: Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),

          // SUMMARY CARDS
          SliverToBoxAdapter(
            child: Padding(
               padding: const EdgeInsets.all(16),
               child: Row(
                 children: [
                   ReportStatCard(
                     title: "Total Sales", 
                     value: "₹${totalSales.toStringAsFixed(0)}", 
                     icon: Icons.currency_rupee, 
                     baseColor: Colors.green.shade600
                   ),
                   const SizedBox(width: 16),
                   ReportStatCard(
                     title: "Total Orders", 
                     value: "$totalCount", 
                     icon: Icons.receipt_long, 
                     baseColor: Colors.blue.shade600
                   ),
                   const SizedBox(width: 16),
                   ReportStatCard(
                     title: "Avg Order", 
                     value: "₹${avgOrder.toStringAsFixed(0)}", 
                     icon: Icons.analytics, 
                     baseColor: Colors.orange.shade600
                   ),
                 ],
               ),
            ),
          ),
          
          // PIE CHART
          if (totalSales > 0)
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
                      "Sales by Payment Method", 
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      )
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: Row(
                        children: [
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: [
                                  if (cashSales > 0) PieChartSectionData(
                                    color: Colors.orange,
                                    value: cashSales,
                                    title: '${(cashSales / totalSales * 100).toStringAsFixed(0)}%',
                                    radius: 50,
                                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  if (cardSales > 0) PieChartSectionData(
                                    color: Colors.blue,
                                    value: cardSales,
                                    title: '${(cardSales / totalSales * 100).toStringAsFixed(0)}%',
                                    radius: 50,
                                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  if (upiSales > 0) PieChartSectionData(
                                    color: Colors.purple,
                                    value: upiSales,
                                    title: '${(upiSales / totalSales * 100).toStringAsFixed(0)}%',
                                    radius: 50,
                                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Indicator(color: Colors.orange, text: 'Cash', isSquare: false),
                              const SizedBox(height: 8),
                              _Indicator(color: Colors.blue, text: 'Card', isSquare: false),
                              const SizedBox(height: 8),
                              _Indicator(color: Colors.purple, text: 'UPI', isSquare: false),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
          // ORDER STATUS PIE CHART
          if (completedSales > 0 || refundedSales > 0 || cancelledSales > 0)
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
                      "Sales by Order Status", 
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      )
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: Row(
                        children: [
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: [
                                  if (completedSales > 0) PieChartSectionData(
                                    color: Colors.green,
                                    value: completedSales,
                                    title: '${(completedSales / (completedSales + refundedSales + cancelledSales) * 100).toStringAsFixed(0)}%',
                                    radius: 50,
                                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  if (refundedSales > 0) PieChartSectionData(
                                    color: Colors.orange,
                                    value: refundedSales,
                                    title: '${(refundedSales / (completedSales + refundedSales + cancelledSales) * 100).toStringAsFixed(0)}%',
                                    radius: 50,
                                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  if (cancelledSales > 0) PieChartSectionData(
                                    color: Colors.red,
                                    value: cancelledSales,
                                    title: '${(cancelledSales / (completedSales + refundedSales + cancelledSales) * 100).toStringAsFixed(0)}%',
                                    radius: 50,
                                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               const _Indicator(color: Colors.green, text: 'Completed', isSquare: false),
                               const SizedBox(height: 8),
                               const _Indicator(color: Colors.orange, text: 'Refunded', isSquare: false),
                               const SizedBox(height: 8),
                               const _Indicator(color: Colors.red, text: 'Cancelled', isSquare: false),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                "Recent Orders", 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16, 
                  color: isDark ? Colors.white70 : Colors.grey.shade800
                )
              ),
            ),
          ),

          // LIST
          if (filteredOrders.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      "No orders found matching criteria.", 
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade600 : Colors.grey, 
                        fontSize: 16
                      )
                    ),
                  ],
                )
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final order = filteredOrders[index];
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
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.receipt, color: isDark ? Colors.blue.shade400 : Colors.blue.shade300),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "#${order.id.substring(order.id.length - 6).toUpperCase()} • ₹${order.total.toStringAsFixed(0)}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 16,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('MMM dd, yyyy • HH:mm').format(order.date),
                                    style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: order.status == 'Cancelled' ? Colors.red.shade50 : (order.status == 'Refunded' ? Colors.orange.shade50 : Colors.green.shade50),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    order.status, 
                                    style: TextStyle(
                                      fontSize: 12, 
                                      color: order.status == 'Cancelled' ? Colors.red.shade700 : (order.status == 'Refunded' ? Colors.orange.shade800 : Colors.green.shade700), 
                                      fontWeight: FontWeight.bold
                                    )
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      order.paymentMethod == 'Cash' ? Icons.money : 
                                      (order.paymentMethod == 'UPI' ? Icons.qr_code : Icons.credit_card),
                                      size: 14,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      order.paymentMethod,
                                      style: TextStyle(
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, 
                                        fontSize: 12, 
                                        fontWeight: FontWeight.w600
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: filteredOrders.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  final Color color;
  final String text;
  final bool isSquare;

  const _Indicator({
    required this.color,
    required this.text,
    required this.isSquare,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
          ),
        )
      ],
    );
  }
}
