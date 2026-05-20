import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

Map<String, dynamic> _decodeJson(String json) => jsonDecode(json) as Map<String, dynamic>;

class RecoveryService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Scans the transaction_journal for PENDING records and resolves them if possible.
  /// Returns a list of unresolved payloads that require user intervention.
  Future<List<Map<String, dynamic>>> scanAndRecover() async {
    final db = await _dbHelper.database;
    final pendingRecords = await db.query(
      'transaction_journal',
      where: 'status = ?',
      whereArgs: ['PENDING'],
    );

    List<Map<String, dynamic>> unresolvedTransactions = [];

    for (var record in pendingRecords) {
      final txId = record['id'] as String;
      final operationsJson = record['operations'] as String;
      
      try {
        final payload = await compute(_decodeJson, operationsJson);
        final orderMap = payload['order'] as Map<String, dynamic>?;
        
        if (orderMap == null || !orderMap.containsKey('id')) {
          // Invalid payload, mark as failed
          await _markStatus(db, txId, 'FAILED');
          continue;
        }

        final orderId = orderMap['id'];

        // Check if the transaction actually succeeded (order exists)
        final orderExists = await _dbHelper.count(
          'orders',
          where: 'id = ?',
          whereArgs: [orderId],
        ) > 0;

        if (orderExists) {
          // Transaction succeeded, but journal wasn't updated
          debugPrint('RecoveryService: Auto-recovering TX $txId (already completed)');
          await _markStatus(db, txId, 'COMPLETED');
        } else {
          // Transaction failed/rolled back
          debugPrint('RecoveryService: TX $txId is pending and order is missing.');
          unresolvedTransactions.add({
            'txId': txId,
            'payload': payload,
            'raw': operationsJson,
            'createdAt': record['createdAt'],
          });
        }
      } catch (e) {
        debugPrint('RecoveryService: Error parsing TX $txId payload: $e');
        await _markStatus(db, txId, 'FAILED');
      }
    }

    return unresolvedTransactions;
  }

  Future<void> _markStatus(Database db, String txId, String status) async {
    await db.update(
      'transaction_journal',
      {'status': status},
      where: 'id = ?',
      whereArgs: [txId],
    );
  }

  Future<void> discardTransaction(String txId) async {
    final db = await _dbHelper.database;
    await _markStatus(db, txId, 'DISCARDED');
  }

  // The actual retry logic will be handled by the UI calling performAtomicCheckout again.
}
