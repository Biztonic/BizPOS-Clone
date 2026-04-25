// ignore_for_file: use_build_context_synchronously, unused_local_variable
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:biztonic_pos/providers/store_provider.dart';
import '../../models/role_model.dart';

class ManageRolesScreen extends StatefulWidget {
  final bool embed;
  const ManageRolesScreen({super.key, this.embed = false});

  @override
  State<ManageRolesScreen> createState() => _ManageRolesScreenState();
}

class _ManageRolesScreenState extends State<ManageRolesScreen> {
  final _searchController = TextEditingController();
  String _filterType = 'All'; // All, System, Custom
  final Set<String> _selectedRoleIds = {};

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedRoleIds.contains(id)) {
        _selectedRoleIds.remove(id);
      } else {
        _selectedRoleIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<RoleModel> roles) {
    final selectableRoles = roles.where((r) => r.id != 'super_admin' && r.name != 'Store Owner').map((r) => r.id).toSet();
    setState(() {
      if (_selectedRoleIds.containsAll(selectableRoles) && selectableRoles.isNotEmpty) {
        _selectedRoleIds.clear();
      } else {
        _selectedRoleIds.addAll(selectableRoles);
      }
    });
  }

  Future<void> _deleteSelectedRoles() async {
    final provider = Provider.of<StoreProvider>(context, listen: false);
    final rolesToDelete = _selectedRoleIds.where((id) {
      final role = provider.roles.firstWhere((r) => r.id == id, orElse: () => RoleModel(id: '', name: '', permissions: {}));
      return role.id != 'super_admin' && role.name != 'Store Owner';
    }).toList();

    if (rolesToDelete.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Selected Roles"),
        content: Text("Are you sure you want to delete ${rolesToDelete.length} roles? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (final id in rolesToDelete) {
         await provider.deleteRole(id);
      }
      setState(() {
        _selectedRoleIds.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${rolesToDelete.length} roles deleted successfully"))
        );
      }
    }
  }
  
  @override
  void initState() {
    super.initState();
    // Ensure roles are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StoreProvider>(context, listen: false).fetchRoles();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showRoleDialog({RoleModel? role}) {
    final isEditing = role != null;
    final nameController = TextEditingController(text: role?.name ?? '');
    
    // Default Permissions
    Map<String, bool> permissions = {
      'pos': false,
      'inventory': false,
      'inventory_view': false,
      'reports': false,
      'settings': false,
      'admin': false,
    };

    if (isEditing) {
      permissions.addAll(role.permissions);
    }
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? 'Edit Role' : 'New Role'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Role Name'),
                ),
                const SizedBox(height: 16),
                // Permissions UI removed as requested
                /*
                const Text('Permissions', style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                ...permissions.keys.map((key) {
                  return CheckboxListTile(
                    title: Text(key.toUpperCase().replaceAll('_', ' ')),
                    value: permissions[key],
                    dense: true,
                    onChanged: (val) {
                      setState(() => permissions[key] = val ?? false);
                    },
                  );
                }),
                */
              ],
            ),
          ),
          actions: [
            if (isEditing && role.id != 'super_admin' && role.name != 'Store Owner')
              TextButton(
                onPressed: () async {
                  final confirm = await showDialog(
                    context: context, 
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Role?'),
                      content: const Text('This action cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                      ],
                    )
                  );
                  if (confirm == true) {
                     final provider = Provider.of<StoreProvider>(context, listen: false);
                     await provider.deleteRole(role.id);
                     if (mounted) Navigator.pop(ctx); // Close Edit Dialog
                  }
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                final provider = Provider.of<StoreProvider>(context, listen: false);
                try {
                  final newRole = RoleModel(
                    id: isEditing ? role.id : '', 
                    name: nameController.text.trim(),
                    permissions: permissions,
                    isSystem: isEditing ? role.isSystem : false
                  );

                  if (isEditing) {
                    // Maintain existing permissions when editing if UI is removed
                    await provider.updateRole(newRole);
                  } else {
                    // Default permissions for new roles
                    await provider.addRole(newRole);
                  }
                  if (mounted) Navigator.pop(ctx);
                } catch (e) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(isEditing ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width < 600 ? 16 : 24, 
          vertical: MediaQuery.of(context).size.width < 600 ? 16 : 32
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER SECTION (Match Store Management)
            _buildModernHeader(context),
            const SizedBox(height: 32),

            // STATS ROW (Match Store Management)
            if (MediaQuery.of(context).size.width > 800)
              _buildStatsRow(),
            
            const SizedBox(height: 32),

            // MAIN CONTENT TABLE (Match Store Management)
            _buildMainContent(context),
          ],
        ),
      ),
    );
  }

  // --- TOP HEADER (Identical to Store Management) ---
  Widget _buildModernHeader(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    
    return isMobile ? Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Text('Manage Roles', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Theme.of(context).textTheme.bodyLarge?.color)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text('Define and manage user roles and permissions.', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey[600], fontSize: 14)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showRoleDialog(),
            icon: const Icon(Icons.add, size: 20),
            label: const Text("Add New Role"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB), 
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    ) : Row(
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
                 Text('Manage Roles', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Theme.of(context).textTheme.bodyLarge?.color)),
                 const SizedBox(height: 8),
                 Text('Define and manage user roles and permissions.', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey[600], fontSize: 15)),
               ],
             ),
           ],
        ),
        // Primary Actions
        ElevatedButton.icon(
           onPressed: () => _showRoleDialog(),
           icon: const Icon(Icons.add, size: 20),
           label: const Text("Add New Role"),
           style: ElevatedButton.styleFrom(
             backgroundColor: const Color(0xFF2563EB), // Premium Blue
             foregroundColor: Colors.white,
             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
             elevation: 2,
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
           ),
        ),
      ],
    );
  }

  // --- STATS ROW (Identical to Store Management) ---
  Widget _buildStatsRow() {
    return Consumer<StoreProvider>(
      builder: (context, provider, child) {
        final roles = provider.roles;
        int total = roles.length;
        int system = roles.where((r) => r.isSystem).length;
        int custom = roles.where((r) => !r.isSystem).length;

        return Row(
          children: [
            Expanded(child: _buildStatCard("Total Roles", "$total", Icons.shield, Colors.blue)),
            const SizedBox(width: 24),
            Expanded(child: _buildStatCard("System Roles", "$system", Icons.lock, Colors.orange)),
            const SizedBox(width: 24),
            Expanded(child: _buildStatCard("Custom Roles", "$custom", Icons.person_outline, Colors.green)),
          ],
        );
      },
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

  // --- MAIN TABLE CONTENT (Identical to Store Management) ---
  Widget _buildMainContent(BuildContext context) {
     return Consumer<StoreProvider>(
       builder: (context, provider, child) {
         final roles = provider.roles;
         final currentUserRole = provider.activeRole;
         
         // Filter Logic
         List<RoleModel> displayedRoles = roles.where((r) {
            bool matchesSearch = r.name.toLowerCase().contains(_searchController.text.toLowerCase());
            bool matchesType = _filterType == 'All' || 
                               (_filterType == 'System' && r.isSystem) ||
                               (_filterType == 'Custom' && !r.isSystem);
            
             return matchesSearch && matchesType;
         }).toList();

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
                // Toolbar (Match Store Management)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      bool isToolbarCompact = constraints.maxWidth < 500;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectedRoleIds.isNotEmpty) ...[
                            SizedBox(
                              width: isToolbarCompact ? double.infinity : null,
                              child: ElevatedButton.icon(
                                onPressed: _deleteSelectedRoles,
                                icon: const Icon(Icons.delete, size: 18),
                                label: Text("Delete (${_selectedRoleIds.length})"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade50,
                                  foregroundColor: Colors.red,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (v) => setState((){}),
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    hintText: "Search roles...",
                                    hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 14),
                                    prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[500] : Colors.grey, size: 20),
                                    filled: isDark,
                                    fillColor: isDark ? Colors.grey[900] : null, 
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _filterType,
                                    style: TextStyle(color: textColor, fontSize: 13),
                                    items: const [
                                      DropdownMenuItem(value: 'All', child: Text("All")),
                                      DropdownMenuItem(value: 'System', child: Text("System")),
                                      DropdownMenuItem(value: 'Custom', child: Text("Custom")),
                                    ],
                                    onChanged: (v) => setState(() => _filterType = v!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
               
               const Divider(height: 1),

               // Header Row
               if (displayedRoles.isNotEmpty)
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                   child: Row(
                     children: [
                       Checkbox(
                          value: displayedRoles.where((r) => r.id != 'super_admin' && r.name != 'Store Owner').every((r) => _selectedRoleIds.contains(r.id)) && 
                                 displayedRoles.where((r) => r.id != 'super_admin' && r.name != 'Store Owner').isNotEmpty,
                          onChanged: (val) => _toggleSelectAll(displayedRoles),
                       ),
                       const SizedBox(width: 16),
                       const Expanded(flex: 3, child: Text("Role Info", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                       const Expanded(flex: 4, child: Text("Permissions", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                       const Expanded(flex: 1, child: Text("Type", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                       const SizedBox(width: 100), // Actions placeholder
                     ],
                   ),
                 ),
                const Divider(height: 1),

               // Responsive Table / List
               displayedRoles.isEmpty 
                 ? const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No roles found", style: TextStyle(color: Colors.grey))))
                 : ListView.separated(
                     shrinkWrap: true,
                     physics: const NeverScrollableScrollPhysics(),
                     itemCount: displayedRoles.length,
                     separatorBuilder: (_, __) => const Divider(height: 1),
                     itemBuilder: (context, index) {
                        final role = displayedRoles[index];
                        return _buildRoleRow(context, provider, role);
                     },
                   ),
             ],
           ),
         );
       },
     );
  }

  Widget _buildRoleRow(BuildContext context, StoreProvider provider, RoleModel role) {
    bool isMobile = MediaQuery.of(context).size.width < 700;
    
    // EDITABILITY RULE: Super Admin and Store Owner Roles cannot be edited or deleted
    bool canEdit = role.id != 'super_admin' && role.name != 'Store Owner';

    if (isMobile) {
      // Mobile - Compact List Tile
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: role.isSystem ? Colors.blue.shade100 : Colors.green.shade100,
          child: Icon(role.isSystem ? Icons.lock : Icons.person_outline, size: 20, color: role.isSystem ? Colors.blue : Colors.green),
        ),
        title: Text(role.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          role.permissions.entries.where((e) => e.value).map((e) => e.key).join(", "),
          maxLines: 1, overflow: TextOverflow.ellipsis
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEdit)
              IconButton(
                 icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                 onPressed: () => _showRoleDialog(role: role),
              ),
            if (role.id != 'super_admin' && role.name != 'Store Owner')
              IconButton(
                 icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                 onPressed: () => _confirmDelete(context, provider, role),
              ),
          ],
        ),
      );
    }

    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    // DESKTOP - Custom Row (Match Store Management)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Checkbox
          Checkbox(
            value: _selectedRoleIds.contains(role.id),
            onChanged: (role.id == 'super_admin' || role.name == 'Store Owner') ? null : (val) => _toggleSelection(role.id),
          ),
          const SizedBox(width: 16),
          // Role Info
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: role.isSystem ? Colors.blue.shade50 : Colors.green.shade50, 
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Center(
                    child: Icon(
                      role.isSystem ? Icons.lock : Icons.person_outline, 
                      color: role.isSystem ? Colors.blue.shade700 : Colors.green.shade700, 
                      size: 20
                    )
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                    const SizedBox(height: 2),
                    Text(role.isSystem ? 'System Role' : 'Custom Role', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                )
              ],
            ),
          ),
          
          // Permissions
          Expanded(
            flex: 4, 
            child: Text(
              role.permissions.entries.where((e) => e.value).map((e) => e.key.toUpperCase()).join(", "),
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey)
            )
          ),
          
          // Type Badge
          Expanded(
            flex: 1, 
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: role.isSystem ? Colors.blue.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1), 
                borderRadius: BorderRadius.circular(20)
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6, 
                    decoration: BoxDecoration(
                      color: role.isSystem ? Colors.blue : Colors.green, 
                      shape: BoxShape.circle
                    )
                  ),
                  const SizedBox(width: 6),
                  Text(
                    role.isSystem ? 'System' : 'Custom', 
                    style: TextStyle(
                      color: role.isSystem ? Colors.blue : Colors.green, 
                      fontSize: 11, 
                      fontWeight: FontWeight.w600
                    )
                  ),
                ],
              ),
            )
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canEdit)
                IconButton(
                   icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                   tooltip: "Edit Role",
                   onPressed: () => _showRoleDialog(role: role),
                ),
              if (role.id != 'super_admin' && role.name != 'Store Owner')
                IconButton(
                   icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                   tooltip: "Delete Role",
                   onPressed: () => _confirmDelete(context, provider, role),
                ),
            ],
          )
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, StoreProvider provider, RoleModel role) async {
    final confirm = await showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Role?'),
        content: Text('Are you sure you want to delete "${role.name}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );
    if (confirm == true) {
       await provider.deleteRole(role.id);
    }
  }
}
