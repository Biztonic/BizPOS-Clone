// ignore_for_file: dead_null_aware_expression, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/user_profile.dart'; // NEW
import '../../models/store.dart';
import 'package:go_router/go_router.dart';
import '../../models/franchise.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/feature_guard.dart';

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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER SECTION
             _buildModernHeader(context, provider),
             const SizedBox(height: 32),

            // STATS ROW (Premium Feature)
            if (MediaQuery.of(context).size.width > 800)
              _buildStatsRow(provider),
            
            const SizedBox(height: 32),

            // MAIN CONTENT TABLE
            _buildMainContent(context, provider, displayedStores),
          ],
        ),
      ),
    );
  }

  // --- TOP HEADER ---
  Widget _buildModernHeader(BuildContext context, DashboardProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             IconButton(
               onPressed: () => Navigator.pop(context),
               icon: const Icon(Icons.arrow_back),
               tooltip: 'Back to Dashboard',
             ),
             const SizedBox(width: 8),
             Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text('Store Management', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Theme.of(context).textTheme.bodyLarge?.color)),
                 const SizedBox(height: 8),
                 Text('Overview of all client stores and performance.', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey[600], fontSize: 15)),
               ],
             ),
           ],
        ),
        // Primary Actions
        Row(
          children: [
             if (provider.activeRole == 'Super Admin' && provider.isDeveloperMode)
               FeatureGuard(
                 featureKey: 'admin.roles',
                 lockedChild: const SizedBox.shrink(),
                 child: OutlinedButton.icon(
                    onPressed: () => context.push('/roles'),
                    icon: const Icon(Icons.shield_outlined, size: 18),
                    label: const Text("Roles"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[700]! : Colors.grey.shade300),
                      foregroundColor: Theme.of(context).textTheme.bodyLarge?.color
                    ),
                 ),
               ),
             const SizedBox(width: 12),
             if (_selectedStoreIds.isNotEmpty)
               ElevatedButton.icon(
                  onPressed: _isBulkDeleting ? null : _confirmBulkDelete,
                  icon: _isBulkDeleting 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.delete_sweep, size: 20),
                  label: Text("Delete (${_selectedStoreIds.length})"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
               )
             else
               ElevatedButton.icon(
                  onPressed: () => _showOnboardStoreDialog(context, provider),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text("Add New Store"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB), // Premium Blue
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
               ),
          ],
        )
      ],
    );
  }

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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bulk Delete Error: $e"), backgroundColor: Colors.red));
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
        Expanded(child: _buildStatCard("Total Stores", "$total", Icons.store, Colors.blue)),
        const SizedBox(width: 24),
        Expanded(child: _buildStatCard("Active Stores", "$active", Icons.check_circle, Colors.green)),
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
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
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
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final cardColor = Theme.of(context).cardTheme.color ?? (isDark ? const Color(0xFF1E1E1E) : Colors.white);
      final borderColor = isDark ? Colors.grey[800]! : Colors.grey.shade300;
      final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

      return Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.03), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Column(
          children: [
            // Toolbar
            Padding(
              padding: const EdgeInsets.all(20),
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
                   const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState((){}),
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: "Search by name or owner...",
                        hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
                        prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[500] : Colors.grey),
                        filled: isDark,
                        fillColor: isDark ? Colors.grey[900] : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      ),
                    ),
                  ),
                 const SizedBox(width: 16),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
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
             ? const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No stores found", style: TextStyle(color: Colors.grey))))
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
                    icon: const Icon(Icons.login, size: 20, color: Colors.blue),
                    onPressed: () => _handleAction(context, provider, store, 'manage'),
                 ),
                 IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    onPressed: () => _handleAction(context, provider, store, 'delete'),
                 ),
               ],
             )
           : null,
      );
    }

    // DESKTOP - Custom Row
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
    children: [
      // Multi-select Checkbox
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
      const SizedBox(width: 8),
      // Store Info
      Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text(store.name[0].toUpperCase(), style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).textTheme.bodyLarge?.color)),
                    const SizedBox(height: 2),
                    Text(store.storeType ?? 'Retail', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                )
              ],
            ),
          ),
          
          // Franchise
          Expanded(flex: 2, child: Text(franchise?.name ?? '—', style: const TextStyle(color: Colors.grey))),
          
          // Owner
          Expanded(flex: 2, child: Row(children: [
             const Icon(Icons.person_outline, size: 16, color: Colors.grey),
             const SizedBox(width: 8),
             Text(store.owner, style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).textTheme.bodyLarge?.color)),
          ])),
          
          // Plan

          
          // Status
          Expanded(flex: 1, child: _buildStatusBadge(context, provider, store)),

          // Actions
          // Actions (Login/Delete)
          if (provider.userProfile?.role == 'Super Admin' && provider.isDeveloperMode)
             Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 IconButton(
                    icon: const Icon(Icons.login, size: 20, color: Colors.blue),
                    tooltip: "Manage Store",
                    onPressed: () => _handleAction(context, provider, store, 'manage'),
                 ),
                 IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
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
    
    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: isActive ? Colors.green : Colors.red, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(isActive ? 'Active' : 'Inactive', style: TextStyle(color: isActive ? Colors.green : Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
          if (provider.userProfile?.role == 'Super Admin' && provider.isDeveloperMode) ...[
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: 12, color: isActive ? Colors.green : Colors.red)
           ]
        ],
      ),
    );

    if (provider.userProfile?.role == 'Super Admin' && provider.isDeveloperMode) {
       return PopupMenuButton<String>(
         tooltip: "Change Status",
         offset: const Offset(0, 30),
         itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'Active', child: Row(children: [Icon(Icons.check_circle, size: 16, color: Colors.green), SizedBox(width: 8), Text("Active")])),
            const PopupMenuItem(value: 'Inactive', child: Row(children: [Icon(Icons.block, size: 16, color: Colors.red), SizedBox(width: 8), Text("Inactive")])),
         ],
         onSelected: (newStatus) async {
            try {
               await provider.updateStoreStatus(store.id, newStatus);
            } catch (e) {
               if (e.toString().contains("LOCALLY")) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Status updated (Offline Mode)"), backgroundColor: Colors.orange));
               } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
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
                 if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error linking store: $e"), backgroundColor: Colors.red));
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Store deleted (Offline Mode)"), backgroundColor: Colors.orange));
             } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
             }
          }
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Delete")),
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
                            const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                            const SizedBox(width: 4),
                            Expanded(child: Text("Invite a user first if they are not listed here.", style: TextStyle(color: Colors.orange.shade800, fontSize: 12))),
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
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Store created (Offline Mode)"), backgroundColor: Colors.orange));
                          } else {
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
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
