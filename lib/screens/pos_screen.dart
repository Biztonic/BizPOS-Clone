import 'dart:async';
import 'dart:math';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import '../core/design/tokens/app_colors.dart';
import '../core/design/components/molecules/app_empty_state.dart';
// ignore_for_file: deprecated_member_use_from_same_package, use_build_context_synchronously
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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
import '../models/store.dart';
import '../services/printer_manager_service.dart';
import '../announcement/service/announcement_service.dart';
import '../utils/theme.dart';
import '../core/design/tokens/app_typography.dart';
import '../core/design/components/atoms/app_text_field.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/components/atoms/app_button.dart';
import '../core/design/components/atoms/app_card.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_radius.dart';
import '../widgets/inventory_image_widget.dart';
import 'package:uuid/uuid.dart';
import '../features/crm/domain/entities/customer.dart';
import '../models/customer_crm_models.dart';
import '../features/store/domain/entities/settings.dart';
import 'add_edit_customer_screen.dart';

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
  Customer? _selectedCustomer; // Selected customer for order & Udhari

  StreamSubscription<String>? _scanSubscription;

  @override
  void initState() {
    super.initState();

    // Check for printer setup on enter and ensure inventory is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPrinterSetupPopup();
      if (mounted) {
        final inventoryProvider =
            Provider.of<InventoryProvider>(context, listen: false);
        if (inventoryProvider.allItems.isEmpty) {
          inventoryProvider.loadInventory();
        }
      }
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

    final inventoryProvider =
        Provider.of<InventoryProvider>(context, listen: false);
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final dashboardProvider =
        Provider.of<DashboardProvider>(context, listen: false);

    // 1. Search in InventoryProvider (InventoryEntity list)
    final inventory = inventoryProvider.allItems;
    InventoryEntity? foundEntity;
    for (var i in inventory) {
      if (i.id.toLowerCase() == cleanBarcode.toLowerCase() ||
          (i.sku != null &&
              i.sku!.trim().toLowerCase() == cleanBarcode.toLowerCase()) ||
          i.name.toLowerCase() == cleanBarcode.toLowerCase()) {
        foundEntity = i;
        break;
      }
    }

    if (foundEntity != null) {
      AnnouncementService().playScanSound();
      billingProvider.addToCart(foundEntity.id);
      _searchController.clear();
      inventoryProvider.setSearchQuery('');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Added ${foundEntity.name}"),
          duration: const Duration(milliseconds: 500)));
      return;
    }

    // 2. Fallback: Search in DashboardProvider (InventoryItem list)
    final legacyInventory = dashboardProvider.storeInventory;
    InventoryItem? foundItem;
    for (var i in legacyInventory) {
      if (i.id.toLowerCase() == cleanBarcode.toLowerCase() ||
          (i.sku != null &&
              i.sku!.trim().toLowerCase() == cleanBarcode.toLowerCase()) ||
          i.name.toLowerCase() == cleanBarcode.toLowerCase()) {
        foundItem = i;
        break;
      }
    }

    if (foundItem != null) {
      AnnouncementService().playScanSound();
      billingProvider.addToCart(foundItem.id);
      _searchController.clear();
      inventoryProvider.setSearchQuery('');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Added ${foundItem.name}"),
          duration: const Duration(milliseconds: 500)));
      return;
    }

    AnnouncementService().playAlertSound();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Item not found for barcode / SKU: $barcode"),
      backgroundColor: AppColors.adaptiveError(context),
    ));
  }

  // Cart state is now managed by BillingProvider

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context); // UPDATED
    final uiStyle =
        context.select<DashboardProvider, UIStyle>((p) => p.uiStyle);

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
                final inventoryProvider =
                    Provider.of<InventoryProvider>(context, listen: false);
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
      rightPanel: Stack(
        children: [
          Container(
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
            child: Selector3<BillingProvider, DashboardProvider,
                InventoryProvider, _PosCartData>(
              selector: (_, b, d, i) => _PosCartData(
                cartItemCount: b.cart.length,
                cartTotalQuantity:
                    b.cart.values.fold(0, (a, b) => a + (b as int? ?? 0)),
                activeStoreId: d.activeStoreId ?? 'unknown',
                inventoryLength: i.allItems.length,
              ),
              builder: (context, data, _) {
                final billingProvider =
                    Provider.of<BillingProvider>(context, listen: false);
                final dashboardProvider =
                    Provider.of<DashboardProvider>(context, listen: false);
                final inventoryProvider =
                    Provider.of<InventoryProvider>(context, listen: false);
                return _buildCartSection(
                    billingProvider, dashboardProvider, inventoryProvider);
              },
            ),
          ),
          if (context.select<DashboardProvider, bool>((p) => p.isEmiLocked))
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.8),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock, color: Colors.redAccent, size: 64),
                    const SizedBox(height: 16),
                    const Text("⚠ EMI Payment Overdue",
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    const Text(
                        "Your hardware EMI is overdue.\nBilling has been temporarily disabled.",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => context.go(
                          '/settings/bizstore'), // Navigates to BizStore to trigger popup or pay
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                      ),
                      child: const Text("Pay EMI Now"),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomBar: isMobile
          ? Selector3<BillingProvider, DashboardProvider, InventoryProvider,
              _PosCartData>(
              selector: (_, b, d, i) => _PosCartData(
                cartItemCount: b.cart.length,
                cartTotalQuantity:
                    b.cart.values.fold(0, (a, b) => a + (b as int? ?? 0)),
                activeStoreId: d.activeStoreId ?? 'unknown',
                inventoryLength: i.allItems.length,
              ),
              builder: (context, data, _) {
                final billingProvider =
                    Provider.of<BillingProvider>(context, listen: false);
                final dashboardProvider =
                    Provider.of<DashboardProvider>(context, listen: false);
                final inventoryProvider =
                    Provider.of<InventoryProvider>(context, listen: false);
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: AppButton.primary(
                      label: "Cart - ${data.cartTotalQuantity} Items",
                      icon: Icons.shopping_cart,
                      onPressed: () => _showMobileCart(context, billingProvider,
                          dashboardProvider, inventoryProvider),
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
              prefixIcon:
                  Icon(Icons.search, color: AppColors.textSecondary(context)),
              variant: AppTextFieldVariant.filled,
              onChanged: (val) {
                Provider.of<InventoryProvider>(context, listen: false)
                    .setSearchQuery(val);
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
          if (Provider.of<DashboardProvider>(context, listen: false)
              .hasAddon('barcode_scanner'))
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxs, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: AppRadius.borderSm,
                border: Border.all(
                    color: AppColors.adaptiveSuccess(context)
                        .withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.monitor_weight,
                      color: AppColors.adaptiveSuccess(context), size: 20),
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

  Widget _buildCategoryTabs(
      List<String> categories, InventoryProvider provider) {
    return Container(
      height: 60,
      color: AppColors.surface(context),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = provider.selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              key: Key(
                  'pos_category_${category.toLowerCase().replaceAll(' ', '_')}'),
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) provider.setCategory(category);
              },
              selectedColor: AppColors.adaptivePrimary(context),
              labelStyle: AppTypography.labelLarge.copyWith(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : AppColors.textPrimary(context),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: AppColors.surfaceVariant(context),
              shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.borderSm),
              side: isSelected
                  ? BorderSide.none
                  : BorderSide(color: AppColors.border(context), width: 1),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 10),
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
            final billingProvider =
                Provider.of<BillingProvider>(context, listen: false);
            final dashboardProvider =
                Provider.of<DashboardProvider>(context, listen: false);
            final product = products[index];
            return RepaintBoundary(
              child: DemoTarget(
                step: index == 0 ? 'pos_item' : 'none',
                instruction: "Tap an item to add to cart",
                child: AppCard(
                  padding: EdgeInsets.zero,
                  onTap: () {
                    if (index == 0 && dashboardProvider.demoStep == 'pos_item')
                      dashboardProvider.nextDemoStep();
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        "₹${product.price.toStringAsFixed(2)}",
                                        style:
                                            AppTypography.titleLarge.copyWith(
                                          color: AppColors.adaptivePrimary(
                                              context),
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: AppColors.adaptivePrimary(context)
                                          .withValues(alpha: 0.1),
                                      borderRadius: AppRadius.borderSm,
                                    ),
                                    child: Icon(Icons.add_shopping_cart_rounded,
                                        color:
                                            AppColors.adaptivePrimary(context),
                                        size: 20),
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

  Widget _buildCartSection(
      BillingProvider billingProvider,
      DashboardProvider dashboardProvider,
      InventoryProvider inventoryProvider) {
    final inventory = inventoryProvider.allItems;
    final activeStore = dashboardProvider.activeStore;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.t(context, 'Current Order'),
                  style:
                      AppTypography.h4.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: AppColors.adaptiveError(context)),
                onPressed: () {
                  billingProvider.clearCart();
                  setState(() => _selectedCustomer = null);
                },
                tooltip: 'Clear Cart',
              ),
            ],
          ),
        ),
        _buildCustomerBar(dashboardProvider),
        const Divider(height: 1),
        Expanded(
          child: billingProvider.cart.isEmpty
              ? const AppEmptyState(
                  type: AppEmptyStateType.cart,
                )
              : Builder(builder: (context) {
                  final cartEntries = billingProvider.cart.entries.toList();

                  return ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: cartEntries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index >= cartEntries.length)
                        return const SizedBox.shrink(); // Safety

                      final entry = cartEntries[index];
                      final itemId = entry.key;
                      final quantity = entry.value;

                      final item = inventory.firstWhere((i) => i.id == itemId,
                          orElse: () => const InventoryEntity(
                              id: '?',
                              name: 'Unknown Item',
                              price: 0,
                              category: 'Misc',
                              trackStock: false));

                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
                                    style: AppTypography.bodyLarge
                                        .copyWith(fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text("₹${item.price.toStringAsFixed(2)}",
                                      style: AppTypography.bodyMedium.copyWith(
                                          color: AppColors.textSecondary(
                                              context))),
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
                                    onTap: () =>
                                        billingProvider.removeFromCart(itemId),
                                  ),
                                  Container(
                                    constraints:
                                        const BoxConstraints(minWidth: 32),
                                    alignment: Alignment.center,
                                    child: Text("$quantity",
                                        style: AppTypography.bodyLarge.copyWith(
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  _buildCartActionButton(
                                    key: Key('pos_cart_add_$itemId'),
                                    icon: Icons.add,
                                    isPrimary: true,
                                    onTap: () =>
                                        billingProvider.addToCart(itemId),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
            boxShadow: [
              BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, -6))
            ],
            border: Border(
                top: BorderSide(color: AppColors.border(context), width: 1)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.t(context, 'Subtotal'),
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textSecondary(context))),
                  Text(
                      "₹${billingProvider.calculateCartTotal(inventory).toStringAsFixed(2)}",
                      style: AppTypography.bodyLarge
                          .copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (activeStore?.isTaxEnabled == true) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Tax (${activeStore?.taxRate ?? 0}%)",
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.textSecondary(context))),
                    Text(
                        "₹${(billingProvider.calculateCartTotal(inventory) * ((activeStore?.taxRate ?? 0) / 100)).toStringAsFixed(2)}",
                        style: AppTypography.bodyLarge
                            .copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Divider(color: AppColors.border(context), height: 1)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.t(context, 'Total'),
                      style: AppTypography.titleLarge
                          .copyWith(fontWeight: FontWeight.bold)),
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
                    onPressed: billingProvider.cart.isNotEmpty && !_isProcessing
                        ? () {
                            if (dashboardProvider.demoStep == 'pos_pay') {
                              dashboardProvider.nextDemoStep();
                            }
                            _processSale();
                          }
                        : null,
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
        title: Text(AppLocalizations.t(context, 'Plan Limit Reached'),
            style: AppTypography.titleLarge
                .copyWith(color: AppColors.adaptiveError(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_clock_rounded,
                size: 64, color: AppColors.adaptiveWarning(context)),
            const SizedBox(height: AppSpacing.lg),
            Text(message,
                textAlign: TextAlign.center, style: AppTypography.bodyLarge),
            const SizedBox(height: AppSpacing.md),
            Text(
                AppLocalizations.t(context,
                    'Please contact our support to upgrade your enterprise subscription and unlock higher limits.'),
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary(context))),
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

  Widget _buildCustomerBar(DashboardProvider dashboardProvider) {
    if (_selectedCustomer == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: InkWell(
          onTap: () async {
            final picked =
                await _openCustomerPickerModal(context, dashboardProvider);
            if (picked != null && mounted) {
              setState(() => _selectedCustomer = picked);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color:
                    AppColors.adaptivePrimary(context).withValues(alpha: 0.35),
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(8),
              color: AppColors.adaptivePrimary(context).withValues(alpha: 0.05),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_add_alt_1_outlined,
                  size: 20,
                  color: AppColors.adaptivePrimary(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Add / Select Customer (Walk-in)",
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.adaptivePrimary(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Required for Udhari (Khata credit) & loyalty coins",
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary(context),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 13,
                  color: AppColors.adaptivePrimary(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Customer is selected
    final cs = dashboardProvider.activeStore?.customerSettings ?? const CustomerAddonSettings();
    final bool isUdhariEnabled = cs.enableUdhari;
    final bool isLoyaltyEnabled = cs.enableLoyalty;
    final hasUdhari = isUdhariEnabled && _selectedCustomer!.udhariBalance > 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasUdhari
              ? AppColors.adaptiveWarning(context).withValues(alpha: 0.5)
              : AppColors.border(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    AppColors.adaptivePrimary(context).withValues(alpha: 0.1),
                child: Text(
                  _selectedCustomer!.name.isNotEmpty
                      ? _selectedCustomer!.name[0].toUpperCase()
                      : 'C',
                  style: TextStyle(
                    color: AppColors.adaptivePrimary(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedCustomer!.name,
                      style: AppTypography.titleSmall
                          .copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_selectedCustomer!.phone != null &&
                        _selectedCustomer!.phone!.isNotEmpty)
                      Text(
                        _selectedCustomer!.phone!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: "Remove Customer",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _selectedCustomer = null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Udhari Balance tag (Only when Udhari is enabled in Settings)
              if (isUdhariEnabled) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasUdhari
                        ? AppColors.adaptiveError(context).withValues(alpha: 0.1)
                        : AppColors.adaptiveSuccess(context)
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 13,
                        color: hasUdhari
                            ? AppColors.adaptiveError(context)
                            : AppColors.adaptiveSuccess(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasUdhari
                            ? "Due Udhari: ₹${_selectedCustomer!.udhariBalance.toStringAsFixed(2)}"
                            : "Udhari: Clear",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: hasUdhari
                              ? AppColors.adaptiveError(context)
                              : AppColors.adaptiveSuccess(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedCustomer!.creditLimit > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant(context),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "Limit: ₹${_selectedCustomer!.creditLimit.toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                ],
              ],
              // Loyalty Points tag (Only when Loyalty is enabled in Settings)
              if (isLoyaltyEnabled) ...[
                if (isUdhariEnabled) const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.adaptiveWarning(context)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars,
                          size: 13, color: AppColors.adaptiveWarning(context)),
                      const SizedBox(width: 4),
                      Text(
                        "${_selectedCustomer!.loyaltyPoints} pts",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.adaptiveWarning(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Member Tier tag (Only when Membership is enabled in Settings)
              if (cs.enableMembership && _selectedCustomer!.tier.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _selectedCustomer!.tier.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.adaptivePrimary(context),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (hasUdhari)
                InkWell(
                  onTap: () => _openSettleUdhariDialog(
                      context, _selectedCustomer!, dashboardProvider),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.adaptiveSuccess(context)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border:
                          Border.all(color: AppColors.adaptiveSuccess(context)),
                    ),
                    child: Text(
                      "Settle Due",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.adaptiveSuccess(context),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<Customer?> _openCustomerPickerModal(
      BuildContext context, DashboardProvider dashboardProvider) async {
    final searchCtrl = TextEditingController();
    List<Customer> allCustomers = dashboardProvider.customers;
    List<Customer> filtered = List.from(allCustomers);

    return showDialog<Customer>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            backgroundColor: AppColors.surface(context),
            shape:
                const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.people_outline,
                        color: AppColors.adaptivePrimary(context)),
                    const SizedBox(width: 8),
                    const Text("Select Customer"),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("New Customer"),
                  onPressed: () async {
                    final newCust =
                        await AddEditCustomerScreen.showAsDialog(context);
                    if (newCust != null && ctx.mounted) {
                      Navigator.pop(ctx, newCust);
                    }
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              height: 480,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: "Search by name, phone, or email...",
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero),
                      suffixIcon: searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchCtrl.clear();
                                setModalState(
                                    () => filtered = List.from(allCustomers));
                              },
                            )
                          : null,
                    ),
                    onChanged: (q) {
                      final query = q.trim().toLowerCase();
                      setModalState(() {
                        if (query.isEmpty) {
                          filtered = List.from(allCustomers);
                        } else {
                          filtered = allCustomers.where((c) {
                            return c.name.toLowerCase().contains(query) ||
                                (c.phone != null && c.phone!.contains(query)) ||
                                (c.mobile != null &&
                                    c.mobile!.contains(query)) ||
                                c.email.toLowerCase().contains(query);
                          }).toList();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_off_outlined,
                                    size: 48,
                                    color: AppColors.textSecondary(context)),
                                const SizedBox(height: 8),
                                const Text("No customers found"),
                                const SizedBox(height: 8),
                                AppButton.secondary(
                                  label: "Create New Customer",
                                  icon: Icons.person_add,
                                  onPressed: () async {
                                    final newCust =
                                        await AddEditCustomerScreen.showAsDialog(
                                            context);
                                    if (newCust != null && ctx.mounted) {
                                      Navigator.pop(ctx, newCust);
                                    }
                                  },
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final cust = filtered[i];
                              final cs = dashboardProvider.activeStore?.customerSettings ?? const CustomerAddonSettings();
                              final bool isUdhariEnabled = cs.enableUdhari;
                              final bool isLoyaltyEnabled = cs.enableLoyalty;
                              final isSelected =
                                  _selectedCustomer?.id == cust.id;
                              final hasUdhari = isUdhariEnabled && cust.udhariBalance > 0;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isSelected
                                      ? AppColors.adaptivePrimary(context)
                                      : AppColors.adaptivePrimary(context)
                                          .withValues(alpha: 0.1),
                                  child: Text(
                                    cust.name.isNotEmpty
                                        ? cust.name[0].toUpperCase()
                                        : 'C',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.adaptivePrimary(context),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        cust.name,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (hasUdhari)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color:
                                              AppColors.adaptiveError(context)
                                                  .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          "Due: ₹${cust.udhariBalance.toStringAsFixed(0)}",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.adaptiveError(
                                                context),
                                          ),
                                        ),
                                      ),
                                    if (isLoyaltyEnabled && cust.loyaltyPoints > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.adaptiveWarning(context)
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          "${cust.loyaltyPoints} pts",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.adaptiveWarning(context),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                    cust.phone ?? cust.mobile ?? cust.email),
                                trailing: isSelected
                                    ? Icon(Icons.check_circle,
                                        color:
                                            AppColors.adaptivePrimary(context))
                                    : null,
                                onTap: () => Navigator.pop(ctx, cust),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.t(context, 'Cancel')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openSettleUdhariDialog(
    BuildContext context,
    Customer customer,
    DashboardProvider dashboardProvider,
  ) {
    final amountController =
        TextEditingController(text: customer.udhariBalance.toStringAsFixed(0));
    final refController = TextEditingController();
    final notesController = TextEditingController();
    String paymentMode = 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final double enteredAmount =
              double.tryParse(amountController.text.trim()) ?? 0.0;
          final double newBalance = (customer.udhariBalance - enteredAmount)
              .clamp(0.0, double.infinity);

          return AlertDialog(
            backgroundColor: AppColors.surface(context),
            shape:
                const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            title: Row(
              children: [
                Icon(Icons.check_circle,
                    color: AppColors.adaptiveSuccess(context)),
                const SizedBox(width: 8),
                Text(
                  "Settle Udhari (Payment Received)",
                  style: AppTypography.titleMedium
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.adaptiveSuccess(context)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.adaptiveSuccess(context)
                                .withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(customer.name,
                                  style: AppTypography.titleSmall
                                      .copyWith(fontWeight: FontWeight.bold)),
                              Text(customer.phone ?? '',
                                  style: AppTypography.bodySmall),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text("Current Due",
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                              Text("₹${customer.udhariBalance.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.adaptiveError(context),
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: amountController,
                      label: "Payment Amount (₹) *",
                      hintText: "Enter amount received",
                      prefixIcon: const Icon(Icons.currency_rupee),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        ActionChip(
                          label: Text(
                              "Full Due: ₹${customer.udhariBalance.toStringAsFixed(0)}",
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold)),
                          backgroundColor: AppColors.adaptiveSuccess(context)
                              .withValues(alpha: 0.15),
                          onPressed: () {
                            amountController.text =
                                customer.udhariBalance.toStringAsFixed(0);
                            setModalState(() {});
                          },
                        ),
                        if (customer.udhariBalance > 500)
                          ActionChip(
                            label: const Text("₹500",
                                style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              amountController.text = "500";
                              setModalState(() {});
                            },
                          ),
                        if (customer.udhariBalance > 1000)
                          ActionChip(
                            label: const Text("₹1000",
                                style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              amountController.text = "1000";
                              setModalState(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: paymentMode,
                      decoration: const InputDecoration(
                        labelText: "Payment Mode",
                        border:
                            OutlineInputBorder(borderRadius: BorderRadius.zero),
                      ),
                      items: ['Cash', 'UPI', 'Card', 'Bank Transfer']
                          .map((m) =>
                              DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => paymentMode = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: refController,
                      label: "Receipt / Txn Ref (Optional)",
                      hintText: "e.g. Receipt #42",
                      prefixIcon: const Icon(Icons.receipt_outlined),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: notesController,
                      label: "Notes (Optional)",
                      hintText: "e.g. Partial cash settlement at counter",
                      prefixIcon: const Icon(Icons.note_outlined),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: newBalance > 0
                            ? AppColors.adaptiveWarning(context)
                                .withValues(alpha: 0.1)
                            : AppColors.adaptiveSuccess(context)
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Remaining Due After Payment:",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(
                            "₹${newBalance.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: newBalance > 0
                                  ? AppColors.adaptiveWarning(context)
                                  : AppColors.adaptiveSuccess(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.t(context, 'Cancel')),
              ),
              AppButton.primary(
                label:
                    "Record Payment (₹${enteredAmount.toStringAsFixed(0)})",
                onPressed: enteredAmount <= 0
                    ? null
                    : () async {
                        final effectiveStoreId =
                            dashboardProvider.activeStore?.id ??
                                dashboardProvider.activeStoreId ??
                                'store_default';

                        final tx = UdhariTransaction(
                          id: const Uuid().v4(),
                          customerId: customer.id,
                          storeId: effectiveStoreId,
                          type: 'payment',
                          amount: enteredAmount,
                          balanceAfter: newBalance,
                          date: DateTime.now(),
                          paymentMode: paymentMode,
                          referenceId: refController.text.trim(),
                          notes: notesController.text.trim(),
                          createdBy: dashboardProvider.userProfile?.name ??
                              'Cashier',
                        );

                        await dashboardProvider.addUdhariTransaction(tx);

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          setState(() {
                            _selectedCustomer = _selectedCustomer?.copyWith(
                                udhariBalance: newBalance);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  "Recorded ₹${enteredAmount.toStringAsFixed(0)} payment from ${customer.name}. New Due: ₹${newBalance.toStringAsFixed(0)}"),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor:
                                  AppColors.adaptiveSuccess(context),
                            ),
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaymentModeOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    Color? accentColor,
    String? badge,
  }) {
    final effectiveColor =
        accentColor ?? AppColors.adaptivePrimary(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveColor.withValues(alpha: 0.12)
              : AppColors.surface(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? effectiveColor : AppColors.border(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 26,
                  color: isSelected
                      ? effectiveColor
                      : AppColors.textSecondary(context),
                ),
                if (badge != null)
                  Positioned(
                    top: -6,
                    right: -14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: effectiveColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected
                    ? effectiveColor
                    : AppColors.textPrimary(context),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDialog({
    required BuildContext context,
    required BillingProvider billingProvider,
    required DashboardProvider dashboardProvider,
    required InventoryProvider inventoryProvider,
  }) {
    final inventory = inventoryProvider.allItems;
    final activeStore = dashboardProvider.activeStore;
    final cartTotal = billingProvider.calculateCartTotal(inventory);
    final isTaxEnabled = activeStore?.isTaxEnabled == true;
    final taxRate = (activeStore?.taxRate ?? 0).toDouble();

    String selectedMode = 'CASH'; // 'CASH', 'UPI', 'UDHARI'
    String udhariType = 'full'; // 'full' or 'partial'
    String upfrontPaymentMode = 'Cash'; // 'Cash' or 'UPI'
    final upfrontAmountController = TextEditingController();
    final cashTenderedController = TextEditingController();
    final notesController = TextEditingController();
    final upiRefController = TextEditingController();
    final couponInputController = TextEditingController();

    SeasonalCoupon? appliedCoupon;
    String? couponError;
    bool redeemLoyaltyPoints = false;
    int pointsToRedeem = 0;
    bool controllersInitialized = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cs =
              activeStore?.customerSettings ?? const CustomerAddonSettings();
          final bool isUdhariEnabled = cs.enableUdhari;
          final bool isLoyaltyEnabled = cs.enableLoyalty;
          final bool isCouponsEnabled = cs.enableCoupons;
          final bool allowPartialUdhari = cs.allowPartialUdhari;

          if (!allowPartialUdhari && udhariType == 'partial') {
            udhariType = 'full';
          }
          if (!isUdhariEnabled && selectedMode == 'UDHARI') {
            selectedMode = 'CASH';
          }
          final bool hasUdhari = isUdhariEnabled &&
              _selectedCustomer != null &&
              _selectedCustomer!.udhariBalance > 0;

          // 1. Coupon Discount calculation
          double couponDiscount = 0.0;
          if (isCouponsEnabled && appliedCoupon != null) {
            if (appliedCoupon!.isActive &&
                !appliedCoupon!.isExpired &&
                cartTotal >= appliedCoupon!.minOrderValue) {
              couponDiscount = appliedCoupon!.calculateDiscount(cartTotal);
            } else {
              appliedCoupon = null;
              couponDiscount = 0.0;
            }
          }

          // 2. Loyalty Points Redemption calculation
          double pointsDiscount = 0.0;
          int maxEligiblePoints = 0;
          if (isLoyaltyEnabled &&
              _selectedCustomer != null &&
              _selectedCustomer!.loyaltyPoints >= cs.minPointsToRedeem) {
            final double maxDiscountCap =
                cartTotal * (cs.maxBillDiscountPercent / 100);
            final int pointsCap = cs.pointRedemptionValue > 0
                ? (maxDiscountCap / cs.pointRedemptionValue).floor()
                : 0;
            maxEligiblePoints = min(_selectedCustomer!.loyaltyPoints, pointsCap);

            if (redeemLoyaltyPoints) {
              if (pointsToRedeem == 0 || pointsToRedeem > maxEligiblePoints) {
                pointsToRedeem = maxEligiblePoints;
              }
              pointsDiscount = pointsToRedeem * cs.pointRedemptionValue;
            } else {
              pointsDiscount = 0.0;
            }
          } else {
            redeemLoyaltyPoints = false;
            pointsToRedeem = 0;
            pointsDiscount = 0.0;
          }

          final double totalDiscount =
              (couponDiscount + pointsDiscount).clamp(0.0, cartTotal);
          final double taxableSubtotal =
              (cartTotal - totalDiscount).clamp(0.0, double.infinity);
          final double totalTax =
              isTaxEnabled ? (taxableSubtotal * (taxRate / 100)) : 0.0;
          final double grandTotal = taxableSubtotal + totalTax;

          if (!controllersInitialized) {
            upfrontAmountController.text = (grandTotal / 2).toStringAsFixed(0);
            cashTenderedController.text = grandTotal.toStringAsFixed(2);
            controllersInitialized = true;
          }

          void syncTotals(double newGrandTotal) {
            cashTenderedController.text = newGrandTotal.toStringAsFixed(2);
            upfrontAmountController.text = (newGrandTotal / 2).toStringAsFixed(0);
          }

          final double upfrontAmount =
              double.tryParse(upfrontAmountController.text.trim()) ?? 0.0;
          final double remainingUdhari =
              (grandTotal - upfrontAmount).clamp(0.0, grandTotal);
          final double cashTendered =
              double.tryParse(cashTenderedController.text.trim()) ??
                  grandTotal;
          final double changeDue = (cashTendered - grandTotal);

          final double effectiveLimit = (_selectedCustomer != null &&
                  _selectedCustomer!.creditLimit > 0)
              ? _selectedCustomer!.creditLimit
              : cs.defaultCreditLimit;
          final double borrowAmount =
              (udhariType == 'full' ? grandTotal : remainingUdhari);
          final double projectedBalance = (_selectedCustomer != null
                  ? _selectedCustomer!.udhariBalance
                  : 0.0) +
              borrowAmount;
          final bool isLimitExceeded = _selectedCustomer != null &&
              effectiveLimit > 0 &&
              projectedBalance > effectiveLimit;
          final bool isBlockEnforced =
              isLimitExceeded && cs.blockWhenLimitExceeded;

          return AlertDialog(
            backgroundColor: AppColors.surface(context),
            shape:
                const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.adaptivePrimary(context)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.point_of_sale,
                          color: AppColors.adaptivePrimary(context),
                          size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Payment & Settlement",
                          style: AppTypography.titleMedium
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "${billingProvider.cart.length} items · Total ₹${grandTotal.toStringAsFixed(2)}",
                          style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary(context)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Grand Total Hero Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.adaptivePrimary(context)
                                .withValues(alpha: 0.12),
                            AppColors.adaptivePrimary(context)
                                .withValues(alpha: 0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.adaptivePrimary(context)
                              .withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("TOTAL PAYABLE AMOUNT",
                                  style: AppTypography.labelSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: AppColors.adaptivePrimary(context),
                                  )),
                              const SizedBox(height: 2),
                              Text("₹${grandTotal.toStringAsFixed(2)}",
                                  style: AppTypography.headlineMedium.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.adaptivePrimary(context),
                                  )),
                              if (totalDiscount > 0)
                                Text(
                                  "You saved ₹${totalDiscount.toStringAsFixed(2)} on this bill!",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.adaptiveSuccess(context),
                                  ),
                                ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                  "Subtotal: ₹${cartTotal.toStringAsFixed(2)}",
                                  style: AppTypography.bodySmall.copyWith(
                                      color:
                                          AppColors.textSecondary(context))),
                              if (couponDiscount > 0)
                                Text(
                                  "Coupon (${appliedCoupon!.code}): -₹${couponDiscount.toStringAsFixed(2)}",
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.adaptiveSuccess(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (pointsDiscount > 0)
                                Text(
                                  "Points ($pointsToRedeem pts): -₹${pointsDiscount.toStringAsFixed(2)}",
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.adaptiveSuccess(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (isTaxEnabled)
                                Text(
                                    "GST (${taxRate.toStringAsFixed(0)}%): ₹${totalTax.toStringAsFixed(2)}",
                                    style: AppTypography.bodySmall.copyWith(
                                        color:
                                            AppColors.textSecondary(context))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Customer Selection & Status Row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _selectedCustomer != null
                            ? (hasUdhari
                                ? AppColors.adaptiveWarning(context)
                                    .withValues(alpha: 0.08)
                                : AppColors.adaptiveSuccess(context)
                                    .withValues(alpha: 0.08))
                            : AppColors.surfaceVariant(context)
                                .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedCustomer != null
                              ? (hasUdhari
                                  ? AppColors.adaptiveWarning(context)
                                      .withValues(alpha: 0.3)
                                  : AppColors.adaptiveSuccess(context)
                                      .withValues(alpha: 0.3))
                              : AppColors.border(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedCustomer != null
                                ? Icons.person
                                : Icons.person_outline,
                            size: 24,
                            color: _selectedCustomer != null
                                ? AppColors.adaptivePrimary(context)
                                : AppColors.textSecondary(context),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _selectedCustomer != null
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            _selectedCustomer!.name,
                                            style: AppTypography.titleSmall
                                                .copyWith(
                                                    fontWeight:
                                                        FontWeight.bold),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _selectedCustomer!.phone ?? '',
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                                    color:
                                                        AppColors.textSecondary(
                                                            context)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          if (isUdhariEnabled) ...[
                                            Text(
                                              _selectedCustomer!.udhariBalance > 0
                                                  ? "Current Udhari: ₹${_selectedCustomer!.udhariBalance.toStringAsFixed(2)}"
                                                  : "Khata Balance: Clear (₹0)",
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: _selectedCustomer!
                                                            .udhariBalance >
                                                        0
                                                    ? AppColors.adaptiveError(
                                                        context)
                                                    : AppColors.adaptiveSuccess(
                                                        context),
                                              ),
                                            ),
                                            if (_selectedCustomer!.creditLimit >
                                                0) ...[
                                              const SizedBox(width: 10),
                                              Text(
                                                "Limit: ₹${_selectedCustomer!.creditLimit.toStringAsFixed(0)}",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textSecondary(
                                                      context),
                                                ),
                                              ),
                                            ],
                                          ],
                                          if (isLoyaltyEnabled) ...[
                                            if (isUdhariEnabled)
                                              const SizedBox(width: 10),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: AppColors.adaptiveWarning(context)
                                                    .withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                "${_selectedCustomer!.loyaltyPoints} Coins (₹${(_selectedCustomer!.loyaltyPoints * cs.pointRedemptionValue).toStringAsFixed(1)})",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.adaptiveWarning(context),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                          "Walk-in Customer (No customer selected)",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      Text(
                                        isUdhariEnabled
                                            ? "Customer selection is required to issue Udhari (Khata)"
                                            : (isLoyaltyEnabled
                                                ? "Select customer to earn & redeem loyalty points"
                                                : "Walk-in customer checkout"),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              AppColors.textSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          TextButton.icon(
                            icon: Icon(
                              _selectedCustomer != null
                                  ? Icons.swap_horiz
                                  : Icons.person_add_alt_1,
                              size: 16,
                            ),
                            label: Text(_selectedCustomer != null
                                ? "Change"
                                : "Select"),
                            onPressed: () async {
                              final picked = await _openCustomerPickerModal(
                                  context, dashboardProvider);
                              if (picked != null && mounted) {
                                setState(() => _selectedCustomer = picked);
                                setDialogState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ─── SEASONAL & FESTIVE COUPONS SECTION ────
                    if (isCouponsEnabled) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant(context).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: appliedCoupon != null
                                ? AppColors.adaptiveSuccess(context).withValues(alpha: 0.5)
                                : AppColors.border(context),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.local_offer, size: 16, color: AppColors.adaptivePrimary(context)),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Seasonal & Festive Coupons",
                                      style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                if (appliedCoupon != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.adaptiveSuccess(context).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle, size: 13, color: AppColors.adaptiveSuccess(context)),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${appliedCoupon!.code}: -₹${couponDiscount.toStringAsFixed(2)}",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.adaptiveSuccess(context),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        InkWell(
                                          onTap: () {
                                            setDialogState(() {
                                              appliedCoupon = null;
                                              couponInputController.clear();
                                              couponError = null;
                                              final disc = pointsDiscount;
                                              final taxable = (cartTotal - disc).clamp(0.0, double.infinity);
                                              final newTot = taxable + (isTaxEnabled ? (taxable * (taxRate / 100)) : 0.0);
                                              syncTotals(newTot);
                                            });
                                          },
                                          child: Icon(Icons.close, size: 14, color: AppColors.adaptiveError(context)),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            if (appliedCoupon == null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 38,
                                      child: TextField(
                                        controller: couponInputController,
                                        textCapitalization: TextCapitalization.characters,
                                        decoration: InputDecoration(
                                          hintText: "Enter coupon code (e.g. DIWALI20)",
                                          hintStyle: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          prefixIcon: const Icon(Icons.confirmation_number_outlined, size: 16),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  AppButton.secondary(
                                    label: "Apply",
                                    onPressed: () {
                                      final code = couponInputController.text.trim().toUpperCase();
                                      if (code.isEmpty) return;
                                      final match = cs.seasonalCoupons.firstWhere(
                                        (c) => c.code.toUpperCase() == code,
                                        orElse: () => SeasonalCoupon(
                                          id: '',
                                          code: code,
                                          title: '',
                                          discountType: 'percentage',
                                          discountValue: 0,
                                          isActive: false,
                                        ),
                                      );
                                      if (!match.isActive || match.id.isEmpty) {
                                        setDialogState(() => couponError = "Invalid or inactive coupon code.");
                                      } else if (match.isExpired) {
                                        setDialogState(() => couponError = "This coupon has expired.");
                                      } else if (cartTotal < match.minOrderValue) {
                                        setDialogState(() => couponError = "Min bill value ₹${match.minOrderValue.toStringAsFixed(0)} required.");
                                      } else {
                                        setDialogState(() {
                                          appliedCoupon = match;
                                          couponError = null;
                                          final disc = match.calculateDiscount(cartTotal);
                                          final totDisc = (disc + pointsDiscount).clamp(0.0, cartTotal);
                                          final taxable = (cartTotal - totDisc).clamp(0.0, double.infinity);
                                          final newTot = taxable + (isTaxEnabled ? (taxable * (taxRate / 100)) : 0.0);
                                          syncTotals(newTot);
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                              if (couponError != null) ...[
                                const SizedBox(height: 4),
                                Text(couponError!, style: TextStyle(fontSize: 11, color: AppColors.adaptiveError(context))),
                              ],
                              if (cs.seasonalCoupons.any((c) => c.isActive && !c.isExpired)) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: cs.seasonalCoupons
                                      .where((c) => c.isActive && !c.isExpired)
                                      .map((c) {
                                    final isEligible = cartTotal >= c.minOrderValue;
                                    return InkWell(
                                      onTap: () {
                                        if (!isEligible) {
                                          setDialogState(() => couponError = "Min bill value ₹${c.minOrderValue.toStringAsFixed(0)} required for ${c.code}.");
                                          return;
                                        }
                                        couponInputController.text = c.code;
                                        setDialogState(() {
                                          appliedCoupon = c;
                                          couponError = null;
                                          final disc = c.calculateDiscount(cartTotal);
                                          final totDisc = (disc + pointsDiscount).clamp(0.0, cartTotal);
                                          final taxable = (cartTotal - totDisc).clamp(0.0, double.infinity);
                                          final newTot = taxable + (isTaxEnabled ? (taxable * (taxRate / 100)) : 0.0);
                                          syncTotals(newTot);
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isEligible
                                              ? AppColors.adaptivePrimary(context).withValues(alpha: 0.08)
                                              : AppColors.surfaceVariant(context),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: isEligible
                                                ? AppColors.adaptivePrimary(context).withValues(alpha: 0.3)
                                                : AppColors.border(context),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              c.code,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isEligible ? AppColors.adaptivePrimary(context) : AppColors.textSecondary(context),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              c.discountType == 'percentage'
                                                  ? "(${c.discountValue.toStringAsFixed(0)}% OFF)"
                                                  : "(₹${c.discountValue.toStringAsFixed(0)} OFF)",
                                              style: TextStyle(fontSize: 10, color: AppColors.textSecondary(context)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // ─── LOYALTY POINTS REDEMPTION SECTION ────
                    if (isLoyaltyEnabled) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant(context).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: redeemLoyaltyPoints
                                ? AppColors.adaptiveWarning(context).withValues(alpha: 0.5)
                                : AppColors.border(context),
                          ),
                        ),
                        child: _selectedCustomer == null
                            ? Row(
                                children: [
                                  Icon(Icons.stars_outlined, size: 18, color: AppColors.adaptiveWarning(context)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Select a customer to redeem loyalty coins and earn points on this bill.",
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                                    ),
                                  ),
                                ],
                              )
                            : (_selectedCustomer!.loyaltyPoints < cs.minPointsToRedeem
                                ? Row(
                                    children: [
                                      Icon(Icons.stars, size: 18, color: AppColors.adaptiveWarning(context)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Customer has ${_selectedCustomer!.loyaltyPoints} loyalty coins (Min ${cs.minPointsToRedeem} required to redeem).",
                                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.stars, size: 18, color: AppColors.adaptiveWarning(context)),
                                              const SizedBox(width: 8),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "Redeem Loyalty Coins",
                                                    style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold),
                                                  ),
                                                  Text(
                                                    "Available: ${_selectedCustomer!.loyaltyPoints} coins • Max bill discount: ${cs.maxBillDiscountPercent.toStringAsFixed(0)}%",
                                                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary(context)),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Switch(
                                            value: redeemLoyaltyPoints,
                                            onChanged: (val) {
                                              setDialogState(() {
                                                redeemLoyaltyPoints = val;
                                                if (val) {
                                                  pointsToRedeem = maxEligiblePoints;
                                                } else {
                                                  pointsToRedeem = 0;
                                                }
                                                final pDisc = pointsToRedeem * cs.pointRedemptionValue;
                                                final totDisc = (couponDiscount + pDisc).clamp(0.0, cartTotal);
                                                final taxable = (cartTotal - totDisc).clamp(0.0, double.infinity);
                                                final newTot = taxable + (isTaxEnabled ? (taxable * (taxRate / 100)) : 0.0);
                                                syncTotals(newTot);
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                      if (redeemLoyaltyPoints) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.adaptiveSuccess(context).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "Redeeming $pointsToRedeem coins",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.adaptiveSuccess(context),
                                                ),
                                              ),
                                              Text(
                                                "- ₹${pointsDiscount.toStringAsFixed(2)} Discount",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.adaptiveSuccess(context),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  )),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // Payment Method Options Header
                    Text(
                      "SELECT PAYMENT METHOD",
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Payment Method Tabs (CASH, UPI, UDHARI strictly conditional)
                    Row(
                      children: [
                        Expanded(
                          child: _buildPaymentModeOption(
                            context: context,
                            title: "CASH",
                            subtitle: "Physical Cash",
                            icon: Icons.payments_outlined,
                            isSelected: selectedMode == 'CASH',
                            onTap: () =>
                                setDialogState(() => selectedMode = 'CASH'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildPaymentModeOption(
                            context: context,
                            title: "UPI",
                            subtitle: "GPay, PhonePe, QR",
                            icon: Icons.qr_code_2_outlined,
                            isSelected: selectedMode == 'UPI',
                            onTap: () =>
                                setDialogState(() => selectedMode = 'UPI'),
                          ),
                        ),
                        if (isUdhariEnabled) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildPaymentModeOption(
                              context: context,
                              title: "UDHARI",
                              subtitle: "Khata Credit",
                              icon: Icons.account_balance_wallet_outlined,
                              isSelected: selectedMode == 'UDHARI',
                              accentColor: AppColors.adaptiveWarning(context),
                              badge: _selectedCustomer != null
                                  ? "Customer Ready"
                                  : "Req. Customer",
                              onTap: () =>
                                  setDialogState(() => selectedMode = 'UDHARI'),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // PAYMENT DETAILS CONTAINER
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant(context)
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Builder(
                        builder: (_) {
                          if (selectedMode == 'CASH') {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.payments,
                                        size: 18,
                                        color: AppColors.adaptiveSuccess(
                                            context)),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Cash Tender & Change",
                                      style: AppTypography.titleSmall
                                          .copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                AppTextField(
                                  controller: cashTenderedController,
                                  label: "Cash Tendered by Customer (₹)",
                                  hintText: "Enter amount received",
                                  prefixIcon: const Icon(Icons.currency_rupee),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                                const SizedBox(height: 8),
                                // Quick tender chips
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    ActionChip(
                                      label: Text(
                                          "Exact (₹${grandTotal.toStringAsFixed(0)})",
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                      onPressed: () {
                                        cashTenderedController.text =
                                            grandTotal.toStringAsFixed(2);
                                        setDialogState(() {});
                                      },
                                    ),
                                    ...[100, 200, 500, 1000, 2000]
                                        .where((denom) => denom >= grandTotal)
                                        .take(3)
                                        .map((denom) => ActionChip(
                                              label: Text("₹$denom",
                                                  style: const TextStyle(
                                                      fontSize: 11)),
                                              onPressed: () {
                                                cashTenderedController.text =
                                                    denom.toString();
                                                setDialogState(() {});
                                              },
                                            )),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: changeDue >= 0
                                        ? AppColors.adaptiveSuccess(context)
                                            .withValues(alpha: 0.1)
                                        : AppColors.adaptiveWarning(context)
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        changeDue >= 0
                                            ? "Change to Return:"
                                            : "Balance Short:",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: changeDue >= 0
                                              ? AppColors.adaptiveSuccess(
                                                  context)
                                              : AppColors.adaptiveWarning(
                                                  context),
                                        ),
                                      ),
                                      Text(
                                        "₹${changeDue.abs().toStringAsFixed(2)}",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: changeDue >= 0
                                              ? AppColors.adaptiveSuccess(
                                                  context)
                                              : AppColors.adaptiveWarning(
                                                  context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          } else if (selectedMode == 'UPI') {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.qr_code_2,
                                        size: 20,
                                        color: AppColors.adaptivePrimary(
                                            context)),
                                    const SizedBox(width: 8),
                                    Text(
                                      "UPI Direct Payment",
                                      style: AppTypography.titleSmall
                                          .copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface(context),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppColors.border(context)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color:
                                              AppColors.adaptivePrimary(context)
                                                  .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(Icons.qr_code_scanner,
                                            size: 36,
                                            color: AppColors.adaptivePrimary(
                                                context)),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Scan with GPay / PhonePe / Paytm",
                                              style: AppTypography.bodyMedium
                                                  .copyWith(
                                                      fontWeight:
                                                          FontWeight.bold),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "Customer scans your store dynamic UPI QR code or transfers to active UPI ID.",
                                              style: AppTypography.bodySmall
                                                  .copyWith(
                                                      color: AppColors
                                                          .textSecondary(
                                                              context)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                AppTextField(
                                  controller: upiRefController,
                                  label:
                                      "UPI Reference / Transaction ID (Optional)",
                                  hintText: "e.g. 331204892341",
                                  prefixIcon: const Icon(Icons.tag),
                                ),
                              ],
                            );
                          } else {
                            // UDHARI (KHATA CREDIT)
                            if (_selectedCustomer == null) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.adaptiveWarning(context)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color:
                                          AppColors.adaptiveWarning(context)),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.person_search_outlined,
                                        size: 40,
                                        color:
                                            AppColors.adaptiveWarning(context)),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Customer Selection Required",
                                      style:
                                          AppTypography.titleMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            AppColors.adaptiveWarning(context),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      "Udhari creates a borrow ledger record under the customer's account so their balance and repayments are tracked. Please select or add a customer to proceed.",
                                      textAlign: TextAlign.center,
                                      style: AppTypography.bodySmall,
                                    ),
                                    const SizedBox(height: 12),
                                    AppButton.primary(
                                      label: "Select / Add Customer Now",
                                      icon: Icons.person_add,
                                      onPressed: () async {
                                        final picked =
                                            await _openCustomerPickerModal(
                                                context, dashboardProvider);
                                        if (picked != null && mounted) {
                                          setState(
                                              () => _selectedCustomer = picked);
                                          setDialogState(() {});
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }

                            // Customer IS selected:
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.account_balance_wallet,
                                        size: 18,
                                        color:
                                            AppColors.adaptiveWarning(context)),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Udhari (Khata Credit) Options",
                                      style: AppTypography.titleSmall
                                          .copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Radio options: Full Udhari vs Partial Payment + Remaining Udhari
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => setDialogState(
                                            () => udhariType = 'full'),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: udhariType == 'full'
                                                ? AppColors.adaptiveWarning(
                                                        context)
                                                    .withValues(alpha: 0.15)
                                                : AppColors.surface(context),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: udhariType == 'full'
                                                  ? AppColors.adaptiveWarning(
                                                      context)
                                                  : AppColors.border(context),
                                              width:
                                                  udhariType == 'full' ? 2 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                udhariType == 'full'
                                                    ? Icons.radio_button_checked
                                                    : Icons.radio_button_off,
                                                size: 18,
                                                color: udhariType == 'full'
                                                    ? AppColors.adaptiveWarning(
                                                        context)
                                                    : AppColors.textSecondary(
                                                        context),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text("Full Udhari",
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13)),
                                                    Text(
                                                        "100% Credit (₹${grandTotal.toStringAsFixed(0)})",
                                                        style: const TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                Colors.grey)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (allowPartialUdhari) ...[
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => setDialogState(
                                              () => udhariType = 'partial'),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: udhariType == 'partial'
                                                  ? AppColors.adaptivePrimary(
                                                          context)
                                                      .withValues(alpha: 0.15)
                                                  : AppColors.surface(context),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: udhariType == 'partial'
                                                    ? AppColors.adaptivePrimary(
                                                        context)
                                                    : AppColors.border(context),
                                                width: udhariType == 'partial'
                                                    ? 2
                                                    : 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  udhariType == 'partial'
                                                      ? Icons.radio_button_checked
                                                      : Icons.radio_button_off,
                                                  size: 18,
                                                  color: udhariType == 'partial'
                                                      ? AppColors
                                                          .adaptivePrimary(
                                                              context)
                                                      : AppColors
                                                          .textSecondary(
                                                              context),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      const Text(
                                                          "Partial + Udhari",
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 13)),
                                                      const Text(
                                                          "Part Pay + Balance Due",
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              color:
                                                                  Colors.grey)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (!allowPartialUdhari) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    "Note: Partial Udhari is disabled in Store Settings. Entire bill is credited to Khata.",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),

                                if (udhariType == 'partial') ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface(context),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: AppColors.border(context)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Partial Payment Details",
                                          style: AppTypography.labelMedium
                                              .copyWith(
                                                  fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: AppTextField(
                                                controller:
                                                    upfrontAmountController,
                                                label: "Paid Now (₹)",
                                                hintText: "Upfront amount",
                                                prefixIcon: const Icon(
                                                    Icons.currency_rupee),
                                                keyboardType:
                                                    TextInputType.number,
                                                onChanged: (_) =>
                                                    setDialogState(() {}),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              flex: 2,
                                              child:
                                                  DropdownButtonFormField<
                                                      String>(
                                                value: upfrontPaymentMode,
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: "Paid Via",
                                                  border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.zero),
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 12),
                                                ),
                                                items: ['Cash', 'UPI']
                                                    .map((m) =>
                                                        DropdownMenuItem(
                                                            value: m,
                                                            child: Text(m)))
                                                    .toList(),
                                                onChanged: (v) {
                                                  if (v != null) {
                                                    setDialogState(() =>
                                                        upfrontPaymentMode = v);
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // Quick percentage buttons
                                        Wrap(
                                          spacing: 6,
                                          children: [
                                            ActionChip(
                                              label: const Text("25%",
                                                  style: TextStyle(
                                                      fontSize: 11)),
                                              onPressed: () {
                                                upfrontAmountController.text =
                                                    (grandTotal * 0.25)
                                                        .toStringAsFixed(0);
                                                setDialogState(() {});
                                              },
                                            ),
                                            ActionChip(
                                              label: const Text("50%",
                                                  style: TextStyle(
                                                      fontSize: 11)),
                                              onPressed: () {
                                                upfrontAmountController.text =
                                                    (grandTotal * 0.50)
                                                        .toStringAsFixed(0);
                                                setDialogState(() {});
                                              },
                                            ),
                                            ActionChip(
                                              label: const Text("75%",
                                                  style: TextStyle(
                                                      fontSize: 11)),
                                              onPressed: () {
                                                upfrontAmountController.text =
                                                    (grandTotal * 0.75)
                                                        .toStringAsFixed(0);
                                                setDialogState(() {});
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Divider(
                                            color: AppColors.border(context)),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                                "Remaining as Udhari:",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13)),
                                            Text(
                                              "₹${remainingUdhari.toStringAsFixed(2)}",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                color: AppColors.adaptiveError(
                                                    context),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Balance Breakdown Card
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.adaptiveWarning(context)
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.adaptiveWarning(context)
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text("Current Due:",
                                              style: AppTypography.bodySmall),
                                          Text(
                                              "₹${_selectedCustomer!.udhariBalance.toStringAsFixed(2)}",
                                              style: AppTypography.bodySmall
                                                  .copyWith(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text("New Borrow (This Bill):",
                                              style: AppTypography.bodySmall),
                                          Text(
                                            "+ ₹${(udhariType == 'full' ? grandTotal : remainingUdhari).toStringAsFixed(2)}",
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.adaptiveError(
                                                  context),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                              "Projected Khata Balance:",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13)),
                                          Text(
                                            "₹${(_selectedCustomer!.udhariBalance + (udhariType == 'full' ? grandTotal : remainingUdhari)).toStringAsFixed(2)}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                              color: AppColors.adaptiveError(
                                                  context),
                                            ),
                                          ),
                                        ],
                                       ),
                                      if (isLimitExceeded) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: (isBlockEnforced
                                                    ? AppColors.adaptiveError(
                                                        context)
                                                    : AppColors.adaptiveWarning(
                                                        context))
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: (isBlockEnforced
                                                  ? AppColors.adaptiveError(
                                                      context)
                                                  : AppColors.adaptiveWarning(
                                                      context)),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isBlockEnforced
                                                    ? Icons.block
                                                    : Icons
                                                        .warning_amber_rounded,
                                                color: (isBlockEnforced
                                                    ? AppColors.adaptiveError(
                                                        context)
                                                    : AppColors.adaptiveWarning(
                                                        context)),
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  isBlockEnforced
                                                      ? "Credit Limit (₹${effectiveLimit.toStringAsFixed(0)}) Exceeded! Checkout is BLOCKED by Store Policy."
                                                      : "Warning: Credit Limit (₹${effectiveLimit.toStringAsFixed(0)}) Exceeded. Approval required.",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: (isBlockEnforced
                                                        ? AppColors
                                                            .adaptiveError(
                                                                context)
                                                        : AppColors
                                                            .adaptiveWarning(
                                                                context)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                AppTextField(
                                  controller: notesController,
                                  label: "Udhari Notes / Remarks (Optional)",
                                  hintText:
                                      "e.g. Promised payment on next visit",
                                  prefixIcon:
                                      const Icon(Icons.note_alt_outlined),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(AppLocalizations.t(context, 'Cancel'),
                    style: TextStyle(color: AppColors.textSecondary(context))),
              ),
              AppButton.primary(
                label: selectedMode == 'UDHARI'
                    ? (isBlockEnforced
                        ? "Credit Limit Exceeded (Blocked)"
                        : (udhariType == 'full'
                            ? "Confirm Full Udhari (₹${grandTotal.toStringAsFixed(0)})"
                            : "Confirm Partial (₹${upfrontAmount.toStringAsFixed(0)} + ₹${remainingUdhari.toStringAsFixed(0)} Udhari)"))
                    : "Confirm & Pay ₹${grandTotal.toStringAsFixed(2)}",
                icon: isBlockEnforced ? Icons.block : Icons.check_circle_outline,
                onPressed: (selectedMode == 'UDHARI' &&
                        (_selectedCustomer == null || isBlockEnforced))
                    ? null
                    : () {
                        Navigator.pop(dialogContext);

                        if (selectedMode == 'CASH') {
                          _executeSale(
                            billingProvider: billingProvider,
                            dashboardProvider: dashboardProvider,
                            inventoryProvider: inventoryProvider,
                            paymentMethod: PaymentMethod.cash,
                            paymentModeLabel: 'Cash',
                            totalDiscount: totalDiscount,
                            redeemedLoyaltyPoints: redeemLoyaltyPoints ? pointsToRedeem : 0,
                            redeemedPointsDiscount: pointsDiscount,
                            couponCodeApplied: appliedCoupon?.code,
                            couponDiscountApplied: couponDiscount,
                          );
                        } else if (selectedMode == 'UPI') {
                          _executeSale(
                            billingProvider: billingProvider,
                            dashboardProvider: dashboardProvider,
                            inventoryProvider: inventoryProvider,
                            paymentMethod: PaymentMethod.upi,
                            paymentModeLabel: 'UPI',
                            notes: upiRefController.text.trim(),
                            totalDiscount: totalDiscount,
                            redeemedLoyaltyPoints: redeemLoyaltyPoints ? pointsToRedeem : 0,
                            redeemedPointsDiscount: pointsDiscount,
                            couponCodeApplied: appliedCoupon?.code,
                            couponDiscountApplied: couponDiscount,
                          );
                        } else {
                          // UDHARI
                          if (udhariType == 'full') {
                            _executeSale(
                              billingProvider: billingProvider,
                              dashboardProvider: dashboardProvider,
                              inventoryProvider: inventoryProvider,
                              paymentMethod: PaymentMethod.udhari,
                              paymentModeLabel: 'Udhari',
                              udhariAmount: grandTotal,
                              notes: notesController.text.trim(),
                              totalDiscount: totalDiscount,
                              redeemedLoyaltyPoints: redeemLoyaltyPoints ? pointsToRedeem : 0,
                              redeemedPointsDiscount: pointsDiscount,
                              couponCodeApplied: appliedCoupon?.code,
                              couponDiscountApplied: couponDiscount,
                            );
                          } else {
                            // PARTIAL
                            _executeSale(
                              billingProvider: billingProvider,
                              dashboardProvider: dashboardProvider,
                              inventoryProvider: inventoryProvider,
                              paymentMethod: PaymentMethod.split,
                              paymentModeLabel: 'Partial Udhari',
                              upfrontPaidAmount: upfrontAmount,
                              upfrontPaymentMode: upfrontPaymentMode,
                              udhariAmount: remainingUdhari,
                              notes: notesController.text.trim(),
                              totalDiscount: totalDiscount,
                              redeemedLoyaltyPoints: redeemLoyaltyPoints ? pointsToRedeem : 0,
                              redeemedPointsDiscount: pointsDiscount,
                              couponCodeApplied: appliedCoupon?.code,
                              couponDiscountApplied: couponDiscount,
                            );
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _processSale() async {
    final dashboardProvider =
        Provider.of<DashboardProvider>(context, listen: false);
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final inventoryProvider =
        Provider.of<InventoryProvider>(context, listen: false);

    _showPaymentDialog(
      context: context,
      billingProvider: billingProvider,
      dashboardProvider: dashboardProvider,
      inventoryProvider: inventoryProvider,
    );
  }

  Future<void> _executeSale({
    required BillingProvider billingProvider,
    required DashboardProvider dashboardProvider,
    required InventoryProvider inventoryProvider,
    required PaymentMethod paymentMethod,
    required String paymentModeLabel,
    double upfrontPaidAmount = 0.0,
    String upfrontPaymentMode = 'Cash',
    double udhariAmount = 0.0,
    String notes = '',
    double totalDiscount = 0.0,
    int redeemedLoyaltyPoints = 0,
    double redeemedPointsDiscount = 0.0,
    String? couponCodeApplied,
    double couponDiscountApplied = 0.0,
  }) async {
    if (_isProcessing) return;

    // Set flag immediately to prevent double-taps
    setState(() => _isProcessing = true);

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
          final item =
              inventoryProvider.allItems.firstWhere((i) => i.id == entry.key);
          if (item.trackStock) {
            final int stock =
                item.quantity.toInt(); // Use InventoryProvider state
            if (stock < entry.value) {
              outOfStockItems.add("${item.name} (Available: $stock)");
            }
          }
        } catch (_) {/* Error ignored */}
      }

      if (outOfStockItems.isNotEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppColors.adaptiveError(context)),
                const SizedBox(width: AppSpacing.md),
                Text(AppLocalizations.t(context, 'Stock Alert')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    AppLocalizations.t(context,
                        'Some items in your cart have insufficient stock to fulfill this order:'),
                    style: AppTypography.bodyMedium),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.adaptiveError(context)
                        .withValues(alpha: 0.05),
                    borderRadius: AppRadius.borderSm,
                    border: Border.all(
                        color: AppColors.adaptiveError(context)
                            .withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: outOfStockItems
                        .map((s) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.xs),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      size: 14,
                                      color: AppColors.adaptiveError(context)),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                      child: Text(s,
                                          style: AppTypography.bodySmall
                                              .copyWith(
                                                  color:
                                                      AppColors.adaptiveError(
                                                          context),
                                                  fontWeight:
                                                      FontWeight.bold))),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.t(context, 'CANCEL'),
                      style:
                          TextStyle(color: AppColors.textSecondary(context)))),
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
        final item =
            inventoryProvider.allItems.firstWhere((i) => i.id == entry.key);
        final itemSubtotal = item.price * entry.value;
        subtotal += itemSubtotal;

        double itemCgst = 0.0;
        double itemSgst = 0.0;

        if (activeStore?.isTaxEnabled == true) {
          final taxRate = (activeStore?.taxRate ?? 0) / 100;
          final halfRate = taxRate / 2;
          itemCgst = itemSubtotal * halfRate;
          itemSgst = itemSubtotal * halfRate;
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

      final effectiveSubtotal = subtotal;
      final effectiveDiscount = totalDiscount.clamp(0.0, effectiveSubtotal);
      final taxableAmount = (effectiveSubtotal - effectiveDiscount).clamp(0.0, double.infinity);
      final total = taxableAmount + totalCgst + totalSgst;
      // Bind durable operation ID from billingProvider to guarantee exactly-once checkout across retries
      final orderId = billingProvider.activeCheckoutId;

      final orderEntity = OrderEntity(
        id: orderId,
        storeId: activeStore?.id ?? 'unknown',
        items: orderItems,
        total: total,
        subtotal: subtotal,
        discount: effectiveDiscount,
        discountSnapshot: effectiveDiscount,
        cgst: totalCgst,
        sgst: totalSgst,
        taxRateSnapshot: (activeStore?.isTaxEnabled == true)
            ? (activeStore?.taxRate ?? 0).toDouble()
            : 0.0,
        date: DateTime.now(),
        status: OrderStatus.newOrder,
        type: OrderType.fromString(_orderType),
        paymentMethod: paymentMethod,
        customerId: _selectedCustomer?.id,
        customerName: _selectedCustomer?.name,
        customerPhone: _selectedCustomer?.phone ?? _selectedCustomer?.mobile,
        tableId:
            _selectedTable?.id ?? (_orderType == 'Dine-In' ? 'counter' : null),
        tableName: _selectedTable?.name ??
            (_orderType == 'Dine-In' ? 'Counter' : null),
      );

      // 2. Execute Checkout
      final result = await billingProvider.checkout(
        order: orderEntity,
        activeStoreId: activeStore?.id ?? 'unknown',
        deviceId: 'device-pos', // Should be fetched from settings/platform
        idempotencyKey: orderId,
        taxRate: (activeStore?.taxRate ?? 0).toDouble(),
        trackInventory: activeStore?.trackInventory ?? true,
        negativeStockPolicy: activeStore?.negativeStockPolicyEnum,
      );

      if (!result.isSuccess) {
        throw Exception(result.error ?? "Checkout failed");
      }

      // 2.1 Record Udhari Transaction if Udhari or Partial Udhari
      if (udhariAmount > 0 && _selectedCustomer != null) {
        final effectiveStoreId =
            (activeStore != null && activeStore.id.isNotEmpty)
                ? activeStore.id
                : (dashboardProvider.activeStoreId ?? 'store_default');

        final udhariTx = UdhariTransaction(
          id: const Uuid().v4(),
          customerId: _selectedCustomer!.id,
          storeId: effectiveStoreId,
          type: 'borrow',
          amount: udhariAmount,
          balanceAfter: _selectedCustomer!.udhariBalance + udhariAmount,
          date: DateTime.now(),
          referenceId: orderId,
          paymentMode: paymentModeLabel == 'Partial Udhari'
              ? 'Partial ($upfrontPaymentMode: ₹${upfrontPaidAmount.toStringAsFixed(2)}, Udhari: ₹${udhariAmount.toStringAsFixed(2)})'
              : 'Udhari (Full Credit)',
          notes: notes.isNotEmpty
              ? notes
              : 'POS Bill #${orderEntity.shortId} credit',
          createdBy: dashboardProvider.userProfile?.name ?? 'Cashier',
        );

        await dashboardProvider.addUdhariTransaction(udhariTx);
      }

      // 2.2 Record Loyalty Points Redemption if points were redeemed
      int currentPoints = _selectedCustomer?.loyaltyPoints ?? 0;
      if (redeemedLoyaltyPoints > 0 && _selectedCustomer != null) {
        final effectiveStoreId =
            (activeStore != null && activeStore.id.isNotEmpty)
                ? activeStore.id
                : (dashboardProvider.activeStoreId ?? 'store_default');

        final int balanceAfterRedemption =
            (currentPoints - redeemedLoyaltyPoints).clamp(0, 9999999);

        final redeemTx = LoyaltyTransaction(
          id: const Uuid().v4(),
          customerId: _selectedCustomer!.id,
          storeId: effectiveStoreId,
          type: 'redeemed',
          points: -redeemedLoyaltyPoints,
          balanceAfter: balanceAfterRedemption,
          date: DateTime.now(),
          reason:
              'Redeemed on Bill #${orderEntity.shortId} (₹${redeemedPointsDiscount.toStringAsFixed(2)} discount)',
        );

        await dashboardProvider.addLoyaltyTransaction(redeemTx);
        currentPoints = balanceAfterRedemption;
      }

      // 2.3 Award Loyalty Points if loyalty program is enabled
      int awardedPoints = 0;
      final cs =
          activeStore?.customerSettings ?? const CustomerAddonSettings();
      if (cs.enableLoyalty && _selectedCustomer != null) {
        final double spendRate =
            cs.earnRateSpendAmount > 0 ? cs.earnRateSpendAmount : 100.0;
        final int earnPoints = cs.earnRatePoints > 0 ? cs.earnRatePoints : 1;
        double multiplier = 1.0;

        if (cs.enableMembership) {
          final totalSpent = _selectedCustomer!.totalSpent;
          if (totalSpent >= cs.platinumMinSpend) {
            multiplier = cs.platinumMultiplier;
          } else if (totalSpent >= cs.goldMinSpend) {
            multiplier = cs.goldMultiplier;
          } else if (totalSpent >= cs.silverMinSpend) {
            multiplier = cs.silverMultiplier;
          }
        }

        // Earn points on net spend (after discount)
        final double netSpend = taxableAmount;
        awardedPoints = ((netSpend / spendRate) * earnPoints * multiplier).floor();

        if (awardedPoints > 0) {
          final effectiveStoreId =
              (activeStore != null && activeStore.id.isNotEmpty)
                ? activeStore.id
                : (dashboardProvider.activeStoreId ?? 'store_default');

          final loyaltyTx = LoyaltyTransaction(
            id: const Uuid().v4(),
            customerId: _selectedCustomer!.id,
            storeId: effectiveStoreId,
            type: 'earned',
            points: awardedPoints,
            balanceAfter: currentPoints + awardedPoints,
            date: DateTime.now(),
            reason:
                'Earned on Bill #${orderEntity.shortId}${multiplier > 1.0 ? " (${multiplier.toStringAsFixed(1)}x tier bonus)" : ""}',
          );

          await dashboardProvider.addLoyaltyTransaction(loyaltyTx);
        }
      }

      // 2.4 Update in-memory customer state immediately
      if (_selectedCustomer != null) {
        final updatedPoints = currentPoints + awardedPoints;
        final updatedSpent = _selectedCustomer!.totalSpent + total;
        final updatedVisits = _selectedCustomer!.visitCount + 1;
        final updatedUdhari = _selectedCustomer!.udhariBalance + udhariAmount;
        setState(() {
          _selectedCustomer = _selectedCustomer!.copyWith(
            loyaltyPoints: updatedPoints,
            totalSpent: updatedSpent,
            visitCount: updatedVisits,
            udhariBalance: updatedUdhari,
          );
        });
      }

      // 3. Occupy Table Logic (If Dine-In)
      if (_orderType == 'Dine-In' && _selectedTable != null) {
        final tableProvider =
            Provider.of<TableProvider>(context, listen: false);
        await tableProvider.occupyTable(_selectedTable!.id, orderId);
      }

      // SUCCESS: Close loader & Clear UI State
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          String successMessage = "Order Placed Successfully!";
          if (totalDiscount > 0) {
            successMessage += " (Saved: ₹${totalDiscount.toStringAsFixed(2)})";
          }
          if (paymentModeLabel == 'Udhari' && _selectedCustomer != null) {
            successMessage =
                "Order Placed! ₹${udhariAmount.toStringAsFixed(2)} added to ${_selectedCustomer!.name}'s Udhari (Khata).";
          } else if (paymentModeLabel == 'Partial Udhari' &&
              _selectedCustomer != null) {
            successMessage =
                "Order Placed! ₹${upfrontPaidAmount.toStringAsFixed(2)} received via $upfrontPaymentMode, ₹${udhariAmount.toStringAsFixed(2)} added to Udhari.";
          }
          if (awardedPoints > 0) {
            successMessage += " ⭐ +$awardedPoints loyalty points awarded!";
          }
          _showSuccessDialog(successMessage);
          billingProvider.clearCart();
          setState(() {
            _currentWeight = "0.000";
            _isProcessing = false;
            _orderType = 'Takeaway';
            _selectedTable = null;
            _selectedCustomer = null;
          });
        }
      }

      // 4. BACKGROUND PRINTING (Convert to model for legacy service)
      if (result.order != null) {
        _printReceiptInBackground(OrderModel.fromEntity(result.order!), activeStore);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loader
        setState(() => _isProcessing = false);
        _showErrorDialog(e.toString());
      }
    }
  }

  Future<void> _printReceiptInBackground(OrderModel order, [Store? passedStore]) async {
    try {
      final dashboardProvider =
          Provider.of<DashboardProvider>(context, listen: false);
      final store = passedStore ?? dashboardProvider.activeStore;

      if (store == null) return;

      final cashierName = dashboardProvider.userProfile?.name ?? "Cashier";
      final action = (store.receipt.printAction).trim().toLowerCase();

      // 1. Print Main Receipt
      if (action == 'main' || action == 'both' || action.isEmpty) {
        await PrinterManagerService()
            .printOrderReceipt(order, store, cashierName: cashierName);
      }

      // 2. Print KDS
      if (action == 'kds' || action == 'both') {
        if (action == 'both') {
          await Future.delayed(const Duration(milliseconds: 500));
        }
        await PrinterManagerService().printOrderKDS(order,
            store: store,
            counters: dashboardProvider.counters,
            billerName: cashierName);
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

  void _showMobileCart(
      BuildContext context,
      BillingProvider billingProvider,
      DashboardProvider dashboardProvider,
      InventoryProvider inventoryProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.border(context),
                  borderRadius: AppRadius.borderCircular),
            ),
            Expanded(
                child: _buildCartSection(
                    billingProvider, dashboardProvider, inventoryProvider)),
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
          color: isPrimary
              ? AppColors.adaptivePrimary(context)
              : AppColors.transparent,
          borderRadius: AppRadius.borderSm,
        ),
        child: Icon(icon,
            size: 18,
            color: isPrimary
                ? Theme.of(context).colorScheme.onPrimary
                : AppColors.textPrimary(context)),
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
                color:
                    AppColors.adaptiveSuccess(context).withValues(alpha: 0.1),
                borderRadius: AppRadius.borderMd,
              ),
              child: Icon(Icons.check_circle_rounded,
                  size: 64, color: AppColors.adaptiveSuccess(context)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(AppLocalizations.t(context, 'Success!'),
                style: AppTypography.h4.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                textAlign: TextAlign.center, style: AppTypography.bodyLarge),
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
        title: Text(AppLocalizations.t(context, 'Checkout Error'),
            style: AppTypography.titleLarge
                .copyWith(color: AppColors.adaptiveError(context))),
        content: Text(message, style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t(context, 'DISMISS'),
                style: TextStyle(color: AppColors.textSecondary(context))),
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
  int get hashCode => Object.hash(
      cartItemCount, cartTotalQuantity, activeStoreId, inventoryLength);
}
