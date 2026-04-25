

class NetworkPrinterService {
  String? get connectedIp => null;
  bool get isConnected => false;

  Future<bool> connect(String ip, {int port = 9100}) async {

    return false;
  }

  Future<bool> disconnect() async {
    return true;
  }

  Future<bool> printRawData(List<int> bytes) async {

    return false;
  }
}
