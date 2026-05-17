/// Mapper to convert between OrderDto (data layer) and OrderEntity (domain layer).
///
/// This is the BRIDGE between infrastructure and pure business logic.
/// All conversion logic lives here — entities never know about DTOs.
library;

import '../../domain/entities/order_entity.dart';
import '../dtos/order_dto.dart';

class OrderMapper {
  /// Convert a DTO to a domain entity.
  static OrderEntity toEntity(OrderDto dto) {
    return OrderEntity(
      id: dto.id,
      storeId: dto.storeId,
      items: dto.items.map(_itemToEntity).toList(),
      total: dto.total,
      subtotal: dto.subtotal,
      discount: dto.discount,
      cgst: dto.cgst,
      sgst: dto.sgst,
      taxRateSnapshot: dto.taxRateSnapshot,
      discountSnapshot: dto.discountSnapshot,
      date: dto.date,
      status: OrderStatus.fromString(dto.status),
      type: OrderType.fromString(dto.type),
      paymentMethod: PaymentMethod.fromString(dto.paymentMethod),
      customerId: dto.customerId,
      customerName: dto.customerName,
      customerPhone: dto.customerPhone,
      tableId: dto.tableId,
      tableName: dto.tableName,
      seatNumbers: dto.seatNumbers,
      synced: dto.synced,
      syncStatus: dto.syncStatus,
      deviceId: dto.deviceId,
      businessDayId: dto.businessDayId,
      version: dto.version,
      updatedAt: dto.updatedAt,
      voidedAt: dto.voidedAt,
      voidedBy: dto.voidedBy,
      voidReason: dto.voidReason,
    );
  }

  /// Convert a domain entity to a DTO.
  static OrderDto toDto(OrderEntity entity) {
    return OrderDto(
      id: entity.id,
      storeId: entity.storeId,
      items: entity.items.map(_itemToDto).toList(),
      total: entity.total,
      subtotal: entity.subtotal,
      discount: entity.discount,
      cgst: entity.cgst,
      sgst: entity.sgst,
      taxRateSnapshot: entity.taxRateSnapshot,
      discountSnapshot: entity.discountSnapshot,
      date: entity.date,
      status: entity.status.value,
      type: entity.type.value,
      paymentMethod: entity.paymentMethod.value,
      customerId: entity.customerId,
      customerName: entity.customerName,
      customerPhone: entity.customerPhone,
      tableId: entity.tableId,
      tableName: entity.tableName,
      seatNumbers: entity.seatNumbers,
      synced: entity.synced,
      syncStatus: entity.syncStatus,
      deviceId: entity.deviceId,
      businessDayId: entity.businessDayId,
      version: entity.version,
      updatedAt: entity.updatedAt,
      voidedAt: entity.voidedAt,
      voidedBy: entity.voidedBy,
      voidReason: entity.voidReason,
    );
  }

  /// Convert a list of DTOs to entities.
  static List<OrderEntity> toEntityList(List<OrderDto> dtos) {
    return dtos.map(toEntity).toList();
  }

  /// Convert a list of entities to DTOs.
  static List<OrderDto> toDtoList(List<OrderEntity> entities) {
    return entities.map(toDto).toList();
  }

  // ─── Item Mappers ──────────────────────────────────────────

  static OrderItemEntity _itemToEntity(OrderItemDto dto) {
    return OrderItemEntity(
      itemId: dto.itemId,
      itemName: dto.name,
      price: dto.price,
      cost: dto.cost,
      quantity: dto.quantity,
      note: dto.note,
      category: dto.category,
      seatIndex: dto.seatIndex,
      cgst: dto.cgst,
      sgst: dto.sgst,
    );
  }

  static OrderItemDto _itemToDto(OrderItemEntity entity) {
    return OrderItemDto(
      itemId: entity.itemId,
      name: entity.itemName,
      price: entity.price,
      cost: entity.cost,
      quantity: entity.quantity,
      note: entity.note,
      category: entity.category,
      seatIndex: entity.seatIndex,
      cgst: entity.cgst,
      sgst: entity.sgst,
    );
  }
}
