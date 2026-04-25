// ignore_for_file: dead_null_aware_expression, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';

class TaxSettingsSection extends StatefulWidget {
  const TaxSettingsSection({super.key});
  @override
  State<TaxSettingsSection> createState() => _TaxSettingsSectionState();
}

class _TaxSettingsSectionState extends State<TaxSettingsSection> {
  final _taxController = TextEditingController();
  bool _isTaxEnabled = false;
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final store = Provider.of<DashboardProvider>(context).activeStore;
      if (store != null) {
        _taxController.text = (store.taxRate ?? 0).toString();
        _isTaxEnabled = store.isTaxEnabled ?? false;
      }
      _isInit = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final store = provider.activeStore;
    if (store == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(title: const Text("Tax Settings")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            SwitchListTile(
              title: const Text('Enable Tax Calculation'),
              subtitle: const Text('Apply tax calculated on bill subtotal'),
              value: _isTaxEnabled,
              onChanged: (val) => setState(() => _isTaxEnabled = val),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            if (_isTaxEnabled)
              TextField(
                controller: _taxController,
                decoration: const InputDecoration(labelText: 'Tax Rate (%)', border: OutlineInputBorder(), suffixText: '%'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final double tax = double.tryParse(_taxController.text) ?? 0.0;
                final updatedStore = store.copyWith(
                  taxRate: tax,
                  isTaxEnabled: _isTaxEnabled,
                );
                await provider.updateStoreSettings(updatedStore);
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tax Settings Saved")));
                   Navigator.pop(context);
                }
              },
              child: const Text("Save Changes"),
            )
          ],
        ),
      ),
    );
  }
}
