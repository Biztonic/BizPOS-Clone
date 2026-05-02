class SubscriptionRequest {
  final String id;
  final String storeId;
  final String storeName;
  final String ownerEmail;
  final String planType;
  final String billingCycle;
  final double amount;
  final String status;
  final DateTime createdAt;
  final String userId; // NEW: Added for Firestore Security Rules
  final List<String> selectedAddons; // NEW
  final int durationInDays; // NEW

  SubscriptionRequest({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.ownerEmail,
    required this.planType,
    required this.billingCycle,
    required this.amount,
    required this.userId, // NEW
    this.status = 'PENDING',
    required this.createdAt,
    this.selectedAddons = const [], // NEW
    this.durationInDays = 30, // NEW
  });

  factory SubscriptionRequest.fromMap(Map<String, dynamic> data, String id) {
    return SubscriptionRequest(
      id: id,
      storeId: data['storeId'] ?? '',
      storeName: data['storeName'] ?? '',
      ownerEmail: data['ownerEmail'] ?? '',
      planType: data['planType'] ?? 'Standard',
      billingCycle: data['billingCycle'] ?? 'Monthly',
      amount: (data['amount'] ?? 0.0).toDouble(),
      userId: data['userId'] ?? '', // NEW
      status: data['status'] ?? 'PENDING',
      createdAt: _parseDate(data['createdAt']),
      selectedAddons: List<String>.from(data['selectedAddons'] ?? []), // NEW
      durationInDays: data['durationInDays'] ?? 30, // NEW
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    try {
      // Handle Firestore Timestamp if present
      return (value as dynamic).toDate();
    } catch (_) {
      return DateTime.now();
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'storeName': storeName,
      'ownerEmail': ownerEmail,
      'planType': planType,
      'billingCycle': billingCycle,
      'amount': amount,
      'userId': userId, // NEW
      'status': status,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'selectedAddons': selectedAddons, // NEW
      'durationInDays': durationInDays, // NEW
    };
  }
}
