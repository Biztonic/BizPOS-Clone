import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/features/inventory/domain/entities/inventory_entity.dart';
import 'package:biztonic_pos/features/inventory/domain/repositories/inventory_repository_interface.dart';
import 'package:biztonic_pos/features/inventory/application/inventory_orchestrator.dart';
import 'package:biztonic_pos/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:biztonic_pos/features/billing/domain/entities/order_entity.dart';
import 'package:biztonic_pos/features/billing/application/checkout_orchestrator.dart';
import 'package:biztonic_pos/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:biztonic_pos/features/store/domain/entities/store.dart';
import 'package:biztonic_pos/features/store/domain/entities/settings.dart';
import 'package:biztonic_pos/providers/store_provider.dart';
import 'package:biztonic_pos/services/sync_service.dart';
import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';

/// In-memory mock repository implementing InventoryRepositoryInterface
class MockInventoryRepository implements InventoryRepositoryInterface {
  final Map<String, InventoryEntity> storage = {};

  @override
  Future<InventoryResult<void>> insertItem(InventoryEntity item) async {
    storage[item.id] = item;
    return InventoryResult.success(null);
  }

  @override
  Future<InventoryResult<InventoryEntity>> getItem(String itemId,
      {String? storeId}) async {
    final item = storage[itemId];
    if (item == null) return InventoryResult.failure('Item not found');
    return InventoryResult.success(item);
  }

  @override
  Future<InventoryResult<List<InventoryEntity>>> getItems(String? storeId,
      {String? category}) async {
    final items = storage.values.where((e) {
      if (storeId != null && e.storeId != storeId) return false;
      if (category != null && category != 'All' && e.category != category) {
        return false;
      }
      return true;
    }).toList();
    return InventoryResult.success(items);
  }

  @override
  Future<InventoryResult<void>> deleteItem(String itemId) async {
    storage.remove(itemId);
    return InventoryResult.success(null);
  }

  @override
  Future<InventoryResult<void>> batchInsertItems(
      List<InventoryEntity> items) async {
    for (var i in items) {
      storage[i.id] = i;
    }
    return InventoryResult.success(null);
  }

  @override
  Future<InventoryResult<int>> getStockQuantity(String itemId,
      {String? storeId}) async {
    final item = storage[itemId];
    return InventoryResult.success(item?.quantity ?? 0);
  }

  @override
  Future<InventoryResult<int>> getPendingDelta(String itemId,
      {String? storeId}) async {
    return InventoryResult.success(0);
  }

  @override
  Future<InventoryResult<void>> rebuildQuantityCache(String storeId) async {
    return InventoryResult.success(null);
  }

  @override
  Future<InventoryResult<List<String>>> getCategories(String? storeId) async {
    final categories = storage.values.map((e) => e.category).toSet().toList();
    return InventoryResult.success(categories);
  }

  @override
  Future<InventoryResult<InventoryStats>> getInventoryStats(
      String? storeId) async {
    final items = storage.values.toList();
    return InventoryResult.success(InventoryStats(
      totalItems: items.length,
      lowStockItems: items.where((e) => e.quantity <= 5).length,
      outOfStockItems: items.where((e) => e.quantity <= 0).length,
      totalCostValue: items.fold(0, (sum, e) => sum + (e.cost * e.quantity)),
      totalRetailValue:
          items.fold(0, (sum, e) => sum + (e.price * e.quantity)),
      categoriesCount: items.map((e) => e.category).toSet().length,
    ));
  }
}

class FakeStoreProvider extends StoreProvider {
  Store? _fakeActiveStore;

  FakeStoreProvider() : super(SyncService());

  @override
  Store? get activeStore => _fakeActiveStore;

  void setActiveStore(Store store) {
    _fakeActiveStore = store;
    notifyListeners();
  }
}

