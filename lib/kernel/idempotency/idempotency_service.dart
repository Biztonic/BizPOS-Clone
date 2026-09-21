import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/services/database_helper.dart';

class IdempotencyService {
  static final IdempotencyService _instance = IdempotencyService._internal();
  factory IdempotencyService() => _instance;
  IdempotencyService._internal();

  final _uuid = const Uuid();

  /// In-memory re-entrancy guard to block concurrent callers in the same process
  /// before they even attempt SQLite transactions.
  final Set<String> _inFlightKeys = {};

  /// Generates a time-sortable UUID v7 key.
  String generateKey() {
    return _uuid.v7();
  }

  /// Checks if a key is currently in-flight in this process.
  bool isKeyInFlight(String key) => _inFlightKeys.contains(key);

  /// Releases an in-flight key (e.g. after transaction completes or rolls back).
  void releaseInFlight(String key) {
    _inFlightKeys.remove(key);
  }

  /// Checks if an idempotency key has already been processed or is currently in flight.
  /// If not, it reserves the key atomically in SQLite and marks it in-flight.
  /// Returns `true` if the key is NEW and safe to process.
  /// Returns `false` if the key has ALREADY BEEN PROCESSED or is IN-FLIGHT (duplicate).
  Future<bool> checkAndReserveKey({
    required String key,
    required String entityType,
    required String entityId,
    required String deviceId,
  }) async {
    // 1. In-process re-entrancy check
    if (_inFlightKeys.contains(key)) {
      debugPrint(
          '🛡️ IdempotencyService: Blocked in-process re-entrancy for key: $key');
      return false;
    }
    _inFlightKeys.add(key);

    try {
      if (kIsWeb) {
        final success = await _checkAndReserveKeyWeb(
          key: key,
          entityType: entityType,
          entityId: entityId,
          deviceId: deviceId,
        );
        if (!success) {
          _inFlightKeys.remove(key);
        }
        return success;
      }

      final db = await DatabaseHelper().database;

      await db.insert(
        'idempotency_keys',
        {
          'key': key,
          'entityType': entityType,
          'entityId': entityId,
          'deviceId': deviceId,
          'createdAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return true; // Key was successfully inserted (new)
    } on DatabaseException catch (e) {
      _inFlightKeys.remove(key);
      if (e.isUniqueConstraintError()) {
        return false; // Key already exists (duplicate)
      }
      rethrow;
    } catch (e) {
      _inFlightKeys.remove(key);
      rethrow;
    }
  }

  /// Look up the entityId associated with a previously reserved key.
  Future<String?> getReservedEntityId(String key) async {
    if (kIsWeb) {
      const boxName = 'idempotency_keys';
      Box box;
      if (!Hive.isBoxOpen(boxName)) {
        box = await Hive.openBox(boxName);
      } else {
        box = Hive.box(boxName);
      }
      final data = box.get(key);
      if (data is Map) {
        return data['entityId'] as String?;
      }
      return null;
    }

    try {
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'idempotency_keys',
        columns: ['entityId'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first['entityId'] as String?;
      }
    } catch (e) {
      debugPrint('IdempotencyService: Error looking up reserved entityId: $e');
    }
    return null;
  }

  /// Optional: Use in a broader SQLite transaction.
  /// The transaction must be passed as `txn`.
  Future<bool> checkAndReserveKeyTxn({
    required Transaction txn,
    required String key,
    required String entityType,
    required String entityId,
    required String deviceId,
  }) async {
    if (kIsWeb) {
      return _checkAndReserveKeyWeb(
        key: key,
        entityType: entityType,
        entityId: entityId,
        deviceId: deviceId,
      );
    }
    try {
      await txn.insert(
        'idempotency_keys',
        {
          'key': key,
          'entityType': entityType,
          'entityId': entityId,
          'deviceId': deviceId,
          'createdAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return true;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        return false;
      }
      rethrow;
    }
  }

  Future<bool> _checkAndReserveKeyWeb({
    required String key,
    required String entityType,
    required String entityId,
    required String deviceId,
  }) async {
    const boxName = 'idempotency_keys';
    Box box;
    if (!Hive.isBoxOpen(boxName)) {
      box = await Hive.openBox(boxName);
    } else {
      box = Hive.box(boxName);
    }

    final existing = box.get(key);
    if (existing != null) {
      return false; // Already reserved/processed (duplicate)
    }

    await box.put(key, {
      'key': key,
      'entityType': entityType,
      'entityId': entityId,
      'deviceId': deviceId,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return true; // Successfully reserved (new)
  }
}
