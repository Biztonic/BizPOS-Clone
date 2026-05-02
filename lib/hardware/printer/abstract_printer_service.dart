/// Abstract printer interface for hardware decoupling.
///
/// All printer implementations (Bluetooth, USB, Network, Web)
/// must implement this interface.
abstract class AbstractPrinterService {
  /// Initialize the printer service.
  Future<void> init();

  /// Print a receipt from order data.
  Future<bool> printReceipt(Map<String, dynamic> orderData, {
    Map<String, dynamic>? storeSettings,
    String? printerAddress,
  });

  /// Print a KOT (Kitchen Order Ticket).
  Future<bool> printKot(Map<String, dynamic> kotData, {
    String? printerAddress,
  });

  /// Print a generic report.
  Future<bool> printReport(String reportContent, {
    String? printerAddress,
  });

  /// Open cash drawer (if supported).
  Future<bool> openCashDrawer({String? printerAddress});

  /// Discover available printers.
  Future<List<Map<String, dynamic>>> discoverPrinters();

  /// Test print connection.
  Future<bool> testPrint({String? printerAddress});

  /// Get current printer status.
  PrinterStatus get status;

  /// Dispose resources.
  void dispose();
}

/// Printer connection status.
enum PrinterStatus {
  connected,
  disconnected,
  printing,
  error,
  discovering,
}
