import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';

class BasicPlanSettingsScreen extends StatefulWidget {
  const BasicPlanSettingsScreen({super.key});

  @override
  State<BasicPlanSettingsScreen> createState() => _BasicPlanSettingsScreenState();
}

class _BasicPlanSettingsScreenState extends State<BasicPlanSettingsScreen> {
  final _dailyCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();
  
  // Standard Plan Controllers
  final _monthlyStandardCtrl = TextEditingController();
  final _yearlyStandardCtrl = TextEditingController();
  final _adminUpiCtrl = TextEditingController();

  // Addon Rate Controllers
  final _customerRateCtrl = TextEditingController();
  final _franchiseRateCtrl = TextEditingController();
  final _catalogRateCtrl = TextEditingController();
  final _employeeRateCtrl = TextEditingController();
  final _supplierRateCtrl = TextEditingController();
  final _kdsRateCtrl = TextEditingController();
  final _tableRateCtrl = TextEditingController();
  final _dataCenterRateCtrl = TextEditingController();
  final _integrationHubRateCtrl = TextEditingController();

  String _syncFrequency = '1_DAY';
  int _retentionDays = 30;

  bool _isLoading = true;
  bool _isConfigLocked = true;
  bool _hasSecurityPassword = false;

  Map<String, bool> _addonVisibility = {};

  @override
  void initState() {
    super.initState();
    _loadLimits();
  }

  Future<void> _loadLimits() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    
    // 1. Load Platform Limits
    final limits = await provider.retrievePlatformLimits();
    _dailyCtrl.text = limits['daily'].toString();
    _monthlyCtrl.text = limits['monthly'].toString();
    
    // Load Rates
    _customerRateCtrl.text = (limits['rate_customer_management'] ?? 0).toString();
    _franchiseRateCtrl.text = (limits['rate_franchise_management'] ?? 0).toString();
    _catalogRateCtrl.text = (limits['rate_central_catalog'] ?? 0).toString();
    _employeeRateCtrl.text = (limits['rate_employee_management'] ?? 0).toString();
    _supplierRateCtrl.text = (limits['rate_supplier_management'] ?? 0).toString();
    _kdsRateCtrl.text = (limits['rate_kds_management'] ?? 0).toString();
    _tableRateCtrl.text = (limits['rate_table_reservation'] ?? 0).toString();
    _dataCenterRateCtrl.text = (limits['rate_data_center'] ?? 0).toString();
    _integrationHubRateCtrl.text = (limits['rate_integration_hub'] ?? 0).toString();
    
    _syncFrequency = limits['sync_frequency_str'] ?? '1_DAY';
    _retentionDays = limits['cloud_retention_days'] ?? 30;

    // 2. Load Standard Plan Config
    final adminConfig = await provider.fetchAdminConfig();
    _adminUpiCtrl.text = adminConfig['adminUpiId'] ?? '';
    _monthlyStandardCtrl.text = (adminConfig['standardPlanMonthlyPrice'] ?? 0).toString();
    _yearlyStandardCtrl.text = (adminConfig['standardPlanYearlyPrice'] ?? 0).toString();
    _hasSecurityPassword = adminConfig['adminSecurityPassword'] != null;

    final List<dynamic> disabledAddonsList = adminConfig['disabledAddons'] ?? [];
    final disabledAddons = Set<String>.from(disabledAddonsList.map((e) => e.toString()));

    _addonVisibility = {
      'employee_management': !disabledAddons.contains('employee_management'),
      'table_reservation': !disabledAddons.contains('table_reservation'),
      'supplier_management': !disabledAddons.contains('supplier_management'),
      'kds_management': !disabledAddons.contains('kds_management'),
      'franchise_management': !disabledAddons.contains('franchise_management'),
      'central_catalog': !disabledAddons.contains('central_catalog'),
      'customer_management': !disabledAddons.contains('customer_management'),
      'data_center': !disabledAddons.contains('data_center'),
      'integration_hub': !disabledAddons.contains('integration_hub'),
    };

