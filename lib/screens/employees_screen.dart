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
import '../core/design/design_system.dart';

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
              backgroundColor: AppColors.surface(context),
              title: Text(
                employee == null ? 'Create Employee' : 'Edit Role',
                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
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
                      dropdownColor: AppColors.surface(context),
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary(context)),
                      decoration: InputDecoration(
                        labelText: 'Role',
                        labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.borderMd,
                          borderSide: BorderSide(color: AppColors.border(context)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppRadius.borderMd,
                          borderSide: BorderSide(color: AppColors.border(context)),
                        ),
                        prefixIcon: Icon(Icons.badge_outlined, color: AppColors.adaptivePrimary(context)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.t(context, 'Cancel'), style: TextStyle(color: AppColors.textSecondary(context))),
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
          : CustomScrollView(
              slivers: [
                if (provider.employees.isEmpty)
                  SliverFillRemaining(child: _buildEmptyState())
                else if (isDesktop)
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    sliver: SliverToBoxAdapter(child: _buildTableView(context, provider)),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _buildEmployeeCard(context, provider.employees[i], provider),
                        ),
                        childCount: provider.employees.length,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildTableView(BuildContext context, DashboardProvider provider) {
    final employees = provider.employees;

    return PosDataTable(
      columns: const [
        PosDataColumn(label: 'Employee', fixedWidth: 300),
        PosDataColumn(label: 'Role', fixedWidth: 150),
        PosDataColumn(label: 'ID', fixedWidth: 150),
        PosDataColumn(label: 'Actions', fixedWidth: 200),
      ],
      rows: employees.map((emp) => PosDataRow(
        cells: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.adaptivePrimary(context).withValues(alpha: 0.1),
                child: Text(
                  emp.name.isNotEmpty ? emp.name[0] : '?',
                  style: TextStyle(color: AppColors.adaptivePrimary(context), fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(emp.name, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.adaptivePrimary(context).withValues(alpha: 0.1),
              borderRadius: AppRadius.borderSm,
            ),
            child: Text(emp.role, style: AppTypography.labelSmall.copyWith(color: AppColors.adaptivePrimary(context), fontWeight: FontWeight.bold)),
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
          Text(AppLocalizations.t(context, 'No employees found'),
            style: AppTypography.titleLarge.copyWith(color: AppColors.textSecondary(context)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(AppLocalizations.t(context, 'Tap + to add your first staff member.'),
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
          backgroundColor: AppColors.adaptivePrimary(context).withValues(alpha: 0.1),
          child: Text(
            emp.name.isNotEmpty ? emp.name[0] : '?',
            style: TextStyle(color: AppColors.adaptivePrimary(context), fontWeight: FontWeight.bold),
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
        backgroundColor: AppColors.surface(context),
        title: Text(AppLocalizations.t(context, 'Delete Employee'), style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
        content: Text(
          "Are you sure you want to remove ${emp.name}? This action is permanent.",
          style: AppTypography.bodyMedium,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(AppLocalizations.t(context, 'Cancel'), style: TextStyle(color: AppColors.textSecondary(context))),
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




