import 'package:flutter/material.dart';
import '../printer_screen.dart';
import 'barcode_scanner_settings_screen.dart';
import 'display_hardware_settings_screen.dart';
import '../../widgets/feature_guard.dart';

class DevicesSettingsSection extends StatelessWidget {
  const DevicesSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    // efficient way to handle sub-navigation within the settings panel
    return Navigator(
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const DevicesMenuScreen(),
        );
      },
    );
  }
}

class DevicesMenuScreen extends StatelessWidget {
  const DevicesMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Connected Devices")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDeviceItem(
            context,
            icon: Icons.print,
            title: "Printers",
            subtitle: "Manage Receipt, KDS, and Label Printers",
            color: Colors.blue,
            destination: const PrinterScreen(),
          ),
          _buildDeviceItem(
            context,
            icon: Icons.qr_code_scanner,
            title: "Barcode Scanners",
            subtitle: "Configure external scanners and behavior",
            color: Colors.green,
            destination: const BarcodeScannerSettingsScreen(),
          ),
          FeatureGuard(
            featureKey: 'kds_management',
            lockedChild: const SizedBox.shrink(),
            child: _buildDeviceItem(
              context,
              icon: Icons.monitor,
              title: "Displays",
              subtitle: "Customer facing displays and Kiosks",
              color: Colors.orange,
              destination: const DisplayHardwareSettingsScreen(),
            ),
          ),

          _buildDeviceItem(
            context,
            icon: Icons.credit_card,
            title: "Card Terminals",
            subtitle: "Payment terminal integration settings",
            color: Colors.purple,
            destination: null, // Coming Soon
          ),
          _buildDeviceItem(
            context,
            icon: Icons.scale,
            title: "Scales",
            subtitle: "Digital weighing scale integration",
            color: Colors.teal,
            destination: null, // Coming Soon
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Widget? destination,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          if (destination != null) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => destination),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Coming Soon"), duration: Duration(seconds: 1)),
            );
          }
        },
      ),
    );
  }
}