    setState(() => _isLoading = false);
  }

  Future<void> _unlockConfig() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    
    if (!_hasSecurityPassword) {
      // Setup Initial Password
      final newPass = await _showPasswordDialog(title: "Setup Security Password", isSetup: true);
      if (newPass != null && newPass.isNotEmpty) {
        await provider.updateAdminConfig({}, newSecurityPassword: newPass);
        if (!mounted) return;
        setState(() { _hasSecurityPassword = true; _isConfigLocked = false; });
        messenger.showSnackBar(const SnackBar(content: Text("Security Password Setup Successfully!")));
      }
      return;
    }

    // Verify Password
    final pass = await _showPasswordDialog(title: "Unlock Standard Settings");
    if (pass != null) {
      final isValid = await provider.verifyAdminSecurityPassword(pass);
      if (!mounted) return;
      if (isValid) {
        setState(() => _isConfigLocked = false);
      } else {
        messenger.showSnackBar(const SnackBar(content: Text("Incorrect Security Password"), backgroundColor: Colors.red));
      }
    }
  }

  Future<String?> _showPasswordDialog({required String title, bool isSetup = false}) async {
    final ctrl = TextEditingController();
    final ctrl2 = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: InputDecoration(labelText: isSetup ? "New Password" : "Enter Password"),
            ),
            if (isSetup) ...[
              const SizedBox(height: 10),
              TextField(
                controller: ctrl2,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Confirm Password"),
              ),
            ]
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              if (isSetup && ctrl.text != ctrl2.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
                return;
              }
              Navigator.pop(ctx, ctrl.text);
            },
            child: Text(isSetup ? "SETUP" : "UNLOCK"),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final daily = int.tryParse(_dailyCtrl.text) ?? 50;
    final monthly = int.tryParse(_monthlyCtrl.text) ?? 1000;
    
    // Parse Rates
    final limits = {
       'daily': daily,
       'monthly': monthly,
       'rate_customer_management': int.tryParse(_customerRateCtrl.text) ?? 0,
       'rate_franchise_management': int.tryParse(_franchiseRateCtrl.text) ?? 0,
       'rate_central_catalog': int.tryParse(_catalogRateCtrl.text) ?? 0,
       'rate_employee_management': int.tryParse(_employeeRateCtrl.text) ?? 0,
       'rate_supplier_management': int.tryParse(_supplierRateCtrl.text) ?? 0,
       'rate_kds_management': int.tryParse(_kdsRateCtrl.text) ?? 0,
       'rate_table_reservation': int.tryParse(_tableRateCtrl.text) ?? 0,
       'rate_data_center': int.tryParse(_dataCenterRateCtrl.text) ?? 0,
       'rate_integration_hub': int.tryParse(_integrationHubRateCtrl.text) ?? 0,
       'sync_frequency_str': _syncFrequency,
       'cloud_retention_days': _retentionDays,
    };
    
    setState(() => _isLoading = true);
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    
    await provider.updatePlatformLimits(limits);

    // Save Admin Config if unlocked
    if (!_isConfigLocked) {
      final upiId = _adminUpiCtrl.text.trim();
      if (upiId.isEmpty) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Super Admin UPI ID cannot be empty"), backgroundColor: Colors.red));
           setState(() => _isLoading = false);
        }
        return;
      }

      final config = {
        'adminUpiId': upiId,
        'standardPlanMonthlyPrice': double.tryParse(_monthlyStandardCtrl.text) ?? 0.0,
        'standardPlanYearlyPrice': double.tryParse(_yearlyStandardCtrl.text) ?? 0.0,
        'disabledAddons': provider.globalDisabledAddons,
      };
      await provider.updateAdminConfig(config);
    }

    if (mounted) {
       setState(() {
         _isLoading = false;
         _isConfigLocked = true; // Lock again after save
       });
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Settings Updated!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(title: const Text("Subscription & Limits")),
          body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
            child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                 // --- STANDARD PLAN CONFIG ---
                 Container(
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                     color: _isConfigLocked ? Colors.grey.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.05),
                     borderRadius: BorderRadius.circular(12),
                     border: Border.all(color: _isConfigLocked ? Colors.grey.shade300 : Colors.green.shade200),
                   ),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           const Text("Standard Plan & Payments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                           if (_isConfigLocked)
                             Tooltip(
                               message: "Click to unlock settings",
                               child: IconButton(onPressed: _unlockConfig, icon: const Icon(Icons.lock_outline, color: Colors.orange)),
                             )
                           else
                             const Icon(Icons.lock_open, color: Colors.green),
                         ],
                       ),
                       const SizedBox(height: 16),
                       AbsorbPointer(
                         absorbing: _isConfigLocked,
                         child: Opacity(
                           opacity: _isConfigLocked ? 0.6 : 1.0,
                           child: Column(
                             children: [
                               TextField(
                                 controller: _adminUpiCtrl,
                                 decoration: const InputDecoration(labelText: "Super Admin UPI ID", border: OutlineInputBorder(), prefixIcon: Icon(Icons.qr_code), helperText: "UPI ID for receiving payments"),
                               ),
                               const SizedBox(height: 16),
                               Row(
                                 children: [
                                   Expanded(child: _buildRateField("Monthly Price", _monthlyStandardCtrl, "/ month")),
                                   const SizedBox(width: 16),
                                   Expanded(child: _buildRateField("Yearly Price", _yearlyStandardCtrl, "/ year")),
                                 ],
                               ),
                             ],
                           ),
                         ),
                       ),
                     ],
                   ),
                 ),
                 const SizedBox(height: 32),
                 const Divider(),
                 const SizedBox(height: 16),
    
                 const Text("Basic Plan Limits", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 8),
                 const Text("Set default limits for all stores on the Basic Plan.", style: TextStyle(color: Colors.grey)),
                 const SizedBox(height: 20),
                 TextField(
                   controller: _dailyCtrl,
                   decoration: const InputDecoration(labelText: "Max Orders Per Day", border: OutlineInputBorder(), helperText: "e.g. 50"),
                   keyboardType: TextInputType.number,
                 ),
                 const SizedBox(height: 16),
                  TextField(
                   controller: _monthlyCtrl,
                   decoration: const InputDecoration(labelText: "Max Orders Per Month", border: OutlineInputBorder(), helperText: "e.g. 1000"),
                   keyboardType: TextInputType.number,
                 ),
                 const SizedBox(height: 24),
                 
                 // SYNC FREQUENCY
                 DropdownButtonFormField<String>(
                    value: _syncFrequency,
                    decoration: const InputDecoration(labelText: "Cloud Sync Frequency (Basic Plan)", border: OutlineInputBorder(), helperText: "How often Basic stores sync with cloud"),
                    items: const [
                       DropdownMenuItem(value: '1_DAY', child: Text("1 Day")),
                       DropdownMenuItem(value: '1_WEEK', child: Text("1 Week")),
                       DropdownMenuItem(value: '1_MONTH', child: Text("1 Month")),
                    ],
                    onChanged: (val) {
                       if (val != null) setState(() => _syncFrequency = val);
                    },
                 ),
                 const SizedBox(height: 16),
                 
                 // CLOUD RETENTION
                 DropdownButtonFormField<int>(
                    value: _retentionDays,
                    decoration: const InputDecoration(labelText: "Cloud Data Retention (Basic Plan)", border: OutlineInputBorder(), helperText: "Data older than this will be removed from Cloud"),
                    items: const [
                       DropdownMenuItem(value: 30, child: Text("30 Days")),
                       DropdownMenuItem(value: 90, child: Text("3 Months")),
                       DropdownMenuItem(value: 180, child: Text("6 Months")),
                       DropdownMenuItem(value: 365, child: Text("1 Year")),
                    ],
                    onChanged: (val) {
                       if (val != null) setState(() => _retentionDays = val);
                    },
                 ),
                 
                 const Text("Add-on Monthly Rates (INR)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 8),
                 const Text("Set the monthly cost for each add-on module.", style: TextStyle(color: Colors.grey)),
                 const SizedBox(height: 20),
    
                 const Divider(),
                 const SizedBox(height: 24),
    
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     const Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text("Global Module Availability", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                         Text("Disable modules platform-wide.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                       ],
                     ),
                     if (_isConfigLocked)
                       GestureDetector(
                         onTap: _unlockConfig,
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                           decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
                           child: const Row(
                             children: [
                               Icon(Icons.lock_outline, size: 14, color: Colors.orange),
                               SizedBox(width: 4),
                               Text("Unlock to Change", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                             ],
                           ),
                         ),
                       ),
                   ],
                 ),
                 const SizedBox(height: 16),
                 
                 AbsorbPointer(
                   absorbing: _isConfigLocked,
                   child: Opacity(
                     opacity: _isConfigLocked ? 0.6 : 1.0,
                     child: Column(
                       children: _addonVisibility.keys.map((key) {
                         final bool isEnabled = !provider.globalDisabledAddons.contains(key);
                         TextEditingController ctrl;
                         switch(key) {
                            case 'employee_management': ctrl = _employeeRateCtrl; break;
                            case 'table_reservation': ctrl = _tableRateCtrl; break;
                            case 'supplier_management': ctrl = _supplierRateCtrl; break;
                            case 'kds_management': ctrl = _kdsRateCtrl; break;
                            case 'franchise_management': ctrl = _franchiseRateCtrl; break;
                            case 'central_catalog': ctrl = _catalogRateCtrl; break;
                            case 'customer_management': ctrl = _customerRateCtrl; break;
                            case 'data_center': ctrl = _dataCenterRateCtrl; break;
                            case 'integration_hub': ctrl = _integrationHubRateCtrl; break;
                            default: ctrl = TextEditingController();
                         }
                         
                         return Container(
                           margin: const EdgeInsets.only(bottom: 16),
                           decoration: BoxDecoration(
                             color: isEnabled ? Colors.green.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05),
                             border: Border.all(color: isEnabled ? Colors.green.withValues(alpha: 0.2) : Colors.grey.shade300),
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: Column(
                             children: [
                               SwitchListTile(
                                 title: Text(_getAddonName(key), style: const TextStyle(fontWeight: FontWeight.bold)),
                                 subtitle: Text("ID: $key", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                 value: isEnabled,
                                 activeColor: Colors.green,
                                 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                 onChanged: (val) async {
                                   try {
                                     await provider.toggleGlobalAddon(key, val);
                                     if (context.mounted) {
                                       ScaffoldMessenger.of(context).showSnackBar(
                                         SnackBar(content: Text("${_getAddonName(key)} has been ${val ? 'Enabled' : 'Disabled'} globally."), duration: const Duration(seconds: 1)),
                                       );
                                     }
                                   } catch (e) {
                                     if (context.mounted) {
                                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                                     }
                                   }
                                 },
                               ),
                               if (isEnabled)
                                 Padding(
                                   padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                   child: Row(
                                     children: [
                                       const Expanded(
                                          flex: 2,
                                          child: Text("Monthly Rate", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                                       ),
                                       Expanded(
                                          flex: 3,
                                          child: TextField(
                                            controller: ctrl,
                                            decoration: const InputDecoration(
                                              prefixText: "₹ ",
                                              suffixText: " / month",
                                              isDense: true,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                              border: OutlineInputBorder(),
                                            ),
                                            keyboardType: TextInputType.number,
                                          ),
                                       )
                                     ],
                                   ),
                                 ),
                             ],
                           ),
                         );
                       }).toList(),
                     ),
                   ),
                 ),
    
                 const SizedBox(height: 24),
                 SizedBox(
                   width: double.infinity,
                   child: ElevatedButton(
                     style: ElevatedButton.styleFrom(
                       padding: const EdgeInsets.symmetric(vertical: 16),
                       backgroundColor: Theme.of(context).primaryColor,
                       foregroundColor: Colors.white,
                     ),
                     onPressed: _save, 
                     child: const Text("SAVE ALL SETTINGS", style: TextStyle(fontWeight: FontWeight.bold))
                   ),
                 ),
              ],
            ),
          ),
          ),
        );
      }
    );
  }
  
  Widget _buildRateField(String label, TextEditingController ctrl, String suffix) {
     return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
           controller: ctrl,
           decoration: InputDecoration(
              labelText: label,
              prefixText: "₹ ",
              border: const OutlineInputBorder(),
              suffixText: suffix
           ),
           keyboardType: TextInputType.number,
        ),
     );
  }

  String _getAddonName(String key) {
    switch (key) {
      case 'employee_management': return 'Employee Management';
      case 'table_reservation': return 'Table Reservation';
      case 'supplier_management': return 'Supplier Management';
      case 'kds_management': return 'KDS / Display Integration';
      case 'franchise_management': return 'Franchise Management';
      case 'central_catalog': return 'Central Catalogue';
      case 'customer_management': return 'Customer Management';
      case 'data_center': return 'Data Center';
      case 'integration_hub': return 'Integration Hub';
      default: return key;
    }
  }
}
