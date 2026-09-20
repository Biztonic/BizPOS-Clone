import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/sync/data/sync_repository_mixin.dart';

class SyncRepository with SyncRepositoryMixin {
  @override
  final DatabaseHelper dbHelper;

  SyncRepository({required this.dbHelper});

  @override
  Future<Database> get database => dbHelper.database;
}
