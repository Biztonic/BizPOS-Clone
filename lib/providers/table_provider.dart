import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/models/floor.dart';
import 'package:biztonic_pos/models/table_model.dart';
import 'package:biztonic_pos/services/sync_service.dart';
import 'package:biztonic_pos/services/firestore_helper.dart';

class TableProvider with ChangeNotifier {
  final SyncService _syncService = SyncService();
  late final FirebaseFirestore _db = getFirestore();

  List<Floor> _floors = [];
  List<TableModel> _tables = [];
  String? _activeStoreId;
  bool _isLoading = false;

  List<Floor> get floors => _floors;
  List<TableModel> get tables => _tables;
  bool get isLoading => _isLoading;

  void setActiveStoreId(String? id) {
    if (_activeStoreId != id) {
      _activeStoreId = id;
      _syncService.setActiveStoreId(id);
      _loadFromCache();
    }
  }

  Future<void> _loadFromCache() async {
    if (_activeStoreId == null) {
      _floors = [];
      _tables = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    scheduleMicrotask(() => notifyListeners());

    try {
      final floorBoxName = 'cache_floors_$_activeStoreId';
      final floorBox = await Hive.openBox(floorBoxName);
      _floors = floorBox.toMap().entries.map((entry) => Floor.fromMap(_deepSanitize(entry.value as Map), entry.key.toString())).toList();

      final tableBoxName = 'cache_tables_$_activeStoreId';
      final tableBox = await Hive.openBox(tableBoxName);
      _tables = tableBox.toMap().entries.map((entry) => TableModel.fromMap(_deepSanitize(entry.value as Map), entry.key.toString())).toList();

      if (_tables.isEmpty) {
        await fetchTablesAndFloorsFromCloud(_activeStoreId!);
      }
      scheduleMicrotask(() => notifyListeners());
    } catch (e) {
      debugPrint('❌ TableProvider: Error loading from cache: $e');
    } finally {
      _isLoading = false;
      scheduleMicrotask(() => notifyListeners());
    }
  }

  Map<String, dynamic> _deepSanitize(Map map) {
    return map.map((key, value) {
      if (value is Map) return MapEntry(key.toString(), _deepSanitize(value));
      if (value is List) return MapEntry(key.toString(), value.map((e) => e is Map ? _deepSanitize(e) : e).toList());
      return MapEntry(key.toString(), value);
    });
  }

  Future<void> fetchTablesAndFloorsFromCloud(String storeId) async {
    try {
      // Use root collections with storeId filtering to align with SyncService and multi-store architecture
      final floorSnap = await _db.collection('floors').where('storeId', isEqualTo: storeId).get();
      if (floorSnap.docs.isNotEmpty) {
        _floors = floorSnap.docs.map((d) => Floor.fromMap(d.data(), d.id)).toList();
        final box = await Hive.openBox('cache_floors_$storeId');
        await box.clear();
        for (var f in _floors) {
          await box.put(f.id, f.toMap());
        }
      }
      
      final tableSnap = await _db.collection('tables').where('storeId', isEqualTo: storeId).get();
      if (tableSnap.docs.isNotEmpty) {
        _tables = tableSnap.docs.map((d) => TableModel.fromMap(d.data(), d.id)).toList();
        final box = await Hive.openBox('cache_tables_$storeId');
        await box.clear();
        for (var t in _tables) {
          await box.put(t.id, t.toMap());
        }
      }
      scheduleMicrotask(() => notifyListeners());
    } catch (e) {
      debugPrint('❌ TableProvider: Error fetching from cloud: $e');
    }
  }

  // --- FLOOR MANAGEMENT ---
  Future<void> addFloor(Floor floor) async {
    final storeId = floor.storeId.isNotEmpty ? floor.storeId : _activeStoreId;
    if (storeId == null || storeId.isEmpty) return;
    
    final id = floor.id.isEmpty ? _syncService.generateId() : floor.id;
    final f = floor.copyWith(id: id, storeId: storeId);
    
    await _syncService.performLocalWrite(
      collection: 'floors',
      docId: id,
      data: f.toMap(),
      action: 'create',
      localCacheBox: 'cache_floors_$storeId'
    );
    
    _floors.add(f);
    notifyListeners();
  }

  Future<void> updateFloor(Floor floor) async {
    final storeId = floor.storeId.isNotEmpty ? floor.storeId : _activeStoreId;
    if (storeId == null || storeId.isEmpty) return;

    await _syncService.performLocalWrite(
      collection: 'floors',
      docId: floor.id,
      data: floor.toMap(),
      action: 'update',
      localCacheBox: 'cache_floors_$storeId'
    );

    final i = _floors.indexWhere((x) => x.id == floor.id);
    if (i != -1) _floors[i] = floor;
    
    notifyListeners();
  }

  Future<void> deleteFloor(String id) async {
    final storeId = _activeStoreId;
    if (storeId == null || storeId.isEmpty) return;

    await _syncService.performLocalWrite(
      collection: 'floors',
      docId: id,
      data: {},
      action: 'delete',
      localCacheBox: 'cache_floors_$storeId'
    );

    _floors.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  // --- TABLE MANAGEMENT ---
  Future<void> addTable(TableModel table) async {
    final storeId = table.storeId.isNotEmpty ? table.storeId : _activeStoreId;
    if (storeId == null || storeId.isEmpty) return;

    final id = table.id.isEmpty ? _syncService.generateId() : table.id;
    final t = table.copyWith(id: id, storeId: storeId);
    
    await _syncService.performLocalWrite(
      collection: 'tables',
      docId: id,
      data: t.toMap(),
      action: 'create',
      localCacheBox: 'cache_tables_$storeId'
    );

    _tables.add(t);
    notifyListeners();
  }

  Future<void> updateTable(TableModel table) async {
    final storeId = table.storeId.isNotEmpty ? table.storeId : _activeStoreId;
    if (storeId == null || storeId.isEmpty) return;

    await _syncService.performLocalWrite(
      collection: 'tables',
      docId: table.id,
      data: table.toMap(),
      action: 'update',
      localCacheBox: 'cache_tables_$storeId'
    );

    final i = _tables.indexWhere((x) => x.id == table.id);
    if (i != -1) _tables[i] = table;
    
    notifyListeners();
  }

  Future<void> deleteTable(String id) async {
    final storeId = _activeStoreId;
    if (storeId == null || storeId.isEmpty) return;

    await _syncService.performLocalWrite(
      collection: 'tables',
      docId: id,
      data: {},
      action: 'delete',
      localCacheBox: 'cache_tables_$storeId'
    );

    _tables.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  Future<void> occupyTable(String tableId, String orderId) async {
    final storeId = _activeStoreId;
    if (storeId == null || storeId.isEmpty) return;

    final i = _tables.indexWhere((x) => x.id == tableId);
    if (i != -1) {
      _tables[i] = _tables[i].copyWith(
        status: 'Occupied', 
        orderId: orderId,
        billingMode: 'whole-table'
      );

      await _syncService.performLocalWrite(
        collection: 'tables',
        docId: tableId,
        data: _tables[i].toMap(),
        action: 'update',
        localCacheBox: 'cache_tables_$storeId'
      );
    }
    notifyListeners();
  }

  Future<void> occupySeat(String tableId, int seatNumber, String orderId) async {
    final storeId = _activeStoreId;
    if (storeId == null || storeId.isEmpty) return;

    final i = _tables.indexWhere((x) => x.id == tableId);
    if (i != -1) {
      final updatedSeats = List<TableSeat>.from(_tables[i].seats);
      final sIdx = updatedSeats.indexWhere((s) => s.number == seatNumber);
      if (sIdx != -1) {
        updatedSeats[sIdx] = TableSeat(number: seatNumber, orderId: orderId);
        _tables[i] = _tables[i].copyWith(
          status: 'Occupied', 
          seats: updatedSeats,
          billingMode: 'per-seat'
        );

        await _syncService.performLocalWrite(
          collection: 'tables',
          docId: tableId,
          data: _tables[i].toMap(),
          action: 'update',
          localCacheBox: 'cache_tables_$storeId'
        );
      }
    }
    notifyListeners();
  }

  Future<void> clearSeat(String tableId, int seatNumber) async {
    final storeId = _activeStoreId;
    if (storeId == null || storeId.isEmpty) return;

    final i = _tables.indexWhere((x) => x.id == tableId);
    if (i != -1) {
      final updatedSeats = List<TableSeat>.from(_tables[i].seats);
      final sIdx = updatedSeats.indexWhere((s) => s.number == seatNumber);
      if (sIdx != -1) {
        updatedSeats[sIdx] = TableSeat(number: seatNumber, orderId: null);
        
        bool anyOccupied = updatedSeats.any((s) => s.orderId != null);
        String newStatus = anyOccupied ? 'Occupied' : (_tables[i].orderId != null ? 'Occupied' : 'Available');

        _tables[i] = _tables[i].copyWith(
          status: newStatus, 
          seats: updatedSeats
        );

        await _syncService.performLocalWrite(
          collection: 'tables',
          docId: tableId,
          data: _tables[i].toMap(),
          action: 'update',
          localCacheBox: 'cache_tables_$storeId'
        );
      }
    }
    notifyListeners();
  }

  Future<void> bookTable(String tableId, DateTime date, TimeOfDay time, int guests) async {
    final storeId = _activeStoreId;
    if (storeId == null || storeId.isEmpty) return;

    final i = _tables.indexWhere((x) => x.id == tableId);
    if (i != -1) {
        _tables[i] = _tables[i].copyWith(
          status: 'Booked', 
          bookedTime: date,
          bookedSeats: guests
        );

        await _syncService.performLocalWrite(
          collection: 'tables',
          docId: tableId,
          data: _tables[i].toMap(),
          action: 'update',
          localCacheBox: 'cache_tables_$storeId'
        );
    }
    notifyListeners();
  }

  Future<void> clearTable(String id) async {
    final storeId = _activeStoreId;
    if (storeId == null || storeId.isEmpty) return;

    final i = _tables.indexWhere((x) => x.id == id);
    if (i != -1) {
       final clearedSeats = _tables[i].seats.map((s) => TableSeat(number: s.number, orderId: null)).toList();
       _tables[i] = _tables[i].copyWith(
         status: 'Available', 
         orderId: null, 
         bookedTime: null,
         seats: clearedSeats
       );

       await _syncService.performLocalWrite(
         collection: 'tables',
         docId: id,
         data: _tables[i].toMap(),
         action: 'update',
         localCacheBox: 'cache_tables_$storeId'
       );
    }
    notifyListeners();
  }
}
