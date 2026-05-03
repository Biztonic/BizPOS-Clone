import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:biztonic_pos/models/business_ledger.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';

import 'package:biztonic_pos/features/billing/data/order_repository_mixin.dart';

class OrderRepository with OrderRepositoryMixin {
  final DatabaseHelper dbHelper;
  final InventoryMovementRepository movementRepo;

  OrderRepository({
    required this.dbHelper,
    required this.movementRepo,
  });

  @override
  Future<Database> get database => dbHelper.database;

  // All order methods are provided by OrderRepositoryMixin with journaling support.
}
