import 'dart:async';
import '../models/printer_device.dart';

class BluetoothPrinterService {
  PrinterDevice? get connectedDevice => null;
  bool get isConnected => false;

  Stream<PrinterDevice> scan() {
    return const Stream.empty();
  }

  Future<bool> connect(PrinterDevice device) async {
    return false;
  }

  Future<bool> disconnect() async {
    return true;
  }

  Future<void> printRaw(List<int> bytes) async {
    // No-op for web stub
  }
}
