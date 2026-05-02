/// Abstract scanner interface for barcode/QR hardware decoupling.
abstract class AbstractScannerService {
  /// Initialize the scanner service.
  Future<void> init();

  /// Start listening for scan events.
  /// Returns a stream of scanned barcodes.
  Stream<ScanResult> get scanStream;

  /// Trigger a manual scan (for camera-based scanning).
  Future<ScanResult?> triggerScan();

  /// Check if hardware scanner is available.
  bool get isAvailable;

  /// Dispose resources.
  void dispose();
}

/// Result of a barcode/QR scan.
class ScanResult {
  final String value;
  final ScanType type;
  final DateTime scannedAt;

  ScanResult({
    required this.value,
    required this.type,
    DateTime? scannedAt,
  }) : scannedAt = scannedAt ?? DateTime.now();
}

/// Type of scan.
enum ScanType {
  barcode,
  qrCode,
  manual,
}
