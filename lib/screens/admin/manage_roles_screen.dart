import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:provider/provider.dart';
import 'package:biztonic_pos/providers/store_provider.dart';
import '../../models/role_model.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_colors.dart';

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

    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t(context, 'Delete Selected Roles')),
        content: Text("Are you sure you want to delete ${rolesToDelete.length} roles? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.t(context, 'Cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.surfaceLight),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.t(context, 'Delete')),
          ),
        ],
      ),
    );


    if (confirm == true) {
      for (final id in rolesToDelete) {
         await provider.deleteRole(id);
      }
      if (mounted) {
        setState(() {
          _selectedRoleIds.clear();
        });
        messenger.showSnackBar(
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
                const SizedBox(height: AppSpacing.md),
                // Permissions UI removed as requested
                /*
                Text(AppLocalizations.t(context, 'Permissions'), style: TextStyle(fontWeight: FontWeight.bold)),
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
                  final provider = Provider.of<StoreProvider>(context, listen: false);
                  final confirm = await showDialog(
                    context: context, 
                    builder: (deleteCtx) => AlertDialog(
                      title: Text(AppLocalizations.t(context, 'Delete Role?')),
                      content: Text(AppLocalizations.t(context, 'This action cannot be undone.')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(deleteCtx, false), child: Text(AppLocalizations.t(context, 'Cancel'))),
                        TextButton(onPressed: () => Navigator.pop(deleteCtx, true), child: Text(AppLocalizations.t(context, 'Delete'), style: const TextStyle(color: AppColors.error))),
                      ],
                    )
                  );
                  if (confirm == true) {
                     await provider.deleteRole(role.id);
                     if (ctx.mounted) Navigator.pop(ctx); // Close Edit Dialog
                  }
                },
                child: Text(AppLocalizations.t(context, 'Delete'), style: const TextStyle(color: AppColors.error)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t(context, 'Cancel'))),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                final provider = Provider.of<StoreProvider>(context, listen: false);
                final messenger = ScaffoldMessenger.of(context);
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
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                   if (mounted) {
                     messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                   }
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
    return PosScaffold(
      title: 'Manage Roles',
      actions: [
        AppButton.primary(
          onPressed: () => _showRoleDialog(),
          icon: Icons.add,
          label: MediaQuery.of(context).size.width > 600 ? "Add New Role" : "Add",
        ),
        const SizedBox(width: AppSpacing.md),
      ],
      mainContent: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (MediaQuery.of(context).size.width > 800) ...[
              _buildStatsRow(),
              const SizedBox(height: AppSpacing.xl),
            ],
            _buildMainContent(context),
          ],
        ),
      ),
    );
  }

  // --- STATS ROW ---
  Widget _buildStatsRow() {
    return Consumer<StoreProvider>(
      builder: (context, provider, child) {
        final roles = provider.roles;
        int total = roles.length;
        int system = roles.where((r) => r.isSystem).length;
        int custom = roles.where((r) => !r.isSystem).length;

        return Row(
          children: [
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: const Icon(Icons.shield, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.t(context, 'Total Roles'),
                          style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary(context)),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text("$total", style: AppTypography.headlineMedium),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: const Icon(Icons.lock, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.t(context, 'System Roles'),
                          style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary(context)),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text("$system", style: AppTypography.headlineMedium),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: const Icon(Icons.person_outline, color: AppColors.success, size: 28),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.t(context, 'Custom Roles'),
                          style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary(context)),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text("$custom", style: AppTypography.headlineMedium),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Consumer<StoreProvider>(
      builder: (context, provider, child) {
        final roles = provider.roles;
        
        List<RoleModel> displayedRoles = roles.where((r) {
          bool matchesSearch = r.name.toLowerCase().contains(_searchController.text.toLowerCase());
          bool matchesType = _filterType == 'All' || 
                             (_filterType == 'System' && r.isSystem) ||
                             (_filterType == 'Custom' && !r.isSystem);
          
          return matchesSearch && matchesType;
        }).toList();

        return AppCard(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    if (_selectedRoleIds.isNotEmpty) ...[
                      AppButton.danger(
                        onPressed: _deleteSelectedRoles,
                        icon: Icons.delete,
                        label: "Delete (${_selectedRoleIds.length})",
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      child: AppTextField(
                        controller: _searchController,
                        hintText: "Search roles...",
                        prefixIcon: const Icon(Icons.search),
                        onChanged: (v) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filterType,
                          items: [
                            DropdownMenuItem(value: 'All', child: Text(AppLocalizations.t(context, 'All Types'), style: AppTypography.bodyMedium)),
                            DropdownMenuItem(value: 'System', child: Text(AppLocalizations.t(context, 'System Only'), style: AppTypography.bodyMedium)),
                            DropdownMenuItem(value: 'Custom', child: Text(AppLocalizations.t(context, 'Custom Only'), style: AppTypography.bodyMedium)),
                          ],
                          onChanged: (v) => setState(() => _filterType = v!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (displayedRoles.isNotEmpty && MediaQuery.of(context).size.width > 700)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  child: Row(
                    children: [
                      Checkbox(
                        value: displayedRoles.where((r) => r.id != 'super_admin' && r.name != 'Store Owner').every((r) => _selectedRoleIds.contains(r.id)) && 
                               displayedRoles.where((r) => r.id != 'super_admin' && r.name != 'Store Owner').isNotEmpty,
                        onChanged: (val) => _toggleSelectAll(displayedRoles),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(flex: 3, child: Text(AppLocalizations.t(context, 'ROLE NAME'), style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context)))),
                      Expanded(flex: 4, child: Text(AppLocalizations.t(context, 'PERMISSIONS'), style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context)))),
                      Expanded(flex: 2, child: Text(AppLocalizations.t(context, 'TYPE'), style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context)))),
                      const SizedBox(width: AppSpacing.xl),
                    ],
                  ),
                ),
              const Divider(height: 1),
              displayedRoles.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Center(child: Text(AppLocalizations.t(context, 'No roles found'), style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context)))),
                  )
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
    bool canEdit = role.id != 'super_admin' && role.name != 'Store Owner';

    if (isMobile) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        leading: CircleAvatar(
          backgroundColor: (role.isSystem ? AppColors.primary : AppColors.success).withValues(alpha: 0.1),
          child: Icon(
            role.isSystem ? Icons.lock : Icons.person_outline, 
            size: 20, 
            color: role.isSystem ? AppColors.primary : AppColors.success,
          ),
        ),
        title: Text(role.name, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text(
          role.permissions.entries.where((e) => e.value).map((e) => e.key.toUpperCase()).join(", "),
          style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                onPressed: () => _showRoleDialog(role: role),
              ),
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                onPressed: () => _confirmDelete(context, provider, role),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Checkbox(
            value: _selectedRoleIds.contains(role.id),
            onChanged: canEdit ? (val) => _toggleSelection(role.id) : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: (role.isSystem ? AppColors.primary : AppColors.success).withValues(alpha: 0.1), 
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Icon(
                    role.isSystem ? Icons.lock : Icons.person_outline, 
                    color: role.isSystem ? AppColors.primary : AppColors.success, 
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(role.name, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            flex: 4, 
            child: Text(
              role.permissions.entries.where((e) => e.value).map((e) => e.key.toUpperCase()).join(", "),
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2, 
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: (role.isSystem ? AppColors.primary : AppColors.success).withValues(alpha: 0.1), 
                  borderRadius: BorderRadius.zero,
                ),
                child: Text(
                  role.isSystem ? 'SYSTEM' : 'CUSTOM', 
                  style: TextStyle(
                    color: role.isSystem ? AppColors.primary : AppColors.success, 
                    fontSize: 10, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canEdit)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primaryLight),
                  onPressed: () => _showRoleDialog(role: role),
                  tooltip: "Edit Role",
                ),
              if (canEdit)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                  onPressed: () => _confirmDelete(context, provider, role),
                  tooltip: "Delete Role",
                ),
            ],
          )
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, StoreProvider provider, RoleModel role) async {
    final confirm = await showDialog<bool>(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t(context, 'Delete Role?'), style: AppTypography.titleLarge),
        content: Text('Are you sure you want to delete "${role.name}"? This action cannot be undone.', style: AppTypography.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.t(context, 'Cancel'), style: AppTypography.bodyMedium)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: Text(AppLocalizations.t(context, 'Delete'), style: AppTypography.bodyMedium.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await provider.deleteRole(role.id);
    }
  }
}



