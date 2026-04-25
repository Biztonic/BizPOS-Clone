// ignore_for_file: deprecated_member_use_from_same_package, use_build_context_synchronously
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/table_provider.dart';
import '../models/inventory_item.dart';
import '../models/order_model.dart';
import '../services/scanner_service.dart';
import '../utils/responsive.dart';
import 'dashboard_theme/car_dashboard_pos_screen.dart';
import '../widgets/demo_target.dart'; // Import DemoTarget
import '../models/table_model.dart'; // NEW
// NEW
import '../services/printer_manager_service.dart';
import '../utils/theme.dart';
import '../widgets/inventory_image_widget.dart';

class POSScreen extends StatefulWidget {
  final TableModel? preSelectedTable; // NEW
  const POSScreen({super.key, this.preSelectedTable});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final ScannerService _scannerService = ScannerService();

  // final ScaleService _scaleService = ScaleService();
  // Cart is now in DashboardProvider
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String _currentWeight = "0.000";
  // POS Order State
  String _orderType = 'Takeaway'; // Default
  TableModel? _selectedTable;

  @override
  void initState() {
    super.initState();
    
    // Check for printer setup on enter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPrinterSetupPopup();
    });

    // Initialize with pre-selected table if available
    if (widget.preSelectedTable != null) {
       _orderType = 'Dine-In';
       _selectedTable = widget.preSelectedTable;
    }
    _scannerService.init();
    _scannerService.scanStream.listen((barcode) {
      _handleBarcodeScan(barcode);
    });
    // _initScale();
  }

  @override
  void dispose() {
    _scannerService.dispose();
    // _scaleService.disconnect();
    super.dispose();
  }

  void _checkPrinterSetupPopup() {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    if (provider.needsPrinterSetup) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.print, color: Colors.blue),
              SizedBox(width: 10),
              Text("Connect Printer"),
            ],
          ),
          content: const Text(
            "Welcome! To start printing receipts, please connect your Bluetooth or USB printer in the settings.\n\nWould you like to do this now?"),
          actions: [
            TextButton(
              onPressed: () {
                provider.dismissPrinterSetup();
                Navigator.pop(ctx);
              },
              child: const Text("Later"),
            ),
            ElevatedButton(
              onPressed: () {
                provider.dismissPrinterSetup();
                Navigator.pop(ctx);
                // Navigate to Printer Management
                Navigator.pushNamed(context, '/printer-management');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              child: const Text("Connect Now"),
            ),
          ],
        ),
      );
    }
  }

  void _handleBarcodeScan(String barcode) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final inventory = provider.storeInventory;
    
    try {
      final item = inventory.firstWhere(
        (i) => i.id == barcode || i.name.toLowerCase() == barcode.toLowerCase(),
      );
      provider.addToCart(item); // Use provider
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added ${item.name}"), duration: const Duration(milliseconds: 500)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Item not found: $barcode"), backgroundColor: Colors.red));
    }
  }

  // Removed local cart methods as we now use DashboardProvider

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context); // UPDATED
    final uiStyle = context.select<DashboardProvider, UIStyle>((p) => p.uiStyle);

    // AUTOMOTIVE THEME OVERRIDE
    if (uiStyle == UIStyle.car_dashboard) {
      // Lazy load the car dashboard POS to keep this file clean(er)
      // Note: We need to import it. I'll add the import via another edit or assume it's there.
      // Wait, I should add the import first or at same time.
      return const CarDashboardPOSScreen();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          // LEFT SIDE: Products
          Expanded(
            flex: 7,
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: Selector<DashboardProvider, List<InventoryItem>>(
                    selector: (_, p) => p.storeInventory,
                    builder: (context, inventory, _) {
                      final categories = ['All', ...inventory.map((e) => e.category.trim().isEmpty ? 'Uncategorized' : e.category.trim()).toSet()];
                      final filteredProducts = inventory.where((item) {
                        final itemCategory = item.category.trim().isEmpty ? 'Uncategorized' : item.category.trim();
                        final matchesCategory = _selectedCategory == 'All' || itemCategory == _selectedCategory;
                        final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
                        return matchesCategory && matchesSearch;
                      }).toList();

                      return Column(
                        children: [
                          _buildCategoryTabs(categories),
                          Expanded(
                            child: _buildProductGrid(filteredProducts),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // RIGHT SIDE: Cart (Desktop/Tablet only)
          if (!isMobile)
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(-4, 0),
                    ),
                  ],
                ),
                child: Selector<DashboardProvider, _PosCartData>(
                  selector: (_, p) => _PosCartData(
                    cartItemCount: p.cart.length,
                    cartTotalQuantity: p.cart.values.fold(0, (a, b) => a + (b as int? ?? 0)),
                    activeStoreId: p.activeStore?.id ?? '',
                    inventoryLength: p.storeInventory.length,
                  ),
                  builder: (context, data, _) {
                    final provider = Provider.of<DashboardProvider>(context, listen: false);
                    return _buildCartSection(provider);
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: isMobile
          ? Selector<DashboardProvider, _PosCartData>(
              selector: (_, p) => _PosCartData(
                cartItemCount: p.cart.length,
                cartTotalQuantity: p.cart.values.fold(0, (a, b) => a + (b as int? ?? 0)),
                activeStoreId: p.activeStore?.id ?? '',
                inventoryLength: p.storeInventory.length,
              ),
              builder: (context, data, _) {
                final provider = Provider.of<DashboardProvider>(context, listen: false);
                return FloatingActionButton.extended(
                  onPressed: () => _showMobileCart(context, provider),
                  icon: const Icon(Icons.shopping_cart),
                  label: Text("${data.cartTotalQuantity} Items"),
                  backgroundColor: Theme.of(context).primaryColor,
                );
              },
            )
          : null,
    );
  }

  Widget _buildHeader(BuildContext context) {
    final storeType = context.select<DashboardProvider, String?>((p) => p.activeStore?.storeType);
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('pos_search_field'),
              decoration: InputDecoration(
                hintText: "Search for burgers, fries...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 8),

          const SizedBox(width: 16),
          // Scale Display
          // Scale Display (Only for Grocery/Supermarket)
          if (storeType == 'Grocery' || storeType == 'Supermarket')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                const Icon(Icons.monitor_weight, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(maxWidth: 100),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      "$_currentWeight kg",
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(List<String> categories) {
    return Container(
      height: 60,
      color: Theme.of(context).cardColor,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              key: Key('pos_category_${category.toLowerCase().replaceAll(' ', '_')}'),
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _selectedCategory = category);
              },
              selectedColor: Theme.of(context).primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
              ),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid(List<InventoryItem> products) {
    // Dynamic CrossAxisCount based on Responsive Utils
    int crossAxisCount = 2; // Default Mobile
    if (Responsive.isDesktop(context)) {
      crossAxisCount = 4;
    } else if (Responsive.isTablet(context)) {
      crossAxisCount = 3; 
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount, 
        childAspectRatio: 0.65, // Taller cards to prevent overflow
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final provider = Provider.of<DashboardProvider>(context, listen: false);
        final product = products[index];
        return DemoTarget(
           step: index == 0 ? 'pos_item' : 'none', // Highlight first item for demo
           instruction: "Tap an item to add to cart",
           child: Card(
            elevation: 4,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              key: Key('pos_product_${product.id}'),
              onTap: () {
                 if (index == 0 && provider.demoStep == 'pos_item') provider.nextDemoStep();
                 provider.addToCart(product);
              },
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Expanded(
                    flex: 3,
                    child: InventoryImageWidget(
                      item: product,
                      borderRadius: 16, // Top only logic in widget? No, widget does full. 
                      // Customizing widget for Grid? Or just use as is. 
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "₹${product.price.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartSection(DashboardProvider provider) {
    final inventory = provider.storeInventory;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Current Order", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => provider.clearCart(),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: provider.cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text("Your cart is empty", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                    ],
                  ),
                )
                  : Builder(
                    builder: (context) {
                      final cartEntries = provider.cart.entries.toList();
                      
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: cartEntries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          if (index >= cartEntries.length) return const SizedBox.shrink(); // Safety
                          
                          final entry = cartEntries[index];
                          final itemId = entry.key;
                          final quantity = entry.value;
                          
                          final item = inventory.firstWhere(
                            (i) => i.id == itemId,
                            orElse: () => InventoryItem(id: '?', name: 'Unknown Item', price: 0, quantity: 0, status: 'Unknown', category: 'Misc', trackStock: false)
                          );
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                  InventoryImageWidget(
                                  item: item,
                                  width: 50,
                                  height: 50,
                                  borderRadius: 8,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      Text("₹${item.price.toStringAsFixed(2)}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    InkWell(
                                      key: Key('pos_cart_remove_$itemId'),
                                      onTap: () => provider.removeFromCart(itemId),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                                        child: const Icon(Icons.remove, size: 16),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text("$quantity", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    InkWell(
                                      key: Key('pos_cart_add_$itemId'),
                                      onTap: () => provider.addToCart(item),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(8)),
                                        child: const Icon(Icons.add, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }
                  ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
          ),
          child: Column(
            children: [
               // ORDER SETTINGS REMOVED PER REQUEST (Dine-In/Takeaway/Delivery)
               // Preserving container for spacing
               const SizedBox.shrink(),

               
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Subtotal", style: TextStyle(color: Colors.grey)),
                  Text("₹${provider.calculateCartTotal(inventory).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              
              // Dynamic Tax Display
              if (provider.activeStore?.isTaxEnabled == true) ...[
                 Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Tax (${provider.activeStore?.taxRate ?? 0}%)", style: const TextStyle(color: Colors.grey)),
                    Text("₹${(provider.calculateCartTotal(inventory) * ((provider.activeStore?.taxRate ?? 0) / 100)).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
              
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(
                    "₹${(provider.calculateCartTotal(inventory) * (1 + (provider.activeStore?.isTaxEnabled == true ? ((provider.activeStore?.taxRate ?? 0) / 100) : 0))).toStringAsFixed(2)}",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: DemoTarget(
                     step: 'pos_pay',
                     instruction: "Click Checkout to complete the order",
                     child: ElevatedButton(
                      key: const Key('checkout_button'),
                      onPressed: provider.cart.isNotEmpty && !_isProcessing ? () {
                         // Validation
                         if (_orderType == 'Dine-In' && _selectedTable == null) {
                            // User request: Table selection not strictly required for Dine-In (e.g. Generic Dine-In)
                         }
                         if (provider.demoStep == 'pos_pay') provider.nextDemoStep();
                         _processSale();
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isProcessing ? Colors.grey : Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: _isProcessing ? 0 : 4,
                      ),
                      child: _isProcessing 
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text("CHECKOUT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showUpgradeDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Plan Limit Reached", style: TextStyle(color: Colors.red)),
        content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
              const Icon(Icons.lock, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              const Text("Contact our sales representative to upgrade your plan.", style: TextStyle(color: Colors.grey, fontSize: 12)),
           ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  bool _isProcessing = false;

  Future<void> _processSale() async {
    if (_isProcessing) return;
    
    // Set flag immediately to prevent double-taps
    setState(() => _isProcessing = true);

    final provider = Provider.of<DashboardProvider>(context, listen: false);

    // 0. Subscription Check (Basic Plan Limits)
    try {
       await provider.checkSubscriptionLimits();
    } catch (e) {
       if (mounted) setState(() => _isProcessing = false);
       _showUpgradeDialog(e.toString());
       return;
    }

    // 1. Inventory Validation
    if (provider.activeStore?.trackInventory == true) {
      List<String> outOfStockItems = [];
      for (var entry in provider.cart.entries) {
        try {
          final item = provider.storeInventory.firstWhere((i) => i.id == entry.key);
          if (item.trackStock) {
             final int stock = provider.getItemStock(item.id);
             if (stock < entry.value) {
               outOfStockItems.add("${item.name} (Available: $stock)");
             }
          }
        } catch (_) { /* Error ignored */ }
      }

      if (outOfStockItems.isNotEmpty) {
        // ... (Dialog logic same) ...
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Out of Stock"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("The following items have insufficient stock:"),
                const SizedBox(height: 10),
                ...outOfStockItems.map((s) => Text("• $s", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
            ],
          ),
        );
        if (mounted) setState(() => _isProcessing = false);
        return; // Abort Sale
      }
    }

    // Show Loading using standard Dialog for consistency
    showDialog(
      context: context, 
      barrierDismissible: false,
      useRootNavigator: true, 
      builder: (_) => const PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      if (provider.cart.isEmpty) {
          throw Exception("Cart is empty");
      }

      // 1. Create Order Model with Line-Item Tax
      double totalCgst = 0.0;
      double totalSgst = 0.0;
      double calculatedSubtotal = 0.0;

      final items = provider.cart.entries.map((e) {
        final item = provider.storeInventory.firstWhere((i) => i.id == e.key);
        final itemSubtotal = item.price * e.value;
        calculatedSubtotal += itemSubtotal;

        double itemCgst = 0.0;
        double itemSgst = 0.0;

        if (provider.activeStore?.isTaxEnabled == true) {
           final taxRate = (provider.activeStore?.taxRate ?? 0) / 100;
           // Line Item Level Rounding
           final totalGst = double.parse((itemSubtotal * taxRate).toStringAsFixed(2));
           itemCgst = double.parse((totalGst / 2).toStringAsFixed(2));
           itemSgst = double.parse((totalGst - itemCgst).toStringAsFixed(2)); // Avoid split drift
        }

        totalCgst += itemCgst;
        totalSgst += itemSgst;

        return OrderItem(
          item: item, 
          quantity: e.value,
          costSnapshot: item.cost,
          priceSnapshot: item.price,
          cgst: itemCgst,
          sgst: itemSgst,
        );
      }).toList();

      final total = calculatedSubtotal + totalCgst + totalSgst;

      final order = OrderModel(
        id: provider.syncService.generateUniqueId('ORD'), // Unique Offline ID
        storeId: provider.activeStoreId ?? 'unknown',
        items: items,
        total: total,
        subtotal: calculatedSubtotal,
        cgst: totalCgst,
        sgst: totalSgst,
        date: DateTime.now(),
        status: 'New', 
        type: _orderType,
        paymentMethod: 'Cash', 
        tableId: _selectedTable?.id ?? (_orderType == 'Dine-In' ? 'counter' : null),
        tableName: _selectedTable?.name ?? (_orderType == 'Dine-In' ? 'Counter' : null),
        taxRateSnapshot: (provider.activeStore?.isTaxEnabled == true) ? (provider.activeStore?.taxRate ?? 0) : 0.0,
      );

      // Occupy Table Logic (If Dine-In)
      if (_orderType == 'Dine-In' && _selectedTable != null) {
         final tableProvider = Provider.of<TableProvider>(context, listen: false);
         await tableProvider.occupyTable(_selectedTable!.id, order.id);
      }

      // 2. Save to Firestore
      await provider.placeOrder(order); 
      
      // SUCCESS: Close loader & Clear Cart
      if (mounted) {
         Navigator.of(context, rootNavigator: true).pop();
         
         await Future.delayed(const Duration(milliseconds: 300));
         
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Order Placed Successfully!")));
            provider.clearCart(); // Use provider
            setState(() {
              // _cart.clear(); // Handled by provider
              _currentWeight = "0.000";
              _isProcessing = false;
              _orderType = 'Takeaway'; // Reset
              _selectedTable = null;
            });
         }
      }
      
      // 3. BACKGROUND PRINTING
      _printReceiptInBackground(order);
      
    } catch (e) {
      if (mounted) {
         Navigator.of(context, rootNavigator: true).pop(); // Close loader
         
         await Future.delayed(const Duration(milliseconds: 100)); // Safety delay
         
         setState(() => _isProcessing = false);

         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _printReceiptInBackground(OrderModel order) async {
    try {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      final store = provider.activeStore;

      // Ensure store is available
      if (store == null) {
          return;
      }

      final cashierName = provider.userProfile?.name ?? "Cashier";
      final action = store.receipt.printAction;

      // 1. Print Main Receipt
      if (action == 'Main' || action == 'Both') {
         await PrinterManagerService().printOrderReceipt(order, store, cashierName: cashierName);
      }

      // 2. Print KDS
      if (action == 'KDS' || action == 'Both') {
         if (action == 'Both') {
            await Future.delayed(const Duration(milliseconds: 500)); 
         }
         await PrinterManagerService().printOrderKDS(order, store: store, counters: provider.counters, billerName: cashierName);
      }

    } catch (e) {
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
           content: Text("Printing Failed: $e"), 
           backgroundColor: Colors.red,
           duration: const Duration(seconds: 5),
         ));
      }

    }
  }

  void _showMobileCart(BuildContext context, DashboardProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(child: _buildCartSection(provider)),
          ],
        ),
      ),
    );
  }
}

class _PosCartData {
  final int cartItemCount;
  final int cartTotalQuantity;
  final String activeStoreId;
  final int inventoryLength;

  _PosCartData({
    required this.cartItemCount,
    required this.cartTotalQuantity,
    required this.activeStoreId,
    required this.inventoryLength,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PosCartData &&
          runtimeType == other.runtimeType &&
          cartItemCount == other.cartItemCount &&
          cartTotalQuantity == other.cartTotalQuantity &&
          activeStoreId == other.activeStoreId &&
          inventoryLength == other.inventoryLength;

  @override
  int get hashCode => Object.hash(cartItemCount, cartTotalQuantity, activeStoreId, inventoryLength);
}
