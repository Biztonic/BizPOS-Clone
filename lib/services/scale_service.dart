import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';

class ScaleService {
  UsbPort? _port;
  StreamSubscription<Uint8List>? _subscription;
  final StreamController<String> _weightController = StreamController<String>.broadcast();

  Stream<String> get weightStream => _weightController.stream;

  Future<List<UsbDevice>> getDevices() async {
    return await UsbSerial.listDevices();
  }

  Future<bool> connect(UsbDevice device) async {
    try {
      _port = await device.create();
      if (_port == null) return false;

      bool openResult = await _port!.open();
      if (!openResult) return false;

      await _port!.setDTR(true);
      await _port!.setRTS(true);
      
      // Standard scale settings (can be made configurable)
      await _port!.setPortParameters(
        9600, 
        UsbPort.DATABITS_8, 
        UsbPort.STOPBITS_1, 
        UsbPort.PARITY_NONE
      );

      _port!.inputStream?.listen((Uint8List data) {
        // Append to buffer
        _buffer.addAll(data);
        
        // Check for line terminators
        while (_buffer.contains(10) || _buffer.contains(13)) { // \n or \r
          int index = _buffer.indexWhere((b) => b == 10 || b == 13);
          if (index == -1) break;
          
          List<int> lineBytes = _buffer.sublist(0, index);
          _buffer.removeRange(0, index + 1); // Remove processed line + terminator
          
          if (lineBytes.isNotEmpty) {
            String line = String.fromCharCodes(lineBytes).trim();
            _parseWeight(line);
          }
        }
      });

      return true;
    } catch (e) {

      return false;
    }
  }

  void _parseWeight(String line) {
     // Typical Format: ST,GS,+  1.23kg or just 1.23
     // Regex to find decimal number
     final regex = RegExp(r'[+-]?\d*\.?\d+');
     final match = regex.firstMatch(line);
     if (match != null) {
        String weight = match.group(0)!;
        _weightController.add(weight);
     }
  }

  final List<int> _buffer = [];

  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _port?.close();
    _port = null;
  }
}
