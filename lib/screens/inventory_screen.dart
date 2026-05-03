// ignore_for_file: deprecated_member_use_from_same_package
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../models/inventory_item.dart';
import 'add_edit_inventory_screen.dart';
import 'central_item_selection_dialog.dart';
import '../l10n/app_localizations.dart'; // LOCALIZATION
import '../widgets/inventory_image_widget.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/components/atoms/app_text_field.dart';
import '../core/design/components/atoms/app_button.dart';
import '../core/design/components/atoms/app_card.dart';
import '../core/design/components/organisms/pos_data_table.dart';
import '../core/design/density/app_density.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';
import '../core/design/tokens/app_colors.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final allItems = provider.storeInventory;
    final isDesktop = MediaQuery.of(context).size.width >= 1100;
    final density = AppDensityProvider.configOf(context);
    
    // Client-Side Search
    final filteredItems = allItems.where((item) {
       if (_searchQuery.isEmpty) return true;
       return item.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
              (item.sku != null && item.sku!.toLowerCase().contains(_searchQuery.toLowerCase())) ||
              item.id.contains(_searchQuery);
    }).toList();

    return PosScaffold(
      title: AppLocalizations.t(context, 'inventory'),
      actions: [
        if (provider.activeStore?.addons.contains('central_catalog') == true)
          AppButton.secondary(
            label: isDesktop ? AppLocalizations.t(context, 'import') : null,
            icon: Icons.cloud_download,
            onPressed: () => _showImportDialog(context, provider),
          ),
        const SizedBox(width: AppSpacing.sm),
        AppButton.primary(
          key: const Key('add_new_item'),
          label: isDesktop ? AppLocalizations.t(context, 'add_item') : null,
          icon: Icons.add,
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditInventoryScreen()));
          },
        ),
      ],
      mainContent: Column(
        children: [
          // Toolbar & Search
          Padding(
            padding: EdgeInsets.all(density.cardPadding),
            child: AppTextField(
              key: const Key('inventory_search_field'),
              controller: _searchController,
              hintText: '${AppLocalizations.t(context, 'search')} ${AppLocalizations.t(context, 'items')}...',
              prefixIcon: const Icon(Icons.search),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          
          Expanded(
            child: filteredItems.isEmpty
                ? _buildEmptyState()
                : isDesktop 
                    ? _buildTableView(context, filteredItems, provider)
                    : _buildListView(context, filteredItems),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.border(context)),
          const SizedBox(height: AppSpacing.md),
          Text(
            _searchQuery.isEmpty ? 'No items in inventory' : 'No matching items found', 
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))
          ),
        ],
      ),
    );
  }

  Widget _buildListView(BuildContext context, List<InventoryItem> items) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: items.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (ctx, i) {
        return _buildInventoryCard(context, items[i]);
      },
    );
  }

  Widget _buildTableView(BuildContext context, List<InventoryItem> items, DashboardProvider provider) {
    return PosDataTable(
      columns: [
        const PosDataColumn(label: 'Item', fixedWidth: 300),
        const PosDataColumn(label: 'Category', fixedWidth: 150),
        const PosDataColumn(label: 'Price', numeric: true, fixedWidth: 120),
        const PosDataColumn(label: 'Stock', numeric: true, fixedWidth: 150),
        const PosDataColumn(label: 'Status', fixedWidth: 150),
      ],
      rows: items.map((item) {
        final currentStock = provider.getItemStock(item.id);
        final threshold = item.lowStockThreshold ?? 10;
        final isLow = currentStock < threshold && currentStock > 0;
        final isOut = currentStock <= 0;

        return PosDataRow(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditInventoryScreen(item: item)));
          },
          cells: [
            Row(
              children: [
                InventoryImageWidget(item: item, width: 40, height: 40),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(item.name, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold))),
              ],
            ),
            Text(item.category),
            Text('₹${item.price.toStringAsFixed(2)}', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.success)),
            Text(currentStock.toString()),
            _buildStatusBadge(
              isOut ? 'Out of Stock' : (isLow ? 'Low Stock' : 'In Stock'),
              isOut ? AppColors.error : (isLow ? AppColors.warning : AppColors.primary),
            ),
          ],
        );
      }).toList(),
    );
  }

  void _showImportDialog(BuildContext context, DashboardProvider provider) {
    showDialog(
      context: context, 
      builder: (ctx) => const CentralItemSelectionDialog()
    );
  }

  Widget _buildInventoryCard(BuildContext context, InventoryItem item) {
    final provider = Provider.of<DashboardProvider>(context);
    final threshold = item.lowStockThreshold ?? 10;
    final currentStock = provider.getItemStock(item.id);
    final isLow = currentStock < threshold && currentStock > 0;
    final isOut = currentStock <= 0;
    
    return AppCard(
      key: Key('inventory_item_${item.id}'),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditInventoryScreen(item: item)));
      },
      child: Row(
        children: [
          // Image
          InventoryImageWidget(item: item),
          const SizedBox(width: AppSpacing.md),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.xs),
                Text('Category: ${item.category}', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary(context))),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Text('₹${item.price.toStringAsFixed(2)}', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.success)),
                    const Spacer(),
                    Builder(builder: (context) {
                      final trackInventory = provider.activeStore?.trackInventory ?? true;

                      if (!trackInventory) {
                        return _buildStatusBadge('Available', AppColors.success);
                      }

                      if (isOut) {
                        return _buildStatusBadge('Out of Stock', AppColors.error);
                      } else if (isLow) {
                        return _buildStatusBadge('Low Stock: ${provider.getItemStock(item.id)}', AppColors.warning);
                      } else {
                        return _buildStatusBadge('In Stock: ${provider.getItemStock(item.id)}', AppColors.primary);
                      }
                    }),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary(context)),
        ],
      ),
    );
  }


  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.bold)),
    );
  }
}
