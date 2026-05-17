import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:biztonic_pos/core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';
import 'package:biztonic_pos/core/design/tokens/app_typography.dart';
import 'package:biztonic_pos/core/design/components/atoms/app_button.dart';
import 'package:biztonic_pos/core/design/components/atoms/app_card.dart';
import 'package:biztonic_pos/core/design/layouts/pos_scaffold.dart';
import 'package:biztonic_pos/core/design/components/organisms/pos_data_table.dart';
import 'package:biztonic_pos/widgets/feature_guard.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/store.dart';

class StoreManagementScreen extends StatefulWidget {
  const StoreManagementScreen({super.key});

  @override
  State<StoreManagementScreen> createState() => _StoreManagementScreenState();
}

class _StoreManagementScreenState extends State<StoreManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'All';
  final Set<String> _selectedStoreIds = {};
  bool _isBulkDeleting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);

    // Filter Logic
    List<Store> displayedStores = provider.stores.where((s) {
      bool matchesSearch = s.name.toLowerCase().contains(_searchController.text.toLowerCase()) || 
                           s.owner.toLowerCase().contains(_searchController.text.toLowerCase());
      bool matchesStatus = _filterStatus == 'All' || s.status == _filterStatus;
      return matchesSearch && matchesStatus;
    }).toList();

    return PosScaffold(
      title: 'Store Management',
      actions: [
        if (provider.activeRole == 'Super Admin' && provider.isDeveloperMode)
          FeatureGuard(
            featureKey: 'admin.roles',
            lockedChild: const SizedBox.shrink(),
            child: AppButton.secondary(
              onPressed: () => context.push('/roles'),
              icon: Icons.shield_outlined,
              label: "Roles",
            ),
          ),
        const SizedBox(width: AppSpacing.sm),
        if (_selectedStoreIds.isNotEmpty)
          AppButton.danger(
            onPressed: _isBulkDeleting ? null : _confirmBulkDelete,
            icon: Icons.delete_sweep,
            label: "Delete (${_selectedStoreIds.length})",
            isLoading: _isBulkDeleting,
          )
        else
          AppButton.primary(
            onPressed: () => _showOnboardStoreDialog(context, provider),
            icon: Icons.add,
            label: "Add New Store",
          ),
        const SizedBox(width: AppSpacing.md),
      ],
      mainContent: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsRow(provider),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toolbar
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        Checkbox(
                          value: displayedStores.isNotEmpty && _selectedStoreIds.length == displayedStores.length,
                          tristate: _selectedStoreIds.isNotEmpty && _selectedStoreIds.length < displayedStores.length,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedStoreIds.addAll(displayedStores.map((s) => s.id));
                              } else {
                                _selectedStoreIds.clear();
                              }
                            });
                          },
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: "Search by name or owner...",
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                              contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).dividerColor),
                            borderRadius: BorderRadius.zero,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _filterStatus,
                              items: [
                                DropdownMenuItem(value: 'All', child: Text(AppLocalizations.t(context, 'All Status'))),
                                DropdownMenuItem(value: 'Active', child: Text(AppLocalizations.t(context, 'Active'))),
                                DropdownMenuItem(value: 'Inactive', child: Text(AppLocalizations.t(context, 'Inactive'))),
                              ],
                              onChanged: (v) => setState(() => _filterStatus = v!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (displayedStores.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: Text(AppLocalizations.t(context, 'No stores found'))),
                    )
                  else
                    PosDataTable(
                      columns: const [
                        PosDataColumn(label: 'Store Name'),
                        PosDataColumn(label: 'Owner'),
                        PosDataColumn(label: 'Status', fixedWidth: 120),
                        PosDataColumn(label: 'Actions', fixedWidth: 120),
                      ],
                      rows: displayedStores.map((store) {
                      return PosDataRow(
                        selected: _selectedStoreIds.contains(store.id),
                        onTap: () {
                          setState(() {
                            if (_selectedStoreIds.contains(store.id)) {
                              _selectedStoreIds.remove(store.id);
                            } else {
                              _selectedStoreIds.add(store.id);
                            }
                          });
                        },
                        cells: [
                          Text(store.name, style: AppTypography.titleSmall),
                          Text(store.owner, style: AppTypography.bodyMedium),
                          _buildStatusBadge(context, provider, store),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _handleAction(context, provider, store, 'edit'),
                                tooltip: 'Edit Store',
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 20, color: AppColors.adaptiveError(context)),
                                onPressed: () => _confirmDelete(context, provider, store),
                                tooltip: 'Delete Store',
                              ),
                            ],
                          ),
                        ],
                      );
                    }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(DashboardProvider provider) {
    final total = provider.stores.length;
    final active = provider.stores.where((s) => s.status == 'Active').length;
    final inactive = total - active;

    return Row(
      children: [
        Expanded(child: _buildStatCard(context, "Total Stores", "$total", Icons.store_outlined, AppColors.adaptivePrimary(context))),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildStatCard(context, "Active", "$active", Icons.check_circle_outline, AppColors.adaptiveSuccess(context))),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildStatCard(context, "Inactive", "$inactive", Icons.pause_circle_outline, AppColors.adaptiveWarning(context))),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.zero,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary(context))),
              Text(value, style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, DashboardProvider provider, Store store) {
    final status = store.status;
    Color color;
    switch (status) {
      case 'Active':
        color = AppColors.adaptiveSuccess(context);
        break;
      case 'Inactive':
        color = AppColors.adaptiveWarning(context);
        break;
      default:
        color = AppColors.textSecondary(context);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        status,
        style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _handleAction(BuildContext context, DashboardProvider provider, Store store, String action) {
    if (action == 'edit') {
      // Implement edit logic or navigate
    }
  }

  void _confirmDelete(BuildContext context, DashboardProvider provider, Store store) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t(context, 'Delete Store')),
        content: Text("Are you sure you want to delete ${store.name}? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t(context, 'Cancel'))),
          AppButton.danger(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteStore(store.id);
            },
            label: "Delete",
          ),
        ],
      ),
    );
  }

  void _confirmBulkDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t(context, 'Bulk Delete')),
        content: Text("Are you sure you want to delete ${_selectedStoreIds.length} selected stores?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t(context, 'Cancel'))),
          AppButton.danger(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isBulkDeleting = true);
              final provider = Provider.of<DashboardProvider>(context, listen: false);
              for (var id in _selectedStoreIds) {
                await provider.deleteStore(id);
              }
              _selectedStoreIds.clear();
              if (mounted) setState(() => _isBulkDeleting = false);
            },
            label: "Delete All",
          ),
        ],
      ),
    );
  }

  void _showOnboardStoreDialog(BuildContext context, DashboardProvider provider) {
    final nameController = TextEditingController();
    final ownerController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(AppLocalizations.t(context, 'Onboard New Store')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Store Name", hintText: "e.g. Downtown POS"),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: ownerController,
                  decoration: const InputDecoration(labelText: "Owner Email", hintText: "owner@example.com"),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t(context, 'Cancel'))),
              AppButton.primary(
                isLoading: isSubmitting,
                onPressed: isSubmitting ? null : () async {
                  if (nameController.text.isEmpty || ownerController.text.isEmpty) return;
                  setDialogState(() => isSubmitting = true);
                  try {
                    await provider.addStore(nameController.text, ownerController.text);
                    if (context.mounted) Navigator.pop(ctx);
                  } finally {
                    if (context.mounted) setDialogState(() => isSubmitting = false);
                  }
                },
                label: "Create Store",
              ),
            ],
          );
        }
      ),
    );
  }
}


