// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:biztonic_pos/providers/store_provider.dart';
import '../../models/role_model.dart';

class RoleConfigurationScreen extends StatefulWidget {
  const RoleConfigurationScreen({super.key});

  @override
  State<RoleConfigurationScreen> createState() => _RoleConfigurationScreenState();
}

class _RoleConfigurationScreenState extends State<RoleConfigurationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rule & Role Configuration"),
        centerTitle: true,
      ),
      body: Consumer<StoreProvider>(
        builder: (context, provider, _) {
          final roles = provider.roles;
          
          if (roles.isEmpty) {
             return const Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: roles.length,
            itemBuilder: (ctx, index) {
              final role = roles[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                   leading: CircleAvatar(
                      backgroundColor: role.isSystem ? Colors.purple[50] : Colors.blue[50],
                      child: Icon(
                         role.isSystem ? Icons.lock : Icons.badge, 
                         color: role.isSystem ? Colors.purple : Colors.blue
                      ),
                   ),
                   title: Text(role.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                   subtitle: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       if (role.description != null) Text(role.description!),
                       const SizedBox(height: 4),
                       _buildModeBadge(role.storeAccessMode),
                     ],
                   ),
                   trailing: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       IconButton(
                         icon: const Icon(Icons.edit, color: Colors.blue),
                         onPressed: () => _showRoleEditor(context, provider, role),
                       ),
                       if (!role.isSystem)
                         IconButton(
                           icon: const Icon(Icons.delete, color: Colors.red),
                           onPressed: () => _confirmDelete(context, provider, role),
                         ),
                     ],
                   ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRoleEditor(context, Provider.of<StoreProvider>(context, listen: false), null),
        label: const Text("Create Role"),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildModeBadge(String mode) {
    Color color;
    String label;
    switch(mode) {
      case 'multi_full': 
        color = Colors.purple;
        label = "Multi-Store (Full)";
        break;
      case 'franchise':
        color = Colors.orange;
        label = "Franchise (Read-Only Secondary)";
        break;
       default:
        color = Colors.green;
        label = "Single Store";
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
         color: color.withValues(alpha: 0.1),
         borderRadius: BorderRadius.circular(4),
         border: Border.all(color: color.withValues(alpha: 0.3))
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }

  void _showRoleEditor(BuildContext context, StoreProvider provider, RoleModel? role) {
     final nameCtrl = TextEditingController(text: role?.name ?? '');
     final descCtrl = TextEditingController(text: role?.description ?? '');
     String accessMode = role?.storeAccessMode ?? 'single';
     // Copy permissions or default empty
     Map<String, bool> permissions = Map<String, bool>.from(role?.permissions ?? {});
     
     // Helper to toggle
     void togglePerm(String key, bool val) {
        if (!val) {
           permissions.remove(key);
        } else {
           permissions[key] = true;
        }
     }
     
     showDialog(
       context: context,
       builder: (ctx) => StatefulBuilder(
         builder: (context, setState) {
           return AlertDialog(
             title: Text(role == null ? "Create Role" : "Edit Role"),
             content: SizedBox(
               width: 500,
               child: SingleChildScrollView(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   mainAxisSize: MainAxisSize.min,
                   children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: "Role Name", border: OutlineInputBorder()),
                        enabled: role == null || !role.isSystem, // System names locked? Usually good practice.
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      const Text("Store Access Mode", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: accessMode,
                        items: const [
                          DropdownMenuItem(value: 'single', child: Text("Single Store (Standard)")),
                          DropdownMenuItem(value: 'multi_full', child: Text("Multi-Store (Full Access)")),
                          DropdownMenuItem(value: 'franchise', child: Text("Franchise (Primary Write / Secondary Read)")),
                        ],
                        onChanged: (v) => setState(() => accessMode = v!),
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      const Text("Permissions", style: TextStyle(fontWeight: FontWeight.bold)),
                      const Divider(),
                      CheckboxListTile(
                         title: const Text("Full Admin Access (All)"),
                         value: permissions['all'] == true,
                         onChanged: (v) => setState(() => togglePerm('all', v!)),
                         controlAffinity: ListTileControlAffinity.leading,
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
               TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
               ElevatedButton(
                 onPressed: () async {
                    if (nameCtrl.text.isEmpty) return;
                    
                    final newRole = RoleModel(
                       id: role?.id ?? '', // Empty ID triggers create logic in provider
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
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                    }
                 },
                 child: const Text("Save"),
               )
             ],
           );
         }
       )
     );
  }
  
  Widget _buildPermCheckbox(String label, String key, Map<String, bool> permissions, StateSetter setState) {
     return CheckboxListTile(
       title: Text(label),
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
     );
  }

  void _confirmDelete(BuildContext context, StoreProvider provider, RoleModel role) {
    showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
          title: const Text("Delete Role?"),
          content: Text("Delete '${role.name}'? Users with this role may lose access."),
          actions: [
             TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
             ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                   await provider.deleteRole(role.id);
                   Navigator.pop(ctx);
                },
                child: const Text("Delete", style: TextStyle(color: Colors.white)),
             )
          ],
       )
    );
  }
}
