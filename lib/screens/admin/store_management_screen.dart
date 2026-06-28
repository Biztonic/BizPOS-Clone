import 'package:flutter/material.dart';
import 'package:biztonic_pos/core/design/layouts/pos_scaffold.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:biztonic_pos/core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';
import 'package:biztonic_pos/core/design/tokens/app_typography.dart';
import 'package:biztonic_pos/core/design/tokens/app_radius.dart';
import 'package:biztonic_pos/core/design/tokens/app_shadows.dart';
import 'package:biztonic_pos/core/design/components/atoms/app_button.dart';
import 'package:biztonic_pos/core/design/components/atoms/app_card.dart';
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
  bool _isLoading = true;
  List<Store> _stores = [];

  @override
  void initState() {
    super.initState();
    // Load stores ONCE after the first frame, not in build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStores();
    });
  }

  Future<void> _loadStores() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    setState(() => _isLoading = true);
    try {
      await provider.fetchStores();
    } catch (e) {
      debugPrint("Error fetching stores: $e");
    }
    if (mounted) {
      setState(() {
        _stores = List.from(provider.stores);
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Store> get _filteredStores {
    final query = _searchController.text.toLowerCase();
    return _stores.where((s) {
      bool matchesSearch = s.name.toLowerCase().contains(query) ||
          s.owner.toLowerCase().contains(query);
      bool matchesStatus = _filterStatus == 'All' || s.status == _filterStatus;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return PosScaffold(
      title: 'Store Management',
      actions: [
        if (_selectedStoreIds.isNotEmpty)
          AppButton.danger(
            onPressed: _isBulkDeleting ? null : _confirmBulkDelete,
            icon: Icons.delete_sweep,
            label: "Delete (${_selectedStoreIds.length})",
            isLoading: _isBulkDeleting,
          )
        else
          AppButton.primary(
            onPressed: () => _showOnboardStoreDialog(context),
            icon: Icons.add,
            label: "Add New Store",
          ),
        const SizedBox(width: AppSpacing.md),
      ],
      mainContent: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats Row
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _buildStatsRow(),
                ),

                // Toolbar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _buildToolbar(context),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Store List
                Expanded(
                  child: _filteredStores.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.store_outlined, size: 64, color: AppColors.textHint(context)),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                AppLocalizations.t(context, 'No stores found'),
                                style: AppTypography.titleMedium.copyWith(color: AppColors.textSecondary(context)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          itemCount: _filteredStores.length,
                          itemBuilder: (context, index) => _buildStoreCard(_filteredStores[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: _filteredStores.isNotEmpty && _selectedStoreIds.length == _filteredStores.length,
          tristate: _selectedStoreIds.isNotEmpty && _selectedStoreIds.length < _filteredStores.length,
          onChanged: (val) {
            setState(() {
              if (val == true) {
                _selectedStoreIds.addAll(_filteredStores.map((s) => s.id));
              } else {
                _selectedStoreIds.clear();
              }
            });
          },
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: "Search by name or owner...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: AppRadius.borderSm),
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border(context)),
            borderRadius: AppRadius.borderSm,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filterStatus,
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All Status')),
                DropdownMenuItem(value: 'Active', child: Text('Active')),
                DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
              ],
              onChanged: (v) => setState(() => _filterStatus = v!),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _loadStores,
        ),
      ],
    );
  }

  Widget _buildStoreCard(Store store) {
    final isSelected = _selectedStoreIds.contains(store.id);
    final isDark = AppColors.isDark(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: isSelected
            ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.05)
            : AppColors.surface(context),
        borderRadius: AppRadius.borderSm,
        child: InkWell(
          borderRadius: AppRadius.borderSm,
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedStoreIds.remove(store.id);
              } else {
                _selectedStoreIds.add(store.id);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: AppRadius.borderSm,
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : AppColors.border(context),
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedStoreIds.add(store.id);
                      } else {
                        _selectedStoreIds.remove(store.id);
                      }
                    });
                  },
                ),
                const SizedBox(width: AppSpacing.md),
                // Store icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: const Icon(Icons.store_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                // Store info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(store.owner, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
                    ],
                  ),
                ),
                // Status badge
                _buildStatusBadge(store.status),
                const SizedBox(width: AppSpacing.md),
                // Actions
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () {},
                  tooltip: 'Edit Store',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                  onPressed: () => _confirmDelete(store),
                  tooltip: 'Delete Store',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final total = _stores.length;
    final active = _stores.where((s) => s.status == 'Active').length;
    final inactive = total - active;

    return Row(
      children: [
        Expanded(child: _buildStatCard("Total Stores", "$total", Icons.store_outlined, AppColors.primary)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildStatCard("Active", "$active", Icons.check_circle_outline, AppColors.success)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildStatCard("Inactive", "$inactive", Icons.pause_circle_outline, AppColors.warning)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: AppColors.border(context)),
        boxShadow: AppShadows.adaptive(context, light: AppShadows.sm),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.borderSm,
            ),
            child: Icon(icon, color: color, size: 22),
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

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Active':
        color = AppColors.success;
        break;
      case 'Inactive':
        color = AppColors.warning;
        break;
      default:
        color = AppColors.secondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.borderXs,
      ),
      child: Text(status, style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }

  void _confirmDelete(Store store) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Store'),
        content: Text("Are you sure you want to delete ${store.name}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          AppButton.danger(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<DashboardProvider>(context, listen: false);
              await provider.deleteStore(store.id);
              _loadStores();
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
        title: const Text('Bulk Delete'),
        content: Text("Delete ${_selectedStoreIds.length} selected stores?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          AppButton.danger(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isBulkDeleting = true);
              final provider = Provider.of<DashboardProvider>(context, listen: false);
              for (var id in _selectedStoreIds.toList()) {
                await provider.deleteStore(id);
              }
              _selectedStoreIds.clear();
              _loadStores();
              if (mounted) setState(() => _isBulkDeleting = false);
            },
            label: "Delete All",
          ),
        ],
      ),
    );
  }

  void _showOnboardStoreDialog(BuildContext context) {
    final nameController = TextEditingController();
    final ownerController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isSubmitting = false;
          return AlertDialog(
            title: const Text('Onboard New Store'),
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
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              AppButton.primary(
                isLoading: isSubmitting,
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (nameController.text.isEmpty || ownerController.text.isEmpty) return;
                        setDialogState(() => isSubmitting = true);
                        try {
                          final provider = Provider.of<DashboardProvider>(context, listen: false);
                          await provider.addStore(nameController.text, ownerController.text);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadStores();
                        } finally {
                          if (ctx.mounted) setDialogState(() => isSubmitting = false);
                        }
                      },
                label: "Create Store",
              ),
            ],
          );
        },
      ),
    );
  }
}
