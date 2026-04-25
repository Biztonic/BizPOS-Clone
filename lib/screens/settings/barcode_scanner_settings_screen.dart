// ignore_for_file: unused_field
import 'package:flutter/material.dart';

class BarcodeScannerSettingsScreen extends StatefulWidget {
  const BarcodeScannerSettingsScreen({super.key});

  @override
  State<BarcodeScannerSettingsScreen> createState() => _BarcodeScannerSettingsScreenState();
}

class _BarcodeScannerSettingsScreenState extends State<BarcodeScannerSettingsScreen> {
  bool _autoEnter = true;
  String _prefix = "";
  String _suffix = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Barcode Scanners")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text("Auto Enter"),
            subtitle: const Text("Automatically submit after scan"),
            value: _autoEnter,
            onChanged: (val) => setState(() => _autoEnter = val),
          ),
          const Divider(),
          const ListTile(
            title: Text("Prefix & Suffix"),
            subtitle: Text("Configure scanner characters"),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: "Prefix", border: OutlineInputBorder()),
                    onChanged: (val) => _prefix = val,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: "Suffix", border: OutlineInputBorder()),
                    onChanged: (val) => _suffix = val,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Center(child: Text("Connect your scanner via USB or Bluetooth.\nIt will work as a keyboard input.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }
}
