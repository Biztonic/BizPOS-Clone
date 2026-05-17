// ignore_for_file: constant_identifier_names, dead_code
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/printer_device.dart';
import '../models/order_model.dart';
import '../models/store.dart';
import '../models/counter_model.dart';

import 'network_printer_service.dart';
import 'universal_printer_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

enum PrinterPurpose {
  receipt,         // Main checkout receipt
  kds,             // Kitchen Display System / Kitchen Printer
  bar,             // Bar Printer
  gst_report,      // Official GST/Tax Invoices
  performance_report, // Store Performance/Day-end reports
  label,           // Product Sticker/Label
  other            // Fallback
}

class PrinterManagerService {
  static final PrinterManagerService _instance = PrinterManagerService._internal();

  factory PrinterManagerService() {
    return _instance;
  }

  PrinterManagerService._internal();

  final UniversalPrinterService _universalService = UniversalPrinterService();
  final NetworkPrinterService _networkService = NetworkPrinterService();
  Timer? _reconnectTimer;

  // Connection Status Tracking
  final StreamController<bool> _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Map of Purpose -> Assigned Printer
  final Map<PrinterPurpose, PrinterDevice> _assignments = {};

  // Pool of all saved/configured devices (available for assignment)
  final List<PrinterDevice> _savedDevices = [];

  Map<PrinterPurpose, PrinterDevice> get assignments => _assignments;
  List<PrinterDevice> get savedDevices => _savedDevices;

