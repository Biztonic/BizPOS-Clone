// ignore_for_file: unused_field
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/services/firestore_helper.dart';
import 'package:biztonic_pos/models/customer.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/services/sync_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CustomerProvider with ChangeNotifier {
  late final FirebaseFirestore _db = getFirestore(); // Use 'bizpos' database
  final Repository _repository = Repository();
  final SyncService _syncService;

  List<Customer> _customers = [];
  bool _isLoading = false;

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;

  CustomerProvider(this._syncService);

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
            final String? targetStoreId = storeId?.trim();

            if (targetStoreId == null) return;

            // HELPER: Recursive cast for Hive maps
            Map<String, dynamic> recursiveCast(Map map) {
              return map.map((key, value) {
                if (value is Map) return MapEntry(key.toString(), recursiveCast(value));
                if (value is List) return MapEntry(key.toString(), value.map((e) => e is Map ? recursiveCast(e) : e).toList());
                return MapEntry(key.toString(), value);
              });
            }

            final cached = box.values
                .where((v) {
                   if (v is! Map) return false;
                   final vStoreId = (v['storeId'] ?? '').toString().trim();
                   return vStoreId == targetStoreId && v['deletedAt'] == null;
                })
                .map((e) => Customer.fromMap(recursiveCast(e as Map), (e)['id'] ?? ''))
                .toList();
            
            _customers = cached;

            notifyListeners();
         } catch (e) { /* Error ignored */ }
      }
 else {
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
    // 1. Write (Local + Queue)
    await _syncService.performLocalWrite(
      collection: 'customers',
      docId: customer.id,
      data: customer.toHiveMap(), // Hive compatible (String dates)
      action: 'create',
      localCacheBox: 'cache_customers',
      refreshCounts: false
    );
    
    // 2. Memory Update
    _customers.add(customer);
    _customers.sort((a,b) => (b.lastVisit ?? DateTime(0)).compareTo(a.lastVisit ?? DateTime(0)));
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
        refreshCounts: false
      );
      _customers.add(customer);
    }
    _customers.sort((a,b) => (b.lastVisit ?? DateTime(0)).compareTo(a.lastVisit ?? DateTime(0)));
    notifyListeners();
  }

  Future<void> updateCustomer(Customer customer) async {
    await _syncService.performLocalWrite(
      collection: 'customers',
      docId: customer.id,
      data: customer.toHiveMap(), // Hive compatible
      action: 'update',
      localCacheBox: 'cache_customers',
      refreshCounts: false
    );

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
      refreshCounts: false
    );
    
    _customers.removeWhere((c) => c.id == customerId);
    notifyListeners();
  }
  
  // STATS UPDATES (Called by OrderProvider or Dashboard)
  Future<void> updateCustomerLoyalty(String id, int pointsChange) async {
     // Retrieve current value to avoid FieldValue.increment in local storage
     // Note: This relies on optimistic concurrency or ensuring single writer if possible.
     // For local Hive, we must compute the final value.
     
     final index = _customers.indexWhere((c) => c.id == id);
     if (index == -1) return; // Should not happen if UI calls this on existing item

     final old = _customers[index];
     final finalPoints = old.loyaltyPoints + pointsChange;
     
     final updatedCustomer = old.copyWith(
        loyaltyPoints: finalPoints,
        lastVisit: DateTime.now()
     );

     // We MUST send the FULL object to performLocalWrite because it uses Repository.insertCustomer
     // which would overwrite the record with partial data if we only sent points/lastVisit.
     await _syncService.performLocalWrite(
       collection: 'customers',
       docId: id,
       data: updatedCustomer.toHiveMap(), 
       action: 'update',
       localCacheBox: 'cache_customers',
       refreshCounts: false
     );
     
     // Optimistic Local Update
     _customers[index] = updatedCustomer;
     notifyListeners();
  }
}
