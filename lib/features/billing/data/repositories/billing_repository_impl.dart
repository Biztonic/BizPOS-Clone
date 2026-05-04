/// Concrete implementation of the [BillingRepository] domain interface.
///
/// This adapter bridges the legacy [Repository] facade with the new
/// clean architecture contract. It uses [OrderMapper] to convert
/// between DTOs and domain entities at the boundary.
///
/// Over time, the legacy Repository can be retired and this class
/// can call SQLite/Hive/Firestore data sources directly.

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/models/order_model.dart';

import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/billing_repository.dart';
import '../dtos/order_dto.dart';
import '../mappers/order_mapper.dart';

class BillingRepositoryImpl implements BillingRepository {
  final Repository _legacyRepo;

  BillingRepositoryImpl({Repository? repository})
      : _legacyRepo = repository ?? Repository();

  // ─── CRUD ──────────────────────────────────────────────────

  @override
  Future<BillingResult<void>> insertOrder(OrderEntity order) async {
    try {
      final dto = OrderMapper.toDto(order);
      // Convert to legacy OrderModel for backward compatibility
      final legacyOrder = _dtoToLegacyModel(dto);
      await _legacyRepo.insertOrder(legacyOrder);
      return BillingResult.success(null);
    } catch (e) {
      return BillingResult.failure('Failed to insert order: $e');
    }
  }

  @override
  Future<BillingResult<OrderEntity>> getOrder(String orderId) async {
    try {
      final legacyOrder = await _legacyRepo.getOrder(orderId);
      if (legacyOrder == null) {
        return BillingResult.failure('Order not found: $orderId');
      }
      final entity = _legacyModelToEntity(legacyOrder);
      return BillingResult.success(entity);
    } catch (e) {
      return BillingResult.failure('Failed to get order: $e');
    }
  }

  @override
  Future<BillingResult<List<OrderEntity>>> getOrders(String? storeId) async {
    try {
      final legacyOrders = await _legacyRepo.getOrders(storeId);
      final entities = legacyOrders.map(_legacyModelToEntity).toList();
      return BillingResult.success(entities);
    } catch (e) {
      return BillingResult.failure('Failed to get orders: $e');
    }
  }

  @override
  Future<BillingResult<List<OrderEntity>>> getPaginatedOrders(
    String? storeId, {
    int limit = 20,
    DateTime? lastDate,
  }) async {
    try {
      if (kIsWeb) {
        return _getPaginatedOrdersFromHive(storeId, limit: limit);
      }
      final legacyOrders = await _legacyRepo.getPaginatedOrders(
        storeId,
        limit: limit,
        lastDate: lastDate,
      );
      final entities = legacyOrders.map(_legacyModelToEntity).toList();
      return BillingResult.success(entities);
    } catch (e) {
      return BillingResult.failure('Failed to get paginated orders: $e');
    }
  }

  @override
  Future<BillingResult<List<OrderEntity>>> getOrdersByCustomer(
    String storeId,
    String customerId,
  ) async {
    try {
      final legacyOrders = await _legacyRepo.getOrdersByCustomer(storeId, customerId);
      final entities = legacyOrders.map(_legacyModelToEntity).toList();
      return BillingResult.success(entities);
    } catch (e) {
      return BillingResult.failure('Failed to get customer orders: $e');
    }
  }

  // ─── Batch Operations ─────────────────────────────────────

  @override
  Future<BillingResult<void>> batchInsertOrders(List<OrderEntity> orders) async {
    try {
      final legacyOrders = orders.map((e) {
        final dto = OrderMapper.toDto(e);
        return _dtoToLegacyModel(dto);
      }).toList();
      await _legacyRepo.batchInsertOrders(legacyOrders);
      return BillingResult.success(null);
    } catch (e) {
      return BillingResult.failure('Failed to batch insert orders: $e');
    }
  }

  @override
  Future<BillingResult<List<OrderEntity>>> getUnsyncedOrders(String? storeId) async {
    try {
      final legacyOrders = await _legacyRepo.getUnsyncedOrders(storeId);
      final entities = legacyOrders.map(_legacyModelToEntity).toList();
      return BillingResult.success(entities);
    } catch (e) {
      return BillingResult.failure('Failed to get unsynced orders: $e');
    }
  }

  @override
  Future<BillingResult<void>> markOrderAsSynced(String orderId) async {
    try {
      await _legacyRepo.markOrderAsSynced(orderId);
      return BillingResult.success(null);
    } catch (e) {
      return BillingResult.failure('Failed to mark order as synced: $e');
    }
  }

  // ─── Aggregations ─────────────────────────────────────────

