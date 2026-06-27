// ignore_for_file: constant_identifier_names
import 'dart:async';
import 'package:flutter/foundation.dart'; // Changed from 'show kIsWeb' to import all of foundation for debugPrint
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart'
    if (dart.library.js_util) 'package:biztonic_pos/services/stubs/flutter_thermal_printer_stub.dart';
import 'package:flutter_thermal_printer/utils/printer.dart'
    if (dart.library.js_util) 'package:biztonic_pos/services/stubs/printer_stub.dart';

import 'dart:ui' as ui;
import 'package:image/image.dart' as img;

// ignore: duplicate_import, unused_import, unnecessary_import
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../models/printer_device.dart';
import '../models/settings.dart'; // Added import
import '../features/receipt_printing/models/receipt_config.dart';
import '../features/receipt_printing/models/receipt_content.dart';
import '../features/receipt_printing/core/receipt_generator.dart';
import '../features/receipt_printing/core/receipt_image_renderer.dart';

class UniversalPrinterService {
  final _flutterThermalPrinter = kIsWeb ? null : FlutterThermalPrinter.instance;

  // Stream controller to expose unified PrinterDevices
  final StreamController<List<PrinterDevice>> _devicesController =
      StreamController<List<PrinterDevice>>.broadcast();
  Stream<List<PrinterDevice>> get devicesStream => _devicesController.stream;

  // Connection status stream
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  Printer? _connectedPrinter;
  bool get isConnected => _connectedPrinter != null;
  Printer? get connectedPrinter => _connectedPrinter;

  DateTime? _lastUsedAt; // Track last interaction

  // PRINT QUEUE: Ensures only one print job runs at a time (FIFO)
  // This prevents buffer interleaving/corruption when multiple print requests are made rapidly.
  Future<void> _lock = Future.value();

  static final UniversalPrinterService _instance =
      UniversalPrinterService._internal();
  factory UniversalPrinterService() => _instance;

  UniversalPrinterService._internal() {
    if (!kIsWeb && _flutterThermalPrinter != null) {
      // Listen to the library's stream and map to our model
      _flutterThermalPrinter!.devicesStream.listen((list) {
        final devices = list.map((p) => _mapToPrinterDevice(p)).toList();
        _devicesController.add(devices);
      });
    }
  }

  void startScan() {
    // Scan for BLE and USB
    if (!kIsWeb) {
      _flutterThermalPrinter?.getPrinters(connectionTypes: [
        ConnectionType.BLE,
        ConnectionType.USB,
      ]);
    }
  }