Store createTestStore() {
  return Store(
    id: 'STORE_01',
    name: 'Main Store',
    owner: 'Owner',
    ownerEmail: 'owner@test.com',
    status: 'ACTIVE',
    storeType: 'Retail',
    trackInventory: true,
    receipt: ReceiptSettings(),
    payment: PaymentSettings(),
    kds: KdsSettings(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    tempDir = Directory.systemTemp.createTempSync('inventory_test_');
    final dbPath = p.join(tempDir.path, 'inventory_test.db');
    DatabaseHelper.setDbName(dbPath);

    Hive.init(tempDir.path);
    await Hive.openBox('cache_inventory');
    await Hive.openBox('cache_orders');
    await Hive.openBox('idempotency_keys_v1');
  });

  tearDownAll(() async {
    await DatabaseHelper().close();
    await Hive.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Inventory Stock Persistence Across Billing & Re-login', () {
    test('1. OrderCreatedEvent deducts stock and persists to repository',
        () async {
      final mockRepo = MockInventoryRepository();
      final storeProvider = FakeStoreProvider();
      storeProvider.setActiveStore(createTestStore());

      // Seed initial item with 20 quantity
      final initialItem = InventoryEntity(
        id: 'ITEM_01',
        storeId: 'STORE_01',
        name: 'Espresso',
        category: 'Beverages',
        price: 100.0,
        cost: 40.0,
        quantity: 20,
        trackStock: true,
      );
      await mockRepo.insertItem(initialItem);

      final orchestrator = InventoryOrchestrator(repository: mockRepo);
      final inventoryProvider = InventoryProvider(
        repository: mockRepo,
        orchestrator: orchestrator,
        storeProvider: storeProvider,
        syncService: SyncService(),
      );

      // Verify initial load
      await inventoryProvider.loadInventory();
      expect(inventoryProvider.getItemStock('ITEM_01'), equals(20));

      // Create an order with 3 units of ITEM_01
      final order = OrderEntity(
        id: 'ORD_01',
        storeId: 'STORE_01',
        items: const [
          OrderItemEntity(
            itemId: 'ITEM_01',
            itemName: 'Espresso',
            price: 100.0,
            quantity: 3,
            cgst: 0.0,
            sgst: 0.0,
            cost: 40.0,
          ),
        ],
        subtotal: 300.0,
        discount: 0.0,
        cgst: 0.0,
        sgst: 0.0,
        total: 300.0,
        status: OrderStatus.completed,
        type: OrderType.takeaway,
        paymentMethod: PaymentMethod.cash,
        date: DateTime.now(),
      );

      // Fire OrderCreatedEvent (simulates POS checkout completion)
      EventBus.instance.fire(OrderCreatedEvent(
        order: order,
        storeId: 'STORE_01',
        event: null,
        movements: [],
      ));

      // Allow event loop to process
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. In-memory stock must be 17
      expect(inventoryProvider.getItemStock('ITEM_01'), equals(17));

      // 2. Authoritative repository storage MUST also be 17 (PERSISTED!)
      final repoCheck = await mockRepo.getItem('ITEM_01');
      expect(repoCheck.isSuccess, isTrue);
      expect(repoCheck.data?.quantity, equals(17));

      // 3. Simulate Logout & Login (New session loading inventory from repository)
      final newInventoryProvider = InventoryProvider(
        repository: mockRepo,
        orchestrator: orchestrator,
        storeProvider: storeProvider,
        syncService: SyncService(),
      );
      await newInventoryProvider.loadInventory();

      // Crucial verification: Stock remains 17 after re-login!
      expect(newInventoryProvider.getItemStock('ITEM_01'), equals(17));
    });

    test('2. OrderRefundedEvent restores stock and persists to repository',
        () async {
      final mockRepo = MockInventoryRepository();
      final storeProvider = FakeStoreProvider();
      storeProvider.setActiveStore(createTestStore());

      // Seed item with 17 quantity
      final item = InventoryEntity(
        id: 'ITEM_01',
        storeId: 'STORE_01',
        name: 'Espresso',
        category: 'Beverages',
        price: 100.0,
        cost: 40.0,
        quantity: 17,
        trackStock: true,
      );
      await mockRepo.insertItem(item);

      final orchestrator = InventoryOrchestrator(repository: mockRepo);
      final inventoryProvider = InventoryProvider(
        repository: mockRepo,
        orchestrator: orchestrator,
        storeProvider: storeProvider,
        syncService: SyncService(),
      );
      await inventoryProvider.loadInventory();

      // Refund 1 unit
      EventBus.instance.fire(OrderRefundedEvent(
        orderId: 'ORD_01',
        storeId: 'STORE_01',
        refundAmount: 100.0,
        items: const [
          OrderItemEntity(
            itemId: 'ITEM_01',
            itemName: 'Espresso',
            price: 100.0,
            quantity: 1,
            cgst: 0.0,
            sgst: 0.0,
            cost: 40.0,
          ),
        ],
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // Stock should now be 18
      expect(inventoryProvider.getItemStock('ITEM_01'), equals(18));
      final repoItem = await mockRepo.getItem('ITEM_01');
      expect(repoItem.data?.quantity, equals(18));
    });

    test(
        '3. CheckoutOrchestrator decrements stock in cache_inventory Hive box',
        () async {
      final db = await DatabaseHelper().database;
      await db.insert('inventory', {
        'id': 'ITEM_PIZZA_01',
        'storeId': 'STORE_01',
        'name': 'Margherita Pizza',
        'price': 250.0,
        'cost': 100.0,
        'quantity': 25,
        'category': 'Food',
        'status': 'ACTIVE',
        'trackStock': 1,
        'isDeleted': 0,
      });

      final box = Hive.box('cache_inventory');
      await box.put('ITEM_PIZZA_01', {
        'id': 'ITEM_PIZZA_01',
        'name': 'Margherita Pizza',
        'storeId': 'STORE_01',
        'quantity': 25,
        'price': 250.0,
        'cost': 100.0,
        'trackStock': true,
      });

      final billingRepo = BillingRepositoryImpl();
      final checkoutOrchestrator =
          CheckoutOrchestrator(billingRepository: billingRepo);

      final order = OrderEntity(
        id: 'ORD_PIZZA_01',
        storeId: 'STORE_01',
        items: const [
          OrderItemEntity(
            itemId: 'ITEM_PIZZA_01',
            itemName: 'Margherita Pizza',
            price: 250.0,
            quantity: 5,
            cgst: 0.0,
            sgst: 0.0,
            cost: 100.0,
          ),
        ],
        subtotal: 1250.0,
        discount: 0.0,
        cgst: 0.0,
        sgst: 0.0,
        total: 1250.0,
        status: OrderStatus.completed,
        type: OrderType.takeaway,
        paymentMethod: PaymentMethod.card,
        date: DateTime.now(),
      );

      final result = await checkoutOrchestrator.execute(CheckoutParams(
        order: order,
        activeStoreId: 'STORE_01',
        deviceId: 'DEVICE_01',
        idempotencyKey: 'idemp_pizza_01',
        trackInventory: true,
      ));

      expect(result.isSuccess, isTrue);

      // Verify Hive cache has 25 - 5 = 20
      final cachedItem = box.get('ITEM_PIZZA_01') as Map;
      expect(cachedItem['quantity'], equals(20));
    });
  });
}
