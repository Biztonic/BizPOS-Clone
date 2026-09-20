import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';
import 'package:biztonic_pos/features/inventory/data/inventory_repository_mixin.dart';

class InventoryRepository with InventoryRepositoryMixin {
  @override
  final DatabaseHelper dbHelper;
  @override
  final InventoryMovementRepository movementRepo;

  InventoryRepository({
    required this.dbHelper,
    required this.movementRepo,
  });

  @override
  Future<Database> get database => dbHelper.database;
}
