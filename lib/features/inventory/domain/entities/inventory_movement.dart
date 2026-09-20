class InventoryMovement {
  final String id;
  final String itemId;
  final String storeId;
  final String type;
  final int delta;
  final String? orderId;
  final String? reason;
  final String? referenceNumber;
  final double? unitCost;
  final String deviceId;
  final String operationId;
  final DateTime createdAt;
  final int version;
  final String syncStatus; // PENDING, SYNCED, CONFIRMED, FAILED
  final DateTime? syncedAt;
  final bool isDeleted;

  /// Compatibility alias for movementId
  String get movementId => id;

  /// Compatibility alias for unitCost
  double? get cost => unitCost;

  InventoryMovement({
    required this.id,
    required this.itemId,
    required this.storeId,
    required this.type,
    required this.delta,
    this.orderId,
    this.reason,
    this.referenceNumber,
    double? unitCost,
    double? cost,
    required this.deviceId,
    String? operationId,
    required this.createdAt,
    this.version = 1,
    this.syncStatus = 'PENDING',
    this.syncedAt,
    this.isDeleted = false,
  })  : unitCost = unitCost ?? cost,
        operationId = operationId ?? id;

  factory InventoryMovement.fromMap(Map<String, dynamic> data, String id) {
    final parsedCost = data['unitCost'] != null
        ? (data['unitCost'] as num).toDouble()
        : (data['cost'] != null ? (data['cost'] as num).toDouble() : null);

    return InventoryMovement(
      id: id,
      itemId: data['itemId']?.toString() ?? '',
      storeId: data['storeId']?.toString() ?? '',
      type: data['type']?.toString() ?? MovementType.adjustment,
      delta: (data['delta'] as num?)?.toInt() ?? 0,
      orderId: data['orderId']?.toString(),
      reason: data['reason']?.toString(),
      referenceNumber: data['referenceNumber']?.toString(),
      unitCost: parsedCost,
      deviceId: data['deviceId']?.toString() ?? '',
      operationId: data['operationId']?.toString() ??
          data['movementId']?.toString() ??
          id,
      createdAt: data['createdAt'] is DateTime
          ? data['createdAt']
          : DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
              DateTime.now(),
      version: (data['version'] as num?)?.toInt() ?? 1,
      syncStatus: data['syncStatus']?.toString() ?? 'PENDING',
      syncedAt: data['syncedAt'] != null
          ? (data['syncedAt'] is DateTime
              ? data['syncedAt']
              : DateTime.tryParse(data['syncedAt']?.toString() ?? ''))
          : null,
      isDeleted: data['isDeleted'] == true || data['isDeleted'] == 1,
    );
  }

  factory InventoryMovement.fromSql(Map<String, dynamic> data) {
    return InventoryMovement.fromMap(data, data['id']?.toString() ?? '');
  }

  Map<String, dynamic> toMap() {
    return {
      'movementId': id,
      'id': id,
      'itemId': itemId,
      'storeId': storeId,
      'type': type,
      'delta': delta,
      'orderId': orderId,
      'reason': reason,
      'referenceNumber': referenceNumber,
      'unitCost': unitCost,
      'cost': unitCost,
      'deviceId': deviceId,
      'operationId': operationId,
      'createdAt': createdAt.toIso8601String(),
      'version': version,
      'syncStatus': syncStatus,
      'syncedAt': syncedAt?.toIso8601String(),
      'isDeleted': isDeleted,
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
      'cost': unitCost,
      'unitCost': unitCost,
      'deviceId': deviceId,
      'operationId': operationId,
      'createdAt': createdAt.toIso8601String(),
      'version': version,
      'syncStatus': syncStatus,
      'syncedAt': syncedAt?.toIso8601String(),
      'isDeleted': isDeleted ? 1 : 0,
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
    double? unitCost,
    String? deviceId,
    String? operationId,
    DateTime? createdAt,
    int? version,
    String? syncStatus,
    DateTime? syncedAt,
    bool? isDeleted,
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
      unitCost: unitCost ?? this.unitCost,
      deviceId: deviceId ?? this.deviceId,
      operationId: operationId ?? this.operationId,
      createdAt: createdAt ?? this.createdAt,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
      syncedAt: syncedAt ?? this.syncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

/// Movement type constants aligned with actual business operations
class MovementType {
  static const String initialStock = 'INITIAL_STOCK';
  static const String purchase = 'PURCHASE';
  static const String sale = 'SALE';
  static const String saleReversal = 'SALE_REVERSAL';
  static const String refund = 'REFUND';
  static const String adjustment = 'ADJUSTMENT';
  static const String transfer = 'TRANSFER';
  static const String transferIn = 'TRANSFER_IN';
  static const String transferOut = 'TRANSFER_OUT';
  static const String damage = 'DAMAGE';
  static const String returnItem = 'RETURN';
  static const String voidReversal = 'VOID_REVERSAL';
  static const String voidItem = 'VOID_ITEM';
  static const String voidOrder = 'VOID';
  static const String voidMovement = 'VOID';
  static const String stockCount = 'STOCK_COUNT';

  /// Legacy alias
  static const String waste = damage;
}
