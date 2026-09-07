import 'package:cloud_firestore/cloud_firestore.dart';

class StoreHardware {
  final String id;
  final String hardwareId;
  final String serialNumber;
  final String? deviceId;
  final String status; // 'Assigned', 'Returned', 'Lost', 'Damaged', 'Inactive'
  final DateTime purchaseDate;
  final DateTime assignedDate;
  final DateTime nextEmiDueDate;
  final DateTime? lastPaymentDate;
  final int emisPaid;
  final int totalEmis;
  final double initialDownPayment;
  final double buybackDepreciationPerDay;
  final double originalPrice;
  final double remainingAmount;

  StoreHardware({
    required this.id,
    required this.hardwareId,
    required this.serialNumber,
    this.deviceId,
    this.status = 'Assigned',
    required this.purchaseDate,
    required this.assignedDate,
    required this.nextEmiDueDate,
    this.lastPaymentDate,
    required this.emisPaid,
    required this.totalEmis,
    required this.initialDownPayment,
    required this.buybackDepreciationPerDay,
    required this.originalPrice,
    required this.remainingAmount,
  });

  factory StoreHardware.fromMap(Map<String, dynamic> data, String id) {
    return StoreHardware(
      id: id,
      hardwareId: data['hardwareId'] ?? '',
      serialNumber: data['serialNumber'] ?? '',
      deviceId: data['deviceId'],
      status: data['status'] ?? 'Assigned',
      purchaseDate: _parseDate(data['purchaseDate']),
      assignedDate: _parseDate(data['assignedDate']),
      nextEmiDueDate: _parseDate(data['nextEmiDueDate']),
      lastPaymentDate: data['lastPaymentDate'] != null ? _parseDate(data['lastPaymentDate']) : null,
      emisPaid: data['emisPaid'] ?? 0,
      totalEmis: data['totalEmis'] ?? 0,
      initialDownPayment: (data['initialDownPayment'] ?? 0).toDouble(),
      buybackDepreciationPerDay: (data['buybackDepreciationPerDay'] ?? 0).toDouble(),
      originalPrice: (data['originalPrice'] ?? 0).toDouble(),
      remainingAmount: (data['remainingAmount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hardwareId': hardwareId,
      'serialNumber': serialNumber,
      'deviceId': deviceId,
      'status': status,
      'purchaseDate': purchaseDate.millisecondsSinceEpoch,
      'assignedDate': assignedDate.millisecondsSinceEpoch,
      'nextEmiDueDate': nextEmiDueDate.millisecondsSinceEpoch,
      'lastPaymentDate': lastPaymentDate?.millisecondsSinceEpoch,
      'emisPaid': emisPaid,
      'totalEmis': totalEmis,
      'initialDownPayment': initialDownPayment,
      'buybackDepreciationPerDay': buybackDepreciationPerDay,
      'originalPrice': originalPrice,
      'remainingAmount': remainingAmount,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    try {
      return (value as dynamic).toDate();
    } catch (_) {
      return DateTime.now();
    }
  }

  StoreHardware copyWith({
    String? id,
    String? hardwareId,
    String? serialNumber,
    String? deviceId,
    String? status,
    DateTime? purchaseDate,
    DateTime? assignedDate,
    DateTime? nextEmiDueDate,
    DateTime? lastPaymentDate,
    int? emisPaid,
    int? totalEmis,
    double? initialDownPayment,
    double? buybackDepreciationPerDay,
    double? originalPrice,
    double? remainingAmount,
  }) {
    return StoreHardware(
      id: id ?? this.id,
      hardwareId: hardwareId ?? this.hardwareId,
      serialNumber: serialNumber ?? this.serialNumber,
      deviceId: deviceId ?? this.deviceId,
      status: status ?? this.status,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      assignedDate: assignedDate ?? this.assignedDate,
      nextEmiDueDate: nextEmiDueDate ?? this.nextEmiDueDate,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      emisPaid: emisPaid ?? this.emisPaid,
      totalEmis: totalEmis ?? this.totalEmis,
      initialDownPayment: initialDownPayment ?? this.initialDownPayment,
      buybackDepreciationPerDay: buybackDepreciationPerDay ?? this.buybackDepreciationPerDay,
      originalPrice: originalPrice ?? this.originalPrice,
      remainingAmount: remainingAmount ?? this.remainingAmount,
    );
  }

  double calculateBuybackValue(DateTime currentDate) {
    int daysPassed = currentDate.difference(purchaseDate).inDays;
    if (daysPassed < 0) daysPassed = 0;
    
    // Original Price - (Days Passed × Depreciation) - Pending EMI
    double depreciation = daysPassed * buybackDepreciationPerDay;
    double buyback = originalPrice - depreciation - remainingAmount;
    
    return buyback > 0 ? buyback : 0;
  }
}
