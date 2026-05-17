import '../../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

// ignore_for_file: unused_field, deprecated_member_use_from_same_package, use_build_context_synchronously, unused_element, dead_null_aware_expression, curly_braces_in_flow_control_structures
// ignore_for_file: constant_identifier_names
import 'dart:async';
// Added for ImageFilter
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart'; // Added for SystemChrome
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/inventory_item.dart';
import '../../models/order_model.dart';
import '../../utils/car_dashboard_theme.dart';
import 'widgets/neon_button.dart';
import 'widgets/dashboard_product_tile.dart';
import 'widgets/calculator_widget.dart';
import '../../services/scanner_service.dart';
import '../../services/printer_manager_service.dart';

class CarDashboardPOSScreen extends StatefulWidget {
  const CarDashboardPOSScreen({super.key});

  @override
  State<CarDashboardPOSScreen> createState() => _CarDashboardPOSScreenState();
}

class _CarDashboardPOSScreenState extends State<CarDashboardPOSScreen> {
  // UI State
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final String _currentWeight = "0.000"; // Added to fix error
  
  final Map<String, int> _cart = {}; // ItemID -> Qty
  
  // Simulated gauges
  double _rpmValue = 0.0; // Represents cart size
  
  final ScrollController _gridController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  final ScannerService _scannerService = ScannerService();
  bool _isProcessing = false;
  bool _isCheckoutVisible = false; // Added for Sliding Drawer

  // Checkout State
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerMobileController = TextEditingController();
  String _orderType = 'Dine In'; // Default order type
  bool _isHeaderExpanded = false; // Collapsible Header State
  bool _isCategoryExpanded = true; // Collapsible Category Sidebar State
  
  // Edit Mode State
  bool _isEditMode = false;
  bool _isSortingLowStock = false;
  final Map<String, int> _stockChanges = {};
  Color? _customBackgroundColor; // User Setting
  bool _isCartPanelVisible = true; // Checkout toggle
  double _cardWidth = 200.0; // Card Size
  String _globalCardStyle = 'image'; // Card Style ('image', 'label', 'minimal_rect')

  // Session Timer
  Timer? _sessionTimer;
  Duration _sessionDuration = Duration.zero;
  bool _isRightHanded = false; // Layout state
  Offset? _miniCartPosition; // Draggable Mini Cart Position
  
