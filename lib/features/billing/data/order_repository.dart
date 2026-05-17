import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';

import 'package:biztonic_pos/features/billing/data/order_repository_mixin.dart';

class OrderRepository with OrderRepositoryMixin {
  @override
  final DatabaseHelper dbHelper;
  @override
  final InventoryMovementRepository movementRepo;

  OrderRepository({
    required this.dbHelper,
    required this.movementRepo,
  });

  @override
  Future<Database> get database => dbHelper.database;

  // All order methods are provided by OrderRepositoryMixin with journaling support.
}
