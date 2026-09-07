import 'package:cloud_firestore/cloud_firestore.dart';

class HardwareEmiHistory {
  final String id;
  final String storeHardwareId;
  final String hardwareId;
  final DateTime paymentDate;
  final double amount;
  final String? approvedBy;
  final String? transactionId;
  final String? receiptImage;
  final String remarks;
  final String status; // 'Pending', 'Approved', 'Rejected'

  HardwareEmiHistory({
    required this.id,
    required this.storeHardwareId,
    required this.hardwareId,
    required this.paymentDate,
    required this.amount,
    this.approvedBy,
    this.transactionId,
    this.receiptImage,
    this.remarks = '',
    this.status = 'Pending',
  });

  factory HardwareEmiHistory.fromMap(Map<String, dynamic> data, String id) {
    return HardwareEmiHistory(
      id: id,
      storeHardwareId: data['storeHardwareId'] ?? '',
      hardwareId: data['hardwareId'] ?? '',
      paymentDate: _parseDate(data['paymentDate']),
      amount: (data['amount'] ?? 0).toDouble(),
      approvedBy: data['approvedBy'],
      transactionId: data['transactionId'],
      receiptImage: data['receiptImage'],
      remarks: data['remarks'] ?? '',
      status: data['status'] ?? 'Pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeHardwareId': storeHardwareId,
      'hardwareId': hardwareId,
      'paymentDate': paymentDate.millisecondsSinceEpoch,
      'amount': amount,
      'approvedBy': approvedBy,
      'transactionId': transactionId,
      'receiptImage': receiptImage,
      'remarks': remarks,
      'status': status,
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

  HardwareEmiHistory copyWith({
    String? id,
    String? storeHardwareId,
    String? hardwareId,
    DateTime? paymentDate,
    double? amount,
    String? approvedBy,
    String? transactionId,
    String? receiptImage,
    String? remarks,
    String? status,
  }) {
    return HardwareEmiHistory(
      id: id ?? this.id,
      storeHardwareId: storeHardwareId ?? this.storeHardwareId,
      hardwareId: hardwareId ?? this.hardwareId,
      paymentDate: paymentDate ?? this.paymentDate,
      amount: amount ?? this.amount,
      approvedBy: approvedBy ?? this.approvedBy,
      transactionId: transactionId ?? this.transactionId,
      receiptImage: receiptImage ?? this.receiptImage,
      remarks: remarks ?? this.remarks,
      status: status ?? this.status,
    );
  }
}
