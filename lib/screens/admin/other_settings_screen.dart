import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:provider/provider.dart';
import 'package:biztonic_pos/providers/store_provider.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import 'package:kiosk_mode/kiosk_mode.dart';
import '../../core/config/store_type_config.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/tokens/app_radius.dart';

class OtherSettingsScreen extends StatefulWidget {
  const OtherSettingsScreen({super.key});

  @override
  State<OtherSettingsScreen> createState() => _OtherSettingsScreenState();
}

class _OtherSettingsScreenState extends State<OtherSettingsScreen> {
  final _textCtrl = TextEditingController();
  List<String> _types = [];
  Map<String, dynamic> _typeConfigs = {};
  bool _isLoading = true;
  bool _isKioskMode = false;
  String _statusMessage = "";

  // New Type Config Peripheral Feature Flags
  bool _isKitchenEnabled = false;
  bool _isTablesEnabled = false;
  bool _isBarcodeEnabled = false;
  bool _isCustomersEnabled = false;
  bool _isEmployeesEnabled = false;
  bool _isSuppliersEnabled = false;
  bool _isDataSyncEnabled = false;
  bool _isDietaryEnabled = false;
  bool _isPackagingEnabled = false;
  bool _isVariantsEnabled = false;


  void _clearAllFeatures() {
    setState(() {
      _isKitchenEnabled = false;
      _isTablesEnabled = false;
      _isBarcodeEnabled = false;
      _isCustomersEnabled = false;
      _isEmployeesEnabled = false;
      _isSuppliersEnabled = false;
      _isDataSyncEnabled = false;
      _isDietaryEnabled = false;
      _isPackagingEnabled = false;
      _isVariantsEnabled = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadTypes();
    _checkKioskMode();
  }

  Future<void> _checkKioskMode() async {
    final mode = await getKioskMode();
    if (context.mounted) {
      setState(() {
        _isKioskMode = mode == KioskMode.enabled;
      });
    }
  }

  Future<void> _toggleKioskMode(bool enable) async {
    setState(() => _statusMessage = "Processing...");
    try {
      if (enable) {
        await startKioskMode();
      } else {
        await stopKioskMode();
      }
      if (!mounted) return;

      // PERSIST STATE (For Auto-Lock on Reboot)
      final provider = Provider.of<StoreProvider>(context, listen: false);
      provider.saveKioskPreference(enable);

      await _checkKioskMode();
      setState(
          () => _statusMessage = enable ? "Device Locked" : "Device Unlocked");
    } catch (e) {
      setState(() => _statusMessage = "Error: $e");
    }
  }

  Future<void> _loadTypes() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<StoreProvider>(context, listen: false);
    final types = await provider.fetchStoreTypes();
    final configs = await provider.fetchStoreTypeConfigs();

    if (mounted) {
      setState(() {
        _types = types;
        _typeConfigs = configs;
        _isLoading = false;
      });
    }
  }

  Future<void> _addType() async {
    if (_textCtrl.text.isEmpty) return;
    final newType = _textCtrl.text.trim();
    if (_types.contains(newType)) return;

    final config = {
      'enableKitchen': _isKitchenEnabled,
      'enableTables': _isTablesEnabled,
      'enableBarcode': _isBarcodeEnabled,
      'enableCustomers': _isCustomersEnabled,
      'enableEmployees': _isEmployeesEnabled,
      'enableSuppliers': _isSuppliersEnabled,
      'enableDataSync': _isDataSyncEnabled,
      'enableDietary': _isDietaryEnabled,
      'enablePackaging': _isPackagingEnabled,
      'enableVariants': _isVariantsEnabled,
      // Canonical keys for feature checks
      'kds_management': _isKitchenEnabled,
      'table_reservation': _isTablesEnabled,
      'barcode_scanner': _isBarcodeEnabled,
      'customer_management': _isCustomersEnabled,
      'employee_management': _isEmployeesEnabled,
      'supplier_management': _isSuppliersEnabled,
      'data_center': _isDataSyncEnabled,
    };

    setState(() {
      _types.add(newType);
      _typeConfigs[newType] = config;
    });

    final toAdd = _textCtrl.text.trim();
    _textCtrl.clear();
    _clearAllFeatures();

    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final dashboard = Provider.of<DashboardProvider>(context, listen: false);
    await storeProvider.addStoreType(toAdd, initialConfig: config);
    try {
      await dashboard.saveStoreTypeConfig(toAdd, config);
    } catch (_) {}
  }

  Future<void> _editType(String oldType) async {
    final ctrl = TextEditingController(text: oldType);
    final rawConfig = _typeConfigs[oldType] as Map?;
    final config = rawConfig != null
        ? Map<String, dynamic>.from(rawConfig)
        : StoreTypeConfig.getDefaultConfig(oldType);

    bool kitchenEnabled =
        config['enableKitchen'] == true || config['kds_management'] == true;
    bool tablesEnabled =
        config['enableTables'] == true || config['table_reservation'] == true;
    bool barcodeEnabled =
        config['enableBarcode'] == true || config['barcode_scanner'] == true;
    bool customersEnabled =
        config['enableCustomers'] == true || config['customer_management'] == true;
    bool employeesEnabled =
        config['enableEmployees'] == true || config['employee_management'] == true;
    bool suppliersEnabled =
        config['enableSuppliers'] == true || config['supplier_management'] == true;
    bool dataSyncEnabled =
        config['enableDataSync'] == true || config['data_center'] == true;
    bool dietaryEnabled = config['enableDietary'] == true;
    bool packagingEnabled = config['enablePackaging'] == true;
    bool variantsEnabled = config['enableVariants'] == true;

    // Using StatefulBuilder to handle dialog state update for Checkboxes
    await showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(AppLocalizations.t(context, 'Edit Store Type')),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                          controller: ctrl,
                          decoration:
                              const InputDecoration(labelText: "Store Type Name")),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: AppRadius.borderSm,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: AppColors.primary, size: 18),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                AppLocalizations.t(context,
                                    'Core features (POS, Inventory, Sales, Reports) are always enabled.'),
                                style: AppTypography.labelSmall
                                    .copyWith(color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              kitchenEnabled = false;
                              tablesEnabled = false;
                              barcodeEnabled = false;
                              customersEnabled = false;
                              employeesEnabled = false;
                              suppliersEnabled = false;
                              dataSyncEnabled = false;
                              dietaryEnabled = false;
                              packagingEnabled = false;
                              variantsEnabled = false;
                            });
                          },
                          icon: const Icon(Icons.clear_all, size: 16),
                          label: const Text('Clear All',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ),
                      const Divider(height: AppSpacing.sm),
                      Text("Operational Features",
                          style: AppTypography.bodySmall
                              .copyWith(fontWeight: FontWeight.bold)),
                      CheckboxListTile(
                        dense: true,
                        title:
                            Text(AppLocalizations.t(context, 'Kitchen & KDS')),
                        subtitle: const Text(
                            'Kitchen display system & order routing',
                            style: TextStyle(fontSize: 11)),
                        value: kitchenEnabled,
                        onChanged: (val) =>
                            setDialogState(() => kitchenEnabled = val ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        dense: true,
                        title:
                            Text(AppLocalizations.t(context, 'Tables & Dining')),
                        subtitle: const Text(
                            'Dining floor plans and table reservations',
                            style: TextStyle(fontSize: 11)),
                        value: tablesEnabled,
                        onChanged: (val) =>
                            setDialogState(() => tablesEnabled = val ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        dense: true,
                        title:
                            Text(AppLocalizations.t(context, 'Barcode Scanner')),
                        subtitle: const Text(
                            'Hardware barcode scanning & lookup',
                            style: TextStyle(fontSize: 11)),
                        value: barcodeEnabled,
                        onChanged: (val) =>
                            setDialogState(() => barcodeEnabled = val ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(height: AppSpacing.md),
                      Text("Management & CRM Features",
                          style: AppTypography.bodySmall
                              .copyWith(fontWeight: FontWeight.bold)),
                      CheckboxListTile(
                        dense: true,
                        title: Text(AppLocalizations.t(
                            context, 'Customer CRM & Khata')),
                        subtitle: const Text(
                            'Customer ledger, Udhari credit & loyalty',
                            style: TextStyle(fontSize: 11)),
                        value: customersEnabled,
                        onChanged: (val) => setDialogState(
                            () => customersEnabled = val ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        dense: true,
                        title: Text(
                            AppLocalizations.t(context, 'Staff & Attendance')),
                        subtitle: const Text(
                            'Staff profiles & attendance tracking',
                            style: TextStyle(fontSize: 11)),
                        value: employeesEnabled,
                        onChanged: (val) => setDialogState(
                            () => employeesEnabled = val ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        dense: true,
                        title: Text(AppLocalizations.t(
                            context, 'Suppliers & Purchase')),
                        subtitle: const Text(
                            'Supplier accounts & purchase orders',
                            style: TextStyle(fontSize: 11)),
                        value: suppliersEnabled,
                        onChanged: (val) => setDialogState(
                            () => suppliersEnabled = val ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        dense: true,
                        title: Text(
                            AppLocalizations.t(context, 'Data Center & Sync')),
                        subtitle: const Text(
                            'Offline data center synchronization',
                            style: TextStyle(fontSize: 11)),
                        value: dataSyncEnabled,
                        onChanged: (val) => setDialogState(
                            () => dataSyncEnabled = val ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(height: AppSpacing.md),
                      Text("Product & Catalog Features",
                          style: AppTypography.bodySmall
                              .copyWith(fontWeight: FontWeight.bold)),
                      CheckboxListTile(
                        dense: true,
                        title: Text(AppLocalizations.t(
                            context, 'Dietary Types (Veg/Non-Veg)')),
                        value: dietaryEnabled,
                        onChanged: (val) =>
                            setDialogState(() => dietaryEnabled = val ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        dense: true,
                        title: Text(AppLocalizations.t(
                            context, 'Packaging Types & Charges')),
                        value: packagingEnabled,
                        onChanged: (val) => setDialogState(
                            () => packagingEnabled = val ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        dense: true,
                        title: Text(
                            AppLocalizations.t(context, 'Product Variants')),
                        value: variantsEnabled,
                        onChanged: (val) => setDialogState(
                            () => variantsEnabled = val ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(AppLocalizations.t(context, 'Cancel'))),
                ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final newType = ctrl.text.trim();
                      if (newType.isNotEmpty) {
                        final newConfig = {
                          'enableKitchen': kitchenEnabled,
                          'enableTables': tablesEnabled,
                          'enableBarcode': barcodeEnabled,
                          'enableCustomers': customersEnabled,
                          'enableEmployees': employeesEnabled,
                          'enableSuppliers': suppliersEnabled,
                          'enableDataSync': dataSyncEnabled,
                          'enableDietary': dietaryEnabled,
                          'enablePackaging': packagingEnabled,
                          'enableVariants': variantsEnabled,
                          'kds_management': kitchenEnabled,
                          'table_reservation': tablesEnabled,
                          'barcode_scanner': barcodeEnabled,
                          'customer_management': customersEnabled,
                          'employee_management': employeesEnabled,
                          'supplier_management': suppliersEnabled,
                          'data_center': dataSyncEnabled,
                        };

                        setState(() {
                          final index = _types.indexOf(oldType);
                          if (index != -1) _types[index] = newType;
                          _typeConfigs.remove(oldType);
                          _typeConfigs[newType] = newConfig;
                        });
                        final storeProvider = Provider.of<StoreProvider>(context, listen: false);
                        final dashboard = Provider.of<DashboardProvider>(context, listen: false);
                        await storeProvider.updateStoreType(oldType, newType,
                            config: newConfig);
                        try {
                          if (oldType != newType) {
                            await dashboard.deleteStoreTypeConfig(oldType);
                          }
                          await dashboard.saveStoreTypeConfig(
                              newType, newConfig);
                        } catch (_) {}
                      }
                    },
                    child: Text(AppLocalizations.t(context, 'Save'))),
              ],
            );
          });
        });
  }

  Future<void> _deleteType(String type) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(AppLocalizations.t(context, 'Delete Store Type?')),
              content: Text('Are you sure you want to delete "$type"?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(AppLocalizations.t(context, 'Cancel'))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(AppLocalizations.t(context, 'Delete'),
                        style: const TextStyle(color: AppColors.error))),
              ],
            ));

    if (confirm == true) {
      setState(() {
        _types.remove(type);
        _typeConfigs.remove(type);
      });
      if (!mounted) return;
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      final dashboard = Provider.of<DashboardProvider>(context, listen: false);
      await storeProvider.deleteStoreType(type);
      try {
        await dashboard.deleteStoreTypeConfig(type);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return PosScaffold(
      title: 'Other Settings',
      mainContent: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.t(context, 'Store Configuration'),
              style: AppTypography.h3,
            ),
            const SizedBox(height: AppSpacing.md),

            // Store Types Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.zero,
                        ),
                        child:
                            const Icon(Icons.store, color: AppColors.primary),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(AppLocalizations.t(context, 'Store Types'),
                          style: AppTypography.h4),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppLocalizations.t(context,
                        'Define the categories of stores available config.'),
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary(context)),
                  ),
                  const Divider(height: AppSpacing.xl),

                  // Add New Input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _textCtrl,
                              label: 'New Store Type',
                              hintText: 'e.g. Cafe, Pharmacy',
                              prefixIcon:
                                  const Icon(Icons.add_business_outlined),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 26), // Align with text field
                            child: AppButton.primary(
                              onPressed: _addType,
                              label: "Add",
                              icon: Icons.add,
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Core features banner
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: AppRadius.borderSm,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: AppColors.primary, size: 16),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                AppLocalizations.t(context,
                                    'Core features (POS, Inventory, Sales, Reports) are always enabled. Toggle additional features below:'),
                                style: AppTypography.labelSmall
                                    .copyWith(color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _clearAllFeatures,
                          icon: const Icon(Icons.clear_all, size: 16),
                          label: const Text('Clear All',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _buildCompactCheckbox("Kitchen/KDS", _isKitchenEnabled,
                              (v) => setState(() => _isKitchenEnabled = v!)),
                          _buildCompactCheckbox("Tables", _isTablesEnabled,
                              (v) => setState(() => _isTablesEnabled = v!)),
                          _buildCompactCheckbox("Barcode", _isBarcodeEnabled,
                              (v) => setState(() => _isBarcodeEnabled = v!)),
                          _buildCompactCheckbox("Customer CRM", _isCustomersEnabled,
                              (v) => setState(() => _isCustomersEnabled = v!)),
                          _buildCompactCheckbox("Staff", _isEmployeesEnabled,
                              (v) => setState(() => _isEmployeesEnabled = v!)),
                          _buildCompactCheckbox("Suppliers", _isSuppliersEnabled,
                              (v) => setState(() => _isSuppliersEnabled = v!)),
                          _buildCompactCheckbox("Data Sync", _isDataSyncEnabled,
                              (v) => setState(() => _isDataSyncEnabled = v!)),
                          _buildCompactCheckbox("Dietary", _isDietaryEnabled,
                              (v) => setState(() => _isDietaryEnabled = v!)),
                          _buildCompactCheckbox("Packaging", _isPackagingEnabled,
                              (v) => setState(() => _isPackagingEnabled = v!)),
                          _buildCompactCheckbox("Variants", _isVariantsEnabled,
                              (v) => setState(() => _isVariantsEnabled = v!)),
                        ],
                      )
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // List
                  _isLoading
                      ? const Center(
                          child: Padding(
                              padding: EdgeInsets.all(AppSpacing.xl),
                              child: CircularProgressIndicator()))
                      : _types.isEmpty
                          ? Center(
                              child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.xl),
                                  child: Text(AppLocalizations.t(
                                      context, 'No store types defined.'))))
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _types.length,
                              separatorBuilder: (ctx, i) =>
                                  const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final type = _types[i];
                                final allowed = StoreTypeConfig.getAllowedFeatures(
                                    type,
                                    storeTypeConfigs: _typeConfigs);

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.xs),
                                  title: Text(type,
                                      style: AppTypography.bodyMedium.copyWith(
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text('Core POS',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primary)),
                                        ),
                                        ...allowed.map((meta) => Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.success
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(meta.label,
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          AppColors.success)),
                                            )),
                                      ],
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 20, color: AppColors.primary),
                                        onPressed: () => _editType(type),
                                        tooltip: "Edit",
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            size: 20, color: AppColors.error),
                                        onPressed: () => _deleteType(type),
                                        tooltip: "Delete",
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            Text(
              AppLocalizations.t(context, 'Device Security'),
              style: AppTypography.h3,
            ),
            const SizedBox(height: AppSpacing.md),

            // KIOSK MODE CARD
            AppCard(
              outlined: !_isKioskMode,
              borderColor: _isKioskMode ? AppColors.success : AppColors.warning,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                            color: (_isKioskMode
                                    ? AppColors.success
                                    : AppColors.warning)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.zero),
                        child: Icon(_isKioskMode ? Icons.lock : Icons.lock_open,
                            color: _isKioskMode
                                ? AppColors.success
                                : AppColors.warning,
                            size: 32),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                AppLocalizations.t(context, 'Lock Device Mode'),
                                style: AppTypography.h4),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _isKioskMode
                                  ? "Device is locked to this app. Home button disabled."
                                  : "Device is unlocked. Access to other apps permitted.",
                              style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary(context)),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isKioskMode,
                        activeColor: AppColors.success,
                        onChanged: (val) => _toggleKioskMode(val),
                      )
                    ],
                  ),
                  if (_statusMessage.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.zero),
                      child: Text(_statusMessage,
                          style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold)),
                    )
                  ]
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),
            Text(
              "Note: Locking the device will make this application the default Launcher. Ensure you have 'Home' access permissions if prompted.",
              style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary(context),
                  fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCheckbox(
      String label, bool value, ValueChanged<bool?> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(value: value, onChanged: onChanged),
        Text(label, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }
}
