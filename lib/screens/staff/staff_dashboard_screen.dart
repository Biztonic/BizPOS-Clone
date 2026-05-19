import 'package:biztonic_pos/core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';
import 'package:biztonic_pos/core/design/tokens/app_radius.dart';
import '../../core/design/design_system.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/store_provider.dart';
import '../../core/design/layouts/pos_scaffold.dart';


class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  /// All feature keys that can be toggled per role
  static const List<Map<String, dynamic>> _allPermissions = [
    {'key': 'pos', 'label': 'Point of Sale', 'icon': Icons.point_of_sale},
    {'key': 'inventory', 'label': 'Inventory', 'icon': Icons.inventory_2},
    {'key': 'reports', 'label': 'Reports', 'icon': Icons.bar_chart},
    {'key': 'crm', 'label': 'Customers', 'icon': Icons.people},
    {'key': 'settings', 'label': 'Settings', 'icon': Icons.settings},
    {'key': 'employees', 'label': 'Employees', 'icon': Icons.badge},
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer2<DashboardProvider, StoreProvider>(
      builder: (context, provider, storeProvider, child) {
        final totalEmployees = provider.employees.length;
        final rolesCount = provider.employees.map((e) => e.role).toSet().length;
        final storeRoles = storeProvider.activeStore?.customRoles ??
            const ['Cashier', 'Manager', 'Kitchen Staff', 'Waiter', 'Inventory Clerk'];

        final density = AppDensityProvider.configOf(context);
        
        return PosScaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.t(context, 'Employee Management')),
            actions: [
              IconButton(
                icon: const Icon(Icons.shield_outlined),
                tooltip: "Manage Role Permissions",
                onPressed: () => _showRolePermissionsEditor(context, storeProvider, storeRoles),
              ),
            ],
          ),
          mainContent: Column(
            children: [
              // Stats Cards
              Padding(
                padding: EdgeInsets.all(density.cardPadding),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(context,
                          icon: Icons.people, iconColor: AppColors.primaryLight,
                          title: "TOTAL EMPLOYEES", value: "$totalEmployees"),
                    ),
                    SizedBox(width: density.cardPadding),
                    Expanded(
                      child: _buildStatCard(context,
                          icon: Icons.badge, iconColor: AppColors.warning,
                          title: "ROLES", value: "$rolesCount"),
                    ),
                  ],
                ),
              ),
              // Employee List
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : provider.employees.isEmpty
                        ? Center(
                            child: Text(AppLocalizations.t(context, 'No employees found. Tap + to add staff.'),
                                style: TextStyle(color: AppColors.textSecondary(context))))
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: density.cardPadding),
                            itemCount: provider.employees.length,
                            itemBuilder: (context, index) {
                              final emp = provider.employees[index];
                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
                                child: ListTile(
                                  leading: CircleAvatar(
                                      child: Text(emp.name.isNotEmpty ? emp.name[0] : '?')),
                                  title: Text(emp.name,
                                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                                  subtitle: Text("${emp.role} â€¢ ID: ${emp.employeeId ?? 'N/A'}",
                                      style: AppTypography.bodySmall),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.share, color: AppColors.primaryLight, size: 20),
                                        tooltip: "Share Login",
                                        onPressed: () => _showShareDialog(context, storeProvider, emp),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: AppColors.warning, size: 20),
                                        tooltip: "Edit Role",
                                        onPressed: () => _showEmployeeDialog(context,
                                            storeRoles: storeRoles, employee: emp),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                        tooltip: "Delete",
                                        onPressed: () => _confirmDeleteEmployee(context, provider, emp),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showEmployeeDialog(context, storeRoles: storeRoles),
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.t(context, 'Add Employee')),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(BuildContext context,
      {required IconData icon, required Color iconColor,
      required String title, required String value}) {
    final density = AppDensityProvider.configOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.all(density.cardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface(context) : AppColors.surfaceLight,
        borderRadius: AppRadius.borderLg,
        boxShadow: [
          BoxShadow(color: AppColors.textPrimaryLight.withValues(alpha: 0.05), blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(title,
                style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context), fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: AppTypography.headlineMedium.copyWith(
              color: isDark ? AppColors.surfaceLight : AppColors.textPrimaryLight,
              fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // â”€â”€â”€ Delete Confirmation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _confirmDeleteEmployee(BuildContext context, DashboardProvider provider, dynamic emp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(AppLocalizations.t(context, 'Delete Employee')),
        content: Text("Are you sure you want to remove ${emp.name}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(AppLocalizations.t(context, 'Cancel'))),
          TextButton(onPressed: () => Navigator.pop(c, true),
              child: Text(AppLocalizations.t(context, 'Delete'), style: const TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm == true) {
      await provider.removeEmployee(emp.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${emp.name} removed")));
      }
    }
  }

  // â”€â”€â”€ Share Login Link Dialog â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showShareDialog(BuildContext context, StoreProvider storeProvider, dynamic emp) {
    final store = storeProvider.activeStore;
    final storeCode = store?.shortCode ?? store?.id ?? 'UNKNOWN';
    final empId = emp.employeeId ?? 'N/A';

    // On web, use current origin; on mobile, use the deployed web app URL
    final baseUrl = kIsWeb
        ? Uri.base.origin
        : 'https://bizpos-clone.web.app';
    final loginUrl = '$baseUrl/employee-login?store=$storeCode&emp=$empId';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.link, color: AppColors.primaryLight),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text("Share Link â€“ ${emp.name}", overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.t(context, 'Share this link with the employee. They can open it on any device and log in with their 4-digit PIN.'),
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.05),
                borderRadius: AppRadius.borderMd,
                border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.2)),
              ),
              child: SelectableText(loginUrl,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t(context, 'Close')),
          ),
          // Native Share button (works on mobile & desktop)
          if (!kIsWeb)
            ElevatedButton.icon(
              icon: const Icon(Icons.share, size: 18),
              label: Text(AppLocalizations.t(context, 'Share')),
              onPressed: () async {
                final box = ctx.findRenderObject() as RenderBox?;
                final sharePositionOrigin = box != null
                    ? box.localToGlobal(Offset.zero) & box.size
                    : null;
                await SharePlus.instance.share(
                  ShareParams(
                    text: 'Login to BizPOS as ${emp.name}:\n$loginUrl',
                    subject: 'BizPOS Employee Login Link',
                    sharePositionOrigin: sharePositionOrigin,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: Text(AppLocalizations.t(context, 'Copy Link')),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: loginUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.t(context, 'Link copied to clipboard!'))),
              );
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Employee Create / Edit Dialog â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showEmployeeDialog(BuildContext context,
      {required List<String> storeRoles, dynamic employee}) {
    final nameController = TextEditingController(text: employee?.name ?? '');
    final roleController = TextEditingController(text: employee?.role ?? 'Cashier');
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final provider = Provider.of<DashboardProvider>(context, listen: false);
        bool isSaving = false;
        return StatefulBuilder(builder: (context, setState) {
          String validSelection = roleController.text;
          if (!storeRoles.contains(validSelection)) {
            validSelection = storeRoles.isNotEmpty ? storeRoles.first : 'Cashier';
          }
          return AlertDialog(
            title: Text(employee == null ? 'Create Employee' : 'Edit Role'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (employee == null)
                    TextField(controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
                  if (employee == null) const SizedBox(height: AppSpacing.md),
                  if (employee == null)
                    TextField(controller: pinController,
                      decoration: const InputDecoration(labelText: "4-Digit PIN", border: OutlineInputBorder()),
                      keyboardType: TextInputType.number, maxLength: 4),
                  if (employee == null) const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    value: validSelection,
                    items: storeRoles.map((role) =>
                        DropdownMenuItem(value: role, child: Text(role))).toList(),
                    onChanged: (v) => setState(() => roleController.text = v!),
                    decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(AppLocalizations.t(context, 'Add Custom Role')),
                      onPressed: () => _showAddRoleDialog(context),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: Text(AppLocalizations.t(context, 'Cancel'))),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  if (employee == null && nameController.text.isEmpty) return;
                  if (employee == null) {
                    if (pinController.text.length != 4) return;
                    setState(() => isSaving = true);
                    try {
                      await provider.createEmployeeWithPin(
                          nameController.text, roleController.text, pinController.text);
                    } finally {
                      if (context.mounted) setState(() => isSaving = false);
                    }
                  } else {
                    setState(() => isSaving = true);
                    try {
                      await provider.updateEmployeeRole(employee.uid, roleController.text);
                    } finally {
                      if (context.mounted) setState(() => isSaving = false);
                    }
                  }
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surfaceLight)) : Text(AppLocalizations.t(context, 'Save')),
              ),
            ],
          );
        });
      },
    );
  }

  // â”€â”€â”€ Add Custom Role Dialog â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showAddRoleDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t(context, 'Add Custom Role')),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Role Name", border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t(context, 'Cancel'))),
          ElevatedButton(
            onPressed: () async {
              final roleName = controller.text.trim();
              if (roleName.isEmpty) return;
              final storeProvider = Provider.of<StoreProvider>(context, listen: false);
              final currentRoles = List<String>.from(storeProvider.activeStore?.customRoles ?? []);
              if (!currentRoles.contains(roleName)) {
                currentRoles.add(roleName);
                await storeProvider.updateStoreCustomRoles(currentRoles);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(AppLocalizations.t(context, 'Add')),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Add Custom Role Dialog (Generic) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<String?> _showSimpleAddRoleDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t(context, 'Add New Role')),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Role Name", border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t(context, 'Cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(AppLocalizations.t(context, 'Add')),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ Role Permissions Editor (Full Screen Dialog) â”€â”€â”€
  void _showRolePermissionsEditor(
      BuildContext context, StoreProvider storeProvider, List<String> storeRoles) {
    // Work with local mutable copies
    final localRoles = List<String>.from(storeRoles);
    final localPerms = <String, Map<String, bool>>{};
    final existingPerms = storeProvider.activeStore?.rolePermissions ?? {};
    for (final role in localRoles) {
      localPerms[role] = Map<String, bool>.from(existingPerms[role] ?? {});
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.shield, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(AppLocalizations.t(context, 'Role Permissions'))),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                  tooltip: "Add New Role",
                  onPressed: () async {
                    final newRole = await _showSimpleAddRoleDialog(context);
                    if (newRole != null && newRole.isNotEmpty) {
                      if (!localRoles.contains(newRole)) {
                        setState(() {
                          localRoles.add(newRole);
                          localPerms[newRole] = {};
                        });
                      }
                    }
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.t(context, 'Define what each role can access in this store.'),
                        style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13)),
                    const SizedBox(height: AppSpacing.md),
                    if (localRoles.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text(AppLocalizations.t(context, 'No custom roles defined. Tap + to add one.'),
                              style: TextStyle(color: AppColors.textSecondary(context))),
                        ),
                      ),
                    ...localRoles.map((role) {
                      final perms = localPerms[role] ?? {};
                      return _buildRolePermissionCard(
                        role, perms, setState, localPerms,
                        onDelete: () {
                          setState(() {
                            localRoles.remove(role);
                            localPerms.remove(role);
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t(context, 'Cancel'))),
              ElevatedButton.icon(
                icon: const Icon(Icons.save, size: 18),
                label: Text(AppLocalizations.t(context, 'Save All')),
                onPressed: () async {
                  await storeProvider.saveStoreRolesAndPermissions(localRoles, localPerms);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.t(context, 'Roles and permissions saved!'))),
                    );
                  }
                },
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildRolePermissionCard(String role, Map<String, bool> perms,
      StateSetter setState, Map<String, Map<String, bool>> localPerms,
      {required VoidCallback onDelete}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(role[0], style: const TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
        title: Text(role, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: AppColors.textSecondary(context), size: 20),
          onPressed: onDelete,
          tooltip: "Delete Role",
        ),
        subtitle: Text(
          perms.values.where((v) => v).isEmpty
              ? "No permissions set"
              : "${perms.values.where((v) => v).length} of ${_allPermissions.length} features enabled",
          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
        ),
        children: _allPermissions.map((perm) {
          final key = perm['key'] as String;
          final label = perm['label'] as String;
          final icon = perm['icon'] as IconData;
          final enabled = perms[key] ?? false;
          return SwitchListTile(
            secondary: Icon(icon, size: 20, color: enabled ? AppColors.primary : AppColors.textSecondary(context)),
            title: Text(label, style: const TextStyle(fontSize: 14)),
            value: enabled,
            onChanged: (val) {
              setState(() {
                localPerms[role] ??= {};
                localPerms[role]![key] = val;
              });
            },
          );
        }).toList(),
      ),
    );
  }
}





