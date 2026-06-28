// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:provider/provider.dart';
import 'package:biztonic_pos/providers/store_provider.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../models/role_model.dart';

class RoleConfigurationScreen extends StatefulWidget {
  const RoleConfigurationScreen({super.key});

  @override
  State<RoleConfigurationScreen> createState() => _RoleConfigurationScreenState();
}

class _RoleConfigurationScreenState extends State<RoleConfigurationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StoreProvider>(context, listen: false).fetchRoles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PosScaffold(
      title: "Rule & Role Configuration",
      actions: [
        AppButton.primary(
          onPressed: () => _showRoleEditor(context, Provider.of<StoreProvider>(context, listen: false), null),
          label: "Create Role",
          icon: Icons.add,
        ),
        const SizedBox(width: AppSpacing.md),
      ],
      mainContent: Consumer<StoreProvider>(
        builder: (context, provider, _) {
          final roles = provider.roles;
          
          if (roles.isEmpty) {
             return const Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: roles.length,
            itemBuilder: (ctx, index) {
              final role = roles[index];
              return _buildRoleCard(context, role, provider);
            },
          );
        },
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, RoleModel role, StoreProvider provider) {
    final isSystem = role.isSystem;
    final iconColor = isSystem ? AppColors.primaryLight : AppColors.primary;
    final permCount = role.permissions.entries.where((e) => e.value == true).length;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.zero,
            ),
            child: Icon(
              isSystem ? Icons.lock : Icons.badge_outlined,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(role.name, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                    if (isSystem) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: AppSpacing.xxs),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Text(AppLocalizations.t(context, 'SYSTEM'), style: const TextStyle(fontSize: 9, color: AppColors.primaryLight, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ),
                    ],
                  ],
                ),
                if (role.description != null && role.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(role.description!, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _buildModeBadge(role.storeAccessMode),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      "$permCount permission${permCount != 1 ? 's' : ''}",
                      style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton.secondary(
                label: "Edit",
                icon: Icons.edit_outlined,
                onPressed: () => _showRoleEditor(context, provider, role),
              ),
              if (!isSystem) ...[
                const SizedBox(width: AppSpacing.xs),
                AppButton.danger(
                  label: "Delete",
                  icon: Icons.delete_outline,
                  onPressed: () => _confirmDelete(context, provider, role),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeBadge(String mode) {
    Color color;
    String label;
    switch(mode) {
      case 'multi_full': 
        color = AppColors.primaryLight;
        label = "Multi-Store (Full)";
        break;
      case 'franchise':
        color = AppColors.warning;
        label = "Franchise (Read-Only)";
        break;
       default:
        color = AppColors.success;
        label = "Single Store";
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
         color: color.withValues(alpha: 0.1),
         borderRadius: BorderRadius.zero,
         border: Border.all(color: color.withValues(alpha: 0.3))
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }

  void _showRoleEditor(BuildContext context, StoreProvider provider, RoleModel? role) {
     final nameCtrl = TextEditingController(text: role?.name ?? '');
     final descCtrl = TextEditingController(text: role?.description ?? '');
     String accessMode = role?.storeAccessMode ?? 'single';
     Map<String, bool> permissions = Map<String, bool>.from(role?.permissions ?? {});
     
     showDialog(
       context: context,
       builder: (ctx) => StatefulBuilder(
         builder: (context, setState) {
           return AlertDialog(
             shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
             title: Text(role == null ? "Create Role" : "Edit Role", style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
             content: SizedBox(
               width: 500,
               child: SingleChildScrollView(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   mainAxisSize: MainAxisSize.min,
                   children: [
                      AppTextField(
                        controller: nameCtrl,
                        label: "Role Name",
                        hintText: "e.g. Manager",
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: descCtrl,
                        label: "Description",
                        hintText: "What can this role do?",
                        prefixIcon: const Icon(Icons.description_outlined),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(AppLocalizations.t(context, 'Store Access Mode'), style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: AppSpacing.sm),
                      DropdownButtonFormField<String>(
                        value: accessMode,
                        items: [
                          DropdownMenuItem(value: 'single', child: Text(AppLocalizations.t(context, 'Single Store (Standard)'))),
                          DropdownMenuItem(value: 'multi_full', child: Text(AppLocalizations.t(context, 'Multi-Store (Full Access)'))),
                          DropdownMenuItem(value: 'franchise', child: Text(AppLocalizations.t(context, 'Franchise (Primary Write / Secondary Read)'))),
                        ],
                        onChanged: (v) => setState(() => accessMode = v!),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                          contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(AppLocalizations.t(context, 'Permissions'), style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      const Divider(height: AppSpacing.lg),
                      CheckboxListTile(
                         title: Text(AppLocalizations.t(context, 'Full Admin Access (All)'), style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                         value: permissions['all'] == true,
                         onChanged: (v) => setState(() {
                           if (v == true) {
                             permissions['all'] = true;
                           } else {
                             permissions.remove('all');
                           }
                         }),
                         controlAffinity: ListTileControlAffinity.leading,
                         contentPadding: EdgeInsets.zero,
                         activeColor: AppColors.primary,
                      ),
                      if (permissions['all'] != true) ...[
                        _buildPermCheckbox("POS Access", 'pos', permissions, setState),
                        _buildPermCheckbox("Inventory Item View", 'inventory_view', permissions, setState),
                        _buildPermCheckbox("Inventory Full Management", 'inventory', permissions, setState),
                        _buildPermCheckbox("Reports View", 'reports', permissions, setState),
                        _buildPermCheckbox("Settings Access", 'settings', permissions, setState),
                        _buildPermCheckbox("User Management", 'admin', permissions, setState),
                      ]
                   ],
                 ),
               ),
             ),
             actions: [
               TextButton(
                 onPressed: () => Navigator.pop(ctx),
                 child: Text(AppLocalizations.t(context, 'Cancel'), style: TextStyle(color: AppColors.textSecondary(context))),
               ),
               AppButton.primary(
                 onPressed: () async {
                    if (nameCtrl.text.isEmpty) return;
                    
                    final newRole = RoleModel(
                       id: role?.id ?? '',
                       name: nameCtrl.text.trim(),
                       description: descCtrl.text.trim(),
                       permissions: permissions,
                       isSystem: role?.isSystem ?? false,
                       storeAccessMode: accessMode
                    );
                    
                    try {
                       if (newRole.id.isNotEmpty) {
                          await provider.updateRole(newRole);
                       } else {
                          await provider.addRole(newRole);
                       }
                       if (mounted) Navigator.pop(ctx);
                    } catch (e) {
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error));
                    }
                 },
                 label: "Save",
               )
             ],
           );
         }
       )
     );
  }
  
  Widget _buildPermCheckbox(String label, String key, Map<String, bool> permissions, StateSetter setState) {
     return CheckboxListTile(
       title: Text(label, style: AppTypography.bodyMedium),
       value: permissions[key] == true,
       dense: true,
       onChanged: (v) => setState(() {
          if (v == true) {
            permissions[key] = true;
          } else {
            permissions.remove(key);
          }
       }),
       controlAffinity: ListTileControlAffinity.leading,
       contentPadding: EdgeInsets.zero,
       activeColor: AppColors.primary,
     );
  }

  void _confirmDelete(BuildContext context, StoreProvider provider, RoleModel role) {
    showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(AppLocalizations.t(context, 'Delete Role?'), style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
          content: Text("Delete '${role.name}'? Users with this role may lose access.", style: AppTypography.bodyMedium),
          actions: [
             TextButton(
               onPressed: () => Navigator.pop(ctx),
               child: Text(AppLocalizations.t(context, 'Cancel'), style: TextStyle(color: AppColors.textSecondary(context))),
             ),
             AppButton.danger(
                onPressed: () async {
                   await provider.deleteRole(role.id);
                   Navigator.pop(ctx);
                },
                label: "Delete",
             )
          ],
       )
    );
  }
}


