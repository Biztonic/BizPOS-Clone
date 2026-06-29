class SubscriptionHistory {
  final String id;
  final String storeId;
  final String planName;
  final double amount;
  final String billingCycle;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final List<String> selectedAddons; // NEW
  final bool isAddonOnly; // NEW

  SubscriptionHistory({
    required this.id,
    required this.storeId,
    required this.planName,
    required this.amount,
    required this.billingCycle,
    required this.startDate,
    required this.endDate,
    this.status = 'ACTIVE',
    this.selectedAddons = const [], // NEW
    this.isAddonOnly = false, // NEW
  });

  factory SubscriptionHistory.fromMap(Map<String, dynamic> data, String id) {
    return SubscriptionHistory(
      id: id,
      storeId: data['storeId'] ?? '',
      planName: data['planName'] ?? 'Standard',
      amount: (data['amount'] ?? 0.0).toDouble(),
      billingCycle: data['billingCycle'] ?? 'Monthly',
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
      status: data['status'] ?? 'ACTIVE',
      selectedAddons: List<String>.from(data['selectedAddons'] ?? []), // NEW
      isAddonOnly: data['isAddonOnly'] ?? false, // NEW
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
      'planName': planName,
      'amount': amount,
      'billingCycle': billingCycle,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'status': status,
      'selectedAddons': selectedAddons, // NEW
      'isAddonOnly': isAddonOnly, // NEW
    };
  }

  bool get isActive {
    if (status != 'ACTIVE') return false;
    return DateTime.now().isBefore(endDate);
  }

  bool get isQueued {
    return status == 'QUEUED';
  }
}
