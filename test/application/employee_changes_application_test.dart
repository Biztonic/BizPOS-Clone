import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/employee_repository.dart';
import 'package:biztonic_pos/models/user_profile.dart';

void main() {
  late Directory tempDir;
  late EmployeeRepository employeeRepo;

  const testStoreId = 'STORE_KOLKATA_01';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('app_employee_test_');
    final dbPath = p.join(tempDir.path, 'app_employee.db');
    DatabaseHelper.setDbName(dbPath);

    employeeRepo = EmployeeRepository();
  });

  tearDown(() async {
    await DatabaseHelper().close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Application Tests: Employee Management & Role Lifecycle', () {
    test('1. Insert employee with secure PIN hash and granular permissions',
        () async {
      final employee = UserProfile(
        uid: 'EMP_AMIT_001',
        email: 'amit.das@biztonic.pos',
        name: 'Amit Das',
        role: 'Cashier',
        storeId: testStoreId,
        employeeId: '1001',
        pinHash:
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', // SHA-256
        permissions: {
          'canVoid': false,
          'canDiscount': true,
          'canAccessKDS': true
        },
        hourlyRate: 150.0,
        monthlySalary: 25000.0,
        createdAt: DateTime.now(),
      );

      await employeeRepo.insertEmployee(employee);

      final fetched = await employeeRepo.getEmployeeById('EMP_AMIT_001');
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Amit Das');
      expect(fetched.role, 'Cashier');
      expect(fetched.employeeId, '1001');
      expect(fetched.pinHash,
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
      expect(fetched.permissions!['canDiscount'], isTrue);
      expect(fetched.permissions!['canVoid'], isFalse);

      // Verify pending sync status
      final pending = await employeeRepo.getPendingEmployees();
      expect(pending.any((e) => e['id'] == 'EMP_AMIT_001'), isTrue);
    });

    test('2. Role update modifies role and queues for sync', () async {
      final employee = UserProfile(
        uid: 'EMP_SUNIL_002',
        email: 'sunil@biztonic.pos',
        name: 'Sunil Roy',
        role: 'Cashier',
        storeId: testStoreId,
        employeeId: '1002',
        createdAt: DateTime.now(),
      );
      await employeeRepo.insertEmployee(employee);

      // Promote to Store Manager
      await employeeRepo.updateEmployeeRole('EMP_SUNIL_002', 'Store Manager');

      final updated = await employeeRepo.getEmployeeById('EMP_SUNIL_002');
      expect(updated, isNotNull);
      expect(updated!.role, 'Store Manager');

      final db = await DatabaseHelper().database;
      final rows = await db
          .query('employees', where: 'id = ?', whereArgs: ['EMP_SUNIL_002']);
      expect(rows.first['syncStatus'], 'PENDING');
    });

    test('3. Soft delete excludes employee from active store count and listing',
        () async {
      final emp = UserProfile(
        uid: 'EMP_TEMP_003',
        email: 'temp@biztonic.pos',
        name: 'Temp Trainee',
        role: 'Trainee',
        storeId: testStoreId,
        employeeId: '1003',
        createdAt: DateTime.now(),
      );
      await employeeRepo.insertEmployee(emp);

      expect(await employeeRepo.getEmployeeCount(testStoreId),
          greaterThanOrEqualTo(1));

      // Soft delete
      await employeeRepo.deleteEmployee('EMP_TEMP_003');

      final employees = await employeeRepo.getEmployeesByStore(testStoreId);
      expect(employees.any((e) => e.uid == 'EMP_TEMP_003'), isFalse);

      // Verify direct lookup also returns null (filtered by deletedAt IS NULL)
      final directLookup = await employeeRepo.getEmployeeById('EMP_TEMP_003');
      expect(directLookup, isNull);
    });

    test('4. Mark as synced transitions status to CONFIRMED with timestamp',
        () async {
      final emp = UserProfile(
        uid: 'EMP_SYNC_004',
        email: 'sync@biztonic.pos',
        name: 'Sync Employee',
        role: 'Waiter',
        storeId: testStoreId,
        employeeId: '1004',
        createdAt: DateTime.now(),
      );
      await employeeRepo.insertEmployee(emp);

      await employeeRepo.markAsSynced('EMP_SYNC_004');

      final pending = await employeeRepo.getPendingEmployees();
      expect(pending.any((e) => e['id'] == 'EMP_SYNC_004'), isFalse);

      final db = await DatabaseHelper().database;
      final rows = await db
          .query('employees', where: 'id = ?', whereArgs: ['EMP_SYNC_004']);
      expect(rows.first['syncStatus'], 'CONFIRMED');
      expect(rows.first['lastSyncedAt'], isNotNull);
    });

    test('5. Attendance tracking persists and queries check-in records',
        () async {
      final employee = UserProfile(
        uid: 'EMP_ATT_001',
        email: 'att@biztonic.pos',
        name: 'Attendance User',
        role: 'Cashier',
        storeId: testStoreId,
        createdAt: DateTime.now(),
      );
      await employeeRepo.insertEmployee(employee);

      final checkInTime = DateTime.now().toIso8601String();
      await employeeRepo.insertAttendance({
        'id': 'ATT_001',
        'employeeId': 'EMP_ATT_001',
        'storeId': testStoreId,
        'checkIn': checkInTime,
        'location': 'Front Desk POS',
        'syncStatus': 'PENDING',
      });

      final records = await employeeRepo.getAttendance('EMP_ATT_001');
      expect(records.length, 1);
      expect(records.first['employeeId'], 'EMP_ATT_001');
      expect(records.first['location'], 'Front Desk POS');
      expect(records.first['syncStatus'], 'PENDING');
    });
  });
}
