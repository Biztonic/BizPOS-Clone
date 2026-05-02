import 'settings.dart';

class Store {
  final String id;
  final String name;
  final String owner;
  final String ownerEmail;
  final String status;
  final String storeType;
  final String subscriptionPlan;
  final List<String> addons;
  final List<String> purchasedAddons; // NEW
  final DateTime? subscriptionExpiry; // NEW
  final bool autoActivateSubscription;
  
  final String? shortCode;
  final String? franchiseId;
  final String? franchiseName;
  final String? address;
  final String? phone;
  final double? taxRate;
  final bool isTaxEnabled;
  final bool trackInventory;
  final String? image;
  final String? gstin;
  final ReceiptSettings receipt;
  final PaymentSettings payment;
  final KdsSettings kds;
  final List<String> customRoles;
  final Map<String, Map<String, bool>> rolePermissions;

  Store({
    required this.id,
    required this.name,
    required this.owner,
    required this.ownerEmail,
    required this.status,
    required this.storeType,
    this.subscriptionPlan = 'Basic', 
    this.addons = const [], // Default empty
    this.purchasedAddons = const [], // NEW
    this.subscriptionExpiry, // NEW
    this.shortCode,
    this.franchiseId,
    this.franchiseName,
    this.address,
    this.phone,
    this.taxRate,
    this.isTaxEnabled = false,
    this.trackInventory = true,
    this.image,
    this.gstin,
    required this.receipt,
    required this.payment,
    required this.kds, 
    this.customRoles = const ['Cashier', 'Manager', 'Kitchen Staff', 'Waiter', 'Inventory Clerk'],
    this.rolePermissions = const {},
    this.autoActivateSubscription = true,
  });

  factory Store.fromMap(Map data, String id) {
    return Store(
      id: id,
      name: data['name'] ?? '',
      owner: data['owner'] ?? '',
      ownerEmail: data['ownerEmail'] ?? '',
      status: data['status'] ?? 'Active',
      storeType: data['storeType'] ?? 'Restaurant',
      subscriptionPlan: data['subscriptionPlan'] ?? 'Basic',
      addons: (data['addons'] as List<dynamic>?)?.map((e) => e?.toString() ?? '').toList() ?? [],
      purchasedAddons: (data['purchasedAddons'] as List<dynamic>?)?.map((e) => e?.toString() ?? '').toList() ?? [],
      subscriptionExpiry: _parseDateTime(data['subscriptionExpiry']),
      shortCode: data['shortCode'],
      franchiseId: data['franchiseId'],
      franchiseName: data['franchiseName'],
      address: data['address'],
      phone: data['phone'],
      taxRate: (data['taxRate'] ?? 0.0).toDouble(),
      isTaxEnabled: data['isTaxEnabled'] ?? false,
      trackInventory: data['trackInventory'] ?? true,
      image: data['image'],
      gstin: data['gstin'],
      receipt: ReceiptSettings.fromMap(data['receipt'] ?? {}),
      payment: PaymentSettings.fromMap(data['payment'] ?? {}),
      kds: KdsSettings.fromMap(data['kds'] ?? {}),
      customRoles: (data['customRoles'] as List<dynamic>?)?.map((e) => e?.toString() ?? '').toList() 
          ?? const ['Cashier', 'Manager', 'Kitchen Staff', 'Waiter', 'Inventory Clerk'],
      rolePermissions: _parseRolePermissions(data['rolePermissions']),
      autoActivateSubscription: data['autoActivateSubscription'] ?? true,
    );
  }

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    // Handle Firestore Timestamp (check for .toDate() via duck typing or type check)
    try {
      if (val.runtimeType.toString().contains('Timestamp')) return val.toDate();
    } catch (_) {}
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  static Map<String, Map<String, bool>> _parseRolePermissions(dynamic raw) {
    if (raw == null || raw is! Map) return {};
    final result = <String, Map<String, bool>>{};
    for (final entry in raw.entries) {
      if (entry.value is Map) {
        result[entry.key.toString()] = Map<String, bool>.from(
          (entry.value as Map).map((k, v) => MapEntry(k.toString(), v == true)),
        );
      }
    }
    return result;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'owner': owner,
      'ownerEmail': ownerEmail,
      'status': status,
      'storeType': storeType,
      'subscriptionPlan': subscriptionPlan,
      'addons': addons,
      'purchasedAddons': purchasedAddons,
      'subscriptionExpiry': subscriptionExpiry?.millisecondsSinceEpoch,
      'shortCode': shortCode,
      'franchiseId': franchiseId,
      'franchiseName': franchiseName,
      'address': address,
      'phone': phone,
      'taxRate': taxRate,
      'isTaxEnabled': isTaxEnabled,
      'trackInventory': trackInventory,
      'image': image,
      'gstin': gstin,
      'receipt': receipt.toMap(),
      'payment': payment.toMap(),
      'kds': kds.toMap(),
      'customRoles': customRoles,
      'rolePermissions': rolePermissions.map((k, v) => MapEntry(k, v)),
      'autoActivateSubscription': autoActivateSubscription,
    };
  }

  Store copyWith({
    String? name,
    String? owner,
    String? ownerEmail,
    String? status,
    String? storeType,
    String? subscriptionPlan,
    List<String>? addons,
    List<String>? purchasedAddons,
    DateTime? subscriptionExpiry,
    String? shortCode,
    String? franchiseId,
    String? franchiseName,
    String? address,
    String? phone,
    double? taxRate,
    bool? isTaxEnabled,
    bool? trackInventory,
    String? image,
    String? gstin,
    ReceiptSettings? receipt,
    PaymentSettings? payment,
    KdsSettings? kds, 
    List<String>? customRoles,
    Map<String, Map<String, bool>>? rolePermissions,
    bool? autoActivateSubscription,
  }) {
    return Store(
      id: id,
      name: name ?? this.name,
      owner: owner ?? this.owner,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      status: status ?? this.status,
      storeType: storeType ?? this.storeType,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      addons: addons ?? this.addons,
      purchasedAddons: purchasedAddons ?? this.purchasedAddons,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      shortCode: shortCode ?? this.shortCode,
      franchiseId: franchiseId ?? this.franchiseId,
      franchiseName: franchiseName ?? this.franchiseName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      taxRate: taxRate ?? this.taxRate,
      isTaxEnabled: isTaxEnabled ?? this.isTaxEnabled,
      trackInventory: trackInventory ?? this.trackInventory,
      image: image ?? this.image,
      gstin: gstin ?? this.gstin,
      receipt: receipt ?? this.receipt,
      payment: payment ?? this.payment,
      kds: kds ?? this.kds, 
      customRoles: customRoles ?? this.customRoles,
      rolePermissions: rolePermissions ?? this.rolePermissions,
      autoActivateSubscription: autoActivateSubscription ?? this.autoActivateSubscription,
    );
  }
}

