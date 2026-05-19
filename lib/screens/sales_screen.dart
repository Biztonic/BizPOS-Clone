import 'package:biztonic_pos/core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';
import 'package:biztonic_pos/core/design/tokens/app_radius.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/order_provider.dart';
import '../models/order_model.dart';
import '../services/printer_manager_service.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/components/atoms/app_button.dart';
import '../core/design/components/atoms/app_card.dart';
import '../core/design/design_system.dart';

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
    final isMobile = MediaQuery.of(context).size.width < 700;

    return PosScaffold(
      title: AppLocalizations.t(context, 'sales'),
      actions: [
        AppButton.secondary(
          icon: _descending ? Icons.arrow_downward : Icons.arrow_upward,
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
        ),
        if (isMobile)
           AppButton.secondary(
             icon: Icons.date_range,
             onPressed: () => _showMobileDateSelector(),
           ),
      ],
      mainContent: isMobile 
        ? _buildRightPanel()
        : Row(
            children: [
              _buildLeftPanel(),
              const VerticalDivider(width: 1),
              Expanded(
                child: _buildRightPanel(),
              )
            ],
          ),
    );
  }

  void _showMobileDateSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (ctx) => SizedBox(
         height: 400,
         child: Column(
           children: [
             const SizedBox(height: AppSpacing.md),
             Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textSecondary(context), borderRadius: AppRadius.borderCircular)),
             const SizedBox(height: AppSpacing.md),
             Expanded(child: _buildLeftPanel(isMobile: true)),
           ],
         ),
      ),
    );
  }

  Widget _buildLeftPanel({bool isMobile = false}) {
    return Container(
            width: isMobile ? double.infinity : 320,
            decoration: BoxDecoration(
              color: AppColors.surface(context),
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

  Widget _buildRightPanel() {
    final density = AppDensityProvider.configOf(context);

    return RefreshIndicator(
      onRefresh: () => _fetchOrders(isRefresh: true),
      child: CustomScrollView(
        controller: _listScrollController,
        slivers: [
          // 1. Stats Header
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(density.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getDateSummaryLabel(),
                    style: AppTypography.displaySmall.copyWith(
                      fontWeight: FontWeight.bold, 
                      color: AppColors.adaptivePrimary(context)
                    )
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                     "Showing $_totalCount transaction${_totalCount == 1 ? '' : 's'} • Total: ₹${_totalSales.toStringAsFixed(2)}",
                     style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))
                  )
                ],
              )
            ),
          ),

          // 2. Main List or Empty State
          if (_orders.isEmpty && !_isLoading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_toggle_off, size: 64, color: AppColors.textSecondary(context).withValues(alpha: 0.5)),
                    const SizedBox(height: AppSpacing.md),
                    Text(_errorMessage ?? AppLocalizations.t(context, 'no_data'), 
                      style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary(context))
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: AppButton.primary(onPressed: () => _fetchOrders(isRefresh: true), label: AppLocalizations.t(context, 'refresh')),
                      )
                  ],
                )
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.all(density.cardPadding),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _orders.length) {
                      return _hasMore 
                          ? const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.md), child: CircularProgressIndicator())) 
                          : const SizedBox(height: AppSpacing.xl); // Bottom padding
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _buildOrderCard(_orders[index]),
                    );
                  },
                  childCount: _orders.length + 1,
                ),
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
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(label, style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary(context))),
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
    final primaryColor = AppColors.adaptivePrimary(context);
    
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isSelected ? 80 : 60,
          decoration: BoxDecoration(
             color: isSelected 
                ? primaryColor.withValues(alpha: 0.1) 
                : AppColors.transparent, 
             borderRadius: AppRadius.borderMd
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
          alignment: Alignment.center,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(
              fontSize: 20, 
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
              color: isSelected 
                  ? primaryColor
                  : AppColors.textSecondary(context).withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }

  // --- EXISTING METHODS ---
  Widget _buildOrderCard(OrderModel order) {
    final bool isRefunded = order.status == 'Refunded';
    final primaryColor = AppColors.adaptivePrimary(context);
    final errorColor = AppColors.adaptiveError(context);
    final successColor = AppColors.adaptiveSuccess(context);
    
    return AppCard(
      key: Key('order_card_${order.id}'),
      backgroundColor: isRefunded ? errorColor.withValues(alpha: 0.05) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isRefunded 
                          ? errorColor.withValues(alpha: 0.1) 
                          : primaryColor.withValues(alpha: 0.1),
                      borderRadius: AppRadius.borderMd,
                    ),
                    child: Icon(
                      isRefunded ? Icons.undo : Icons.receipt_long_rounded, 
                      color: isRefunded ? errorColor : primaryColor, 
                      size: 24
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${order.id.substring(0, 5).toUpperCase()}', 
                        style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        DateFormat('MMM dd, yyyy • hh:mm a').format(order.date),
                        style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary(context))
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
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w800, 
                      color: isRefunded ? AppColors.textSecondary(context) : null
                    )
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _buildStatusBadge(
                    order.status,
                    isRefunded ? errorColor : successColor,
                  ),
                ],
              )
            ],
          ),
          
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.lg),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  key: Key('order_print_button_${order.id}'),
                  icon: Icons.print_rounded,
                  label: AppLocalizations.t(context, 'print'),
                   onPressed: () {
                       final provider = Provider.of<DashboardProvider>(context, listen: false);
                       PrinterManagerService().printOrderReceipt(order, provider.activeStore, cashierName: provider.userProfile?.name ?? "Cashier");
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton.secondary(
                icon: Icons.visibility_rounded,
                onPressed: () => _showReceiptDialog(order),
              ),
              if (!isRefunded) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton.danger(
                    icon: Icons.undo_rounded,
                    label: AppLocalizations.t(context, 'refund'),
                    onPressed: () => _confirmRefund(context, order.id)
                  ),
                ),
              ]
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showReceiptDialog(OrderModel order) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final store = provider.activeStore;
    final receiptSettings = store?.receipt;
    
    const TextStyle monoStyle = TextStyle(
      fontFamily: 'Courier', 
      fontSize: 12, 
      color: AppColors.textPrimaryLight, // Receipts are usually white background anyway
      height: 1.2
    );
    final TextStyle boldMonoStyle = monoStyle.copyWith(fontWeight: FontWeight.bold);
    
    showDialog(
      context: context, 
      builder: (ctx) => Dialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
        backgroundColor: AppColors.surfaceLight, // Keep receipt paper white
        child: Container(
          width: 380, // Approximate width of a receipt
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs, horizontal: AppSpacing.md),
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
              
              const SizedBox(height: AppSpacing.sm),
              Text(AppLocalizations.t(context, '________________________________________'), style: monoStyle, textAlign: TextAlign.center, maxLines: 1),
              const SizedBox(height: AppSpacing.sm),
             
             // DETAILS
             Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
               Text("Date: ${DateFormat('dd/MM/yy').format(order.date)}", style: monoStyle),
               Text(AppLocalizations.t(context, 'Self Service'), style: monoStyle),
             ]),
             Text(DateFormat('HH:mm').format(order.date), style: monoStyle),
             Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
               Text(AppLocalizations.t(context, 'Cashier: Cashier'), style: monoStyle), // Placeholder for now
               Text("Bill No.: ${order.id.length > 5 ? order.id.substring(order.id.length - 5) : order.id}", style: monoStyle),
             ]),
             
             if (receiptSettings?.showTokenNo ?? true) ...[
                const SizedBox(height: AppSpacing.sm),
                Center(child: Text("Token No.: ${order.id.length > 4 ? order.id.substring(order.id.length - 4) : order.id}", style: boldMonoStyle.copyWith(fontSize: 14))),
             ],

             const SizedBox(height: AppSpacing.xs),
             Text(AppLocalizations.t(context, '________________________________________'), style: monoStyle, textAlign: TextAlign.center, maxLines: 1),
             const SizedBox(height: AppSpacing.xs),
             
             // ITEMS HEADER
             // No.  Item                     Qty    Price   Amount
             // 3    22                       4      8       9
              Row(children: [
                SizedBox(width: 25, child: Text(AppLocalizations.t(context, 'No.'), style: monoStyle)),
                Expanded(child: Text(AppLocalizations.t(context, 'Item'), style: monoStyle)),
                SizedBox(width: 30, child: Text(AppLocalizations.t(context, 'Qty'), style: monoStyle, textAlign: TextAlign.right)),
                SizedBox(width: 60, child: Text(AppLocalizations.t(context, 'Price'), style: monoStyle, textAlign: TextAlign.right)),
                SizedBox(width: 60, child: Text(AppLocalizations.t(context, 'Amount'), style: monoStyle, textAlign: TextAlign.right)),
              ]),
              Text(AppLocalizations.t(context, '________________________________________'), style: monoStyle, textAlign: TextAlign.center, maxLines: 1),
             
             // ITEMS
             Expanded(
               child: ListView.builder(
                 shrinkWrap: true,
                 itemCount: order.items.length,
                 itemBuilder: (context, index) {
                    final item = order.items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
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
             
              Text(AppLocalizations.t(context, '________________________________________'), style: monoStyle, textAlign: TextAlign.center, maxLines: 1),
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
                        SizedBox(width: 50, child: Text(AppLocalizations.t(context, 'Sub'), style: monoStyle, textAlign: TextAlign.right)),
                        SizedBox(width: 70, child: Text(derivedSubtotal.toStringAsFixed(2), style: monoStyle, textAlign: TextAlign.right)),
                      ])
                    ]),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Spacer(),
                      Row(children: [
                        SizedBox(width: 50, child: Text(AppLocalizations.t(context, 'Total'), style: monoStyle, textAlign: TextAlign.right)),
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
             
              Text(AppLocalizations.t(context, '________________________________________'), style: monoStyle, textAlign: TextAlign.center, maxLines: 1),
             
             // GRAND TOTAL
             Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(AppLocalizations.t(context, 'Grand Total'), style: boldMonoStyle),
                Text(order.total.toStringAsFixed(2), style: boldMonoStyle),
             ]),
             
             const SizedBox(height: AppSpacing.sm),
              Text(AppLocalizations.t(context, 'Paid via Other [UPI]'), style: monoStyle), // Placeholder
             
             const SizedBox(height: AppSpacing.sm),
              Text(AppLocalizations.t(context, '________________________________________'), style: monoStyle, textAlign: TextAlign.center, maxLines: 1),
             
             // FOOTER
             const SizedBox(height: AppSpacing.sm),
              Center(child: Text(AppLocalizations.t(context, 'Thank You Visit Again !!!'), style: monoStyle)),
             const SizedBox(height: AppSpacing.md),
             
             // Actions
             Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                  TextButton.icon(
                    icon: const Icon(Icons.print, size: 16, color: AppColors.textPrimaryLight),
                    label: Text(AppLocalizations.t(context, 'PRINT'), style: const TextStyle(color: AppColors.textPrimaryLight)),
                    onPressed: () {
                       PrinterManagerService().printOrderReceipt(order, provider.activeStore, cashierName: provider.userProfile?.name ?? "Cashier");
                    },
                  ),
                  const SizedBox(width: AppSpacing.md),
                  TextButton.icon(
                    icon: const Icon(Icons.close, size: 16, color: AppColors.error),
                    label: Text(AppLocalizations.t(context, 'CLOSE'), style: const TextStyle(color: AppColors.error)),
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
        title: Text(AppLocalizations.t(context, 'confirm_refund')),
        content: Text(AppLocalizations.t(context, 'refund_confirmation_msg')),
        actions: [
          AppButton.secondary(
            label: AppLocalizations.t(context, 'cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          AppButton.danger(
            label: AppLocalizations.t(context, 'refund'),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.refundOrder(orderId);
              _fetchOrders(isRefresh: true); 
            }, 
          )
        ],
      ),
    );
  }
}




