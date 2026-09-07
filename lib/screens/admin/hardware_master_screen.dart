import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import 'package:biztonic_pos/models/hardware_master.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/core/design/tokens/app_typography.dart';
import 'package:biztonic_pos/services/firestore_helper.dart';

class HardwareMasterScreen extends StatefulWidget {
  const HardwareMasterScreen({super.key});

  @override
  State<HardwareMasterScreen> createState() => _HardwareMasterScreenState();
}

class _HardwareMasterScreenState extends State<HardwareMasterScreen> {
  final FirebaseFirestore _db = getFirestore();
  List<HardwareMaster> _hardwares = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHardwares();
  }

  Future<void> _fetchHardwares() async {
    setState(() => _isLoading = true);
    try {
      final snap = await _db.collection('hardware_master').get();
      _hardwares = snap.docs.map((d) => HardwareMaster.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      debugPrint('Error fetching hardwares: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showHardwareDialog([HardwareMaster? hardware]) {
    showDialog(
      context: context,
      builder: (context) => _HardwareDialog(
        hardware: hardware,
        onSave: () => _fetchHardwares(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text("Hardware Master", style: AppTypography.titleLarge),
        backgroundColor: AppColors.surface(context),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () => _showHardwareDialog(),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hardwares.isEmpty
              ? Center(child: Text("No hardware models defined.", style: AppTypography.bodyMedium))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _hardwares.length,
                  itemBuilder: (context, index) {
                    final hw = _hardwares[index];
                    return Card(
                      color: AppColors.surface(context),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.devices, color: AppColors.primary),
                        title: Text(hw.name, style: AppTypography.titleMedium),
                        subtitle: Text("Price: ₹${hw.basePrice} | EMI: ₹${hw.emiAmount} (${hw.emiType})\nTotal EMIs: ${hw.totalEmiCount} | Grace: ${hw.gracePeriodDays} days", style: AppTypography.bodySmall),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: hw.isActive,
                              onChanged: (val) async {
                                await _db.collection('hardware_master').doc(hw.id).update({'isActive': val});
                                _fetchHardwares();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppColors.primary),
                              onPressed: () => _showHardwareDialog(hw),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _HardwareDialog extends StatefulWidget {
  final HardwareMaster? hardware;
  final VoidCallback onSave;

  const _HardwareDialog({this.hardware, required this.onSave});

  @override
  State<_HardwareDialog> createState() => _HardwareDialogState();
}

class _HardwareDialogState extends State<_HardwareDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _downPaymentController;
  late TextEditingController _emiAmountController;
  late TextEditingController _emiCountController;
  late TextEditingController _depreciationController;
  late TextEditingController _gracePeriodController;
  late TextEditingController _serialPrefixController;
  late TextEditingController _imageUrlController;
  String _emiType = 'monthly';

  @override
  void initState() {
    super.initState();
    final hw = widget.hardware;
    _nameController = TextEditingController(text: hw?.name ?? '');
    _descController = TextEditingController(text: hw?.description ?? '');
    _priceController = TextEditingController(text: hw?.basePrice.toString() ?? '');
    _downPaymentController = TextEditingController(text: hw?.downPayment.toString() ?? '');
    _emiAmountController = TextEditingController(text: hw?.emiAmount.toString() ?? '');
    _emiCountController = TextEditingController(text: hw?.totalEmiCount.toString() ?? '');
    _depreciationController = TextEditingController(text: hw?.buybackDepreciationPerDay.toString() ?? '');
    _gracePeriodController = TextEditingController(text: hw?.gracePeriodDays.toString() ?? '2');
    _serialPrefixController = TextEditingController(text: hw?.serialPrefix ?? '');
    _imageUrlController = TextEditingController(text: hw?.imageUrl ?? '');
    if (hw != null) _emiType = hw.emiType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _downPaymentController.dispose();
    _emiAmountController.dispose();
    _emiCountController.dispose();
    _depreciationController.dispose();
    _gracePeriodController.dispose();
    _serialPrefixController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final hw = HardwareMaster(
      id: widget.hardware?.id ?? '', // Handled by add()
      name: _nameController.text,
      description: _descController.text,
      basePrice: double.tryParse(_priceController.text) ?? 0,
      downPayment: double.tryParse(_downPaymentController.text) ?? 0,
      emiAmount: double.tryParse(_emiAmountController.text) ?? 0,
      emiType: _emiType,
      totalEmiCount: int.tryParse(_emiCountController.text) ?? 0,
      buybackDepreciationPerDay: double.tryParse(_depreciationController.text) ?? 0,
      gracePeriodDays: int.tryParse(_gracePeriodController.text) ?? 2,
      serialPrefix: _serialPrefixController.text,
      imageUrl: _imageUrlController.text.isEmpty ? null : _imageUrlController.text,
      isActive: widget.hardware?.isActive ?? true,
      createdAt: widget.hardware?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final db = getFirestore();
    if (widget.hardware == null) {
      await db.collection('hardware_master').add(hw.toMap());
    } else {
      await db.collection('hardware_master').doc(widget.hardware!.id).update(hw.toMap());
    }
    widget.onSave();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.hardware == null ? "Add Hardware" : "Edit Hardware"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
              TextFormField(controller: _descController, decoration: const InputDecoration(labelText: 'Description')),
              TextFormField(controller: _priceController, decoration: const InputDecoration(labelText: 'Base Price (₹)'), keyboardType: TextInputType.number),
              TextFormField(controller: _downPaymentController, decoration: const InputDecoration(labelText: 'Down Payment (₹)'), keyboardType: TextInputType.number),
              TextFormField(controller: _emiAmountController, decoration: const InputDecoration(labelText: 'EMI Amount (₹)'), keyboardType: TextInputType.number),
              TextFormField(controller: _emiCountController, decoration: const InputDecoration(labelText: 'Total EMI Count'), keyboardType: TextInputType.number),
              DropdownButtonFormField<String>(
                value: _emiType,
                items: const [
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: (v) => setState(() => _emiType = v!),
                decoration: const InputDecoration(labelText: 'EMI Frequency'),
              ),
              TextFormField(controller: _depreciationController, decoration: const InputDecoration(labelText: 'Daily Depreciation (₹)'), keyboardType: TextInputType.number),
              TextFormField(controller: _gracePeriodController, decoration: const InputDecoration(labelText: 'Grace Period (Days)'), keyboardType: TextInputType.number),
              TextFormField(controller: _serialPrefixController, decoration: const InputDecoration(labelText: 'Serial Prefix (e.g. BP2026)')),
              TextFormField(controller: _imageUrlController, decoration: const InputDecoration(labelText: 'Image URL')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: _save, child: const Text("Save")),
      ],
    );
  }
}
