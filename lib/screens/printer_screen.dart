import '../core/design/tokens/app_colors.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:permission_handler/permission_handler.dart';
import '../services/printer_manager_service.dart';
import '../services/printer_log_service.dart';
import '../models/printer_device.dart';

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});

  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen>
    with SingleTickerProviderStateMixin {
  final PrinterManagerService _printerManager = PrinterManagerService();
  final PrinterLogService _logger = PrinterLogService();

  late TabController _tabController;
  final ScrollController _logScrollController = ScrollController();
  StreamSubscription? _scanSubscription;

  // UI State - Separated
  // Separate scan states and device lists
  List<PrinterDevice> _btDevices = [];
  bool _isScanningBt = false;
  List<PrinterDevice> _usbDevices = [];
  bool _isScanningUsb = false;

  final TextEditingController _ipController =
      TextEditingController(text: "192.168.1.100");

  // Logs
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Listen to logs
    // Listen to devices from UniversalService
    _scanSubscription = _printerManager.universalService.devicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          // Clear current lists (optional, or merge)
          _btDevices = devices.where((d) => d.type == PrinterConnectionType.bluetooth).toList();
          _usbDevices = devices.where((d) => d.type == PrinterConnectionType.usb).toList();
          
          // Stop loaders if we got results (or keep them running for a fixed time)
             //  Actually, stream updates continuosly. We stop loaders after timeout in startScan.
        });
      }
    });

    _logs = List.from(_logger.logs);
    _logger.logStream.listen((log) {
      if (mounted) {
        setState(() {
          _logs.add(log);
          if (_logs.length > 100) _logs.removeAt(0);
        });
        if (_logScrollController.hasClients) {
          _logScrollController.animateTo(
            _logScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _tabController.dispose();
    _logScrollController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  // --- Actions ---

  // Bluetooth scan
  Future<void> _scanBluetooth() async {
    if (_isScanningBt) return;

    // Platform Check
    bool isMobile = false;
    try {
       if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
          isMobile = true;
       }
    } catch (e) { isMobile = false; }

    if (!isMobile) {
       _showPlatformError("Bluetooth scanning is only available on Mobile platforms.");
       return;
    }

    // Request Permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted) {
      if (statuses.values.any((status) => status.isPermanentlyDenied)) {
         _showPermissionDialog();
      } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Bluetooth permissions are required to scan."),
            backgroundColor: AppColors.error));
      }
      return;
    }

    setState(() {
      _isScanningBt = true;
      _btDevices.clear();
    });
    _logger.log("Starting Bluetooth Scan...");
    
    // Start unified scan
    _printerManager.universalService.startScan();
    
    // Auto-stop loader
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _isScanningBt) setState(() => _isScanningBt = false);
    });
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Permissions Required"),
        content: const Text(
            "Bluetooth and Location permissions are required to scan for printers. Please enable them in settings."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text("Open Settings")),
        ],
      ),
    );
  }

  // USB scan
  Future<void> _scanUsb() async {
    if (_isScanningUsb) return;

    // Platform Check (Android only for usb_serial usually, or maybe serial on Windows?)
    // usb_serial package is typically Android.
    bool isAndroid = false;
    try {
       if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          isAndroid = true;
       }
    } catch (e) { isAndroid = false; }

    if (!isAndroid) {
       _showPlatformError("USB scanning via this method is only available on Android.");
       return;
    }

    setState(() {
      _isScanningUsb = true;
      _usbDevices.clear();
    });
    _logger.log("Starting USB Scan...");
    
    _printerManager.universalService.startScan();

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isScanningUsb) setState(() => _isScanningUsb = false);
    });
  }

  void _showPlatformError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Feature Not Available"),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
        ],
      )
    );
  }

  Future<void> _connectAndAssign(PrinterDevice device) async {
    // Configuration State
    List<PrinterPurpose> selectedPurposes = [];
    PrinterPaperSize selectedPaperSize =
        device.paperSize; // Default to device's current or default

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
        return AlertDialog(
          title: Text("Configure ${device.name}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Paper Size",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<PrinterPaperSize>(
                  value: selectedPaperSize,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                        value: PrinterPaperSize.mm58,
                        child: Text("58mm Thermal")),
                    DropdownMenuItem(
                        value: PrinterPaperSize.mm80,
                        child: Text("80mm Thermal")),
                    DropdownMenuItem(
                        value: PrinterPaperSize.isoA4,
                        child: Text("A4 / Letter")),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setStateDialog(() => selectedPaperSize = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text("Assign Functions",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...PrinterPurpose.values.map((purpose) {
                  if (purpose == PrinterPurpose.other) {
                    return const SizedBox.shrink();
                  }
                  return CheckboxListTile(
                    title:
                        Text(purpose.name.toUpperCase().replaceAll('_', ' ')),
                    value: selectedPurposes.contains(purpose),
                    onChanged: (bool? checked) {
                      setStateDialog(() {
                        if (checked == true) {
                          selectedPurposes.add(purpose);
                        } else {
                          selectedPurposes.remove(purpose);
                        }
                      });
                    },
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _saveConfiguration(
                      device, selectedPaperSize, selectedPurposes);
                },
                child: const Text("Connect & Save")),
          ],
        );
      }),
    );
  }

  Future<void> _saveConfiguration(PrinterDevice baseDevice,
      PrinterPaperSize size, List<PrinterPurpose> purposes) async {
    // Create new device object with updated size (Config is technically per device, but here we update the source definition essentially)
    // Actually, if we assign to multiple purposes, we just reuse the connection info.

    // Update device config
    final configDevice = PrinterDevice(
        name: baseDevice.name,
        address: baseDevice.address,
        vendorId: baseDevice.vendorId,
        productId: baseDevice.productId,
        type: baseDevice.type,
        paperSize: size);

    _logger.log("Connecting ${configDevice.name} [${size.name}]...");

    if (purposes.isEmpty) {
      _logger.log("No purposes selected.");
      return;
    }

    // If network, ask for IP if missing
    if (configDevice.type == PrinterConnectionType.network &&
        configDevice.address == null) {
      // Manual IP handling would happen here or before.
      // Assuming scanned devices have IP or manual entry provided it.
    }

    for (var purpose in purposes) {
      _logger.log("Assigning to ${purpose.name}...");
      await _printerManager.connect(configDevice, purpose);
    }

    setState(() {});
  }

  Future<void> _connectNetworkManual() async {
    if (_ipController.text.isEmpty) return;
    
    final device = PrinterDevice(
        name: "Network Printer (${_ipController.text})",
        address: _ipController.text,
        type: PrinterConnectionType.network);
    await _connectAndAssign(device);
  }

  Future<void> _testPrint(PrinterPurpose purpose) async {
    _logger.log("Test Print for ${purpose.name}...");
    List<int> bytes = [];
    bytes += [0x1B, 0x40]; // Init
    bytes += [0x1B, 0x61, 0x01]; // Center
    bytes += [0x1B, 0x21, 0x30]; // Large
    bytes += 'Biztonic TEST\n'.codeUnits;
    bytes += [0x1B, 0x21, 0x00]; // Normal
    bytes += 'Purpose: ${purpose.name}\n\n'.codeUnits;
    bytes += [0x1D, 0x56, 0x42, 0x00]; // Cut

    bool result = await _printerManager.printBytes(purpose, bytes);
    if (result) {
      _logger.log("Print Sent Successfully.");
    } else {
      _logger.log("Print Failed. Check connection.");
    }
  }

  Future<void> _disconnect(PrinterPurpose purpose) async {
    await _printerManager.disconnect(purpose);
    setState(() {});
  }

  // --- Views ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Configured"),
            Tab(text: "Discover"),
            Tab(text: "Logs"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConfiguredView(),
          _buildDiscoverView(),
          _buildLogsView(),
        ],
      ),
    );
  }

  Widget _buildConfiguredView() {
    final assignments = _printerManager.assignments;
    if (assignments.isEmpty) {
      return const Center(
          child: Text(
              "No printers configured.\nGo to Discover tab to add printers."));
    }
    return ListView(
      children: assignments.entries.map((entry) {
        final purpose = entry.key;
        final device = entry.value;
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            leading: Icon(_getIconForType(device.type)),
            title: Text("${purpose.name.toUpperCase()}: ${device.name}"),
            subtitle: Text(
                "${device.type.name} - ${device.address ?? device.vendorId ?? ''}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                    icon: const Icon(Icons.print),
                    onPressed: () => _testPrint(purpose)),
                IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.error),
                    onPressed: () => _disconnect(purpose)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDiscoverView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- 1. BLUETOOTH SECTION ---
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: const Icon(Icons.bluetooth, color: AppColors.primaryLight),
            title: const Text("Bluetooth Printers"),
            subtitle: Text("${_btDevices.length} devices found"),
            trailing: ElevatedButton(
                onPressed: _isScanningBt ? null : _scanBluetooth,
                style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact),
                child: _isScanningBt
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Scan")),
            children: [
              if (_btDevices.isEmpty && !_isScanningBt)
                Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("No bluetooth devices found.",
                        style: TextStyle(color: AppColors.textSecondary(context)))),
              ..._btDevices.map((device) => ListTile(
                    leading: const Icon(Icons.print, color: AppColors.primaryLightGrey),
                    title: Text(device.name),
                    subtitle: Text(device.address ?? "Unknown MAC"),
                    trailing: TextButton(
                      onPressed: () => _connectAndAssign(device),
                      child: const Text("Connect"),
                    ),
                  )),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- 2. USB SECTION ---
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: const Icon(Icons.usb, color: AppColors.warning),
            title: const Text("USB Printers"),
            subtitle: Text("${_usbDevices.length} devices found"),
            trailing: ElevatedButton(
                onPressed: _isScanningUsb ? null : _scanUsb,
                style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact),
                child: _isScanningUsb
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Scan")),
            children: [
              if (_usbDevices.isEmpty && !_isScanningUsb)
                Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("No USB devices found.",
                        style: TextStyle(color: AppColors.textSecondary(context)))),
              ..._usbDevices.map((device) => ListTile(
                    leading: const Icon(Icons.print, color: AppColors.primaryLightGrey),
                    title: Text(device.name),
                    subtitle:
                        Text("VID:${device.vendorId} PID:${device.productId}"),
                    trailing: TextButton(
                      onPressed: () => _connectAndAssign(device),
                      child: const Text("Connect"),
                    ),
                  )),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- 3. NETWORK SECTION ---
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            initiallyExpanded: false,
            leading: const Icon(Icons.wifi, color: AppColors.success),
            title: const Text("Network Printer"),
            subtitle: const Text("Connect via IP Address"),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ipController,
                        decoration: const InputDecoration(
                            labelText: "Printer IP Address",
                            hintText: "e.g. 192.168.1.100",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.network_check)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _connectNetworkManual,
                      icon: const Icon(Icons.link),
                      label: const Text("Connect"),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16)),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogsView() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(8),
      child: ListView.builder(
        controller: _logScrollController,
        itemCount: _logs.length,
        itemBuilder: (context, index) => Text(_logs[index],
            style: const TextStyle(color: AppColors.success, fontFamily: 'Courier')),
      ),
    );
  }

  IconData _getIconForType(PrinterConnectionType type) {
    switch (type) {
      case PrinterConnectionType.bluetooth:
        return Icons.bluetooth;
      case PrinterConnectionType.network:
        return Icons.wifi;
      case PrinterConnectionType.usb:
        return Icons.usb;
      case PrinterConnectionType.system:
        return Icons.print; // Generic print icon for system
    }
  }
}
