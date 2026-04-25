// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../models/user_profile.dart';
import '../l10n/app_localizations.dart'; 

class EmployeesScreen extends StatefulWidget {
  final int initialTabIndex;

  const EmployeesScreen({super.key, this.initialTabIndex = 0});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      provider.fetchRoles();
    });
  }

  // --- CORE UTILS ---
  void _showEmployeeDialog(BuildContext context, {UserProfile? employee}) {
    final nameController = TextEditingController(text: employee?.name ?? '');
    final roleController = TextEditingController(text: employee?.role ?? 'Cashier');
    final pinController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) {
        final provider = Provider.of<DashboardProvider>(context, listen: false);
        return StatefulBuilder(
          builder: (context, setState) {
            final validRoles = provider.roles.where((r) => r.name != 'Super Admin').toList();
            String validSelection = roleController.text;
            if (!validRoles.any((r) => r.name == validSelection)) {
               validSelection = validRoles.isNotEmpty ? validRoles.first.name : 'Cashier';
            }

            return AlertDialog(
              title: Text(employee == null ? 'Create Employee' : 'Edit Role'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (employee == null)
                       TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
                    if (employee == null) const SizedBox(height: 12),
                    if (employee == null)
                      TextField(
                        controller: pinController, 
                        decoration: const InputDecoration(labelText: "4-Digit PIN", border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                      ),
                    if (employee == null) const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: validSelection,
                      items: validRoles.map((r) => DropdownMenuItem(value: r.name, child: Text(r.name))).toList(),
                      onChanged: (v) {
                         setState(() {
                            roleController.text = v!;
                         });
                      },
                      decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    if (employee == null && nameController.text.isEmpty) return;
                    
                    if (employee == null) {
                      if (pinController.text.length != 4) return;
                      await provider.createEmployeeWithPin(nameController.text, roleController.text, pinController.text);
                    } else {
                      await provider.updateEmployeeRole(employee.uid, roleController.text);
                    }
                    if (context.mounted) Navigator.pop(ctx);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;
        
        return Scaffold(
          appBar: AppBar(title: Text(AppLocalizations.t(context, 'employees'))),
          body: Consumer<DashboardProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) return const Center(child: CircularProgressIndicator());
              return _buildStaffList(context, provider, isDesktop);
            }
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showEmployeeDialog(context),
            icon: const Icon(Icons.add),
            label: const Text("Add"),
          ),
        );
      }
    );
  }


  // --- 2. ROSTER ---
  Widget _buildStaffList(BuildContext context, DashboardProvider provider, bool isDesktop) {
    final employees = provider.employees;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (employees.isEmpty)
          const Center(child: Text("No employees found. Tap + to add staff.", style: TextStyle(color: Colors.grey)))
        else
          ...employees.map((emp) => Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(child: Text(emp.name.isNotEmpty ? emp.name[0] : '?')),
              title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${emp.role} • ID: ${emp.employeeId ?? 'N/A'}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                    tooltip: "Edit Role",
                    onPressed: () => _showEmployeeDialog(context, employee: emp),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    tooltip: "Delete",
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text("Delete Employee"),
                          content: Text("Are you sure you want to remove ${emp.name}?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await provider.removeEmployee(emp.uid);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${emp.name} removed")));
                      }
                    },
                  ),
                ],
              ),
            ),
          )),
      ],
    );
  }
}
