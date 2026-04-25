import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/inventory_provider.dart';
import '../../models/inventory_item.dart';
import '../../widgets/report_stat_card.dart';
import '../../utils/export_utils.dart';
import 'package:fl_chart/fl_chart.dart';

class InventoryReportsScreen extends StatefulWidget {
  const InventoryReportsScreen({super.key});

  @override
  State<InventoryReportsScreen> createState() => _InventoryReportsScreenState();
}

class _InventoryReportsScreenState extends State<InventoryReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _exportExcel(List<InventoryItem> items, String reportType) async {
    final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
    try {
      final headers = ['Item Name', 'Category', 'Quantity', 'Price (₹)', 'Total Value (₹)'];
      double totalValue = 0;
      
      final rows = items.map((i) {
        final currentStock = inventoryProvider.getItemStock(i.id);
        final itemValue = i.price * currentStock;
        totalValue += itemValue;
        return [
          i.name,
          i.category,
          currentStock,
          i.price,
          itemValue,
        ];
      }).toList();
      
      rows.add([]);
      rows.add(['Summary', '', '', '', '']);
      rows.add(['Total Items', items.length, '', '', '']);
      rows.add(['Total Inventory Value', '', '', '', totalValue]);

      await ExportUtils.exportToExcel(
        fileName: 'Inventory_${reportType}_Report',
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
    final inventoryProvider = Provider.of<InventoryProvider>(context);
    final allItems = inventoryProvider.storeInventory;
    final lowStockItems = allItems.where((i) => inventoryProvider.getItemStock(i.id) <= 10).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/reports'),
            ),
            title: const Text('Inventory Reports', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download),
                tooltip: "Export Current Tab",
                onPressed: () {
                  if (_tabController.index == 0) {
                    _exportExcel(allItems, 'All');
                  } else {
                    _exportExcel(lowStockItems, 'LowStock');
                  }
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              indicatorColor: Theme.of(context).primaryColor,
              labelColor: isDark ? Colors.white : Colors.black87,
              tabs: const [
                Tab(text: 'All Stock'),
                Tab(text: 'Low Stock Alerts'),
              ],
            ),
          ),
          
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _StockList(items: allItems),
                _StockList(items: lowStockItems, isAlert: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StockList extends StatelessWidget {
  final List<InventoryItem> items;
  final bool isAlert;

  const _StockList({required this.items, this.isAlert = false});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isAlert ? Icons.check_circle : Icons.inventory_2_outlined, size: 64, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(isAlert ? "No Low Stock Alerts" : "No Inventory Found", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade600 : Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    final inventoryProvider = Provider.of<InventoryProvider>(context);
    final totalValue = items.fold(0.0, (sum, i) => sum + (i.price * inventoryProvider.getItemStock(i.id)));
    
    // Group by category for Pie Chart
    Map<String, double> categoryValues = {};
    for (var item in items) {
       final currentStock = inventoryProvider.getItemStock(item.id);
       categoryValues[item.category] = (categoryValues[item.category] ?? 0) + (item.price * currentStock);
    }
    
    // Sort and get top categories
    var sortedCategories = categoryValues.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
      
    final colors = [Colors.blue, Colors.orange, Colors.purple, Colors.teal, Colors.red];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                ReportStatCard(
                  title: isAlert ? "Low Stock Items" : "Total Items",
                  value: "${items.length}",
                  icon: isAlert ? Icons.warning_amber_rounded : Icons.inventory_2,
                  baseColor: isAlert ? Colors.orange.shade600 : Colors.blue.shade600,
                ),
                const SizedBox(width: 16),
                ReportStatCard(
                  title: "Total Value",
                  value: "₹${totalValue.toStringAsFixed(0)}",
                  icon: Icons.account_balance_wallet,
                  baseColor: Colors.green.shade600,
                ),
              ],
            ),
          ),
        ),
        
        // PIE CHART
        if (!isAlert && totalValue > 0 && sortedCategories.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.black.withValues(alpha: 0.03), 
                    blurRadius: 10, 
                    offset: const Offset(0, 4)
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Value by Category", 
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
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
                              sections: List.generate(
                                sortedCategories.length > 5 ? 5 : sortedCategories.length, 
                                (index) {
                                  final cat = sortedCategories[index];
                                  return PieChartSectionData(
                                    color: colors[index % colors.length],
                                    value: cat.value,
                                    title: '${(cat.value / totalValue * 100).toStringAsFixed(0)}%',
                                    radius: 50,
                                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  );
                                }
                              )
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(
                             sortedCategories.length > 5 ? 5 : sortedCategories.length,
                             (index) {
                               return Padding(
                                 padding: const EdgeInsets.only(bottom: 8.0),
                                 child: _Indicator(
                                   color: colors[index % colors.length], 
                                   text: sortedCategories[index].key.length > 12 ? '${sortedCategories[index].key.substring(0,10)}...' : sortedCategories[index].key, 
                                   isSquare: false
                                 ),
                               );
                             }
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Card(
                  elevation: 0,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: inventoryProvider.getItemStock(item.id) <= 10 
                              ? (Theme.of(context).brightness == Brightness.dark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange.shade50) 
                              : (Theme.of(context).brightness == Brightness.dark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            inventoryProvider.getItemStock(item.id) <= 10 ? Icons.warning_rounded : Icons.category, 
                            color: inventoryProvider.getItemStock(item.id) <= 10 
                              ? (Theme.of(context).brightness == Brightness.dark ? Colors.orange.shade400 : Colors.orange.shade400) 
                              : (Theme.of(context).brightness == Brightness.dark ? Colors.blue.shade400 : Colors.blue.shade400)
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 16,
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Category: ${item.category}",
                                style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 13),
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
                                color: inventoryProvider.getItemStock(item.id) <= 10 
                                  ? (Theme.of(context).brightness == Brightness.dark ? Colors.red.withValues(alpha: 0.1) : Colors.red.shade50) 
                                  : (Theme.of(context).brightness == Brightness.dark ? Colors.green.withValues(alpha: 0.1) : Colors.green.shade50),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${inventoryProvider.getItemStock(item.id)} units", 
                                    style: TextStyle(
                                      fontSize: 13, 
                                      color: inventoryProvider.getItemStock(item.id) <= 10 
                                        ? (Theme.of(context).brightness == Brightness.dark ? Colors.red.shade400 : Colors.red.shade700) 
                                        : (Theme.of(context).brightness == Brightness.dark ? Colors.green.shade400 : Colors.green.shade700), 
                                      fontWeight: FontWeight.bold
                                    )
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "₹${item.price.toStringAsFixed(0)} / unit",
                              style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            childCount: items.length,
          ),
        ),
      ],
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
            fontSize: 12, 
            fontWeight: FontWeight.w500,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
          )
        )
      ],
    );
  }
}
