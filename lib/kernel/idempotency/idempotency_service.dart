import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';

class IdempotencyService {
  static final IdempotencyService _instance = IdempotencyService._internal();
  factory IdempotencyService() => _instance;
  IdempotencyService._internal();

  final _uuid = const Uuid();

  /// Generates a time-sortable UUID v7 key.
  String generateKey() {
    return _uuid.v7();
  }

  /// Checks if an idempotency key has already been processed.
  /// If not, it reserves the key atomically.
  /// Returns `true` if the key is NEW and safe to process.
  /// Returns `false` if the key has ALREADY BEEN PROCESSED (duplicate).
  Future<bool> checkAndReserveKey({
    required String key,
    required String entityType,
    required String entityId,
    required String deviceId,
  }) async {
    final db = await DatabaseHelper().database;

    try {
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
      if (e.isUniqueConstraintError()) {
        return false; // Key already exists (duplicate)
      }
      rethrow;
    }
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
}
