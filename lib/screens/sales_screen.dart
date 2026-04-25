// ignore_for_file: unused_field
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/order_provider.dart'; // NEW
import '../models/order_model.dart';
import '../services/printer_manager_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../l10n/app_localizations.dart'; // LOCALIZATION

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final ScrollController _listScrollController = ScrollController();
  // final UniversalPrinterService _printerService = UniversalPrinterService(); // Removed direct usage
  
  List<OrderModel> _orders = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorMessage;
  DocumentSnapshot? _lastDocument;
  int _totalCount = 0;
  double _totalSales = 0;
  
  // New Filter State
  int? _selectedYear;
  int? _selectedMonth;
  int? _selectedDay;

  // Sorting
  String _sortBy = 'date';
  bool _descending = true;

  // Scroll Controllers for Date Columns (to programmatically scroll)
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;

  @override
  void initState() {
    super.initState();
    
    // Default to Today
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _selectedDay = now.day;

    // Initialize Scroll Controllers based on default selection
    // Years: 2020 to Current+1. Index 0 is 2020.
    _yearController = FixedExtentScrollController(initialItem: _selectedYear! - 2020);
    // Months: 1-12. Index 0 is Jan (1).
    _monthController = FixedExtentScrollController(initialItem: _selectedMonth! - 1);
    // Days: 1-31. Index 0 is 1.
    _dayController = FixedExtentScrollController(initialItem: _selectedDay! - 1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOrders(isRefresh: true);
    });
    _listScrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_listScrollController.position.pixels >= _listScrollController.position.maxScrollExtent - 200 && !_isLoading && _hasMore) {
      _fetchOrders();
    }
  }

  void _handleDateSelection() {
     _fetchOrders(isRefresh: true);
  }

  Future<void> _fetchOrders({bool isRefresh = false}) async {
    if (_isLoading && !isRefresh) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      if (provider.activeStoreId == null) {
        setState(() {
          _errorMessage = "No Active Store Selected";
          _isLoading = false;
        });
        return;
      }

      // USE LOCAL DATA (Offline First)
      // This avoids Index issues and ensures instant UI
      List<OrderModel> sourceOrders = List.from(provider.orders);
      
      // 1. Filter by Date
      List<OrderModel> filtered = [];
      
      if (_selectedYear != null) {
          DateTime start = DateTime(_selectedYear!, _selectedMonth ?? 1, _selectedDay ?? 1);
          DateTime end;
          
          if (_selectedMonth == null) {
             end = DateTime(_selectedYear!, 12, 31, 23, 59, 59);
          } else if (_selectedDay == null) {
             int lastDay = DateTime(_selectedYear!, _selectedMonth! + 1, 0).day;
             end = DateTime(_selectedYear!, _selectedMonth!, lastDay, 23, 59, 59);
          } else {
             end = DateTime(_selectedYear!, _selectedMonth!, _selectedDay!, 23, 59, 59);
          }
          
          filtered = sourceOrders.where((o) {
             // Ensure we convert to local for comparison if needed, or rely on internal logic
             // OrderModel.date is standard DateTime.
             return !o.date.isBefore(start) && !o.date.isAfter(end);
          }).toList();
      } else {
         // No date filter = All History
         filtered = sourceOrders;
      }

      // 2. Sort
      filtered.sort((a, b) {
         int cmp = (_sortBy == 'date') ? a.date.compareTo(b.date) : a.total.compareTo(b.total);
         return _descending ? -cmp : cmp;
      });

      // 3. Pagination (Simulated for UI performance if list is huge)
      // For now, load all valid filtered results as the list handles it well up to thousands.
      // If needed, we can implemented .take(limit) here.
      
      if (mounted) {
        setState(() {
          _orders = filtered;
          _hasMore = false; 
          _isLoading = false;
        });

        // Background fetch for accurate totals
        _updateStats();
      }
      
      // Optional: Trigger background refresh if empty?
      if (_orders.isEmpty && provider.syncService.isOnline) {
         // provider.syncService.smartSync(); // Already runs periodically
      }

    } catch (e) {

      if (mounted) {
        setState(() {
          _errorMessage = "Error loading data: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateStats() async {
    try {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      
      DateTime? start;
      DateTime? end;
      if (_selectedYear != null) {
        start = DateTime(_selectedYear!, _selectedMonth ?? 1, _selectedDay ?? 1);
        if (_selectedMonth == null) {
          end = DateTime(_selectedYear!, 12, 31, 23, 59, 59);
        } else if (_selectedDay == null) {
          int lastDay = DateTime(_selectedYear!, _selectedMonth! + 1, 0).day;
          end = DateTime(_selectedYear!, _selectedMonth!, lastDay, 23, 59, 59);
        } else {
          end = DateTime(_selectedYear!, _selectedMonth!, _selectedDay!, 23, 59, 59);
        }
      }

      final stats = await orderProvider.fetchStats(
        provider.activeStoreId, 
        start: start, 
        end: end,
      );

      if (mounted) {
        setState(() {
          _totalCount = stats['orderCount'] ?? 0;
          _totalSales = stats['totalSales'] ?? 0.0;
        });
      }
    } catch (e) {
      debugPrint("Stats error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF14141F) : Colors.grey[100];
    final surfaceColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final dividerColor = isDark ? Colors.white10 : Colors.grey.shade300;

    // Check Mobile
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(AppLocalizations.t(context, 'sales'), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: surfaceColor,
        foregroundColor: textColor,
        actions: [
          IconButton(
            icon: Icon(_descending ? Icons.arrow_downward : Icons.arrow_upward, color: textColor.withValues(alpha: 0.7)), 
            onPressed: () {
               setState(() {
                 if (_sortBy == 'date') {
                   _sortBy = 'total';
                   _descending = true;
                 } else if (_sortBy == 'total' && _descending) {
                    _descending = false;
                 } else {
                   _sortBy = 'date';
                   _descending = true;
                 }
                 _fetchOrders(isRefresh: true);
               });
            },
            tooltip: 'Sort: $_sortBy',
          ),
          if (isMobile)
             IconButton(
               icon: const Icon(Icons.date_range),
             tooltip: AppLocalizations.t(context, 'filter'),
             onPressed: () => _showMobileDateSelector(surfaceColor, dividerColor),
             ),
        ],
      ),
      body: isMobile 
        ? _buildRightPanel(surfaceColor, dividerColor, isDark)
        : Row(
            children: [
              // LEFT PANEL: Date Selectors
              _buildLeftPanel(surfaceColor, dividerColor),
              // RIGHT PANEL
              Expanded(
                child: _buildRightPanel(surfaceColor, dividerColor, isDark),
              )
            ],
          )
    );
  }

  void _showMobileDateSelector(Color surfaceColor, Color dividerColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SizedBox(
         height: 400,
         child: Column(
           children: [
             const SizedBox(height: 16),
             Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
             const SizedBox(height: 16),
             Expanded(child: _buildLeftPanel(Colors.transparent, dividerColor, isMobile: true)),
           ],
         ),
      ),
    );
  }

  Widget _buildLeftPanel(Color surfaceColor, Color dividerColor, {bool isMobile = false}) {
    return Container(
            width: isMobile ? double.infinity : 320,
            decoration: BoxDecoration(
              color: surfaceColor,
              border: isMobile ? null : Border(right: BorderSide(color: dividerColor)),
              boxShadow: isMobile ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]
            ),
            child: Row(
              children: [
                _buildWheelColumn(
                  label: "YEAR",
                  controller: _yearController,
                  itemCount: (DateTime.now().year + 1) - 2020 + 1,
                  onSelectedItemChanged: (index) {
                     setState(() {
                       _selectedYear = 2020 + index;
                       if (_selectedMonth != null && _selectedDay != null) {
                          int maxDays = DateTime(_selectedYear!, _selectedMonth! + 1, 0).day;
                          if (_selectedDay! > maxDays) _selectedDay = null; 
                       }
                     });
                     _handleDateSelection(); 
                  },
                  builder: (context, index) {
                    final year = 2020 + index;
                    return _buildWheelItem(
                      text: "$year", 
                      isSelected: _selectedYear == year,
                      onTap: () {
                         if (_selectedYear == year) {
                           setState(() { _selectedYear = null; _selectedMonth = null; _selectedDay = null; });
                           _handleDateSelection();
                         } else {
                            _yearController.animateToItem(index, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                         }
                      }
                    );
                  }
                ),
                _buildWheelColumn(
                  label: "MONTH",
                  controller: _monthController,
                  itemCount: 12,
                  onSelectedItemChanged: (index) {
                     setState(() {
                       _selectedMonth = index + 1;
                       if (_selectedYear == null) {
                          _selectedYear = DateTime.now().year;
                          try { _yearController.jumpToItem(_selectedYear! - 2020); } catch (e) { /* Error ignored */ }
                       }
                       if (_selectedDay != null) {
                           int maxDays = DateTime(_selectedYear!, _selectedMonth! + 1, 0).day;
                           if (_selectedDay! > maxDays) _selectedDay = null;
                       }
                     });
                     _handleDateSelection();
                  },
                  builder: (context, index) {
                    final monthName = DateFormat('MMM').format(DateTime(2024, index + 1));
                    return _buildWheelItem(
                      text: monthName, 
                      isSelected: _selectedMonth == index + 1,
                      onTap: () {
                        if (_selectedMonth == index + 1) {
                           setState(() { _selectedMonth = null; _selectedDay = null; });
                           _handleDateSelection();
                        } else {
                           _monthController.animateToItem(index, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                        }
                      }
                    );
                  }
                ),
                _buildWheelColumn(
                  label: "DAY",
                  controller: _dayController,
                  itemCount: 31,
                  onSelectedItemChanged: (index) {
                     final day = index + 1;
                     int maxDays = 31;
                     if (_selectedYear != null && _selectedMonth != null) {
                        maxDays = DateTime(_selectedYear!, _selectedMonth! + 1, 0).day;
                     }
                     
                     if (day <= maxDays) {
                       setState(() {
                         _selectedDay = day;
                         if (_selectedMonth == null) {
                            _selectedMonth = DateTime.now().month;
                            try { _monthController.jumpToItem(_selectedMonth! - 1); } catch (e) { /* Error ignored */ }
                         }
                         if (_selectedYear == null) {
                            _selectedYear = DateTime.now().year;
                            try { _yearController.jumpToItem(_selectedYear! - 2020); } catch (e) { /* Error ignored */ }
                         }
                       });
                       _handleDateSelection();
                     }
                  },
                  builder: (context, index) {
                    final day = index + 1;
                    int maxDays = 31;
                    if (_selectedYear != null && _selectedMonth != null) {
                       maxDays = DateTime(_selectedYear!, _selectedMonth! + 1, 0).day;
                    }
                    if (day > maxDays) return const SizedBox(); 

                    return _buildWheelItem(
                      text: "$day", 
                      isSelected: _selectedDay == day,
                      onTap: () {
                        if (_selectedDay == day) {
                           setState(() { _selectedDay = null; });
                           _handleDateSelection();
                        } else {
                           _dayController.animateToItem(index, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                        }
                      }
                    );
                  }
                ),
              ],
            ),
    );
  }

  Widget _buildRightPanel(Color surfaceColor, Color dividerColor, bool isDark) {
    return RefreshIndicator(
              onRefresh: () => _fetchOrders(isRefresh: true),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: surfaceColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getDateSummaryLabel(),
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.blueAccent : Colors.blue.shade900)
                        ),
                        const SizedBox(height: 4),
                        Text(
                           "Showing $_totalCount transaction${_totalCount == 1 ? '' : 's'} • Total: ₹${_totalSales.toStringAsFixed(2)}",
                           style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 14)
                        )
                      ],
                    )
                  ),
                  Divider(height: 1, color: dividerColor),
                  Expanded(
                    child: _orders.isEmpty && !_isLoading 
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(_errorMessage ?? AppLocalizations.t(context, 'no_data'), style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                              if (_errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: ElevatedButton(onPressed: () => _fetchOrders(isRefresh: true), child: Text(AppLocalizations.t(context, 'refresh'))),
                                )
                            ],
                          )
                        )
                      : ListView.builder(
                          controller: _listScrollController,
                          padding: const EdgeInsets.all(24),
                          itemCount: _orders.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _orders.length) {
                              return _hasMore 
                                  ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())) 
                                  : const SizedBox(height: 50);
                            }
                            return _buildOrderCard(_orders[index]);
                          },
                        ),
                  ),
                ],
              ),
            );
  }

  String _getDateSummaryLabel() {
     if (_selectedYear == null) return "All History";
     if (_selectedMonth == null) return "Year $_selectedYear";
     String m = DateFormat('MMMM').format(DateTime(_selectedYear!, _selectedMonth!));
     if (_selectedDay == null) return "$m $_selectedYear";
     return "$m $_selectedDay, $_selectedYear";
  }

  Widget _buildWheelColumn({
    required String label, 
    required FixedExtentScrollController controller, 
    required int itemCount, 
    required Function(int) onSelectedItemChanged,
    required Widget? Function(BuildContext, int) builder
  }) {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: ListWheelScrollView.useDelegate(
              controller: controller,
              itemExtent: 50,
              physics: const FixedExtentScrollPhysics(),
              magnification: 1.5,
              useMagnifier: true,
              perspective: 0.005,
              onSelectedItemChanged: onSelectedItemChanged,
              childDelegate: ListWheelChildBuilderDelegate(
                builder: builder,
                childCount: itemCount,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWheelItem({required String text, required bool isSelected, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isSelected ? 80 : 60,
          decoration: BoxDecoration(
             color: isSelected 
                ? (isDark ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.1)) 
                : Colors.transparent, 
             borderRadius: BorderRadius.circular(8)
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          alignment: Alignment.center,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20, 
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
              color: isSelected 
                  ? (isDark ? Colors.blueAccent : Colors.blue.shade800)
                  : (isDark ? Colors.white24 : Colors.grey.shade400),
            ),
          ),
        ),
      ),
    );
  }

  // --- EXISTING METHODS ---
  Widget _buildOrderCard(OrderModel order) {
    final bool isRefunded = order.status == 'Refunded';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      key: Key('order_card_${order.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isRefunded 
                          ? Colors.red.withValues(alpha: 0.1) 
                          : Colors.blueAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isRefunded ? Icons.undo : Icons.receipt_long_rounded, 
                      color: isRefunded ? Colors.redAccent : Colors.blueAccent, 
                      size: 24
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${order.id.substring(0, 5).toUpperCase()}', 
                        style: TextStyle(
                          fontWeight: FontWeight.w700, 
                          fontSize: 18,
                          color: textColor
                        )
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy • hh:mm a').format(order.date),
                        style: TextStyle(color: subTextColor, fontSize: 13)
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${order.total.toStringAsFixed(2)}', 
                    style: TextStyle(
                      fontWeight: FontWeight.w800, 
                      fontSize: 20, 
                      color: isRefunded ? Colors.grey : (isDark ? Colors.white : Colors.black)
                    )
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isRefunded ? Colors.red.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: Text(
                      order.status.toUpperCase(), 
                      style: TextStyle(
                        color: isRefunded ? Colors.redAccent : Colors.greenAccent,
                        fontSize: 11, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5
                      )
                    ),
                  ),
                ],
              )
            ],
          ),
          
          const SizedBox(height: 20),
          Divider(color: isDark ? Colors.white10 : Colors.grey.shade200),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              // Print Button
              Expanded(
                child: SizedBox(
                   height: 50,
                   child: ElevatedButton.icon(
                      key: Key('order_print_button_${order.id}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF3D3D5C) : Colors.grey.shade100,
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.print_rounded, size: 22),
                      label: Text(AppLocalizations.t(context, 'print'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                       onPressed: () {
                           final provider = Provider.of<DashboardProvider>(context, listen: false);
                           PrinterManagerService().printOrderReceipt(order, provider.activeStore, cashierName: provider.userProfile?.name ?? "Cashier");
                      },
                   ),
                ),
              ),
              const SizedBox(width: 12),
              
              // View Button (Secondary)
              SizedBox(
                height: 50,
                width: 50,
                child: IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  icon: const Icon(Icons.visibility_rounded, color: Colors.blueAccent),
                  tooltip: AppLocalizations.t(context, 'view'),
                  onPressed: () => _showReceiptDialog(order),
                ),
              ),

              if (!isRefunded) ...[
                const SizedBox(width: 12),
                // Refund Button
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                        foregroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3))
                      ),
                      icon: const Icon(Icons.undo_rounded, size: 22),
                      label: Text(AppLocalizations.t(context, 'delete'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      onPressed: () => _confirmRefund(context, order.id)
                    ),
                  ),
                ),
              ]
            ],
          )
        ],
      ),
    );
  }

  void _showReceiptDialog(OrderModel order) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final store = provider.activeStore;
    final receiptSettings = store?.receipt;
    
    // Thermal Printer Layout Constants
    const TextStyle monoStyle = TextStyle(
      fontFamily: 'Courier', 
      fontSize: 12, 
      color: Colors.black,
      height: 1.2
    );
    final TextStyle boldMonoStyle = monoStyle.copyWith(fontWeight: FontWeight.bold);
    
    showDialog(
      context: context, 
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // Sharp edges like paper
        backgroundColor: Colors.white,
        child: Container(
          width: 380, // Approximate width of a receipt
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // HEADER
              Center(child: Text(store?.name ?? 'Store Name', style: boldMonoStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w900))),
              if (store?.address != null)
                Center(child: Text(store!.address!, style: monoStyle, textAlign: TextAlign.center)),
              if (store?.gstin != null && store!.gstin!.isNotEmpty)
                 Center(child: Text("GSTIN NO : ${store.gstin}", style: monoStyle)),
              
             const SizedBox(height: 8),
             const Text("________________________________________", style: monoStyle, textAlign: TextAlign.center, maxLines: 1),
             const SizedBox(height: 8),
             
             // DETAILS
             Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
               Text("Date: ${DateFormat('dd/MM/yy').format(order.date)}", style: monoStyle),
               const Text("Self Service", style: monoStyle),
             ]),
             Text(DateFormat('HH:mm').format(order.date), style: monoStyle),
             Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
               const Text("Cashier: Cashier", style: monoStyle), // Placeholder for now
               Text("Bill No.: ${order.id.length > 5 ? order.id.substring(order.id.length - 5) : order.id}", style: monoStyle),
             ]),
             
             if (receiptSettings?.showTokenNo ?? true) ...[
                const SizedBox(height: 8),
                Center(child: Text("Token No.: ${order.id.length > 4 ? order.id.substring(order.id.length - 4) : order.id}", style: boldMonoStyle.copyWith(fontSize: 14))),
             ],

             const SizedBox(height: 4),
             const Text("________________________________________", style: monoStyle, textAlign: TextAlign.center, maxLines: 1),
             const SizedBox(height: 4),
             
             // ITEMS HEADER
             // No.  Item                     Qty    Price   Amount
             // 3    22                       4      8       9
             const Row(children: [
               SizedBox(width: 25, child: Text("No.", style: monoStyle)),
               Expanded(child: Text("Item", style: monoStyle)),
               SizedBox(width: 30, child: Text("Qty", style: monoStyle, textAlign: TextAlign.right)),
               SizedBox(width: 60, child: Text("Price", style: monoStyle, textAlign: TextAlign.right)),
               SizedBox(width: 60, child: Text("Amount", style: monoStyle, textAlign: TextAlign.right)),
             ]),
             const Text("________________________________________", style: monoStyle, textAlign: TextAlign.center, maxLines: 1),
             
             // ITEMS
             Expanded(
               child: ListView.builder(
                 shrinkWrap: true,
                 itemCount: order.items.length,
                 itemBuilder: (context, index) {
                    final item = order.items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           SizedBox(width: 25, child: Text("${index + 1}", style: monoStyle)),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(item.item.name, style: monoStyle),
                                 // Add modifiers/variants here if any
                               ],
                             )
                           ),
                           SizedBox(width: 30, child: Text("${item.quantity}", style: monoStyle, textAlign: TextAlign.right)),
                           SizedBox(width: 60, child: Text(item.item.price.toStringAsFixed(2), style: monoStyle, textAlign: TextAlign.right)),
                           SizedBox(width: 60, child: Text((item.item.price * item.quantity).toStringAsFixed(2), style: monoStyle, textAlign: TextAlign.right)),
                        ],
                      ),
                    );
                 },
               ),
             ),
             
             const Text("________________________________________", style: monoStyle, textAlign: TextAlign.center, maxLines: 1),
                          // TOTALS
              // Total Qty: 5                          Sub   100.00
              Builder(builder: (context) {
                final taxPct = order.taxRateSnapshot; // e.g. 5.0
                final taxFraction = taxPct / 100; // e.g. 0.05
                final derivedSubtotal = taxPct > 0 ? order.total / (1 + taxFraction) : order.total;
                return Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text("Total Qty: ${order.items.fold<int>(0, (p, e) => p + e.quantity)}", style: monoStyle),
                      Row(children: [
                        const SizedBox(width: 50, child: Text("Sub", style: monoStyle, textAlign: TextAlign.right)),
                        SizedBox(width: 70, child: Text(derivedSubtotal.toStringAsFixed(2), style: monoStyle, textAlign: TextAlign.right)),
                      ])
                    ]),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Spacer(),
                      Row(children: [
                        const SizedBox(width: 50, child: Text("Total", style: monoStyle, textAlign: TextAlign.right)),
                        SizedBox(width: 70, child: Text(derivedSubtotal.toStringAsFixed(2), style: monoStyle, textAlign: TextAlign.right)),
                      ])
                    ]),
                  ],
                );
              }),

              if (receiptSettings?.showTaxDetails ?? true) ...[
                 Builder(builder: (context) {
                    final taxPct = order.taxRateSnapshot;
                    final taxFraction = taxPct / 100;
                    final derivedSubtotal = taxPct > 0 ? order.total / (1 + taxFraction) : order.total;
                    final totalTax = order.total - derivedSubtotal;
                    final halfTax = totalTax / 2;
                    final halfRate = taxPct / 2;
                    final rateLabel = halfRate == halfRate.roundToDouble()
                        ? halfRate.toStringAsFixed(0)
                        : halfRate.toStringAsFixed(1);
                    return Column(children: [
                      if (taxPct > 0) ...[
                        _buildTaxRow("CGST@$rateLabel%", halfTax, monoStyle),
                        _buildTaxRow("SGST@$rateLabel%", halfTax, monoStyle),
                      ],
                    ]);
                 }),
              ],
             
             const Text("________________________________________", style: monoStyle, textAlign: TextAlign.center, maxLines: 1),
             
             // GRAND TOTAL
             Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("Grand Total", style: boldMonoStyle),
                Text(order.total.toStringAsFixed(2), style: boldMonoStyle),
             ]),
             
             const SizedBox(height: 8),
             const Text("Paid via Other [UPI]", style: monoStyle), // Placeholder
             
             const SizedBox(height: 8),
             const Text("________________________________________", style: monoStyle, textAlign: TextAlign.center, maxLines: 1),
             
             // FOOTER
             const SizedBox(height: 8),
             const Center(child: Text("Thank You Visit Again !!!", style: monoStyle)),
             const SizedBox(height: 16),
             
             // Actions
             Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                  TextButton.icon(
                    icon: const Icon(Icons.print, size: 16, color: Colors.black),
                    label: const Text("PRINT", style: TextStyle(color: Colors.black)),
                    onPressed: () {
                       PrinterManagerService().printOrderReceipt(order, provider.activeStore, cashierName: provider.userProfile?.name ?? "Cashier");
                    },
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                    label: const Text("CLOSE", style: TextStyle(color: Colors.red)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
               ],
             )
             
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaxRow(String label, double amount, TextStyle style) {
     return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
         SizedBox(width: 100, child: Text(label, style: style, textAlign: TextAlign.right)),
         SizedBox(width: 70, child: Text(amount.toStringAsFixed(2), style: style, textAlign: TextAlign.right)),
     ]);
  }

  void _confirmRefund(BuildContext context, String orderId) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
     showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Refund'),
        content: const Text('Are you sure you want to refund this order?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.refundOrder(orderId);
              _fetchOrders(isRefresh: true); 
            }, 
            child: const Text('Refund', style: TextStyle(color: Colors.white))
          )
        ],
      ),
    );
  }
}
