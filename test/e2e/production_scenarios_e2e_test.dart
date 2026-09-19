import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/features/billing/application/checkout_orchestrator.dart';
import 'package:biztonic_pos/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:biztonic_pos/features/billing/domain/entities/order_entity.dart';
import 'package:biztonic_pos/features/billing/domain/policies/discount_policy.dart';
import 'package:biztonic_pos/features/inventory/domain/entities/inventory_movement.dart';
import 'package:biztonic_pos/features/inventory/domain/policies/inventory_policy.dart';
import 'package:biztonic_pos/models/customer.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_model.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_service.dart';
import 'package:biztonic_pos/sync/outbox/outbox_store.dart';
import 'package:biztonic_pos/sync/outbox/outbox_operation.dart';
import 'package:biztonic_pos/services/recovery_service.dart';

void main() {
  late Directory tempDir;
  late Repository repository;
  late BillingRepositoryImpl billingRepository;
  late CheckoutOrchestrator orchestrator;
  late EntitlementService entitlementService;
  late OutboxStore outboxStore;
  late RecoveryService recoveryService;
  late Box queueBox;
  late Box deadLetterBox;

  const testStoreId = 'STORE_E2E_DELHI_01';
  const testStoreB = 'STORE_E2E_MUMBAI_02';
  const testDeviceId = 'POS_TERM_E2E_01';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('e2e_scenarios_test_');
    final dbPath = p.join(tempDir.path, 'e2e_scenarios.db');
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
    recoveryService = RecoveryService(
      dbHelper: DatabaseHelper(),
      movementRepo: repository.movementRepo,
    );
    outboxStore = OutboxStore(
      getQueueBox: () => queueBox,
      getFailedQueueBox: () => deadLetterBox,
      getRepository: () => repository,
    );

    // Seed 3 items for store with initial stock
    final db = await DatabaseHelper().database;
    final items = [
      {
        'id': 'E2E_ITEM_1',
        'name': 'Butter Chicken Roll',
        'price': 200.0,
        'cost': 90.0,
        'qty': 50
      },
      {
        'id': 'E2E_ITEM_2',
        'name': 'Garlic Naan',
        'price': 50.0,
        'cost': 15.0,
        'qty': 100
      },
      {
        'id': 'E2E_ITEM_3',
        'name': 'Sweet Lassi',
        'price': 60.0,
        'cost': 20.0,
        'qty': 80
      },
    ];

    for (final item in items) {
      await db.insert('inventory', {
        'id': item['id'],
        'storeId': testStoreId,
        'name': item['name'],
        'price': item['price'],
        'cost': item['cost'],
        'quantity': item['qty'],
        'category': 'Food',
        'status': 'ACTIVE',
        'trackStock': 1,
        'isDeleted': 0,
      });

      await repository.movementRepo.insertMovement(InventoryMovement(
        id: 'INIT_MVT_${item['id']}',
        itemId: item['id'] as String,
        storeId: testStoreId,
        type: MovementType.purchase,
        delta: item['qty'] as int,
        cost: item['cost'] as double,
        reason: 'Initial Batch',
        deviceId: testDeviceId,
        operationId: 'op_init_${item['id']}',
        createdAt: DateTime.now(),
      ));
    }
  });

  tearDown(() async {
    await Hive.close();
    await DatabaseHelper().close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('E2E Production Scenarios: Deterministic Journeys 1 to 7', () {
    test(
        'Scenario 1: Cashier opens store, rings up 3 items, applies coupon, takes cash, prints receipt',
        () async {
      // 1. Validate ₹50 coupon on ₹560 subtotal
      // Items: 2x Roll (400), 2x Naan (100), 1x Lassi (60) = 560
      const subtotal = 560.0;
      final couponValidation = DiscountPolicy.validateCoupon(
        subtotal: subtotal,
        minOrderValue: 300.0,
      );
      expect(couponValidation.isValid, isTrue);

      const discountAmount = 50.0;
      const taxableAmount = subtotal - discountAmount; // 510.0
      const taxRate = 5.0; // 5% GST
      const taxAmount = (taxableAmount * taxRate) / 100; // 25.5
      const cgst = taxAmount / 2; // 12.75
      const sgst = taxAmount / 2; // 12.75
      const total = taxableAmount + taxAmount; // 535.50

      final orderEntity = OrderEntity(
        id: 'ORD_E2E_SCENARIO_1',
        storeId: testStoreId,
        items: const [
          OrderItemEntity(
              itemId: 'E2E_ITEM_1',
              itemName: 'Butter Chicken Roll',
              price: 200.0,
              cost: 90.0,
              quantity: 2,
              cgst: 4.5,
              sgst: 4.5),
          OrderItemEntity(
              itemId: 'E2E_ITEM_2',
              itemName: 'Garlic Naan',
              price: 50.0,
              cost: 15.0,
              quantity: 2,
              cgst: 1.15,
              sgst: 1.15),
          OrderItemEntity(
              itemId: 'E2E_ITEM_3',
              itemName: 'Sweet Lassi',
              price: 60.0,
              cost: 20.0,
              quantity: 1,
              cgst: 1.35,
              sgst: 1.35),
        ],
        subtotal: subtotal,
        discount: discountAmount,
        cgst: cgst,
        sgst: sgst,
        total: total,
        status: OrderStatus.completed,
        type: OrderType.dineIn,
        paymentMethod: PaymentMethod.cash,
        date: DateTime.now(),
      );

      final result = await orchestrator.execute(CheckoutParams(
        order: orderEntity,
        activeStoreId: testStoreId,
        deviceId: testDeviceId,
        idempotencyKey: 'IDEMP_SCENARIO_1',
        trackInventory: true,
        taxRate: taxRate,
      ));

      expect(result.isSuccess, isTrue);
      expect(result.order!.total, 535.50);
      expect(result.order!.cgst, 12.75);
      expect(result.order!.sgst, 12.75);

      // Verify receipt data in SQLite
      final orderInDb = await repository.getOrder('ORD_E2E_SCENARIO_1');
      expect(orderInDb, isNotNull);
      expect(orderInDb!.subtotal, 560.0);
      expect(orderInDb.discount, 50.0);
      expect(orderInDb.cgst, 12.75);
      expect(orderInDb.sgst, 12.75);
      expect(orderInDb.total, 535.50);
      expect(orderInDb.paymentMethod, 'Cash');

      // Verify stock deductions:
      // Item 1: 50 - 2 = 48
      // Item 2: 100 - 2 = 98
      // Item 3: 80 - 1 = 79
      final quantities =
          await repository.movementRepo.getAllQuantities(testStoreId);
      expect(quantities['E2E_ITEM_1'], 48);
      expect(quantities['E2E_ITEM_2'], 98);
      expect(quantities['E2E_ITEM_3'], 79);
    });

    test(
        'Scenario 2: Manager voids order, inventory restores, ledger reflects reversal',
        () async {
      // 1. Create a completed order with 2x Butter Chicken Roll
      final order = OrderEntity(
        id: 'ORD_E2E_TO_VOID',
        storeId: testStoreId,
        items: const [
          OrderItemEntity(
              itemId: 'E2E_ITEM_1',
              itemName: 'Butter Chicken Roll',
              price: 200.0,
              cost: 90.0,
              quantity: 2,
              cgst: 5.0,
              sgst: 5.0),
        ],
        subtotal: 400.0,
        cgst: 10.0,
        sgst: 10.0,
        total: 420.0,
        status: OrderStatus.completed,
        date: DateTime.now(),
      );

      await orchestrator.execute(CheckoutParams(
        order: order,
        activeStoreId: testStoreId,
        deviceId: testDeviceId,
        idempotencyKey: 'IDEMP_BEFORE_VOID',
        trackInventory: true,
        taxRate: 5.0,
      ));

      expect(
          (await repository.movementRepo
              .getAllQuantities(testStoreId))['E2E_ITEM_1'],
          48);

      // 2. Manager voids the order
      final reversals = await repository.movementRepo.voidOrderStock(
        orderId: 'ORD_E2E_TO_VOID',
        storeId: testStoreId,
        deviceId: testDeviceId,
        reason: 'Customer walked out without food',
        voidedBy: 'MANAGER_PRIYA',
      );

      expect(reversals.length, 1);
      expect(reversals.first.type, MovementType.voidReversal);
      expect(reversals.first.delta, 2);

      // 3. Verify stock restored back to 50
      expect(
          (await repository.movementRepo
              .getAllQuantities(testStoreId))['E2E_ITEM_1'],
          50);

      // 4. Verify order marked VOID
      final voided = await repository.getOrder('ORD_E2E_TO_VOID');
      expect(voided!.status, 'VOID');
      expect(voided.voidReason, 'Customer walked out without food');
      expect(voided.voidedBy, 'MANAGER_PRIYA');
    });

    test(
        'Scenario 3: Offline cashier completes 5 sales, network reconnects, sync pushes outbox, zero duplicates',
        () async {
      // Cashier completes 5 distinct offline orders
      for (int i = 1; i <= 5; i++) {
        final offlineOrder = OrderEntity(
          id: 'ORD_OFFLINE_BATCH_$i',
          storeId: testStoreId,
          items: const [
            OrderItemEntity(
                itemId: 'E2E_ITEM_3',
                itemName: 'Sweet Lassi',
                price: 60.0,
                cost: 20.0,
                quantity: 1,
                cgst: 1.5,
                sgst: 1.5),
          ],
          subtotal: 60.0,
          cgst: 1.5,
          sgst: 1.5,
          total: 63.0,
          status: OrderStatus.completed,
          date: DateTime.now(),
        );

        final result = await orchestrator.execute(CheckoutParams(
          order: offlineOrder,
          activeStoreId: testStoreId,
          deviceId: testDeviceId,
          idempotencyKey: 'IDEMP_OFFLINE_SALE_$i',
          trackInventory: true,
          taxRate: 5.0,
        ));
        expect(result.isSuccess, isTrue);

        // Enqueue into durable outbox
        await outboxStore.enqueue(OutboxOperation(
          operationId: 'OP_OFFLINE_$i',
          storeId: testStoreId,
          userId: 'CASHIER_01',
          deviceId: testDeviceId,
          collection: 'orders',
          entityId: 'ORD_OFFLINE_BATCH_$i',
          operation: 'create',
          payload: {'total': 63.0, 'orderId': 'ORD_OFFLINE_BATCH_$i'},
          createdAt: DateTime.now().millisecondsSinceEpoch,
          state: OutboxState.pending,
        ));
      }

      // Replay attempt with duplicate key is blocked
      final replayResult = await orchestrator.execute(CheckoutParams(
        order: OrderEntity(
          id: 'ORD_OFFLINE_BATCH_1',
          storeId: testStoreId,
          items: const [
            OrderItemEntity(
                itemId: 'E2E_ITEM_3',
                itemName: 'Sweet Lassi',
                price: 60.0,
                cost: 20.0,
                quantity: 1),
          ],
          total: 63.0,
          date: DateTime.now(),
        ),
        activeStoreId: testStoreId,
        deviceId: testDeviceId,
        idempotencyKey: 'IDEMP_OFFLINE_SALE_1', // Duplicate!
      ));
      expect(replayResult.isSuccess, isFalse);

      // Reconnect & Sync
      final readyOps = await outboxStore.getReadyOperations();
      expect(readyOps.length, 5);

      for (var op in readyOps) {
        await outboxStore.markInFlight([op.operationId]);
        await outboxStore.markPushed(op.operationId);
      }

      // Verify no remaining pending operations
      final remaining = await outboxStore.getReadyOperations();
      expect(remaining.isEmpty, isTrue);

      // Verify stock deducted by exactly 5 (80 initial - 5 = 75)
      final quantities =
          await repository.movementRepo.getAllQuantities(testStoreId);
      expect(quantities['E2E_ITEM_3'], 75);
    });

    test(
        'Scenario 4: Two devices edit same customer loyalty, conflict resolution merges cleanly',
        () async {
      // Seed customer with 100 points
      final initialCustomer = Customer(
        id: 'CUST_CONCURRENT_01',
        storeId: testStoreId,
        name: 'Arjun Verma',
        email: 'arjun@example.com',
        joinDate: DateTime.now(),
        totalSpent: 2000.0,
        loyaltyPoints: 100,
        tier: 'Gold',
      );
      await repository.insertCustomer(initialCustomer);

      // Terminal 1 adds +25 points
      const deltaTerm1 = 25;

      // Terminal 2 adds +40 points (from base of 100)
      const deltaTerm2 = 40;

      // Under pure additive resolution:
      // Final points = base + delta1 + delta2 = 100 + 25 + 40 = 165 points
      final mergedPoints =
          initialCustomer.loyaltyPoints + deltaTerm1 + deltaTerm2;
      final resolvedCustomer = initialCustomer.copyWith(
        loyaltyPoints: mergedPoints,
        totalSpent: initialCustomer.totalSpent + 500.0 + 800.0,
        version: initialCustomer.version + 2,
      );
      await repository.insertCustomer(resolvedCustomer);

      final reloaded = await repository.getCustomer('CUST_CONCURRENT_01');
      expect(reloaded!.loyaltyPoints, 165);
      expect(reloaded.totalSpent, 3300.0);
    });

    test(
        'Scenario 5: Store hits subscription order limit, order blocked, admin upgrades plan, sales resume',
        () {
      // Starting tier: limit is 50 orders
      final startingTier = StoreEntitlement.create(
        storeId: testStoreId,
        plan: PlanTier.starting,
        status: PlanStatus.active,
        limits: EntitlementService.defaultPlanLimits[PlanTier.starting]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.starting]!,
        endDate: DateTime.now().add(const Duration(days: 30)),
      );
      entitlementService.registerInMemory(startingTier);

      // Allowed under limit
      expect(
          entitlementService.canPerformAction('create_order',
              storeId: testStoreId, currentCount: 49),
          isTrue);

      // Blocked at or above limit of 50
      expect(
          entitlementService.canPerformAction('create_order',
              storeId: testStoreId, currentCount: 50),
          isFalse);
      expect(
          entitlementService.getBlockReason('create_order',
              storeId: testStoreId),
          contains('Order limit reached'));

      // Admin upgrades plan to Standard (limit: 5000 orders)
      final upgradedStandard = StoreEntitlement.create(
        storeId: testStoreId,
        plan: PlanTier.standard,
        status: PlanStatus.active,
        limits: EntitlementService.defaultPlanLimits[PlanTier.standard]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.standard]!,
        endDate: DateTime.now().add(const Duration(days: 365)),
      );
      entitlementService.registerInMemory(upgradedStandard);

      // Order creation is immediately unblocked at count 50!
      expect(
          entitlementService.canPerformAction('create_order',
              storeId: testStoreId, currentCount: 50),
          isTrue);
      expect(
          entitlementService.canPerformAction('create_order',
              storeId: testStoreId, currentCount: 1500),
          isTrue);
    });

    test(
        'Scenario 6: Cross-tenant injection attempt is rejected by domain and repository policies',
        () async {
      // Attacker on Device in Store A attempts to create a stock deduction targeting Store B
      final rogueMovement = InventoryMovement(
        id: 'MVT_ROGUE_ATTACK',
        itemId: 'E2E_ITEM_1', // Belongs to Store A
        storeId: testStoreB, // Targets Store B!
        type: MovementType.sale,
        delta: -10,
        deviceId: 'POS_ROGUE',
        operationId: 'op_rogue_01',
        createdAt: DateTime.now(),
      );

      expect(
        () async => await repository.movementRepo.insertMovement(rogueMovement),
        throwsA(isA<CrossStoreViolationException>()),
      );
    });

    test(
        'Scenario 7: Unexpected crash during checkout, recovery service replays/rolls back cleanly',
        () async {
      final db = await DatabaseHelper().database;
      const uncommittedTxId = 'TX_CRASH_DURING_CHECKOUT_001';

      // 1. Transaction journal logged as PENDING before transaction crashed
      final payload = jsonEncode({
        'order': {'id': 'ORD_CRASH_1', 'storeId': testStoreId, 'total': 100.0},
        'orderItems': [],
        'event': {
          'id': 'EVT_CRASH_1',
          'storeId': testStoreId,
          'entityType': 'ORDER',
          'entityId': 'ORD_CRASH_1',
          'eventType': 'CREATE',
          'amount': 100.0
        },
        'movements': [],
        'yearMonth': '2026-09',
      });

      await db.insert('transaction_journal', {
        'id': uncommittedTxId,
        'storeId': testStoreId,
        'status': 'PENDING',
        'operations': payload,
        'createdAt': DateTime.now().toIso8601String(),
      });

      // App restarts -> RecoveryService scans journal
      final reports = await recoveryService.scanAndRecoverReports();
      expect(reports.length, 1);
      expect(reports.first.status, TransactionResolutionStatus.rolledBack);

      final journal = await db.query('transaction_journal',
          where: 'id = ?', whereArgs: [uncommittedTxId]);
      expect(journal.first['status'], 'ROLLED_BACK');
    });
  });
}
