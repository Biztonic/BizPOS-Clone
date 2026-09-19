import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/models/inventory_item.dart';
import 'package:biztonic_pos/sync/outbox/outbox_operation.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_model.dart';
import 'package:biztonic_pos/services/recovery_service.dart';

void main() {
  group('Unit Tests: Cross-Layer Serialization & Data Integrity', () {
    test('1. OrderModel toMap and fromMap round-trip preserving all fields',
        () {
      final item = InventoryItem(
        id: 'ITEM_SER_1',
        name: 'Cappuccino',
        price: 180.0,
        cost: 60.0,
        quantity: 20,
        storeId: 'STORE_SER',
        category: 'Hot Coffee',
        status: 'In Stock',
        trackStock: true,
      );

      final originalOrder = OrderModel(
        id: 'ORD_SER_100',
        storeId: 'STORE_SER',
        items: [
          OrderItem(
              item: item,
              quantity: 2,
              note: 'Extra hot',
              cgst: 16.2,
              sgst: 16.2)
        ],
        total: 392.4,
        date: DateTime(2026, 3, 15, 10, 30),
        status: 'Completed',
        type: 'Dine-In',
        paymentMethod: 'UPI',
        customerName: 'Aarav Patel',
        customerPhone: '9876543210',
        businessDayId: 'BD_2026_03_15',
      );

      final map = originalOrder.toMap();
      expect(map['idempotencyKey'], 'ORD_SER_100');
      expect(map['storeId'], 'STORE_SER');
      expect(map['total'], 392.4);
      expect(map['businessDayId'], 'BD_2026_03_15');

      final reconstructed = OrderModel.fromMap(map, 'ORD_SER_100');
      expect(reconstructed.id, originalOrder.id);
      expect(reconstructed.storeId, originalOrder.storeId);
      expect(reconstructed.total, originalOrder.total);
      expect(reconstructed.items.length, 1);
      expect(reconstructed.items.first.item.name, 'Cappuccino');
      expect(reconstructed.items.first.quantity, 2);
      expect(reconstructed.items.first.note, 'Extra hot');
      expect(reconstructed.businessDayId, 'BD_2026_03_15');
    });

    test('2. InventoryItem toMap and toHiveMap serialization', () {
      final expiry = DateTime(2026, 12, 31);
      final item = InventoryItem(
        id: 'ITEM_HIVE_1',
        name: 'Sourdough Bread',
        price: 120.0,
        cost: 50.0,
        quantity: 15,
        storeId: 'STORE_BAKERY',
        category: 'Bakery',
        status: 'In Stock',
        trackStock: true,
        expiryDate: expiry,
      );

      // Firestore format uses Timestamp
      final firestoreMap = item.toMap();
      expect(firestoreMap['name'], 'Sourdough Bread');
      expect(firestoreMap['price'], 120.0);
      expect(firestoreMap['expiryDate'], isA<Timestamp>());

      // Hive format uses ISO string for local cross-platform web safety
      final hiveMap = item.toHiveMap();
      expect(hiveMap['name'], 'Sourdough Bread');
      expect(hiveMap['expiryDate'], isA<String>());
      expect(hiveMap['expiryDate'], expiry.toIso8601String());

      final fromHive = InventoryItem.fromMap(hiveMap, 'ITEM_HIVE_1');
      expect(fromHive.name, 'Sourdough Bread');
      expect(fromHive.price, 120.0);
    });

    test('3. OutboxOperation serialization between Hive Map and SQLite row',
        () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final op = OutboxOperation(
        operationId: 'OP_SER_999',
        storeId: 'STORE_OUTBOX',
        userId: 'USER_MGR',
        deviceId: 'POS_TERMINAL_2',
        collection: 'inventory_movements',
        entityId: 'MOV_SER_01',
        operation: 'create',
        payload: {
          'id': 'MOV_SER_01',
          'delta': -3,
          'itemId': 'ITEM_HIVE_1',
        },
        baseVersion: 2,
        newVersion: 3,
        createdAt: nowMs,
        state: OutboxState.pending,
        attemptCount: 1,
        nextRetryAt: nowMs + 30000,
      );

      // SQLite row representation
      final sqlRow = op.toSqlRow();
      expect(sqlRow['operationId'], 'OP_SER_999');
      expect(sqlRow['collection'], 'inventory_movements');
      expect(sqlRow['state'], 'PENDING');
      expect(sqlRow['payload'], isA<String>()); // JSON stringified

      final reconstructedFromDb = OutboxOperation.fromSqlRow(sqlRow);
      expect(reconstructedFromDb.operationId, op.operationId);
      expect(reconstructedFromDb.storeId, op.storeId);
      expect(reconstructedFromDb.collection, op.collection);
      expect(reconstructedFromDb.payload['delta'], -3);
      expect(reconstructedFromDb.state, OutboxState.pending);
    });

    test('4. StoreEntitlement toMap and fromMap serialization', () {
      final now = DateTime.now();
      final entitlement = StoreEntitlement(
        storeId: 'STORE_ENT_SER',
        plan: PlanTier.standard,
        status: PlanStatus.active,
        startDate: now.subtract(const Duration(days: 10)),
        endDate: now.add(const Duration(days: 20)),
        gracePeriodDays: 7,
        addons: const {'kds_management', 'delivery_integration'},
        features: const {'pos_billing', 'kds', 'analytics'},
        limits: const {'orders': 2500, 'staff': 5},
        version: 2,
        tamperHash: '',
        updatedAt: now,
      );

      final map = entitlement.toMap();
      expect(map['storeId'], 'STORE_ENT_SER');
      expect(map['plan'], 'Standard');
      expect(map['status'], 'ACTIVE');
      expect(map['limits']['orders'], 2500);

      final reconstructed = StoreEntitlement.fromMap(map);
      expect(reconstructed.storeId, entitlement.storeId);
      expect(reconstructed.plan, PlanTier.standard);
      expect(reconstructed.addons.contains('kds_management'), isTrue);
      expect(reconstructed.limits['orders'], 2500);
    });

    test('5. TransactionReconciliationReport serialization', () {
      final report = TransactionReconciliationReport(
        txId: 'TX_SER_777',
        storeId: 'STORE_SER',
        evaluatedAt: DateTime.now(),
        status: TransactionResolutionStatus.partiallyAppliedRecovered,
        orderExisted: true,
        itemsFound: 2,
        itemsExpected: 3,
        eventExisted: false,
        movementsFound: 1,
        movementsExpected: 3,
        counterIncremented: false,
        actionsTaken: const [
          'Synchronized complete order items list',
          'Inserted missing business event',
          'Inserted missing inventory movements',
        ],
      );

      final map = report.toMap();
      expect(map['txId'], 'TX_SER_777');
      expect(map['status'], 'PARTIALLY_APPLIED_RECOVERED');
      expect(map['itemsFound'], 2);
      expect(map['actionsTaken'].length, 3);
    });
  });
}
