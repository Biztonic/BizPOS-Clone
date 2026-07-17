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
  String _activeTab = 'Stores';

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
        if (_activeTab == 'Stores') ...[
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
        ],
        const SizedBox(width: AppSpacing.md),
      ],
      mainContent: Column(
        children: [
          // Tab Selection Segment
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Active Stores'),
                  selected: _activeTab == 'Stores',
                  onSelected: (val) {
                    if (val) setState(() => _activeTab = 'Stores');
                  },
                ),
                const SizedBox(width: AppSpacing.sm),
                ChoiceChip(
                  label: const Text('Configure Store Types'),
                  selected: _activeTab == 'Store Types',
                  onSelected: (val) {
                    if (val) setState(() => _activeTab = 'Store Types');
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _activeTab == 'Store Types'
                ? _buildStoreTypesView()
                : (_isLoading
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
                      )),
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
    final dashboard = Provider.of<DashboardProvider>(context, listen: false);
    final List<String> availableStoreTypes = dashboard.storeTypeConfigs.keys.isNotEmpty 
        ? dashboard.storeTypeConfigs.keys.toList() 
        : ['Restaurant', 'Grocery', 'Supermarket', 'Retail'];
    String selectedStoreType = availableStoreTypes.contains('Restaurant') 
        ? 'Restaurant' 
        : availableStoreTypes.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isSubmitting = false;
          return AlertDialog(
            title: const Text('Onboard New Store'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: selectedStoreType,
                  decoration: const InputDecoration(labelText: "Store Type"),
                  items: availableStoreTypes.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedStoreType = val;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              AppButton.primary(
                isLoading: isSubmitting,
                onPressed: () async {
                  if (nameController.text.isEmpty || ownerController.text.isEmpty) return;
                  setDialogState(() => isSubmitting = true);
                  try {
                    final provider = Provider.of<DashboardProvider>(context, listen: false);
                    await provider.addStore(nameController.text, ownerController.text, storeType: selectedStoreType);
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

  Widget _buildStoreTypesView() {
    final dashboard = Provider.of<DashboardProvider>(context);
    final configs = dashboard.storeTypeConfigs;

    final List<String> types = configs.keys.isNotEmpty 
        ? configs.keys.toList() 
        : ['Restaurant', 'Grocery', 'Supermarket', 'Retail'];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Define Store Types & Features',
                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              AppButton.primary(
                icon: Icons.add,
                label: 'Create Custom Store Type',
                onPressed: () => _showAddStoreTypeDialog(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: types.isEmpty
              ? const Center(child: Text('No store types defined.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: types.length,
                  itemBuilder: (context, index) {
                    final type = types[index];
                    final Map<String, dynamic> config = configs[type] is Map 
                        ? Map<String, dynamic>.from(configs[type]) 
                        : _getDefaultConfigFor(type);

                    return AppCard(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getIconForType(type),
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      type,
                                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                if (!['Restaurant', 'Grocery', 'Supermarket', 'Retail'].contains(type))
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => _confirmDeleteStoreType(type),
                                    tooltip: 'Delete Custom Store Type',
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const Divider(),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Feature Access Permissions',
                              style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary(context)),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.md,
                              runSpacing: AppSpacing.sm,
                              children: [
                                _buildFeatureSwitch(type, config, 'table_reservation', 'Table Management (Floor Plans)'),
                                _buildFeatureSwitch(type, config, 'barcode_scanner', 'Barcode Scanner & Scales'),
                                _buildFeatureSwitch(type, config, 'kds_management', 'Kitchen Display System (KDS)'),
                                _buildFeatureSwitch(type, config, 'customer_management', 'CRM & Customer Management'),
                                _buildFeatureSwitch(type, config, 'employee_management', 'Employee Roles & Staff Shift'),
                                _buildFeatureSwitch(type, config, 'supplier_management', 'Supplier Ledger & Orders'),
                                _buildFeatureSwitch(type, config, 'data_center', 'Offline Data Center Sync'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getDefaultConfigFor(String type) {
    if (type == 'Restaurant') {
      return {
        'table_reservation': true,
        'kds_management': true,
        'employee_management': true,
        'barcode_scanner': false,
        'customer_management': false,
        'supplier_management': false,
        'data_center': false,
      };
    }
    if (type == 'Grocery' || type == 'Supermarket') {
      return {
        'barcode_scanner': true,
        'customer_management': true,
        'supplier_management': true,
        'data_center': true,
        'table_reservation': false,
        'kds_management': false,
        'employee_management': false,
      };
    }
    return {
      'barcode_scanner': true,
      'customer_management': true,
      'employee_management': true,
      'table_reservation': false,
      'kds_management': false,
      'supplier_management': false,
      'data_center': false,
    };
  }

  IconData _getIconForType(String type) {
    if (type.contains('Restaurant') || type.contains('Cafe')) return Icons.restaurant;
    if (type.contains('Grocery') || type.contains('Supermarket')) return Icons.local_grocery_store;
    if (type.contains('Automotive')) return Icons.directions_car;
    return Icons.storefront;
  }

  Widget _buildFeatureSwitch(String type, Map<String, dynamic> config, String key, String label) {
    final isEnabled = config[key] == true;
    return SizedBox(
      width: 280,
      child: CheckboxListTile(
        title: Text(label, style: const TextStyle(fontSize: 13)),
        value: isEnabled,
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (val) {
          if (val != null) {
            final updated = Map<String, dynamic>.from(config);
            updated[key] = val;
            Provider.of<DashboardProvider>(context, listen: false).saveStoreTypeConfig(type, updated);
          }
        },
      ),
    );
  }

  void _showAddStoreTypeDialog(BuildContext context) {
    final typeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Store Type'),
        content: TextField(
          controller: typeController,
          decoration: const InputDecoration(
            labelText: 'Store Type Name',
            hintText: 'e.g. Pharmacy, Fashion Boutique',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          AppButton.primary(
            onPressed: () {
              final type = typeController.text.trim();
              if (type.isNotEmpty) {
                final initial = {
                  'table_reservation': false,
                  'barcode_scanner': true,
                  'kds_management': false,
                  'customer_management': true,
                  'employee_management': true,
                  'supplier_management': false,
                  'data_center': false,
                };
                Provider.of<DashboardProvider>(context, listen: false).saveStoreTypeConfig(type, initial);
                Navigator.pop(ctx);
              }
            },
            label: 'Add Type',
          ),
        ],
      ),
    );
  }

  void _confirmDeleteStoreType(String type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Store Type'),
        content: Text('Are you sure you want to delete the store type "$type"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          AppButton.danger(
            onPressed: () {
              Provider.of<DashboardProvider>(context, listen: false).deleteStoreTypeConfig(type);
              Navigator.pop(ctx);
            },
            label: 'Delete',
          ),
        ],
      ),
    );
  }
}
