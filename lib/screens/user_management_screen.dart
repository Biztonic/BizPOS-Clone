import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:provider/provider.dart';
import 'package:biztonic_pos/core/design/design_system.dart';
import 'package:biztonic_pos/core/design/components/atoms/app_button.dart';
import 'package:biztonic_pos/core/design/components/atoms/app_text_field.dart';
import 'package:biztonic_pos/core/design/components/atoms/app_card.dart';
import 'package:biztonic_pos/core/design/layouts/pos_scaffold.dart';
import 'package:biztonic_pos/core/design/components/organisms/pos_data_table.dart';
import '../providers/dashboard_provider.dart';
import '../models/user_profile.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterRole = 'All';
  final Set<String> _selectedUserIds = {};

  final List<String> _ownerLevelRoles = [
    'Super Admin',
    'Admin',
    'Store Owner',
    'Manager',
    'Cashier',
    'Unauthorized'
  ];

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

  Future<void> _deleteSelectedUsers() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final count = _selectedUserIds.length;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t(context, 'Delete Users')),
        content: Text("Are you sure you want to delete $count selected users?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.t(context, 'Cancel'))),
          AppButton.danger(onPressed: () => Navigator.pop(ctx, true), label: "Delete"),
        ],
      ),
    );

    if (confirm == true) {
      for (var uid in _selectedUserIds) {
        await provider.deleteUser(uid);
      }
      setState(() => _selectedUserIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Successfully deleted $count users")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final filteredUsers = provider.systemUsers.where((u) {
      final matchesSearch = u.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          u.email.toLowerCase().contains(_searchController.text.toLowerCase());
      final matchesRole = _filterRole == 'All' || u.role == _filterRole;
      return matchesSearch && matchesRole;
    }).toList();

    final isSuperAdmin = provider.activeRole == 'Super Admin';

    return PosScaffold(
      title: 'User Management',
      actions: [
        if (!isSuperAdmin) ...[
          AppButton.primary(
            onPressed: () => _showAddUserDialog(),
            icon: Icons.person_add,
            label: isDesktop ? "Add New User" : null,
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ],
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsRow(context, provider),
                const SizedBox(height: AppSpacing.lg),
                _buildFilters(context, filteredUsers),
              ],
            ),
          ),
          if (filteredUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: AppCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      children: [
                        Icon(Icons.people_outline, size: 64, color: AppColors.textHint(context)),
                        const SizedBox(height: AppSpacing.md),
                        Text(AppLocalizations.t(context, 'No users found'), style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary(context))),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, bottom: AppSpacing.lg),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: PosDataTable(
                  columns: const [
                    PosDataColumn(label: 'SEL', fixedWidth: 50),
                    PosDataColumn(label: 'User Info', flex: 3),
                    PosDataColumn(label: 'Role', flex: 2),
                    PosDataColumn(label: 'Actions', fixedWidth: 120),
                  ],
                  rows: filteredUsers.map((user) {
                    final primaryColor = AppColors.adaptivePrimary(context);
                    return PosDataRow(
                      cells: [
                        Checkbox(
                          value: _selectedUserIds.contains(user.uid),
                          onChanged: user.role == 'Super Admin' ? null : (val) => _toggleSelection(user.uid),
                        ),
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: primaryColor.withValues(alpha: 0.1),
                              child: Text(
                                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                style: AppTypography.titleSmall.copyWith(color: primaryColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(user.name, style: AppTypography.titleMedium),
                                Text(user.email, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
                              ],
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _buildRoleBadge(context, user.role),
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
                              icon: Icon(Icons.delete_outline, size: 20, color: AppColors.adaptiveError(context)),
                              onPressed: () => _confirmRemove(context, provider, user),
                              tooltip: 'Remove User',
                            ),
                          ],
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context, List<UserProfile> users) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          if (_selectedUserIds.isNotEmpty) ...[
            AppButton.danger(
              onPressed: _deleteSelectedUsers,
              label: "Delete (${_selectedUserIds.length})",
              icon: Icons.delete,
              size: AppButtonSize.small,
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
    );
  }

  Widget _buildRoleBadge(BuildContext context, String role) {
    final color = AppColors.adaptivePrimary(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.borderSm,
      ),
      child: Text(role,
          style: AppTypography.labelSmall.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          )),
    );
  }

  Widget _buildStatsRow(BuildContext context, DashboardProvider provider) {
    final total = provider.systemUsers.length;
    final admins = provider.systemUsers.where((u) => u.role == 'Admin' || u.role == 'Super Admin').length;
    final owners = provider.systemUsers.where((u) => u.role == 'Store Owner').length;

    return Row(
      children: [
        Expanded(child: _buildStatCard(context, "Total Users", "$total", Icons.people, AppColors.adaptivePrimary(context))),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildStatCard(context, "Administrators", "$admins", Icons.admin_panel_settings, AppColors.adaptiveInfo(context))),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildStatCard(context, "Store Owners", "$owners", Icons.store, AppColors.adaptiveSuccess(context))),
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
              borderRadius: AppRadius.borderMd,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _showAddUserDialog() {
    // Implement add user logic
  }

  void _showEditRoleDialog(BuildContext context, DashboardProvider provider, UserProfile user) {
    String selectedRole = user.role;
    final roleNames = _ownerLevelRoles.where((r) => r != 'Super Admin').toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(AppLocalizations.t(context, 'Update Role')),
          content: DropdownButtonFormField<String>(
            value: roleNames.contains(selectedRole) ? selectedRole : roleNames.first,
            items: roleNames.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => setDialogState(() => selectedRole = v!),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t(context, 'Cancel'))),
            AppButton.primary(
              onPressed: () async {
                await provider.updateUserRole(user.uid, selectedRole);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              label: "Update",
            )
          ],
        );
      })
    );
  }

  void _confirmRemove(BuildContext context, DashboardProvider provider, UserProfile user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t(context, 'Remove User')),
        content: Text("Are you sure you want to remove access for ${user.email}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t(context, 'Cancel'))),
          AppButton.danger(
            onPressed: () async {
              if (provider.activeRole == 'Super Admin' && provider.isDeveloperMode) {
                await provider.deleteUser(user.uid);
              } else {
                await provider.removeEmployee(user.uid);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            label: "Remove",
          ),
        ],
      )
    );
  }
}



