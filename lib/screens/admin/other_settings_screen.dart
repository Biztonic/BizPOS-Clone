import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:biztonic_pos/providers/store_provider.dart';
import 'package:kiosk_mode/kiosk_mode.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_colors.dart';

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
  
  // New Type Config
  bool _isKitchenEnabled = false;
  bool _isDietaryEnabled = false;
  bool _isPackagingEnabled = false;
  bool _isVariantsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadTypes();
    _checkKioskMode();
  }

  Future<void> _checkKioskMode() async {
    final mode = await getKioskMode();
    if (mounted) {
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
      
      // PERSIST STATE (For Auto-Lock on Reboot)
      final provider = Provider.of<StoreProvider>(context, listen: false);
      provider.saveKioskPreference(enable);

      await _checkKioskMode();
      setState(() => _statusMessage = enable ? "Device Locked" : "Device Unlocked");
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
       'enableDietary': _isDietaryEnabled,
       'enablePackaging': _isPackagingEnabled,
       'enableVariants': _isVariantsEnabled,
    };

    setState(() {
       _types.add(newType);
       _typeConfigs[newType] = config;
    });
    
    final toAdd = _textCtrl.text.trim();
    _textCtrl.clear();
    setState(() {
       _isKitchenEnabled = false;
       _isDietaryEnabled = false;
       _isPackagingEnabled = false;
       _isVariantsEnabled = false;
    });

    await Provider.of<StoreProvider>(context, listen: false).addStoreType(toAdd, initialConfig: config);
  }
  
  Future<void> _editType(String oldType) async {
    final ctrl = TextEditingController(text: oldType);
    final config = _typeConfigs[oldType] as Map?;
    bool kitchenEnabled = config?['enableKitchen'] ?? false;
    bool dietaryEnabled = config?['enableDietary'] ?? false;
    bool packagingEnabled = config?['enablePackaging'] ?? false;
    bool variantsEnabled = config?['enableVariants'] ?? false;
    
    // Using StatefulBuilder to handle dialog state update for Checkbox
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Store Type"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: ctrl, decoration: const InputDecoration(labelText: "Store Type")),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text("Enable Kitchen & Counters"),
                      value: kitchenEnabled,
                      onChanged: (val) => setDialogState(() => kitchenEnabled = val ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: const Text("Enable Dietary Types (Veg/Non-Veg)"),
                      value: dietaryEnabled,
                      onChanged: (val) => setDialogState(() => dietaryEnabled = val ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: const Text("Enable Packaging Types"),
                      value: packagingEnabled,
                      onChanged: (val) => setDialogState(() => packagingEnabled = val ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: const Text("Enable Variant Categories"),
                      value: variantsEnabled,
                      onChanged: (val) => setDialogState(() => variantsEnabled = val ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    )
                  ],
                ),
              ),
              actions: [
                 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                 ElevatedButton(
                   onPressed: () async {
                      Navigator.pop(ctx);
                      final newType = ctrl.text.trim();
                      if (newType.isNotEmpty) {
                         final newConfig = {
                            'enableKitchen': kitchenEnabled,
                            'enableDietary': dietaryEnabled,
                            'enablePackaging': packagingEnabled,
                            'enableVariants': variantsEnabled,
                         };

                         setState(() {
                           final index = _types.indexOf(oldType);
                           if (index != -1) _types[index] = newType;
                           // Update local config map
                           _typeConfigs.remove(oldType);
                           _typeConfigs[newType] = newConfig;
                         });
                         await Provider.of<StoreProvider>(context, listen: false).updateStoreType(oldType, newType, config: newConfig);
                      }
                   }, 
                   child: const Text("Save")
                 ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _deleteType(String type) async {
    final confirm = await showDialog<bool>(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Store Type?'),
        content: Text('Are you sure you want to delete "$type"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      )
    );

    if (confirm == true) {
      setState(() {
        _types.remove(type);
        _typeConfigs.remove(type);
      });
      await Provider.of<StoreProvider>(context, listen: false).deleteStoreType(type);
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
              "Store Configuration",
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
                          borderRadius: BorderRadius.circular(AppSpacing.xs),
                        ),
                        child: const Icon(Icons.store, color: AppColors.primary),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text("Store Types", style: AppTypography.h4),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    "Define the categories of stores available config.",
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context)),
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
                              prefixIcon: const Icon(Icons.add_business_outlined),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Padding(
                            padding: const EdgeInsets.only(top: 26), // Align with text field
                            child: AppButton.primary(
                              onPressed: _addType,
                              label: "Add",
                              icon: Icons.add,
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _buildCompactCheckbox("Kitchen", _isKitchenEnabled, (v) => setState(() => _isKitchenEnabled = v!)),
                          _buildCompactCheckbox("Dietary", _isDietaryEnabled, (v) => setState(() => _isDietaryEnabled = v!)),
                          _buildCompactCheckbox("Packaging", _isPackagingEnabled, (v) => setState(() => _isPackagingEnabled = v!)),
                          _buildCompactCheckbox("Variants", _isVariantsEnabled, (v) => setState(() => _isVariantsEnabled = v!)),
                        ],
                      )
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  
                  // List
                  _isLoading 
                    ? const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.xl), child: CircularProgressIndicator()))
                    : _types.isEmpty 
                        ? const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Text('No store types defined.')))
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _types.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final type = _types[i];
                              final config = _typeConfigs[type] as Map?;
                              final hasKitchen = config?['enableKitchen'] == true;
                              
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(type, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                                subtitle: hasKitchen 
                                  ? Text("Kitchen Enabled", style: AppTypography.bodySmall.copyWith(color: AppColors.success)) 
                                  : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary), 
                                      onPressed: () => _editType(type),
                                      tooltip: "Edit",
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error), 
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
              "Device Security", 
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
                          color: (_isKioskMode ? AppColors.success : AppColors.warning).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.sm)
                        ),
                        child: Icon(
                          _isKioskMode ? Icons.lock : Icons.lock_open,
                          color: _isKioskMode ? AppColors.success : AppColors.warning,
                          size: 32
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Lock Device Mode", style: AppTypography.h4),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _isKioskMode 
                                 ? "Device is locked to this app. Home button disabled."
                                 : "Device is unlocked. Access to other apps permitted.",
                               style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context)),
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
                        borderRadius: BorderRadius.circular(AppSpacing.xs)
                      ),
                      child: Text(
                        _statusMessage, 
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)
                      ),
                    )
                  ]
                ],
              ),
            ),
             
            const SizedBox(height: AppSpacing.md),
            Text(
              "Note: Locking the device will make this application the default Launcher. Ensure you have 'Home' access permissions if prompted.",
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context), fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCheckbox(String label, bool value, ValueChanged<bool?> onChanged) {
     return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
           Checkbox(value: value, onChanged: onChanged),
           Text(label, style: const TextStyle(fontSize: 13)),
           const SizedBox(width: 8),
        ],
     );
  }
}
