class InventoryMovement {
  final String id;
  final String itemId;
  final String storeId;
  final String type; // SALE, PURCHASE, ADJUSTMENT, RETURN, WASTE, TRANSFER_IN, TRANSFER_OUT
  final int delta; // Negative for sales/waste, positive for purchases/returns
  final String? orderId; // Reference to order if movement is from sale
  final String? reason; // Human-readable reason for adjustment
  final String? referenceNumber; // PO number, invoice number, etc.
  final double? cost; // Cost per unit for purchases
  final String deviceId;
  final DateTime createdAt;
  final String syncStatus; // PENDING, SYNCED, FAILED
  final DateTime? syncedAt;

  InventoryMovement({
    required this.id,
    required this.itemId,
    required this.storeId,
    required this.type,
    required this.delta,
    this.orderId,
    this.reason,
    this.referenceNumber,
    this.cost,
    required this.deviceId,
    required this.createdAt,
    this.syncStatus = 'PENDING',
    this.syncedAt,
  });

  factory InventoryMovement.fromMap(Map<String, dynamic> data, String id) {
    return InventoryMovement(
      id: id,
      itemId: data['itemId'] ?? '',
      storeId: data['storeId'] ?? '',
      type: data['type'] ?? 'ADJUSTMENT',
      delta: data['delta'] ?? 0,
      orderId: data['orderId'],
      reason: data['reason'],
      referenceNumber: data['referenceNumber'],
      cost: data['cost']?.toDouble(),
      deviceId: data['deviceId'] ?? '',
      createdAt: data['createdAt'] is DateTime
          ? data['createdAt']
          : DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now(),
      syncStatus: data['syncStatus'] ?? 'PENDING',
      syncedAt: data['syncedAt'] != null
          ? (data['syncedAt'] is DateTime
              ? data['syncedAt']
              : DateTime.tryParse(data['syncedAt']?.toString() ?? ''))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'storeId': storeId,
      'type': type,
      'delta': delta,
      'orderId': orderId,
      'reason': reason,
      'referenceNumber': referenceNumber,
      'cost': cost,
      'deviceId': deviceId,
      'createdAt': createdAt,
      'syncStatus': syncStatus,
      'syncedAt': syncedAt,
    };
  }

  Map<String, dynamic> toSqlMap() {
    return {
      'id': id,
      'itemId': itemId,
      'storeId': storeId,
      'type': type,
      'delta': delta,
      'orderId': orderId,
      'reason': reason,
      'referenceNumber': referenceNumber,
      'cost': cost,
      'deviceId': deviceId,
      'createdAt': createdAt.toIso8601String(),
      'syncStatus': syncStatus,
      'syncedAt': syncedAt?.toIso8601String(),
    };
  }

  InventoryMovement copyWith({
    String? id,
    String? itemId,
    String? storeId,
    String? type,
    int? delta,
    String? orderId,
    String? reason,
    String? referenceNumber,
    double? cost,
    String? deviceId,
    DateTime? createdAt,
    String? syncStatus,
    DateTime? syncedAt,
  }) {
    return InventoryMovement(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      storeId: storeId ?? this.storeId,
      type: type ?? this.type,
      delta: delta ?? this.delta,
      orderId: orderId ?? this.orderId,
      reason: reason ?? this.reason,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      cost: cost ?? this.cost,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}

// Movement type constants
class MovementType {
  static const String sale = 'SALE';
  static const String purchase = 'PURCHASE';
  static const String adjustment = 'ADJUSTMENT';
  static const String returnItem = 'RETURN';
  static const String waste = 'WASTE';
  static const String transferIn = 'TRANSFER_IN';
  static const String transferOut = 'TRANSFER_OUT';
  static const String initialStock = 'INITIAL_STOCK';
}
