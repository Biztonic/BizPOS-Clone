// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
// Reuse logger for now
import '../../services/device_manager_service.dart';
// Reuse logger for now
import '../customer_display_screen.dart';
import '../cfd_screen.dart';

class DisplayHardwareSettingsScreen extends StatefulWidget {
  const DisplayHardwareSettingsScreen({super.key});

  @override
  State<DisplayHardwareSettingsScreen> createState() => _DisplayHardwareSettingsScreenState();
}

class _DisplayHardwareSettingsScreenState extends State<DisplayHardwareSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _ipController = TextEditingController(text: "192.168.1.50");
  
  // Mock State
  bool _isScanning = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Refresh UI after data might have loaded (though service init is async, this ensures rebuild if already loaded)
    DeviceManagerService().init().then((_) {
      if(mounted) setState((){});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  void _addDisplay(DisplayDevice device) async {
     await DeviceManagerService().addDisplay(device);
     setState(() {}); // Refresh list
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added ${device.name}")));
  }

  void _scan() async {
    setState(() => _isScanning = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isScanning = false);
    // Mock found device
    if(mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Device Found"),
          content: const Text("Found 'Samsung TV' at 192.168.1.105"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _addDisplay(DisplayDevice(
                  name: "Samsung TV (Kitchen)", 
                  address: "192.168.1.105", 
                  type: DisplayType.order_board, 
                  connection: DisplayConnection.network
                ));
              }, 
              child: const Text("Add")
            )
          ],
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Display Management"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
             Tab(text: "Connected", icon: Icon(Icons.connected_tv)),
             Tab(text: "Discover", icon: Icon(Icons.search)),
             Tab(text: "This Device", icon: Icon(Icons.devices)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConnectedList(),
          _buildDiscoverTab(),
          _buildLocalOptions(),
        ],
      ),
    );
  }

  Widget _buildConnectedList() {
    final savedDisplays = DeviceManagerService().savedDisplays;
    if (savedDisplays.isEmpty) {
      return const Center(child: Text("No displays configured.\nGo to Discover to add one.", textAlign: TextAlign.center));
    }
    return ListView.builder(
      itemCount: savedDisplays.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final device = savedDisplays[index];
        return Card(
           child: ListTile(
             leading: const Icon(Icons.tv, size: 32),
             title: Text(device.name),
             subtitle: Text("${device.type.name.toUpperCase().replaceAll('_', ' ')} • ${device.connection.name.toUpperCase()}"),
             trailing: IconButton(
               icon: const Icon(Icons.delete, color: Colors.grey),
               onPressed: () async {
                   await DeviceManagerService().removeDisplay(index);
                   setState(() {}); // refresh
               },
             ),
             onTap: () {
                // Show options to push content
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sending test signal...")));
             },
           ),
        );
      },
    );
  }

  Widget _buildDiscoverTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _isScanning ? null : _scan, 
            icon: _isScanning 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.wifi_find),
            label: Text(_isScanning ? "Scanning Network..." : "Scan for Displays"),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text("Manual Connect", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipController,
                  decoration: const InputDecoration(labelText: "IP Address / URL", border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: () {
                   _addDisplay(DisplayDevice(
                      name: "Manual Display",
                      address: _ipController.text,
                      type: DisplayType.cfd,
                      connection: DisplayConnection.network
                   ));
                }, 
                icon: const Icon(Icons.add)
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocalOptions() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.orange.shade50,
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
               children: [
                 Icon(Icons.info, color: Colors.orange),
                 SizedBox(width: 16),
                 Expanded(child: Text("Use this device as a dedicated display unit if connected via HDMI to a TV."))
               ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ListTile(
          title: const Text("Launch Order Status Board"),
          subtitle: const Text("Open the public view for prepared/ready orders"),
          leading: const Icon(Icons.grid_view),
          trailing: const Icon(Icons.launch),
          onTap: () {
             Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomerDisplayScreen()));
          },
        ),
        const Divider(),
        ListTile(
          title: const Text("Launch Customer Facing Display (CFD)"),
          subtitle: const Text("Show cart items and total (Mock)"),
          leading: const Icon(Icons.shopping_cart_checkout),
          trailing: const Icon(Icons.launch),
          onTap: () {
             Navigator.push(context, MaterialPageRoute(builder: (context) => const CFDScreen()));
          },
        ),
      ],
    );
  }
}
