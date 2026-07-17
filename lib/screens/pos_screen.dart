import 'dart:async';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import '../core/design/tokens/app_colors.dart';
import '../core/design/components/molecules/app_empty_state.dart';
// ignore_for_file: deprecated_member_use_from_same_package, use_build_context_synchronously
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/table_provider.dart';
import '../features/inventory/presentation/providers/inventory_provider.dart';
import '../features/inventory/domain/entities/inventory_entity.dart';
import '../models/inventory_item.dart';
import '../features/billing/presentation/providers/billing_provider.dart';
import '../features/billing/domain/entities/order_entity.dart';
import '../models/order_model.dart';
import '../services/scanner_service.dart';
import '../utils/responsive.dart';
import 'dashboard_theme/car_dashboard_pos_screen.dart';
import '../widgets/demo_target.dart'; // Import DemoTarget
import '../models/table_model.dart'; // NEW
// NEW
import '../services/printer_manager_service.dart';
import '../utils/theme.dart';
import '../core/design/tokens/app_typography.dart';
import '../core/design/components/atoms/app_text_field.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/components/atoms/app_button.dart';
import '../core/design/components/atoms/app_card.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_radius.dart';
import '../widgets/inventory_image_widget.dart';

class POSScreen extends StatefulWidget {
  final TableModel? preSelectedTable; // NEW
  const POSScreen({super.key, this.preSelectedTable});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final ScannerService _scannerService = ScannerService();
  final TextEditingController _searchController = TextEditingController();
  String _currentWeight = "0.000";
  // POS Order State
  String _orderType = 'Takeaway'; // Default
  TableModel? _selectedTable;

