import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart'; // LOCALIZATION

class SupplierScreen extends StatelessWidget {
  const SupplierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.t(context, 'suppliers'))),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_shipping, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Supplier List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: (){}, child: Text(AppLocalizations.t(context, 'add')))
          ],
        ),
      ),
    );
  }
}
