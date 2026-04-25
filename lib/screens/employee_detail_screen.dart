import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import 'package:biztonic_pos/models/user_profile.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employee.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated")));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildPayrollSection(),
            const SizedBox(height: 24),
            _buildHistoryTabs(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 30,
          backgroundColor: Colors.blue.shade50,
          child: Text(widget.employee.name[0].toUpperCase(), style: const TextStyle(fontSize: 24)),
        ),
        title: Text(widget.employee.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        subtitle: Text("Role: ${widget.employee.role} • ID: ${widget.employee.employeeId}"),
      ),
    );
  }

  Widget _buildPayrollSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Payroll Configuration", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hourlyCtrl,
                    decoration: const InputDecoration(labelText: "Hourly Rate", border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _salaryCtrl,
                    decoration: const InputDecoration(labelText: "Monthly Salary", border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
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
          const TabBar(
            tabs: [
              Tab(text: "Attendance"),
              Tab(text: "Payroll"),
            ],
            labelColor: Colors.blue,
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

    return ListView.builder(
      itemCount: records.length,
      itemBuilder: (context, index) {
        final rec = records[index];
        return ListTile(
          leading: const Icon(Icons.history),
          title: Text("In: ${rec['checkIn']}"),
          subtitle: Text("Out: ${rec['checkOut'] ?? 'Active'}"),
        );
      },
    );
  }

  Widget _buildPayrollHistory() {
    final provider = Provider.of<DashboardProvider>(context);
    final records = provider.payrollRecords.where((r) => r['employeeId'] == widget.employee.uid).toList();

    return ListView.builder(
      itemCount: records.length,
      itemBuilder: (context, index) {
        final rec = records[index];
        return ListTile(
          title: Text("Period: ${rec['periodStart'].split('T')[0]}"),
          trailing: Text("${rec['totalAmount']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        );
      },
    );
  }
}
