class CounterModel {
  final String id;
  final String name;
  final String? assignedPrinterId;
  final Map<String, dynamic>? printerDevice; // Stored as json map for simplicity or we can use ID
  final bool isCfdEnabled;

  CounterModel({
    required this.id,
    required this.name,
    this.assignedPrinterId,
    this.printerDevice,
    this.isCfdEnabled = false,
  });

  factory CounterModel.fromMap(Map<String, dynamic> data, String id) {
    return CounterModel(
      id: id,
      name: data['name'] ?? '',
      assignedPrinterId: data['assignedPrinterId'],
      printerDevice: data['printerDevice'],
      isCfdEnabled: data['isCfdEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'assignedPrinterId': assignedPrinterId,
      'printerDevice': printerDevice,
      'isCfdEnabled': isCfdEnabled,
    };
  }
}
