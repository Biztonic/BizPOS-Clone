// ignore_for_file: constant_identifier_names
class Printer {
  final String? name;
  final String? address;
  final String? vendorId;
  final String? productId;
  final dynamic connectionType;

  Printer({this.name, this.address, this.vendorId, this.productId, this.connectionType});
}

enum ConnectionType {
  BLE,
  USB,
  NETWORK,
}
