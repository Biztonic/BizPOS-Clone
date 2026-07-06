/// Pure domain entity for an Order.
///
/// CRITICAL RULE: This file MUST NOT import:
///   - cloud_firestore
///   - hive
///   - sqflite
///   - flutter (except foundation for @immutable)
///
/// All serialization logic belongs in [OrderDto].
library;

class OrderItemEntity {
  final String itemId;
  final String itemName;
  final double price;
  final double cost;
  final int quantity;
  final String? note;
  final String? category;
  final int? seatIndex;
  final double cgst;
  final double sgst;

  const OrderItemEntity({
    required this.itemId,
    required this.itemName,
    required this.price,
    required this.cost,
    required this.quantity,
    this.note,
    this.category,
    this.seatIndex,
    this.cgst = 0.0,
    this.sgst = 0.0,
  });

  double get lineTotal => price * quantity;
  double get lineCost => cost * quantity;
  double get lineTax => (cgst + sgst) * quantity;

  OrderItemEntity copyWith({
    String? itemId,
    String? itemName,
    double? price,
    double? cost,
    int? quantity,
    String? note,
    String? category,
    int? seatIndex,
    double? cgst,
    double? sgst,
  }) {
    return OrderItemEntity(
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      category: category ?? this.category,
      seatIndex: seatIndex ?? this.seatIndex,
      cgst: cgst ?? this.cgst,
      sgst: sgst ?? this.sgst,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderItemEntity &&
          itemId == other.itemId &&
          quantity == other.quantity;

  @override
  int get hashCode => itemId.hashCode ^ quantity.hashCode;
}

/// Terminal order states that prevent further modification.
enum OrderStatus {
  newOrder('New'),
  preparing('Preparing'),
  ready('Ready'),
  completed('Completed'),
  cancelled('Cancelled'),
  refunded('Refunded'),
  voided('VOID');

  final String value;
  const OrderStatus(this.value);

  /// Whether this order can still be modified.
  bool get isTerminal => [completed, cancelled, refunded, voided].contains(this);

  static OrderStatus fromString(String status) {
    return OrderStatus.values.firstWhere(
      (e) => e.value == status,
      orElse: () => OrderStatus.newOrder,
    );
  }
}

enum PaymentMethod {
  cash('Cash'),
  card('Card'),
  upi('UPI'),
  split('Split');

  final String value;
  const PaymentMethod(this.value);

  static PaymentMethod fromString(String method) {
    return PaymentMethod.values.firstWhere(
      (e) => e.value == method,
      orElse: () => PaymentMethod.cash,
    );
  }
}

enum OrderType {
  dineIn('Dine-In'),
  takeaway('Takeaway'),
  delivery('Delivery'),
  online('Online');

  final String value;
  const OrderType(this.value);

  static OrderType fromString(String type) {
    return OrderType.values.firstWhere(
      (e) => e.value == type,
      orElse: () => OrderType.dineIn,
    );
  }
}

class OrderEntity {
  final String id;
  final String storeId;
  final List<OrderItemEntity> items;
  final double total;
  final double subtotal;
  final double discount;
  final double cgst;
  final double sgst;
  final double taxRateSnapshot;
  final double discountSnapshot;
  final DateTime date;
  final OrderStatus status;
  final OrderType type;
  final PaymentMethod paymentMethod;

  // Customer info (denormalized for offline access)
  final String? customerId;
  final String? customerName;
  final String? customerPhone;

  // Table info
  final String? tableId;
  final String? tableName;
  final List<int>? seatNumbers;

  // Sync metadata
  final bool synced;
  final String? syncStatus;
  final String? deviceId;
  final String? businessDayId;
  final int version;

  // Void metadata
  final DateTime? updatedAt;
  final DateTime? voidedAt;
  final String? voidedBy;
  final String? voidReason;

  /// Clean, collision-free short display ID (e.g. C6A38F90)
  String get shortId {
    final clean = id.startsWith('ORD_') ? id.substring(4) : id;
    if (clean.length <= 8) return clean.toUpperCase();
    return clean.substring(0, 8).toUpperCase();
  }

  const OrderEntity({
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
    this.status = OrderStatus.newOrder,
    this.type = OrderType.dineIn,
    this.paymentMethod = PaymentMethod.cash,
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

  /// Whether this order can be edited.
  bool get isImmutable => status.isTerminal;

  /// Computed item count.
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  /// Computed total COGS.
  double get totalCogs => items.fold(0.0, (sum, item) => sum + item.lineCost);

  /// Computed gross profit.
  double get grossProfit => total - totalCogs;

  OrderEntity copyWith({
    String? id,
    String? storeId,
    List<OrderItemEntity>? items,
    double? total,
    double? subtotal,
    double? discount,
    double? cgst,
    double? sgst,
    double? taxRateSnapshot,
    double? discountSnapshot,
    DateTime? date,
    OrderStatus? status,
    OrderType? type,
    PaymentMethod? paymentMethod,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? tableId,
    String? tableName,
    List<int>? seatNumbers,
    bool? synced,
    String? syncStatus,
    String? deviceId,
    String? businessDayId,
    int? version,
    DateTime? updatedAt,
    DateTime? voidedAt,
    String? voidedBy,
    String? voidReason,
  }) {
    return OrderEntity(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      items: items ?? this.items,
      total: total ?? this.total,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      cgst: cgst ?? this.cgst,
      sgst: sgst ?? this.sgst,
      taxRateSnapshot: taxRateSnapshot ?? this.taxRateSnapshot,
      discountSnapshot: discountSnapshot ?? this.discountSnapshot,
      date: date ?? this.date,
      status: status ?? this.status,
      type: type ?? this.type,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      tableId: tableId ?? this.tableId,
      tableName: tableName ?? this.tableName,
      seatNumbers: seatNumbers ?? this.seatNumbers,
      synced: synced ?? this.synced,
      syncStatus: syncStatus ?? this.syncStatus,
      deviceId: deviceId ?? this.deviceId,
      businessDayId: businessDayId ?? this.businessDayId,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      voidedAt: voidedAt ?? this.voidedAt,
      voidedBy: voidedBy ?? this.voidedBy,
      voidReason: voidReason ?? this.voidReason,
    );
  }
}
