// ignore_for_file: deprecated_member_use_from_same_package
import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryItem {
  final String id;
  final String name;
  final String category;
  final double price;
  @Deprecated('Use inventory_movements as source of truth. This is a cached view only.')
  final int quantity; 
  
  final String status;
  final String? image;
  final String? counterId;
  final double? cost;
  final String? unit;
  final String? sku;
  final DateTime? expiryDate;
  final bool trackStock;
  final String? storeId; 
  final String? centralItemId;
  final String? storeType;
  final String? dietaryType;
  final String? packagingType;
  final String? variantCategory;
  final String? localImage; // NEW: Local cached image path

  // Customization
  final String cardStyle;
  final String cardSize;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String syncStatus;
  final String? deviceId;
  final int version; // Optimistic Locking
  final bool featured; // NEW: Featured Item Support
  final int? lowStockThreshold; // NEW: Custom Low Stock Threshold

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.quantity = 0, 
    required this.status,
    this.image,
    this.counterId,
    this.cost,
    this.unit,
    this.sku,
    this.expiryDate,
    required this.trackStock,
    this.storeId,
    this.centralItemId,
    this.storeType,
    this.dietaryType,
    this.packagingType,
    this.variantCategory,
    this.cardStyle = 'image',
    this.cardSize = 'medium',
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = 'PENDING',
    this.deviceId,
    this.version = 1,
    this.featured = false, 
    this.lowStockThreshold = 10,
    this.localImage,
  });

  factory InventoryItem.fromMap(Map<String, dynamic> data, String id) {
    // Helper for safe parsing
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is String) return int.tryParse(val) ?? 0;
      if (val is double) return val.toInt();
      return 0;
    }

    // Safe date parser: handles Firestore Timestamp, ISO String, and null
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    return InventoryItem(
      id: id,
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      price: parseDouble(data['price']),
      quantity: parseInt(data['quantity']), 
      status: data['status'] ?? 'In Stock',
      image: data['image'],
      counterId: data['counterId'],
      cost: parseDouble(data['cost']),
      unit: data['unit'],
      sku: data['sku'],
      expiryDate: parseDate(data['expiryDate']),
      trackStock: data['trackStock'] ?? true,
      storeId: data['storeId'],
      centralItemId: data['centralItemId'],
      storeType: data['storeType'],
      dietaryType: data['dietaryType'],
      packagingType: data['packagingType'],
      variantCategory: data['variantCategory'],
      cardStyle: data['cardStyle'] ?? 'image',
      cardSize: data['cardSize'] ?? 'medium',
      updatedAt: parseDate(data['updatedAt']),
      deletedAt: parseDate(data['deletedAt']),
      syncStatus: data['syncStatus'] ?? 'PENDING',
      deviceId: data['deviceId'],
      version: parseInt(data['version']) > 0 ? parseInt(data['version']) : 1,
      featured: data['featured'] ?? false, 
      lowStockThreshold: parseInt(data['lowStockThreshold']) > 0 ? parseInt(data['lowStockThreshold']) : 10,
      localImage: data['localImage'],
    );
  }

  InventoryItem copyWith({
    String? id,
    String? name,
    String? category,
    double? price,
    int? quantity,
    String? status,
    String? image,
    String? counterId,
    double? cost,
    String? unit,
    String? sku,
    DateTime? expiryDate,
    bool? trackStock,
    String? storeId,
    String? centralItemId,
    String? storeType,
    String? dietaryType,
    String? packagingType,
    String? variantCategory,
    String? cardStyle,
    String? cardSize,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? syncStatus,
    String? deviceId,
    int? version,
     bool? featured,
    int? lowStockThreshold,
    String? localImage,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      image: image ?? this.image,
      counterId: counterId ?? this.counterId,
      cost: cost ?? this.cost,
      unit: unit ?? this.unit,
      sku: sku ?? this.sku,
      expiryDate: expiryDate ?? this.expiryDate,
      trackStock: trackStock ?? this.trackStock,
      storeId: storeId ?? this.storeId,
      centralItemId: centralItemId ?? this.centralItemId,
      storeType: storeType ?? this.storeType,
      dietaryType: dietaryType ?? this.dietaryType,
      packagingType: packagingType ?? this.packagingType,
      variantCategory: variantCategory ?? this.variantCategory,
      cardStyle: cardStyle ?? this.cardStyle,
      cardSize: cardSize ?? this.cardSize,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
      featured: featured ?? this.featured,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      localImage: localImage ?? this.localImage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'price': price,
      'status': status,
      'image': image,
      'counterId': counterId,
      'cost': cost,
      'unit': unit,
      'sku': sku,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'trackStock': trackStock,
      'storeId': storeId,
      'centralItemId': centralItemId,
      'storeType': storeType,
      'dietaryType': dietaryType,
      'packagingType': packagingType,
      'variantCategory': variantCategory,
      'cardStyle': cardStyle,
      'cardSize': cardSize,
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
      'deletedAt': deletedAt, 
      'syncStatus': syncStatus,
      'deviceId': deviceId,
      'version': version,
      'featured': featured, 
      'lowStockThreshold': lowStockThreshold,
      'localImage': localImage,
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
      'name': name,
      'category': category,
      'price': price,
      'quantity': quantity,
      'status': status,
      'image': image,
      'counterId': counterId,
      'cost': cost,
      'unit': unit,
      'sku': sku,
      'expiryDate': expiryDate?.toIso8601String(),
      'trackStock': trackStock,
      'storeId': storeId,
      'centralItemId': centralItemId,
      'storeType': storeType,
      'dietaryType': dietaryType,
      'packagingType': packagingType,
      'variantCategory': variantCategory,
      'cardStyle': cardStyle,
      'cardSize': cardSize,
      'updatedAt': updatedAt?.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'syncStatus': syncStatus,
      'deviceId': deviceId,
      'version': version,
      'featured': featured, 
      'lowStockThreshold': lowStockThreshold,
      'localImage': localImage,
    };
  }
  // --- SQFlite Adapters ---
  Map<String, dynamic> toSqlMap() {
    return {
      'id': id,
      'storeId': storeId,
      'name': name,
      'category': category,
      'price': price,
      'quantity': quantity,
      'status': status,
      'image': image,
      'sku': sku,
      'cost': cost,
      'unit': unit,
      'expiryDate': expiryDate?.toIso8601String(),
      'trackStock': trackStock ? 1 : 0, // Boolean -> Integer
      'centralItemId': centralItemId,
      'storeType': storeType,
      'dietaryType': dietaryType,
      'packagingType': packagingType,
      'variantCategory': variantCategory,
      'updatedAt': updatedAt?.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'syncStatus': syncStatus,
      'deviceId': deviceId,
      'version': version,
      'featured': featured ? 1 : 0, // Boolean -> Integer
      'lowStockThreshold': lowStockThreshold,
      'localImage': localImage,
    };
  }

  factory InventoryItem.fromSql(Map<String, dynamic> row) {
    return InventoryItem(
      id: row['id'],
      name: row['name'],
      category: row['category'],
      price: (row['price'] ?? 0).toDouble(),
      quantity: (row['quantity'] ?? 0).toInt(),
      status: row['status'] ?? 'In Stock',
      image: row['image'],
      sku: row['sku'],
      cost: (row['cost'] ?? 0).toDouble(),
      unit: row['unit'],
      expiryDate: row['expiryDate'] != null ? DateTime.tryParse(row['expiryDate']) : null,
      trackStock: (row['trackStock'] == 1), // Integer -> Boolean
      storeId: row['storeId'],
      centralItemId: row['centralItemId'],
      storeType: row['storeType'],
      dietaryType: row['dietaryType'],
      packagingType: row['packagingType'],
      variantCategory: row['variantCategory'],
      updatedAt: DateTime.tryParse(row['updatedAt'] ?? ''),
      deletedAt: DateTime.tryParse(row['deletedAt'] ?? ''),
      syncStatus: row['syncStatus'] ?? 'PENDING',
      deviceId: row['deviceId'],
      version: row['version'] ?? 1,
      featured: (row['featured'] == 1), // Integer -> Boolean
      lowStockThreshold: (row['lowStockThreshold'] ?? 10).toInt(),
      localImage: row['localImage'],
    );
  }
}
