// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:biztonic_pos/providers/store_provider.dart';
import 'package:kiosk_mode/kiosk_mode.dart';

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
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Other Settings'),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Store Configuration", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 16),
            
            // Store Types Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2D44) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                border: isDark ? Border.all(color: Colors.white10) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.blueGrey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.store, color: Colors.blueGrey),
                      ),
                      const SizedBox(width: 16),
                      const Text("Store Types", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text("Define the categories of stores available config.", style: TextStyle(color: Colors.grey)),
                  const Divider(height: 32),
                  
                  // Add New Input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                         children: [
                           Expanded(
                             child: TextField(
                               controller: _textCtrl,
                               decoration: InputDecoration(
                                 labelText: 'New Store Type',
                                 hintText: 'e.g. Cafe, Pharmacy',
                                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                               ),
                             ),
                           ),
                           const SizedBox(width: 12),
                           ElevatedButton.icon(
                             onPressed: _addType,
                             icon: const Icon(Icons.add, size: 18),
                             label: const Text("Add"),
                             style: ElevatedButton.styleFrom(
                               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                               backgroundColor: Colors.blueGrey,
                               foregroundColor: Colors.white,
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                             ),
                           )
                         ],
                      ),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: [
                           _buildCompactCheckbox("Kitchen", _isKitchenEnabled, (v) => setState(() => _isKitchenEnabled = v!)),
                           _buildCompactCheckbox("Dietary", _isDietaryEnabled, (v) => setState(() => _isDietaryEnabled = v!)),
                           _buildCompactCheckbox("Packaging", _isPackagingEnabled, (v) => setState(() => _isPackagingEnabled = v!)),
                           _buildCompactCheckbox("Variants", _isVariantsEnabled, (v) => setState(() => _isVariantsEnabled = v!)),
                        ],
                      )
                    ],
                  ),

                  const SizedBox(height: 24),
                  
                  // List
                  _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : _types.isEmpty 
                        ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No store types defined.')))
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _types.length,
                            separatorBuilder: (ctx, i) => const Divider(),
                            itemBuilder: (ctx, i) {
                               final type = _types[i];
                               final config = _typeConfigs[type] as Map?;
                               final hasKitchen = config?['enableKitchen'] == true;
                               
                               return ListTile(
                                 contentPadding: EdgeInsets.zero,
                                 title: Text(type, style: const TextStyle(fontWeight: FontWeight.w500)),
                                 subtitle: hasKitchen ? const Text("Kitchen Enabled", style: TextStyle(color: Colors.green, fontSize: 12)) : null,
                                 trailing: Row(
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     IconButton(
                                       icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue), 
                                       onPressed: () => _editType(type),
                                       tooltip: "Edit",
                                     ),
                                     IconButton(
                                       icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), 
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
            
            const SizedBox(height: 32),
            const Text(
              "Device Security", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 16),

            // KIOSK MODE CARD
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2D44) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                border: Border.all(color: _isKioskMode ? Colors.green : Colors.amber),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isKioskMode ? Colors.green.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12)
                        ),
                        child: Icon(
                          _isKioskMode ? Icons.lock : Icons.lock_open,
                          color: _isKioskMode ? Colors.green : Colors.amber,
                          size: 32
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Lock Device Mode", 
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isKioskMode 
                                 ? "Device is locked to this app. Home button disabled."
                                 : "Device is unlocked. Access to other apps permitted.",
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isKioskMode,
                        activeColor: Colors.green,
                        onChanged: (val) => _toggleKioskMode(val),
                      )
                    ],
                  ),
                  if (_statusMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(_statusMessage, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    )
                  ]
                ],
              ),
            ),
             
            const SizedBox(height: 16),
            const Text(
              "Note: Locking the device will make this application the default Launcher. Ensure you have 'Home' access permissions if prompted.",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
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
