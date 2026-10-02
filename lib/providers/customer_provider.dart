// ignore_for_file: unused_field
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/services/firestore_helper.dart';
import 'package:biztonic_pos/models/customer.dart';
import 'package:biztonic_pos/models/customer_crm_models.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/services/sync_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';

class CustomerProvider with ChangeNotifier {
  late final FirebaseFirestore _db = getFirestore(); // Use 'bizpos' database
  final Repository _repository = Repository();
  final SyncService _syncService;

  List<Customer> _customers = [];
  bool _isLoading = false;

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;

  StreamSubscription? _syncCompletedSub;

  CustomerProvider(this._syncService) {
    _syncCompletedSub = EventBus.instance.on<SyncCompletedEvent>((event) {
      fetchCustomers(event.storeId, refresh: true);
    });
  }

  // --- FETCHING ---

  Future<void> fetchCustomers(String? storeId, {bool refresh = false}) async {
    if (_isLoading) return;

    // Check cache first (via Repository) or just memory if not refresh
    if (!refresh && _customers.isNotEmpty) return;

    _isLoading = true;
    // notifyListeners(); // Don't notify start to avoid flicker if list is already populated

    try {
      // Use Repository for offline-first fetch
      if (kIsWeb) {
        // WEB: Use Hive Cache (SyncService manages the cloud sync)
        try {
          final box = await Hive.openBox('cache_customers');
          final String targetStoreId = (storeId ?? _syncService.activeStoreId ?? '').trim();

          // HELPER: Recursive cast for Hive maps
          Map<String, dynamic> recursiveCast(Map map) {
            return map.map((key, value) {
              if (value is Map) {
                return MapEntry(key.toString(), recursiveCast(value));
              }
              if (value is List) {
                return MapEntry(key.toString(),
                    value.map((e) => e is Map ? recursiveCast(e) : e).toList());
              }
              return MapEntry(key.toString(), value);
            });
          }

          final cached = box.values
              .where((v) {
                if (v is! Map) return false;
                final vStoreId = (v['storeId'] ?? '').toString().trim();
                final matchesStore = targetStoreId.isEmpty ||
                    vStoreId.isEmpty ||
                    vStoreId == targetStoreId;
                return matchesStore && v['deletedAt'] == null;
              })
              .map((e) =>
                  Customer.fromMap(recursiveCast(e as Map), (e)['id'] ?? ''))
              .toList();

          _customers = cached;

          notifyListeners();
        } catch (e) {/* Error ignored */}
      } else {
        final loaded = await _repository.getCustomers(storeId);
        _customers = loaded;
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? _error;
  String? get error => _error;

  void clearCustomers() {
    _customers.clear();
    notifyListeners();
  }

  // --- ACTIONS ---

  Future<void> addCustomer(Customer customer) async {
    final effectiveStoreId = customer.storeId.isNotEmpty
        ? customer.storeId
        : (_syncService.activeStoreId ?? '');
    final effectiveCustomer = customer.copyWith(storeId: effectiveStoreId);

    // 1. Write (Local + Queue)
    await _syncService.performLocalWrite(
        collection: 'customers',
        docId: effectiveCustomer.id,
        data: effectiveCustomer.toHiveMap(), // Hive compatible (String dates)
        action: 'create',
        localCacheBox: 'cache_customers',
        refreshCounts: false);

    // 2. Memory Update
    _customers.removeWhere((c) => c.id == effectiveCustomer.id);
    _customers.add(effectiveCustomer);
    _customers.sort((a, b) =>
        (b.lastVisit ?? DateTime(0)).compareTo(a.lastVisit ?? DateTime(0)));
    notifyListeners();
  }

  Future<void> addCustomers(List<Customer> customers) async {
    for (var customer in customers) {
      await _syncService.performLocalWrite(
          collection: 'customers',
          docId: customer.id,
          data: customer.toHiveMap(),
          action: 'create',
          localCacheBox: 'cache_customers',
          refreshCounts: false);
      _customers.add(customer);
    }
    _customers.sort((a, b) =>
        (b.lastVisit ?? DateTime(0)).compareTo(a.lastVisit ?? DateTime(0)));
    notifyListeners();
  }

  Future<void> updateCustomer(Customer customer) async {
    await _syncService.performLocalWrite(
        collection: 'customers',
        docId: customer.id,
        data: customer.toHiveMap(), // Hive compatible
        action: 'update',
        localCacheBox: 'cache_customers',
        refreshCounts: false);

    final index = _customers.indexWhere((c) => c.id == customer.id);
    if (index != -1) {
      _customers[index] = customer;
      notifyListeners();
    }
  }

  Future<void> deleteCustomer(String customerId) async {
    // Soft Delete
    await _syncService.performLocalWrite(
        collection: 'customers',
        docId: customerId,
        data: {
          'deletedAt': DateTime.now().toIso8601String(),
          'isDeleted': true
        },
        action: 'update', // Soft delete is just an update
        localCacheBox: 'cache_customers',
        refreshCounts: false);

    _customers.removeWhere((c) => c.id == customerId);
    notifyListeners();
  }

  // STATS UPDATES (Called by OrderProvider or Dashboard)
  Future<void> updateCustomerLoyalty(String id, int pointsChange) async {
    // Retrieve current value to avoid FieldValue.increment in local storage
    // Note: This relies on optimistic concurrency or ensuring single writer if possible.
    // For local Hive, we must compute the final value.

    final index = _customers.indexWhere((c) => c.id == id);
    if (index == -1) {
      return; // Should not happen if UI calls this on existing item
    }

    final old = _customers[index];
    final finalPoints = old.loyaltyPoints + pointsChange;

    final updatedCustomer =
        old.copyWith(loyaltyPoints: finalPoints, lastVisit: DateTime.now());

    // We MUST send the FULL object to performLocalWrite because it uses Repository.insertCustomer
    // which would overwrite the record with partial data if we only sent points/lastVisit.
    await _syncService.performLocalWrite(
        collection: 'customers',
        docId: id,
        data: updatedCustomer.toHiveMap(),
        action: 'update',
        localCacheBox: 'cache_customers',
        refreshCounts: false);

    // Optimistic Local Update
    _customers[index] = updatedCustomer;
    notifyListeners();
  }

  // --- CRM HELPER ---
  Map<String, dynamic> _castMap(Map map) {
    return map.map((key, value) {
      if (value is Map) return MapEntry(key.toString(), _castMap(value));
      if (value is List) {
        return MapEntry(
            key.toString(),
            value.map((e) => e is Map ? _castMap(e) : e).toList());
      }
      return MapEntry(key.toString(), value);
    });
  }

  // ─────────────────────────────────────────────────────────────
  // UDHARI (CUSTOMER CREDIT / BORROW LEDGER)
  // ─────────────────────────────────────────────────────────────

  Future<void> addUdhariTransaction(UdhariTransaction tx) async {
    await _syncService.performLocalWrite(
      collection: 'udhari_transactions',
      docId: tx.id,
      data: tx.toHiveMap(),
      action: 'create',
      localCacheBox: 'cache_udhari',
      refreshCounts: false,
    );

    // Update customer's udhariBalance
    final custIndex = _customers.indexWhere((c) => c.id == tx.customerId);
    if (custIndex != -1) {
      final cust = _customers[custIndex];
      final currentBalance = cust.udhariBalance;
      final newBalance = tx.type == 'borrow'
          ? (currentBalance + tx.amount)
          : (currentBalance - tx.amount);
      final updatedCust = cust.copyWith(
        udhariBalance: newBalance < 0 ? 0.0 : newBalance,
        lastVisit: DateTime.now(),
      );
      await updateCustomer(updatedCust);
    }
    notifyListeners();
  }

  Future<List<UdhariTransaction>> getUdhariTransactions(String customerId) async {
    try {
      final box = await Hive.openBox('cache_udhari');
      final list = box.values
          .where((v) => v is Map && (v['customerId'] ?? '') == customerId)
          .map((v) => UdhariTransaction.fromMap(_castMap(v as Map), v['id'] ?? ''))
          .toList();

      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (e) {
      debugPrint("Error fetching udhari transactions: $e");
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CUSTOMER COUPONS
  // ─────────────────────────────────────────────────────────────

  Future<void> addCustomerCoupon(CustomerCoupon coupon) async {
    await _syncService.performLocalWrite(
      collection: 'customer_coupons',
      docId: coupon.id,
      data: coupon.toHiveMap(),
      action: 'create',
      localCacheBox: 'cache_customer_coupons',
      refreshCounts: false,
    );
    notifyListeners();
  }

  Future<List<CustomerCoupon>> getCustomerCoupons(String customerId) async {
    try {
      final box = await Hive.openBox('cache_customer_coupons');
      final list = box.values
          .where((v) => v is Map && (v['customerId'] ?? '') == customerId)
          .map((v) => CustomerCoupon.fromMap(_castMap(v as Map), v['id'] ?? ''))
          .toList();
      list.sort((a, b) => b.validUntil.compareTo(a.validUntil));
      return list;
    } catch (e) {
      debugPrint("Error fetching customer coupons: $e");
      return [];
    }
  }

  Future<void> redeemCustomerCoupon(String customerId, String couponId) async {
    try {
      final box = await Hive.openBox('cache_customer_coupons');
      final raw = box.get(couponId);
      if (raw is Map) {
        final coupon = CustomerCoupon.fromMap(_castMap(raw), couponId);
        final updated = CustomerCoupon(
          id: coupon.id,
          customerId: coupon.customerId,
          storeId: coupon.storeId,
          code: coupon.code,
          title: coupon.title,
          description: coupon.description,
          discountType: coupon.discountType,
          discountValue: coupon.discountValue,
          minOrderValue: coupon.minOrderValue,
          validUntil: coupon.validUntil,
          isRedeemed: true,
          redeemedAt: DateTime.now(),
        );
        await _syncService.performLocalWrite(
          collection: 'customer_coupons',
          docId: couponId,
          data: updated.toHiveMap(),
          action: 'update',
          localCacheBox: 'cache_customer_coupons',
          refreshCounts: false,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error redeeming coupon: $e");
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CUSTOMER GIFTS (VOUCHERS / GIFT CARDS)
  // ─────────────────────────────────────────────────────────────

  Future<void> addCustomerGift(CustomerGift gift) async {
    await _syncService.performLocalWrite(
      collection: 'customer_gifts',
      docId: gift.id,
      data: gift.toHiveMap(),
      action: 'create',
      localCacheBox: 'cache_customer_gifts',
      refreshCounts: false,
    );
    notifyListeners();
  }

  Future<List<CustomerGift>> getCustomerGifts(String customerId) async {
    try {
      final box = await Hive.openBox('cache_customer_gifts');
      final list = box.values
          .where((v) => v is Map && (v['customerId'] ?? '') == customerId)
          .map((v) => CustomerGift.fromMap(_castMap(v as Map), v['id'] ?? ''))
          .toList();
      list.sort((a, b) => b.validUntil.compareTo(a.validUntil));
      return list;
    } catch (e) {
      debugPrint("Error fetching customer gifts: $e");
      return [];
    }
  }

  Future<void> redeemCustomerGift(String customerId, String giftId) async {
    try {
      final box = await Hive.openBox('cache_customer_gifts');
      final raw = box.get(giftId);
      if (raw is Map) {
        final gift = CustomerGift.fromMap(_castMap(raw), giftId);
        final updated = CustomerGift(
          id: gift.id,
          customerId: gift.customerId,
          storeId: gift.storeId,
          voucherCode: gift.voucherCode,
          title: gift.title,
          amount: gift.amount,
          validUntil: gift.validUntil,
          status: 'Redeemed',
          notes: gift.notes,
        );
        await _syncService.performLocalWrite(
          collection: 'customer_gifts',
          docId: giftId,
          data: updated.toHiveMap(),
          action: 'update',
          localCacheBox: 'cache_customer_gifts',
          refreshCounts: false,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error redeeming gift: $e");
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LOYALTY HISTORY
  // ─────────────────────────────────────────────────────────────

  Future<void> addLoyaltyTransaction(LoyaltyTransaction tx) async {
    await _syncService.performLocalWrite(
      collection: 'loyalty_transactions',
      docId: tx.id,
      data: tx.toHiveMap(),
      action: 'create',
      localCacheBox: 'cache_customer_loyalty',
      refreshCounts: false,
    );

    // Update customer's points
    final custIndex = _customers.indexWhere((c) => c.id == tx.customerId);
    if (custIndex != -1) {
      final cust = _customers[custIndex];
      final newPoints = tx.balanceAfter;
      final updatedCust = cust.copyWith(
        loyaltyPoints: newPoints,
        lastVisit: DateTime.now(),
      );
      await updateCustomer(updatedCust);
    }
    notifyListeners();
  }

  Future<List<LoyaltyTransaction>> getLoyaltyHistory(String customerId) async {
    try {
      final box = await Hive.openBox('cache_customer_loyalty');
      final list = box.values
          .where((v) => v is Map && (v['customerId'] ?? '') == customerId)
          .map((v) => LoyaltyTransaction.fromMap(_castMap(v as Map), v['id'] ?? ''))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (e) {
      debugPrint("Error fetching loyalty history: $e");
      return [];
    }
  }

  @override
  void dispose() {
    _syncCompletedSub?.cancel();
    super.dispose();
  }
}
