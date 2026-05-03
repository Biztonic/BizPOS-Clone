import '../core/design/tokens/app_colors.dart';
// ignore_for_file: unused_local_variable, use_build_context_synchronously
import 'package:flutter/material.dart';
import '../core/design/layouts/pos_scaffold.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../models/user_profile.dart';
import 'admin/manage_roles_screen.dart';
import '../core/design/components/atoms/app_button.dart';
import '../core/design/components/atoms/app_card.dart';
import '../core/design/components/atoms/app_text_field.dart';
import '../core/design/components/organisms/pos_data_table.dart';
import '../core/design/density/app_density.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _searchController = TextEditingController();
  String _filterRole = 'All';
  final Set<String> _selectedUserIds = {};

  static const _ownerLevelRoles = {'Super Admin', 'Franchise Owner', 'Store Owner', 'Admin'};

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
          AppButton.danger(
            label: "Delete",
            onPressed: () => Navigator.pop(ctx, true),
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

  void _showAddUserDialog() {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
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
                AppTextField(controller: nameController, label: 'Name', hintText: 'Enter full name'),
                const SizedBox(height: AppSpacing.md),
                AppTextField(controller: emailController, label: 'Email', hintText: 'Enter email address'),
                const SizedBox(height: AppSpacing.md),
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
            AppButton.primary(
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
              label: 'Invite User',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 1100;
    
    List<UserProfile> displayedUsers = provider.systemUsers.where((u) {
       if (!_ownerLevelRoles.contains(u.role)) return false;
       bool matchesSearch = u.name.toLowerCase().contains(_searchController.text.toLowerCase()) || 
                            u.email.toLowerCase().contains(_searchController.text.toLowerCase());
       bool matchesRole = _filterRole == 'All' || u.role == _filterRole;
       return matchesSearch && matchesRole;
    }).toList();

    return PosScaffold(
      title: 'User Management',
      actions: [
        AppButton.secondary(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageRolesScreen())),
          icon: Icons.shield_outlined,
          label: isDesktop ? "Manage Roles" : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        AppButton.primary(
          onPressed: _showAddUserDialog,
          icon: Icons.person_add,
          label: isDesktop ? "Add New User" : null,
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
            _buildMainContent(context, provider, displayedUsers),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(DashboardProvider provider) {
    final ownerUsers = provider.systemUsers.where((u) => _ownerLevelRoles.contains(u.role)).toList();
    int total = ownerUsers.length;
    int owners = ownerUsers.where((u) => u.role == 'Store Owner' || u.role == 'Franchise Owner').length;
    int admins = ownerUsers.where((u) => u.role.contains('Admin')).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSpacing.lg,
          mainAxisSpacing: AppSpacing.lg,
          childAspectRatio: 2.5,
          children: [
            _buildStatCard("Total Users", "$total", Icons.group, AppColors.primaryLight),
            _buildStatCard("Store Owners", "$owners", Icons.storefront, AppColors.primaryLight),
            _buildStatCard("Admins", "$admins", Icons.admin_panel_settings, AppColors.success),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary(context))),
              const SizedBox(height: AppSpacing.xs),
              Text(value, style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, DashboardProvider provider, List<UserProfile> users) {
    final isDesktop = MediaQuery.of(context).size.width >= 1100;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                if (_selectedUserIds.isNotEmpty) ...[
                  AppButton.danger(
                    onPressed: _deleteSelectedUsers,
                    label: "Delete (${_selectedUserIds.length})",
                    icon: Icons.delete,
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: AppTextField(
                    controller: _searchController,
                    hintText: "Search by name or email...",
                    prefixIcon: const Icon(Icons.search),
                    onChanged: (v) => setState(() {}),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _filterRole,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(),
                    ),
                    items: ['All', ..._ownerLevelRoles.where((r) => r != 'Super Admin')]
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) => setState(() => _filterRole = v!),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (users.isEmpty)
            Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Center(child: Text("No users found", style: TextStyle(color: AppColors.textSecondary(context)))),
            )
          else if (isDesktop)
            _buildTableView(context, provider, users)
          else
            _buildListView(context, provider, users),
        ],
      ),
    );
  }

  Widget _buildTableView(BuildContext context, DashboardProvider provider, List<UserProfile> users) {
    return PosDataTable(
      columns: [
        PosDataColumn(
          label: 'SEL',
          fixedWidth: 50,
        ),
        const PosDataColumn(label: 'User Info', flex: 3),
        const PosDataColumn(label: 'Role', flex: 2),
        const PosDataColumn(label: 'Actions', fixedWidth: 120),
      ],
      rows: users.map((user) {
        return PosDataRow(
          cells: [
            Checkbox(
              value: _selectedUserIds.contains(user.uid),
              onChanged: user.role == 'Super Admin' ? null : (val) => _toggleSelection(user.uid),
            ),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(user.email, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                  ],
                )
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: _buildRoleBadge(user.role),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _showEditRoleDialog(context, provider, user),
                  tooltip: 'Edit Role',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                  onPressed: () => _confirmRemove(context, provider, user),
                  tooltip: 'Remove User',
                ),
              ],
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildListView(BuildContext context, DashboardProvider provider, List<UserProfile> users) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: users.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = users[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.email, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
              const SizedBox(height: 4),
              _buildRoleBadge(user.role),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _showEditRoleDialog(context, provider, user),
                tooltip: 'Edit Role',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                onPressed: () => _confirmRemove(context, provider, user),
                tooltip: 'Remove User',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleBadge(String role) {
    final color = role == 'Admin' || role == 'Store Owner' || role == 'Super Admin' ? AppColors.primaryLight : AppColors.primaryLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(role,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          )),
    );
  }

  void _showEditRoleDialog(BuildContext context, DashboardProvider provider, UserProfile user) {
    String selectedRole = user.role;
    final roleNames = provider.roles.map((r) => r.name).toSet().toList();
    if (!roleNames.contains(selectedRole) && selectedRole != 'Unauthorized') {
      if (roleNames.isNotEmpty) selectedRole = roleNames.first;
    }

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text("Update Role"),
                content: DropdownButtonFormField<String>(
                  value: selectedRole,
                  items: roleNames.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setDialogState(() => selectedRole = v!),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                  AppButton.primary(
                    onPressed: () {
                      provider.updateUserRole(user.uid, selectedRole);
                      Navigator.pop(ctx);
                    },
                    label: "Update",
                  )
                ],
              );
            }));
  }

  void _confirmRemove(BuildContext context, DashboardProvider provider, UserProfile user) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Remove User"),
              content: Text("Are you sure you want to remove access for ${user.email}?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                AppButton.danger(
                  onPressed: () {
                    if (provider.activeRole == 'Super Admin' && provider.isDeveloperMode) {
                      provider.deleteUser(user.uid);
                    } else {
                      provider.removeEmployee(user.uid);
                    }
                    Navigator.pop(ctx);
                  },
                  label: "Remove",
                ),
              ],
            ));
  }
}

