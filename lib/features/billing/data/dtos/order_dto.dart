/// Data Transfer Object for Order serialization.
///
/// This class handles ALL infrastructure-specific serialization:
///   - Firestore (toFirestoreMap / fromFirestoreMap)
///   - Hive (toHiveMap / fromHiveMap)
///   - SQLite (toSqlMap / fromSqlMap)
///
/// The domain OrderEntity stays pure.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItemDto {
  final String itemId;
  final String name;
  final double price;
  final double cost;
  final int quantity;
  final String? note;
  final String? category;
  final int? seatIndex;
  final double cgst;
  final double sgst;

  const OrderItemDto({
    required this.itemId,
    required this.name,
    required this.price,
    required this.cost,
    required this.quantity,
    this.note,
    this.category,
    this.seatIndex,
    this.cgst = 0.0,
    this.sgst = 0.0,
  });

  // ─── Firestore ───────────────────────────────────────────

  factory OrderItemDto.fromFirestore(Map<String, dynamic> data) {
    return OrderItemDto(
      itemId: data['id'] ?? '',
      name: data['name'] ?? 'Unknown',
      price: (data['price'] ?? 0).toDouble(),
      cost: (data['costSnapshot'] ?? data['cost'] ?? 0).toDouble(),
      quantity: _parseInt(data['quantity']),
      note: data['note'],
      category: data['category'],
      seatIndex: data['seatIndex'] != null ? _parseInt(data['seatIndex']) : null,
      cgst: (data['cgst'] ?? 0.0).toDouble(),
      sgst: (data['sgst'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestoreMap() => {
    'id': itemId,
    'name': name,
    'price': price,
    'costSnapshot': cost,
    'quantity': quantity,
    'note': note,
    'category': category,
    'seatIndex': seatIndex,
    'cgst': cgst,
    'sgst': sgst,
  };

  // ─── Hive ────────────────────────────────────────────────

  factory OrderItemDto.fromHive(Map<String, dynamic> data) {
    return OrderItemDto.fromFirestore(data); // Same structure, different timestamps
  }

  Map<String, dynamic> toHiveMap() => toFirestoreMap(); // No Timestamps in Hive

  // ─── SQLite ──────────────────────────────────────────────

  factory OrderItemDto.fromSql(Map<String, dynamic> row) {
    return OrderItemDto(
      itemId: row['itemId'] ?? '',
      name: row['name'] ?? 'Unknown',
      price: (row['price'] ?? 0).toDouble(),
      cost: (row['cost'] ?? 0).toDouble(),
      quantity: _parseInt(row['quantity']),
      note: row['note'],
      category: row['category'],
      seatIndex: row['seatIndex'] != null ? _parseInt(row['seatIndex']) : null,
      cgst: (row['cgst'] ?? 0.0).toDouble(),
      sgst: (row['sgst'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toSqlMap(String orderId) => {
    'orderId': orderId,
    'itemId': itemId,
    'name': name,
    'price': price,
    'quantity': quantity,
    'note': note,
    'seatIndex': seatIndex,
    'category': category,
    'cost': cost,
    'cgst': cgst,
    'sgst': sgst,
  };

  static int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is String) return int.tryParse(val) ?? 0;
    if (val is double) return val.toInt();
    return 0;
  }
}

class OrderDto {
  final String id;
  final String storeId;
  final List<OrderItemDto> items;
  final double total;
  final double subtotal;
  final double discount;
  final double cgst;
  final double sgst;
  final double taxRateSnapshot;
  final double discountSnapshot;
  final DateTime date;
  final String status;
  final String type;
  final String paymentMethod;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? tableId;
  final String? tableName;
  final List<int>? seatNumbers;
  final bool synced;
  final String? syncStatus;
  final String? deviceId;
  final String? businessDayId;
  final int version;
  final DateTime? updatedAt;
  final DateTime? voidedAt;
  final String? voidedBy;
  final String? voidReason;

  const OrderDto({
    required this.id,
    required this.storeId,
    required this.items,
    required this.total,
    this.subtotal = 0.0,
    this.discount = 0.0,
    this.cgst = 0.0,
    this.sgst = 0.0,
    this.taxRateSnapshot = 0.0,
    this.discountSnapshot = 0.0,
    required this.date,
    this.status = 'New',
    this.type = 'Dine-In',
    this.paymentMethod = 'Cash',
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.tableId,
    this.tableName,
    this.seatNumbers,
    this.synced = false,
    this.syncStatus = 'PENDING',
    this.deviceId,
    this.businessDayId,
    this.version = 1,
    this.updatedAt,
    this.voidedAt,
    this.voidedBy,
    this.voidReason,
  });

  // ─── Firestore ───────────────────────────────────────────

  factory OrderDto.fromFirestore(Map<String, dynamic> data, String id) {
    return OrderDto(
      id: id,
      storeId: data['storeId'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => OrderItemDto.fromFirestore(item as Map<String, dynamic>))
              .toList() ??
          [],
      total: (data['total'] ?? 0).toDouble(),
      subtotal: (data['subtotal'] ?? 0.0).toDouble(),
      discount: (data['discount'] ?? 0).toDouble(),
      cgst: (data['cgst'] ?? 0.0).toDouble(),
      sgst: (data['sgst'] ?? 0.0).toDouble(),
      taxRateSnapshot: (data['taxRateSnapshot'] ?? 0.0).toDouble(),
      discountSnapshot: (data['discountSnapshot'] ?? 0.0).toDouble(),
      date: _parseDate(data['date']),
      status: data['status'] ?? 'New',
      type: data['type'] ?? 'Dine-In',
      paymentMethod: data['paymentMethod'] ?? 'Cash',
      customerId: data['customerRefId'] ??
          (data['customerRef'] is DocumentReference
              ? (data['customerRef'] as DocumentReference).id
              : null),
      customerName: data['customerName'],
      customerPhone: data['customerPhone'],
      tableId: data['tableId'],
      tableName: data['tableName'],
      seatNumbers: (data['seatNumbers'] as List<dynamic>?)
          ?.map((e) => OrderItemDto._parseInt(e))
          .toList(),
      syncStatus: data['syncStatus'] ?? 'PENDING',
      deviceId: data['deviceId'],
      businessDayId: data['businessDayId'],
      version: OrderItemDto._parseInt(data['version']) > 0
          ? OrderItemDto._parseInt(data['version'])
          : 1,
      updatedAt: _parseDateNullable(data['updatedAt']),
      voidedAt: _parseDateNullable(data['voidedAt']),
      voidedBy: data['voidedBy'],
      voidReason: data['voidReason'],
    );
  }

  Map<String, dynamic> toFirestoreMap() => {
    'storeId': storeId,
    'items': items.map((i) => i.toFirestoreMap()).toList(),
    'total': total,
    'subtotal': subtotal,
    'discount': discount,
    'cgst': cgst,
    'sgst': sgst,
    'taxRateSnapshot': taxRateSnapshot,
    'discountSnapshot': discountSnapshot,
    'date': date,
    'status': status,
    'customerRefId': customerId,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'type': type,
    'paymentMethod': paymentMethod,
    'tableId': tableId,
    'tableName': tableName,
    'seatNumbers': seatNumbers,
    'synced': synced,
    'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    'voidedAt': voidedAt,
    'voidedBy': voidedBy,
    'voidReason': voidReason,
    'deletedAt': null,
    'version': version,
    'idempotencyKey': id,
    'serverUpdatedAt': FieldValue.serverTimestamp(),
    'syncStatus': syncStatus,
    'deviceId': deviceId,
    'businessDayId': businessDayId,
  };

  // ─── Hive ────────────────────────────────────────────────

  factory OrderDto.fromHive(Map<String, dynamic> data) {
    return OrderDto(
      id: data['id'] ?? '',
      storeId: data['storeId'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => OrderItemDto.fromHive(item as Map<String, dynamic>))
              .toList() ??
          [],
      total: (data['total'] ?? 0).toDouble(),
      subtotal: (data['subtotal'] ?? 0.0).toDouble(),
      discount: (data['discount'] ?? 0).toDouble(),
      cgst: (data['cgst'] ?? 0.0).toDouble(),
      sgst: (data['sgst'] ?? 0.0).toDouble(),
      taxRateSnapshot: (data['taxRateSnapshot'] ?? 0.0).toDouble(),
      discountSnapshot: (data['discountSnapshot'] ?? 0.0).toDouble(),
      date: DateTime.tryParse(data['date']?.toString() ?? '') ?? DateTime.now(),
      status: data['status'] ?? 'New',
      type: data['type'] ?? 'Dine-In',
      paymentMethod: data['paymentMethod'] ?? 'Cash',
      customerName: data['customerName'],
      customerPhone: data['customerPhone'],
      tableId: data['tableId'],
      tableName: data['tableName'],
      syncStatus: data['syncStatus'] ?? 'PENDING',
      deviceId: data['deviceId'],
      businessDayId: data['businessDayId'],
      version: OrderItemDto._parseInt(data['version']) > 0
          ? OrderItemDto._parseInt(data['version'])
          : 1,
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      voidedAt: DateTime.tryParse(data['voidedAt']?.toString() ?? ''),
      voidedBy: data['voidedBy'],
      voidReason: data['voidReason'],
    );
  }

  Map<String, dynamic> toHiveMap() => {
    'id': id,
    'storeId': storeId,
    'items': items.map((i) => i.toHiveMap()).toList(),
    'total': total,
    'subtotal': subtotal,
    'discount': discount,
    'cgst': cgst,
    'sgst': sgst,
    'taxRateSnapshot': taxRateSnapshot,
    'discountSnapshot': discountSnapshot,
    'date': date.toIso8601String(),
    'status': status,
    'type': type,
    'paymentMethod': paymentMethod,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'tableId': tableId,
    'tableName': tableName,
    'seatNumbers': seatNumbers,
    'updatedAt': updatedAt?.toIso8601String(),
    'voidedAt': voidedAt?.toIso8601String(),
    'voidedBy': voidedBy,
    'voidReason': voidReason,
    'syncStatus': syncStatus,
    'deviceId': deviceId,
    'version': version,
    'businessDayId': businessDayId,
  };

  // ─── SQLite ──────────────────────────────────────────────

  factory OrderDto.fromSql(Map<String, dynamic> row, List<OrderItemDto> items) {
    return OrderDto(
      id: row['id'] ?? '',
      storeId: row['storeId'] ?? '',
      items: items,
      total: (row['total'] ?? 0).toDouble(),
      subtotal: (row['subtotal'] ?? 0.0).toDouble(),
      discount: (row['discount'] ?? 0).toDouble(),
      cgst: (row['cgst'] ?? 0.0).toDouble(),
      sgst: (row['sgst'] ?? 0.0).toDouble(),
      taxRateSnapshot: (row['taxRateSnapshot'] ?? 0.0).toDouble(),
      discountSnapshot: (row['discountSnapshot'] ?? 0.0).toDouble(),
      date: DateTime.tryParse(row['date'] ?? '') ?? DateTime.now(),
      status: row['status'] ?? 'Unknown',
      type: row['type'] ?? 'Takeaway',
      paymentMethod: row['paymentMethod'] ?? 'Cash',
      customerName: row['customerName'],
      customerPhone: row['customerPhone'],
      tableId: row['tableId'],
      tableName: row['tableName'],
      synced: (row['synced'] ?? 0) == 1,
      syncStatus: row['syncStatus'],
      deviceId: row['deviceId'],
      businessDayId: row['businessDayId'],
      version: row['version'] ?? 1,
      updatedAt: DateTime.tryParse(row['updatedAt'] ?? ''),
      voidedAt: DateTime.tryParse(row['voidedAt'] ?? ''),
      voidedBy: row['voidedBy'],
      voidReason: row['voidReason'],
    );
  }

  Map<String, dynamic> toSqlMap() => {
    'id': id,
    'storeId': storeId,
    'total': total,
    'subtotal': subtotal,
    'discount': discount,
    'cgst': cgst,
    'sgst': sgst,
    'taxRateSnapshot': taxRateSnapshot,
    'discountSnapshot': discountSnapshot,
    'date': date.toIso8601String(),
    'status': status,
    'type': type,
    'paymentMethod': paymentMethod,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'tableId': tableId,
    'tableName': tableName,
    'synced': synced ? 1 : 0,
    'updatedAt': updatedAt?.toIso8601String(),
    'voidedAt': voidedAt?.toIso8601String(),
    'voidedBy': voidedBy,
    'voidReason': voidReason,
    'version': version,
    'syncStatus': syncStatus,
    'deviceId': deviceId,
    'businessDayId': businessDayId,
    'lastSyncedAt': DateTime.now().toIso8601String(),
  };

  // ─── Helpers ─────────────────────────────────────────────

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  static DateTime? _parseDateNullable(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
