// ignore_for_file: unused_local_variable, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../models/user_profile.dart';
import 'admin/manage_roles_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _searchController = TextEditingController();
  String _filterRole = 'All';
  final Set<String> _selectedUserIds = {};

  // Top-level roles shown in Admin User Management (not store employees)
  static const _ownerLevelRoles = {'Super Admin', 'Franchise Owner', 'Store Owner', 'Admin'};

  void _toggleSelection(String uid) {
    setState(() {
      if (_selectedUserIds.contains(uid)) {
        _selectedUserIds.remove(uid);
      } else {
        _selectedUserIds.add(uid);
      }
    });
  }

  void _toggleSelectAll(List<UserProfile> users) {
    final selectableUsers = users.where((u) => u.role != 'Super Admin').map((u) => u.uid).toSet();
    setState(() {
      if (_selectedUserIds.containsAll(selectableUsers) && selectableUsers.isNotEmpty) {
        _selectedUserIds.clear();
      } else {
        _selectedUserIds.addAll(selectableUsers);
      }
    });
  }

  Future<void> _deleteSelectedUsers() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final usersToDelete = _selectedUserIds.where((uid) {
      final user = provider.systemUsers.firstWhere((u) => u.uid == uid, orElse: () => UserProfile(uid: '', email: '', name: '', role: ''));
      return user.uid.isNotEmpty && user.role != 'Super Admin';
    }).toList();

    if (usersToDelete.isEmpty) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Selected Users"),
        content: Text("Are you sure you want to delete ${usersToDelete.length} users? This action cannot be undone."),
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
      final isSuperAdminMode = provider.activeRole == 'Super Admin' && provider.isDeveloperMode;
      for (final uid in usersToDelete) {
         if (isSuperAdminMode) {
            await provider.deleteUser(uid);
         } else {
            await provider.removeEmployee(uid);
         }
      }
      setState(() {
        _selectedUserIds.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${usersToDelete.length} users deleted successfully"))
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      provider.fetchRoles();
      
      if (provider.activeRole == 'Super Admin' || provider.activeRole == 'Store Owner') {
        provider.fetchSystemUsers();
      } else {
        provider.fetchEmployees();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddUserDialog() {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    final passwordController = TextEditingController(); // For invite, just email/name usually enough, but keeping for now
    String selectedRole = 'Store Owner';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add User'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                
                
                // Fetch Roles Dynamically
                Consumer<DashboardProvider>(
                  builder: (ctx, provider, _) {
                    final roleNames = provider.roles.map((r) => r.name).where((r) => _ownerLevelRoles.contains(r) && r != 'Super Admin').toSet().toList();
                    if (roleNames.isEmpty) roleNames.add('Store Owner');

                    if (!roleNames.contains(selectedRole)) {
                       selectedRole = roleNames.first; 
                    }

                    return DropdownButtonFormField<String>(
                     value: selectedRole,
                     decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                     items: roleNames.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                     onChanged: (val) => setState(() => selectedRole = val!),
                   );
                  }
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () async {
                if (emailController.text.isEmpty) return;
                
                final provider = Provider.of<DashboardProvider>(context, listen: false);
                try {
                  await provider.inviteEmployee(emailController.text, selectedRole, nameController.text);
                  if (mounted) Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User Invited Successfully')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Invite User'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    
    // Filter to show only owner/admin-level users (not store employees)
    List<UserProfile> displayedUsers = provider.systemUsers.where((u) {
       // Only show owner-level roles in Admin User Management
       if (!_ownerLevelRoles.contains(u.role)) return false;
       bool matchesSearch = u.name.toLowerCase().contains(_searchController.text.toLowerCase()) || 
                            u.email.toLowerCase().contains(_searchController.text.toLowerCase());
       bool matchesRole = _filterRole == 'All' || u.role == _filterRole;
       return matchesSearch && matchesRole;
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF4F6F9), // Premium Light Grey
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER SECTION
             _buildModernHeader(context),
             const SizedBox(height: 32),

            // STATS ROW (Premium Feature)
            if (MediaQuery.of(context).size.width > 800)
              _buildStatsRow(provider),
            
            const SizedBox(height: 32),

            // MAIN CONTENT TABLE
            _buildMainContent(context, provider, displayedUsers),
          ],
        ),
      ),
    );
  }

  // --- TOP HEADER ---
  Widget _buildModernHeader(BuildContext context) {
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
              const Text('Store Owner Management', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                 const SizedBox(height: 8),
                 Text('Manage store owners and admin-level users.', style: TextStyle(color: Colors.grey[600], fontSize: 15)),
               ],
             ),
           ],
        ),
        // Primary Actions
        Row(
          children: [
             OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageRolesScreen())),
                icon: const Icon(Icons.shield_outlined, size: 18),
                label: const Text("Manage Roles"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  side: BorderSide(color: Colors.grey.shade300),
                  foregroundColor: Colors.black87,
                  backgroundColor: Colors.white,
                ),
             ),
             const SizedBox(width: 12),
             ElevatedButton.icon(
                onPressed: _showAddUserDialog,
                icon: const Icon(Icons.person_add, size: 20),
                label: const Text("Add New User"),
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

  // --- STATS ROW ---
  Widget _buildStatsRow(DashboardProvider provider) {
    final ownerUsers = provider.systemUsers.where((u) => _ownerLevelRoles.contains(u.role)).toList();
    int total = ownerUsers.length;
    int owners = ownerUsers.where((u) => u.role == 'Store Owner' || u.role == 'Franchise Owner').length;
    int admins = ownerUsers.where((u) => u.role.contains('Admin')).length;

    return Row(
      children: [
        Expanded(child: _buildStatCard("Total Users", "$total", Icons.group, Colors.blue)),
        const SizedBox(width: 24),
        Expanded(child: _buildStatCard("Store Owners", "$owners", Icons.storefront, Colors.purple)),
        const SizedBox(width: 24),
        Expanded(child: _buildStatCard("Admins", "$admins", Icons.admin_panel_settings, Colors.green)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D2D44) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
            border: isDark ? Border.all(color: Colors.white10) : null,
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
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
      }
    );
  }

  // --- MAIN TABLE CONTENT ---
  Widget _buildMainContent(BuildContext context, DashboardProvider provider, List<UserProfile> users) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     return Container(
       decoration: BoxDecoration(
         color: isDark ? const Color(0xFF2D2D44) : Colors.white,
         borderRadius: BorderRadius.circular(16),
         boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03), blurRadius: 15, offset: const Offset(0, 5))],
         border: isDark ? Border.all(color: Colors.white10) : null,
       ),
       child: Column(
         children: [
            // Toolbar
           Padding(
             padding: const EdgeInsets.all(20),
             child: Row(
               children: [
                 if (_selectedUserIds.isNotEmpty) ...[
                    ElevatedButton.icon(
                      onPressed: _deleteSelectedUsers, 
                      icon: const Icon(Icons.delete, size: 18),
                      label: Text("Delete (${_selectedUserIds.length})"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 16),
                 ],
                 Expanded(
                   child: TextField(
                     controller: _searchController,
                     onChanged: (v) => setState((){}),
                     decoration: InputDecoration(
                       hintText: "Search by name or email...",
                       prefixIcon: const Icon(Icons.search, color: Colors.grey),
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                       enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                       contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                     ),
                   ),
                 ),
                 const SizedBox(width: 16),
                 Container(
                   decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                   padding: const EdgeInsets.symmetric(horizontal: 12),
                   child: DropdownButtonHideUnderline(
                   child: Consumer<DashboardProvider>(
                    builder: (context, provider, _) {
                       final roles = ['All', ..._ownerLevelRoles.where((r) => r != 'Super Admin')];
                       return DropdownButton<String>(
                         value: roles.contains(_filterRole) ? _filterRole : 'All',
                         items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                         onChanged: (v) => setState(() => _filterRole = v!),
                       );
                    }
                  ),
                   ),
                 ),
               ],
             ),
           ),
           
           const Divider(height: 1),

           // Header Row
           if (users.isNotEmpty)
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
               child: Row(
                 children: [
                   Checkbox(
                      value: users.where((u) => u.role != 'Super Admin').every((u) => _selectedUserIds.contains(u.uid)) && 
                             users.where((u) => u.role != 'Super Admin').isNotEmpty,
                      onChanged: (val) => _toggleSelectAll(users),
                   ),
                   const SizedBox(width: 16), // Adjusted width for alignment
                   const Expanded(flex: 3, child: Text("User Info", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                   const Expanded(flex: 2, child: Text("Role", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
                   const SizedBox(width: 100), // Actions placeholder
                 ],
               ),
             ),
            const Divider(height: 1),

           // Responsive Table / List
           users.isEmpty 
             ? const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No users found", style: TextStyle(color: Colors.grey))))
             : ListView.separated(
                 shrinkWrap: true,
                 physics: const NeverScrollableScrollPhysics(),
                 itemCount: users.length,
                 separatorBuilder: (_, __) => const Divider(height: 1),
                 itemBuilder: (context, index) {
                    final user = users[index];
                    return _buildUserRow(context, provider, user);
                 },
               ),
         ],
       ),
     );
  }

  Widget _buildUserRow(BuildContext context, DashboardProvider provider, UserProfile user) {
    bool isMobile = MediaQuery.of(context).size.width < 700;

    if (isMobile) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
        ),
        title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: user.role == 'Admin' || user.role == 'Store Owner' ? Colors.purple.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(user.role, style: TextStyle(
                color: user.role == 'Admin' || user.role == 'Store Owner' ? Colors.purple : Colors.blue, 
                fontWeight: FontWeight.bold, fontSize: 11
              )),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
               icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
               tooltip: "Edit Role",
               onPressed: () => _showEditRoleDialog(context, provider, user),
            ),
            IconButton(
               icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
               tooltip: "Remove User",
               onPressed: () => _confirmRemove(context, provider, user),
            ),
          ],
        ),
      );
    }

    // DESKTOP - Custom Row
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Checkbox
          Checkbox(
            value: _selectedUserIds.contains(user.uid),
            onChanged: user.role == 'Super Admin' ? null : (val) => _toggleSelection(user.uid),
          ),
          const SizedBox(width: 16),
          // User Info
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(user.email, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                )
              ],
            ),
          ),
          
          // Role Badge
          Expanded(flex: 2, child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: user.role == 'Admin' || user.role == 'Store Owner' ? Colors.purple.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(user.role, style: TextStyle(
                color: user.role == 'Admin' || user.role == 'Store Owner' ? Colors.purple : Colors.blue, 
                fontWeight: FontWeight.bold, fontSize: 12
              )),
            ),
          )),
          
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                 icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                 tooltip: "Edit Role",
                 onPressed: () {
                    // Start simplified edit dialog
                    _showEditRoleDialog(context, provider, user);
                 },
              ),
              IconButton(
                 icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                 tooltip: "Remove User",
                 onPressed: () => _confirmRemove(context, provider, user),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _showEditRoleDialog(BuildContext context, DashboardProvider provider, UserProfile user) {
    String selectedRole = user.role;
    final roleNames = provider.roles.map((r) => r.name).toSet().toList();
    
    // Ensure current role is valid or fallback to unauthorized/default
    if (!roleNames.contains(selectedRole) && selectedRole != 'Unauthorized') {
       if (roleNames.isNotEmpty) selectedRole = roleNames.first;
    }

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text("Update Role"),
          content: DropdownButtonFormField<String>(
              value: selectedRole,
              items: roleNames.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setDialogState(() => selectedRole = v!),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(onPressed: () {
               provider.updateUserRole(user.uid, selectedRole);
               Navigator.pop(ctx);
            }, child: const Text("Update"))
          ],
        );
      }
    ));
  }

  void _confirmRemove(BuildContext context, DashboardProvider provider, UserProfile user) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Remove User"),
      content: Text("Are you sure you want to remove access for ${user.email}?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
             if (provider.activeRole == 'Super Admin' && provider.isDeveloperMode) {
                provider.deleteUser(user.uid);
             } else {
                provider.removeEmployee(user.uid); 
             }
             Navigator.pop(ctx);
          }, 
          child: const Text("Remove")
        ),
      ],
    ));
  }
}