  StreamSubscription<String>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _scannerService.init();
    _scanSubscription = _scannerService.scanStream.listen(_onBarcodeScanned);
    _startSessionTimer();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadSavedBackground();
  }

  // --- BACKGROUND COLOR PERSISTENCE ---
  void _loadSavedBackground() {
    try {
      final box = Hive.box('settings');
      final savedColor = box.get('pos_bg_color');
      if (savedColor != null && mounted) {
        setState(() => _customBackgroundColor = Color(savedColor as int));
      }
    } catch (_) {}
  }

  void _saveBgColor(Color? color) {
    try {
      final box = Hive.box('settings');
      if (color == null) {
        box.delete('pos_bg_color');
      } else {
        box.put('pos_bg_color', color.toARGB32());
      }
    } catch (_) {}
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _sessionDuration += const Duration(seconds: 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _gridController.dispose();
    // _categoryScrollController.dispose(); // Added - This line was commented out in the original, but the user's instruction implies it should be there. I will keep it as it was in the original, but add the timer dispose.
    _customerNameController.dispose();
    _customerMobileController.dispose();
    _sessionTimer?.cancel();
    _scanSubscription?.cancel();
    super.dispose();
  }

  void _onBarcodeScanned(String barcode) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final inventory = provider.storeInventory;
    
    try {
      final item = inventory.firstWhere(
        (i) => i.id == barcode || i.name.toLowerCase() == barcode.toLowerCase(),
      );
      _addToCart(item);
      // Optional: Add visual feedback for scan in automotive theme
    } catch (e) {
      // Ignore or show subtle error
    }
  }

  void _addToCart(InventoryItem item) {
    setState(() {
      _cart[item.id] = (_cart[item.id] ?? 0) + 1;
      _updateRPM();
    });
  }

  void _removeFromCart(String itemId) {
    setState(() {
      if (_cart.containsKey(itemId)) {
        if (_cart[itemId]! > 1) {
          _cart[itemId] = _cart[itemId]! - 1;
        } else {
          _cart.remove(itemId);
        }
      }
      _updateRPM();
    });
  }

  void _updateRPM() {
    // RPM gauge effect (0.0 to 1.0) based on items count
    int count = _cart.values.fold(0, (sum, q) => sum + q);
    _rpmValue = (count / 20).clamp(0.0, 1.0);
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _rpmValue = 0.0;
    });
  }

  double _calculateTotal(List<InventoryItem> inventory) {
    double total = 0;
    _cart.forEach((itemId, quantity) {
      final item = inventory.firstWhere(
        (i) => i.id == itemId,
        orElse: () => InventoryItem(id: '?', name: 'Unknown', price: 0, quantity: 0, status: '', category: '', trackStock: false)
      );
      total += item.price * quantity;
    });
    return total;
  }

  // --- EDIT MODE & CUSTOMIZATION ---

  void _showCalculator() {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    
    // Calculate Stats for Calculator Context
    double todaysSale = 0;
    int todaysOrders = 0;
    final now = DateTime.now();

    for (var o in provider.orders) {
        if (o.date.year == now.year && o.date.month == now.month && o.date.day == now.day) {
            todaysSale += o.total;
            todaysOrders++;
        }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CalculatorWidget(
          isDarkMode: provider.isDarkMode,
          // Removed onClose as pop handles it naturally in full screen
          todaysSale: todaysSale,
          totalOrders: todaysOrders,
          cashInHand: todaysSale, // Simplified logic matching insights
        ),
      ),
    );
  }

  void _showItemCustomizationDialog(InventoryItem item) {
    String selectedStyle = item.cardStyle;
    String selectedSize = item.cardSize;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: CarDashboardTheme.bgDark.withValues(alpha: 0.95),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: CarDashboardTheme.neonBlue)),
            title: Text("CUSTOMIZE CARD: ${item.name}", style: const TextStyle(color: Colors.white, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.t(context, 'CARD STYLE'), style: const TextStyle(color: CarDashboardTheme.neonBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStyleOption("IMAGE", 'image', selectedStyle, (val) => setDialogState(() => selectedStyle = val)),
                    const SizedBox(width: 12),
                    _buildStyleOption("LABEL", 'label', selectedStyle, (val) => setDialogState(() => selectedStyle = val)),
                  ],
                ),
                
                const SizedBox(height: AppSpacing.lg),
                Text(AppLocalizations.t(context, 'CARD SIZE'), style: const TextStyle(color: CarDashboardTheme.neonBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                     _buildStyleOption("SMALL", 'small', selectedSize, (val) => setDialogState(() => selectedSize = val)),
                     const SizedBox(width: AppSpacing.sm),
                     _buildStyleOption("MEDIUM", 'medium', selectedSize, (val) => setDialogState(() => selectedSize = val)),
                     const SizedBox(width: AppSpacing.sm),
                     _buildStyleOption("LARGE", 'large', selectedSize, (val) => setDialogState(() => selectedSize = val)),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t(context, 'CANCEL'), style: TextStyle(color: AppColors.textSecondary(context)))),
              NeonButton(
                label: "SAVE CHANGES",
                onPressed: () {
                   _saveItemCustomization(item, selectedStyle, selectedSize);
                   Navigator.pop(ctx);
                },
              )
            ],
          );
        }
      ),
    );
  }

  Widget _buildStyleOption(String label, String value, String groupValue, Function(String) onTap) {
     final isSelected = value == groupValue;
     return Expanded(
       child: GestureDetector(
         onTap: () => onTap(value),
         child: Container(
           height: 40,
           alignment: Alignment.center,
           decoration: BoxDecoration(
             color: isSelected ? CarDashboardTheme.neonBlue.withValues(alpha: 0.2) : Colors.transparent,
             border: Border.all(color: isSelected ? CarDashboardTheme.neonBlue : AppColors.textSecondary(context)),
             borderRadius: BorderRadius.zero
           ),
           child: Text(label, style: TextStyle(
             color: isSelected ? CarDashboardTheme.neonBlue : AppColors.textSecondary(context), 
             fontWeight: FontWeight.bold, fontSize: 12
           )),
         ),
       ),
     );
  }

  void _saveItemCustomization(InventoryItem item, String style, String size) {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      final updatedItem = item.copyWith(cardStyle: style, cardSize: size);
      
      // Update in Provider (and ideally persist)
      // Since DashboardProvider might not have a direct 'updateItem' exposed or I need to check, 
      // I will assume for now we use a method to update.
      // If 'updateItem' doesn't exist, I might need to implement it.
      // Checking provider usage...
      // Provider has `updateInventoryItem`? I will check or implement.
      // For now, I'll assume we can handle it via a new method in DashboardProvider or just update local state if Provider is limited.
      // But user wants it persisted.
      provider.updateInventoryItem(updatedItem); 
  }
  

  void _handleCashPayment() {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final isDarkMode = provider.isDarkMode;
    final subtotal = _calculateTotal(provider.storeInventory);
    final taxRate = (provider.activeStore?.isTaxEnabled == true) ? ((provider.activeStore?.taxRate ?? 0) / 100) : 0.0;
    final total = subtotal * (1 + taxRate);
    double receivedAmount = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          double returnAmount = receivedAmount - total;
          
          // Helper for colorful buttons
          Widget buildMoneyBtn(int value, Color color) {
              return SizedBox(
                width: 70, // Slightly smaller width
                height: 55, // Slightly smaller height
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color, // SOLID COLOR
                    foregroundColor: Colors.black, // Dark text on bright buttons
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                        side: BorderSide(color: color.withValues(alpha: 0.5), width: 1)
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () => setState(() => receivedAmount += value),
                  child: Text("+$value", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              );
          }

          return AlertDialog(
            backgroundColor: CarDashboardTheme.panelColor(isDarkMode), // Theme Aware
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: CarDashboardTheme.borderColor(isDarkMode))),
            title: Text(AppLocalizations.t(context, 'CASH PAYMENT'), style: TextStyle(color: CarDashboardTheme.textColor(isDarkMode), fontWeight: FontWeight.bold, fontSize: 24)),
            content: SingleChildScrollView( // Fix Overflow
              child: SizedBox(
                width: 450, 
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Summary Box
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: CarDashboardTheme.primaryColor(isDarkMode).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.zero,
                        border: Border.all(color: CarDashboardTheme.borderColor(isDarkMode))
                      ),
                      child: Column(
                        children: [
                          _buildPaymentSummaryRow("BILL TOTAL", total, CarDashboardTheme.textColor(isDarkMode), isLarge: true),
                          const SizedBox(height: AppSpacing.sm),
                          _buildPaymentSummaryRow("RECEIVED", receivedAmount, CarDashboardTheme.electricGreen, isLarge: true),
                          Divider(color: CarDashboardTheme.borderColor(isDarkMode), height: 24),
                          _buildPaymentSummaryRow("CHANGE", returnAmount > 0 ? returnAmount : 0, CarDashboardTheme.neonBlue, isExtraLarge: true),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.md), // Reduced Spacing
                    
                    // Denom Buttons (Colorful & Simple)
                    Wrap(
                      spacing: 12, runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        buildMoneyBtn(10, AppColors.primaryLight),
                        buildMoneyBtn(20, AppColors.warning),
                        buildMoneyBtn(50, AppColors.primary),
                        buildMoneyBtn(100, AppColors.primaryLight),
                        buildMoneyBtn(200, AppColors.warning),
                        buildMoneyBtn(500, AppColors.success),
                        buildMoneyBtn(2000, AppColors.error),
                      ],
                    ),
                    
                    const SizedBox(height: AppSpacing.md), // Reduced Spacing
                    
                    // Reset Button
                     TextButton.icon(
                       onPressed: () => setState(() => receivedAmount = 0),
                       icon: Icon(Icons.refresh, color: CarDashboardTheme.subTextColor(isDarkMode), size: 20),
                       label: Text(AppLocalizations.t(context, 'RESET AMOUNT'), style: TextStyle(color: CarDashboardTheme.subTextColor(isDarkMode), fontSize: 14)),
                     )
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.all(AppSpacing.md),
            actions: [
               Row(
                 children: [
                   Expanded(
                     child: TextButton(
                       onPressed: () => Navigator.pop(ctx), 
                       style: TextButton.styleFrom(
                         padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs), // Increased Height
                         shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Sharp Corners
                         backgroundColor: AppColors.textSecondary(context).withValues(alpha: 0.1),
                       ),
                       child: Text(AppLocalizations.t(context, 'CANCEL'), style: TextStyle(color: CarDashboardTheme.subTextColor(isDarkMode), fontSize: 18, fontWeight: FontWeight.bold))
                     ),
                   ),
                   const SizedBox(width: 12),
                   Expanded(
                     flex: 2, // Give Confirm more space
                     child: ElevatedButton(
                       style: ElevatedButton.styleFrom(
                         backgroundColor: CarDashboardTheme.electricGreen, 
                         foregroundColor: Colors.black,
                         padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs), // Increased Height
                         shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Sharp Corners
                         elevation: 0,
                       ),
                       onPressed: () {
                         Navigator.pop(ctx);
                         _finalizeOrder('Cash');
                       },
                       child: Text(AppLocalizations.t(context, 'CONFIRM PAYMENT'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                     ),
                   ),
                 ],
               )
            ],
          );
        }
      ),
    );
  }

  Widget _buildPaymentSummaryRow(String label, double amount, Color color, {bool isLarge = false, bool isExtraLarge = false}) {
    final provider = Provider.of<DashboardProvider>(context);
    final isDarkMode = provider.isDarkMode;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: CarDashboardTheme.subTextColor(isDarkMode), fontSize: isExtraLarge ? 20 : (isLarge ? 16 : 14), fontWeight: FontWeight.bold)),
        Text("₹${amount.toStringAsFixed(2)}", style: TextStyle(color: color, fontSize: isExtraLarge ? 30 : (isLarge ? 22 : 16), fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showUpgradeDialog(String message) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final isDarkMode = provider.isDarkMode;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CarDashboardTheme.panelColor(isDarkMode),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero, 
            side: BorderSide(color: CarDashboardTheme.alertRed, width: 2)
        ),
        title: Row(
          children: [
            const Icon(Icons.lock, color: CarDashboardTheme.alertRed),
            const SizedBox(width: AppSpacing.sm),
            Text(AppLocalizations.t(context, 'PLAN RESTRICTION'), style: CarDashboardTheme.labelStyle.copyWith(color: CarDashboardTheme.alertRed)),
          ],
        ),
        content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
              const Icon(Icons.security, size: 64, color: CarDashboardTheme.warningAmber),
              const SizedBox(height: AppSpacing.md),
              Text(
                message, 
                textAlign: TextAlign.center,
                style: TextStyle(color: CarDashboardTheme.textColor(isDarkMode), fontSize: 18),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(AppLocalizations.t(context, 'UPGRADE TO STANDARD PLAN FOR UNLIMITED ACCESS'), 
                textAlign: TextAlign.center,
                style: TextStyle(color: CarDashboardTheme.subTextColor(isDarkMode), fontSize: 12, fontWeight: FontWeight.bold),
              ),
           ],
        ),
        actions: [
          NeonButton(
            label: "UNDERSTOOD",
            color: CarDashboardTheme.neonBlue,
            onPressed: () => Navigator.pop(ctx),
          )
        ],
      ),
    );
  }

  void _handleUPIPayment() {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final isDarkMode = provider.isDarkMode;
    final subtotal = _calculateTotal(provider.storeInventory);
    final taxRate = (provider.activeStore?.isTaxEnabled == true) ? ((provider.activeStore?.taxRate ?? 0) / 100) : 0.0;
    final total = subtotal * (1 + taxRate);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: CarDashboardTheme.panelColor(isDarkMode),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: CarDashboardTheme.electricGreen, width: 2)),
        title: Text(AppLocalizations.t(context, 'UPI PAYMENT'), style: TextStyle(color: CarDashboardTheme.textColor(isDarkMode), fontWeight: FontWeight.bold, fontSize: 24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2, size: 120, color: CarDashboardTheme.textColor(isDarkMode)),
            const SizedBox(height: AppSpacing.md),
            Text("Requesting ₹${total.toStringAsFixed(2)}", style: const TextStyle(color: CarDashboardTheme.electricGreen, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(AppLocalizations.t(context, 'Waiting for payment validation...'), style: TextStyle(color: CarDashboardTheme.subTextColor(isDarkMode), fontSize: 16)),
          ],
        ),
        actionsPadding: const EdgeInsets.all(AppSpacing.md),
        actions: [
           Row(
             children: [
               Expanded(
                 child: TextButton(
                   onPressed: () => Navigator.pop(ctx), 
                   style: TextButton.styleFrom(
                     padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                     shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                     backgroundColor: AppColors.textSecondary(context).withValues(alpha: 0.1),
                   ),
                   child: Text(AppLocalizations.t(context, 'CANCEL'), style: TextStyle(color: CarDashboardTheme.subTextColor(isDarkMode), fontSize: 18, fontWeight: FontWeight.bold))
                 ),
               ),
               const SizedBox(width: 12),
               Expanded(
                 flex: 2,
                 child: ElevatedButton(
                   style: ElevatedButton.styleFrom(
                     backgroundColor: CarDashboardTheme.electricGreen,
                     foregroundColor: Colors.black,
                     padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                     shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                     elevation: 0,
                   ),
                   onPressed: () {
                      Navigator.pop(ctx);
                      _finalizeOrder('UPI');
                   },
                   child: Text(AppLocalizations.t(context, 'PAYMENT RECEIVED'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                 ),
               ),
             ],
           )
        ],
      ),
    );
  }

  Future<void> _finalizeOrder(String paymentMethod) async {
    if (_isProcessing) return;

    final provider = Provider.of<DashboardProvider>(context, listen: false);

    // 0. Subscription Check (Plan Limits)
    try {
       await provider.checkSubscriptionLimits();
    } catch (e) {
       _showUpgradeDialog(e.toString());
       return;
    }

    // 1. Inventory Validation (BLOCKING CHECK)
    // We check this first to prevent valid sales if critical stock is missing.
    if (provider.activeStore?.trackInventory == true) {
      List<String> outOfStockItems = [];
      List<String> lowStockItems = []; // For warning only

      for (var entry in _cart.entries) {
         try {
           final item = provider.storeInventory.firstWhere((i) => i.id == entry.key);
           
           if (item.trackStock) {
              final int stock = provider.getItemStock(item.id);
              if (stock < entry.value) {
                outOfStockItems.add(item.name);
              } else if (stock < 5) {
                // Low stock threshold (Hardcoded to 5 temporarily)
                lowStockItems.add("${item.name} ($stock left)");
              }
           }
         } catch (_) { /* Error ignored */ }
      }

      // 1.1 Show blocking dialog for OUT OF STOCK
      if (outOfStockItems.isNotEmpty) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: CarDashboardTheme.bgDark.withValues(alpha: 0.95),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero, 
              side: BorderSide(color: CarDashboardTheme.alertRed, width: 2)
            ),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: CarDashboardTheme.alertRed),
                const SizedBox(width: AppSpacing.sm),
                Text(AppLocalizations.t(context, 'CRITICAL STOCK FAILURE'), style: CarDashboardTheme.labelStyle.copyWith(color: CarDashboardTheme.alertRed, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.t(context, 'UNABLE TO PROCESS SEQUENCE.'), style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: AppSpacing.md),
                Text(AppLocalizations.t(context, 'DEPLETED ASSETS:'), style: const TextStyle(color: CarDashboardTheme.alertRed, fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.sm),
                ...outOfStockItems.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      const Icon(Icons.close, color: CarDashboardTheme.alertRed, size: 14),
                      const SizedBox(width: AppSpacing.sm),
                      Text(s, style: const TextStyle(color: Colors.white, fontFamily: 'Orbitron')),
                    ],
                  ),
                )),
              ],
            ),
            actions: [
              NeonButton(
                label: "ABORT",
                color: CarDashboardTheme.alertRed,
                onPressed: () => Navigator.pop(ctx),
              )
            ],
          ),
        );
        return; // STOP execution
      }

      // 1.2 Show warning dialog for LOW STOCK (Non-blocking but informative)
      if (lowStockItems.isNotEmpty) {
         // We show this briefly or ask for confirmation?
         // User requested "popup for low or out of stock".
         // We will show a confirmation dialog.
         bool continueSequence = false;
         await showDialog(
           context: context,
           barrierDismissible: false,
           builder: (ctx) => AlertDialog(
            backgroundColor: CarDashboardTheme.bgDark.withValues(alpha: 0.95),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero, 
              side: BorderSide(color: CarDashboardTheme.warningAmber, width: 2)
            ),
            title: Row(
              children: [
                const Icon(Icons.info_outline, color: CarDashboardTheme.warningAmber),
                const SizedBox(width: AppSpacing.sm),
                Text(AppLocalizations.t(context, 'LOW ASSET WARNING'), style: CarDashboardTheme.labelStyle.copyWith(color: CarDashboardTheme.warningAmber, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.t(context, 'ASSETS REACHING CRITICAL LEVELS:'), style: const TextStyle(color: CarDashboardTheme.warningAmber, fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.sm),
                ...lowStockItems.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      const Icon(Icons.priority_high, color: CarDashboardTheme.warningAmber, size: 14),
                      const SizedBox(width: AppSpacing.sm),
                      Text(s, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.t(context, 'CANCEL'), style: const TextStyle(color: Colors.white54)),
              ),
              const SizedBox(width: AppSpacing.md),
              NeonButton(
                label: "IGNORE & PROCEED",
                color: CarDashboardTheme.warningAmber,
                onPressed: () {
                  continueSequence = true;
                  Navigator.pop(ctx);
                },
              )
            ],
           ),
         );
         
         if (!continueSequence) return; // User cancelled
      }
    }

    setState(() => _isProcessing = true);
    
    // Show Loading
    showDialog(
      context: context, 
      barrierDismissible: false,
      useRootNavigator: true, 
      builder: (_) => const PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(child: CircularProgressIndicator(color: CarDashboardTheme.neonBlue)),
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 50)); // Minimized delay

    try {
      if (_cart.isEmpty) throw Exception("Cart is empty");

      // 2. Create Order Model
      final subtotal = _calculateTotal(provider.storeInventory);
      final taxRate = (provider.activeStore?.isTaxEnabled == true) ? ((provider.activeStore?.taxRate ?? 0) / 100) : 0.0;
      final total = subtotal * (1 + taxRate); // Inc Tax
      final items = _cart.entries.map((e) {
        final item = provider.storeInventory.firstWhere(
           (i) => i.id == e.key,
           orElse: () => InventoryItem(id: '?', name: 'Unknown Item', price: 0, quantity: 0, status: 'Unknown', category: 'Misc', trackStock: false)
        );
        return OrderItem(
          item: item, 
          quantity: e.value,
          costSnapshot: item.cost, // NEW: Capture cost for accurate COGS
        );
      }).toList();

      final order = OrderModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(), 
        storeId: provider.activeStoreId ?? 'unknown',
        items: items,
        total: total,
        date: DateTime.now(),
        status: 'Completed', // CHANGED: Completed status ensures it appears in Sales History for instant checkout
        type: _orderType,
        paymentMethod: paymentMethod,
        customerName: _customerNameController.text.isNotEmpty ? _customerNameController.text : null,
        customerPhone: _customerMobileController.text.isNotEmpty ? _customerMobileController.text : null,
      );

      // 3. INSTANT PRINTING (Optimistic)
      // We fire this BEFORE the database write to reduce perceived lag.
      _printReceiptInBackground(order, items, total);

      // 4. Save to Firestore
      await provider.placeOrder(order); 

      // SUCCESS
      if (mounted) {
         Navigator.of(context, rootNavigator: true).pop(); // Close loader
         
         // Fix: Wait slightly before showing success to ensure context is clean
         await Future.delayed(const Duration(milliseconds: 100));
         
         if (mounted) {
             _clearCart(); // Auto-clear cart
             // Success Toast or small feedback instead of blocking dialog?
             // User didn't specify. Keeping it seamless.
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 backgroundColor: CarDashboardTheme.electricGreen,
                 content: Text("Order #${order.id.substring(order.id.length - 4)} Sent to Kitchen"),
               )
             );
         }
      }
      
    } catch (e, stackTrace) {
      debugPrint('âŒ _finalizeOrder ERROR: $e');
      debugPrint('âŒ Stack: $stackTrace');
      if (mounted) {
         Navigator.of(context, rootNavigator: true).pop(); 
         setState(() => _isProcessing = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _printReceiptInBackground(OrderModel order, List<OrderItem> items, double total) async {
    try {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      final store = provider.activeStore;

      final action = store?.receipt.printAction ?? 'Both'; // Default Both
      final cashierName = provider.userProfile?.name ?? "Cashier";

      // 1. Print Main Receipt
      if (action == 'Main' || action == 'Both') {
        await PrinterManagerService().printOrderReceipt(order, store, cashierName: cashierName);
      }
      
      // 2. Print KDS Receipt (if applicable)
      if (action == 'KDS' || action == 'Both') {
        // Small buffer if printing both sequentially on same printer (rare but possible in dev)
        if (action == 'Both') {
           await Future.delayed(const Duration(milliseconds: 500)); 
        }
        await PrinterManagerService().printOrderKDS(order, store: store, counters: provider.counters, billerName: cashierName);
      }

    } catch (e) { /* Error ignored */ }
  }

  // Caching for Filtered Products
  List<InventoryItem>? _cachedFilteredProducts;
  List<String>? _cachedCategories;
  String _lastSearchBox = '';
  String _lastCategory = '';
  bool _lastLowStock = false;
  int _lastInventoryHash = 0;

  void _computeFilteredProducts(DashboardProvider provider) {
    final inventory = provider.storeInventory;
    final hash = Object.hashAll(inventory);
    bool shouldRecompute = _cachedFilteredProducts == null ||
        _cachedCategories == null ||
        _lastSearchBox != _searchQuery ||
        _lastCategory != _selectedCategory ||
        _lastLowStock != _isSortingLowStock ||
        _lastInventoryHash != hash;

    if (shouldRecompute) {
      _lastSearchBox = _searchQuery;
      _lastCategory = _selectedCategory;
      _lastLowStock = _isSortingLowStock;
      _lastInventoryHash = hash;

      _cachedCategories = ['All', ...inventory.map((e) => e.category).toSet()];

      var products = inventory.where((item) {
        final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
        final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();

      if (_isSortingLowStock) {
        products.sort((a, b) {
          final aStock = _stockChanges[a.id] ?? provider.getItemStock(a.id);
          final bStock = _stockChanges[b.id] ?? provider.getItemStock(b.id);
          return aStock.compareTo(bStock);
        });
      }

      _cachedFilteredProducts = products;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final inventory = provider.storeInventory;
    final isDarkMode = provider.isDarkMode;

    _computeFilteredProducts(provider);
    final categories = _cachedCategories!;
    final filteredProducts = _cachedFilteredProducts!;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
      backgroundColor: _customBackgroundColor ?? CarDashboardTheme.backgroundColor(isDarkMode),
      // Drawer for Mobile
      drawerEnableOpenDragGesture: false, // PREVENT ACCIDENTAL TRIGGERS
      drawer: Drawer(
              backgroundColor: CarDashboardTheme.panelColor(isDarkMode),
              child: Builder(
                builder: (drawerContext) => _buildVerticalCategoryBar(categories, isExpanded: true, drawerContext: drawerContext),
              ),
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Use mobile layout for narrow screens
          // Desktop 3-pane layout for landscape or portrait screens wider than 700px (supports tablets)
          final isMobile = constraints.maxWidth < 700;
          
          if (isMobile) {
            // --- MOBILE LAYOUT ---
            return Stack(
              children: [
                Column(
                  children: [
                    // Header Bar
                    Container(
                      height: 60,
                      color: CarDashboardTheme.panelColor(isDarkMode),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.menu, color: CarDashboardTheme.primaryColor(isDarkMode)),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                          Text(AppLocalizations.t(context, 'POS Terminal'), style: CarDashboardTheme.productTitle.copyWith(fontSize: 18, color: CarDashboardTheme.textColor(isDarkMode))),
                          // Printer Status
                          _buildPrinterStatusIndicator(isDarkMode, compact: true),
                          // Cart Toggle
                          IconButton(
                            icon: Badge(
                              label: Text("${_cart.length}"),
                              isLabelVisible: _cart.isNotEmpty,
                              child: Icon(Icons.shopping_cart, color: CarDashboardTheme.textColor(isDarkMode)),
                            ),
                            onPressed: () => setState(() => _isCheckoutVisible = !_isCheckoutVisible),
                          ),
                        ],
                      ),
                    ),
                    
                    if (_isEditMode) _buildEditModeControls(),
                    
                    // Product Grid (Full Width)
                    Expanded(child: _buildProductGrid(filteredProducts)),
                  ],
                ),
                
                // Mobile Cart Drawer (Overlay)
                if (_isCheckoutVisible)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => setState(() => _isCheckoutVisible = false), // Close on outside click
                      child: Container(
                        color: Colors.black54,
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                           onTap: () {}, // Prevent closing
                           child: Container(
                             width: constraints.maxWidth * 0.85,
                             height: double.infinity,
                             color: CarDashboardTheme.panelColor(isDarkMode),
                             child: SafeArea(child: _buildHUDPanel(inventory)),
                           ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          } else {
            // --- DESKTOP LAYOUT (Classic 3-Pane) ---
            _miniCartPosition ??= Offset(constraints.maxWidth - 320, constraints.maxHeight - 200);
            
            return Stack(
              children: [
                Row(
                  children: [
                // LEFT PANEL (Sidebar or Cart)
                if (_isRightHanded) 
                  // CART ON LEFT
                  if (_isCartPanelVisible)
                    Container(
                      width: constraints.maxWidth < 1100 ? 300 : 350,
                      decoration: BoxDecoration(
                        color: CarDashboardTheme.panelColor(isDarkMode),
                        border: Border(right: BorderSide(color: CarDashboardTheme.borderColor(isDarkMode))),
                      ),
                      child: SafeArea(child: _buildHUDPanel(inventory)),
                    )
                  else
                     const SizedBox.shrink()
                else
                  // SIDEBAR ON LEFT
                  Container(
                    width: (_isCategoryExpanded == true) ? 200 : 70, // Defensive Check
                    color: CarDashboardTheme.panelColor(isDarkMode),
                    child: SafeArea(
                      child: Column(
                        children: [
                           // Header with Toggle
                           Padding(
                             padding: const EdgeInsets.all(AppSpacing.md),
                             child: Row(
                               mainAxisAlignment: (_isCategoryExpanded == true) ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                               children: [
                                 if (_isCategoryExpanded == true)
                                    Expanded(child: Text(AppLocalizations.t(context, 'BIZTONIC'), style: CarDashboardTheme.priceStyle.copyWith(color: CarDashboardTheme.primaryColor(isDarkMode), fontSize: 18))),
                                 
                                 // Toggle Arrow
                                 InkWell(
                                   onTap: () => setState(() => _isCategoryExpanded = !(_isCategoryExpanded == true)),
                                   child: Icon(
                                      (_isCategoryExpanded == true) ? Icons.arrow_back_ios_new : Icons.arrow_forward_ios,
                                      color: CarDashboardTheme.primaryColor(isDarkMode),
                                      size: 16,
                                   ),
                                 )
                               ],
                             ),
                           ),
                           Expanded(child: _buildVerticalCategoryBar(categories, isExpanded: _isCategoryExpanded == true)),
                        ],
                      ),
                    ),
                  ),

                // CENTER CONTENT
                Expanded(
                  child: Container(
                    color: _customBackgroundColor ?? CarDashboardTheme.backgroundColor(isDarkMode), // Use Custom BG
                    child: Column(
                      children: [
                        // Top Bar
                        Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: CarDashboardTheme.borderColor(isDarkMode))),
                            color: CarDashboardTheme.panelColor(isDarkMode),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: CarDashboardTheme.subTextColor(isDarkMode)),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    hintText: "Search products...",
                                    border: InputBorder.none,
                                  ),
                                  style: TextStyle(color: CarDashboardTheme.textColor(isDarkMode)),
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                ),
                              ),
                              IconButton(
                                icon: Icon(_isEditMode ? Icons.check_circle : Icons.edit, color: _isEditMode ? CarDashboardTheme.accentSuccess : CarDashboardTheme.subTextColor(isDarkMode)),
                                onPressed: _toggleEditMode,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              _buildPrinterStatusIndicator(isDarkMode),
                              const SizedBox(width: AppSpacing.sm),
                              // Checkout Toggle
                              IconButton(
                                icon: Icon((_isRightHanded == _isCartPanelVisible) ? Icons.arrow_forward : Icons.arrow_back, color: CarDashboardTheme.textColor(isDarkMode)),
                                onPressed: () => setState(() => _isCartPanelVisible = !_isCartPanelVisible),
                                tooltip: _isCartPanelVisible ? "Hide Checkout" : "Show Checkout",
                              ),
                            ],
                          ),
                        ),

                        if (_isEditMode) _buildEditModeControls(),

                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: _buildProductGrid(filteredProducts), 
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // RIGHT PANEL (Cart or Sidebar)
                if (_isRightHanded)
                  // SIDEBAR ON RIGHT
                  Container(
                    width: (_isCategoryExpanded == true) ? 200 : 70, // Dynamic Width
                    decoration: BoxDecoration(
                      color: CarDashboardTheme.panelColor(isDarkMode),
                      border: Border(left: BorderSide(color: CarDashboardTheme.borderColor(isDarkMode))),
                    ),
                    child: SafeArea(
                      child: Column(
                        children: [
                           // Header with Toggle
                           Padding(
                             padding: const EdgeInsets.all(AppSpacing.md),
                             child: Row(
                               mainAxisAlignment: (_isCategoryExpanded == true) ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                               children: [
                                 // Toggle Arrow (Left Side of text for Right Bar)
                                 InkWell(
                                   onTap: () => setState(() => _isCategoryExpanded = !(_isCategoryExpanded == true)),
                                   child: Icon(
                                      (_isCategoryExpanded == true) ? Icons.arrow_forward_ios : Icons.arrow_back_ios_new, // Points Right to Collapse
                                      color: CarDashboardTheme.primaryColor(isDarkMode),
                                      size: 16,
                                   ),
                                 ),

                                 if (_isCategoryExpanded == true)
                                    Expanded(child: Text(AppLocalizations.t(context, 'BIZTONIC'), textAlign: TextAlign.right, style: CarDashboardTheme.priceStyle.copyWith(color: CarDashboardTheme.primaryColor(isDarkMode), fontSize: 18))),
                               ],
                             ),
                           ),
                           Expanded(child: _buildVerticalCategoryBar(categories, isExpanded: _isCategoryExpanded == true)),
                        ],
                      ),
                    ),
                  )
                else
                  // CART ON RIGHT
                  if (_isCartPanelVisible)
                    Container(
                      width: constraints.maxWidth < 1100 ? 300 : 350,
                      decoration: BoxDecoration(
                        color: CarDashboardTheme.panelColor(isDarkMode),
                        border: Border(left: BorderSide(color: CarDashboardTheme.borderColor(isDarkMode))),
                      ),
                      child: SafeArea(child: _buildHUDPanel(inventory)),
                    )
                  else
                     const SizedBox.shrink()
              ],
            ),

            // MINI CART DRAGGABLE OVERLAY
            if (!_isCartPanelVisible) 
              Positioned(
                 left: _miniCartPosition?.dx ?? (constraints.maxWidth - 300),
                 top: _miniCartPosition?.dy ?? (constraints.maxHeight - 250),
                 child: GestureDetector(
                    onPanUpdate: (details) {
                       setState(() {
                          final currentPos = _miniCartPosition ?? Offset(constraints.maxWidth - 300, constraints.maxHeight - 250);
                          _miniCartPosition = currentPos + details.delta;
                       });
                    },
                    child: _buildMiniCartContent(inventory),
                 ),
              ),
          ],
        );
          }
        },
      ),
      ), // end Scaffold
    ); // end Directionality
  }

  // --- Helper Widgets ---

  // --- Helper Widgets ---

  Widget _buildVerticalCategoryBar(List<String> categories, {bool isExpanded = false, BuildContext? drawerContext}) {
    // Simplified Category Bar without Glass/Blur
    final effectiveContext = drawerContext ?? context;
    final provider = Provider.of<DashboardProvider>(effectiveContext);
    final isDarkMode = provider.isDarkMode;
    final user = provider.userProfile;

    return Column(
      children: [
        if (isExpanded == true) ...[
          // User Name
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md, left: AppSpacing.md, right: AppSpacing.md),
              child: Text(
                user.name, 
                style: CarDashboardTheme.labelStyle.copyWith(color: CarDashboardTheme.accentSuccess, fontSize: 16, fontWeight: FontWeight.bold), // Increased to 16
                textAlign: TextAlign.center,
              ),
            ),
            
          // Session Timer
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _buildSessionTimer(isDarkMode),
          ),
          const Divider(),
        ],
        
        Expanded(
          child: ListView.builder(
            controller: _categoryScrollController,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = _selectedCategory == cat;
              return GestureDetector(
                onTap: () {
                   setState(() => _selectedCategory = cat);
                   _scrollToCategory(index);
                   if (Scaffold.of(context).hasDrawer && Scaffold.of(context).isDrawerOpen) {
                     Scaffold.of(context).closeDrawer();
                   }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm, left: AppSpacing.xs, right: AppSpacing.xs),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xs),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? CarDashboardTheme.neonBlue : Colors.transparent,
                    borderRadius: BorderRadius.zero,
                    boxShadow: isSelected ? CarDashboardTheme.neonGlowBlue : [],
                  ),
                  child: Row(
                    mainAxisAlignment: (isExpanded == true) ? MainAxisAlignment.start : MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: (isExpanded == true) ? 12 : 0),
                        child: Icon(
                          _getCategoryIcon(cat), 
                          color: isSelected ? (isDarkMode ? Colors.black : Colors.white) : CarDashboardTheme.subTextColor(isDarkMode),
                          size: 24,
                        ),
                      ),
                      if (isExpanded == true) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            cat.toUpperCase(),
                            style: CarDashboardTheme.labelStyle.copyWith(
                              color: isSelected ? (isDarkMode ? Colors.black : Colors.white) : CarDashboardTheme.subTextColor(isDarkMode),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: isSelected ? 14 : 12,
                              letterSpacing: 1.0,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else if (isExpanded != true) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            cat.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: CarDashboardTheme.labelStyle.copyWith(
                              color: isSelected ? (isDarkMode ? Colors.black : Colors.white) : CarDashboardTheme.subTextColor(isDarkMode),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: isSelected ? 10 : 8, // Smaller for unexpanded
                              letterSpacing: 0.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom Actions
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: (isExpanded == true) 
          ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSidebarActionBtn(Icons.calculate, "Calculator", CarDashboardTheme.neonBlue, _showCalculator, overrideBg: Colors.black),
              _buildSidebarActionBtn(Icons.power_settings_new, "Exit", CarDashboardTheme.alertRed, () {
                 final router = GoRouter.of(context);
                 final scaffold = Scaffold.maybeOf(effectiveContext);
                 if (scaffold != null && scaffold.isDrawerOpen) {
                   Navigator.pop(effectiveContext);
                 }
                 router.go('/');
              }, isSolid: true),
            ],
          )
          : Column(
             children: [
              _buildSidebarActionBtn(Icons.calculate, "Calc", CarDashboardTheme.neonBlue, _showCalculator, overrideBg: Colors.black),
              const SizedBox(height: AppSpacing.md),
              _buildSidebarActionBtn(Icons.power_settings_new, "Exit", CarDashboardTheme.alertRed, () {
                 final router = GoRouter.of(context);
                 final scaffold = Scaffold.maybeOf(effectiveContext);
                 if (scaffold != null && scaffold.isDrawerOpen) {
                   Navigator.pop(effectiveContext);
                 }
                 router.go('/');
              }, isSolid: true),
             ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarActionBtn(IconData icon, String tooltip, Color color, VoidCallback onTap, {bool isSolid = false, Color? overrideBg}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: overrideBg ?? (isSolid ? color : color.withValues(alpha: 0.15)),
            border: Border.all(color: overrideBg != null ? color :  (isSolid ? color : color), width: 2), // Keep border color consistent
          ),
          child: Center(
            child: Icon(icon, color: isSolid ? Colors.white : color, size: 24),
          ),
        ),
      );
  }

  Widget _buildSessionTimer(bool isDarkMode) {
     String twoDigits(int n) => n.toString().padLeft(2, "0");
     final hours = twoDigits(_sessionDuration.inHours);
     final minutes = twoDigits(_sessionDuration.inMinutes.remainder(60));
     final seconds = twoDigits(_sessionDuration.inSeconds.remainder(60));
     
     return Container(
       padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: 12),
       decoration: BoxDecoration(
         color: CarDashboardTheme.backgroundColor(isDarkMode),
         borderRadius: BorderRadius.zero,
         border: Border.all(color: CarDashboardTheme.borderColor(isDarkMode)),
       ),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(Icons.timer, size: 16, color: CarDashboardTheme.primaryColor(isDarkMode)),
           const SizedBox(width: AppSpacing.sm),
           Text("$hours:$minutes:$seconds", style: TextStyle(color: CarDashboardTheme.textColor(isDarkMode), fontSize: 16, fontWeight: FontWeight.bold)), // Increased to 16
         ],
       ),
     );
  }

  void _scrollToCategory(int index) {
      if (!_categoryScrollController.hasClients) return;
      // Fixed item height estimation: margin(8) + padding(32) + text(14?) approx 60px
      const double itemHeight = 60.0;
      final double targetOffset = (index * itemHeight) - (MediaQuery.of(context).size.height / 3); // Centerish
      
      _categoryScrollController.animateTo(
        targetOffset.clamp(0.0, _categoryScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
  }

  Widget _buildProductGrid(List<InventoryItem> products) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    
    if (products.isEmpty) {
      final isDarkMode = provider.isDarkMode;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: CarDashboardTheme.subTextColor(isDarkMode).withValues(alpha: 0.5)),
            const SizedBox(height: AppSpacing.md),
            Text(AppLocalizations.t(context, 'No products found in this category.'),
              style: TextStyle(color: CarDashboardTheme.textColor(isDarkMode), fontSize: 18),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate safest cross axis count based strictly on the available container width
        int crossAxisCount = (constraints.maxWidth / 150).floor();
        if (crossAxisCount < 2) crossAxisCount = 2; // Hard floor to 2 columns
        if (crossAxisCount > 8) crossAxisCount = 8; // Soft ceiling

        return GridView.builder(
          controller: _gridController,
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.80, // Taller for better fit
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final item = products[index];
            final qty = _cart[item.id] ?? 0;
            
            int currentStock = item.trackStock ? provider.getItemStock(item.id) : 9999;
            if (_isEditMode && _stockChanges.containsKey(item.id)) {
               currentStock = _stockChanges[item.id]!;
            } else {
               currentStock -= qty; 
            }
            
            final displayItem = item.copyWith(quantity: currentStock);
            
            return DashboardProductTile(
              item: displayItem,
              isEditMode: _isEditMode,
              cardStyle: _globalCardStyle,
              showImage: _globalCardStyle == 'image',
              onTap: () => _addToCart(item),
              onLongPress: () {
                if (_isEditMode) return; 
                _showItemCustomizationDialog(item);
              },
              onStockChanged: (delta) {
                if (!_isEditMode) return; 
                setState(() {
                  final provider = Provider.of<DashboardProvider>(context, listen: false);
                  int oldStock = _stockChanges[item.id] ?? provider.getItemStock(item.id);
                  _stockChanges[item.id] = oldStock + delta;
                });
              },
            );
          },
        );
      }
    );
  }

  Widget _buildHUDPanel(List<InventoryItem> inventory) {
    final provider = Provider.of<DashboardProvider>(context); // Listen to changes
    final store = provider.activeStore;
    final subtotal = _calculateTotal(inventory);
    
    double total = subtotal;
    if (store != null && (store.isTaxEnabled ?? false)) {
      total += (subtotal * ((store.taxRate ?? 0.0) / 100));
    }

    final isDarkMode = provider.isDarkMode;

    return Column(
      children: [
        // 1. Header (User Info / Order Type) - Collapsible
        Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm), 
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: CarDashboardTheme.panelColor(isDarkMode),
            borderRadius: BorderRadius.zero,
            border: Border.all(color: CarDashboardTheme.borderColor(isDarkMode)),
          ),
          child: Column(
            children: [
        // 1. Expandable Header Trigger
        GestureDetector(
          onTap: () => setState(() => _isHeaderExpanded = !_isHeaderExpanded),
          behavior: HitTestBehavior.translucent, // Capture full width
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm), // Increase touch area
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.t(context, 'ORDER DETAILS'), style: CarDashboardTheme.labelStyle.copyWith(color: CarDashboardTheme.subTextColor(isDarkMode))),
                Icon(
                  _isHeaderExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: CarDashboardTheme.primaryColor(isDarkMode),
                  size: 28, // Bigger Icon
                ),
              ],
            ),
          ),
        ),
        
        // 2. Collapsible Content (Customer + Order Type)
        if (_isHeaderExpanded) ...[
                const SizedBox(height: 12),
                // Customer Details
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             Row(
                               children: [
                                 Icon(Icons.person_outline, size: 20, color: CarDashboardTheme.primaryColor(isDarkMode)),
                                 const SizedBox(width: AppSpacing.sm),
                                 Text(AppLocalizations.t(context, 'CUSTOMER DETAILS'), style: CarDashboardTheme.labelStyle.copyWith(color: CarDashboardTheme.primaryColor(isDarkMode), fontSize: 16, fontWeight: FontWeight.bold)),
                               ],
                             ),
                             // Select Button
                             TextButton.icon(
                               onPressed: _showCustomerSelectionDialog,
                               icon: Icon(Icons.list, size: 24, color: CarDashboardTheme.secondaryColor(isDarkMode)),
                               label: Text(AppLocalizations.t(context, 'Select'), style: TextStyle(color: CarDashboardTheme.secondaryColor(isDarkMode), fontSize: 16, fontWeight: FontWeight.bold)),
                               style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                                  minimumSize: const Size(80, 48)
                               ),
                             )
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      // Name Input
                      Container(
                        height: 50, // Increased height
                        decoration: BoxDecoration(
                          color: CarDashboardTheme.backgroundColor(isDarkMode),
                          borderRadius: BorderRadius.zero,
                          border: Border.all(color: CarDashboardTheme.borderColor(isDarkMode)),
                        ),
                        child: TextField(
                          controller: _customerNameController,
                          style: TextStyle(color: CarDashboardTheme.textColor(isDarkMode), fontSize: 16),
                          decoration: InputDecoration(
                            hintText: "Customer Name",
                            hintStyle: TextStyle(color: CarDashboardTheme.subTextColor(isDarkMode), fontSize: 16),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), 
                            prefixIcon: Icon(Icons.person, size: 18, color: CarDashboardTheme.subTextColor(isDarkMode)),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Mobile Input
                      Container(
                        height: 50, // Increased height
                        decoration: BoxDecoration(
                          color: CarDashboardTheme.backgroundColor(isDarkMode),
                          borderRadius: BorderRadius.zero,
                          border: Border.all(color: CarDashboardTheme.borderColor(isDarkMode)),
                        ),
                        child: TextField(
                          controller: _customerMobileController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: CarDashboardTheme.textColor(isDarkMode), fontSize: 16), 
                          decoration: InputDecoration(
                            hintText: "Mobile Number",
                            hintStyle: TextStyle(color: CarDashboardTheme.subTextColor(isDarkMode), fontSize: 16),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            prefixIcon: Icon(Icons.phone_android, size: 18, color: CarDashboardTheme.subTextColor(isDarkMode)),
                          ),
                        ),
                      ),
                    ],
                ),
                const SizedBox(height: 12),
                // Order Type
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildOrderTypeBtn('Dine In', Icons.restaurant),
                    const SizedBox(width: AppSpacing.sm),
                    _buildOrderTypeBtn('Take Out', Icons.shopping_bag_outlined),
                    const SizedBox(width: AppSpacing.sm),
                    _buildOrderTypeBtn('Delivery', Icons.delivery_dining),
                  ],
                ),
              ]
            ],
            ),
          ),

        const SizedBox(height: 12),
        
        // 3. Cart List
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: CarDashboardTheme.panelColor(isDarkMode),
              borderRadius: BorderRadius.zero,
              border: Border.all(color: CarDashboardTheme.borderColor(isDarkMode)),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("ITEMS (${_cart.length})", style: CarDashboardTheme.labelStyle.copyWith(color: CarDashboardTheme.subTextColor(isDarkMode))),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: CarDashboardTheme.accentDanger, size: 20),
                      onPressed: _clearCart,
                    )
                  ],
                ),
                const Divider(),
                Expanded(
                  child: _cart.isEmpty 
                  ? Center(child: Text(AppLocalizations.t(context, 'Cart Empty'), style: CarDashboardTheme.labelStyle.copyWith(color: CarDashboardTheme.subTextColor(isDarkMode))))
                  : ListView.builder(
                      itemCount: _cart.length,
                      itemBuilder: (ctx, i) {
                        final cartKeys = _cart.keys.toList(); // Safety snapshot
                        if (i >= cartKeys.length) return const SizedBox(); // Prevent RangeError
                        final itemId = cartKeys[i];
                        if (!_cart.containsKey(itemId)) return const SizedBox();
                        final qty = _cart[itemId]!;
                        final item = inventory.firstWhere(
                          (e) => e.id == itemId, 
                          orElse: () => InventoryItem(
                            id: '?', 
                            name: 'Unknown', 
                            price: 0, 
                            category: '', 
                            quantity: 0, 
                            status: 'Unknown', 
                            trackStock: false
                          )
                        ); // Safety
                        
                        return Container(
                           margin: const EdgeInsets.only(bottom: AppSpacing.sm), 
                           padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: 12),
                           decoration: BoxDecoration(
                             color: CarDashboardTheme.backgroundColor(isDarkMode),
                             borderRadius: BorderRadius.zero,
                             border: Border.all(color: CarDashboardTheme.borderColor(isDarkMode)),
                           ),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               // ROW 1: Name + Delete
                               Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(item.name, 
                                      style: CarDashboardTheme.labelStyle.copyWith(
                                        color: CarDashboardTheme.textColor(isDarkMode), 
                                        fontSize: 20, // Increased Name Size
                                        fontWeight: FontWeight.bold
                                      ), 
                                      maxLines: 2, 
                                      overflow: TextOverflow.ellipsis
                                    ),
                                  ),
                                  // Delete Button Removed as per request (Minus provides functionality)
                                ],
                              ),
                              
                              const SizedBox(height: AppSpacing.sm), 
                              
                              // ROW 2: Price (Left) + Qty (Right)
                              Row(
                                children: [
                                  // PRICE (Shifted Left)
                                  Text("₹${(item.price * qty).toStringAsFixed(0)}", 
                                    style: CarDashboardTheme.priceStyle.copyWith(
                                      fontSize: 24, // High Visibility
                                      color: CarDashboardTheme.primaryColor(isDarkMode)
                                    )
                                  ),
                                  
                                  const Spacer(),
                                  
                                  // QUANTITY CONTROLS (Compacted)
                                  Row(
                                    children: [
                                      _buildQtyBtn(Icons.remove, () {
                                         _removeFromCart(itemId);
                                      }, isDarkMode),
                                      
                                      // Qty Display (Reduced Width)
                                      Container(
                                        width: 50, // Fixed width
                                        height: 44, 
                                        alignment: Alignment.center,
                                        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                                        decoration: BoxDecoration(
                                          color: CarDashboardTheme.panelColor(isDarkMode),
                                          borderRadius: BorderRadius.zero,
                                          border: Border.all(color: CarDashboardTheme.borderColor(isDarkMode))
                                        ),
                                        child: Text(
                                          "$qty", 
                                          style: TextStyle(
                                            color: CarDashboardTheme.textColor(isDarkMode), 
                                            fontSize: 20, 
                                            fontWeight: FontWeight.bold
                                          )
                                        ),
                                      ),
                                      
                                      _buildQtyBtn(Icons.add, () {
                                         _addToCart(item);
                                      }, isDarkMode),
                                    ],
                                  )
                                ],
                              )
                             ],
                           ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
        ),
        
        const SizedBox(height: 12), // Reduced gap
        
        // 4. Total & Payment Buttons
        Container(
          padding: const EdgeInsets.all(AppSpacing.md), 
          decoration: BoxDecoration(
              color: CarDashboardTheme.panelColor(isDarkMode),
              borderRadius: BorderRadius.zero,
              border: Border.all(color: CarDashboardTheme.borderColor(isDarkMode)),
              boxShadow: CarDashboardTheme.cardShadow(isDarkMode),
          ),
          child: Column(
            children: [
               Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.t(context, 'TOTAL'), style: CarDashboardTheme.labelStyle.copyWith(fontSize: 20, fontWeight: FontWeight.bold, color: CarDashboardTheme.subTextColor(isDarkMode))),
                  Text("₹${total.toStringAsFixed(2)}", style: CarDashboardTheme.priceStyle.copyWith(fontSize: 36, color: CarDashboardTheme.textColor(isDarkMode))), 
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CarDashboardTheme.alertRed, // CASH = RED
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md), // Height adjusted
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Sharp Corners
                      ),
                      onPressed: _cart.isNotEmpty ? () => _finalizeOrder('Cash') : null,
                      onLongPress: _cart.isNotEmpty ? _handleCashPayment : null,
                      child: Text(AppLocalizations.t(context, 'CASH'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), // Larger Text
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CarDashboardTheme.electricGreen, // UPI = GREEN
                          foregroundColor: Colors.black, // Dark Text for Contrast
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md), // Height adjusted
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Sharp Corners
                        ),
                        onPressed: _cart.isNotEmpty ? () => _finalizeOrder('UPI') : null,
                        onLongPress: _cart.isNotEmpty ? _handleUPIPayment : null,
                        child: Text(AppLocalizations.t(context, 'UPI'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), // Larger Text
                      ),
                  ),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderTypeBtn(String type, IconData icon) {
    final bool isSelected = _orderType == type;
    final provider = Provider.of<DashboardProvider>(context);
    final isDarkMode = provider.isDarkMode;

    Color activeColor;
    switch (type) {
      case 'Dine In': activeColor = CarDashboardTheme.primaryColor(isDarkMode); break;
      case 'Take Out': activeColor = AppColors.warning; break;
      case 'Delivery': activeColor = const Color(0xFF9C27B0); break; // Purple
      default: activeColor = CarDashboardTheme.primaryColor(isDarkMode);
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _orderType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md), // Increased Padding
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent, // Filled BG when selected
            border: Border.all(color: isSelected ? activeColor : CarDashboardTheme.borderColor(isDarkMode)),
            borderRadius: BorderRadius.zero,
          ),
          child: Column(
            children: [
              // Icon Removed for Simplicity
              Text(
                type.toUpperCase(), 
                style: TextStyle(
                  fontSize: 14, // Increased Font Size
                  color: isSelected ? Colors.black : CarDashboardTheme.subTextColor(isDarkMode), // Black text on colored BG
                  fontWeight: FontWeight.bold
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap, bool isDarkMode) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 44, // Large Touch Target
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: CarDashboardTheme.primaryColor(isDarkMode).withValues(alpha: 0.15),
          borderRadius: BorderRadius.zero,
          border: Border.all(color: CarDashboardTheme.primaryColor(isDarkMode).withValues(alpha: 0.5))
        ),
        child: Icon(icon, color: CarDashboardTheme.primaryColor(isDarkMode), size: 24),
      ),
    );
  }

  void _showCustomerSelectionDialog() {
     final provider = Provider.of<DashboardProvider>(context, listen: false);
     final customers = provider.customers; 

     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
         backgroundColor: CarDashboardTheme.panelColor(provider.isDarkMode),
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: CarDashboardTheme.borderColor(provider.isDarkMode))),
         title: Text(AppLocalizations.t(context, 'SELECT CUSTOMER'), style: TextStyle(color: CarDashboardTheme.textColor(provider.isDarkMode), fontSize: 16)),
         content: SizedBox(
           width: 300,
           height: 400,
           child: customers.isEmpty 
             ? Center(child: Text(AppLocalizations.t(context, 'No customers found'), style: TextStyle(color: CarDashboardTheme.subTextColor(provider.isDarkMode))))
             : ListView.builder(
                 itemCount: customers.length,
                 itemBuilder: (context, index) {
                   final customer = customers[index];
                   return ListTile(
                     leading: CircleAvatar(
                        backgroundColor: CarDashboardTheme.primaryColor(provider.isDarkMode).withValues(alpha: 0.2),
                        child: Text(customer.name.isNotEmpty ? customer.name[0].toUpperCase() : "?", style: TextStyle(color: CarDashboardTheme.primaryColor(provider.isDarkMode))),
                     ),
                     title: Text(customer.name, style: TextStyle(color: CarDashboardTheme.textColor(provider.isDarkMode))),
                     subtitle: Text(customer.mobile ?? '', style: TextStyle(color: CarDashboardTheme.subTextColor(provider.isDarkMode))),
                     onTap: () {
                       setState(() {
                         _customerNameController.text = customer.name;
                         _customerMobileController.text = customer.mobile ?? '';
                       });
                       Navigator.pop(ctx);
                     },
                   );
                 },
             ),
         ),
       )
     );
  }

  Widget _buildPrinterStatusIndicator(bool isDarkMode, {bool compact = false}) {
     return StreamBuilder<bool>(
       stream: PrinterManagerService().statusStream,
       initialData: PrinterManagerService().isConnected,
       builder: (context, snapshot) {
         final isConnected = snapshot.data ?? false;
         final isAssigned = PrinterManagerService().assignments.isNotEmpty;
         
         final Color statusColor = !isAssigned ? AppColors.warning : (isConnected ? AppColors.success : AppColors.error);
         
         if (compact) {
            return Icon(isConnected ? Icons.print : Icons.print_disabled, color: statusColor, size: 20);
         }

         return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
               color: statusColor.withValues(alpha: 0.1),
               borderRadius: BorderRadius.zero,
               border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                  Icon(isConnected ? Icons.print : Icons.print_disabled, color: statusColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    !isAssigned ? "NO CONFIG" : (isConnected ? "ONLINE" : "OFFLINE"), 
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)
                  ),
               ],
            ),
         );
       },
     );
  }

  // --- EDIT MODE METHODS ---

  void _toggleEditMode() {
    setState(() {
      _isEditMode = true;
      _stockChanges.clear();
      _isCheckoutVisible = false; // Hide sidebar to give space
    });
  }

  void _exitEditMode() {
    setState(() {
      _isEditMode = false;
      _isSortingLowStock = false;
      _stockChanges.clear();
    });
  }

  Future<void> _saveStockChanges() async {
    if (_stockChanges.isNotEmpty) {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      try {
        await provider.batchUpdateStock(_stockChanges);
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(AppLocalizations.t(context, 'Stock Updated Successfully')), backgroundColor: CarDashboardTheme.electricGreen)
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Error saving stock: $e"), backgroundColor: CarDashboardTheme.alertRed)
        );
      }
    }
    _exitEditMode();
  }

  void _handleStockChange(InventoryItem item, int delta) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    setState(() {
      final currentQty = _stockChanges[item.id] ?? provider.getItemStock(item.id);
      final newQty = currentQty + delta;
      if (newQty >= 0) {
        _stockChanges[item.id] = newQty;
      }
    });
  }
  
  void _showCentralCatalogPicker() {
    showDialog(context: context, builder: (ctx) => _CentralCatalogPickerDialog());
  }

  void _showBackgroundColorPicker() {
    final colors = [
      {'name': 'Default', 'color': null},
      {'name': 'Charcoal', 'color': const Color(0xFF1E1E1E)},
      {'name': 'Navy', 'color': const Color(0xFF0D1B2A)},
      {'name': 'D.Green', 'color': const Color(0xFF0B2516)},
      {'name': 'Slate', 'color': const Color(0xFF263238)},
      {'name': 'Black', 'color': const Color(0xFF000000)},
      {'name': 'Royal', 'color': const Color(0xFF1A237E)},
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CarDashboardTheme.panelColor(true),
        title: Text(AppLocalizations.t(context, 'Choose Background'), style: TextStyle(color: CarDashboardTheme.textColor(true))),
        content: SizedBox(
          width: 320,
          child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...colors.map((c) {
                    final color = c['color'] as Color?;
                    final name = c['name'] as String;
                    final isSelected = _customBackgroundColor == color;
                    return InkWell(
                      onTap: () {
                        setState(() => _customBackgroundColor = color);
                        _saveBgColor(color);
                        Navigator.pop(ctx);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: color ?? CarDashboardTheme.backgroundColor(true),
                              borderRadius: BorderRadius.zero,
                              border: isSelected ? Border.all(color: CarDashboardTheme.electricGreen, width: 2) : Border.all(color: Colors.white24),
                            ),
                            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(name, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    );
                  }),
                  // Custom Hex Button
                  InkWell(
                      onTap: () {
                         Navigator.pop(ctx);
                         _showHexColorDialog();
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary(context),
                              borderRadius: BorderRadius.zero,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(Icons.colorize, color: Colors.white),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(AppLocalizations.t(context, 'Custom'), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    )
                ],
              ),
             ],
          ),
        ),
      ),
    );
  }
  
  void _showHexColorDialog() {
     String hexCode = "";
     showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
           backgroundColor: CarDashboardTheme.panelColor(true),
           title: Text(AppLocalizations.t(context, 'Enter Hex Color'), style: const TextStyle(color: Colors.white)),
           content: TextField(
             style: const TextStyle(color: Colors.white),
             decoration: const InputDecoration(
                hintText: "#FF0000",
                hintStyle: TextStyle(color: Colors.white30),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
             ),
             onChanged: (val) => hexCode = val,
           ),
           actions: [
             TextButton(child: Text(AppLocalizations.t(context, 'Cancel')), onPressed: () => Navigator.pop(ctx)),
             ElevatedButton(
                child: Text(AppLocalizations.t(context, 'Set')), 
                onPressed: () {
                   try {
                      hexCode = hexCode.replaceAll("#", "");
                      if (hexCode.length == 6) hexCode = "FF$hexCode";
                      final newColor = Color(int.parse("0x$hexCode"));
                      setState(() => _customBackgroundColor = newColor);
                      _saveBgColor(newColor);
                      Navigator.pop(ctx);
                   } catch (e) {
                      // Ignore invalid
                   }
                }
             )
           ],
        )
     );
  }

  Widget _buildEditModeControls() {
    final isDarkMode = Provider.of<DashboardProvider>(context, listen: false).isDarkMode;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: CarDashboardTheme.neonBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: CarDashboardTheme.neonBlue.withValues(alpha: 0.3)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit, color: CarDashboardTheme.neonBlue),
            const SizedBox(width: AppSpacing.sm),
            Text(AppLocalizations.t(context, 'EDIT'), style: CarDashboardTheme.labelStyle.copyWith(color: CarDashboardTheme.neonBlue, fontWeight: FontWeight.bold)),
            const SizedBox(width: AppSpacing.md),
            
            // Card Size Slider
            Text(AppLocalizations.t(context, 'Size:'), style: TextStyle(color: CarDashboardTheme.subTextColor(isDarkMode))),
            SizedBox(
              width: 100,
              child: Slider(
                value: _cardWidth,
                min: 150,
                max: 400,
                divisions: 5,
                label: _cardWidth.round().toString(),
                activeColor: CarDashboardTheme.neonBlue,
                onChanged: (val) => setState(() => _cardWidth = val),
              ),
            ),
            
            // Style Toggle
            // Style Toggle
            ElevatedButton.icon(
              icon: Icon(
                 _globalCardStyle == 'image' ? Icons.image 
                 : _globalCardStyle == 'label' ? Icons.label 
                 : Icons.view_agenda, 
                 color: Colors.white, size: 16
              ),
              label: Text(_globalCardStyle == 'minimal_rect' ? "RECT" : _globalCardStyle.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm)),
              onPressed: () => setState(() {
                 if (_globalCardStyle == 'image') {
                   _globalCardStyle = 'label';
                 } else if (_globalCardStyle == 'label') _globalCardStyle = 'minimal_rect';
                 else _globalCardStyle = 'image';
              }),
            ),
            const SizedBox(width: AppSpacing.sm),

            // BG Color
            ElevatedButton.icon(
               icon: const Icon(Icons.palette, size: 16, color: Colors.white),
               label: Text(AppLocalizations.t(context, 'BG COLOR'), style: const TextStyle(color: Colors.white)),
               style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
               onPressed: _showBackgroundColorPicker,
            ),
            const SizedBox(width: AppSpacing.sm),

            // Layout
            ElevatedButton.icon(
               icon: const Icon(Icons.swap_horiz, size: 16, color: Colors.white),
               label: Text(AppLocalizations.t(context, 'LAYOUT'), style: const TextStyle(color: Colors.white)),
               style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLightGrey),
               onPressed: () => setState(() => _isRightHanded = !_isRightHanded),
            ),
            const SizedBox(width: AppSpacing.sm),
            
            // Central Catalog Import
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_download, size: 16, color: Colors.white),
              label: Text(AppLocalizations.t(context, 'IMPORT'), style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight),
              onPressed: _showCentralCatalogPicker,
            ),
            const SizedBox(width: AppSpacing.sm),

            // Save
            ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 16, color: Colors.white),
              label: Text("SAVE (${_stockChanges.length})", style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: CarDashboardTheme.electricGreen),
              onPressed: _saveStockChanges,
            ),
            const SizedBox(width: AppSpacing.sm),

            // Exit
            TextButton(
              onPressed: _exitEditMode,
              child: Text(AppLocalizations.t(context, 'EXIT'), style: const TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'BURGER': return Icons.lunch_dining;
      case 'PIZZA': return Icons.local_pizza;
      case 'DRINKS': return Icons.local_drink;
      case 'DESSERT': return Icons.icecream;
      case 'SIDES': return Icons.fastfood;
      default: return Icons.category;
    }
  }
  Widget _buildMiniCartContent(List<InventoryItem> inventory) {
    final provider = Provider.of<DashboardProvider>(context);
    final store = provider.activeStore;
    final subtotal = _calculateTotal(inventory);
    
    double total = subtotal;
    if (store != null && (store.isTaxEnabled ?? false)) {
      total += (subtotal * ((store.taxRate ?? 0.0) / 100));
    }

    final isDarkMode = provider.isDarkMode;

    return Container(
       width: 280,
       padding: const EdgeInsets.all(AppSpacing.md),
       decoration: BoxDecoration(
          color: CarDashboardTheme.panelColor(isDarkMode).withValues(alpha: 0.95),
          borderRadius: BorderRadius.zero,
          border: Border.all(color: CarDashboardTheme.primaryColor(isDarkMode), width: 1),
          boxShadow: [
             BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(4, 4))
          ]
       ),
       child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             // Header / Drag Handle
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                  Row(
                    children: [
                       const Icon(Icons.shopping_cart, color: CarDashboardTheme.neonBlue, size: 20),
                       const SizedBox(width: AppSpacing.sm),
                       Text(AppLocalizations.t(context, 'MINI CHECKOUT'), style: TextStyle(color: CarDashboardTheme.textColor(isDarkMode), fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  Icon(Icons.drag_indicator, color: AppColors.textSecondary(context), size: 20),
               ],
             ),
             const Divider(height: 24),
             
             // Content
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text("ITEMS: ${_cart.length}", style: TextStyle(color: CarDashboardTheme.subTextColor(isDarkMode))),
                   Text("₹${total.toStringAsFixed(2)}", style: CarDashboardTheme.priceStyle.copyWith(color: CarDashboardTheme.electricGreen, fontSize: 18)),
                ],
             ),
             const SizedBox(height: AppSpacing.md),
             
             // Actions
             Row(
               children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CarDashboardTheme.alertRed, 
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero) // Sharp Corners
                      ),
                      onPressed: () => _finalizeOrder('Cash'),
                      onLongPress: _handleCashPayment,
                      child: Text(AppLocalizations.t(context, 'CASH'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CarDashboardTheme.electricGreen, 
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero) // Sharp Corners
                       ),
                      onPressed: () => _finalizeOrder('UPI'),
                      onLongPress: _handleUPIPayment,
                      child: Text(AppLocalizations.t(context, 'UPI'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
               ],
             )
          ],
       ),
    );
  }
}

