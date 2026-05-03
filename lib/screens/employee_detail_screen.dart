import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../models/user_profile.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/components/atoms/app_card.dart';
import '../core/design/components/atoms/app_button.dart';
import '../core/design/components/atoms/app_text_field.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';
import '../core/design/tokens/app_colors.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final UserProfile employee;
  const EmployeeDetailScreen({super.key, required this.employee});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  late Map<String, bool> _permissions;
  late List<String> _accessibleAddons;
  late String _preferredTheme;
  final _hourlyCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _permissions = Map<String, bool>.from(widget.employee.permissions ?? {
      'pos': true,
      'inventory': false,
      'reports': false,
      'settings': false,
      'employees': false,
      'crm': false,
    });
    _accessibleAddons = List<String>.from(widget.employee.accessibleAddons ?? []);
    _preferredTheme = widget.employee.preferredTheme ?? 'standard';
    _hourlyCtrl.text = widget.employee.hourlyRate?.toString() ?? '0.0';
    _salaryCtrl.text = widget.employee.monthlySalary?.toString() ?? '0.0';
    
    // Fetch History
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      provider.fetchAttendance(widget.employee.uid);
      provider.fetchPayroll(widget.employee.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);

    return PosScaffold(
      title: widget.employee.name,
      actions: [
        AppButton.primary(
          icon: Icons.save,
          label: "Save",
          onPressed: () async {
            await provider.updateEmployeePermissions(
              widget.employee.uid, 
              _permissions,
              accessibleAddons: _accessibleAddons,
              preferredTheme: _preferredTheme,
            );
            await provider.updateEmployeeRates(
              widget.employee.uid,
              hourlyRate: double.tryParse(_hourlyCtrl.text),
              monthlySalary: double.tryParse(_salaryCtrl.text),
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Profile Updated"), behavior: SnackBarBehavior.floating),
            );
          },
        ),
      ],
      mainContent: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: AppSpacing.lg),
            _buildPayrollSection(),
            const SizedBox(height: AppSpacing.lg),
            _buildHistoryTabs(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              widget.employee.name[0].toUpperCase(), 
              style: AppTypography.headlineSmall.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.employee.name, style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "Role: ${widget.employee.role} • ID: ${widget.employee.employeeId}",
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Payroll Configuration", style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _hourlyCtrl,
                  label: "Hourly Rate",
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.access_time),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField(
                  controller: _salaryCtrl,
                  label: "Monthly Salary",
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTabs() {
    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            tabs: const [
              Tab(text: "Attendance"),
              Tab(text: "Payroll"),
            ],
            labelColor: AppColors.primary,
          ),
          SizedBox(
            height: 300,
            child: TabBarView(
              children: [
                _buildAttendanceHistory(),
                _buildPayrollHistory(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceHistory() {
    final provider = Provider.of<DashboardProvider>(context);
    final records = provider.attendanceRecords.where((r) => r['employeeId'] == widget.employee.uid).toList();

    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: AppColors.border(context)),
            const SizedBox(height: AppSpacing.sm),
            Text("No attendance records", style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: records.length,
      itemBuilder: (context, index) {
        final rec = records[index];
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.history, color: AppColors.primary, size: 20),
          ),
          title: Text("In: ${rec['checkIn']}", style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text("Out: ${rec['checkOut'] ?? 'Active'}", style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
        );
      },
    );
  }

  Widget _buildPayrollHistory() {
    final provider = Provider.of<DashboardProvider>(context);
    final records = provider.payrollRecords.where((r) => r['employeeId'] == widget.employee.uid).toList();

    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payments_outlined, size: 48, color: AppColors.border(context)),
            const SizedBox(height: AppSpacing.sm),
            Text("No payroll records", style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: records.length,
      itemBuilder: (context, index) {
        final rec = records[index];
        return ListTile(
          title: Text("Period: ${rec['periodStart'].split('T')[0]}", style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          trailing: Text("${rec['totalAmount']}", style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.success)),
        );
      },
    );
  }
}
