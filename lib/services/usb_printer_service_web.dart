import 'dart:async';
import '../models/printer_device.dart';

class UsbPrinterService {
  PrinterDevice? get connectedDevice => null;
  bool get isConnected => false;

  Stream<PrinterDevice> scan() async* {
    // Nothing on web for now
  }

  Future<bool> connect(PrinterDevice device) async {

    return false;
  }

  Future<bool> disconnect() async {
    return true;
  }

  Future<void> printRaw(List<int> bytes) async {

  }
}