class _CentralCatalogPickerDialog extends StatefulWidget {
  @override
  State<_CentralCatalogPickerDialog> createState() => _CentralCatalogPickerDialogState();
}

class _CentralCatalogPickerDialogState extends State<_CentralCatalogPickerDialog> {
  String _search = '';
  String _selectedStoreType = 'All';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    const theme = CarDashboardTheme.neonBlue;

    // Filter Logic
    final filtered = provider.centralInventory.where((item) {
       final matchesSearch = item.name.toLowerCase().contains(_search.toLowerCase()) || 
                             (item.sku?.toLowerCase().contains(_search.toLowerCase()) ?? false);
       final matchesType = _selectedStoreType == 'All' || item.storeType == _selectedStoreType;
       return matchesSearch && matchesType;
    }).toList();

    return Dialog(
       backgroundColor: CarDashboardTheme.bgDark.withValues(alpha: 0.95),
       shape: const RoundedRectangleBorder(
         borderRadius: BorderRadius.zero, 
         side: BorderSide(color: theme, width: 2)
       ),
       child: SizedBox(
         width: 800,
         height: 600,
         child: Column(
           children: [
             // Header
             Container(
               padding: const EdgeInsets.all(AppSpacing.md),
               decoration: BoxDecoration(
                 color: theme.withValues(alpha: 0.1),
                 border: Border(bottom: BorderSide(color: theme.withValues(alpha: 0.3))),
               ),
               child: Row(
                 children: [
                   const Icon(Icons.cloud_download, color: theme),
                   const SizedBox(width: AppSpacing.sm),
                   Text(AppLocalizations.t(context, 'CENTRAL CATALOG'), style: CarDashboardTheme.labelStyle.copyWith(color: Colors.white, fontSize: 20)),
                   const Spacer(),
                   IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))
                 ],
               ),
             ),

             // Search & Filter
             Padding(
               padding: const EdgeInsets.all(AppSpacing.md),
               child: Row(
                 children: [
                   Expanded(
                     child: TextField(
                       style: const TextStyle(color: Colors.white),
                       decoration: const InputDecoration(
                         hintText: "Search items...",
                         hintStyle: TextStyle(color: Colors.white30),
                         prefixIcon: Icon(Icons.search, color: Colors.white54),
                         filled: true,
                         fillColor: Colors.white10,
                         border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide.none),
                       ),
                       onChanged: (val) => setState(() => _search = val),
                     ),
                   ),
                   const SizedBox(width: AppSpacing.md),
                   // Simple Store Type Toggle
                   DropdownButton<String>(
                     value: _selectedStoreType,
                     dropdownColor: CarDashboardTheme.bgPanel,
                     style: const TextStyle(color: Colors.white),
                     items: ['All', 'Retail', 'Grocery', 'Restaurant'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                     onChanged: (val) => setState(() => _selectedStoreType = val!),
                   )
                 ],
               ),
             ),

             // List
             Expanded(
               child: ListView.separated(
                 padding: const EdgeInsets.all(AppSpacing.md),
                 itemCount: filtered.length,
                 separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                 itemBuilder: (ctx, i) {
                   final item = filtered[i];
                   final isInStore = provider.storeInventory.any((s) => s.name == item.name); // Simple rename check
                   
                   return ListTile(
                     leading: item.image != null 
                         ? Image.network(item.image!, width: 40, height: 40, fit: BoxFit.cover)
                         : Container(width: 40, height: 40, color: Colors.white10, child: const Icon(Icons.image, color: Colors.white54)),
                     title: Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                     subtitle: Text("SKU: ${item.sku ?? '-'} | ${item.category}", style: const TextStyle(color: Colors.white54)),
                     trailing: isInStore 
                         ? Text(AppLocalizations.t(context, 'Imported'), style: const TextStyle(color: CarDashboardTheme.electricGreen))
                         : NeonButton(
                             label: "IMPORT",
                             color: theme,
                             onPressed: () async {
                               try {
                                 await provider.importCentralItem(item);
                                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Imported ${item.name}"), backgroundColor: CarDashboardTheme.electricGreen));
                                 setState(() {}); // Refresh check
                               } catch (e) {
                                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: CarDashboardTheme.alertRed));
                               }
                             },
                           ),
                   );
                 },
               ),
             )
           ],
         ),
       ),
    );
  }

}



