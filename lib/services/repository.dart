import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';

// Import Entities
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/models/inventory_item.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:biztonic_pos/models/customer.dart';
import 'package:biztonic_pos/models/business_ledger.dart';
import 'package:biztonic_pos/models/user_profile.dart';

import 'package:biztonic_pos/services/sync_service.dart';

// Import New Repositories
import 'package:biztonic_pos/features/billing/data/order_repository.dart';
import 'package:biztonic_pos/features/inventory/data/inventory_repository.dart';
import 'package:biztonic_pos/features/crm/data/customer_repository.dart';
import 'package:biztonic_pos/features/reporting/data/reporting_repository.dart';
import 'package:biztonic_pos/features/store/data/store_repository.dart';
import 'package:biztonic_pos/sync/data/sync_repository.dart';

/// Legacy Repository Façade
/// 
/// This class maintains backward compatibility by delegating calls to 
/// domain-specific repositories. New code should prefer using the 
/// specialized repositories directly via ServiceLocator.
class Repository {
  final DatabaseHelper dbHelper = DatabaseHelper();
  final InventoryMovementRepository movementRepo = InventoryMovementRepository();

  // Internal Repositories
  late final OrderRepository _orders = OrderRepository(dbHelper: dbHelper, movementRepo: movementRepo);
  late final InventoryRepository _inventory = InventoryRepository(dbHelper: dbHelper, movementRepo: movementRepo);
  late final CustomerRepository _customers = CustomerRepository(dbHelper: dbHelper);
  late final ReportingRepository _reporting = ReportingRepository(dbHelper: dbHelper);
  late final StoreRepository _store = StoreRepository(SyncService());
  late final SyncRepository _sync = SyncRepository(dbHelper: dbHelper);

  Repository();

  // Getters for direct access if needed
  OrderRepository get orders => _orders;
  InventoryRepository get inventory => _inventory;
  CustomerRepository get customers => _customers;
  ReportingRepository get reporting => _reporting;
  StoreRepository get store => _store;
  SyncRepository get sync => _sync;

  Future<Database> get database => dbHelper.database;

  // --- ORDER DELEGATIONS ---
  Future<void> insertOrder(OrderModel order) => _orders.insertOrder(order);
  Future<int> getDailyOrderCount(String storeId, String dateStr) => _orders.getDailyOrderCount(storeId, dateStr);
  Future<int> getMonthlyOrderCount(String storeId, String yearMonth) => _orders.getMonthlyOrderCount(storeId, yearMonth);
  Future<void> performAtomicCheckout({
    required OrderModel order,
    required List<InventoryMovement> movements,
    required BusinessEvent event,
    required String storeId,
    required String yearMonth,
  }) => _orders.performAtomicCheckout(
    order: order, 
    movements: movements, 
    event: event, 
    storeId: storeId, 
    yearMonth: yearMonth
  );
  Future<void> replayTransaction(String txId, String operationsJson) => _orders.replayTransaction(txId, operationsJson);
  Future<void> batchInsertOrders(List<OrderModel> orders) => _orders.batchInsertOrders(orders);
  Future<List<OrderModel>> getOrders(String? storeId) => _orders.getOrders(storeId);
  Future<OrderModel?> getOrder(String id) => _orders.getOrder(id);
  Future<List<OrderModel>> getOrdersByCustomer(String storeId, String customerId) => _orders.getOrdersByCustomer(storeId, customerId);
  Future<List<OrderModel>> getPaginatedOrders(String? storeId, {int limit = 20, DateTime? lastDate}) => _orders.getPaginatedOrders(storeId, limit: limit, lastDate: lastDate);
  Future<List<OrderModel>> getUnsyncedOrders(String? storeId) => _orders.getUnsyncedOrders(storeId);
  Future<Map<String, dynamic>> getSalesStats(String storeId, {DateTime? start, DateTime? end, String? status, String? paymentMethod}) => _orders.getSalesStats(storeId, start: start, end: end, status: status, paymentMethod: paymentMethod);
  Future<List<Map<String, dynamic>>> getSalesByDay(String storeId, int days) => _orders.getSalesByDay(storeId, days);
  Future<void> markOrderAsSynced(String orderId) => _orders.markOrderAsSynced(orderId);

