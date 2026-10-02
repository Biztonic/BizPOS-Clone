import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _parseDate(dynamic d) {
  if (d is Timestamp) return d.toDate();
  if (d is DateTime) return d;
  if (d is int) return DateTime.fromMillisecondsSinceEpoch(d);
  if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
  return DateTime.now();
}

/// Represents an Udhari (Customer Credit / Borrow) ledger entry.
class UdhariTransaction {
  final String id;
  final String customerId;
  final String storeId;
  final String type; // 'borrow' (debit / credit taken) or 'payment' (credit / settled)
  final double amount;
  final double balanceAfter;
  final DateTime date;
  final String? notes;
  final String? referenceId; // Bill / Order ID or Receipt #
  final String? paymentMode; // Cash, UPI, Card, Bank (for payments)
  final String? createdBy;

  UdhariTransaction({
    required this.id,
    required this.customerId,
    required this.storeId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.date,
    this.notes,
    this.referenceId,
    this.paymentMode,
    this.createdBy,
  });

  factory UdhariTransaction.fromMap(Map<String, dynamic> map, String id) {
    return UdhariTransaction(
      id: id,
      customerId: map['customerId'] ?? '',
      storeId: map['storeId'] ?? '',
      type: map['type'] ?? 'borrow',
      amount: (map['amount'] ?? 0).toDouble(),
      balanceAfter: (map['balanceAfter'] ?? 0).toDouble(),
      date: _parseDate(map['date']),
      notes: map['notes'],
      referenceId: map['referenceId'],
      paymentMode: map['paymentMode'],
      createdBy: map['createdBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'storeId': storeId,
      'type': type,
      'amount': amount,
      'balanceAfter': balanceAfter,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'referenceId': referenceId,
      'paymentMode': paymentMode,
      'createdBy': createdBy,
    };
  }

  Map<String, dynamic> toHiveMap() {
    return {
      'id': id,
      'customerId': customerId,
      'storeId': storeId,
      'type': type,
      'amount': amount,
      'balanceAfter': balanceAfter,
      'date': date.toIso8601String(),
      'notes': notes,
      'referenceId': referenceId,
      'paymentMode': paymentMode,
      'createdBy': createdBy,
    };
  }
}

/// Represents a Coupon issued to or available for a customer.
class CustomerCoupon {
  final String id;
  final String customerId;
  final String storeId;
  final String code;
  final String title;
  final String? description;
  final String discountType; // 'percentage' or 'flat'
  final double discountValue; // e.g. 10 (%) or 100 ($/₹)
  final double minOrderValue;
  final DateTime validUntil;
  final bool isRedeemed;
  final DateTime? redeemedAt;

  CustomerCoupon({
    required this.id,
    required this.customerId,
    required this.storeId,
    required this.code,
    required this.title,
    this.description,
    this.discountType = 'percentage',
    required this.discountValue,
    this.minOrderValue = 0.0,
    required this.validUntil,
    this.isRedeemed = false,
    this.redeemedAt,
  });

  bool get isExpired => DateTime.now().isAfter(validUntil);
  bool get isValid => !isRedeemed && !isExpired;

