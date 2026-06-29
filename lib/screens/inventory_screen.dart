// ignore_for_file: deprecated_member_use_from_same_package
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../features/inventory/presentation/providers/inventory_provider.dart';
import '../features/inventory/domain/entities/inventory_entity.dart';
import '../features/inventory/data/mappers/inventory_mapper.dart';
import 'add_edit_inventory_screen.dart';
import 'central_item_selection_dialog.dart';
import '../l10n/app_localizations.dart'; 
import '../widgets/inventory_image_widget.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/components/atoms/app_text_field.dart';
import '../core/design/components/atoms/app_button.dart';
import '../core/design/components/atoms/app_card.dart';
import '../core/design/components/organisms/pos_data_table.dart';
import '../core/design/components/molecules/app_empty_state.dart';
import '../core/design/density/app_density.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';
import '../core/design/tokens/app_colors.dart';
import '../core/design/tokens/app_radius.dart';


class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        final provider = Provider.of<InventoryProvider>(context, listen: false);
        provider.setSearchQuery(_searchController.text.trim());
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 1100;
    final density = AppDensityProvider.configOf(context);
    
    return PosScaffold(
      title: AppLocalizations.t(context, 'inventory'),
      actions: [
        if (dashboardProvider.activeStore?.addons.contains('central_catalog') == true)
          AppButton.secondary(
            label: isDesktop ? AppLocalizations.t(context, 'import') : null,
            icon: Icons.cloud_download,
            onPressed: () => _showImportDialog(context, dashboardProvider),
          ),
        const SizedBox(width: AppSpacing.sm),
        AppButton.primary(
          key: const Key('add_new_item'),
          label: isDesktop ? AppLocalizations.t(context, 'add_item') : null,
          icon: Icons.add,
          onPressed: () {
            AddEditInventoryScreen.showAsDialog(context);
          },
        ),
      ],
      mainContent: CustomScrollView(
        slivers: [
          // Toolbar & Search
          SliverPadding(
            padding: EdgeInsets.all(density.cardPadding),
            sliver: SliverToBoxAdapter(
              child: AppTextField(
                key: const Key('inventory_search_field'),
                controller: _searchController,
                hintText: '${AppLocalizations.t(context, 'search')} ${AppLocalizations.t(context, 'items')}...',
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),

          // Category Filters
          Selector<InventoryProvider, List<String>>(
            selector: (_, p) => p.categories,
            builder: (context, categories, _) {
              if (categories.length <= 1) return const SliverToBoxAdapter(child: SizedBox.shrink());
              final selectedCategory = Provider.of<InventoryProvider>(context).selectedCategory;
              return SliverPadding(
                padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.md, bottom: AppSpacing.md),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      itemBuilder: (context, idx) {
                        final cat = categories[idx];
                        final isSelected = cat == selectedCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ChoiceChip(
                            label: Text(
                              cat,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : AppColors.textSecondary(context),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.adaptivePrimary(context),
                            backgroundColor: AppColors.surface(context),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.borderSm,
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.transparent
                                    : AppColors.textHint(context).withValues(alpha: 0.2),
                              ),
                            ),
                            onSelected: (val) {
                              if (val) {
                                Provider.of<InventoryProvider>(context, listen: false).setCategory(cat);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          Selector<InventoryProvider, bool>(
            selector: (_, p) => p.isLoading,
            builder: (context, isLoading, _) {
              if (isLoading) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            },
          ),

          Selector<InventoryProvider, List<InventoryEntity>>(
            selector: (_, p) => p.filteredItems,
            builder: (context, filteredItems, _) {
              final isLoading = Provider.of<InventoryProvider>(context, listen: false).isLoading;
              if (isLoading) return const SliverToBoxAdapter(child: SizedBox.shrink());

              if (filteredItems.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                );
              }

              if (isDesktop) {
                return SliverFillRemaining(
                  child: _buildTableView(context, filteredItems),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _buildInventoryCard(context, filteredItems[index]),
                    ),
                    childCount: filteredItems.length,
                  ),
                ),
              );
            },
          ),
          
          // Bottom spacing
          if (!isDesktop)
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const AppEmptyState(
      type: AppEmptyStateType.box,
    );
  }


  Widget _buildTableView(BuildContext context, List<InventoryEntity> items) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildDesktopInventoryCard(context, items[index]),
        );
      },
    );
  }

  Widget _buildDesktopInventoryCard(BuildContext context, InventoryEntity item) {
    final status = item.stockStatus;
    final color = status == StockStatus.outOfStock 
        ? AppColors.adaptiveError(context) 
        : (status == StockStatus.lowStock ? AppColors.adaptiveWarning(context) : AppColors.adaptiveSuccess(context));

    return AppCard(
      key: Key('inventory_item_desktop_${item.id}'),
      onTap: () {
        AddEditInventoryScreen.showAsDialog(context, item: InventoryMapper.toLegacy(item));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            // 1. Large Image Thumbnail
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: AppRadius.borderSm,
                border: Border.all(color: AppColors.border(context)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InventoryImageWidget(
                item: InventoryMapper.toLegacy(item),
                width: 64,
                height: 64,
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // 2. Info Column (Name & Category)
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.textPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${AppLocalizations.t(context, 'category')}: ${item.category}',
                    style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            // 3. Price Column
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.t(context, 'price').toUpperCase(),
                    style: TextStyle(
                      color: AppColors.textHint(context),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '₹${item.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.adaptiveSuccess(context),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            // 4. Stock Column
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.t(context, 'stock').toUpperCase(),
                    style: TextStyle(
                      color: AppColors.textHint(context),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${item.quantity} units',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            // 5. Status Badge Column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatusBadge(context, status.value, color),
              ],
            ),

            const SizedBox(width: AppSpacing.lg),

            // 6. Action Button (Chevron or Edit)
            Icon(
              Icons.edit_outlined,
              size: 20,
              color: AppColors.textSecondary(context),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
      ),
    );
  }

  void _showImportDialog(BuildContext context, DashboardProvider provider) {
    showDialog(
      context: context, 
      builder: (ctx) => const CentralItemSelectionDialog()
    );
  }

  Widget _buildInventoryCard(BuildContext context, InventoryEntity item) {
    final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
    final status = item.stockStatus;
    final color = status == StockStatus.outOfStock 
        ? AppColors.adaptiveError(context) 
        : (status == StockStatus.lowStock ? AppColors.adaptiveWarning(context) : AppColors.adaptiveSuccess(context));

    return AppCard(
      key: Key('inventory_item_${item.id}'),
      onTap: () {
        AddEditInventoryScreen.showAsDialog(context, item: InventoryMapper.toLegacy(item));
      },
      child: Row(
        children: [
          // Image
          InventoryImageWidget(item: InventoryMapper.toLegacy(item)),
          const SizedBox(width: AppSpacing.md),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${AppLocalizations.t(context, 'category')}: ${item.category}', 
                  style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary(context))
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Text(
                      '₹${item.price.toStringAsFixed(2)}', 
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold, 
                        color: AppColors.adaptiveSuccess(context)
                      )
                    ),
                    const Spacer(),
                    Builder(builder: (context) {
                      final trackInventory = dashboardProvider.activeStore?.trackInventory ?? true;

                      if (!trackInventory) {
                        return _buildStatusBadge(context, 'Available', AppColors.adaptiveSuccess(context));
                      }

                      return _buildStatusBadge(
                        context, 
                        status == StockStatus.inStock ? 'In Stock: ${item.quantity}' : status.value, 
                        color
                      );
                    }),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textHint(context)),
        ],
      ),
    );
  }


  Widget _buildStatusBadge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), 
        borderRadius: AppRadius.borderXs,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text.toUpperCase(), 
        style: AppTypography.labelSmall.copyWith(
          color: color, 
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        )
      ),
    );
  }
}




