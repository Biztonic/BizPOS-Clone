class BusinessEvent {
  final String id;
  final String storeId;
  final String entityType; // ORDER, INVENTORY, PAYMENT
  final String entityId;
  final String eventType; // CREATE, UPDATE, CANCEL, REFUND, ADJUSTMENT
  final double amount;
  final int quantity;
  final DateTime createdAt;
  final String deviceId;
  final bool synced;
  final DateTime? syncedAt;

  BusinessEvent({
    required this.id,
    required this.storeId,
    required this.entityType,
    required this.entityId,
    required this.eventType,
    this.amount = 0.0,
    this.quantity = 0,
    required this.createdAt,
    required this.deviceId,
    this.synced = false,
    this.syncedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'entityType': entityType,
      'entityId': entityId,
      'eventType': eventType,
      'amount': amount,
      'quantity': quantity,
      'createdAt': createdAt.toIso8601String(),
      'deviceId': deviceId,
      'synced': synced ? 1 : 0,
      'syncedAt': syncedAt?.toIso8601String(),
    };
  }

  factory BusinessEvent.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      // Handle Firestore Timestamp if encountered
      try {
        if (val.runtimeType.toString().contains('Timestamp')) {
          return val.toDate();
        }
      } catch (_) {}
      return DateTime.now();
    }

    return BusinessEvent(
      id: map['id'] ?? '',
      storeId: map['storeId'] ?? '',
      entityType: map['entityType'] ?? '',
      entityId: map['entityId'] ?? '',
      eventType: map['eventType'] ?? '',
      amount: (map['amount'] as num? ?? 0.0).toDouble(),
      quantity: (map['quantity'] as num? ?? 0).toInt(),
      createdAt: parseDate(map['createdAt']),
      deviceId: map['deviceId'] ?? '',
      synced: map['synced'] == 1 || map['synced'] == true,
      syncedAt: map['syncedAt'] != null ? parseDate(map['syncedAt']) : null,
    );
  }
}