  @override
  Future<BillingResult<SalesStats>> getSalesStats(
    String storeId, {
    DateTime? start,
    DateTime? end,
    String? status,
    String? paymentMethod,
  }) async {
    try {
      final Map<String, dynamic> raw;
      if (kIsWeb) {
        raw = await _getSalesStatsFromHive(
          storeId,
          start: start,
          end: end,
          status: status,
          paymentMethod: paymentMethod,
        );
      } else {
        raw = await _legacyRepo.getSalesStats(
          storeId,
          start: start,
          end: end,
          status: status,
          paymentMethod: paymentMethod,
        );
      }
      final stats = SalesStats(
        totalSales: (raw['totalSales'] ?? 0.0).toDouble(),
        orderCount: (raw['orderCount'] ?? 0).toInt(),
        avgOrderValue: (raw['avgOrderValue'] ?? 0.0).toDouble(),
        cardSales: (raw['cardSales'] ?? 0.0).toDouble(),
        cashSales: (raw['cashSales'] ?? 0.0).toDouble(),
        totalCogs: (raw['totalCogs'] ?? 0.0).toDouble(),
        grossProfit: (raw['grossProfit'] ?? 0.0).toDouble(),
      );
      return BillingResult.success(stats);
    } catch (e) {
      return BillingResult.failure('Failed to get sales stats: $e');
    }
  }

  @override
  Future<BillingResult<List<Map<String, dynamic>>>> getSalesByDay(
    String storeId,
    int days,
  ) async {
    try {
      final data = await _legacyRepo.getSalesByDay(storeId, days);
      return BillingResult.success(data);
    } catch (e) {
      return BillingResult.failure('Failed to get daily sales: $e');
    }
  }

  @override
  Future<BillingResult<int>> getDailyOrderCount(
    String storeId,
    String dateStr,
  ) async {
    try {
      final count = await _legacyRepo.getDailyOrderCount(storeId, dateStr);
      return BillingResult.success(count);
    } catch (e) {
      return BillingResult.failure('Failed to get daily order count: $e');
    }
  }

  @override
  Future<BillingResult<int>> getMonthlyOrderCount(
    String storeId,
    String yearMonth,
  ) async {
    try {
      final count = await _legacyRepo.getMonthlyOrderCount(storeId, yearMonth);
      return BillingResult.success(count);
    } catch (e) {
      return BillingResult.failure('Failed to get monthly order count: $e');
    }
  }

  // ─── Private: Legacy Adapters ─────────────────────────────

  /// Convert a DTO to a legacy OrderModel for backward compat.
  OrderModel _dtoToLegacyModel(OrderDto dto) {
    return OrderModel(
      id: dto.id,
      storeId: dto.storeId,
      items: dto.items.map((i) => OrderItem(
        item: _createMinimalItem(i),
        quantity: i.quantity,
        costSnapshot: i.cost,
        priceSnapshot: i.price,
        cgst: i.cgst,
        sgst: i.sgst,
      )).toList(),
      total: dto.total,
      subtotal: dto.subtotal,
      discount: dto.discount,
      cgst: dto.cgst,
      sgst: dto.sgst,
      date: dto.date,
      status: dto.status,
      type: dto.type,
      paymentMethod: dto.paymentMethod,
      tableId: dto.tableId,
      tableName: dto.tableName,
      taxRateSnapshot: dto.taxRateSnapshot,
      syncStatus: dto.syncStatus,
      deviceId: dto.deviceId,
      businessDayId: dto.businessDayId,
    );
  }

  /// Convert a legacy OrderModel to domain entity.
  OrderEntity _legacyModelToEntity(OrderModel model) {
    return OrderEntity(
      id: model.id,
      storeId: model.storeId,
      items: model.items.map((item) => OrderItemEntity(
        itemId: item.item.id,
        itemName: item.item.name,
        price: item.priceSnapshot ?? item.item.price,
        cost: item.costSnapshot ?? 0.0,
        quantity: item.quantity,
        category: item.item.category,
        cgst: item.cgst ?? 0.0,
        sgst: item.sgst ?? 0.0,
      )).toList(),
      total: model.total,
      subtotal: model.subtotal ?? 0.0,
      discount: model.discount ?? 0.0,
      cgst: model.cgst ?? 0.0,
      sgst: model.sgst ?? 0.0,
      taxRateSnapshot: model.taxRateSnapshot ?? 0.0,
      date: model.date,
      status: OrderStatus.fromString(model.status),
      type: OrderType.fromString(model.type),
      paymentMethod: PaymentMethod.fromString(model.paymentMethod),
      tableId: model.tableId,
      tableName: model.tableName,
      synced: model.syncStatus == 'SYNCED' || model.syncStatus == 'CONFIRMED',
      syncStatus: model.syncStatus,
      deviceId: model.deviceId,
      businessDayId: model.businessDayId,
      version: model.version ?? 1,
    );
  }

