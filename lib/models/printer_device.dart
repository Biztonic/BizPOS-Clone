enum PrinterConnectionType { bluetooth, network, usb, system }

enum PrinterPaperSize { mm58, mm80, isoA4 }

class PrinterDevice {
  final String name;
  final String? address; // MAC for BT, IP for Network, UUID for System
  final String? vendorId; // USB VID
  final String? productId; // USB PID
  final PrinterConnectionType type;
  final PrinterPaperSize paperSize;

  PrinterDevice({
    required this.name,
    this.address,
    this.vendorId,
    this.productId,
    this.type = PrinterConnectionType.bluetooth,
    this.paperSize = PrinterPaperSize.mm80, // Default to standard thermal
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'vendorId': vendorId,
      'productId': productId,
      'type': type.index,
      'paperSize': paperSize.index,
    };
  }

  factory PrinterDevice.fromJson(Map<String, dynamic> json) {
    return PrinterDevice(
      name: json['name'],
      address: json['address'],
      vendorId: json['vendorId'],
      productId: json['productId'],
      type: PrinterConnectionType.values[json['type'] ?? 0],
      paperSize: PrinterPaperSize.values[json['paperSize'] ?? 1], // Default mm80 if missing
    );
  }
}
