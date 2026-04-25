import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:biztonic_pos/main.dart' as app;
import 'package:biztonic_pos/utils/app_driver_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Scenario: Inventory Management (Add Item)', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    
    final driver = AppDriver(tester);
    
    bool isOnDashboard = find.text('Overview').evaluate().isNotEmpty;
    if (!isOnDashboard) {
      // Login flow
      await driver.enterText('email_input', 'admin@biztonic.com');
      await driver.enterText('password_input', 'password123');
      await driver.tap('login_button');
      await driver.waitForText('Overview');
    }

    await driver.openDrawer();
    await driver.tap('menu_inventory'); // Ensure this Key exists in Drawer
    
    // Try mobile key first then desktop key or by tooltip
    // We added 'add_new_item' for Desktop and 'add_new_item_mobile' for mobile.
    // Ideally we try one.
    // But since we are on Chrome Desktop usually, 'add_new_item' should work.
    // If mobile emulation is on, 'add_new_item_mobile'.
    // Let's use find.byIcon(Icons.add) as fallback? No, robust keys.
    try {
       await driver.tap('add_new_item');
    } catch (e) {
       await driver.tap('add_new_item_mobile');
    }
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await driver.enterText('item_name_input', 'Test Item $timestamp');
    await driver.enterText('item_price_input', '100');
    // Screen has Quantity not Cost
    await driver.enterText('item_qty_input', '50');
    
    await driver.tap('save_item_button');
    
    await driver.waitForText('Test Item $timestamp');
  });
}
