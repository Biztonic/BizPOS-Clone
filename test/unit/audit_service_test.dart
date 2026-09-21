import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/core/audit/audit_models.dart';
import 'package:biztonic_pos/core/audit/audit_service.dart';
import 'package:biztonic_pos/core/diagnostics/diagnostics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    AuditService.isTesting = true;
    DiagnosticsService.isTesting = true;
    tempDir = await Directory.systemTemp.createTemp('audit_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    final service = AuditService();
    await service.init();
    await service.clearLogs();
  });

  group('AuditService', () {
    test('records and queries all 8 mandated business audit actions', () async {
      final service = AuditService();
      service.configure(deviceId: 'dev_audit_test', storeId: 'store_audit_1');

      // 1. Refund
      await service.recordAction(
        storeId: 'store_audit_1',
        action: AuditActionType.refund,
        actorId: 'manager_1',
        actorRole: 'MANAGER',
        entityId: 'ord_ref_101',
        entityType: 'ORDER',
        reason: 'Customer requested refund for damaged box',
        previousState: {'total': 150.0, 'status': 'PAID'},
        newState: {'total': 0.0, 'status': 'REFUNDED'},
      );

      // 2. Void
      await service.recordAction(
        storeId: 'store_audit_1',
        action: AuditActionType.voidOrder,
        actorId: 'cashier_1',
        actorRole: 'CASHIER',
        entityId: 'ord_void_102',
        entityType: 'ORDER',
        reason: 'Duplicate checkout entry',
        previousState: {'status': 'OPEN'},
        newState: {'status': 'VOIDED'},
      );

      // 3. Price Change
      await service.recordAction(
        storeId: 'store_audit_1',
        action: AuditActionType.priceChange,
        actorId: 'admin_1',
        actorRole: 'ADMIN',
        entityId: 'item_milk_1',
        entityType: 'INVENTORY_ITEM',
        previousState: {'price': 40.0, 'name': 'Milk 1L'},
        newState: {'price': 45.0, 'name': 'Milk 1L'},
      );

      // 4. Stock Adjustment
      await service.recordAction(
        storeId: 'store_audit_1',
        action: AuditActionType.stockAdjustment,
        actorId: 'warehouse_1',
        actorRole: 'WAREHOUSE',
        entityId: 'item_milk_1',
        entityType: 'INVENTORY_MOVEMENT',
        previousState: {'stock': 100},
        newState: {'stock': 95, 'delta': -5},
        reason: 'Expired stock write-off',
      );

      // 5. Employee Permission Change
      await service.recordAction(
        storeId: 'store_audit_1',
        action: AuditActionType.permissionChange,
        actorId: 'superadmin',
        actorRole: 'OWNER',
        entityId: 'emp_raj_1',
        entityType: 'EMPLOYEE_ROLE',
        previousState: {'role': 'cashier'},
        newState: {'role': 'manager'},
      );

      // 6. Subscription Change
      await service.recordAction(
        storeId: 'store_audit_1',
        action: AuditActionType.subscriptionChange,
        actorId: 'billing_service',
        actorRole: 'SYSTEM',
        entityId: 'sub_pro_tier',
        entityType: 'SUBSCRIPTION',
        previousState: {'tier': 'FREE'},
        newState: {'tier': 'PRO'},
      );

      // 7. Store Configuration Change
      await service.recordAction(
        storeId: 'store_audit_1',
        action: AuditActionType.storeConfigChange,
        actorId: 'owner_1',
        actorRole: 'OWNER',
        entityId: 'cfg_tax_rate',
        entityType: 'STORE_SETTINGS',
        previousState: {'taxRate': 0.05},
        newState: {'taxRate': 0.12},
      );

      // 8. Admin Operation
      await service.recordAction(
        storeId: 'store_audit_1',
        action: AuditActionType.adminOperation,
        actorId: 'admin_root',
        actorRole: 'ADMIN',
        entityId: 'backup_op_01',
        entityType: 'SYSTEM_MAINTENANCE',
        reason: 'Database schema sanity verification',
      );

      final records =
          service.getRecentAuditRecords(storeId: 'store_audit_1', limit: 100);
      expect(records.length, equals(8));

      // Filter by action type: refunds only
      final refunds = service.getRecentAuditRecords(
        storeId: 'store_audit_1',
        action: AuditActionType.refund,
      );
      expect(refunds.length, equals(1));
      expect(refunds.first.entityId, equals('ord_ref_101'));
      expect(refunds.first.action, equals(AuditActionType.refund));
      expect(refunds.first.reason, contains('damaged box'));

      // Filter by price changes only
      final priceChanges = service.getRecentAuditRecords(
        action: AuditActionType.priceChange,
      );
      expect(priceChanges.length, equals(1));
      expect(priceChanges.first.entityId, equals('item_milk_1'));
      expect(priceChanges.first.previousState!['price'], equals(40.0));
      expect(priceChanges.first.newState!['price'], equals(45.0));
    });

    test('sanitizes sensitive data within previousState and newState',
        () async {
      final service = AuditService();

      await service.recordAction(
        storeId: 'store_1',
        action: AuditActionType.adminOperation,
        actorId: 'admin_sec',
        entityId: 'emp_sec_1',
        entityType: 'SECURITY_RECORD',
        previousState: {
          'user_pin': '1111',
          'password': 'oldPassword123',
          'email': 'john.doe@test.com',
        },
        newState: {
          'user_pin': '2222',
          'password': 'newPassword456',
          'email': 'john.doe@test.com',
        },
      );

      final records = service.getRecentAuditRecords(storeId: 'store_1');
      expect(records.length, equals(1));

      final rec = records.first;
      expect(rec.previousState!['user_pin'], equals('[REDACTED]'));
      expect(rec.previousState!['password'], equals('[REDACTED]'));
      expect(rec.previousState!['email'], equals('jo***@test.com'));

      expect(rec.newState!['user_pin'], equals('[REDACTED]'));
      expect(rec.newState!['password'], equals('[REDACTED]'));
    });

    test('exports audit trail as sanitized JSON-serializable list', () async {
      final service = AuditService();

      await service.recordAction(
        storeId: 'store_exp',
        action: AuditActionType.refund,
        actorId: 'mgr',
        entityId: 'ord_99',
        entityType: 'ORDER',
      );

      final exported = await service.exportAuditLog(storeId: 'store_exp');
      expect(exported.length, equals(1));
      expect(exported.first['action'], equals('REFUND'));
      expect(exported.first['entityId'], equals('ord_99'));
    });
  });
}
