import 'dart:io';

class NetworkPrinterService {
  Socket? _socket;
  String? _connectedIp;
  
  String? get connectedIp => _connectedIp;
  bool get isConnected => _socket != null;

  Future<bool> connect(String ip, {int port = 9100}) async {
    try {
      _socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      _connectedIp = ip;
      return true;
    } catch (e) {

      return false;
    }
  }

  Future<bool> disconnect() async {
    if (_socket != null) {
      await _socket!.close();
      _socket = null;
      _connectedIp = null;
    }
    return true;
  }

  Future<bool> printRawData(List<int> bytes) async {
    if (_socket == null) return false;
    
    try {
      _socket!.add(bytes);
      await _socket!.flush();
      return true;
    } catch (e) {

      // If write fails, the connection is likely dead
      await disconnect();
      return false;
    }
  }
}
