/// Abstract repository interface for billing operations.
///
/// CRITICAL RULE: This belongs to the DOMAIN layer.
/// It defines the "contract" — the DATA layer provides the implementation.
///
/// No infrastructure imports allowed here.
library;

import '../entities/order_entity.dart';

/// Result wrapper for operations that can fail gracefully.
class BillingResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  BillingResult.success(this.data)
      : error = null,
        isSuccess = true;

  BillingResult.failure(this.error)
      : data = null,
        isSuccess = false;
}

/// Sales statistics for a given period.
class SalesStats {
  final double totalSales;
  final int orderCount;
  final double avgOrderValue;
  final double cardSales;
  final double cashSales;
  final double totalCogs;
  final double grossProfit;

  const SalesStats({
    required this.totalSales,
    required this.orderCount,
    required this.avgOrderValue,
    required this.cardSales,
    required this.cashSales,
    required this.totalCogs,
    required this.grossProfit,
  });
}

/// Abstract contract for billing data operations.
///
/// Implementations may use SQLite, Firestore, Hive, or any
/// combination of data sources.
abstract class BillingRepository {
  // ─── CRUD ──────────────────────────────────────────────────

  /// Insert or replace an order.
  Future<BillingResult<void>> insertOrder(OrderEntity order);

  /// Retrieve a single order by ID.
  Future<BillingResult<OrderEntity>> getOrder(String orderId);

  /// Retrieve all orders for a store, sorted by date descending.
  Future<BillingResult<List<OrderEntity>>> getOrders(String? storeId);

  /// Retrieve orders with keyset pagination.
  Future<BillingResult<List<OrderEntity>>> getPaginatedOrders(
    String? storeId, {
    int limit = 20,
    DateTime? lastDate,
  });

  /// Retrieve orders for a specific customer.
  Future<BillingResult<List<OrderEntity>>> getOrdersByCustomer(
    String storeId,
    String customerId,
  );

  // ─── Batch Operations ─────────────────────────────────────

  /// Batch insert orders (used during sync pulls).
  Future<BillingResult<void>> batchInsertOrders(List<OrderEntity> orders);

  /// Retrieve all unsynced orders for a store.
  Future<BillingResult<List<OrderEntity>>> getUnsyncedOrders(String? storeId);

  /// Mark an order as synced after successful cloud push.
  Future<BillingResult<void>> markOrderAsSynced(String orderId);

  // ─── Aggregations ─────────────────────────────────────────

  /// Get sales statistics for a store with optional filters.
  Future<BillingResult<SalesStats>> getSalesStats(
    String storeId, {
    DateTime? start,
    DateTime? end,
    String? status,
    String? paymentMethod,
  });

  /// Get daily sales breakdown for the last N days.
  Future<BillingResult<List<Map<String, dynamic>>>> getSalesByDay(
    String storeId,
    int days,
  );

  /// Get the daily order count for a specific date.
  Future<BillingResult<int>> getDailyOrderCount(
    String storeId,
    String dateStr,
  );

  /// Get the monthly order count for a specific year-month.
  Future<BillingResult<int>> getMonthlyOrderCount(
    String storeId,
    String yearMonth,
  );
}
