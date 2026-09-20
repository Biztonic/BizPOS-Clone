import 'package:sqflite/sqflite.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/features/crm/data/customer_repository_mixin.dart';

class CustomerRepository with CustomerRepositoryMixin {
  @override
  final DatabaseHelper dbHelper;

  CustomerRepository({required this.dbHelper});

  @override
  Future<Database> get database => dbHelper.database;
}