  Future<void> init() async {
    await _loadAssignments();
    await _loadSavedDevices();
    
    // Auto-connect to all assigned printers
    for (var entry in _assignments.entries) {
      await connect(entry.value, entry.key);
    }

    // Initial status check
    _updateOverallStatus();

    // START BACKGROUND RECONNECT TIMER (Android 14+ Power Management Mitigation)
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkAndReconnect();
    });
  }
    
  Future<void> _checkAndReconnect() async {
    // Only attempt if not web
    if (kIsWeb) return;

    bool anyConnected = false;

    for (var entry in _assignments.entries) {
      final device = entry.value;
      bool currentDeviceOk = false;

      if (device.type == PrinterConnectionType.bluetooth || device.type == PrinterConnectionType.usb) {
        // IMPORTANT: verifyConnection() in UniversalService checks the LAST CONNECTED printer.
        // If we have multiple, this logic needs to be careful.
        // For now, we assume if ANY printer is connected, the link is alive.
        currentDeviceOk = await _universalService.verifyConnection();
        
        if (!currentDeviceOk) {
          debugPrint('🔄 PrinterManager: Attempting auto-reconnect for ${device.name} (${entry.key.name})...');
          currentDeviceOk = await _universalService.connect(device);
        }
      } else if (device.type == PrinterConnectionType.network) {
        // Simple ping/check if needed, but network is usually reliable or handled at print time
        currentDeviceOk = true; 
      } else if (device.type == PrinterConnectionType.system) {
        currentDeviceOk = true;
      }

      if (currentDeviceOk) anyConnected = true;
    }

    _updateOverallStatus(anyConnected);
  }

  void _updateOverallStatus([bool? forceStatus]) {
    final bool newStatus = forceStatus ?? (_universalService.isConnected || _assignments.values.any((d) => d.type == PrinterConnectionType.network));
    if (newStatus != _isConnected) {
      _isConnected = newStatus;
      _statusController.add(_isConnected);
      debugPrint('🖨️ PrinterManager: Overall Status changed to: $_isConnected');
    }
  }

  // --- Saved Device Management ---
  Future<void> addSavedDevice(PrinterDevice device) async {
    // Remove if exists (update)
    _savedDevices.removeWhere((d) => d.address == device.address && d.name == device.name);
    _savedDevices.add(device);
    await _saveSavedDevices();
    // notifyListeners(); // Usage of notifyListeners removed as this is not a ChangeNotifier
    // Consumers should rely on getters or streams if we added them.
  }

  Future<void> removeSavedDevice(PrinterDevice device) async {
    _savedDevices.removeWhere((d) => d.address == device.address && d.name == device.name);
    await _saveSavedDevices();
  }

  PrinterDevice? getSavedDevice(String? identifier) {
    if (identifier == null) return null;
    try {
      return _savedDevices.firstWhere((d) => d.address == identifier || d.name == identifier);
    } catch (_) {
      return null;
    }
  }

  Future<void> connect(PrinterDevice device, PrinterPurpose purpose) async {
    bool success = false;
    switch (device.type) {
      case PrinterConnectionType.bluetooth:
        success = await _universalService.connect(device);
        break;
      case PrinterConnectionType.network:
        if (device.address != null) {
            success = await _networkService.connect(device.address!);
        }
        break;
      case PrinterConnectionType.usb:
        success = await _universalService.connect(device);
        break;
      case PrinterConnectionType.system:
        success = true; // System printers are handled by OS
        break;
    }

    if (success) {
      _assignments[purpose] = device;
      await _saveAssignments();
      _updateOverallStatus();
    }
  }

  Future<void> disconnect(PrinterPurpose purpose) async {
    if (_assignments.containsKey(purpose)) {
      final device = _assignments[purpose]!;
       switch (device.type) {
        case PrinterConnectionType.bluetooth:
           // Only disconnect if no other purpose is using this BT device (simple check)
            await _universalService.disconnect();
            break;
        case PrinterConnectionType.network:
            // Network is stateless mostly, but we can reset internal state?
             break;
        case PrinterConnectionType.usb:
             await _universalService.disconnect();
             break;
        case PrinterConnectionType.system:
             break;
      }
      _assignments.remove(purpose);
      await _saveAssignments();
      _updateOverallStatus();
    }
  }
  
  // Unified Print Method
  // For Thermal: uses escPosBytes
  // For A4/System: uses pdfBytes (future implementation via 'printing' package)
  Future<bool> printDocument({
    required PrinterPurpose purpose,
    List<int>? escPosBytes,
    List<int>? pdfBytes, // Uint8List
  }) async {
     final device = _assignments[purpose];
     if (device == null) return false;

     switch (device.type) {
       case PrinterConnectionType.bluetooth:
          if (escPosBytes == null) return false;
          try {
            await _universalService.printWithRetry(escPosBytes, reconnectDevice: device);
            return true;
          } catch (e) {
            debugPrint('🖨️ PrinterManager: BT print failed: $e');
            return false;
          }
       case PrinterConnectionType.network:
         if (escPosBytes == null) return false;
         return await _networkService.printRawData(escPosBytes);
       case PrinterConnectionType.usb:
          if (escPosBytes == null) return false;
          try {
            await _universalService.printWithRetry(escPosBytes, reconnectDevice: device);
            return true;
          } catch (e) {
            debugPrint('🖨️ PrinterManager: USB print failed: $e');
            return false;
          }
       case PrinterConnectionType.system:
         // NOTE: Native/System printing (via 'printing' package) is deferred — thermal printers handle all current use cases.
         return true; // Mock success
     }
     return false;
  }

  Future<void> printOrderReceipt(OrderModel order, Store? store, {String cashierName = "Cashier"}) async {
    if (store == null) return;
    
    // Use stored tax components if they exist, otherwise fallback to calculation (for older orders)
    double subtotal = order.subtotal > 0 ? order.subtotal : 0;
    double cgst = order.cgst > 0 ? order.cgst : 0;
    double sgst = order.sgst > 0 ? order.sgst : 0;
    double taxRatePct = order.taxRateSnapshot;

    // If stored values are missing (legacy orders), perform back-calculation
    if (subtotal == 0 && (cgst + sgst == 0)) {
      taxRatePct = order.taxRateSnapshot > 0
          ? order.taxRateSnapshot
          : (store.isTaxEnabled ? (store.taxRate ?? 0) : 0);
      double taxRate = taxRatePct / 100;
      subtotal = taxRate > 0 ? order.total / (1 + taxRate) : order.total;
      double totalTax = order.total - subtotal;
      cgst = totalTax / 2;
      sgst = totalTax / 2;
    }
    
    await _universalService.printMainReceipt(
      storeName: store.name,
      address: store.address ?? "",
      phone: store.phone ?? "",
      gstin: store.gstin ?? "",
      orderId: order.id,
      date: order.date,
      cashierName: cashierName,
      items: order.items.map((i) {
        final double unitPrice = i.priceSnapshot ?? i.item.price;
        final int qty = i.quantity;
        return {
          'name': i.item.name,
          'qty': qty,
          'price': unitPrice.toStringAsFixed(2),
          'amount': (unitPrice * qty).toStringAsFixed(2),
        };
      }).toList(),
      subtotal: subtotal,
      tax: cgst + sgst,
      discount: order.discount,
      grantTotal: order.total,
      settings: store.receipt,
      paymentSettings: store.payment,
      taxRate: taxRatePct,
      cgst: cgst,
      sgst: sgst,
      paymentMethod: order.paymentMethod,
      tableName: order.tableName,
      seatNumbers: (order.seatNumbers?.isNotEmpty ?? false) ? order.seatNumbers!.join(', ') : null,
    );
  }

  Future<void> printOrderKDS(OrderModel order, {Store? store, List<CounterModel>? counters, String billerName = "Server"}) async {
    // Check if KDS printer is assigned?
    // For now, we force print to active printer if called.

    int width = 80;
    if (store != null) {
      width = store.receipt.receiptWidth;
    }
    
    // Group Items by Counter
    Map<String, List<dynamic>> groups = {};
    
    for (var i in order.items) {
      String cId = i.item.counterId ?? 'default';
      groups.putIfAbsent(cId, () => []);
      groups[cId]!.add(i);
    }
    
    // Print Slip for each group
    for (var entry in groups.entries) {
       String cId = entry.key;
       var groupItems = entry.value; // List<OrderItem>
       
       String counterName = "KITCHEN";
       if (cId != 'default' && counters != null) {
          try {
            final match = counters.firstWhere((c) => c.id == cId);
            counterName = match.name.toUpperCase();
          } catch (_) { /* Error ignored */ }
       }

       await _universalService.printKDSReceipt(
        counterName: counterName, 
        date: order.date,
        kotNumber: order.id.length > 4 ? order.id.substring(order.id.length - 4) : order.id,
        serviceType: order.type,
        billerName: billerName,
        items: groupItems.map((i) => {
          'name': i.item.name,
          'qty': i.quantity,
          'note': i.note
        }).toList(),
        tableName: order.tableName,
        seatNumbers: (order.seatNumbers?.isNotEmpty ?? false) ? order.seatNumbers!.join(', ') : null,
        receiptWidth: width,
      );
      
      // Reduced delay for speed
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  // Legacy wrapper for backward compatibility
  Future<bool> printBytes(PrinterPurpose purpose, List<int> bytes) async {
      return printDocument(purpose: purpose, escPosBytes: bytes);
  }

  Future<void> _saveAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> jsonMap = {};
    _assignments.forEach((key, value) {
      jsonMap[key.name] = value.toJson();
    });
    await prefs.setString('printer_assignments', json.encode(jsonMap));
  }

  Future<void> _saveSavedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> jsonList = _savedDevices.map((d) => json.encode(d.toJson())).toList();
    await prefs.setStringList('saved_printer_devices', jsonList);
  }

  Future<void> _loadSavedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonList = prefs.getStringList('saved_printer_devices');
    if (jsonList != null) {
      try {
        _savedDevices.clear();
        for (var jsonStr in jsonList) {
          _savedDevices.add(PrinterDevice.fromJson(json.decode(jsonStr)));
        }
      } catch (e) { /* Error ignored */ }
    }
  }
  Future<void> _loadAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('printer_assignments');
    if (jsonString != null) {
      try {
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        jsonMap.forEach((key, value) {
          final purpose = PrinterPurpose.values.firstWhere((e) => e.name == key, orElse: () => PrinterPurpose.other);
          final device = PrinterDevice.fromJson(value);
          _assignments[purpose] = device;
        });
      } catch (e) { /* Error ignored */ }
    }
  }
  
  UniversalPrinterService get universalService => _universalService;
  // UsbPrinterService get usbService => _usbService; // Removed
  NetworkPrinterService get networkService => _networkService;
}
