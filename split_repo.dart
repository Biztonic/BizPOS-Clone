import 'dart:io';

void main() {
  final file = File('lib/services/repository.dart');
  final content = file.readAsStringSync();
  
  // Extract sections using precise indexing to not lose any code
  final lines = content.split('\n');
  
  final outOrders = File('lib/features/billing/data/order_repository_mixin.dart');
  final outInventory = File('lib/features/inventory/data/inventory_repository_mixin.dart');
  final outCustomer = File('lib/features/crm/data/customer_repository_mixin.dart');
  final outReporting = File('lib/features/reporting/data/reporting_repository_mixin.dart');
  final outConfig = File('lib/features/store/data/config_repository_mixin.dart');
  
  outOrders.createSync(recursive: true);
  outInventory.createSync(recursive: true);
  outCustomer.createSync(recursive: true);
  outReporting.createSync(recursive: true);
  outConfig.createSync(recursive: true);
  
  // Just print the line numbers for now to verify
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('  // --- ')) {
      print('$i: ${lines[i]}');
    }
  }
}
