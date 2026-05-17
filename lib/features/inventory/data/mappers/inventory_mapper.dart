// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package
import 'package:biztonic_pos/models/inventory_item.dart' as legacy;
import '../../domain/entities/inventory_entity.dart';

/// Maps between pure [InventoryEntity] and legacy infrastructure models.
class InventoryMapper {
  /// Convert legacy model to pure domain entity.
  static InventoryEntity fromLegacy(legacy.InventoryItem item) {
    return InventoryEntity(
      id: item.id,
      name: item.name,
      category: item.category,
      price: item.price,
      cost: item.cost ?? 0.0,
      quantity: item.quantity,
      unit: item.unit ?? 'pcs',
      sku: item.sku,
      image: item.image,
      localImage: item.localImage,
      trackStock: item.trackStock,
      featured: item.featured,
      lowStockThreshold: item.lowStockThreshold ?? 10,
      storeId: item.storeId,
      centralItemId: item.centralItemId,
      storeType: item.storeType,
      dietaryType: item.dietaryType,
      packagingType: item.packagingType,
      variantCategory: item.variantCategory,
      counterId: item.counterId,
      cardStyle: item.cardStyle,
      cardSize: item.cardSize,
      expiryDate: item.expiryDate,
      updatedAt: item.updatedAt,
      deletedAt: item.deletedAt,
      syncStatus: item.syncStatus,
      deviceId: item.deviceId,
      version: item.version,
    );
  }

  /// Convert pure domain entity to legacy model for persistence.
  static legacy.InventoryItem toLegacy(InventoryEntity entity) {
    return legacy.InventoryItem(
      id: entity.id,
      name: entity.name,
      category: entity.category,
      price: entity.price,
      cost: entity.cost,
      quantity: entity.quantity,
      unit: entity.unit,
      sku: entity.sku,
      image: entity.image,
      localImage: entity.localImage,
      trackStock: entity.trackStock,
      featured: entity.featured,
      lowStockThreshold: entity.lowStockThreshold,
      storeId: entity.storeId,
      centralItemId: entity.centralItemId,
      storeType: entity.storeType,
      dietaryType: entity.dietaryType,
      packagingType: entity.packagingType,
      variantCategory: entity.variantCategory,
      counterId: entity.counterId,
      cardStyle: entity.cardStyle,
      cardSize: entity.cardSize,
      expiryDate: entity.expiryDate,
      updatedAt: entity.updatedAt,
      deletedAt: entity.deletedAt,
      syncStatus: entity.syncStatus,
      deviceId: entity.deviceId,
      version: entity.version,
      status: entity.stockStatus.value,
    );
  }

  /// Convert to a map, typically for Hive or JSON serialization.
  static Map<String, dynamic> toMap(InventoryEntity entity) {
    return toLegacy(entity).toMap();
  }

  /// Parse from a map, typically from Hive or JSON.
  static InventoryEntity fromMap(Map<String, dynamic> map, String id) {
    return fromLegacy(legacy.InventoryItem.fromMap(map, id));
  }
}
