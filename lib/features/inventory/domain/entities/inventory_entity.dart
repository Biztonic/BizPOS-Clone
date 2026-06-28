/// Pure domain entity for Inventory.
///
/// CRITICAL RULE: This file MUST NOT import:
///   - cloud_firestore
///   - hive
///   - sqflite
///   - flutter (except foundation for @immutable)
///
/// All serialization logic belongs in the data layer DTOs.
/// The legacy [InventoryItem] in domain/entities/inventory_item.dart
/// is kept for backward compatibility but violates domain purity
/// (imports cloud_firestore). This entity is the clean replacement.
library;

/// Represents the stock status of an inventory item.
enum StockStatus {
  inStock('In Stock'),
  lowStock('Low Stock'),
  outOfStock('Out of Stock'),
  discontinued('Discontinued');

  final String value;
  const StockStatus(this.value);

  static StockStatus fromString(String status) {
    return StockStatus.values.firstWhere(
      (e) => e.value == status,
      orElse: () => StockStatus.inStock,
    );
  }
}

/// Pure inventory entity — no infrastructure imports.
class InventoryEntity {
  final String id;
  final String name;
  final String category;
  final double price;
  final double cost;
  final int quantity;
  final String unit;
  final String? sku;
  final String? image;
  final String? localImage;
  final bool trackStock;
  final bool featured;
  final int lowStockThreshold;

  // Store association
  final String? storeId;
  final String? centralItemId;

  // Display config
  final String? storeType;
  final String? dietaryType;
  final String? packagingType;
  final String? variantCategory;
  final String? counterId;
  final String cardStyle;
  final String cardSize;

  // Metadata
  final DateTime? expiryDate;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String syncStatus;
  final String? deviceId;
  final int version;

  const InventoryEntity({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.cost = 0.0,
    int quantity = 0,
    this.unit = 'pcs',
    this.sku,
    this.image,
    this.localImage,
    this.trackStock = true,
    this.featured = false,
    this.lowStockThreshold = 10,
    this.storeId,
    this.centralItemId,
    this.storeType,
    this.dietaryType,
    this.packagingType,
    this.variantCategory,
    this.counterId,
    this.cardStyle = 'image',
    this.cardSize = 'medium',
    this.expiryDate,
    this.updatedAt,
    this.deletedAt,
    this.syncStatus = 'PENDING',
    this.deviceId,
    this.version = 1,
  }) : this.quantity = quantity < 0 ? 0 : quantity;

  // ─── Computed Properties ───────────────────────────────────

  /// Current stock status based on quantity thresholds.
  StockStatus get stockStatus {
    if (!trackStock) return StockStatus.inStock;
    if (quantity <= 0) return StockStatus.outOfStock;
    if (quantity <= lowStockThreshold) return StockStatus.lowStock;
    return StockStatus.inStock;
  }

  /// Whether this item is soft-deleted.
  bool get isDeleted => deletedAt != null;

  /// Whether this item is expired.
  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  /// Total inventory value at cost.
  double get totalCostValue => cost * quantity;

  /// Total inventory value at retail price.
  double get totalRetailValue => price * quantity;

  /// Profit margin percentage.
  double get marginPercent =>
      price > 0 ? ((price - cost) / price) * 100 : 0.0;

  // ─── CopyWith ──────────────────────────────────────────────

  InventoryEntity copyWith({
    String? id,
    String? name,
    String? category,
    double? price,
    double? cost,
    int? quantity,
    String? unit,
    String? sku,
    String? image,
    String? localImage,
    bool? trackStock,
    bool? featured,
    int? lowStockThreshold,
    String? storeId,
    String? centralItemId,
    String? storeType,
    String? dietaryType,
    String? packagingType,
    String? variantCategory,
    String? counterId,
    String? cardStyle,
    String? cardSize,
    DateTime? expiryDate,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? syncStatus,
    String? deviceId,
    int? version,
  }) {
    return InventoryEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      sku: sku ?? this.sku,
      image: image ?? this.image,
      localImage: localImage ?? this.localImage,
      trackStock: trackStock ?? this.trackStock,
      featured: featured ?? this.featured,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      storeId: storeId ?? this.storeId,
      centralItemId: centralItemId ?? this.centralItemId,
      storeType: storeType ?? this.storeType,
      dietaryType: dietaryType ?? this.dietaryType,
      packagingType: packagingType ?? this.packagingType,
      variantCategory: variantCategory ?? this.variantCategory,
      counterId: counterId ?? this.counterId,
      cardStyle: cardStyle ?? this.cardStyle,
      cardSize: cardSize ?? this.cardSize,
      expiryDate: expiryDate ?? this.expiryDate,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryEntity && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