  StreamSubscription<String>? _scanSubscription;

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
    _scanSubscription = _scannerService.scanStream.listen((barcode) {
      _handleBarcodeScan(barcode);
    });
    // _initScale();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _scannerService.dispose();
    _searchController.dispose();
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
          title: Row(
            children: [
              Icon(Icons.print, color: AppColors.adaptivePrimary(context)),
              const SizedBox(width: AppSpacing.md),
              Text(AppLocalizations.t(context, 'Connect Printer')),
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
              child: Text(AppLocalizations.t(context, 'Later')),
            ),
            ElevatedButton(
              onPressed: () {
                provider.dismissPrinterSetup();
                Navigator.pop(ctx);
                // Navigate to Printer Management
                Navigator.pushNamed(context, '/printer-management');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.adaptivePrimary(context),
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: Text(AppLocalizations.t(context, 'Connect Now')),
            ),
          ],
        ),
      );
    }
  }

  void _handleBarcodeScan(String barcode) {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return;

    final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
    final billingProvider = Provider.of<BillingProvider>(context, listen: false);
    final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);

    // 1. Search in InventoryProvider (InventoryEntity list)
    final inventory = inventoryProvider.allItems;
    InventoryEntity? foundEntity;
    for (var i in inventory) {
      if (i.id.toLowerCase() == cleanBarcode.toLowerCase() ||
          (i.sku != null && i.sku!.trim().toLowerCase() == cleanBarcode.toLowerCase()) ||
          i.name.toLowerCase() == cleanBarcode.toLowerCase()) {
        foundEntity = i;
        break;
      }
    }

    if (foundEntity != null) {
      billingProvider.addToCart(foundEntity.id);
      _searchController.clear();
      inventoryProvider.setSearchQuery('');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Added ${foundEntity.name}"), 
        duration: const Duration(milliseconds: 500)
      ));
      return;
    }

    // 2. Fallback: Search in DashboardProvider (InventoryItem list)
    final legacyInventory = dashboardProvider.storeInventory;
    InventoryItem? foundItem;
    for (var i in legacyInventory) {
      if (i.id.toLowerCase() == cleanBarcode.toLowerCase() ||
          (i.sku != null && i.sku!.trim().toLowerCase() == cleanBarcode.toLowerCase()) ||
          i.name.toLowerCase() == cleanBarcode.toLowerCase()) {
        foundItem = i;
        break;
      }
    }

    if (foundItem != null) {
      billingProvider.addToCart(foundItem.id);
      _searchController.clear();
      inventoryProvider.setSearchQuery('');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Added ${foundItem.name}"), 
        duration: const Duration(milliseconds: 500)
      ));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Item not found for barcode / SKU: $barcode"),
      backgroundColor: AppColors.adaptiveError(context),
    ));
  }

  // Cart state is now managed by BillingProvider

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context); // UPDATED
    final uiStyle = context.select<DashboardProvider, UIStyle>((p) => p.uiStyle);

    // AUTOMOTIVE THEME OVERRIDE
    if (uiStyle == UIStyle.car_dashboard && !isMobile) {
      // Lazy load the car dashboard POS to keep this file clean(er)
      // Note: We need to import it. I'll add the import via another edit or assume it's there.
      // Wait, I should add the import first or at same time.
      return const CarDashboardPOSScreen();
    }

    return PosScaffold(
      mainContent: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: Selector<InventoryProvider, List<InventoryEntity>>(
              selector: (_, p) => p.filteredItems,
              builder: (context, filteredProducts, _) {
                final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
                final categories = inventoryProvider.categories;

                return Column(
                  children: [
                    _buildCategoryTabs(categories, inventoryProvider),
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
      rightPanel: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(-4, 0),
            ),
          ],
        ),
        child: Selector3<BillingProvider, DashboardProvider, InventoryProvider, _PosCartData>(
          selector: (_, b, d, i) => _PosCartData(
            cartItemCount: b.cart.length,
            cartTotalQuantity: b.cart.values.fold(0, (a, b) => a + (b as int? ?? 0)),
            activeStoreId: d.activeStoreId ?? 'unknown',
            inventoryLength: i.allItems.length,
          ),
          builder: (context, data, _) {
            final billingProvider = Provider.of<BillingProvider>(context, listen: false);
            final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
            final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
            return _buildCartSection(billingProvider, dashboardProvider, inventoryProvider);
          },
        ),
      ),
      bottomBar: isMobile
          ? Selector3<BillingProvider, DashboardProvider, InventoryProvider, _PosCartData>(
              selector: (_, b, d, i) => _PosCartData(
                cartItemCount: b.cart.length,
                cartTotalQuantity: b.cart.values.fold(0, (a, b) => a + (b as int? ?? 0)),
                activeStoreId: d.activeStoreId ?? 'unknown',
                inventoryLength: i.allItems.length,
              ),
              builder: (context, data, _) {
                final billingProvider = Provider.of<BillingProvider>(context, listen: false);
                final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
                final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: AppButton.primary(
                      label: "Cart - ${data.cartTotalQuantity} Items",
                      icon: Icons.shopping_cart,
                      onPressed: () => _showMobileCart(context, billingProvider, dashboardProvider, inventoryProvider),
                      size: AppButtonSize.large,
                    ),
                  ),
                );
              },
            )
          : null,
    );
  }

  Widget _buildHeader(BuildContext context) {
    final storeType = context.select<DashboardProvider, String?>((p) => p.activeStore?.storeType);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.surface(context),
      child: Row(
        children: [
          Expanded(
            child: AppTextField(
              key: const Key('pos_search_field'),
              controller: _searchController,
              hintText: "Search for burgers, fries...",
              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary(context)),
              variant: AppTextFieldVariant.filled,
              onChanged: (val) {
                Provider.of<InventoryProvider>(context, listen: false).setSearchQuery(val);
              },
              onSubmitted: (val) {
                _handleBarcodeScan(val);
              },
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          const SizedBox(width: AppSpacing.md),
          // Scale Display
          // Scale Display (Only for Grocery/Supermarket)
          if (Provider.of<DashboardProvider>(context, listen: false).hasAddon('barcode_scanner'))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: AppRadius.borderSm,
                border: Border.all(color: AppColors.adaptiveSuccess(context).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.monitor_weight, color: AppColors.adaptiveSuccess(context), size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 100),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        "$_currentWeight kg",
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.adaptiveSuccess(context),
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

  Widget _buildCategoryTabs(List<String> categories, InventoryProvider provider) {
    return Container(
      height: 60,
      color: AppColors.surface(context),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = provider.selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              key: Key('pos_category_${category.toLowerCase().replaceAll(' ', '_')}'),
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) provider.setCategory(category);
              },
              selectedColor: AppColors.adaptivePrimary(context),
              labelStyle: AppTypography.labelLarge.copyWith(
                color: isSelected ? Theme.of(context).colorScheme.onPrimary : AppColors.textPrimary(context),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: AppColors.surfaceVariant(context),
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
              side: isSelected 
                  ? BorderSide.none 
                  : BorderSide(color: AppColors.border(context), width: 1),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid(List<InventoryEntity> products) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate dynamic crossAxisCount based on available width
        // We target ~180-220px per card width
        int crossAxisCount = (constraints.maxWidth / 180).floor().clamp(2, 6);
        
        // Calculate aspect ratio to keep cards looking good
        // On wider screens, we might want slightly different ratios
        double childAspectRatio = 0.75; 
        if (constraints.maxWidth < 400) {
          childAspectRatio = 0.65; // Taller on small mobile
        } else if (constraints.maxWidth > 1200) {
          childAspectRatio = 0.85; // Slightly wider on very large screens
        }

        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          addAutomaticKeepAlives: false,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final billingProvider = Provider.of<BillingProvider>(context, listen: false);
            final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
            final product = products[index];
            return RepaintBoundary(
              child: DemoTarget(
                step: index == 0 ? 'pos_item' : 'none',
                instruction: "Tap an item to add to cart",
                child: AppCard(
                  padding: EdgeInsets.zero,
                  onTap: () {
                    if (index == 0 && dashboardProvider.demoStep == 'pos_item') dashboardProvider.nextDemoStep();
                    billingProvider.addToCart(product.id);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 4,
                        child: InventoryImageWidget(
                          item: product,
                          borderRadius: 16,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: AppTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary(context),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        "₹${product.price.toStringAsFixed(2)}",
                                        style: AppTypography.titleLarge.copyWith(
                                          color: AppColors.adaptivePrimary(context),
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: AppColors.adaptivePrimary(context).withValues(alpha: 0.1),
                                      borderRadius: AppRadius.borderSm,
                                    ),
                                    child: Icon(
                                      Icons.add_shopping_cart_rounded, 
                                      color: AppColors.adaptivePrimary(context), 
                                      size: 20
                                    ),
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
      },
    );
  }

  Widget _buildCartSection(BillingProvider billingProvider, DashboardProvider dashboardProvider, InventoryProvider inventoryProvider) {
    final inventory = inventoryProvider.allItems;
    final activeStore = dashboardProvider.activeStore;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.t(context, 'Current Order'), style: AppTypography.h4.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                icon: Icon(Icons.delete_outline, color: AppColors.adaptiveError(context)),
                onPressed: () => billingProvider.clearCart(),
                tooltip: 'Clear Cart',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: billingProvider.cart.isEmpty
              ? const AppEmptyState(
                  type: AppEmptyStateType.cart,
                )
                  : Builder(
                    builder: (context) {
                      final cartEntries = billingProvider.cart.entries.toList();
                      
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        itemCount: cartEntries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          if (index >= cartEntries.length) return const SizedBox.shrink(); // Safety
                          
                          final entry = cartEntries[index];
                          final itemId = entry.key;
                          final quantity = entry.value;
                          
                          final item = inventory.firstWhere(
                            (i) => i.id == itemId,
                            orElse: () => const InventoryEntity(id: '?', name: 'Unknown Item', price: 0, category: 'Misc', trackStock: false)
                          );
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                            child: Row(
                              children: [
                                InventoryImageWidget(
                                  item: item,
                                  width: 60,
                                  height: 60,
                                  borderRadius: 12,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name, 
                                        style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        "₹${item.price.toStringAsFixed(2)}", 
                                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant(context),
                                    borderRadius: AppRadius.borderSm,
                                  ),
                                  child: Row(
                                    children: [
                                      _buildCartActionButton(
                                        key: Key('pos_cart_remove_$itemId'),
                                        icon: Icons.remove,
                                        onTap: () => billingProvider.removeFromCart(itemId),
                                      ),
                                      Container(
                                        constraints: const BoxConstraints(minWidth: 32),
                                        alignment: Alignment.center,
                                        child: Text(
                                          "$quantity", 
                                          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)
                                        ),
                                      ),
                                      _buildCartActionButton(
                                        key: Key('pos_cart_add_$itemId'),
                                        icon: Icons.add,
                                        isPrimary: true,
                                        onTap: () => billingProvider.addToCart(itemId),
                                      ),
                                    ],
                                  ),
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
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.08), 
                blurRadius: 15, 
                offset: const Offset(0, -6)
              )
            ],
            border: Border(top: BorderSide(color: AppColors.border(context), width: 1)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.t(context, 'Subtotal'), style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
                  Text("₹${billingProvider.calculateCartTotal(inventory).toStringAsFixed(2)}", style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              
              if (activeStore?.isTaxEnabled == true) ...[
                 Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Tax (${activeStore?.taxRate ?? 0}%)", style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
                    Text("₹${(billingProvider.calculateCartTotal(inventory) * ((activeStore?.taxRate ?? 0) / 100)).toStringAsFixed(2)}", style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md), 
                child: Divider(color: AppColors.border(context), height: 1)
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.t(context, 'Total'), style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                  Text(
                    "₹${(billingProvider.calculateCartTotal(inventory) * (1 + (activeStore?.isTaxEnabled == true ? ((activeStore?.taxRate ?? 0) / 100) : 0))).toStringAsFixed(2)}",
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.w900, 
                      color: AppColors.adaptivePrimary(context),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: DemoTarget(
                     step: 'pos_pay',
                     instruction: "Click Checkout to complete the order",
                     child: AppButton.primary(
                      key: const Key('checkout_button'),
                      label: "PROCEED TO PAYMENT",
                      size: AppButtonSize.large,
                      isLoading: _isProcessing,
                      onPressed: billingProvider.cart.isNotEmpty && !_isProcessing ? () {
                         if (dashboardProvider.demoStep == 'pos_pay') dashboardProvider.nextDemoStep();
                         _processSale();
                      } : null,
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
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        title: Text(AppLocalizations.t(context, 'Plan Limit Reached'), style: AppTypography.titleLarge.copyWith(color: AppColors.adaptiveError(context))),
        content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
              Icon(Icons.lock_clock_rounded, size: 64, color: AppColors.adaptiveWarning(context)),
              const SizedBox(height: AppSpacing.lg),
              Text(message, textAlign: TextAlign.center, style: AppTypography.bodyLarge),
              const SizedBox(height: AppSpacing.md),
              Text(AppLocalizations.t(context, 'Please contact our support to upgrade your enterprise subscription and unlock higher limits.'), 
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))
              ),
           ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: AppButton.primary(
              label: "UNDERSTOOD",
              onPressed: () => Navigator.pop(ctx),
              size: AppButtonSize.medium,
            ),
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

    final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
    final billingProvider = Provider.of<BillingProvider>(context, listen: false);
    final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
    final activeStore = dashboardProvider.activeStore;

    // 0. Subscription Check (Basic Plan Limits)
    try {
       await dashboardProvider.checkSubscriptionLimits();
    } catch (e) {
       if (mounted) setState(() => _isProcessing = false);
       _showUpgradeDialog(e.toString());
       return;
    }

    // 1. Inventory Validation
    if (activeStore?.trackInventory == true) {
      List<String> outOfStockItems = [];
      for (var entry in billingProvider.cart.entries) {
        try {
          final item = inventoryProvider.allItems.firstWhere((i) => i.id == entry.key);
          if (item.trackStock) {
             final int stock = item.quantity.toInt(); // Use InventoryProvider state
             if (stock < entry.value) {
               outOfStockItems.add("${item.name} (Available: $stock)");
             }
          }
        } catch (_) { /* Error ignored */ }
      }

      if (outOfStockItems.isNotEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.adaptiveError(context)),
                const SizedBox(width: AppSpacing.md),
                Text(AppLocalizations.t(context, 'Stock Alert')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.t(context, 'Some items in your cart have insufficient stock to fulfill this order:'), style: AppTypography.bodyMedium),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.adaptiveError(context).withValues(alpha: 0.05),
                    borderRadius: AppRadius.borderSm,
                    border: Border.all(color: AppColors.adaptiveError(context).withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: outOfStockItems.map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, size: 14, color: AppColors.adaptiveError(context)),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(s, style: AppTypography.bodySmall.copyWith(color: AppColors.adaptiveError(context), fontWeight: FontWeight.bold))),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx), 
                child: Text(AppLocalizations.t(context, 'CANCEL'), style: TextStyle(color: AppColors.textSecondary(context)))
              ),
              AppButton.primary(
                label: "ADJUST QUANTITY",
                onPressed: () => Navigator.pop(ctx),
                size: AppButtonSize.small,
              )
            ],
          ),
        );
        if (mounted) setState(() => _isProcessing = false);
        return; // Abort Sale
      }
    }

    // Show Loading
    showDialog(
      context: context, 
      barrierDismissible: false,
      useRootNavigator: true, 
      builder: (_) => const PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: AppColors.transparent,
          elevation: 0,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      if (billingProvider.cart.isEmpty) {
          throw Exception("Cart is empty");
      }

      // 1. Prepare OrderEntity
      final List<OrderItemEntity> orderItems = [];
      double subtotal = 0.0;
      double totalCgst = 0.0;
      double totalSgst = 0.0;

      for (var entry in billingProvider.cart.entries) {
        final item = inventoryProvider.allItems.firstWhere((i) => i.id == entry.key);
        final itemSubtotal = item.price * entry.value;
        subtotal += itemSubtotal;

        double itemCgst = 0.0;
        double itemSgst = 0.0;

        if (activeStore?.isTaxEnabled == true) {
           final taxRate = (activeStore?.taxRate ?? 0) / 100;
           final halfRate = taxRate / 2;
           final totalGst = itemSubtotal * taxRate;
           itemCgst = totalGst * halfRate;
           itemSgst = totalGst * halfRate;
        }

        totalCgst += itemCgst;
        totalSgst += itemSgst;

        orderItems.add(OrderItemEntity(
          itemId: item.id,
          itemName: item.name,
          price: item.price,
          cost: item.cost,
          quantity: entry.value,
          category: item.category,
          cgst: itemCgst,
          sgst: itemSgst,
        ));
      }

      final total = subtotal + totalCgst + totalSgst;
      final orderId = billingProvider.generateOrderId(); // New method helper

      final orderEntity = OrderEntity(
        id: orderId,
        storeId: activeStore?.id ?? 'unknown',
        items: orderItems,
        total: total,
        subtotal: subtotal,
        cgst: totalCgst,
        sgst: totalSgst,
        taxRateSnapshot: (activeStore?.isTaxEnabled == true) ? (activeStore?.taxRate ?? 0).toDouble() : 0.0,
        date: DateTime.now(),
        status: OrderStatus.newOrder,
        type: OrderType.fromString(_orderType),
        paymentMethod: PaymentMethod.cash,
        tableId: _selectedTable?.id ?? (_orderType == 'Dine-In' ? 'counter' : null),
        tableName: _selectedTable?.name ?? (_orderType == 'Dine-In' ? 'Counter' : null),
      );

      // 2. Execute Checkout
      final result = await billingProvider.checkout(
        order: orderEntity,
        activeStoreId: activeStore?.id ?? 'unknown',
        deviceId: 'device-pos', // Should be fetched from settings/platform
        idempotencyKey: orderId,
        taxRate: (activeStore?.taxRate ?? 0).toDouble(),
        trackInventory: activeStore?.trackInventory ?? false,
      );

      if (!result.isSuccess) {
        throw Exception(result.error ?? "Checkout failed");
      }

      // 3. Occupy Table Logic (If Dine-In)
      if (_orderType == 'Dine-In' && _selectedTable != null) {
         final tableProvider = Provider.of<TableProvider>(context, listen: false);
         await tableProvider.occupyTable(_selectedTable!.id, orderId);
      }

      // SUCCESS: Close loader & Clear UI State
      if (mounted) {
         Navigator.of(context, rootNavigator: true).pop();
         
         await Future.delayed(const Duration(milliseconds: 300));
         
         if (mounted) {
            _showSuccessDialog("Order Placed Successfully!");
            billingProvider.clearCart();
            setState(() {
              _currentWeight = "0.000";
              _isProcessing = false;
              _orderType = 'Takeaway';
              _selectedTable = null;
            });
         }
      }
      
      // 4. BACKGROUND PRINTING (Convert to model for legacy service)
      if (result.order != null) {
        _printReceiptInBackground(OrderModel.fromEntity(result.order!));
      }
      
    } catch (e) {
      if (mounted) {
         Navigator.of(context, rootNavigator: true).pop(); // Close loader
         setState(() => _isProcessing = false);
         _showErrorDialog(e.toString());
      }
    }
  }

  Future<void> _printReceiptInBackground(OrderModel order) async {
    try {
      final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
      final store = dashboardProvider.activeStore;

      if (store == null) return;

      final cashierName = dashboardProvider.userProfile?.name ?? "Cashier";
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
         await PrinterManagerService().printOrderKDS(order, store: store, counters: dashboardProvider.counters, billerName: cashierName);
      }

    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
           content: Text("Printing Failed: $e"), 
           backgroundColor: AppColors.error,
           duration: const Duration(seconds: 5),
         ));
      }
    }
  }

  void _showMobileCart(BuildContext context, BillingProvider billingProvider, DashboardProvider dashboardProvider, InventoryProvider inventoryProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.border(context), 
                borderRadius: AppRadius.borderCircular
              ),
            ),
            Expanded(child: _buildCartSection(billingProvider, dashboardProvider, inventoryProvider)),
          ],
        ),
      ),
    );
  }

  Widget _buildCartActionButton({
    required VoidCallback onTap, 
    required IconData icon, 
    bool isPrimary = false,
    Key? key,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: AppRadius.borderSm,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.adaptivePrimary(context) : AppColors.transparent,
          borderRadius: AppRadius.borderSm,
        ),
        child: Icon(
          icon, 
          size: 18, 
          color: isPrimary ? Theme.of(context).colorScheme.onPrimary : AppColors.textPrimary(context)
        ),
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.adaptiveSuccess(context).withValues(alpha: 0.1),
                borderRadius: AppRadius.borderMd,
              ),
              child: Icon(Icons.check_circle_rounded, size: 64, color: AppColors.adaptiveSuccess(context)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(AppLocalizations.t(context, 'Success!'), style: AppTypography.h4.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center, style: AppTypography.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            AppButton.primary(
              label: "CONTINUE",
              onPressed: () => Navigator.pop(ctx),
              size: AppButtonSize.large,
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        title: Text(AppLocalizations.t(context, 'Checkout Error'), style: AppTypography.titleLarge.copyWith(color: AppColors.adaptiveError(context))),
        content: Text(message, style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t(context, 'DISMISS'), style: TextStyle(color: AppColors.textSecondary(context))),
          ),
        ],
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





