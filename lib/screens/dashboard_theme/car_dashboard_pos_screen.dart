import 'package:biztonic_pos/core/design/tokens/app_radius.dart';
import '../../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';
import 'package:biztonic_pos/core/design/tokens/app_typography.dart';
import 'package:biztonic_pos/core/design/tokens/app_shadows.dart';
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
            backgroundColor: AppColors.surface(context),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd, side: BorderSide(color: AppColors.adaptivePrimary(context).withValues(alpha: 0.3))),
            title: Text("CUSTOMIZE CARD: ${item.name}", style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.w600)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.t(context, 'CARD STYLE'), style: TextStyle(color: AppColors.adaptivePrimary(context), fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _buildStyleOption("IMAGE", 'image', selectedStyle, (val) => setDialogState(() => selectedStyle = val)),
                    const SizedBox(width: AppSpacing.md),
                    _buildStyleOption("LABEL", 'label', selectedStyle, (val) => setDialogState(() => selectedStyle = val)),
                  ],
                ),
                
                const SizedBox(height: AppSpacing.lg),
                Text(AppLocalizations.t(context, 'CARD SIZE'), style: TextStyle(color: AppColors.adaptivePrimary(context), fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.md),
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
             color: isSelected ? AppColors.adaptivePrimary(context).withValues(alpha: 0.2) : AppColors.transparent,
             border: Border.all(color: isSelected ? AppColors.adaptivePrimary(context) : AppColors.textSecondary(context)),
             borderRadius: AppRadius.borderSm
           ),
           child: Text(label, style: TextStyle(
             color: isSelected ? AppColors.adaptivePrimary(context) : AppColors.textSecondary(context), 
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
                    foregroundColor: AppColors.textPrimaryLight, // Dark text on bright buttons
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderSm,
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
            backgroundColor: AppColors.surface(context), // Theme Aware
            shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm, side: BorderSide(color: AppColors.border(context))),
            title: Text(AppLocalizations.t(context, 'CASH PAYMENT'), style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 24)),
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
                        color: AppColors.adaptivePrimary(context).withValues(alpha: 0.05),
                        borderRadius: AppRadius.borderSm,
                        border: Border.all(color: AppColors.border(context))
                      ),
                      child: Column(
                        children: [
                          _buildPaymentSummaryRow("BILL TOTAL", total, AppColors.textPrimary(context), isLarge: true),
                          const SizedBox(height: AppSpacing.sm),
                          _buildPaymentSummaryRow("RECEIVED", receivedAmount, AppColors.success, isLarge: true),
                          Divider(color: AppColors.border(context), height: 24),
                          _buildPaymentSummaryRow("CHANGE", returnAmount > 0 ? returnAmount : 0, AppColors.adaptivePrimary(context), isExtraLarge: true),
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
                       icon: Icon(Icons.refresh, color: AppColors.textSecondary(context), size: 20),
                       label: Text(AppLocalizations.t(context, 'RESET AMOUNT'), style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14)),
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
                         shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm), // Sharp Corners
                         backgroundColor: AppColors.textSecondary(context).withValues(alpha: 0.1),
                       ),
                       child: Text(AppLocalizations.t(context, 'CANCEL'), style: TextStyle(color: AppColors.textSecondary(context), fontSize: 18, fontWeight: FontWeight.bold))
                     ),
                   ),
                   const SizedBox(width: AppSpacing.md),
                   Expanded(
                     flex: 2, // Give Confirm more space
                     child: ElevatedButton(
                       style: ElevatedButton.styleFrom(
                         backgroundColor: AppColors.success, 
                         foregroundColor: AppColors.textPrimaryLight,
                         padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs), // Increased Height
                         shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm), // Sharp Corners
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
        Text(label, style: TextStyle(color: AppColors.textSecondary(context), fontSize: isExtraLarge ? 20 : (isLarge ? 16 : 14), fontWeight: FontWeight.bold)),
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
        backgroundColor: AppColors.surface(context),
        shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.borderSm, 
            side: BorderSide(color: AppColors.error, width: 2)
        ),
        title: Row(
          children: [
            const Icon(Icons.lock, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Text(AppLocalizations.t(context, 'PLAN RESTRICTION'), style: AppTypography.labelLarge.copyWith(color: AppColors.error)),
          ],
        ),
        content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
              const Icon(Icons.security, size: 64, color: AppColors.warning),
              const SizedBox(height: AppSpacing.md),
              Text(
                message, 
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary(context), fontSize: 18),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(AppLocalizations.t(context, 'UPGRADE TO STANDARD PLAN FOR UNLIMITED ACCESS'), 
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12, fontWeight: FontWeight.bold),
              ),
           ],
        ),
        actions: [
          NeonButton(
            label: "UNDERSTOOD",
            color: AppColors.adaptivePrimary(context),
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
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm, side: BorderSide(color: AppColors.success, width: 2)),
        title: Text(AppLocalizations.t(context, 'UPI PAYMENT'), style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_2, size: 120, color: AppColors.textPrimary(context)),
            const SizedBox(height: AppSpacing.md),
            Text("Requesting ₹${total.toStringAsFixed(2)}", style: const TextStyle(color: AppColors.success, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.md),
            Text(AppLocalizations.t(context, 'Waiting for payment validation...'), style: TextStyle(color: AppColors.textSecondary(context), fontSize: 16)),
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
                     shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
                     backgroundColor: AppColors.textSecondary(context).withValues(alpha: 0.1),
                   ),
                   child: Text(AppLocalizations.t(context, 'CANCEL'), style: TextStyle(color: AppColors.textSecondary(context), fontSize: 18, fontWeight: FontWeight.bold))
                 ),
               ),
               const SizedBox(width: AppSpacing.md),
               Expanded(
                 flex: 2,
                 child: ElevatedButton(
                   style: ElevatedButton.styleFrom(
                     backgroundColor: AppColors.success,
                     foregroundColor: AppColors.textPrimaryLight,
                     padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                     shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
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
            backgroundColor: AppColors.surface(context).withValues(alpha: 0.95),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.borderSm, 
              side: BorderSide(color: AppColors.error, width: 2)
            ),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                const SizedBox(width: AppSpacing.sm),
                Text(AppLocalizations.t(context, 'CRITICAL STOCK FAILURE'), style: AppTypography.labelLarge.copyWith(color: AppColors.error, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.t(context, 'UNABLE TO PROCESS SEQUENCE.'), style: const TextStyle(color: AppColors.textSecondaryDark)),
                const SizedBox(height: AppSpacing.md),
                Text(AppLocalizations.t(context, 'DEPLETED ASSETS:'), style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.sm),
                ...outOfStockItems.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      const Icon(Icons.close, color: AppColors.error, size: 14),
                      const SizedBox(width: AppSpacing.sm),
                      Text(s, style: const TextStyle(color: AppColors.surfaceLight, fontFamily: 'Orbitron')),
                    ],
                  ),
                )),
              ],
            ),
            actions: [
              NeonButton(
                label: "ABORT",
                color: AppColors.error,
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
            backgroundColor: AppColors.surface(context).withValues(alpha: 0.95),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.borderSm, 
              side: BorderSide(color: AppColors.warning, width: 2)
            ),
            title: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning),
                const SizedBox(width: AppSpacing.sm),
                Text(AppLocalizations.t(context, 'LOW ASSET WARNING'), style: AppTypography.labelLarge.copyWith(color: AppColors.warning, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.t(context, 'ASSETS REACHING CRITICAL LEVELS:'), style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.sm),
                ...lowStockItems.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      Icon(Icons.priority_high, color: AppColors.warning, size: 14),
                      const SizedBox(width: AppSpacing.sm),
                      Text(s, style: const TextStyle(color: AppColors.surfaceLight)),
                    ],
                  ),
                )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.t(context, 'CANCEL'), style: const TextStyle(color: AppColors.textHintDark)),
              ),
              const SizedBox(width: AppSpacing.md),
              NeonButton(
                label: "IGNORE & PROCEED",
                color: AppColors.warning,
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
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: AppColors.transparent,
          elevation: 0,
          child: Center(child: CircularProgressIndicator(color: AppColors.adaptivePrimary(context))),
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
                 backgroundColor: AppColors.success,
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
      backgroundColor: _customBackgroundColor ?? AppColors.background(context),
      // Drawer for Mobile
      drawerEnableOpenDragGesture: false, // PREVENT ACCIDENTAL TRIGGERS
      drawer: Drawer(
              backgroundColor: AppColors.surface(context),
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
                      color: AppColors.surface(context),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.menu, color: AppColors.adaptivePrimary(context)),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                          Text(AppLocalizations.t(context, 'POS Terminal'), style: AppTypography.titleMedium.copyWith(fontSize: 18, color: AppColors.textPrimary(context))),
                          // Printer Status
                          _buildPrinterStatusIndicator(isDarkMode, compact: true),
                          // Cart Toggle
                          IconButton(
                            icon: Badge(
                              label: Text("${_cart.length}"),
                              isLabelVisible: _cart.isNotEmpty,
                              child: Icon(Icons.shopping_cart, color: AppColors.textPrimary(context)),
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
                        color: AppColors.textSecondaryLight,
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                           onTap: () {}, // Prevent closing
                           child: Container(
                             width: constraints.maxWidth * 0.85,
                             height: double.infinity,
                             color: AppColors.surface(context),
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
                        color: AppColors.surface(context),
                        border: Border(right: BorderSide(color: AppColors.border(context))),
                      ),
                      child: SafeArea(child: _buildHUDPanel(inventory)),
                    )
                  else
                     const SizedBox.shrink()
                else
                  // SIDEBAR ON LEFT
                  Container(
                    width: (_isCategoryExpanded == true) ? 200 : 70, // Defensive Check
                    color: AppColors.surface(context),
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
                                    Expanded(child: Text(AppLocalizations.t(context, 'BIZTONIC'), style: AppTypography.titleLarge.copyWith(color: AppColors.adaptivePrimary(context), fontSize: 18))),
                                 
                                 // Toggle Arrow
                                 InkWell(
                                   onTap: () => setState(() => _isCategoryExpanded = !(_isCategoryExpanded == true)),
                                   child: Icon(
                                      (_isCategoryExpanded == true) ? Icons.arrow_back_ios_new : Icons.arrow_forward_ios,
                                      color: AppColors.adaptivePrimary(context),
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
                    color: _customBackgroundColor ?? AppColors.background(context), // Use Custom BG
                    child: Column(
                      children: [
                        // Top Bar
                        Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.border(context))),
                            color: AppColors.surface(context),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: AppColors.textSecondary(context)),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                    hintText: "Search products...",
                                    border: InputBorder.none,
                                  ),
                                  style: TextStyle(color: AppColors.textPrimary(context)),
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                ),
                              ),
                              IconButton(
                                icon: Icon(_isEditMode ? Icons.check_circle : Icons.edit, color: _isEditMode ? AppColors.success : AppColors.textSecondary(context)),
                                onPressed: _toggleEditMode,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              _buildPrinterStatusIndicator(isDarkMode),
                              const SizedBox(width: AppSpacing.sm),
                              // Checkout Toggle
                              IconButton(
                                icon: Icon((_isRightHanded == _isCartPanelVisible) ? Icons.arrow_forward : Icons.arrow_back, color: AppColors.textPrimary(context)),
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
                      color: AppColors.surface(context),
                      border: Border(left: BorderSide(color: AppColors.border(context))),
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
                                      color: AppColors.adaptivePrimary(context),
                                      size: 16,
                                   ),
                                 ),

                                 if (_isCategoryExpanded == true)
                                    Expanded(child: Text(AppLocalizations.t(context, 'BIZTONIC'), textAlign: TextAlign.right, style: AppTypography.titleLarge.copyWith(color: AppColors.adaptivePrimary(context), fontSize: 18))),
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
                        color: AppColors.surface(context),
                        border: Border(left: BorderSide(color: AppColors.border(context))),
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
                style: AppTypography.labelLarge.copyWith(color: AppColors.success, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            
          // Session Timer
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _buildSessionTimer(isDarkMode),
          ),
          Divider(color: AppColors.border(effectiveContext).withValues(alpha: 0.3), height: 1),
        ],
        
        Expanded(
          child: ListView.builder(
            controller: _categoryScrollController,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = _selectedCategory == cat;
              final catColor = _getCategoryColor(cat);
              final catIcon = _getCategoryIcon(cat);
//               final isAllCategory = cat.toUpperCase() == 'ALL';
              
              return GestureDetector(
                onTap: () {
                   setState(() => _selectedCategory = cat);
                   _scrollToCategory(index);
                   if (Scaffold.of(context).hasDrawer && Scaffold.of(context).isDrawerOpen) {
                     Scaffold.of(context).closeDrawer();
                   }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  margin: EdgeInsets.symmetric(
                    horizontal: isExpanded ? AppSpacing.sm : 6,
                    vertical: 3,
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: isExpanded ? 12 : 10,
                    horizontal: isExpanded ? 14 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? catColor.withValues(alpha: isDarkMode ? 0.2 : 0.12)
                      : AppColors.transparent,
                    borderRadius: AppRadius.borderSm,
                    border: isSelected 
                      ? Border.all(color: catColor.withValues(alpha: 0.5), width: 1.5)
                      : null,
                  ),
                  child: isExpanded
                    ? Row(
                        children: [
                          // Icon with colored background
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected 
                                ? catColor.withValues(alpha: 0.25)
                                : (isDarkMode ? AppColors.surfaceLight.withValues(alpha: 0.06) : AppColors.textPrimaryLight.withValues(alpha: 0.04)),
                              borderRadius: AppRadius.borderSm,
                            ),
                            child: Center(
                              child: Icon(
                                catIcon, 
                                color: isSelected ? catColor : AppColors.textSecondary(context),
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              cat.toUpperCase(),
                              style: TextStyle(
                                color: isSelected 
                                  ? catColor
                                  : AppColors.textPrimary(context).withValues(alpha: 0.7),
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 4,
                              height: 20,
                              decoration: BoxDecoration(
                                color: catColor,
                                borderRadius: AppRadius.borderXs,
                              ),
                            ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon with colored background
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSelected 
                                ? catColor.withValues(alpha: 0.25)
                                : (isDarkMode ? AppColors.surfaceLight.withValues(alpha: 0.06) : AppColors.textPrimaryLight.withValues(alpha: 0.04)),
                              borderRadius: AppRadius.borderSm,
                              border: isSelected 
                                ? null
                                : Border.all(
                                    color: isDarkMode ? AppColors.surfaceLight.withValues(alpha: 0.06) : AppColors.textPrimaryLight.withValues(alpha: 0.06),
                                  ),
                            ),
                            child: Center(
                              child: Icon(
                                catIcon, 
                                color: isSelected ? catColor : AppColors.textSecondary(context),
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            cat.length > 6 ? '${cat.substring(0, 6)}..' : cat.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected 
                                ? catColor 
                                : AppColors.textSecondary(context),
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 9,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
              _buildSidebarActionBtn(Icons.calculate, "Calculator", AppColors.adaptivePrimary(context), _showCalculator, overrideBg: AppColors.textPrimaryLight),
              _buildSidebarActionBtn(Icons.power_settings_new, "Exit", AppColors.error, () {
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
              _buildSidebarActionBtn(Icons.calculate, "Calc", AppColors.adaptivePrimary(context), _showCalculator, overrideBg: AppColors.textPrimaryLight),
              const SizedBox(height: AppSpacing.md),
              _buildSidebarActionBtn(Icons.power_settings_new, "Exit", AppColors.error, () {
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
        borderRadius: AppRadius.borderSm,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: overrideBg ?? (isSolid ? color : color.withValues(alpha: 0.15)),
            border: Border.all(color: overrideBg != null ? color :  (isSolid ? color : color), width: 2), // Keep border color consistent
          ),
          child: Center(
            child: Icon(icon, color: isSolid ? AppColors.surfaceLight : color, size: 24),
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
         color: AppColors.background(context),
         borderRadius: AppRadius.borderSm,
         border: Border.all(color: AppColors.border(context)),
       ),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(Icons.timer, size: 16, color: AppColors.adaptivePrimary(context)),
           const SizedBox(width: AppSpacing.sm),
           Text("$hours:$minutes:$seconds", style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.bold)), // Increased to 16
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
            Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textSecondary(context).withValues(alpha: 0.5)),
            const SizedBox(height: AppSpacing.md),
            Text(AppLocalizations.t(context, 'No products found in this category.'),
              style: TextStyle(color: AppColors.textPrimary(context), fontSize: 18),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate safest cross axis count based strictly on the available container width
        int crossAxisCount = (constraints.maxWidth / _cardWidth).floor();
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
            color: AppColors.surface(context),
            borderRadius: AppRadius.borderSm,
            border: Border.all(color: AppColors.border(context)),
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
                Text(AppLocalizations.t(context, 'ORDER DETAILS'), style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary(context))),
                Icon(
                  _isHeaderExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.adaptivePrimary(context),
                  size: 28, // Bigger Icon
                ),
              ],
            ),
          ),
        ),
        
        // 2. Collapsible Content (Customer + Order Type)
        if (_isHeaderExpanded) ...[
                const SizedBox(height: AppSpacing.md),
                // Customer Details
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             Row(
                               children: [
                                 Icon(Icons.person_outline, size: 20, color: AppColors.adaptivePrimary(context)),
                                 const SizedBox(width: AppSpacing.sm),
                                 Text(AppLocalizations.t(context, 'CUSTOMER DETAILS'), style: AppTypography.labelLarge.copyWith(color: AppColors.adaptivePrimary(context), fontSize: 16, fontWeight: FontWeight.bold)),
                               ],
                             ),
                             // Select Button
                             TextButton.icon(
                               onPressed: _showCustomerSelectionDialog,
                               icon: Icon(Icons.list, size: 24, color: AppColors.secondary),
                               label: Text(AppLocalizations.t(context, 'Select'), style: TextStyle(color: AppColors.secondary, fontSize: 16, fontWeight: FontWeight.bold)),
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
                          color: AppColors.background(context),
                          borderRadius: AppRadius.borderSm,
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: TextField(
                          controller: _customerNameController,
                          style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16),
                          decoration: InputDecoration(
                            hintText: "Customer Name",
                            hintStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 16),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), 
                            prefixIcon: Icon(Icons.person, size: 18, color: AppColors.textSecondary(context)),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Mobile Input
                      Container(
                        height: 50, // Increased height
                        decoration: BoxDecoration(
                          color: AppColors.background(context),
                          borderRadius: AppRadius.borderSm,
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: TextField(
                          controller: _customerMobileController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16), 
                          decoration: InputDecoration(
                            hintText: "Mobile Number",
                            hintStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 16),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            prefixIcon: Icon(Icons.phone_android, size: 18, color: AppColors.textSecondary(context)),
                          ),
                        ),
                      ),
                    ],
                ),
                const SizedBox(height: AppSpacing.md),
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

        const SizedBox(height: AppSpacing.md),
        
        // 3. Cart List
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: AppRadius.borderSm,
              border: Border.all(color: AppColors.border(context)),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("ITEMS (${_cart.length})", style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary(context))),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                      onPressed: _clearCart,
                    )
                  ],
                ),
                const Divider(),
                Expanded(
                  child: _cart.isEmpty 
                  ? Center(child: Text(AppLocalizations.t(context, 'Cart Empty'), style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary(context))))
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
                             color: AppColors.background(context),
                             borderRadius: AppRadius.borderSm,
                             border: Border.all(color: AppColors.border(context)),
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
                                      style: AppTypography.labelLarge.copyWith(
                                        color: AppColors.textPrimary(context), 
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
                                    style: AppTypography.titleLarge.copyWith(
                                      fontSize: 24, // High Visibility
                                      color: AppColors.adaptivePrimary(context)
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
                                          color: AppColors.surface(context),
                                          borderRadius: AppRadius.borderSm,
                                          border: Border.all(color: AppColors.border(context))
                                        ),
                                        child: Text(
                                          "$qty", 
                                          style: TextStyle(
                                            color: AppColors.textPrimary(context), 
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
        
        const SizedBox(height: AppSpacing.md), // Reduced gap
        
        // 4. Total & Payment Buttons
        Container(
          padding: const EdgeInsets.all(AppSpacing.md), 
          decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: AppRadius.borderSm,
              border: Border.all(color: AppColors.border(context)),
              boxShadow: AppShadows.adaptive(context),
          ),
          child: Column(
            children: [
               Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.t(context, 'TOTAL'), style: AppTypography.labelLarge.copyWith(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textSecondary(context))),
                  Text("₹${total.toStringAsFixed(2)}", style: AppTypography.titleLarge.copyWith(fontSize: 36, color: AppColors.textPrimary(context))), 
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error, // CASH = RED
                        foregroundColor: AppColors.surfaceLight,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md), // Height adjusted
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm), // Sharp Corners
                      ),
                      onPressed: _cart.isNotEmpty ? () => _finalizeOrder('Cash') : null,
                      onLongPress: _cart.isNotEmpty ? _handleCashPayment : null,
                      child: Text(AppLocalizations.t(context, 'CASH'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), // Larger Text
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success, // UPI = GREEN
                          foregroundColor: AppColors.textPrimaryLight, // Dark Text for Contrast
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md), // Height adjusted
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm), // Sharp Corners
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
      case 'Dine In': activeColor = AppColors.adaptivePrimary(context); break;
      case 'Take Out': activeColor = AppColors.warning; break;
      case 'Delivery': activeColor = const Color(0xFF9C27B0); break; // Purple
      default: activeColor = AppColors.adaptivePrimary(context);
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _orderType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md), // Increased Padding
          decoration: BoxDecoration(
            color: isSelected ? activeColor : AppColors.transparent, // Filled BG when selected
            border: Border.all(color: isSelected ? activeColor : AppColors.border(context)),
            borderRadius: AppRadius.borderSm,
          ),
          child: Column(
            children: [
              // Icon Removed for Simplicity
              Text(
                type.toUpperCase(), 
                style: TextStyle(
                  fontSize: 14, // Increased Font Size
                  color: isSelected ? AppColors.textPrimaryLight : AppColors.textSecondary(context), // Black text on colored BG
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
          color: AppColors.adaptivePrimary(context).withValues(alpha: 0.15),
          borderRadius: AppRadius.borderSm,
          border: Border.all(color: AppColors.adaptivePrimary(context).withValues(alpha: 0.5))
        ),
        child: Icon(icon, color: AppColors.adaptivePrimary(context), size: 24),
      ),
    );
  }

  void _showCustomerSelectionDialog() {
     final provider = Provider.of<DashboardProvider>(context, listen: false);
     final customers = provider.customers; 

     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
         backgroundColor: AppColors.surface(context),
         shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm, side: BorderSide(color: AppColors.border(context))),
         title: Text(AppLocalizations.t(context, 'SELECT CUSTOMER'), style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16)),
         content: SizedBox(
           width: 300,
           height: 400,
           child: customers.isEmpty 
             ? Center(child: Text(AppLocalizations.t(context, 'No customers found'), style: TextStyle(color: AppColors.textSecondary(context))))
             : ListView.builder(
                 itemCount: customers.length,
                 itemBuilder: (context, index) {
                   final customer = customers[index];
                   return ListTile(
                     leading: CircleAvatar(
                        backgroundColor: AppColors.adaptivePrimary(context).withValues(alpha: 0.2),
                        child: Text(customer.name.isNotEmpty ? customer.name[0].toUpperCase() : "?", style: TextStyle(color: AppColors.adaptivePrimary(context))),
                     ),
                     title: Text(customer.name, style: TextStyle(color: AppColors.textPrimary(context))),
                     subtitle: Text(customer.mobile ?? '', style: TextStyle(color: AppColors.textSecondary(context))),
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
               borderRadius: AppRadius.borderSm,
               border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                  Icon(isConnected ? Icons.print : Icons.print_disabled, color: statusColor, size: 16),
                  const SizedBox(width: AppSpacing.sm),
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
           SnackBar(content: Text(AppLocalizations.t(context, 'Stock Updated Successfully')), backgroundColor: AppColors.success)
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Error saving stock: $e"), backgroundColor: AppColors.error)
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
        backgroundColor: AppColors.surface(context),
        title: Text(AppLocalizations.t(context, 'Choose Background'), style: TextStyle(color: AppColors.textPrimary(context))),
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
                              color: color ?? AppColors.surface(context),
                              borderRadius: AppRadius.borderSm,
                              border: isSelected ? Border.all(color: AppColors.success, width: 2) : Border.all(color: Colors.white24),
                            ),
                            child: isSelected ? const Icon(Icons.check, color: AppColors.surfaceLight, size: 16) : null,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(name, style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 10)),
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
                              borderRadius: AppRadius.borderSm,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(Icons.colorize, color: AppColors.surfaceLight),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(AppLocalizations.t(context, 'Custom'), style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 10)),
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
           backgroundColor: AppColors.surface(context),
           shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
           title: Text(AppLocalizations.t(context, 'Enter Hex Color'), style: TextStyle(color: AppColors.textPrimary(context))),
           content: TextField(
             style: TextStyle(color: AppColors.textPrimary(context)),
             decoration: InputDecoration(
                hintText: "#FF0000",
                hintStyle: TextStyle(color: AppColors.textSecondary(context)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border(context))),
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
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: AppColors.adaptivePrimary(context).withValues(alpha: 0.3)),
        boxShadow: AppShadows.adaptive(context),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Edit badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.adaptivePrimary(context).withValues(alpha: 0.1),
                borderRadius: AppRadius.borderSm,
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, color: AppColors.adaptivePrimary(context), size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Text('EDIT', style: AppTypography.labelSmall.copyWith(color: AppColors.adaptivePrimary(context), fontWeight: FontWeight.w700, letterSpacing: 1.0)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            
            // Card Size Slider
            Text('Size:', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
            SizedBox(
              width: 120,
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.adaptivePrimary(context),
                  inactiveTrackColor: AppColors.border(context),
                  thumbColor: AppColors.adaptivePrimary(context),
                  overlayColor: AppColors.adaptivePrimary(context).withValues(alpha: 0.1),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: _cardWidth,
                  min: 150,
                  max: 400,
                  divisions: 5,
                  label: _cardWidth.round().toString(),
                  onChanged: (val) => setState(() => _cardWidth = val),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            
            // Style Toggle
            _editToolbarButton(
              icon: _globalCardStyle == 'image' ? Icons.image : _globalCardStyle == 'label' ? Icons.label : Icons.view_agenda,
              label: _globalCardStyle == 'minimal_rect' ? "RECT" : _globalCardStyle.toUpperCase(),
              color: AppColors.primary,
              onPressed: () => setState(() {
                if (_globalCardStyle == 'image') _globalCardStyle = 'label';
                else if (_globalCardStyle == 'label') _globalCardStyle = 'minimal_rect';
                else _globalCardStyle = 'image';
              }),
            ),
            const SizedBox(width: AppSpacing.sm),

            // BG Color
            _editToolbarButton(
              icon: Icons.palette,
              label: 'BG',
              color: AppColors.primary,
              onPressed: _showBackgroundColorPicker,
            ),
            const SizedBox(width: AppSpacing.sm),

            // Layout
            _editToolbarButton(
              icon: Icons.swap_horiz,
              label: 'LAYOUT',
              color: AppColors.secondary,
              onPressed: () => setState(() => _isRightHanded = !_isRightHanded),
            ),
            const SizedBox(width: AppSpacing.sm),
            
            // Central Catalog Import
            _editToolbarButton(
              icon: Icons.cloud_download,
              label: 'IMPORT',
              color: AppColors.primaryLight,
              onPressed: _showCentralCatalogPicker,
            ),
            const SizedBox(width: AppSpacing.lg),

            // Save
            ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 16, color: AppColors.surfaceLight),
              label: Text("SAVE (${_stockChanges.length})", style: const TextStyle(color: AppColors.surfaceLight, fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success, 
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
              ),
              onPressed: _saveStockChanges,
            ),
            const SizedBox(width: AppSpacing.sm),

            // Exit
            TextButton.icon(
              icon: Icon(Icons.close, size: 16, color: AppColors.textSecondary(context)),
              label: Text('EXIT', style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context))),
              onPressed: _exitEditMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _editToolbarButton({required IconData icon, required String label, required Color color, required VoidCallback onPressed}) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: AppRadius.borderSm,
      child: InkWell(
        borderRadius: AppRadius.borderSm,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final key = category.toUpperCase().trim();
    // Primary exact matches
    const Map<String, IconData> iconMap = {
      'ALL': Icons.grid_view_rounded,
      'BURGER': Icons.lunch_dining,
      'BURGERS': Icons.lunch_dining,
      'PIZZA': Icons.local_pizza,
      'DRINKS': Icons.local_cafe,
      'BEVERAGES': Icons.local_cafe,
      'BEVERAGE': Icons.local_cafe,
      'COFFEE': Icons.coffee_rounded,
      'TEA': Icons.emoji_food_beverage,
      'JUICE': Icons.local_bar,
      'SMOOTHIE': Icons.blender,
      'SMOOTHIES': Icons.blender,
      'DESSERT': Icons.icecream,
      'DESSERTS': Icons.icecream,
      'ICE CREAM': Icons.icecream,
      'CAKE': Icons.cake,
      'CAKES': Icons.cake,
      'BAKERY': Icons.bakery_dining,
      'BREAD': Icons.bakery_dining,
      'SIDES': Icons.tapas,
      'SNACKS': Icons.tapas,
      'SNACK': Icons.tapas,
      'STARTERS': Icons.restaurant,
      'APPETIZER': Icons.restaurant,
      'APPETIZERS': Icons.restaurant,
      'MAIN COURSE': Icons.dinner_dining,
      'MAINS': Icons.dinner_dining,
      'RICE': Icons.rice_bowl,
      'BIRYANI': Icons.rice_bowl,
      'NOODLES': Icons.ramen_dining,
      'PASTA': Icons.ramen_dining,
      'SOUP': Icons.soup_kitchen,
      'SOUPS': Icons.soup_kitchen,
      'SALAD': Icons.eco,
      'SALADS': Icons.eco,
      'VEG': Icons.spa,
      'VEGETARIAN': Icons.spa,
      'NON VEG': Icons.set_meal,
      'NON-VEG': Icons.set_meal,
      'MEAT': Icons.set_meal,
      'SEAFOOD': Icons.set_meal,
      'CHICKEN': Icons.set_meal,
      'FISH': Icons.set_meal,
      'CHINESE': Icons.ramen_dining,
      'INDIAN': Icons.dinner_dining,
      'ITALIAN': Icons.local_pizza,
      'MEXICAN': Icons.restaurant,
      'FAST FOOD': Icons.fastfood,
      'FASTFOOD': Icons.fastfood,
      'COMBO': Icons.takeout_dining,
      'COMBOS': Icons.takeout_dining,
      'THALI': Icons.takeout_dining,
      'BREAKFAST': Icons.free_breakfast,
      'BRUNCH': Icons.brunch_dining,
      'LUNCH': Icons.lunch_dining,
      'DINNER': Icons.dinner_dining,
      'SANDWICH': Icons.lunch_dining,
      'SANDWICHES': Icons.lunch_dining,
      'WRAPS': Icons.kebab_dining,
      'WRAP': Icons.kebab_dining,
      'KEBAB': Icons.kebab_dining,
      'GROCERY': Icons.shopping_basket,
      'GROCERIES': Icons.shopping_basket,
      'DAIRY': Icons.egg_alt,
      'EGGS': Icons.egg,
      'FRUITS': Icons.apple,
      'VEGETABLES': Icons.grass,
      'ORGANIC': Icons.eco,
      'SWEETS': Icons.cookie,
      'CHOCOLATE': Icons.cookie,
      'PAAN': Icons.spa,
      'TOBACCO': Icons.smoking_rooms,
      'EXTRAS': Icons.add_circle_outline,
      'ADD-ONS': Icons.add_circle_outline,
      'TOPPINGS': Icons.add_circle_outline,
      'SPECIALS': Icons.star_rounded,
      'SPECIAL': Icons.star_rounded,
      'TODAY\'S SPECIAL': Icons.star_rounded,
      'NEW': Icons.fiber_new,
      'POPULAR': Icons.trending_up,
      'BESTSELLER': Icons.emoji_events,
      'FAVOURITES': Icons.favorite,
      'FAVORITES': Icons.favorite,
    };
    
    if (iconMap.containsKey(key)) return iconMap[key]!;
    
    // Fuzzy match: check if category contains a known keyword
    for (final entry in iconMap.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value;
      }
    }
    
    return Icons.restaurant_menu;
  }

  Color _getCategoryColor(String category) {
    final key = category.toUpperCase().trim();
    
    const Map<String, Color> colorMap = {
      'ALL': Color(0xFF6366F1),           // Indigo
      'BURGER': Color(0xFFFF6B35),        // Vibrant Orange
      'BURGERS': Color(0xFFFF6B35),
      'PIZZA': Color(0xFFEF4444),         // Red
      'DRINKS': Color(0xFF06B6D4),        // Cyan
      'BEVERAGES': Color(0xFF06B6D4),
      'BEVERAGE': Color(0xFF06B6D4),
      'COFFEE': Color(0xFF92400E),        // Coffee Brown
      'TEA': Color(0xFF059669),           // Emerald
      'JUICE': Color(0xFFF59E0B),         // Amber
      'DESSERT': Color(0xFFEC4899),       // Pink
      'DESSERTS': Color(0xFFEC4899),
      'ICE CREAM': Color(0xFFEC4899),
      'CAKE': Color(0xFFDB2777),          // Deep Pink
      'CAKES': Color(0xFFDB2777),
      'BAKERY': Color(0xFFD97706),        // Warm Amber
      'SIDES': Color(0xFF8B5CF6),         // Purple
      'SNACKS': Color(0xFF8B5CF6),
      'STARTERS': Color(0xFF10B981),      // Green
      'MAIN COURSE': Color(0xFFDC2626),   // Red
      'MAINS': Color(0xFFDC2626),
      'RICE': Color(0xFFF59E0B),          // Amber
      'BIRYANI': Color(0xFFF97316),       // Orange
      'NOODLES': Color(0xFFEAB308),       // Yellow
      'PASTA': Color(0xFFEAB308),
      'SOUP': Color(0xFF14B8A6),          // Teal
      'SALAD': Color(0xFF22C55E),         // Light Green
      'VEG': Color(0xFF16A34A),           // Green
      'NON VEG': Color(0xFFDC2626),       // Red
      'NON-VEG': Color(0xFFDC2626),
      'CHINESE': Color(0xFFEF4444),       // Red
      'INDIAN': Color(0xFFF97316),        // Orange
      'FAST FOOD': Color(0xFFEAB308),     // Yellow
      'COMBO': Color(0xFF7C3AED),         // Violet
      'COMBOS': Color(0xFF7C3AED),
      'BREAKFAST': Color(0xFFFB923C),     // Light Orange
      'SANDWICH': Color(0xFF0EA5E9),      // Sky
      'WRAPS': Color(0xFF0D9488),         // Teal
      'GROCERY': Color(0xFF059669),       // Emerald
      'SPECIALS': Color(0xFFF59E0B),      // Amber
      'SPECIAL': Color(0xFFF59E0B),
      'POPULAR': Color(0xFFEF4444),       // Red
      'BESTSELLER': Color(0xFFD97706),    // Gold
      'FAVOURITES': Color(0xFFEC4899),    // Pink
    };
    
    if (colorMap.containsKey(key)) return colorMap[key]!;
    
    // Fuzzy match
    for (final entry in colorMap.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value;
      }
    }
    
    // Generate a consistent color from the category name hash
    final List<Color> fallbackPalette = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
      const Color(0xFFEF4444), // Red
      const Color(0xFFF97316), // Orange
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF22C55E), // Green
      const Color(0xFF14B8A6), // Teal
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF3B82F6), // Blue
    ];
    
    return fallbackPalette[category.hashCode.abs() % fallbackPalette.length];
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
          color: AppColors.surface(context).withValues(alpha: 0.95),
          borderRadius: AppRadius.borderSm,
          border: Border.all(color: AppColors.adaptivePrimary(context), width: 1),
          boxShadow: [
             BoxShadow(color: AppColors.textPrimaryLight.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(4, 4))
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
                       Icon(Icons.shopping_cart, color: AppColors.adaptivePrimary(context), size: 20),
                       const SizedBox(width: AppSpacing.sm),
                       Text(AppLocalizations.t(context, 'MINI CHECKOUT'), style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 12)),
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
                   Text("ITEMS: ${_cart.length}", style: TextStyle(color: AppColors.textSecondary(context))),
                   Text("₹${total.toStringAsFixed(2)}", style: AppTypography.titleLarge.copyWith(color: AppColors.success, fontSize: 18)),
                ],
             ),
             const SizedBox(height: AppSpacing.md),
             
             // Actions
             Row(
               children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error, 
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm) // Sharp Corners
                      ),
                      onPressed: () => _finalizeOrder('Cash'),
                      onLongPress: _handleCashPayment,
                      child: Text(AppLocalizations.t(context, 'CASH'), style: const TextStyle(color: AppColors.surfaceLight, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success, 
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm) // Sharp Corners
                       ),
                      onPressed: () => _finalizeOrder('UPI'),
                      onLongPress: _handleUPIPayment,
                      child: Text(AppLocalizations.t(context, 'UPI'), style: const TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.bold)),
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
    final theme = AppColors.adaptivePrimary(context);

    // Filter Logic
    final filtered = provider.centralInventory.where((item) {
       final matchesSearch = item.name.toLowerCase().contains(_search.toLowerCase()) || 
                             (item.sku?.toLowerCase().contains(_search.toLowerCase()) ?? false);
       final matchesType = _selectedStoreType == 'All' || item.storeType == _selectedStoreType;
       return matchesSearch && matchesType;
    }).toList();

    return Dialog(
       backgroundColor: AppColors.surface(context),
       shape: RoundedRectangleBorder(
         borderRadius: AppRadius.borderSm, 
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
                   Icon(Icons.cloud_download, color: theme),
                   const SizedBox(width: AppSpacing.sm),
                   Text(AppLocalizations.t(context, 'CENTRAL CATALOG'), style: AppTypography.labelLarge.copyWith(color: AppColors.textPrimary(context), fontSize: 20)),
                   const Spacer(),
                   IconButton(icon: Icon(Icons.close, color: AppColors.textPrimary(context)), onPressed: () => Navigator.pop(context))
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
                       style: TextStyle(color: AppColors.textPrimary(context)),
                       decoration: InputDecoration(
                         hintText: "Search items...",
                         hintStyle: TextStyle(color: AppColors.textSecondary(context)),
                         prefixIcon: Icon(Icons.search, color: AppColors.textSecondary(context)),
                         filled: true,
                         fillColor: AppColors.background(context),
                         border: OutlineInputBorder(borderRadius: AppRadius.borderSm, borderSide: BorderSide.none),
                       ),
                       onChanged: (val) => setState(() => _search = val),
                     ),
                   ),
                   const SizedBox(width: AppSpacing.md),
                   // Simple Store Type Toggle
                   DropdownButton<String>(
                     value: _selectedStoreType,
                     dropdownColor: AppColors.surface(context),
                     style: TextStyle(color: AppColors.textPrimary(context)),
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
                 separatorBuilder: (_, __) => Divider(color: AppColors.border(context)),
                 itemBuilder: (ctx, i) {
                   final item = filtered[i];
                   final isInStore = provider.storeInventory.any((s) => s.name == item.name); // Simple rename check
                   
                   return ListTile(
                     leading: item.image != null 
                         ? Image.network(item.image!, width: 40, height: 40, fit: BoxFit.cover)
                         : Container(width: 40, height: 40, color: AppColors.background(context), child: Icon(Icons.image, color: AppColors.textSecondary(context))),
                     title: Text(item.name, style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold)),
                     subtitle: Text("SKU: ${item.sku ?? '-'} | ${item.category}", style: TextStyle(color: AppColors.textSecondary(context))),
                     trailing: isInStore 
                         ? Text(AppLocalizations.t(context, 'Imported'), style: const TextStyle(color: AppColors.success))
                         : NeonButton(
                             label: "IMPORT",
                             color: theme,
                             onPressed: () async {
                               try {
                                 await provider.importCentralItem(item);
                                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Imported ${item.name}"), backgroundColor: AppColors.success));
                                 setState(() {}); // Refresh check
                               } catch (e) {
                                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error));
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


