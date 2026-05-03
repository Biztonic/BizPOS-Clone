import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import '../models/printer_device.dart';

class UsbPrinterService {
  UsbPort? _port;
  PrinterDevice? _connectedDevice;
  
  PrinterDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _port != null;

  Stream<PrinterDevice> scan() async* {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    for (var device in devices) {
      yield PrinterDevice(
        name: device.productName ?? "USB Device", 
        vendorId: device.vid.toString(), 
        productId: device.pid.toString()
      );
    }
  }

  Future<bool> connect(PrinterDevice device) async {
    try {
      if (device.vendorId == null || device.productId == null) return false;
      
      List<UsbDevice> devices = await UsbSerial.listDevices();
      UsbDevice? target = devices.firstWhere(
        (d) => d.vid.toString() == device.vendorId && d.pid.toString() == device.productId,
        orElse: () => throw Exception("Device not found")
      );
      
      _port = await target.create();
      bool openResult = await _port!.open();
      if (!openResult) {

        return false;
      }

      // Standard ESC/POS configuration
      await _port!.setDTR(true);
      await _port!.setRTS(true);
      
      // Standard Baud Rates for Thermal Printers: 9600, 19200, 38400, 57600, 115200
      // 115200 is most common for USB-Serial adapters inside printers.
      _port!.setPortParameters(115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

      _connectedDevice = device;
      return true;
    } catch (e) {

      // Clean up if partial connection
      if (_port != null) {
        await _port!.close();
        _port = null;
      }
      return false;
    }
  }

  Future<bool> disconnect() async {
    if (_port != null) {
      await _port!.close();
      _port = null;
      _connectedDevice = null;
    }
    return true;
  }

  Future<void> printRaw(List<int> bytes) async {
    if (_port != null) {
      await _port!.write(Uint8List.fromList(bytes));
    }
  }
}
