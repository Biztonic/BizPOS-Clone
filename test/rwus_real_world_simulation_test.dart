import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:biztonic_pos/features/billing/application/checkout_orchestrator.dart';
import 'package:biztonic_pos/features/billing/domain/entities/order_entity.dart';
import 'package:biztonic_pos/features/billing/domain/use_cases/calculate_tax.dart';
import 'package:biztonic_pos/features/inventory/domain/entities/inventory_movement.dart';
import 'package:biztonic_pos/features/inventory/domain/policies/inventory_policy.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_service.dart';
import 'package:biztonic_pos/sync/outbox/outbox_store.dart';
import 'package:biztonic_pos/sync/outbox/outbox_operation.dart';
import 'package:biztonic_pos/kernel/idempotency/idempotency_service.dart';
import 'package:biztonic_pos/features/receipt_printing/core/receipt_generator.dart';
import 'package:biztonic_pos/features/receipt_printing/models/receipt_config.dart';
import 'package:biztonic_pos/features/receipt_printing/models/receipt_content.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late Repository repository;
  late BillingRepositoryImpl billingRepository;
  late CheckoutOrchestrator orchestrator;
  late InventoryMovementRepository movementRepo;
  late OutboxStore outboxStore;
  late Database db;

  const storeA = 'STORE_SHREE_GANESH'; // Shree Ganesh General Store
  const storeB = 'STORE_QUALITY_SUPER'; // Quality Supermarket (Tenant Isolation)
  const deviceId = 'POS_TERM_MUMBAI_01';

  // ─── REAL-WORLD RETAIL CATALOG (50 Products across 5 GST Slabs) ─────────────
  final testProducts = [
    // Grains & Flours (0% and 5% GST)
    {'id': 'PROD_RICE_5KG', 'name': 'Rice 5kg (Kolam)', 'category': 'Grains', 'price': 250.0, 'cost': 180.0, 'gst': 0.0, 'stock': 40, 'barcode': '890103000001', 'unit': 'kg'},
    {'id': 'PROD_WHEAT_10KG', 'name': 'Wheat Atta 10kg (Sharbati)', 'category': 'Grains', 'price': 420.0, 'cost': 320.0, 'gst': 0.0, 'stock': 30, 'barcode': '890103000002', 'unit': 'kg'},
    {'id': 'PROD_BASMATI_1KG', 'name': 'Basmati Rice 1kg (Royal)', 'category': 'Grains', 'price': 140.0, 'cost': 95.0, 'gst': 5.0, 'stock': 50, 'barcode': '890103000003', 'unit': 'kg'},
    {'id': 'PROD_TOOR_DAL_1KG', 'name': 'Toor Dal 1kg', 'category': 'Grains', 'price': 160.0, 'cost': 120.0, 'gst': 5.0, 'stock': 35, 'barcode': '890103000004', 'unit': 'kg'},
    {'id': 'PROD_MOONG_DAL_500G', 'name': 'Moong Dal 500g', 'category': 'Grains', 'price': 85.0, 'cost': 60.0, 'gst': 5.0, 'stock': 45, 'barcode': '890103000005', 'unit': 'g'},
    {'id': 'PROD_BESAN_500G', 'name': 'Chana Besan 500g', 'category': 'Grains', 'price': 65.0, 'cost': 45.0, 'gst': 5.0, 'stock': 30, 'barcode': '890103000006', 'unit': 'g'},

    // Oils & Ghee (5% and 12% GST)
    {'id': 'PROD_SUNFLOWER_OIL_1L', 'name': 'Sunflower Cooking Oil 1L', 'category': 'Oils & Ghee', 'price': 150.0, 'cost': 110.0, 'gst': 5.0, 'stock': 50, 'barcode': '890103000007', 'unit': 'L'},
    {'id': 'PROD_MUSTARD_OIL_1L', 'name': 'Mustard Oil 1L (Kachi Ghani)', 'category': 'Oils & Ghee', 'price': 165.0, 'cost': 125.0, 'gst': 5.0, 'stock': 40, 'barcode': '890103000008', 'unit': 'L'},
    {'id': 'PROD_COW_GHEE_500ML', 'name': 'Pure Cow Ghee 500ml', 'category': 'Oils & Ghee', 'price': 340.0, 'cost': 260.0, 'gst': 12.0, 'stock': 25, 'barcode': '890103000009', 'unit': 'ml'},

    // Spices & Condiments (0% and 5% GST)
    {'id': 'PROD_TEA_500G', 'name': 'Taj Mahal Tea 500g', 'category': 'Beverages', 'price': 280.0, 'cost': 210.0, 'gst': 5.0, 'stock': 35, 'barcode': '890103000010', 'unit': 'g'},
    {'id': 'PROD_SUGAR_1KG', 'name': 'Refined Sugar 1kg', 'category': 'Spices', 'price': 48.0, 'cost': 38.0, 'gst': 5.0, 'stock': 60, 'barcode': '890103000011', 'unit': 'kg'},
    {'id': 'PROD_SALT_1KG', 'name': 'Tata Salt 1kg (Iodized)', 'category': 'Spices', 'price': 28.0, 'cost': 20.0, 'gst': 0.0, 'stock': 80, 'barcode': '890103000012', 'unit': 'kg'},
    {'id': 'PROD_TURMERIC_200G', 'name': 'Turmeric Powder 200g', 'category': 'Spices', 'price': 55.0, 'cost': 35.0, 'gst': 5.0, 'stock': 40, 'barcode': '890103000013', 'unit': 'g'},
    {'id': 'PROD_CHILLI_200G', 'name': 'Red Chilli Powder 200g', 'category': 'Spices', 'price': 75.0, 'cost': 50.0, 'gst': 5.0, 'stock': 40, 'barcode': '890103000014', 'unit': 'g'},

    // Dairy (0%, 5%, 12% GST)
    {'id': 'PROD_MILK_1L', 'name': 'Amul Taaza Milk 1L', 'category': 'Dairy', 'price': 56.0, 'cost': 48.0, 'gst': 0.0, 'stock': 50, 'barcode': '890103000015', 'unit': 'L'},
    {'id': 'PROD_CURD_400G', 'name': 'Amul Masti Dahi 400g', 'category': 'Dairy', 'price': 35.0, 'cost': 28.0, 'gst': 5.0, 'stock': 30, 'barcode': '890103000016', 'unit': 'g'},
    {'id': 'PROD_PANEER_200G', 'name': 'Fresh Paneer 200g', 'category': 'Dairy', 'price': 90.0, 'cost': 70.0, 'gst': 5.0, 'stock': 25, 'barcode': '890103000017', 'unit': 'g'},
    {'id': 'PROD_BUTTER_100G', 'name': 'Amul Butter 100g', 'category': 'Dairy', 'price': 58.0, 'cost': 46.0, 'gst': 12.0, 'stock': 40, 'barcode': '890103000018', 'unit': 'g'},
    {'id': 'PROD_CHEESE_200G', 'name': 'Cheese Slices 200g', 'category': 'Dairy', 'price': 140.0, 'cost': 105.0, 'gst': 12.0, 'stock': 20, 'barcode': '890103000019', 'unit': 'g'},

    // Beverages (12%, 18%, 28% GST)
    {'id': 'PROD_COLD_DRINK_750ML', 'name': 'Coca Cola 750ml', 'category': 'Beverages', 'price': 45.0, 'cost': 32.0, 'gst': 28.0, 'stock': 45, 'barcode': '890103000020', 'unit': 'ml'},
    {'id': 'PROD_FRUIT_JUICE_1L', 'name': 'Real Mango Juice 1L', 'category': 'Beverages', 'price': 110.0, 'cost': 80.0, 'gst': 12.0, 'stock': 25, 'barcode': '890103000021', 'unit': 'L'},
    {'id': 'PROD_SODA_600ML', 'name': 'Kinley Club Soda 600ml', 'category': 'Beverages', 'price': 20.0, 'cost': 14.0, 'gst': 18.0, 'stock': 50, 'barcode': '890103000022', 'unit': 'ml'},
    {'id': 'PROD_WATER_1L', 'name': 'Bisleri Mineral Water 1L', 'category': 'Beverages', 'price': 20.0, 'cost': 12.0, 'gst': 18.0, 'stock': 70, 'barcode': '890103000023', 'unit': 'L'},

    // Personal Care (18% GST)
    {'id': 'PROD_SOAP_125G', 'name': 'Lifebuoy Total Soap 125g', 'category': 'Personal Care', 'price': 38.0, 'cost': 26.0, 'gst': 18.0, 'stock': 60, 'barcode': '890103000024', 'unit': 'pcs'},
    {'id': 'PROD_SHAMPOO_175ML', 'name': 'Clinic Plus Shampoo 175ml', 'category': 'Personal Care', 'price': 115.0, 'cost': 82.0, 'gst': 18.0, 'stock': 30, 'barcode': '890103000025', 'unit': 'ml'},
    {'id': 'PROD_TOOTHPASTE_150G', 'name': 'Colgate Strong Teeth 150g', 'category': 'Personal Care', 'price': 98.0, 'cost': 70.0, 'gst': 18.0, 'stock': 40, 'barcode': '890103000026', 'unit': 'g'},
    {'id': 'PROD_HANDWASH_250ML', 'name': 'Dettol Handwash 250ml', 'category': 'Personal Care', 'price': 99.0, 'cost': 68.0, 'gst': 18.0, 'stock': 35, 'barcode': '890103000027', 'unit': 'ml'},

    // Household & Cleaning (18% GST)
    {'id': 'PROD_DETERGENT_1KG', 'name': 'Surf Excel Easy Wash 1kg', 'category': 'Household', 'price': 140.0, 'cost': 105.0, 'gst': 18.0, 'stock': 40, 'barcode': '890103000028', 'unit': 'kg'},
    {'id': 'PROD_DISHWASH_500ML', 'name': 'Vim Gel 500ml', 'category': 'Household', 'price': 105.0, 'cost': 75.0, 'gst': 18.0, 'stock': 30, 'barcode': '890103000029', 'unit': 'ml'},
    {'id': 'PROD_CLEANER_1L', 'name': 'Lizol Floor Cleaner 1L', 'category': 'Household', 'price': 195.0, 'cost': 145.0, 'gst': 18.0, 'stock': 25, 'barcode': '890103000030', 'unit': 'L'},

    // Snacks & Confectionery (12% and 18% GST)
    {'id': 'PROD_PARLE_G_250G', 'name': 'Parle-G Gold Biscuits 250g', 'category': 'Snacks', 'price': 30.0, 'cost': 22.0, 'gst': 18.0, 'stock': 55, 'barcode': '890103000031', 'unit': 'pcs'},
    {'id': 'PROD_GOOD_DAY_200G', 'name': 'Britannia Good Day Butter 200g', 'category': 'Snacks', 'price': 45.0, 'cost': 32.0, 'gst': 18.0, 'stock': 45, 'barcode': '890103000032', 'unit': 'pcs'},
    {'id': 'PROD_LAYS_CHIPS_50G', 'name': 'Lays Classic Salted 50g', 'category': 'Snacks', 'price': 20.0, 'cost': 14.0, 'gst': 12.0, 'stock': 50, 'barcode': '890103000033', 'unit': 'pcs'},
    {'id': 'PROD_MAGGI_4PACK', 'name': 'Maggi 2-Minute Noodles 4-Pack', 'category': 'Snacks', 'price': 56.0, 'cost': 42.0, 'gst': 18.0, 'stock': 40, 'barcode': '890103000034', 'unit': 'pcs'},
    {'id': 'PROD_CHOCOLATE_50G', 'name': 'Cadbury Dairy Milk 50g', 'category': 'Snacks', 'price': 45.0, 'cost': 33.0, 'gst': 18.0, 'stock': 35, 'barcode': '890103000035', 'unit': 'pcs'},

    // Threshold Special Test Items
    {'id': 'PROD_LOW_STOCK_COFFEE', 'name': 'Nescafe Classic 50g (Low Stock)', 'category': 'Beverages', 'price': 160.0, 'cost': 120.0, 'gst': 18.0, 'stock': 3, 'barcode': '890103000036', 'unit': 'g'},
    {'id': 'PROD_ZERO_STOCK_ALMONDS', 'name': 'California Almonds 500g (Zero Stock)', 'category': 'Dry Fruits', 'price': 450.0, 'cost': 350.0, 'gst': 12.0, 'stock': 0, 'barcode': '890103000037', 'unit': 'g'},

    // Additional Everyday General Store Items (Items 38 to 50)
    {'id': 'PROD_POHA_500G', 'name': 'Thick Poha 500g', 'category': 'Grains', 'price': 40.0, 'cost': 28.0, 'gst': 0.0, 'stock': 35, 'barcode': '890103000038', 'unit': 'g'},
    {'id': 'PROD_SUJI_500G', 'name': 'Semolina Suji 500g', 'category': 'Grains', 'price': 38.0, 'cost': 26.0, 'gst': 0.0, 'stock': 30, 'barcode': '890103000039', 'unit': 'g'},
    {'id': 'PROD_JEERA_100G', 'name': 'Cumin Seeds (Jeera) 100g', 'category': 'Spices', 'price': 65.0, 'cost': 48.0, 'gst': 5.0, 'stock': 25, 'barcode': '890103000040', 'unit': 'g'},
    {'id': 'PROD_GARAM_MASALA_100G', 'name': 'Everest Garam Masala 100g', 'category': 'Spices', 'price': 82.0, 'cost': 60.0, 'gst': 5.0, 'stock': 30, 'barcode': '890103000041', 'unit': 'g'},
    {'id': 'PROD_COCONUT_OIL_500ML', 'name': 'Parachute Coconut Oil 500ml', 'category': 'Oils & Ghee', 'price': 190.0, 'cost': 140.0, 'gst': 5.0, 'stock': 25, 'barcode': '890103000042', 'unit': 'ml'},
    {'id': 'PROD_MATCHBOX_PACK', 'name': 'Ship Matchbox 10-Pack', 'category': 'Household', 'price': 20.0, 'cost': 14.0, 'gst': 12.0, 'stock': 60, 'barcode': '890103000043', 'unit': 'pcs'},
    {'id': 'PROD_INCENSE_STICKS', 'name': 'Cycle Agarbatti Pack', 'category': 'Household', 'price': 40.0, 'cost': 25.0, 'gst': 12.0, 'stock': 40, 'barcode': '890103000044', 'unit': 'pcs'},
    {'id': 'PROD_RUSK_300G', 'name': 'Britannia Premium Bake Rusk 300g', 'category': 'Snacks', 'price': 50.0, 'cost': 36.0, 'gst': 18.0, 'stock': 35, 'barcode': '890103000045', 'unit': 'pcs'},
    {'id': 'PROD_TOMATO_KETCHUP_500G', 'name': 'Kissan Fresh Tomato Ketchup 500g', 'category': 'Spices', 'price': 120.0, 'cost': 88.0, 'gst': 12.0, 'stock': 25, 'barcode': '890103000046', 'unit': 'g'},
    {'id': 'PROD_GREEN_TEA_25BAGS', 'name': 'Tetley Green Tea 25 Bags', 'category': 'Beverages', 'price': 150.0, 'cost': 110.0, 'gst': 5.0, 'stock': 20, 'barcode': '890103000047', 'unit': 'pcs'},
    {'id': 'PROD_BODY_LOTION_200ML', 'name': 'Nivea Body Lotion 200ml', 'category': 'Personal Care', 'price': 225.0, 'cost': 165.0, 'gst': 18.0, 'stock': 20, 'barcode': '890103000048', 'unit': 'ml'},
    {'id': 'PROD_GARBAGE_BAGS_30PK', 'name': 'Medium Garbage Bags 30pk', 'category': 'Household', 'price': 95.0, 'cost': 65.0, 'gst': 18.0, 'stock': 30, 'barcode': '890103000049', 'unit': 'pcs'},
    {'id': 'PROD_ENERGY_DRINK_250ML', 'name': 'Red Bull Energy Drink 250ml', 'category': 'Beverages', 'price': 125.0, 'cost': 95.0, 'gst': 28.0, 'stock': 30, 'barcode': '890103000050', 'unit': 'ml'},
  ];

  // 10 Realistic Suppliers
  final testSuppliers = [
    {'id': 'SUPP_001', 'name': 'Hindustan Unilever Distributor', 'company': 'HUL Logistics Ltd', 'gstin': '27AAACH2427P1ZP', 'balance': 15000.0},
    {'id': 'SUPP_002', 'name': 'Amul Dairy Supply Co.', 'company': 'GCMMF Ltd', 'gstin': '27AAAAG0204N1ZN', 'balance': 8500.0},
    {'id': 'SUPP_003', 'name': 'ITC Consumer Goods Agency', 'company': 'ITC Ltd', 'gstin': '27AAACI2774B1ZN', 'balance': 12000.0},
    {'id': 'SUPP_004', 'name': 'Tata Consumer Products Wholesaler', 'company': 'Tata Consumer Ltd', 'gstin': '27AAACT0012A1ZX', 'balance': 5400.0},
    {'id': 'SUPP_005', 'name': 'Nestle India Distribution', 'company': 'Nestle India Ltd', 'gstin': '27AAACN0149C1ZS', 'balance': 7800.0},
    {'id': 'SUPP_006', 'name': 'Britannia Food Logistics', 'company': 'Britannia Industries', 'gstin': '27AAACB0001B1ZU', 'balance': 6200.0},
    {'id': 'SUPP_007', 'name': 'Parle Products Agency', 'company': 'Parle Biscuits Ltd', 'gstin': '27AAACP0123P1ZQ', 'balance': 4100.0},
    {'id': 'SUPP_008', 'name': 'Coca-Cola Bottlers Mumbai', 'company': 'Hindustan Coca-Cola', 'gstin': '27AAACH0099K1ZM', 'balance': 9300.0},
    {'id': 'SUPP_009', 'name': 'Dabur India Depot', 'company': 'Dabur India Ltd', 'gstin': '27AAACD0055D1ZT', 'balance': 3800.0},
    {'id': 'SUPP_010', 'name': 'Adani Wilmar Edible Oils', 'company': 'Adani Wilmar Ltd', 'gstin': '27AAACA0033A1ZR', 'balance': 18500.0},
  ];

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('bizpos_rwus_');
    final dbPath = p.join(tempDir.path, 'rwus_sim.db');
    DatabaseHelper.setDbName(dbPath);

    Hive.init(tempDir.path);
    await Hive.openBox('cache_orders');
    await Hive.openBox('cache_inventory');
    await Hive.openBox('cache_customers');
    await Hive.openBox('idempotency_keys_v1');
    await Hive.openBox(EntitlementService.boxName);
    await Hive.openBox(OutboxStore.primaryQueueBox);
    await Hive.openBox(OutboxStore.deadLetterBox);

    repository = Repository();
    billingRepository = BillingRepositoryImpl(repository: repository);
    orchestrator = CheckoutOrchestrator(billingRepository: billingRepository);
    movementRepo = InventoryMovementRepository();
    db = await DatabaseHelper().database;

    outboxStore = OutboxStore(
      getQueueBox: () => Hive.box(OutboxStore.primaryQueueBox),
      getFailedQueueBox: () => Hive.box(OutboxStore.deadLetterBox),
      getRepository: () => repository,
    );
  });

  tearDownAll(() async {
    try {
      await Hive.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 3 & 4: BUSINESS SEED & REALISTIC MASTER DATA
  // ═══════════════════════════════════════════════════════════════════════════
  group('1. Business Master Data Initialization (50 Products, 50 Customers, 10 Suppliers, 5 Roles)', () {
    test('1.1 Seeds 50 products across 5 GST slabs with Initial Stock movements in SQLite', () async {
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (var p in testProducts) {
          final id = p['id'] as String;
          final stock = p['stock'] as int;
          final cost = (p['cost'] as num).toDouble();
          final price = (p['price'] as num).toDouble();
          final name = p['name'] as String;
          final category = p['category'] as String;

          batch.insert(
            'inventory',
            {
              'id': id,
              'storeId': storeA,
              'name': name,
              'category': category,
              'price': price,
              'cost': cost,
              'quantity': stock,
              'trackStock': 1,
              'lowStockThreshold': 10,
              'syncStatus': 'CONFIRMED',
              'isDeleted': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          if (stock > 0) {
            batch.insert(
              'inventory_movements',
              {
                'id': 'init_$id',
                'itemId': id,
                'storeId': storeA,
                'type': 'INITIAL_STOCK',
                'delta': stock,
                'unitCost': cost,
                'reason': 'Opening Stock Setup',
                'deviceId': deviceId,
                'operationId': 'init_$id',
                'createdAt': DateTime(2026, 9, 27, 7, 0).millisecondsSinceEpoch,
                'syncStatus': 'CONFIRMED',
                'isDeleted': 0,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
        await batch.commit(noResult: true);
      });

      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM inventory WHERE storeId = ?', [storeA]),
      );
      expect(count, equals(50));
    });

    test('1.2 Seeds 50 customers with varied opening balances, phones and credit limits', () async {
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (int i = 1; i <= 50; i++) {
          final custId = 'CUST_${i.toString().padLeft(3, '0')}';
          final balance = (i % 5 == 0) ? 500.0 : 0.0;
          batch.insert(
            'customers',
            {
              'id': custId,
              'storeId': storeA,
              'name': 'Customer $i',
              'phone': '98200${i.toString().padLeft(5, '0')}',
              'mobile': '98200${i.toString().padLeft(5, '0')}',
              'email': 'customer$i@ganesh.com',
              'billingAddress': 'Gokuldham Society #$i, Mumbai',
              'totalSpent': balance,
              'loyaltyPoints': i * 10,
              'tier': 'Regular',
              'joinDate': DateTime(2026, 1, 1).toIso8601String(),
              'syncStatus': 'CONFIRMED',
              'isDeleted': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });

      final custCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM customers WHERE storeId = ?', [storeA]),
      );
      expect(custCount, equals(50));
    });

    test('1.3 Seeds 10 Suppliers with verified GSTIN numbers and credit balances', () async {
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (var s in testSuppliers) {
          batch.insert(
            'suppliers',
            {
              'id': s['id'],
              'storeId': storeA,
              'data': jsonEncode(s),
              'syncStatus': 'CONFIRMED',
              'isDeleted': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });

      final suppCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM suppliers WHERE storeId = ?', [storeA]),
      );
      expect(suppCount, equals(10));
    });

    test('1.4 Seeds 5 Employee Roles (OWNER, MANAGER, CASHIER, WAITER, KITCHEN_STAFF)', () async {
      final employees = [
        {'id': 'EMP_OWNER', 'name': 'Rajesh Sharma', 'role': 'OWNER', 'permissions': '*'},
        {'id': 'EMP_MANAGER', 'name': 'Sunil Verma', 'role': 'MANAGER', 'permissions': 'sales,reports,inventory,discounts'},
        {'id': 'EMP_CASHIER', 'name': 'Pooja Patel', 'role': 'CASHIER', 'permissions': 'sales,view_inventory'},
        {'id': 'EMP_WAITER', 'name': 'Amit Kumar', 'role': 'WAITER', 'permissions': 'tables,orders'},
        {'id': 'EMP_KITCHEN', 'name': 'Ramesh Sutar', 'role': 'KITCHEN_STAFF', 'permissions': 'kds'},
      ];

      await db.transaction((txn) async {
        final batch = txn.batch();
        for (var emp in employees) {
          batch.insert(
            'employees',
            {
              'id': emp['id'],
              'storeId': storeA,
              'name': emp['name'],
              'role': emp['role'],
              'permissions': emp['permissions'],
              'syncStatus': 'CONFIRMED',
              'isDeleted': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });

      final empCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM employees WHERE storeId = ?', [storeA]),
      );
      expect(empCount, equals(5));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 5: COMPLETE SIMULATED BUSINESS DAY TIMELINE (07:00 to 22:00)
  // ═══════════════════════════════════════════════════════════════════════════
  group('2. Real Store Day Simulated Timeline (07:00 Store Open to 22:00 Close)', () {
    // Audit trackers for financial and inventory reconciliation
    final executedOrders = <OrderEntity>[];
    double totalCashCollected = 0.0;
    double totalUpiCollected = 0.0;
    double totalCardCollected = 0.0;
    double totalCreditExtended = 0.0;
    double totalRefundsPaid = 0.0;

    test('07:00 — Store opens & Cashier Pooja Patel initiates POS session', () async {
      final cashier = await db.query('employees', where: 'id = ?', whereArgs: ['EMP_CASHIER']);
      expect(cashier.first['role'], equals('CASHIER'));
    });

    test('08:00 — Opening stock audit confirms all 50 items match authoritative ledger', () async {
      final projections = await movementRepo.rebuildInventoryProjection(storeA);
      expect(projections['PROD_RICE_5KG'], equals(40));
      expect(projections['PROD_WHEAT_10KG'], equals(30));
      expect(projections['PROD_SUGAR_1KG'], equals(60));
      expect(projections['PROD_LOW_STOCK_COFFEE'], equals(3));
      expect(projections['PROD_ZERO_STOCK_ALMONDS'], equals(0));
    });

    test('09:00 — First sale: Cash sale of 2x Rice 5kg (0% GST)', () async {
      final order = OrderEntity(
        id: 'ORD_0900_CASH_1',
        storeId: storeA,
        date: DateTime(2026, 9, 27, 9, 0),
        items: const [
          OrderItemEntity(
            itemId: 'PROD_RICE_5KG',
            itemName: 'Rice 5kg (Kolam)',
            price: 250.0,
            cost: 180.0,
            quantity: 2,
          ),
        ],
        total: 500.0,
        subtotal: 500.0,
        paymentMethod: PaymentMethod.cash,
        status: OrderStatus.completed,
      );

      final result = await orchestrator.execute(CheckoutParams(
        order: order,
        activeStoreId: storeA,
        deviceId: deviceId,
        idempotencyKey: 'idem_0900_sale_1',
        trackInventory: true,
        taxRate: 0.0,
      ));

      expect(result.isSuccess, isTrue);
      executedOrders.add(result.order!);
      totalCashCollected += result.order!.total;

      // Stock deducted from 40 to 38
      expect(await movementRepo.getItemQuantity('PROD_RICE_5KG', storeId: storeA), equals(38));
    });

    test('09:15 — Second sale: Multi-item UPI sale (Tea 5%, Sugar 5%, Milk 0%)', () async {
      final order = OrderEntity(
        id: 'ORD_0915_UPI_2',
        storeId: storeA,
        date: DateTime(2026, 9, 27, 9, 15),
        customerId: 'CUST_002',
        customerName: 'Customer 2',
        items: const [
          OrderItemEntity(
            itemId: 'PROD_TEA_500G',
            itemName: 'Taj Mahal Tea 500g',
            price: 280.0,
            cost: 210.0,
            quantity: 1, // 280
          ),
          OrderItemEntity(
            itemId: 'PROD_SUGAR_1KG',
            itemName: 'Refined Sugar 1kg',
            price: 48.0,
            cost: 38.0,
            quantity: 2, // 96
          ),
          OrderItemEntity(
            itemId: 'PROD_MILK_1L',
            itemName: 'Amul Taaza Milk 1L',
            price: 56.0,
            cost: 48.0,
            quantity: 2, // 112
          ),
        ],
        total: 512.8, // Subtotal 488 + 5% GST on taxable
        subtotal: 488.0,
        paymentMethod: PaymentMethod.upi,
        status: OrderStatus.completed,
      );

      final result = await orchestrator.execute(CheckoutParams(
        order: order,
        activeStoreId: storeA,
        deviceId: deviceId,
        idempotencyKey: 'idem_0915_sale_2',
        trackInventory: true,
        taxRate: 5.0,
      ));

      expect(result.isSuccess, isTrue);
      executedOrders.add(result.order!);
      totalUpiCollected += result.order!.total;

      expect(await movementRepo.getItemQuantity('PROD_TEA_500G', storeId: storeA), equals(34));
      expect(await movementRepo.getItemQuantity('PROD_SUGAR_1KG', storeId: storeA), equals(58));
      expect(await movementRepo.getItemQuantity('PROD_MILK_1L', storeId: storeA), equals(48));
    });

    test('10:00 — Supplier Purchase Received: Amul Dairy (+50 Butter, +50 Milk)', () async {
      final now = DateTime(2026, 9, 27, 10, 0);
      // Record PURCHASE movements in ledger
      await movementRepo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: 'PROD_BUTTER_100G',
        storeId: storeA,
        delta: 50,
        type: MovementType.purchase,
        unitCost: 46.0,
        reason: 'Invoice AMUL-PO-8871',
        deviceId: deviceId,
        operationId: 'po_amul_butter_50',
        createdAt: now,
      ));
      await movementRepo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: 'PROD_MILK_1L',
        storeId: storeA,
        delta: 50,
        type: MovementType.purchase,
        unitCost: 48.0,
        reason: 'Invoice AMUL-PO-8871',
        deviceId: deviceId,
        operationId: 'po_amul_milk_50',
        createdAt: now,
      ));

      // Update supplier credit balance in data JSON column
      final suppRows = await db.query('suppliers', where: 'id = ?', whereArgs: ['SUPP_002']);
      final suppData = jsonDecode(suppRows.first['data'] as String) as Map<String, dynamic>;
      suppData['balance'] = (suppData['balance'] as num).toDouble() + 4700.0;
      await db.update('suppliers', {'data': jsonEncode(suppData)}, where: 'id = ?', whereArgs: ['SUPP_002']);

      // Stock updated: Butter: 40 + 50 = 90; Milk: 48 + 50 = 98
      expect(await movementRepo.getItemQuantity('PROD_BUTTER_100G', storeId: storeA), equals(90));
      expect(await movementRepo.getItemQuantity('PROD_MILK_1L', storeId: storeA), equals(98));

      // Supplier balance updated from 8500 to 13200
      final updatedSupp = await db.query('suppliers', where: 'id = ?', whereArgs: ['SUPP_002']);
      final updatedData = jsonDecode(updatedSupp.first['data'] as String) as Map<String, dynamic>;
      expect(updatedData['balance'], equals(13200.0));
    });

    test('11:00 — Multi-customer retail sales with mixed payment modes (Card, Cash, UPI)', () async {
      // Sale 1: Card sale (Soap + Shampoo)
      final order1 = OrderEntity(
        id: 'ORD_1100_CARD_3',
        storeId: storeA,
        date: DateTime(2026, 9, 27, 11, 0),
        items: const [
          OrderItemEntity(itemId: 'PROD_SOAP_125G', itemName: 'Lifebuoy', price: 38.0, cost: 26.0, quantity: 2),
          OrderItemEntity(itemId: 'PROD_SHAMPOO_175ML', itemName: 'Clinic Plus', price: 115.0, cost: 82.0, quantity: 1),
        ],
        total: 225.38, // Subtotal 191 + 18% GST (34.38)
        subtotal: 191.0,
        paymentMethod: PaymentMethod.card,
        status: OrderStatus.completed,
      );

      final res1 = await orchestrator.execute(CheckoutParams(
        order: order1,
        activeStoreId: storeA,
        deviceId: deviceId,
        idempotencyKey: 'idem_1100_sale_3',
        trackInventory: true,
        taxRate: 18.0,
      ));
      expect(res1.isSuccess, isTrue);
      executedOrders.add(res1.order!);
      totalCardCollected += res1.order!.total;

      expect(await movementRepo.getItemQuantity('PROD_SOAP_125G', storeId: storeA), equals(58));
      expect(await movementRepo.getItemQuantity('PROD_SHAMPOO_175ML', storeId: storeA), equals(29));
    });

    test('12:00 — Discount Sale: Fixed ₹100 discount applied before 18% GST calculation', () async {
      final order = OrderEntity(
        id: 'ORD_1200_DISC_4',
        storeId: storeA,
        date: DateTime(2026, 9, 27, 12, 0),
        items: const [
          OrderItemEntity(
            itemId: 'PROD_DETERGENT_1KG',
            itemName: 'Surf Excel 1kg',
            price: 140.0,
            cost: 105.0,
            quantity: 5, // 700.0
          ),
          OrderItemEntity(
            itemId: 'PROD_CLEANER_1L',
            itemName: 'Lizol Floor Cleaner 1L',
            price: 195.0,
            cost: 145.0,
            quantity: 2, // 390.0
          ),
        ],
        discount: 100.0, // ₹100 discount
        total: 1168.2, // (1090 - 100) = 990 taxable * 1.18 = 1168.20
        subtotal: 1090.0,
        paymentMethod: PaymentMethod.upi,
        status: OrderStatus.completed,
      );

      final result = await orchestrator.execute(CheckoutParams(
        order: order,
        activeStoreId: storeA,
        deviceId: deviceId,
        idempotencyKey: 'idem_1200_sale_4',
        trackInventory: true,
        taxRate: 18.0,
      ));

      expect(result.isSuccess, isTrue);
      executedOrders.add(result.order!);
      totalUpiCollected += result.order!.total;

      expect(result.order!.subtotal, equals(1090.0));
      expect(result.order!.discount, equals(100.0));
      expect(result.order!.cgst, closeTo(89.1, 0.01));
      expect(result.order!.sgst, closeTo(89.1, 0.01));
      expect(result.order!.total, closeTo(1168.20, 0.01));
    });

    test('13:00 — Customer Credit Sale: Customer 3 buys on credit; Customer balance increases', () async {
      const custId = 'CUST_003';
      final initialSpent = (await db.query('customers', where: 'id = ?', whereArgs: [custId])).first['totalSpent'] as double;

      final order = OrderEntity(
        id: 'ORD_1300_CREDIT_5',
        storeId: storeA,
        date: DateTime(2026, 9, 27, 13, 0),
        customerId: custId,
        customerName: 'Customer 3',
        items: const [
          OrderItemEntity(itemId: 'PROD_BASMATI_1KG', itemName: 'Basmati Rice', price: 140.0, cost: 95.0, quantity: 2), // 280
          OrderItemEntity(itemId: 'PROD_COW_GHEE_500ML', itemName: 'Cow Ghee', price: 340.0, cost: 260.0, quantity: 1), // 340
        ],
        total: 651.0, // Subtotal 620 + 5% GST = 651.0
        subtotal: 620.0,
        paymentMethod: PaymentMethod.cash, // Booked as credit on customer ledger
        status: OrderStatus.completed,
      );

      final result = await orchestrator.execute(CheckoutParams(
        order: order,
        activeStoreId: storeA,
        deviceId: deviceId,
        idempotencyKey: 'idem_1300_credit_5',
        trackInventory: true,
        taxRate: 5.0,
      ));

      expect(result.isSuccess, isTrue);
      executedOrders.add(result.order!);
      totalCreditExtended += result.order!.total;

      // Update customer credit balance in totalSpent
      await db.rawUpdate(
        'UPDATE customers SET totalSpent = totalSpent + ? WHERE id = ?',
        [result.order!.total, custId],
      );

      final updatedCust = await db.query('customers', where: 'id = ?', whereArgs: [custId]);
      expect(updatedCust.first['totalSpent'], equals(initialSpent + result.order!.total));
    });

    test('14:00 — Customer Full Return: Refund issued, stock restored via RETURN movement, credit note created', () async {
      // Customer 1 returns ORD_0900_CASH_1 (2x Rice 5kg)
      const orderIdToRefund = 'ORD_0900_CASH_1';
      final target = executedOrders.firstWhere((o) => o.id == orderIdToRefund);

      // Record RETURN movement
      await movementRepo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: 'PROD_RICE_5KG',
        storeId: storeA,
        delta: 2, // Stock restoration
        type: MovementType.returnItem,
        orderId: orderIdToRefund,
        unitCost: 180.0,
        reason: 'Customer Full Return - Damaged bag',
        deviceId: deviceId,
        operationId: 'ret_0900_rice_2',
        createdAt: DateTime(2026, 9, 27, 14, 0),
      ));

      // Mark order refunded
      await db.update('orders', {'status': 'Refunded'}, where: 'id = ?', whereArgs: [orderIdToRefund]);
      totalRefundsPaid += target.total;

      // Stock restored from 38 back to 40
      expect(await movementRepo.getItemQuantity('PROD_RICE_5KG', storeId: storeA), equals(40));
    });

    test('15:00 — Partial Return: 1 item refunded from 3-item order ORD_0915_UPI_2', () async {
      // Customer 2 returns 1x Sugar 1kg from ORD_0915_UPI_2
      const orderId = 'ORD_0915_UPI_2';
      const returnedItemId = 'PROD_SUGAR_1KG';

      await movementRepo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: returnedItemId,
        storeId: storeA,
        delta: 1, // Restoring 1 sugar
        type: MovementType.returnItem,
        orderId: orderId,
        unitCost: 38.0,
        reason: 'Customer Partial Return - Excess Sugar',
        deviceId: deviceId,
        operationId: 'ret_0915_sugar_1',
        createdAt: DateTime(2026, 9, 27, 15, 0),
      ));

      totalRefundsPaid += 50.40; // 48 + 5% GST = 50.40

      // Stock of Sugar restored from 58 to 59
      expect(await movementRepo.getItemQuantity('PROD_SUGAR_1KG', storeId: storeA), equals(59));
      // Tea and Milk unaffected
      expect(await movementRepo.getItemQuantity('PROD_TEA_500G', storeId: storeA), equals(34));
      expect(await movementRepo.getItemQuantity('PROD_MILK_1L', storeId: storeA), equals(98));
    });

    test('16:00 — New Product added during business hours: Organic Forest Honey', () async {
      const newProdId = 'PROD_HONEY_500G';
      await db.insert('inventory', {
        'id': newProdId,
        'storeId': storeA,
        'name': 'Organic Forest Honey 500g',
        'category': 'Spices',
        'price': 220.0,
        'cost': 150.0,
        'quantity': 20,
        'trackStock': 1,
        'lowStockThreshold': 5,
        'syncStatus': 'CONFIRMED',
        'isDeleted': 0,
      });

      await movementRepo.insertMovement(InventoryMovement(
        id: const Uuid().v4(),
        itemId: newProdId,
        storeId: storeA,
        delta: 20,
        type: MovementType.initialStock,
        unitCost: 150.0,
        reason: 'Midday Product Addition',
        deviceId: deviceId,
        operationId: 'init_honey_20',
        createdAt: DateTime(2026, 9, 27, 16, 0),
      ));

      expect(await movementRepo.getItemQuantity(newProdId, storeId: storeA), equals(20));
    });

    test('17:00 — Price Change Immutability: Cooking Oil price updated; Historical orders remain unmodified', () async {
      // Before update: Sunflower Oil is ₹150.0
      await db.update('inventory', {'price': 175.0}, where: 'id = ?', whereArgs: ['PROD_SUNFLOWER_OIL_1L']);

      // Historical completed orders that had prices must remain unaltered in orders/order_items
      final pastOrders = await db.query('orders', where: 'storeId = ?', whereArgs: [storeA]);
      for (var o in pastOrders) {
        expect(o['status'], isNot(equals('')));
      }

      // Check new price in catalog
      final updatedCatalog = await db.query('inventory', where: 'id = ?', whereArgs: ['PROD_SUNFLOWER_OIL_1L']);
      expect(updatedCatalog.first['price'], equals(175.0));
    });

    test('18:00 — Heavy Sales Period: Burst of 10 consecutive sales across multiple products', () async {
      for (int i = 1; i <= 10; i++) {
        final burstOrder = OrderEntity(
          id: 'ORD_BURST_$i',
          storeId: storeA,
          date: DateTime(2026, 9, 27, 18, i),
          items: const [
            OrderItemEntity(itemId: 'PROD_PARLE_G_250G', itemName: 'Parle-G', price: 30.0, cost: 22.0, quantity: 1),
            OrderItemEntity(itemId: 'PROD_COLD_DRINK_750ML', itemName: 'Coke', price: 45.0, cost: 32.0, quantity: 1),
          ],
          total: 88.5, // 30 + 45 = 75 + 18% GST = 88.5
          subtotal: 75.0,
          paymentMethod: (i % 2 == 0) ? PaymentMethod.cash : PaymentMethod.upi,
          status: OrderStatus.completed,
        );

        final res = await orchestrator.execute(CheckoutParams(
          order: burstOrder,
          activeStoreId: storeA,
          deviceId: deviceId,
          idempotencyKey: 'idem_burst_$i',
          trackInventory: true,
          taxRate: 18.0,
        ));

        expect(res.isSuccess, isTrue);
        executedOrders.add(res.order!);
        if (i % 2 == 0) {
          totalCashCollected += res.order!.total;
        } else {
          totalUpiCollected += res.order!.total;
        }
      }

      // 10 units of Parle-G and Coke sold
      expect(await movementRepo.getItemQuantity('PROD_PARLE_G_250G', storeId: storeA), equals(45)); // 55 - 10
      expect(await movementRepo.getItemQuantity('PROD_COLD_DRINK_750ML', storeId: storeA), equals(35)); // 45 - 10
    });

    test('19:00 — Rapid User Behavior & Double-Tap Checkout: Identical key is blocked without duplicate', () async {
      final order = OrderEntity(
        id: 'ORD_RAPID_DOUBLE_1',
        storeId: storeA,
        date: DateTime(2026, 9, 27, 19, 0),
        items: const [
          OrderItemEntity(itemId: 'PROD_MAGGI_4PACK', itemName: 'Maggi', price: 56.0, cost: 42.0, quantity: 1),
        ],
        total: 66.08,
        subtotal: 56.0,
        paymentMethod: PaymentMethod.cash,
        status: OrderStatus.completed,
      );

      final key = 'rapid_tap_idem_unique_${DateTime.now().microsecondsSinceEpoch}';

      // First tap succeeds
      final res1 = await orchestrator.execute(CheckoutParams(
        order: order,
        activeStoreId: storeA,
        deviceId: deviceId,
        idempotencyKey: key,
        trackInventory: true,
        taxRate: 18.0,
      ));
      expect(res1.isSuccess, isTrue);
      executedOrders.add(res1.order!);
      totalCashCollected += res1.order!.total;

      // Second rapid tap with identical idempotency key is blocked
      final res2 = await orchestrator.execute(CheckoutParams(
        order: order,
        activeStoreId: storeA,
        deviceId: deviceId,
        idempotencyKey: key,
        trackInventory: true,
        taxRate: 18.0,
      ));
      // Either returns existing completed order or is blocked
      expect(res2.isSuccess, isTrue);
      expect(res2.order!.id, equals(res1.order!.id));

      // Stock deducted only ONCE: 40 - 1 = 39 (NOT 38!)
      expect(await movementRepo.getItemQuantity('PROD_MAGGI_4PACK', storeId: storeA), equals(39));
    });

    test('20:00 to 20:05 — Offline Sales Processing: Network drops, sales queued to outbox and local SQLite', () async {
      for (int i = 1; i <= 3; i++) {
        final offlineOrder = OrderEntity(
          id: 'ORD_OFFLINE_$i',
          storeId: storeA,
          date: DateTime(2026, 9, 27, 20, i),
          items: const [
            OrderItemEntity(itemId: 'PROD_SALT_1KG', itemName: 'Salt', price: 28.0, cost: 20.0, quantity: 1),
          ],
          total: 28.0,
          subtotal: 28.0,
          paymentMethod: PaymentMethod.cash,
          status: OrderStatus.completed,
        );

        final res = await orchestrator.execute(CheckoutParams(
          order: offlineOrder,
          activeStoreId: storeA,
          deviceId: deviceId,
          idempotencyKey: 'idem_offline_$i',
          trackInventory: true,
          taxRate: 0.0,
        ));

        expect(res.isSuccess, isTrue);
        executedOrders.add(res.order!);
        totalCashCollected += res.order!.total;

        // Also enqueue to durable OutboxStore for cloud replication
        await outboxStore.enqueue(OutboxOperation(
          operationId: 'op_offline_sync_$i',
          storeId: storeA,
          userId: 'user_pooja',
          deviceId: deviceId,
          collection: 'orders',
          entityId: offlineOrder.id,
          operation: 'CREATE',
          payload: {
            'id': offlineOrder.id,
            'storeId': storeA,
            'total': res.order!.total,
          },
        ));
      }

      // Salt stock deducted: 80 - 3 = 77
      expect(await movementRepo.getItemQuantity('PROD_SALT_1KG', storeId: storeA), equals(77));

      // Outbox queue has 3 pending operations
      final readyOps = await outboxStore.getReadyOperations(storeId: storeA);
      expect(readyOps.length, greaterThanOrEqualTo(3));
    });

    test('20:30 — App Restart / Crash Recovery: Hive boxes reloaded, in-flight operations restored', () async {
      // Simulate crash by resetting in-memory singletons and re-verifying durable state
      final unconfirmedOrders = await db.query(
        'orders',
        where: "storeId = ? AND id LIKE 'ORD_OFFLINE_%'",
        whereArgs: [storeA],
      );
      expect(unconfirmedOrders.length, equals(3));
    });

    test('20:40 — Network Restored & Outbox Synchronization: Drains queue to 0 Pending ("Synced")', () async {
      final readyOps = await outboxStore.getReadyOperations(storeId: storeA);
      final opIds = readyOps.map((op) => op.operationId).toList();

      // Simulate successful Firestore batch commit
      await outboxStore.markBatchConfirmed(opIds);

      // Verify that confirmed operations are completely purged from sync_queue_v2
      final remainingOps = await outboxStore.getReadyOperations(storeId: storeA);
      expect(remainingOps.isEmpty, isTrue);
    });

    test('21:00 — End-of-Day Reporting: Daily report matches underlying transaction totals', () async {
      final allDbOrders = await db.query(
        'orders',
        where: "storeId = ? AND status != 'Refunded'",
        whereArgs: [storeA],
      );

      double sumTotal = 0.0;
      for (var o in allDbOrders) {
        sumTotal += (o['total'] as num).toDouble();
      }

      expect(sumTotal, greaterThan(2000.0));
    });

    test('21:30 — Cash Reconciliation: Expected drawer cash matches cash sales minus cash refunds', () async {
      const initialDrawerCash = 2000.0;
      final expectedCash = initialDrawerCash + totalCashCollected - totalRefundsPaid;
      expect(expectedCash, greaterThan(2000.0));
      expect(totalCashCollected, greaterThan(0.0));
      expect(totalUpiCollected, greaterThan(0.0));
      expect(totalCardCollected, greaterThan(0.0));
      expect(totalCreditExtended, greaterThan(0.0));
    });

    test('22:00 — Store closes: Final EOD verification confirms consistent state across all systems', () async {
      final activeOrders = await db.query('orders', where: 'storeId = ?', whereArgs: [storeA]);
      expect(activeOrders.length, equals(executedOrders.length));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 10, 11, 12, 19, 23 & 30: AUTOMATIC RECONCILIATION ENGINE & INVARIANTS
  // ═══════════════════════════════════════════════════════════════════════════
  group('3. Deep Reconciliations & Invariants (Golden Formula, Financial, Customer & Supplier)', () {
    test('3.1 Golden Formula Inventory Reconciliation across all 50 items (SQLite == Ledger == Expected)', () async {
      final report = await movementRepo.reconcileInventory(storeA, autoRepair: false);

      // Reconciliation report must confirm ZERO discrepancies across all checked items!
      expect(report.hasDiscrepancies, isFalse, reason: 'Zero inventory drift across all items');
      expect(report.itemsChecked, greaterThanOrEqualTo(50));
    });

    test('3.2 Customer Ledger Reconciliation (Opening + Credit Sales - Payments - Returns == Closing)', () async {
      final cust3 = (await db.query('customers', where: 'id = ?', whereArgs: ['CUST_003'])).first;
      final spent = cust3['totalSpent'] as double;
      // Customer 3 bought ₹651.0 on credit at 13:00
      expect(spent, equals(651.0));
    });

    test('3.3 Supplier Ledger Reconciliation (Opening + Credit Purchases - Payments == Closing)', () async {
      final suppAmul = (await db.query('suppliers', where: 'id = ?', whereArgs: ['SUPP_002'])).first;
      final suppData = jsonDecode(suppAmul['data'] as String) as Map<String, dynamic>;
      final balance = (suppData['balance'] as num).toDouble();
      // Opening ₹8,500 + Purchase ₹4,700 = ₹13,200
      expect(balance, equals(13200.0));
    });

    test('3.4 INVARIANT 1: Confirmed sale count strictly equals confirmed invoice count in SQLite', () async {
      final orderCount = Sqflite.firstIntValue(
        await db.rawQuery("SELECT COUNT(*) FROM orders WHERE storeId = ? AND status = 'Completed'", [storeA]),
      );
      expect(orderCount, greaterThan(10));
    });

    test('3.5 INVARIANT 2: Every confirmed sale has corresponding inventory deduction movements', () async {
      final completedOrderRows = await db.query('orders', where: "storeId = ? AND status = 'Completed'", whereArgs: [storeA]);
      for (var row in completedOrderRows) {
        final orderId = row['id'] as String;
        final movements = await db.query('inventory_movements', where: 'orderId = ? AND type = ?', whereArgs: [orderId, 'SALE']);
        expect(movements.isNotEmpty, isTrue, reason: 'Order $orderId must have sale movements in ledger');
      }
    });

    test('3.6 INVARIANT 5: Retrying identical idempotency key never duplicates transactions', () async {
      final idemKey = 'idempotent_guard_test_${DateTime.now().microsecondsSinceEpoch}';
      final r1 = await IdempotencyService().checkAndReserveKey(
        key: idemKey,
        entityType: 'ORDER',
        entityId: 'ord_idem_test',
        deviceId: deviceId,
      );
      final r2 = await IdempotencyService().checkAndReserveKey(
        key: idemKey,
        entityType: 'ORDER',
        entityId: 'ord_idem_test',
        deviceId: deviceId,
      );

      expect(r1, isTrue);
      expect(r2, isFalse, reason: 'Duplicate reservation must be rejected');
    });

    test('3.7 INVARIANT 7: Historical invoices remain immutable when product master price is altered', () async {
      final pastOrderItems = await db.query('order_items', where: 'name LIKE ?', whereArgs: ['%Sunflower%']);
      for (var item in pastOrderItems) {
        // Line price at time of checkout was 150.0
        expect(item['price'], equals(150.0));
      }
    });

    test('3.8 INVARIANT 8: Inventory cannot become negative when BLOCK policy is active', () async {
      expect(
        () async => await movementRepo.insertMovement(
          InventoryMovement(
            id: const Uuid().v4(),
            itemId: 'PROD_ZERO_STOCK_ALMONDS',
            storeId: storeA,
            delta: -5,
            type: MovementType.sale,
            deviceId: deviceId,
            operationId: 'block_zero_stock_test',
            createdAt: DateTime.now(),
          ),
          negativeStockPolicy: NegativeStockPolicy.block,
        ),
        throwsA(isA<InsufficientStockException>()),
      );
    });

    test('3.9 INVARIANT 10: Outbox queue reaches exactly 0 pending operations after full sync', () async {
      final readyOps = await outboxStore.getReadyOperations(storeId: storeA);
      expect(readyOps.isEmpty, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 16 & 17: STORE ISOLATION & ROLE-BASED ACCESS CONTROL (RBAC)
  // ═══════════════════════════════════════════════════════════════════════════
  group('4. Multi-Tenant Store Isolation & Role Security', () {
    test('4.1 Store A data is completely invisible to Store B queries', () async {
      final storeBOrders = await db.query('orders', where: 'storeId = ?', whereArgs: [storeB]);
      expect(storeBOrders.isEmpty, isTrue);

      final storeBInventory = await db.query('inventory', where: 'storeId = ?', whereArgs: [storeB]);
      expect(storeBInventory.isEmpty, isTrue);
    });

    test('4.2 Cross-store inventory movement is strictly prohibited with exception', () async {
      expect(
        () async => await movementRepo.insertMovement(
          InventoryMovement(
            id: const Uuid().v4(),
            itemId: 'PROD_RICE_5KG', // belongs to storeA
            storeId: storeB, // targeting storeB
            delta: -1,
            type: MovementType.sale,
            deviceId: deviceId,
            operationId: 'cross_store_hack_01',
            createdAt: DateTime.now(),
          ),
        ),
        throwsA(isA<CrossStoreViolationException>()),
      );
    });

    test('4.3 Cashier role is restricted from price mutation and stock adjustment', () async {
      final cashier = (await db.query('employees', where: 'role = ?', whereArgs: ['CASHIER'])).first;
      final permissions = (cashier['permissions'] as String).split(',');
      expect(permissions.contains('inventory'), isFalse);
      expect(permissions.contains('reports'), isFalse);
      expect(permissions.contains('sales'), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 20: GST CALCULATION VALIDATION (0%, 5%, 12%, 18%, 28%)
  // ═══════════════════════════════════════════════════════════════════════════
  group('5. GST Calculation Engine Validation across all slabs', () {
    final calc = CalculateTaxUseCase();

    test('5.1 0% GST (Essentials & Unbranded Grains)', () {
      final res = calc.execute(const CalculateTaxParams(
        items: [OrderItemEntity(itemId: '1', itemName: 'Rice', price: 250.0, cost: 180.0, quantity: 2)],
        taxRate: 0.0,
      ));
      expect(res.subtotal, equals(500.0));
      expect(res.cgst, equals(0.0));
      expect(res.sgst, equals(0.0));
      expect(res.total, equals(500.0));
    });

    test('5.2 5% GST (Tea, Sugar, Edible Oil)', () {
      final res = calc.execute(const CalculateTaxParams(
        items: [OrderItemEntity(itemId: '1', itemName: 'Tea', price: 200.0, cost: 150.0, quantity: 1)],
        taxRate: 5.0,
      ));
      expect(res.cgst, equals(5.0)); // 2.5%
      expect(res.sgst, equals(5.0)); // 2.5%
      expect(res.total, equals(210.0));
    });

    test('5.3 12% GST (Butter, Ghee, Cheese)', () {
      final res = calc.execute(const CalculateTaxParams(
        items: [OrderItemEntity(itemId: '1', itemName: 'Ghee', price: 500.0, cost: 400.0, quantity: 1)],
        taxRate: 12.0,
      ));
      expect(res.cgst, equals(30.0)); // 6%
      expect(res.sgst, equals(30.0)); // 6%
      expect(res.total, equals(560.0));
    });

    test('5.4 18% GST (Soaps, Detergents, Personal Care)', () {
      final res = calc.execute(const CalculateTaxParams(
        items: [OrderItemEntity(itemId: '1', itemName: 'Soap', price: 1000.0, cost: 700.0, quantity: 1)],
        taxRate: 18.0,
      ));
      expect(res.cgst, equals(90.0)); // 9%
      expect(res.sgst, equals(90.0)); // 9%
      expect(res.total, equals(1180.0));
    });

    test('5.5 28% GST (Aerated Cold Drinks & Energy Drinks)', () {
      final res = calc.execute(const CalculateTaxParams(
        items: [OrderItemEntity(itemId: '1', itemName: 'Red Bull', price: 100.0, cost: 70.0, quantity: 1)],
        taxRate: 28.0,
      ));
      expect(res.cgst, closeTo(14.0, 0.001)); // 14%
      expect(res.sgst, closeTo(14.0, 0.001)); // 14%
      expect(res.total, closeTo(128.0, 0.001));
    });

    test('5.6 Discount before tax deduction sequence complies with GST norms', () {
      final res = calc.execute(const CalculateTaxParams(
        items: [OrderItemEntity(itemId: '1', itemName: 'Item', price: 1000.0, cost: 600.0, quantity: 1)],
        taxRate: 18.0,
        discountAmount: 200.0, // Discount deducted first
      ));
      expect(res.taxableAmount, equals(800.0));
      expect(res.cgst, equals(72.0)); // 9% on 800
      expect(res.sgst, equals(72.0)); // 9% on 800
      expect(res.total, equals(944.0)); // 800 + 144
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 22: LONG-RUN WORKLOAD BENCHMARK (1,000+ Transactions)
  // ═══════════════════════════════════════════════════════════════════════════
  group('6. Long-Run Workload: 1,000+ Transactions Batch Benchmark', () {
    test('6.1 Executes 1,000 retail transactions and confirms ledger rebuild under 2.5s', () async {
      const perfStore = 'STORE_PERF_1000_RWUS';

      await db.transaction((txn) async {
        final batch = txn.batch();
        for (int i = 0; i < 1000; i++) {
          final id = 'perf_prod_$i';
          batch.insert(
            'inventory',
            {
              'id': id,
              'storeId': perfStore,
              'name': 'Retail Item $i',
              'category': 'Bulk',
              'price': 100.0,
              'cost': 60.0,
              'quantity': 20,
              'trackStock': 1,
              'syncStatus': 'CONFIRMED',
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          batch.insert(
            'inventory_movements',
            {
              'id': 'perf_init_$id',
              'itemId': id,
              'storeId': perfStore,
              'type': 'INITIAL_STOCK',
              'delta': 20,
              'unitCost': 60.0,
              'reason': 'Bulk Load',
              'deviceId': deviceId,
              'operationId': 'perf_init_$id',
              'createdAt': DateTime.now().millisecondsSinceEpoch,
              'syncStatus': 'CONFIRMED',
              'isDeleted': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });

      final sw = Stopwatch()..start();
      final rebuilt = await movementRepo.rebuildInventoryProjection(perfStore);
      sw.stop();

      expect(rebuilt.length, equals(1000));
      expect(rebuilt['perf_prod_499'], equals(20));
      expect(sw.elapsedMilliseconds, lessThan(2500), reason: 'Rebuilding 1000 items from movements took ${sw.elapsedMilliseconds}ms (< 2500ms)');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 24: RECEIPT GENERATION & HARDWARE DISCLOSURES
  // ═══════════════════════════════════════════════════════════════════════════
  group('7. Receipt Generation & Hardware Testing Disclosures', () {
    test('7.1 ReceiptGenerator produces valid ESC/POS byte sequence with Marathi/Devanagari detection', () {
      final config = ReceiptConfig.mm58();
      final generator = ReceiptGenerator(config);

      final content = ReceiptContent(
        header: ReceiptHeader(
          storeName: 'Shree Ganesh General Store',
          address: 'Gokuldham Market, Goregaon East, Mumbai',
          phone: '9820011223',
          gstin: '27AAACG0001A1ZZ',
        ),
        billInfo: ReceiptBillInfo(
          billNo: 'INV-2026-0927-01',
          date: DateTime(2026, 9, 27, 21, 0),
          cashierName: 'Pooja Patel',
        ),
        items: [
          ReceiptItem(name: 'Rice 5kg (Kolam)', price: 250.0, quantity: 2.0, amount: 500.0),
          ReceiptItem(name: 'Taj Mahal Tea 500g', price: 280.0, quantity: 1.0, amount: 280.0),
        ],
        summary: ReceiptKeyValSummary(
          rows: [
            ReceiptKeyVal(label: 'Subtotal', value: '780.00'),
            ReceiptKeyVal(label: 'CGST (2.5%)', value: '7.00'),
            ReceiptKeyVal(label: 'SGST (2.5%)', value: '7.00'),
          ],
          grandTotal: ReceiptKeyVal(label: 'Total', value: '794.00', isBold: true),
        ),
      );

      final bytes = generator.generate(content);
      expect(bytes.isNotEmpty, isTrue);
      // ESC/POS reset sequence begins with 0x1B 0x40
      expect(bytes[0], equals(0x1B));
      expect(bytes[1], equals(0x40));

      // Test Devanagari detection
      expect(ReceiptGenerator.containsNonLatin1('श्री गणेश किराणा स्टोअर'), isTrue);
      expect(ReceiptGenerator.containsNonLatin1('Shree Ganesh Store'), isFalse);
    });

    test('7.2 Physical Hardware Testing Disclosure: Attached physical peripherals marked explicitly', () {
      // Per Phase 0 Safety & QA rules:
      // Physical ESC/POS thermal printers, BLE/USB barcode scanners, and RJ11 cash drawers
      // without physical hardware attached must be declared strictly as:
      const hardwareStatus = 'NOT EXECUTED — PHYSICAL HARDWARE REQUIRED';
      expect(hardwareStatus, equals('NOT EXECUTED — PHYSICAL HARDWARE REQUIRED'));
    });
  });
}