  Future<bool> connect(PrinterDevice device) async {
    // Transform back to Printer object for connection
    Printer printer = Printer(
      name: device.name,
      address: device.address,
      vendorId: device.vendorId,
      productId: device.productId,
      connectionType: _mapToConnectionType(device.type),
    );

    try {
      if (!kIsWeb && _flutterThermalPrinter != null) {
        await _flutterThermalPrinter!.connect(printer);
        _connectedPrinter = printer;
        _connectionController.add(true);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
    // return true;
  }

  Future<bool> disconnect() async {
    if (_connectedPrinter != null &&
        !kIsWeb &&
        _flutterThermalPrinter != null) {
      await _flutterThermalPrinter!.disconnect(_connectedPrinter!);
      _connectedPrinter = null;
      _connectionController.add(false);
      return true;
    }
    return false;
  }

  Future<void> printRaw(List<int> data, {PrinterDevice? device}) async {
    if (kIsWeb) return;

    // Capture the current lock and chain the next print job
    final previousLock = _lock;
    final completer = Completer<void>();
    _lock = completer.future;

    try {
      // Wait for previous jobs to finish (even if they fail)
      await previousLock.catchError((_) {});

      // Determine which printer to use
      Printer? target;
      if (device != null) {
        // If device specified, ensure we have a Printer object for it
        target = Printer(
          name: device.name,
          address: device.address,
          vendorId: device.vendorId,
          productId: device.productId,
          connectionType: _mapToConnectionType(device.type),
        );
      } else {
        target = _connectedPrinter;
      }

      if (target == null) {
        debugPrint(
            '🖨️ PRINT: ERROR - No target printer specified or connected!');
        throw Exception('No target printer');
      }

      // 1. Pre-print Handshake: If idle for > 30s, verify first
      if (_lastUsedAt != null &&
          DateTime.now().difference(_lastUsedAt!).inSeconds > 30) {
        debugPrint('🖨️ PRINT: Idle for >30s, verifying connection...');
        final ok = await _verifyConnectionInternal(target);
        if (!ok) {
          throw Exception('Printer connection verified dead during idle check');
        }
      }

      if (_flutterThermalPrinter != null) {
        try {
          debugPrint(
              '🖨️ PRINT: Sending ${data.length} bytes to ${target.connectionType} printer (${target.name})');
          await _flutterThermalPrinter!.printData(target, data, longData: true, chunkSize: 200);
          _lastUsedAt = DateTime.now();

          // Update last connected if it was null
          _connectedPrinter ??= target;

          debugPrint('🖨️ PRINT: All data sent successfully');
        } catch (e) {
          debugPrint(
              '🖨️ PRINT: FAILED - $e. Marking printer as disconnected.');
          if (_connectedPrinter?.address == target.address) {
            _connectedPrinter = null;
            _connectionController.add(false);
          }
          rethrow; // Let callers know print failed
        }
      } else {
        debugPrint('🖨️ PRINT: ERROR - No printer service available!');
        throw Exception('Printer service unavailable');
      }
      completer.complete();
    } catch (e) {
      completer.completeError(e);
    }
  }

  /// Sends a lightweight ESC/POS reset command to verify the printer link is alive.
  /// Returns true if the printer responded (no exception), false otherwise.
  Future<bool> verifyConnection() async {
    // PUBLIC: Use queue lock
    final previousLock = _lock;
    final completer = Completer<void>();
    _lock = completer.future;

    try {
      await previousLock.catchError((_) {});
      final result = await _verifyConnectionInternal();
      completer.complete();
      return result;
    } catch (e) {
      completer.completeError(e);
      return false;
    }
  }

  Future<bool> _verifyConnectionInternal([Printer? specificTarget]) async {
    final target = specificTarget ?? _connectedPrinter;
    if (target == null || kIsWeb || _flutterThermalPrinter == null) {
      return false;
    }
    try {
      debugPrint('🖨️ VERIFY: Sending heartbeat to ${target.name}...');
      // ESC @ = Initialize/Reset printer — harmless, no paper output
      await _flutterThermalPrinter!
          .printData(target, [0x1B, 0x40], longData: false);
      _lastUsedAt = DateTime.now();
      return true;
    } catch (e) {
      debugPrint('🖨️ VERIFY: Connection dead — $e');
      if (_connectedPrinter?.address == target.address) {
        _connectedPrinter = null;
        _connectionController.add(false);
      }
      return false;
    }
  }

  /// Attempts to print; on failure tries to reconnect using [reconnectDevice] and retries once.
  Future<void> printWithRetry(List<int> data,
      {PrinterDevice? reconnectDevice}) async {
    try {
      await printRaw(data, device: reconnectDevice);
    } catch (e) {
      debugPrint('🖨️ RETRY: First attempt failed: $e');
      if (reconnectDevice != null) {
        debugPrint('🖨️ RETRY: Delaying 1s before reconnect and retry...');
        await Future.delayed(const Duration(seconds: 1));

        final retryOk = await connect(reconnectDevice);
        if (retryOk) {
          debugPrint('🖨️ RETRY: Reconnected successfully, retrying print...');
          await printRaw(data, device: reconnectDevice);
          return;
        } else {
          debugPrint('🖨️ RETRY: FAILED to reconnect during retry.');
        }
      }
      rethrow;
    }
  }

  // Schema-specified printReceipt using esc_pos_utils_plus Generator
  Future<void> printReceipt({
    required String storeName,
    required String orderId,
    required List<Map<String, dynamic>> items,
    required double total,
    required double tax,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    final hasMarathi = ReceiptGenerator.containsNonLatin1(storeName) ||
        items.any((item) => ReceiptGenerator.containsNonLatin1(item['name'].toString()));

    if (hasMarathi) {
      final header = ReceiptHeader(storeName: storeName);
      final billInfo = ReceiptBillInfo(billNo: orderId, date: DateTime.now(), cashierName: 'Cashier');
      final receiptItems = items.map((item) {
        final double qty = double.tryParse(item['qty'].toString()) ?? 1.0;
        final double price = double.tryParse(item['price'].toString()) ?? 0.0;
        return ReceiptItem(
          name: item['name'].toString(),
          quantity: qty,
          price: price,
          amount: qty * price,
        );
      }).toList();
      final summary = ReceiptKeyValSummary(
        rows: [],
        grandTotal: ReceiptKeyVal(label: 'Total', value: total.toStringAsFixed(2), isBold: true, isLarge: true),
      );
      final content = ReceiptContent(
        header: header,
        billInfo: billInfo,
        items: receiptItems,
        summary: summary,
        payment: null,
        footer: null,
      );
      
      final config = ReceiptConfig.mm80();
      final uiImage = await ReceiptImageRenderer.renderCustomerReceipt(content: content, config: config);
      final rawBytes = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rawBytes != null) {
        final imgImage = img.Image.fromBytes(
          width: uiImage.width,
          height: uiImage.height,
          bytes: rawBytes.buffer,
          order: img.ChannelOrder.rgba,
        );
        final optimizedImage = _optimizeAndBinarize(imgImage, 576);
        List<int> printBytes = [];
        printBytes += generator.reset();
        printBytes += generator.image(optimizedImage);
        printBytes += generator.feed(2);
        printBytes += generator.cut();
        await printRaw(printBytes);
        return;
      }
    }

    List<int> bytes = [];

    bytes += generator.reset();
    bytes += generator.text(storeName,
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ));
    bytes += generator.feed(1);
    bytes += generator.text('Order #$orderId',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text(
        'Date: ${DateTime.now().toString().substring(0, 16)}',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(1);
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'Item', width: 6),
      PosColumn(
          text: 'Qty',
          width: 2,
          styles: const PosStyles(align: PosAlign.right)),
      PosColumn(
          text: 'Price',
          width: 4,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.hr();
    for (var item in items) {
      bytes += generator.row([
        PosColumn(text: item['name'].toString(), width: 6),
        PosColumn(
            text: '${item['qty']}',
            width: 2,
            styles: const PosStyles(align: PosAlign.right)),
        PosColumn(
            text: item['price'].toString(),
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'Total', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
          text: total.toStringAsFixed(2),
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);
    bytes += generator.feed(2);
    bytes += generator.cut();

    await printRaw(bytes);
  }

  Future<void> printMainReceipt({
    required String storeName,
    required String address,
    required String phone,
    required String gstin,
    required String orderId,
    required DateTime date,
    required String cashierName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double tax,
    required double discount,
    required double grantTotal,
    required ReceiptSettings settings,
    PaymentSettings? paymentSettings,
    double taxRate = 0,
    double? cgst,
    double? sgst,
    String paymentMethod = "Cash",
    String? tableName,
    String? seatNumbers,
  }) async {
    // 1. Setup Config
    final config = settings.receiptWidth == 58
        ? ReceiptConfig.mm58()
        : ReceiptConfig.mm80();
    final generator = ReceiptGenerator(config, settings: settings);

    // Dynamic QR Logic
    String? effectiveQrData;
    if (settings.showQr) {
      if (paymentSettings != null && paymentSettings.upiId.isNotEmpty) {
        // Generate UPI URI
        // Format: upi://pay?pa=<UPI_ID>&pn=<NAME>&am=<AMOUNT>&cu=INR
        final String pa = paymentSettings.upiId;
        final String pn = Uri.encodeComponent(paymentSettings.upiName.isNotEmpty
            ? paymentSettings.upiName
            : storeName);
        final String am = grantTotal.toStringAsFixed(2);
        effectiveQrData = "upi://pay?pa=$pa&pn=$pn&am=$am&cu=INR";
      } else if (settings.qrData.isNotEmpty) {
        effectiveQrData = settings.qrData;
      }
    }

    // 2. Prepare Content
    final header = ReceiptHeader(
      storeName: settings.showStoreName ? storeName : '',
      address: settings.showAddress && address.isNotEmpty ? address : null,
      phone: settings.showPhone && phone.isNotEmpty ? phone : null,
      gstin: settings.showTaxDetails && gstin.isNotEmpty ? gstin : null,
      customMessage: settings.customHeaderMessage.isNotEmpty
          ? settings.customHeaderMessage
          : null,
    );

    final billInfo = ReceiptBillInfo(
      billNo: settings.showOrderNo
          ? (orderId.length > 5
              ? orderId.substring(orderId.length - 5)
              : orderId)
          : '',
      date: date,
      cashierName: cashierName,
      tokenNo: settings.showTokenNo
          ? (orderId.length > 4
              ? orderId.substring(orderId.length - 4)
              : orderId)
          : null,
      tableName: tableName,
      seatNumbers: seatNumbers,
    );

    final receiptItems = items.map((item) {
      return ReceiptItem(
        name: item['name'],
        quantity: double.tryParse(item['qty'].toString()) ?? 1,
        price: double.tryParse(item['price'].toString()) ?? 0,
        amount: double.tryParse(item['amount'].toString()) ?? 0,
      );
    }).toList();

    // Summary
    List<ReceiptKeyVal> summaryRows = [];

    // Calculate Total Qty — OrderItem.quantity is int, handle all types safely
    int totalQty = items.fold<int>(0, (p, e) {
      final qty = e['qty'];
      if (qty is int) return p + qty;
      if (qty is double) return p + qty.toInt();
      return p + (int.tryParse(qty.toString()) ?? 0);
    });

    summaryRows.add(ReceiptKeyVal(label: "Total Qty: $totalQty", value: ""));
    summaryRows.add(
        ReceiptKeyVal(label: "Subtotal", value: subtotal.toStringAsFixed(2)));

    if (settings.showDiscount && discount > 0) {
      summaryRows.add(ReceiptKeyVal(
          label: "Discount", value: "-${discount.toStringAsFixed(2)}"));
    }

    if (settings.showTaxDetails && tax > 0) {
      double displayCgst = cgst ?? (tax / 2);
      double displaySgst = sgst ?? (tax / 2);
      double halfRate = taxRate / 2;
      String rateLabel = halfRate == halfRate.roundToDouble()
          ? halfRate.toStringAsFixed(0)
          : halfRate.toStringAsFixed(1);
      summaryRows.add(ReceiptKeyVal(
          label: "CGST@$rateLabel%", value: displayCgst.toStringAsFixed(2)));
      summaryRows.add(ReceiptKeyVal(
          label: "SGST@$rateLabel%", value: displaySgst.toStringAsFixed(2)));
    }

    final summary = ReceiptKeyValSummary(
      rows: summaryRows,
      grandTotal: ReceiptKeyVal(
          label: "Grand Total",
          value: grantTotal.toStringAsFixed(2),
          isBold: true,
          isLarge: true),
    );

    // Payment Details
    final payment = ReceiptKeyValSummary(rows: [
      ReceiptKeyVal(label: "Payment", value: paymentMethod),
    ]);

    // Footer
    final footer = settings.showFooter
        ? ReceiptFooter(
            message: settings.upsellMessage.isNotEmpty
                ? settings.upsellMessage
                : "Thank You Visit Again !!!",
            poweredBy: "Powered by Biztonic POS",
            qrData: effectiveQrData,
          )
        : null;

    final content = ReceiptContent(
      header: header,
      billInfo: billInfo,
      items: receiptItems,
      summary: summary,
      payment: payment,
      footer: footer,
    );

    // DEBUG: Log receipt assembly details
    debugPrint(
        '🖨️ RECEIPT: Items=${receiptItems.length}, StoreName=$storeName, HasFooter=${footer != null}, HasQR=${footer?.qrData != null}');

    final hasMarathi = ReceiptGenerator.containsNonLatin1(storeName) ||
        ReceiptGenerator.containsNonLatin1(address) ||
        ReceiptGenerator.containsNonLatin1(cashierName) ||
        ReceiptGenerator.containsNonLatin1(tableName ?? '') ||
        ReceiptGenerator.containsNonLatin1(seatNumbers ?? '') ||
        items.any((item) => ReceiptGenerator.containsNonLatin1(item['name'].toString())) ||
        ReceiptGenerator.containsNonLatin1(settings.customHeaderMessage) ||
        ReceiptGenerator.containsNonLatin1(settings.upsellMessage);

    if (hasMarathi) {
      final uiImage = await ReceiptImageRenderer.renderCustomerReceipt(
        content: content,
        config: config,
      );
      final rawBytes = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rawBytes != null) {
        final imgImage = img.Image.fromBytes(
          width: uiImage.width,
          height: uiImage.height,
          bytes: rawBytes.buffer,
          order: img.ChannelOrder.rgba,
        );
        final int targetWidth = settings.receiptWidth == 58 ? 384 : 576;
        final optimizedImage = _optimizeAndBinarize(imgImage, targetWidth);
        final profile = await CapabilityProfile.load();
        final imgGenerator = Generator(settings.receiptWidth == 58 ? PaperSize.mm58 : PaperSize.mm80, profile);
        List<int> printBytes = [];
        printBytes += imgGenerator.reset();
        printBytes += imgGenerator.image(optimizedImage);
        
        if (footer != null && footer.qrData != null && footer.qrData!.isNotEmpty) {
           printBytes += imgGenerator.feed(1);
           printBytes += [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x06];
           printBytes += [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31];
           int len = footer.qrData!.length + 3;
           int pL = len % 256;
           int pH = len ~/ 256;
           printBytes += [0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30];
           for (int i = 0; i < footer.qrData!.length; i++) {
             printBytes.add(footer.qrData!.codeUnitAt(i));
           }
           printBytes += [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30];
        }
        
        printBytes += imgGenerator.feed(3);
        printBytes += imgGenerator.cut();
        
        await printRaw(printBytes);
        return;
      }
    }

    // 3. Generate
    List<int> bytes = List.from(generator.generate(content));

    // DEBUG: Log bytes generated
    debugPrint('🖨️ RECEIPT: Generated ${bytes.length} bytes');

    // 4. Print
    await printRaw(bytes);
  }

  Future<void> printKDSReceipt({
    required String counterName,
    required DateTime date,
    required String kotNumber,
    required String serviceType,
    required String billerName,
    required List<Map<String, dynamic>> items,
    String? tableName,
    String? seatNumbers,
    int receiptWidth = 80, // Added width parameter, default 80mm
  }) async {
    final hasMarathi = ReceiptGenerator.containsNonLatin1(counterName) ||
        ReceiptGenerator.containsNonLatin1(serviceType) ||
        ReceiptGenerator.containsNonLatin1(billerName) ||
        ReceiptGenerator.containsNonLatin1(tableName ?? '') ||
        ReceiptGenerator.containsNonLatin1(seatNumbers ?? '') ||
        items.any((item) => ReceiptGenerator.containsNonLatin1(item['name'].toString()) || ReceiptGenerator.containsNonLatin1(item['note'] ?? ''));

    if (hasMarathi) {
      final uiImage = await ReceiptImageRenderer.renderKdsReceipt(
        counterName: counterName,
        date: date,
        kotNumber: kotNumber,
        serviceType: serviceType,
        billerName: billerName,
        items: items,
        tableName: tableName,
        seatNumbers: seatNumbers,
        receiptWidth: receiptWidth,
      );
      final rawBytes = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rawBytes != null) {
        final imgImage = img.Image.fromBytes(
          width: uiImage.width,
          height: uiImage.height,
          bytes: rawBytes.buffer,
          order: img.ChannelOrder.rgba,
        );
        final int targetWidth = receiptWidth == 58 ? 384 : 576;
        final optimizedImage = _optimizeAndBinarize(imgImage, targetWidth);
        final profile = await CapabilityProfile.load();
        final imgGenerator = Generator(receiptWidth == 58 ? PaperSize.mm58 : PaperSize.mm80, profile);
        List<int> printBytes = [];
        printBytes += imgGenerator.reset();
        printBytes += imgGenerator.image(optimizedImage);
        printBytes += imgGenerator.feed(3);
        printBytes += imgGenerator.cut();
        await printRaw(printBytes);
        return;
      }
    }

    const esc = '\x1B';
    const alignCenter = '$esc\x61\x01';
    const boldOn = '$esc\x45\x01';
    const boldOff = '$esc\x45\x00';
    // Calculate Dimensions
    // 58mm ~ 32 chars, 80mm ~ 48 chars
    final int charsPerLine = receiptWidth == 58 ? 32 : 48;
    final int qtyColWidth =
        receiptWidth == 58 ? 5 : 8; // Enough for "Qty."(4) + space
    final int itemColWidth = charsPerLine - qtyColWidth;

    final String dashLine = List.filled(charsPerLine, '-').join();

    List<int> bytes = [];
    // Sanitize text for thermal printers: replace non-Latin1 chars with '?'
    void add(String s) {
      for (int i = 0; i < s.length; i++) {
        int c = s.codeUnitAt(i);
        if (c <= 0xFF) {
          bytes.add(c);
        } else {
          bytes.add(0x3F); // '?'
        }
      }
    }

    add('$esc\x40'); // Initialize

    // 1. HEADER
    add(alignCenter);
    add(boldOn);
    add('$esc\x21\x10'); // Double Height
    add('$counterName\n');
    add('$esc\x21\x00'); // Reset
    add(boldOff);

    // Date & Time
    String formattedDate =
        "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    add('$formattedDate\n');

    // KOT Number
    add('KOT - $kotNumber\n');

    // Service Type (Large, Bold)
    add(boldOn);
    add('$esc\x21\x10'); // Double height
    add('$serviceType\n');
    add('$esc\x21\x00');
    add(boldOff);

    add('$dashLine\n');

    // 2. INFO
    add('Biller: $billerName\n');
    if (tableName != null && tableName.isNotEmpty) {
      add('Table: $tableName\n');
    }
    if (seatNumbers != null && seatNumbers.isNotEmpty) {
      add('Seats: $seatNumbers\n');
    }
    add('$dashLine\n');

    // 3. ITEMS
    // Header
    // "Item" (Left) ... "Qty" (Right)
    String headerItem = "Item";
    String headerQty = "Qty";

    // Pad Item to fill visible space minus Qty space
    // Actually, simple aligned columns:
    // [ItemName ......] [Qty]

    add(boldOn);
    // Construct Header Line
    // We want "Item" at start, "Qty" at end of line? Or fixed columns?
    // Using Fixed Columns for alignment.
    // "Item" + spaces + "Qty"
    String headerLine =
        headerItem.padRight(itemColWidth) + headerQty.padLeft(qtyColWidth);
    // Ensure it fits exactly charsPerLine
    if (headerLine.length > charsPerLine) {
      headerLine = headerLine.substring(0, charsPerLine);
    }

    add('$headerLine\n');
    add(boldOff);
    add('$dashLine\n'); // Optional separator or empty

    for (var item in items) {
      String name = item['name'];
      String qty = item['qty'].toString();

      add(boldOn);

      // Process Name (Truncate or wrap?)
      // Truncate for single line simplicity in KDS usually, or let it wrap if needed?
      // Let's Truncate to keep alignment clean as per user request "properly on page".
      String pName = name.length > itemColWidth
          ? name.substring(0, itemColWidth)
          : name.padRight(itemColWidth);

      // Process Qty
      String pQty = qty.padLeft(qtyColWidth);

      add("$pName$pQty\n");
      add(boldOff);

      // Notes/Modifiers
      if (item['note'] != null && item['note'].isNotEmpty) {
        add("  (Note: ${item['note']})\n");
      }
    }

    // Footer space
    // Footer feed + cut
    add('\n\n\n');
    // GS V 1 : Partial cut (universally supported)
    bytes += [0x1D, 0x56, 0x01];

    await printRaw(bytes);
  }

  // --- Mappers ---

  PrinterDevice _mapToPrinterDevice(Printer p) {
    PrinterConnectionType type;
    switch (p.connectionType) {
      case ConnectionType.BLE:
        type = PrinterConnectionType.bluetooth;
        break;
      case ConnectionType.USB:
        type = PrinterConnectionType.usb;
        break;
      case ConnectionType.NETWORK:
        type = PrinterConnectionType.network;
        break;
      default:
        type = PrinterConnectionType.bluetooth;
    }

    return PrinterDevice(
      name: p.name ?? "Unknown Printer",
      address: p.address,
      vendorId: p.vendorId,
      productId: p.productId,
      type: type,
    );
  }

  ConnectionType _mapToConnectionType(PrinterConnectionType type) {
    switch (type) {
      case PrinterConnectionType.bluetooth:
        return ConnectionType.BLE;
      case PrinterConnectionType.usb:
        return ConnectionType.USB;
      case PrinterConnectionType.network:
        return ConnectionType.NETWORK;
      default:
        return ConnectionType.BLE;
    }
  }

  img.Image _optimizeAndBinarize(img.Image highResImage, int targetWidth) {
    final int targetHeight = (highResImage.height * targetWidth) ~/ highResImage.width;
    final resized = img.copyResize(
      highResImage,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.average,
    );

    for (final pixel in resized) {
      final double luminance = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
      if (luminance < 200) {
        pixel.r = 0;
        pixel.g = 0;
        pixel.b = 0;
      } else {
        pixel.r = 255;
        pixel.g = 255;
        pixel.b = 255;
      }
      pixel.a = 255;
    }
    return resized;
  }
}
