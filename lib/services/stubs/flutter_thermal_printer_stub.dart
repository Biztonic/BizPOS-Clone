import 'dart:async';
import 'printer_stub.dart';

class FlutterThermalPrinter {
  static final FlutterThermalPrinter instance = FlutterThermalPrinter._();
  FlutterThermalPrinter._();

  Stream<List<Printer>> get devicesStream => Stream.value([]);
  
  Future<void> getPrinters({required List<dynamic> connectionTypes}) async {}
  Future<bool> connect(Printer printer) async => false;
  Future<bool> disconnect(Printer printer) async => false;
  Future<void> printData(Printer printer, List<int> data, {bool longData = false}) async {}
}
