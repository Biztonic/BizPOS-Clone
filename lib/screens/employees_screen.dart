import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../models/user_profile.dart';
import '../l10n/app_localizations.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/components/atoms/app_button.dart';
import '../core/design/components/atoms/app_card.dart';
import '../core/design/components/atoms/app_text_field.dart';
import '../core/design/components/organisms/pos_data_table.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';
import '../core/design/tokens/app_colors.dart';
import '../core/design/density/app_density.dart';

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
              title: Text(
                employee == null ? 'Create Employee' : 'Edit Role',
                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (employee == null) ...[
                      AppTextField(
                        controller: nameController,
                        label: 'Full Name',
                        hintText: 'e.g. John Doe',
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: pinController,
                        label: '4-Digit PIN',
                        hintText: 'Used for login',
                        prefixIcon: const Icon(Icons.lock_outline),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    DropdownButtonFormField<String>(
                      value: validSelection,
                      items: validRoles.map((r) => DropdownMenuItem(value: r.name, child: Text(r.name))).toList(),
                      onChanged: (v) {
                         setState(() {
                            roleController.text = v!;
                         });
                      },
                      decoration: InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("Cancel", style: TextStyle(color: AppColors.textSecondary(context))),
                ),
                AppButton.primary(
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
                  label: "Save",
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
    final provider = Provider.of<DashboardProvider>(context);
    final isDesktop = MediaQuery.of(context).size.width >= 1100;
    
    return PosScaffold(
      title: AppLocalizations.t(context, 'employees'),
      actions: [
        AppButton.primary(
          label: isDesktop ? "Add Employee" : null,
          icon: Icons.add,
          onPressed: () => _showEmployeeDialog(context),
        ),
      ],
      mainContent: provider.isLoading 
          ? const Center(child: CircularProgressIndicator())
          : isDesktop 
              ? _buildTableView(context, provider)
              : _buildListView(context, provider),
    );
  }

  Widget _buildListView(BuildContext context, DashboardProvider provider) {
    final employees = provider.employees;
    if (employees.isEmpty) return _buildEmptyState();

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: employees.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (ctx, i) => _buildEmployeeCard(context, employees[i], provider),
    );
  }

  Widget _buildTableView(BuildContext context, DashboardProvider provider) {
    final employees = provider.employees;
    if (employees.isEmpty) return _buildEmptyState();

    return PosDataTable(
      columns: [
        const PosDataColumn(label: 'Employee', fixedWidth: 300),
        const PosDataColumn(label: 'Role', fixedWidth: 150),
        const PosDataColumn(label: 'ID', fixedWidth: 150),
        const PosDataColumn(label: 'Actions', fixedWidth: 200),
      ],
      rows: employees.map((emp) => PosDataRow(
        cells: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  emp.name.isNotEmpty ? emp.name[0] : '?',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(emp.name, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(emp.role, style: AppTypography.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          Text(emp.employeeId ?? 'N/A', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context), fontFamily: 'monospace')),
          Row(
            children: [
              AppButton.secondary(
                icon: Icons.edit,
                onPressed: () => _showEmployeeDialog(context, employee: emp),
              ),
              const SizedBox(width: AppSpacing.xs),
              AppButton.danger(
                icon: Icons.delete_outline,
                onPressed: () => _confirmDelete(context, provider, emp),
              ),
            ],
          ),
        ],
      )).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: AppColors.border(context)),
          const SizedBox(height: AppSpacing.md),
          Text(
            "No employees found",
            style: AppTypography.titleLarge.copyWith(color: AppColors.textSecondary(context)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Tap + to add your first staff member.",
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(BuildContext context, UserProfile emp, DashboardProvider provider) {
    final density = AppDensityProvider.configOf(context);
    return AppCard(
      padding: EdgeInsets.all(density.cardPadding),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(
            emp.name.isNotEmpty ? emp.name[0] : '?',
            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(emp.name, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text(
          "${emp.role} • ID: ${emp.employeeId ?? 'N/A'}",
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton.secondary(
              icon: Icons.edit,
              onPressed: () => _showEmployeeDialog(context, employee: emp),
            ),
            const SizedBox(width: AppSpacing.xs),
            AppButton.danger(
              icon: Icons.delete_outline,
              onPressed: () => _confirmDelete(context, provider, emp),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, DashboardProvider provider, UserProfile emp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("Delete Employee", style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
        content: Text(
          "Are you sure you want to remove ${emp.name}? This action is permanent.",
          style: AppTypography.bodyMedium,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text("Cancel", style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          AppButton.danger(
            onPressed: () => Navigator.pop(c, true),
            label: "Delete",
          ),
        ],
      ),
    );
    if (confirm == true) {
      await provider.removeEmployee(emp.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${emp.name} removed"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
