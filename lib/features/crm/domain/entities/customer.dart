import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String storeId;
  final String name;
  final String email;
  final String? mobile;
  final String? phone;
  final String? whatsapp;
  final String? taxNumber;
  final String? billingAddress;
  final String? shippingAddress;
  final String? avatar;
  final DateTime joinDate;
  final double totalSpent;
  final int loyaltyPoints;
  final String tier;
  final int visitCount;
  final DateTime? lastVisit;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String syncStatus;
  final String? deviceId;
  final int version; // Optimistic locking version
  final double udhariBalance; // Outstanding amount owed by customer (Udhari / Borrowed)
  final double creditLimit; // Maximum credit/udhari allowed for customer

  Customer({
    required this.id,
    required this.storeId,
    required this.name,
    required this.email,
    this.mobile,
    this.phone,
    this.whatsapp,
    this.taxNumber,
    this.billingAddress,
    this.shippingAddress,
    this.avatar,
    required this.joinDate,
    required this.totalSpent,
    required this.loyaltyPoints,
    required this.tier,
    this.visitCount = 0,
    this.lastVisit,
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = 'PENDING',
    this.deviceId,
    this.version = 1,
    this.udhariBalance = 0.0,
    this.creditLimit = 0.0,
  });

  factory Customer.fromMap(Map<String, dynamic> data, String id) {
    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is String) return int.tryParse(val) ?? 0;
      if (val is double) return val.toInt();
      return 0;
    }

    return Customer(
      id: id,
      storeId: data['storeId'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      mobile: data['mobile'],
      phone: data['phone'],
      whatsapp: data['whatsapp'],
      taxNumber: data['taxNumber'],
      billingAddress: data['billingAddress'],
      shippingAddress: data['shippingAddress'],
      avatar: data['avatar'],
      joinDate: data['joinDate'] != null
          ? (data['joinDate'] is Timestamp
              ? (data['joinDate'] as Timestamp).toDate()
              : DateTime.tryParse(data['joinDate']?.toString() ?? '') ??
                  DateTime.now())
          : DateTime.now(),
      totalSpent: (data['totalSpent'] ?? 0).toDouble(),
      loyaltyPoints: parseInt(data['loyaltyPoints']),
      tier: data['tier'] ?? 'New',
      visitCount: parseInt(data['visitCount']),
      lastVisit: data['lastVisit'] != null
          ? (data['lastVisit'] is Timestamp
              ? (data['lastVisit'] as Timestamp).toDate()
              : DateTime.tryParse(data['lastVisit']?.toString() ?? ''))
          : null,
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      deletedAt: (data['deletedAt'] is Timestamp)
          ? (data['deletedAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['deletedAt']?.toString() ?? ''),
      syncStatus: data['syncStatus'] ?? 'PENDING',
      deviceId: data['deviceId'],
      version: parseInt(data['version']) > 0 ? parseInt(data['version']) : 1,
      udhariBalance: (data['udhariBalance'] ?? data['creditBalance'] ?? 0).toDouble(),
      creditLimit: (data['creditLimit'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'name': name,
      'email': email,
      'mobile': mobile,
      'phone': phone,
      'whatsapp': whatsapp,
      'taxNumber': taxNumber,
      'billingAddress': billingAddress,
      'shippingAddress': shippingAddress,
      'avatar': avatar,
      'joinDate': Timestamp.fromDate(joinDate),
      'totalSpent': totalSpent,
      'loyaltyPoints': loyaltyPoints,
      'tier': tier,
      'visitCount': visitCount,
      'lastVisit': lastVisit != null ? Timestamp.fromDate(lastVisit!) : null,
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
      'deletedAt': deletedAt,
      'syncStatus': syncStatus,
      'deviceId': deviceId,
      'version': version,
      'udhariBalance': udhariBalance,
      'creditLimit': creditLimit,
    };
  }

  Map<String, dynamic> toMapForLocal() {
    return {
      ...toMap(),
      'updatedAt': updatedAt,
    };
  }

  // Hive-compatible Map (No Timestamp objects)
  Map<String, dynamic> toHiveMap() {
    return {
      'id': id,
      'storeId': storeId,
      'name': name,
      'email': email,
      'mobile': mobile,
      'phone': phone,
      'whatsapp': whatsapp,
      'taxNumber': taxNumber,
      'billingAddress': billingAddress,
      'shippingAddress': shippingAddress,
      'avatar': avatar,
      'joinDate': joinDate.toIso8601String(),
      'totalSpent': totalSpent,
      'loyaltyPoints': loyaltyPoints,
      'tier': tier,
      'visitCount': visitCount,
      'lastVisit': lastVisit?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'syncStatus': syncStatus,
      'deviceId': deviceId,
      'version': version,
      'udhariBalance': udhariBalance,
      'creditLimit': creditLimit,
    };
  }

  // --- SQFlite Adapters ---
  Map<String, dynamic> toSqlMap() {
    return {
      'id': id,
      'storeId': storeId,
      'name': name,
      'email': email,
      'mobile': mobile,
      'phone': phone,
      'whatsapp': whatsapp,
      'taxNumber': taxNumber,
      'billingAddress': billingAddress,
      'shippingAddress': shippingAddress,
      'avatar': avatar,
      'joinDate': joinDate.toIso8601String(),
      'totalSpent': totalSpent,
      'loyaltyPoints': loyaltyPoints,
      'tier': tier,
      'visitCount': visitCount,
      'lastVisit': lastVisit?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'syncStatus': syncStatus,
      'deviceId': deviceId,
      'version': version,
      'udhariBalance': udhariBalance,
      'creditLimit': creditLimit,
    };
  }

  factory Customer.fromSql(Map<String, dynamic> row) {
    return Customer(
      id: row['id'] as String,
      storeId: (row['storeId'] ?? '') as String,
      name: (row['name'] ?? '') as String,
      email: (row['email'] ?? '') as String,
      mobile: row['mobile'] as String?,
      phone: row['phone'] as String?,
      whatsapp: row['whatsapp'] as String?,
      taxNumber: row['taxNumber'],
      billingAddress: row['billingAddress'],
      shippingAddress: row['shippingAddress'],
      avatar: row['avatar'],
      joinDate: DateTime.tryParse(row['joinDate'] ?? '') ?? DateTime.now(),
      totalSpent: (row['totalSpent'] ?? 0).toDouble(),
      loyaltyPoints: (row['loyaltyPoints'] ?? 0).toInt(),
      tier: row['tier'] ?? 'New',
      visitCount: (row['visitCount'] ?? 0).toInt(),
      lastVisit:
          row['lastVisit'] != null ? DateTime.tryParse(row['lastVisit']) : null,
      updatedAt: DateTime.tryParse(row['updatedAt'] ?? ''),
      deletedAt: DateTime.tryParse(row['deletedAt'] ?? ''),
      syncStatus: row['syncStatus'] ?? 'PENDING',
      deviceId: row['deviceId'],
      version: row['version'] ?? 1,
      udhariBalance: (row['udhariBalance'] ?? 0).toDouble(),
      creditLimit: (row['creditLimit'] ?? 0).toDouble(),
    );
  }
  Customer copyWith({
    String? id,
    String? storeId,
    String? name,
    String? email,
    String? mobile,
    String? phone,
    String? whatsapp,
    String? taxNumber,
    String? billingAddress,
    String? shippingAddress,
    String? avatar,
    DateTime? joinDate,
    double? totalSpent,
    int? loyaltyPoints,
    String? tier,
    int? visitCount,
    DateTime? lastVisit,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? syncStatus,
    String? deviceId,
    int? version,
    double? udhariBalance,
    double? creditLimit,
  }) {
    return Customer(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      taxNumber: taxNumber ?? this.taxNumber,
      billingAddress: billingAddress ?? this.billingAddress,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      avatar: avatar ?? this.avatar,
      joinDate: joinDate ?? this.joinDate,
      totalSpent: totalSpent ?? this.totalSpent,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      tier: tier ?? this.tier,
      visitCount: visitCount ?? this.visitCount,
      lastVisit: lastVisit ?? this.lastVisit,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
      udhariBalance: udhariBalance ?? this.udhariBalance,
      creditLimit: creditLimit ?? this.creditLimit,
    );
  }
}