  // --- INVENTORY DELEGATIONS ---
  Future<void> insertInventory(InventoryItem item) => _inventory.insertInventory(item);
  Future<int> getPendingInventoryDelta(String itemId, {String? storeId}) => _inventory.getPendingInventoryDelta(itemId, storeId: storeId);
  Future<void> updateInventoryCache(String itemId, int quantity, String storeId) => _inventory.updateInventoryCache(itemId, quantity, storeId);
  Future<void> insertMovement(InventoryMovement movement, {Transaction? txn}) => _inventory.insertMovement(movement, txn: txn);
  Future<void> rebuildQuantityCache(String storeId) => _inventory.rebuildQuantityCache(storeId);
  Future<void> batchInsertInventory(List<InventoryItem> items) => _inventory.batchInsertInventory(items);
  Future<List<InventoryItem>> getInventory(String? storeId, {String? category}) => _inventory.getInventory(storeId, category: category);
  Future<InventoryItem?> getInventoryItem(String id, {String? storeId}) => _inventory.getInventoryItem(id, storeId: storeId);
  Future<List<InventoryItem>> getAllInventoryDebug() => _inventory.getAllInventoryDebug();

  // --- CUSTOMER DELEGATIONS ---
  Future<void> insertCustomer(Customer customer) => _customers.insertCustomer(customer);
  Future<void> batchInsertCustomers(List<Customer> customers) => _customers.batchInsertCustomers(customers);
  Future<List<Customer>> getCustomers(String? storeId) => _customers.getCustomers(storeId);
  Future<Customer?> getCustomer(String id) => _customers.getCustomer(id);

  // --- REPORTING DELEGATIONS ---
  Future<int> getOrderCount(String? storeId) => _reporting.getOrderCount(storeId);
  Future<int> getOrderCountSince(String? storeId, DateTime since) => _reporting.getOrderCountSince(storeId, since);
  Future<int> getInventoryCount(String? storeId) => _reporting.getInventoryCount(storeId);
  Future<int> getCustomerCount(String? storeId) => _reporting.getCustomerCount(storeId);
  Future<int> getEmployeeCount(String? storeId) => _reporting.getEmployeeCount(storeId);
  Future<int> getFloorCount(String? storeId) => _reporting.getFloorCount(storeId);
  Future<int> getTableCount(String? storeId) => _reporting.getTableCount(storeId);
  Future<int> getSupplierCount(String? storeId) => _reporting.getSupplierCount(storeId);
  Future<int> getNoteCount(String? storeId) => _reporting.getNoteCount(storeId);
  Future<void> insertBusinessEvent(BusinessEvent event) => _reporting.insertBusinessEvent(event);
  Future<List<BusinessEvent>> getUnsyncedEvents(String? storeId) => _reporting.getUnsyncedEvents(storeId);
  Future<void> markEventAsSynced(String id) => _reporting.markEventAsSynced(id);
  Future<List<BusinessEvent>> getBusinessEvents(String storeId, {int limit = 50}) => _reporting.getBusinessEvents(storeId, limit: limit);
  Future<void> resetLocalDatabase() => _reporting.resetLocalDatabase();

  // --- STORE DELEGATIONS ---
  Future<void> insertStoreSettings(String storeId, Map<String, dynamic> data) => _store.insertStoreSettings(storeId, data);
  Future<Map<String, dynamic>?> getStoreSettings(String storeId) => _store.getStoreSettings(storeId);
  Future<void> insertFloor(String id, String storeId, Map<String, dynamic> data) => _store.insertFloor(id, storeId, data);
  Future<void> insertTable(String id, String storeId, Map<String, dynamic> data) => _store.insertTable(id, storeId, data);
  Future<void> insertSupplier(String id, String storeId, Map<String, dynamic> data) => _store.insertSupplier(id, storeId, data);
  Future<void> insertNote(String id, String storeId, Map<String, dynamic> data) => _store.insertNote(id, storeId, data);
  Future<void> insertEmployee(UserProfile emp) => _store.insertEmployee(emp);
  Future<void> deleteOfflineEntity(String table, String id) => _store.deleteOfflineEntity(table, id);
  Future<int> deleteOrphans(String table, String storeId, List<String> currentCloudIds) => _store.deleteOrphans(table, storeId, currentCloudIds);
  Future<List<Map<String, dynamic>>> getUnsyncedRows(String table) => _store.getUnsyncedRows(table);

  // --- SYNC DELEGATIONS ---
  Future<void> voidOrder(String id, {String? voidedBy, String? reason}) => _sync.voidOrder(id, voidedBy: voidedBy, reason: reason);
  Future<void> deleteInventory(String id) => _sync.deleteInventory(id);
  Future<void> deleteCustomer(String id) => _sync.deleteCustomer(id);
  Future<void> deleteOrder(String id) => _sync.deleteOrder(id);
  Future<void> deleteEmployee(String id) => _sync.deleteEmployee(id);
  Future<void> markAsPushed(String table, String id) => _sync.markAsPushed(table, id);
  Future<void> markAsConfirmed(String table, String id) => _sync.markAsConfirmed(table, id);
  Future<void> markAsSynced(String table, String id) => _sync.markAsSynced(table, id);
}