  factory CustomerCoupon.fromMap(Map<String, dynamic> map, String id) {
    return CustomerCoupon(
      id: id,
      customerId: map['customerId'] ?? '',
      storeId: map['storeId'] ?? '',
      code: map['code'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      discountType: map['discountType'] ?? 'percentage',
      discountValue: (map['discountValue'] ?? 0).toDouble(),
      minOrderValue: (map['minOrderValue'] ?? 0).toDouble(),
      validUntil: _parseDate(map['validUntil']),
      isRedeemed: map['isRedeemed'] ?? false,
      redeemedAt: map['redeemedAt'] != null ? _parseDate(map['redeemedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'storeId': storeId,
      'code': code,
      'title': title,
      'description': description,
      'discountType': discountType,
      'discountValue': discountValue,
      'minOrderValue': minOrderValue,
      'validUntil': Timestamp.fromDate(validUntil),
      'isRedeemed': isRedeemed,
      'redeemedAt': redeemedAt != null ? Timestamp.fromDate(redeemedAt!) : null,
    };
  }

  Map<String, dynamic> toHiveMap() {
    return {
      'id': id,
      'customerId': customerId,
      'storeId': storeId,
      'code': code,
      'title': title,
      'description': description,
      'discountType': discountType,
      'discountValue': discountValue,
      'minOrderValue': minOrderValue,
      'validUntil': validUntil.toIso8601String(),
      'isRedeemed': isRedeemed,
      'redeemedAt': redeemedAt?.toIso8601String(),
    };
  }
}

/// Represents a Gift Card / Voucher issued to a customer.
class CustomerGift {
  final String id;
  final String customerId;
  final String storeId;
  final String voucherCode;
  final String title;
  final double amount;
  final DateTime validUntil;
  final String status; // 'Active', 'Redeemed', 'Expired'
  final String? notes;

  CustomerGift({
    required this.id,
    required this.customerId,
    required this.storeId,
    required this.voucherCode,
    required this.title,
    required this.amount,
    required this.validUntil,
    this.status = 'Active',
    this.notes,
  });

  bool get isExpired => DateTime.now().isAfter(validUntil);
  bool get isActive => status == 'Active' && !isExpired;

  factory CustomerGift.fromMap(Map<String, dynamic> map, String id) {
    return CustomerGift(
      id: id,
      customerId: map['customerId'] ?? '',
      storeId: map['storeId'] ?? '',
      voucherCode: map['voucherCode'] ?? '',
      title: map['title'] ?? 'Gift Voucher',
      amount: (map['amount'] ?? 0).toDouble(),
      validUntil: _parseDate(map['validUntil']),
      status: map['status'] ?? 'Active',
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'storeId': storeId,
      'voucherCode': voucherCode,
      'title': title,
      'amount': amount,
      'validUntil': Timestamp.fromDate(validUntil),
      'status': status,
      'notes': notes,
    };
  }

  Map<String, dynamic> toHiveMap() {
    return {
      'id': id,
      'customerId': customerId,
      'storeId': storeId,
      'voucherCode': voucherCode,
      'title': title,
      'amount': amount,
      'validUntil': validUntil.toIso8601String(),
      'status': status,
      'notes': notes,
    };
  }
}

/// Represents a Loyalty Coins / Points transaction.
class LoyaltyTransaction {
  final String id;
  final String customerId;
  final String storeId;
  final String type; // 'earned', 'redeemed', 'adjusted'
  final int points;
  final int balanceAfter;
  final DateTime date;
  final String reason;
  final String? referenceId; // Order ID if earned on bill

  LoyaltyTransaction({
    required this.id,
    required this.customerId,
    required this.storeId,
    required this.type,
    required this.points,
    required this.balanceAfter,
    required this.date,
    required this.reason,
    this.referenceId,
  });

  factory LoyaltyTransaction.fromMap(Map<String, dynamic> map, String id) {
    return LoyaltyTransaction(
      id: id,
      customerId: map['customerId'] ?? '',
      storeId: map['storeId'] ?? '',
      type: map['type'] ?? 'earned',
      points: (map['points'] ?? 0).toInt(),
      balanceAfter: (map['balanceAfter'] ?? 0).toInt(),
      date: _parseDate(map['date']),
      reason: map['reason'] ?? 'Loyalty update',
      referenceId: map['referenceId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'storeId': storeId,
      'type': type,
      'points': points,
      'balanceAfter': balanceAfter,
      'date': Timestamp.fromDate(date),
      'reason': reason,
      'referenceId': referenceId,
    };
  }

  Map<String, dynamic> toHiveMap() {
    return {
      'id': id,
      'customerId': customerId,
      'storeId': storeId,
      'type': type,
      'points': points,
      'balanceAfter': balanceAfter,
      'date': date.toIso8601String(),
      'reason': reason,
      'referenceId': referenceId,
    };
  }
}
