import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';

class PaymentSettingsSection extends StatefulWidget {
  const PaymentSettingsSection({super.key});

  @override
  State<PaymentSettingsSection> createState() => _PaymentSettingsSectionState();
}

class _PaymentSettingsSectionState extends State<PaymentSettingsSection> {
  // Mock settings for toggles, but UPI ID/Name backed by Store
  bool _enableCash = true;
  bool _enableUPI = true;
  bool _enableCard = false;
  
  final TextEditingController _upiIdController = TextEditingController();
  final TextEditingController _upiNameController = TextEditingController();
  
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final store = Provider.of<DashboardProvider>(context, listen: false).activeStore;
      if (store != null) {
        _upiIdController.text = store.payment.upiId;
        _upiNameController.text = store.payment.upiName;
        // Mock toggles - in real app add fields to PaymentSettings
        _enableUPI = store.payment.upiId.isNotEmpty; 
      }
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _upiNameController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
     final provider = Provider.of<DashboardProvider>(context, listen: false);
     final store = provider.activeStore;
     if (store != null) {
       final updatedPayment = store.payment.copyWith(
         upiId: _upiIdController.text.trim(),
         upiName: _upiNameController.text.trim(),
       );
       
       final updatedStore = store.copyWith(payment: updatedPayment);
       await provider.updateStoreSettings(updatedStore);
       
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Settings Saved")));
       }
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Settings")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text("Payment Methods", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // Cash Toggle
            SwitchListTile(
              title: const Text("Accept Cash"),
              subtitle: const Text("Enable cash payments at POS"),
              value: _enableCash,
              onChanged: (val) => setState(() => _enableCash = val),
              secondary: const Icon(Icons.money),
            ),
            
            // UPI Toggle
            SwitchListTile(
              title: const Text("Accept UPI"),
              subtitle: const Text("Enable QR code payments"),
              value: _enableUPI,
              onChanged: (val) => setState(() => _enableUPI = val),
              secondary: const Icon(Icons.qr_code),
            ),

            if (_enableUPI) ...[
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 child: Column(
                   children: [
                     TextField(
                       controller: _upiIdController,
                       decoration: const InputDecoration(
                         labelText: "UPI ID / VPA",
                         hintText: "merchant@upi",
                         border: OutlineInputBorder(),
                         prefixIcon: Icon(Icons.link)
                       ),
                     ),
                     const SizedBox(height: 12),
                     TextField(
                       controller: _upiNameController,
                       decoration: const InputDecoration(
                         labelText: "Payee Name (Business Name)",
                         hintText: "My Store",
                         border: OutlineInputBorder(),
                         prefixIcon: Icon(Icons.store)
                       ),
                     ),
                   ],
                 ),
               )
            ],

            // Card Toggle
            SwitchListTile(
              title: const Text("Accept Card"),
              subtitle: const Text("Enable card reader integration"),
              value: _enableCard,
              onChanged: (val) => setState(() => _enableCard = val),
              secondary: const Icon(Icons.credit_card),
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text("Save Changes"),
            )
          ],
        ),
      ),
    );
  }
}
