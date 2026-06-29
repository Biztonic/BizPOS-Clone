import '../../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/store.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';

class FranchiseScreen extends StatefulWidget {
  const FranchiseScreen({super.key});

  @override
  State<FranchiseScreen> createState() => _FranchiseScreenState();
}

class _FranchiseScreenState extends State<FranchiseScreen> {
  final _searchController = TextEditingController();
  String _selectedOwner = 'All Owners';
  String _selectedStatus = 'All Statuses';
  int _currentPage = 1;
  static const int _pageSize = 5;

  Map<String, Map<String, dynamic>> _storeStats = {};
  bool _isLoadingStats = false;
  List<Store>? _previousStores;

  bool _areListsEqual(List<Store> a, List<Store> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  Future<void> _loadStoresStats(List<Store> stores) async {
    if (_isLoadingStats) return;
    setState(() => _isLoadingStats = true);
    
    try {
      final db = FirebaseFirestore.instance;
      final Map<String, Map<String, dynamic>> newStats = {};
      
      for (var store in stores) {
        final ordersQuery = await db.collection('stores')
            .doc(store.id)
            .collection('orders')
            .get();
            
        double totalSales = 0.0;
        int totalOrders = ordersQuery.docs.length;
        
        for (var doc in ordersQuery.docs) {
          final data = doc.data();
          final total = (data['total'] ?? data['grandTotal'] ?? data['amount'] ?? 0.0) as num;
          totalSales += total.toDouble();
        }
        
        newStats[store.id] = {
          'sales': totalSales,
          'orders': totalOrders,
        };
      }
      
      if (mounted) {
        setState(() {
          _storeStats = newStats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading franchise stores stats: $e');
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final isFranchiseOwner = provider.activeRole == 'Franchise Owner';

    return PosScaffold(
      title: isFranchiseOwner ? 'Franchise Performance Dashboard' : 'Franchise Management',
      mainContent: isFranchiseOwner 
          ? _buildFranchiseOwnerContent(context, provider) 
          : _buildSuperAdminViewContent(context),
    );
  }

  Widget _buildFranchiseOwnerContent(BuildContext context, DashboardProvider provider) {
    final uid = provider.userProfile?.uid;
    final franchiseId = provider.userProfile?.franchiseId ?? uid;

    final stores = provider.stores.where((s) => s.franchiseId == franchiseId).toList();

    // Trigger stats load if stores list changed
    if (_previousStores == null || !_areListsEqual(_previousStores!, stores)) {
      _previousStores = stores;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadStoresStats(stores);
      });
    }

    // Filtered list
    final filteredStores = stores.where((s) {
      final nameMatch = s.name.toLowerCase().contains(_searchController.text.toLowerCase());
      final ownerMatch = _selectedOwner == 'All Owners' || (s.ownerEmail == _selectedOwner || s.owner == _selectedOwner);
      final statusMatch = _selectedStatus == 'All Statuses' || s.status == _selectedStatus;
      return nameMatch && ownerMatch && statusMatch;
    }).toList();

    int activeStores = stores.where((s) => s.status == 'Active').length;

    // Calculate aggregated sales & orders from real loaded stats
    double aggregatedSales = 0.0;
    int aggregatedOrders = 0;
    
    for (var store in stores) {
      if (_storeStats.containsKey(store.id)) {
        aggregatedSales += (_storeStats[store.id]?['sales'] ?? 0.0) as double;
        aggregatedOrders += (_storeStats[store.id]?['orders'] ?? 0) as int;
      }
    }

    final totalPages = (filteredStores.length / _pageSize).ceil();
    final paginatedStores = filteredStores.skip((_currentPage - 1) * _pageSize).take(_pageSize).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: const Icon(Icons.business_outlined, color: AppColors.primaryLight),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.t(context, 'Franchise Overview'), style: AppTypography.headlineSmall),
                          if (provider.userProfile?.franchiseCode != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            SelectableText(
                              'Franchise Code: ${provider.userProfile!.franchiseCode}',
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    AppButton.primary(
                      label: 'Link Existing Store',
                      icon: Icons.add,
                      onPressed: () => _showAddExistingStoreDialog(context, provider),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(AppLocalizations.t(context, 'Overview of performance for all stores under your franchise.'),
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Stats Cards
          LayoutBuilder(builder: (context, constraints) {
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                _buildStatCard('Total Stores', stores.length.toString(), Icons.store_outlined, AppColors.primary, constraints.maxWidth),
                _buildStatCard('Active Stores', activeStores.toString(), Icons.check_circle_outline, AppColors.success, constraints.maxWidth),
                _buildStatCard('Total Sales (Est)', '₹${aggregatedSales.toStringAsFixed(2)}', Icons.payments_outlined, AppColors.warning, constraints.maxWidth),
                _buildStatCard('Total Orders (Est)', aggregatedOrders.toString(), Icons.receipt_long_outlined, AppColors.primary, constraints.maxWidth),
              ],
            );
          }),

          const SizedBox(height: AppSpacing.xl),

          // Store Performance Section
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.t(context, 'Store Performance'), style: AppTypography.titleLarge),
                const SizedBox(height: AppSpacing.lg),

                // Filters
                LayoutBuilder(builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 800;

                  // Get unique owner emails/IDs from the franchise stores
                  final Set<String> uniqueOwners = {'All Owners'};
                  for (var s in stores) {
                    if (s.ownerEmail != null) uniqueOwners.add(s.ownerEmail!);
                    else uniqueOwners.add(s.owner);
                  }

                  final filterContent = [
                    Expanded(
                      flex: isNarrow ? 0 : 2,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) {
                          setState(() {
                            _currentPage = 1;
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Filter by Store Name...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                          contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        ),
                      ),
                    ),
                    if (!isNarrow) const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: isNarrow ? 0 : 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(border: Border.all(color: AppColors.textSecondary(context)), borderRadius: BorderRadius.zero),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedOwner,
                            isExpanded: true,
                            hint: const Text('Filter by Owner...'),
                            items: uniqueOwners.map((owner) {
                              return DropdownMenuItem(value: owner, child: Text(owner, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedOwner = val;
                                  _currentPage = 1;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    if (!isNarrow) const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: isNarrow ? 0 : 1,
                      child: TextField(
                        enabled: false,
                        decoration: InputDecoration(
                          hintText: provider.franchises.isNotEmpty ? provider.franchises.first.name : 'Your Franchise',
                          filled: true,
                          fillColor: Theme.of(context).disabledColor.withValues(alpha: 0.05),
                          border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        ),
                      ),
                    ),
                    if (!isNarrow) const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: isNarrow ? 0 : 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(border: Border.all(color: AppColors.textSecondary(context)), borderRadius: BorderRadius.zero),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedStatus,
                            isExpanded: true,
                            hint: const Text('All Statuses'),
                            items: const [
                              DropdownMenuItem(value: 'All Statuses', child: Text('All Statuses', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'Active', child: Text('Active', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'Inactive', child: Text('Inactive', style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedStatus = val;
                                  _currentPage = 1;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ];

                  if (isNarrow) {
                    return Column(
                      children: filterContent.map((w) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.md), child: SizedBox(width: double.infinity, child: w))).toList(),
                    );
                  }
                  return Row(children: filterContent);
                }),

                const SizedBox(height: AppSpacing.lg),

                // Table
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 800),
                    child: DataTable(
                      headingTextStyle: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary(context)),
                      dataTextStyle: AppTypography.bodyMedium,
                      columns: [
                        DataColumn(label: Text(AppLocalizations.t(context, 'Store Name'))),
                        DataColumn(label: Text(AppLocalizations.t(context, 'Owner'))),
                        DataColumn(label: Text(AppLocalizations.t(context, 'Franchise'))),
                        DataColumn(label: Text(AppLocalizations.t(context, 'Total Sales'))),
                        DataColumn(label: Text(AppLocalizations.t(context, 'Total Orders'))),
                        DataColumn(label: Text(AppLocalizations.t(context, 'Status'))),
                      ],
                      rows: paginatedStores.isEmpty
                          ? [
                              DataRow(cells: [
                                DataCell(Text(AppLocalizations.t(context, 'No stores found matching your criteria.'), style: TextStyle(color: AppColors.textSecondary(context)))),
                                const DataCell(SizedBox()),
                                const DataCell(SizedBox()),
                                const DataCell(SizedBox()),
                                const DataCell(SizedBox()),
                                const DataCell(SizedBox()),
                              ])
                            ]
                          : paginatedStores.map((store) {
                              final double storeSales = (_storeStats[store.id]?['sales'] ?? 0.0) as double;
                              final int storeOrders = (_storeStats[store.id]?['orders'] ?? 0) as int;

                              return DataRow(cells: [
                                DataCell(Text(store.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text(store.ownerEmail ?? store.owner)),
                                DataCell(Text(store.franchiseName ?? '-')),
                                DataCell(Text('₹${storeSales.toStringAsFixed(2)}')),
                                DataCell(Text(storeOrders.toString())),
                                DataCell(_buildStatusBadge(store.status)),
                              ]);
                            }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton.secondary(
                      onPressed: _currentPage > 1 
                          ? () => setState(() => _currentPage--) 
                          : null, 
                      label: 'Previous',
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(AppLocalizations.t(context, 'Page $_currentPage of ${totalPages == 0 ? 1 : totalPages}'), style: AppTypography.bodySmall),
                    const SizedBox(width: AppSpacing.md),
                    AppButton.secondary(
                      onPressed: _currentPage < totalPages 
                          ? () => setState(() => _currentPage++) 
                          : null, 
                      label: 'Next',
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, double maxWidth) {
    double width = (maxWidth - (AppSpacing.lg * 2) - (AppSpacing.md * 3)) / 4;
    if (width < 160) width = (maxWidth - (AppSpacing.lg * 2) - AppSpacing.md) / 2;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        width: width - (AppSpacing.lg * 2), // Adjust for card padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary(context)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: AppTypography.headlineSmall),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMockDropdown(String hint) {
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 12),
       decoration: BoxDecoration(border: Border.all(color: AppColors.textSecondary(context)), borderRadius: BorderRadius.zero),
       child: DropdownButtonHideUnderline(
         child: DropdownButton<String>(
           hint: Text(hint, style: const TextStyle(fontSize: 14)),
           items: const [],
           onChanged: null,
         ),
       ),
     );
  }

  Widget _buildStatusBadge(String status) {
    bool isActive = status == 'Active';
    Color color = isActive ? AppColors.success : AppColors.textSecondary(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: AppSpacing.xs),
          Text(
            status,
            style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSuperAdminViewContent(BuildContext context) {
    return Center(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined, size: 64, color: Theme.of(context).disabledColor),
            const SizedBox(height: AppSpacing.lg),
            Text(AppLocalizations.t(context, 'Manage Franchises'), style: AppTypography.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(AppLocalizations.t(context, 'Feature Coming Soon'), style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
            const SizedBox(height: AppSpacing.xl),
            AppButton.primary(
              onPressed: () {},
              label: 'Add Franchise',
              icon: Icons.add,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExistingStoreDialog(BuildContext context, DashboardProvider provider) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Existing Store'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter the credentials of the existing store owner to link it under your franchise.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Store Owner Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Please enter email' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Store Owner Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Please enter password' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() => isSubmitting = true);
                          try {
                            await provider.addExistingStoreToFranchise(
                              email: emailController.text.trim(),
                              password: passwordController.text,
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Store successfully linked to your franchise!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error linking store: ${e.toString()}'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() => isSubmitting = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.surfaceLight,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Link Store'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}


