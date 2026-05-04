// ignore_for_file: dead_null_aware_expression
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/features/inventory/domain/entities/inventory_item.dart';
import 'package:biztonic_pos/features/crm/domain/entities/customer.dart';
import 'package:biztonic_pos/features/billing/domain/entities/order_entity.dart';

class OrderItem {
  final InventoryItem item;
  final int quantity;
  final String? note;
  final String? orderId; // Added for SQL grouping optimization
  final int? seatIndex; // Added for Seat-wise Billing
  final double? priceSnapshot; // Price at time of order
  final String? category; // Added for historical reporting (v12)
  final double? costSnapshot; // Added for accurate COGS (v17)
  final double? cgst; // Added for line-item tax (v18)
  final double? sgst; // Added for line-item tax (v18)

  OrderItem({
    required this.item, 
    required this.quantity, 
    this.note, 
    this.orderId, 
    this.seatIndex,
    this.priceSnapshot,
    this.category,
    this.costSnapshot,
    this.cgst,
    this.sgst,
  });

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    // Note: This assumes the item data is fully embedded or we reconstruct it.
    // For simplicity in Firestore, we often store a snapshot of the item.
    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is String) return int.tryParse(val) ?? 0;
      if (val is double) return val.toInt();
      return 0;
    }

    return OrderItem(
      item: InventoryItem.fromMap(data, data['id'] ?? ''),
      quantity: parseInt(data['quantity']),
      note: data['note'],
      seatIndex: parseInt(data['seatIndex']),
      category: data['category'],
      costSnapshot: (data['costSnapshot'] ?? data['cost'])?.toDouble(),
      cgst: (data['cgst'] ?? 0.0).toDouble(),
      sgst: (data['sgst'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    var itemMap = item.toMap();
    itemMap['id'] = item.id; // Ensure ID is included in snapshot
    return {
      ...itemMap,
      'quantity': quantity,
      'note': note,
      'seatIndex': seatIndex,
      'category': category ?? item.category,
      'costSnapshot': costSnapshot ?? item.cost,
      'cgst': cgst ?? 0.0,
      'sgst': sgst ?? 0.0,
    };
  }

  // Use Hive-safe serialization for nested items
  Map<String, dynamic> toHiveMap() {
    var itemMap = item.toHiveMap(); // Use Hive map (String timestamps)
    itemMap['id'] = item.id;
    return {
      ...itemMap,
      'quantity': quantity,
      'note': note,
      'seatIndex': seatIndex,
      'category': category ?? item.category,
      'costSnapshot': costSnapshot ?? item.cost,
      'cgst': cgst ?? 0.0,
      'sgst': sgst ?? 0.0,
    };
  }
  // --- SQFlite Adapters ---
  Map<String, dynamic> toSqlMap(String orderId) {
    return {
      'orderId': orderId,
      'itemId': item.id,
      'name': item.name,
      'price': priceSnapshot ?? item.price, // Use snapshot if available
      'quantity': quantity,
      'note': note,
      'seatIndex': seatIndex,
      'category': category ?? item.category,
      'cost': costSnapshot ?? item.cost,
      'cgst': cgst ?? 0.0,
      'sgst': sgst ?? 0.0,
    };
  }

  factory OrderItem.fromSql(Map<String, dynamic> row) {
    // Reconstruct snapshot from history
    final snapshotItem = InventoryItem(
      id: row['itemId'] ?? '',
      name: row['name'] ?? 'Unknown Item',
      category: 'History', // Placeholder
      price: (row['price'] ?? 0).toDouble(),
      quantity: 0,
      status: 'Sold',
      trackStock: false,
    );
    return OrderItem(
      item: snapshotItem,
      quantity: row['quantity'] ?? 0,
      note: row['note'],
      orderId: row['orderId'],
      seatIndex: row['seatIndex'],
      priceSnapshot: (row['price'] ?? 0).toDouble(),
      category: row['category'],
      costSnapshot: (row['cost'] ?? 0).toDouble(),
      cgst: (row['cgst'] ?? 0.0).toDouble(),
      sgst: (row['sgst'] ?? 0.0).toDouble(),
    );
  }

  OrderItem copyWith({
    InventoryItem? item,
    int? quantity,
    String? note,
    String? orderId,
    int? seatIndex,
    double? priceSnapshot,
    String? category,
    double? costSnapshot,
    double? cgst,
    double? sgst,
  }) {
    return OrderItem(
      item: item ?? this.item,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      orderId: orderId ?? this.orderId,
      seatIndex: seatIndex ?? this.seatIndex,
      priceSnapshot: priceSnapshot ?? this.priceSnapshot,
      category: category ?? this.category,
      costSnapshot: costSnapshot ?? this.costSnapshot,
      cgst: cgst ?? this.cgst,
      sgst: sgst ?? this.sgst,
    );
  }
}

class OrderModel {
  final String id;
  final String storeId;
  final List<OrderItem> items;
  final double total;
  final double discount;
  final DateTime date;
  final String status;
  final Customer? customer;
  final String? customerRefId;
  final String? customerName;
  final String? customerPhone;
  final String type;
  final String paymentMethod;
  final String? tableId;
  final String? tableName;
  final List<int>? seatNumbers;
  final bool synced; // New field for local sync tracking
  final DateTime? updatedAt;
  final DateTime? voidedAt;
  final String? voidedBy;
  final String? voidReason;
  final int version;
  final String? deviceId;
  final String? businessDayId;
  final String? syncStatus;
  final double taxRateSnapshot; // Frozen tax rate
  final double discountSnapshot; // Frozen discount at time of order
  final double subtotal; // Added for tax integrity (v18)
  final double cgst; // Added for tax integrity (v18)
  final double sgst; // Added for tax integrity (v18)

  // Immutability Check: Terminal states that prevent further editing
  bool get isImmutable => ['Completed', 'Cancelled', 'Refunded', 'VOID'].contains(status);

  OrderModel({
    required this.id,
    required this.storeId,
    required this.items,
    required this.total,
    this.discount = 0,
    required this.date,
    required this.status,
    this.customer,
    this.customerRefId,
    this.customerName,
    this.customerPhone,
    required this.type,
    required this.paymentMethod,
    this.tableId,
    this.tableName,
    this.seatNumbers,
    this.synced = false,
    this.updatedAt,
    this.voidedAt,
    this.voidedBy,
    this.voidReason,
    this.version = 1,
    this.syncStatus = 'PENDING',
    this.deviceId,
    this.businessDayId,
    this.taxRateSnapshot = 0.0,
    this.discountSnapshot = 0.0,
    this.subtotal = 0.0,
    this.cgst = 0.0,
    this.sgst = 0.0,
  });

  factory OrderModel.fromEntity(OrderEntity entity) {
    return OrderModel(
      id: entity.id,
      storeId: entity.storeId,
      items: entity.items.map((i) => OrderItem(
        item: InventoryItem(
          id: i.itemId,
          name: i.itemName,
          price: i.price,
          category: i.category ?? 'Misc',
          quantity: 0,
          status: 'Active',
          trackStock: false,
        ),
        quantity: i.quantity,
        priceSnapshot: i.price,
        costSnapshot: i.cost,
        cgst: i.cgst,
        sgst: i.sgst,
        category: i.category,
      )).toList(),
      total: entity.total,
      subtotal: entity.subtotal,
      discount: entity.discount,
      cgst: entity.cgst,
      sgst: entity.sgst,
      date: entity.date,
      status: entity.status.value,
      type: entity.type.value,
      paymentMethod: entity.paymentMethod.value,
      tableId: entity.tableId,
      tableName: entity.tableName,
      customerName: entity.customerName,
      customerPhone: entity.customerPhone,
      deviceId: entity.deviceId,
      taxRateSnapshot: entity.taxRateSnapshot,
    );
  }

  factory OrderModel.fromMap(Map<String, dynamic> data, String id) {
    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is String) return int.tryParse(val) ?? 0;
      if (val is double) return val.toInt();
      return 0;
    }

    return OrderModel(
      id: id,
      storeId: data['storeId'] ?? '',
      items: (data['items'] as List<dynamic>?)
          ?.map((item) => OrderItem.fromMap(item))
          .toList() ?? [],
      total: (data['total'] ?? 0).toDouble(),
      discount: (data['discount'] ?? 0).toDouble(),
      date: (data['date'] is Timestamp)
          ? (data['date'] as Timestamp).toDate()
          : (data['date'] is DateTime 
              ? data['date'] as DateTime 
              : DateTime.tryParse(data['date']?.toString() ?? '') ?? DateTime.now()),
      status: data['status'] ?? 'New',
      customer: data['customer'] != null ? Customer.fromMap(data['customer'], data['customer']['id'] ?? '') : null,
      customerRefId: data['customerRefId'] ?? (data['customerRef'] is DocumentReference ? (data['customerRef'] as DocumentReference).id : null),
      customerName: data['customerName'],
      customerPhone: data['customerPhone'],
      type: data['type'] ?? 'Dine-In',
      paymentMethod: data['paymentMethod'] ?? 'Cash',
      tableId: data['tableId'],
      tableName: data['tableName'],
      seatNumbers: (data['seatNumbers'] as List<dynamic>?)?.map((e) => parseInt(e)).toList(),
      updatedAt: (data['updatedAt'] is Timestamp) ? (data['updatedAt'] as Timestamp).toDate() : DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      voidedAt: (data['voidedAt'] is Timestamp) ? (data['voidedAt'] as Timestamp).toDate() : DateTime.tryParse(data['voidedAt']?.toString() ?? ''),
      voidedBy: data['voidedBy'],
      voidReason: data['voidReason'],
      version: parseInt(data['version']) > 0 ? parseInt(data['version']) : 1,
      syncStatus: data['syncStatus'] ?? 'PENDING',
      deviceId: data['deviceId'],
      businessDayId: data['businessDayId'],
      taxRateSnapshot: (data['taxRateSnapshot'] ?? 0.0).toDouble(),
      discountSnapshot: (data['discountSnapshot'] ?? 0.0).toDouble(),
      subtotal: (data['subtotal'] ?? 0.0).toDouble(),
      cgst: (data['cgst'] ?? 0.0).toDouble(),
      sgst: (data['sgst'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'items': items.map((i) => i.toMap()).toList(),
      'total': total,
      'discount': discount,
      'date': date, // Use DateTime (Hive compatible, Firestore compatible)
      'status': status,
      'customer': customer?.toMap(),
      'customerRefId': customerRefId, // Store ID string directly
      // 'customerRef': Remove DocumentReference to allow Hive storage
      'customerName': customerName,
      'customerPhone': customerPhone,
      'type': type,
      'paymentMethod': paymentMethod,
      'tableId': tableId,
      'tableName': tableName,
      'seatNumbers': seatNumbers,
      'synced': synced,
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(), // Use server timestamp on create
      'voidedAt': voidedAt,
      'voidedBy': voidedBy,
      'voidReason': voidReason,
      'deletedAt': null, // Explicitly for count filtering
      'version': version,
      'idempotencyKey': id, // Explicitly use ID as idempotency key
      'serverUpdatedAt': FieldValue.serverTimestamp(), // Authoritative sync clock
      'syncStatus': syncStatus,
      'deviceId': deviceId,
      'businessDayId': businessDayId,
      'taxRateSnapshot': taxRateSnapshot,
      'discountSnapshot': discountSnapshot,
      'subtotal': subtotal,
      'cgst': cgst,
      'sgst': sgst,
    };
  }

  Map<String, dynamic> toMapForLocal() {
     return {
       ...toMap(),
       'updatedAt': updatedAt, // Keep local datetime
     };
  }

  // Hive-compatible Map (No Timestamp objects)
  Map<String, dynamic> toHiveMap() {
    return {
      'id': id, // Ensure ID is saved locally
      'storeId': storeId,
      'items': items.map((i) => i.toHiveMap()).toList(),
      'total': total,
      'discount': discount,
      'date': date.toIso8601String(), // Store as String for Hive
      'status': status,
      'customer': customer?.toHiveMap(),
      // 'customerRef': cannot be saved to Hive easily, skip or store path string if needed
      'customerName': customerName,
      'customerPhone': customerPhone,
      'type': type,
      'paymentMethod': paymentMethod,
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
      'taxRateSnapshot': taxRateSnapshot,
      'discountSnapshot': discountSnapshot,
      'subtotal': subtotal,
      'cgst': cgst,
      'sgst': sgst,
    };
  }
  
  // --- SQFlite Adapters ---
  Map<String, dynamic> toSqlMap() {
    return {
      'id': id,
      'storeId': storeId,
      'total': total,
      'discount': discount,
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
      'taxRateSnapshot': taxRateSnapshot,
      'discountSnapshot': discountSnapshot,
      'subtotal': subtotal,
      'cgst': cgst,
      'sgst': sgst,
    };
  }

  static OrderModel fromSql(Map<String, dynamic> row, List<OrderItem> items) {
    return OrderModel(
      id: row['id'],
      storeId: row['storeId'],
      items: items,
      total: (row['total'] ?? 0).toDouble(),
      discount: (row['discount'] ?? 0).toDouble(),
      date: DateTime.tryParse(row['date'] ?? '') ?? DateTime.now(),
      status: row['status'] ?? 'Unknown',
      type: row['type'] ?? 'Takeaway',
      paymentMethod: row['paymentMethod'] ?? 'Cash',
      customerName: row['customerName'],
      customerPhone: row['customerPhone'],
      tableId: row['tableId'],
      tableName: row['tableName'],
      synced: (row['synced'] ?? 0) == 1,
      updatedAt: DateTime.tryParse(row['updatedAt'] ?? ''),
      voidedAt: DateTime.tryParse(row['voidedAt'] ?? ''),
      voidedBy: row['voidedBy'],
      voidReason: row['voidReason'],
      version: row['version'] ?? 1,
      deviceId: row['deviceId'],
      businessDayId: row['businessDayId'],
      syncStatus: row['syncStatus'],
      taxRateSnapshot: (row['taxRateSnapshot'] ?? 0.0).toDouble(),
      discountSnapshot: (row['discountSnapshot'] ?? 0.0).toDouble(),
      subtotal: (row['subtotal'] ?? 0.0).toDouble(),
      cgst: (row['cgst'] ?? 0.0).toDouble(),
      sgst: (row['sgst'] ?? 0.0).toDouble(),
    );
  }

  OrderModel copyWith({
    String? id,
    String? storeId,
    List<OrderItem>? items,
    double? total,
    double? discount,
    DateTime? date,
    String? status,
    Customer? customer,
    String? customerRefId,
    String? customerName,
    String? customerPhone,
    String? type,
    String? tableId,
    String? tableName,
    List<int>? seatNumbers,
    bool? synced,
    DateTime? updatedAt,
    DateTime? voidedAt,
    String? voidedBy,
    String? voidReason,
    int? version,
    String? syncStatus,
    String? deviceId,
    String? businessDayId,
    double? taxRateSnapshot,
    double? discountSnapshot,
  }) {
    return OrderModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      items: items ?? this.items,
      total: total ?? this.total,
      discount: discount ?? this.discount,
      date: date ?? this.date,
      status: status ?? this.status,
      customer: customer ?? this.customer,
      customerRefId: customerRefId ?? this.customerRefId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      type: type ?? this.type,
      paymentMethod: paymentMethod,
      tableId: tableId ?? this.tableId,
      tableName: tableName ?? this.tableName,
      seatNumbers: seatNumbers ?? this.seatNumbers,
      synced: synced ?? this.synced,
      updatedAt: updatedAt ?? this.updatedAt,
      voidedAt: voidedAt ?? this.voidedAt,
      voidedBy: voidedBy ?? this.voidedBy,
      voidReason: voidReason ?? this.voidReason,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
      deviceId: deviceId ?? this.deviceId,
      businessDayId: businessDayId ?? this.businessDayId,
      taxRateSnapshot: taxRateSnapshot ?? this.taxRateSnapshot,
      discountSnapshot: discountSnapshot ?? this.discountSnapshot,
      subtotal: subtotal,
      cgst: cgst,
      sgst: sgst,
    );
  }
}
