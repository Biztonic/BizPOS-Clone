// ignore_for_file: dead_null_aware_expression, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/user_profile.dart';
import '../../models/store.dart';
import 'package:go_router/go_router.dart';
import '../../models/franchise.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/feature_guard.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/components/atoms/app_card.dart';

class StoreManagementScreen extends StatefulWidget {
  const StoreManagementScreen({super.key});

  @override
  State<StoreManagementScreen> createState() => _StoreManagementScreenState();
}

class _StoreManagementScreenState extends State<StoreManagementScreen> {
  final _searchController = TextEditingController();
  String _filterStatus = 'All';
  final Set<String> _selectedStoreIds = {};
  bool _isBulkDeleting = false;

  @override
  void initState() {
    super.initState();
    // Fetch all stores when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      provider.fetchStores();
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
            if (MediaQuery.of(context).size.width > 800) ...[
              _buildStatsRow(provider),
              const SizedBox(height: AppSpacing.xl),
            ],
            _buildMainContent(context, provider, displayedStores),
          ],
        ),
      ),
    );
  }

// Header and actions are handled by PosScaffold title and actions parameters


  void _confirmBulkDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Bulk Delete (${_selectedStoreIds.length} stores)"),
        content: const Text("Are you absolutely sure? This will permanently delete all selected stores and their data."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _performBulkDelete();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text("Yes, Delete All"),
          ),
        ],
      ),
    );
  }

  Future<void> _performBulkDelete() async {
    setState(() => _isBulkDeleting = true);
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    
    try {
      int count = 0;
      final idsToDelete = _selectedStoreIds.toList();
      for (final id in idsToDelete) {
        await provider.deleteStore(id);
        count++;
      }
      _selectedStoreIds.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Successfully deleted $count stores")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bulk Delete Error: $e"), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isBulkDeleting = false);
    }
  }

  // --- STATS ROW ---
  Widget _buildStatsRow(DashboardProvider provider) {
    int total = provider.stores.length;
    int active = provider.stores.where((s) => s.status == 'Active').length;

    return Row(
      children: [
        Expanded(child: _buildStatCard("Total Stores", "$total", Icons.store, AppColors.primary)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _buildStatCard("Active Stores", "$active", Icons.check_circle, AppColors.success)),
        const SizedBox(width: 24),

      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
            ],
          )
        ],
      ),
    );
  }

  // --- MAIN TABLE CONTENT ---
  Widget _buildMainContent(BuildContext context, DashboardProvider provider, List<Store> stores) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                // Bulk Select Checkbox
                Checkbox(
                  value: stores.isNotEmpty && _selectedStoreIds.length == stores.length,
                  tristate: _selectedStoreIds.isNotEmpty && _selectedStoreIds.length < stores.length,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedStoreIds.addAll(stores.map((s) => s.id));
                      } else {
                        _selectedStoreIds.clear();
                      }
                    });
                  },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: "Search by name or owner...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.sm)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filterStatus,
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text("All Status")),
                        DropdownMenuItem(value: 'Active', child: Text("Active")),
                        DropdownMenuItem(value: 'Inactive', child: Text("Inactive")),
                      ],
                      onChanged: (v) => setState(() => _filterStatus = v!),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),


           // Responsive Table / List
           stores.isEmpty 
             ? Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No stores found", style: TextStyle(color: AppColors.textSecondary(context)))))
             : ListView.separated(
                 shrinkWrap: true,
                 physics: const NeverScrollableScrollPhysics(),
                 itemCount: stores.length,
                 separatorBuilder: (_, __) => const Divider(height: 1),
                 itemBuilder: (context, index) {
                    final store = stores[index];
                    return _buildStoreRow(context, provider, store);
                 },
               ),
         ],
       ),
     );
  }

  Widget _buildStoreRow(BuildContext context, DashboardProvider provider, Store store) {
    bool isMobile = MediaQuery.of(context).size.width < 700;
    Franchise? franchise;
    try {
      if (store.franchiseId != null) franchise = provider.franchises.firstWhere((f) => f.id == store.franchiseId);
    } catch (_) { /* Error ignored */ }

    if (isMobile) {
      // Mobile - Compact List Tile
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Checkbox(
            value: _selectedStoreIds.contains(store.id),
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedStoreIds.add(store.id);
                } else {
                  _selectedStoreIds.remove(store.id);
                }
              });
            },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        title: Text(store.name, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             const SizedBox(height: 4),
             Text(store.owner),
             const SizedBox(height: 4),

          ],
        ),
        trailing: provider.userProfile?.role == 'Super Admin' && provider.isDeveloperMode
           ? Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 IconButton(
                    icon: Icon(Icons.login, size: 20, color: AppColors.primary),
                    onPressed: () => _handleAction(context, provider, store, 'manage'),
                 ),
                 IconButton(
                    icon: Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                    onPressed: () => _handleAction(context, provider, store, 'delete'),
                 ),
               ],
             )
           : null,
      );
    }

    // DESKTOP - Custom Row
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Checkbox(
            value: _selectedStoreIds.contains(store.id),
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedStoreIds.add(store.id);
                } else {
                  _selectedStoreIds.remove(store.id);
                }
              });
            },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Center(
                    child: Text(
                      store.name[0].toUpperCase(),
                      style: AppTypography.titleMedium.copyWith(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name, style: AppTypography.titleMedium),
                    const SizedBox(height: 2),
                    Text(store.storeType ?? 'Retail', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
                  ],
                )
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(franchise?.name ?? '—', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary(context)),
                const SizedBox(width: AppSpacing.xs),
                Text(store.owner, style: AppTypography.bodyMedium),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: _buildStatusBadge(context, provider, store),
          ),

          // Actions
          // Actions (Login/Delete)
          if (provider.userProfile?.role == 'Super Admin' && provider.isDeveloperMode)
             Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 IconButton(
                    icon: Icon(Icons.login, size: 20, color: AppColors.primary),
                    tooltip: "Manage Store",
                    onPressed: () => _handleAction(context, provider, store, 'manage'),
                 ),
                 IconButton(
                    icon: Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                    tooltip: "Delete Store",
                    onPressed: () => _handleAction(context, provider, store, 'delete'),
                 ),
               ],
             )
          else 
             const SizedBox(width: 48), // Spacer for alignment if not super admin
        ],
      ),
    );
  }

  // --- HELPERS (Copied & Styled) ---
  

  Widget _buildStatusBadge(BuildContext context, DashboardProvider provider, Store store) {
    String status = store.status;
    bool isActive = status.toLowerCase() == 'active';
    Color statusColor = isActive ? AppColors.success : AppColors.error;

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
          const SizedBox(width: AppSpacing.xs),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: AppTypography.labelSmall.copyWith(color: statusColor, fontWeight: FontWeight.w600),
          ),
          if (provider.userProfile?.role == 'Super Admin' && provider.isDeveloperMode) ...[
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 12, color: statusColor)
          ]
        ],
      ),
    );


    if (provider.userProfile?.role == 'Super Admin' && provider.isDeveloperMode) {
       return PopupMenuButton<String>(
         tooltip: "Change Status",
         offset: const Offset(0, 30),
         itemBuilder: (ctx) => [
            PopupMenuItem(value: 'Active', child: Row(children: [Icon(Icons.check_circle, size: 16, color: AppColors.success), const SizedBox(width: 8), const Text("Active")])),
            PopupMenuItem(value: 'Inactive', child: Row(children: [Icon(Icons.block, size: 16, color: AppColors.error), const SizedBox(width: 8), const Text("Inactive")])),
         ],
         onSelected: (newStatus) async {
            try {
               await provider.updateStoreStatus(store.id, newStatus);
            } catch (e) {
               if (e.toString().contains("LOCALLY")) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Status updated (Offline Mode)"), backgroundColor: AppColors.warning));
               } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error));
               }
            }
         },
         child: badge,
       );
    }
    return badge;
  }

  void _handleAction(BuildContext context, DashboardProvider provider, Store store, dynamic action) {
    if (action == 'delete') {
       _confirmDelete(context, provider, store);
    } else if (action == 'settings') {
       provider.setActiveStoreId(store.id);
       context.push('/settings');
    } else if (action == 'manage') {

       final uid = Provider.of<AuthProvider>(context, listen: false).user?.uid;

       if (uid != null) {
          // IMPORTANT: Wait for Firestore update to finish 
          // so that the next sync call has the correct permissions (accessibleStoreIds)
          _showLoadingOverlay(context);

          // For Super Admin, we don't strictly need to wait for the link to propagate if security rules are correct.
          // We can optimisticly switch.
          final isSuperAdmin = provider.activeRole == 'Super Admin';
          
          if (isSuperAdmin) {
              // Fire and Forget linking to ensure context is saved for next reload, but don't block UI
              provider.linkUserToStore(uid, store.id).catchError((e) { /* Error ignored */ });

              provider.setActiveStoreId(store.id);
              Navigator.pop(context); // Remove overlay
              context.go('/dashboard');
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Switched to ${store.name}")));
          } else {
              // For regular users, we MUST wait for permission propagation
              provider.linkUserToStore(uid, store.id).then((_) async {

                 await provider.setActiveStoreId(store.id);

                 if (context.mounted) Navigator.pop(context); // Remove overlay

                 if (context.mounted) context.go('/dashboard');
                 if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Switched to ${store.name}")));
              }).catchError((e) {

                 if (context.mounted) Navigator.pop(context);
                 if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error linking store: $e"), backgroundColor: AppColors.error));
              });
          }
       } else {
          // Fallback if no uid

          provider.setActiveStoreId(store.id);
          context.go('/dashboard');
       }
    }
  }

  void _showLoadingOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
  }

  // --- DIALOGS (Maintained functional logic) ---
  
  void _confirmDelete(BuildContext context, DashboardProvider provider, Store store) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Delete Store"),
      content: const Text("Are you sure? This is irreversible."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(onPressed: () async {
          try {
             await provider.deleteStore(store.id);
             Navigator.pop(ctx);
          } catch (e) {
             if (e.toString().contains("LOCALLY")) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Store deleted (Offline Mode)"), backgroundColor: AppColors.warning));
             } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error));
             }
          }
        }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: const Text("Delete")),
      ],
    ));
  }

  void _showOnboardStoreDialog(BuildContext context, DashboardProvider provider) {
     // Reusing basic dialog logic from previous iteration for brevity but updated style
    final nameCtrl = TextEditingController();
    String? selectedOwnerEmail;
    bool isSubmitting = false; // Local state for debounce
    
    // Future to fetch users
    final futureUsers = provider.fetchPotentialStoreOwners();
    
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           title: const Text("Add New Store"),
           content: SizedBox(
             width: 400, // wider for dropdown safety
             child: FutureBuilder<List<UserProfile>>(
               future: futureUsers,
               builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
                  }
                  
                  final users = snapshot.data ?? [];
                  final hasUsers = users.isNotEmpty;
                  
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                     TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Store Name", border: OutlineInputBorder())),
                     const SizedBox(height: 12),
                     
                     // OWNER SELECTION DROPDOWN
                     DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: "Assign Owner", 
                          border: OutlineInputBorder(),
                          helperText: "Select from unassigned users (excludes Super Admins)"
                        ),
                        value: selectedOwnerEmail,
                        hint: const Text("Select Owner Email"),
                        onChanged: hasUsers ? (v) => selectedOwnerEmail = v : null,
                        items: hasUsers 
                            ? users.map((u) => DropdownMenuItem(
                                 value: u.email, 
                                 child: Text("${u.email} (${u.name})", overflow: TextOverflow.ellipsis)
                              )).toList()
                            : [],
                        disabledHint: hasUsers ? null : const Text("No unassigned users found."),
                     ),
                     
                     if (!hasUsers) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                            const SizedBox(width: 4),
                            Expanded(child: Text("Invite a user first if they are not listed here.", style: TextStyle(color: AppColors.warning, fontSize: 12))),
                          ],
                        )
                     ],
     
                     const SizedBox(height: 12),
     
                  ]);
               }
             ),
           ),
           actions: [
             TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(ctx), child: const Text("Cancel")),
             ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                   if (nameCtrl.text.isEmpty || selectedOwnerEmail == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
                      return;
                   }
                   
                   setState(() => isSubmitting = true); // Lock button
     
                   try {
                      await provider.addStore(nameCtrl.text, selectedOwnerEmail!);
                      if (context.mounted) Navigator.pop(ctx);
                   } catch (e) {
                      setState(() => isSubmitting = false); // Unlock on error
                      if (context.mounted) {
                          if (e.toString().contains("LOCALLY")) {
                             Navigator.pop(ctx);
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Store created (Offline Mode)"), backgroundColor: AppColors.warning));
                          } else {
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error));
                          }
                      }
                   }
                },
                child: isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Create"),
             )
           ],
        );
      }
    ));
  }

}