  /// Creates a minimal InventoryItem stub for legacy OrderItem compat.
  dynamic _createMinimalItem(OrderItemDto dto) {
    // Import avoided — using dynamic to prevent circular dependency.
    // The legacy OrderItem.toSqlMap() only needs id, name, price, cost, category.
    return _MinimalItem(
      id: dto.itemId,
      name: dto.name,
      price: dto.price,
      cost: dto.cost,
      category: dto.category ?? '',
    );
  }

  // ─── Private: Hive Fallback for Web ───────────────────────

  Future<BillingResult<List<OrderEntity>>> _getPaginatedOrdersFromHive(
    String? storeId, {
    int limit = 20,
  }) async {
    try {
      final box = await Hive.openBox('cache_orders');
      final targetStoreId = storeId?.trim();
      if (targetStoreId == null) return BillingResult.success([]);

      final cachedData = box.values
          .where((v) {
            if (v is! Map) return false;
            final vStoreId = (v['storeId'] ?? '').toString().trim();
            return vStoreId == targetStoreId && v['deletedAt'] == null;
          })
          .map((e) => _recursiveCast(e as Map))
          .toList();

      cachedData.sort((a, b) =>
          (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));

      final limited = cachedData.take(limit).toList();
      final entities = limited.map((d) {
        final dto = OrderDto.fromHive(d);
        return OrderMapper.toEntity(dto);
      }).toList();

      return BillingResult.success(entities);
    } catch (e) {
      return BillingResult.failure('Hive fallback failed: $e');
    }
  }

  Future<Map<String, dynamic>> _getSalesStatsFromHive(
    String storeId, {
    DateTime? start,
    DateTime? end,
    String? status,
    String? paymentMethod,
  }) async {
    final box = await Hive.openBox('cache_orders');
    double totalSales = 0, cardSales = 0, cashSales = 0, totalCogs = 0;
    int count = 0;
    final targetStoreId = storeId.trim();

    for (var val in box.values) {
      if (val is! Map) continue;
      final vStoreId = (val['storeId'] ?? '').toString().trim();
      if (vStoreId != targetStoreId) continue;
      if (val['deletedAt'] != null) continue;

      final orderStatus = val['status'] ?? 'New';
      final orderDate = DateTime.tryParse(
              (val['date'] ?? val['createdAt'] ?? '').toString()) ??
          DateTime.now();
      final pm = val['paymentMethod'] ?? 'Cash';

      if (status != null) {
        if (orderStatus != status) continue;
      } else {
        if (['Cancelled', 'VOID'].contains(orderStatus)) continue;
      }
      if (paymentMethod != null && pm != paymentMethod) continue;
      if (start != null && orderDate.isBefore(start)) continue;
      if (end != null &&
          orderDate.isAfter(end.add(const Duration(days: 1)))) continue;

      final isRefunded = orderStatus == 'Refunded';
      final orderTotal = (val['total'] ?? 0).toDouble();
      final effectiveTotal = isRefunded ? 0.0 : orderTotal;

      totalSales += effectiveTotal;
      if (['Card', 'UPI'].contains(pm)) {
        cardSales += effectiveTotal;
      } else if (pm == 'Cash') {
        cashSales += effectiveTotal;
      }

      final items = val['items'] as List<dynamic>? ?? [];
      for (var itemRecord in items) {
        if (itemRecord is Map) {
          final qty = (itemRecord['quantity'] ?? 0).toDouble();
          final cost =
              (itemRecord['costSnapshot'] ?? itemRecord['cost'] ?? 0)
                  .toDouble();
          totalCogs += isRefunded ? 0.0 : (cost * qty);
        }
      }
      if (!isRefunded) count++;
    }

    return {
      'totalSales': totalSales,
      'orderCount': count,
      'avgOrderValue': count > 0 ? totalSales / count : 0.0,
      'cardSales': cardSales,
      'cashSales': cashSales,
      'totalCogs': totalCogs,
      'grossProfit': totalSales - totalCogs,
    };
  }

  Map<String, dynamic> _recursiveCast(Map map) {
    return map.map((key, value) {
      if (value is Map) return MapEntry(key.toString(), _recursiveCast(value));
      if (value is List) {
        return MapEntry(key.toString(),
            value.map((e) => e is Map ? _recursiveCast(e) : e).toList());
      }
      return MapEntry(key.toString(), value);
    });
  }
}

/// Minimal item stub to satisfy legacy OrderItem constructor
/// without importing InventoryItem (avoids circular dependency).
class _MinimalItem {
  final String id;
  final String name;
  final double price;
  final double cost;
  final String category;
  final int quantity = 0;
  final String status = 'Active';
  final bool trackStock = false;

  _MinimalItem({
    required this.id,
    required this.name,
    required this.price,
    required this.cost,
    required this.category,
  });
}
