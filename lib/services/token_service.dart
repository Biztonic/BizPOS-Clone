import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class TokenService {
  static final TokenService _instance = TokenService._internal();
  factory TokenService() => _instance;
  TokenService._internal();

  final _dbHelper = DatabaseHelper();
  
  // In production, this secret should be rotated or fetched securely
  static const String _tokenSecret = "BIZTONIC_ENTERPRISE_SECRET_2026";

  /// Verifies a signed JSON token.
  /// Format: { "plan": "BASIC", "maxOrders": 500, "expiry": 12345678, "signature": "..." }
  bool verifyToken(String tokenJson, String signature) {
    var key = utf8.encode(_tokenSecret);
    var bytes = utf8.encode(tokenJson);

    var hmacSha256 = Hmac(sha256, key);
    var digest = hmacSha256.convert(bytes);

    return digest.toString() == signature;
  }

  Future<void> saveToken(String storeId, String tokenJson, String signature, DateTime validUntil) async {
    final db = await _dbHelper.database;
    await db.insert(
      'plan_tokens',
      {
        'storeId': storeId,
        'token': tokenJson,
        'signature': signature,
        'validUntil': validUntil.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getActivePlanDetails(String storeId) async {
    final db = await _dbHelper.database;
    final results = await db.query('plan_tokens', where: 'storeId = ?', whereArgs: [storeId]);
    
    if (results.isEmpty) return null;

    final row = results.first;
    final tokenJson = row['token'] as String;
    final signature = row['signature'] as String;
    final validUntil = DateTime.parse(row['validUntil'] as String);

    if (DateTime.now().isAfter(validUntil)) {
      return null; // Expired
    }

    if (!verifyToken(tokenJson, signature)) {
      return null; // Tampered
    }

    return jsonDecode(tokenJson);
  }

  /// Increments local monthly counter
  Future<int> incrementOrderCounter(String storeId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final yearMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    await db.transaction((txn) async {
      final results = await txn.query(
        'monthly_order_counter', 
        where: 'storeId = ? AND yearMonth = ?', 
        whereArgs: [storeId, yearMonth]
      );

      if (results.isEmpty) {
        await txn.insert('monthly_order_counter', {
          'storeId': storeId,
          'yearMonth': yearMonth,
          'count': 1
        });
      } else {
        int currentCount = results.first['count'] as int;
        await txn.update(
          'monthly_order_counter', 
          {'count': currentCount + 1},
          where: 'storeId = ? AND yearMonth = ?',
          whereArgs: [storeId, yearMonth]
        );
      }
    });

    return await getMonthlyCount(storeId);
  }

  Future<int> getMonthlyCount(String storeId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final yearMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    final results = await db.query(
      'monthly_order_counter', 
      where: 'storeId = ? AND yearMonth = ?', 
      whereArgs: [storeId, yearMonth]
    );

    if (results.isEmpty) return 0;
    return results.first['count'] as int;
  }
}
