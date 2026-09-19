import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/services/employee_repository.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/features/billing/application/checkout_orchestrator.dart';
import 'package:biztonic_pos/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:biztonic_pos/features/billing/domain/entities/order_entity.dart';
import 'package:biztonic_pos/features/inventory/domain/entities/inventory_movement.dart';
import 'package:biztonic_pos/models/user_profile.dart';
import 'package:biztonic_pos/models/customer.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_model.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_service.dart';
import 'package:biztonic_pos/sync/outbox/outbox_store.dart';
import 'package:biztonic_pos/sync/outbox/outbox_operation.dart';

void main() {
  late Directory tempDir;
  late Repository repository;
  late BillingRepositoryImpl billingRepository;
  late CheckoutOrchestrator orchestrator;
  late EntitlementService entitlementService;
  late OutboxStore outboxStore;
  late Box queueBox;
  late Box deadLetterBox;

  const testStoreId = 'STORE_INTEG_PUNE_01';
  const testUserId = 'USER_CASHIER_01';
  const testDeviceId = 'TERMINAL_POS_01';
  const testItemId = 'ITEM_PIZZA_BURGER';
  const testCustomerId = 'CUST_INTEG_01';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('integration_pos_test_');
    final dbPath = p.join(tempDir.path, 'integration_pos.db');
    DatabaseHelper.setDbName(dbPath);

    Hive.init(tempDir.path);
    await Hive.openBox('cache_orders');
    await Hive.openBox('cache_inventory');
    await Hive.openBox('cache_customers');
    await Hive.openBox('idempotency_keys_v1');
    await Hive.openBox(EntitlementService.boxName);
    queueBox = await Hive.openBox(OutboxStore.primaryQueueBox);
    deadLetterBox = await Hive.openBox(OutboxStore.deadLetterBox);

    repository = Repository();
    billingRepository = BillingRepositoryImpl(repository: repository);
    orchestrator = CheckoutOrchestrator(billingRepository: billingRepository);
    entitlementService = EntitlementService(repository: repository);
    outboxStore = OutboxStore(
      getQueueBox: () => queueBox,
      getFailedQueueBox: () => deadLetterBox,
      getRepository: () => repository,
    );
  });

  tearDown(() async {
    await Hive.close();
    await DatabaseHelper().close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Integration Tests: Complete Production POS Workflow (Steps 1 to 14)',
      () {
    test(
        'Executes end-to-end POS lifecycle: Login -> Store -> Entitlement -> POS -> Checkout -> Receipt -> Inventory -> KDS -> CRM -> Refund -> Offline Sale -> Reconnect -> Sync',
        () async {
      final db = await DatabaseHelper().database;

      // ─── STEP 1: Login ─────────────────────────────────────────
      final cashierProfile = UserProfile(
        uid: testUserId,
        email: 'cashier@bizpos.com',
        name: 'Rohan Joshi',
        role: 'Cashier',
        storeId: testStoreId,
        accessibleStoreIds: [testStoreId],
        permissions: {'canBilling': true, 'canDiscount': true},
        createdAt: DateTime.now(),
      );
      await repository.insertEmployee(cashierProfile);
      final loggedInUser =
          await EmployeeRepository().getEmployeeById(testUserId);
      expect(loggedInUser, isNotNull);
      expect(loggedInUser!.name, 'Rohan Joshi');

      // ─── STEP 2: Store Selection ───────────────────────────────
      expect(loggedInUser.accessibleStoreIds, contains(testStoreId));
      final activeStoreId = loggedInUser.storeId!;
      expect(activeStoreId, testStoreId);

      // ─── STEP 3: Subscription Restrictions ─────────────────────
      final standardEntitlement = StoreEntitlement.create(
        storeId: activeStoreId,
        plan: PlanTier.standard,
        status: PlanStatus.active,
        limits: EntitlementService.defaultPlanLimits[PlanTier.standard]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.standard]!,
        endDate: DateTime.now().add(const Duration(days: 90)),
      );
      entitlementService.registerInMemory(standardEntitlement);
      expect(
          entitlementService.canPerformAction('create_order',
              storeId: activeStoreId, currentCount: 0),
          isTrue);
      expect(
          entitlementService.isFeatureEnabled('billing',
              storeId: activeStoreId),
          isTrue);

      // ─── STEP 4: Customer Lookup / Creation ─────────────────────
      final customer = Customer(
        id: testCustomerId,
        storeId: activeStoreId,
        name: 'Suresh Kumar',
        email: 'suresh@example.com',
        phone: '+919876500000',
        joinDate: DateTime.now(),
        totalSpent: 1200.0,
        loyaltyPoints: 50,
        tier: 'Silver',
      );
      await repository.insertCustomer(customer);
      final fetchedCustomer = await repository.getCustomer(testCustomerId);
      expect(fetchedCustomer, isNotNull);
      expect(fetchedCustomer!.loyaltyPoints, 50);

      // ─── STEP 5: POS Catalog & Add Product ──────────────────────
      await db.insert('inventory', {
        'id': testItemId,
        'storeId': activeStoreId,
        'name': 'Paneer Pizza Supreme',
        'price': 300.0,
        'cost': 130.0,
        'quantity': 40,
        'category': 'Food',
        'status': 'ACTIVE',
        'trackStock': 1,
        'isDeleted': 0,
      });

      // Initial Stock Movement in Ledger (+40 units)
      await repository.movementRepo.insertMovement(InventoryMovement(
        id: 'MVT_INIT_SUPREME',
        itemId: testItemId,
        storeId: activeStoreId,
        type: MovementType.purchase,
        delta: 40,
        cost: 130.0,
        reason: 'Initial Batch',
        deviceId: testDeviceId,
        operationId: 'op_init_supreme',
        createdAt: DateTime.now(),
      ));

      final initialStock = (await repository.movementRepo
          .getAllQuantities(activeStoreId))[testItemId];
      expect(initialStock, 40);

      // ─── STEP 6: Checkout ──────────────────────────────────────
      final orderEntity = OrderEntity(
        id: 'ORD_INTEG_1001',
        storeId: activeStoreId,
        items: const [
          OrderItemEntity(
            itemId: testItemId,
            itemName: 'Paneer Pizza Supreme',
            price: 300.0,
            cost: 130.0,
            quantity: 2,
            cgst: 7.5,
            sgst: 7.5,
          ),
        ],
        subtotal: 600.0,
        discount: 0.0,
        cgst: 15.0,
        sgst: 15.0,
        total: 630.0,
        status: OrderStatus.completed,
        type: OrderType.dineIn,
        paymentMethod: PaymentMethod.cash,
        customerId: testCustomerId,
        customerName: 'Suresh Kumar',
        date: DateTime.now(),
      );

      final checkoutResult = await orchestrator.execute(CheckoutParams(
        order: orderEntity,
        activeStoreId: activeStoreId,
        deviceId: testDeviceId,
        idempotencyKey: 'IDEMP_INTEG_KEY_001',
        trackInventory: true,
        taxRate: 5.0,
      ));

      expect(checkoutResult.isSuccess, isTrue);
      expect(checkoutResult.order, isNotNull);

      // ─── STEP 7: Receipt Generation Data ───────────────────────
      final orderInDb = await repository.getOrder('ORD_INTEG_1001');
      expect(orderInDb, isNotNull);
      expect(orderInDb!.subtotal, 600.0);
      expect(orderInDb.cgst, 15.0);
      expect(orderInDb.sgst, 15.0);
      expect(orderInDb.total, 630.0);
      expect(orderInDb.paymentMethod, 'Cash');
      expect(orderInDb.businessDayId, isNotNull);

      // ─── STEP 8: Inventory Deduction Verification ──────────────
      // 40 initial - 2 sold = 38
      final postSaleStock = (await repository.movementRepo
          .getAllQuantities(activeStoreId))[testItemId];
      expect(postSaleStock, 38);

      // ─── STEP 9: KDS Kitchen Display Update ────────────────────
      // Kitchen marks order as Preparing -> Ready
      await db.update('orders', {'status': 'Preparing'},
          where: 'id = ?', whereArgs: ['ORD_INTEG_1001']);
      var kdsOrder = await repository.getOrder('ORD_INTEG_1001');
      expect(kdsOrder!.status, 'Preparing');

      await db.update('orders', {'status': 'Ready'},
          where: 'id = ?', whereArgs: ['ORD_INTEG_1001']);
      kdsOrder = await repository.getOrder('ORD_INTEG_1001');
      expect(kdsOrder!.status, 'Ready');

      // ─── STEP 10: Customer Loyalty Accrual ─────────────────────
      final earnedPoints = (orderInDb.subtotal / 100).floor() * 5; // 30 points
      final updatedCust = fetchedCustomer.copyWith(
        loyaltyPoints: fetchedCustomer.loyaltyPoints + earnedPoints,
        totalSpent: fetchedCustomer.totalSpent + orderInDb.total,
        visitCount: fetchedCustomer.visitCount + 1,
      );
      await repository.insertCustomer(updatedCust);
      final loyaltyUpdated = await repository.getCustomer(testCustomerId);
      expect(loyaltyUpdated!.loyaltyPoints, 80);
      expect(loyaltyUpdated.totalSpent, 1830.0);

      // ─── STEP 11: Refund of 1 Item ─────────────────────────────
      // Revert 1 pizza: stock becomes 38 + 1 = 39
      final refundMovement = InventoryMovement(
        id: 'MVT_REFUND_INTEG_1',
        itemId: testItemId,
        storeId: activeStoreId,
        type: MovementType.refund,
        delta: 1,
        orderId: 'ORD_INTEG_1001',
        unitCost: 130.0,
        reason: 'Customer Return',
        deviceId: testDeviceId,
        operationId: 'refund_op_integ_1',
        createdAt: DateTime.now(),
      );
      await repository.movementRepo.insertMovement(refundMovement);
      final postRefundStock = (await repository.movementRepo
          .getAllQuantities(activeStoreId))[testItemId];
      expect(postRefundStock, 39);

      // ─── STEP 12: Offline Sale Workflow ────────────────────────
      // Device goes offline: write local order and queue into durable outbox
      final offlineOrder = OrderEntity(
        id: 'ORD_OFFLINE_9001',
        storeId: activeStoreId,
        items: const [
          OrderItemEntity(
            itemId: testItemId,
            itemName: 'Paneer Pizza Supreme',
            price: 300.0,
            cost: 130.0,
            quantity: 1,
            cgst: 7.5,
            sgst: 7.5,
          ),
        ],
        subtotal: 300.0,
        cgst: 7.5,
        sgst: 7.5,
        total: 315.0,
        status: OrderStatus.completed,
        type: OrderType.takeaway,
        paymentMethod: PaymentMethod.cash,
        date: DateTime.now(),
      );

      final offlineResult = await orchestrator.execute(CheckoutParams(
        order: offlineOrder,
        activeStoreId: activeStoreId,
        deviceId: testDeviceId,
        idempotencyKey: 'IDEMP_OFFLINE_001',
        trackInventory: true,
        taxRate: 5.0,
      ));
      expect(offlineResult.isSuccess, isTrue);

      // Enqueue into durable outbox store for cloud sync
      final outboxOp = OutboxOperation(
        operationId: 'OP_SYNC_OFFLINE_9001',
        storeId: activeStoreId,
        userId: testUserId,
        deviceId: testDeviceId,
        collection: 'orders',
        entityId: 'ORD_OFFLINE_9001',
        operation: 'create',
        payload: OrderModel.fromEntity(offlineOrder).toSqlMap(),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        state: OutboxState.pending,
      );
      await outboxStore.enqueue(outboxOp);

      // Verify queued in outbox
      expect(queueBox.containsKey('OP_SYNC_OFFLINE_9001'), isTrue);

      // ─── STEP 13 & 14: Reconnect & Synchronization ─────────────
      // Background sync picks up pending operations
      final pendingOps = await outboxStore.getReadyOperations();
      expect(pendingOps.isNotEmpty, isTrue);
      expect(pendingOps.any((o) => o.operationId == 'OP_SYNC_OFFLINE_9001'),
          isTrue);

      // Process operation: pending -> inFlight -> pushed
      await outboxStore.markInFlight(['OP_SYNC_OFFLINE_9001']);
      var inFlightOp = queueBox.get('OP_SYNC_OFFLINE_9001');
      expect(inFlightOp['state'], 'IN_FLIGHT');

      await outboxStore.markPushed('OP_SYNC_OFFLINE_9001');
      var pushedOp = queueBox.get('OP_SYNC_OFFLINE_9001');
      expect(pushedOp['state'], 'PUSHED');
    });
  });
}
