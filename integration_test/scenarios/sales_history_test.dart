import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:biztonic_pos/main.dart' as app;
import 'package:biztonic_pos/utils/app_driver_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Scenario: Sales History View', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    
    final driver = AppDriver(tester);
    
    bool isOnDashboard = find.text('Overview').evaluate().isNotEmpty;
    if (!isOnDashboard) {
      await driver.enterText('email_input', 'admin@biztonic.com');
      await driver.enterText('password_input', 'password123');
      await driver.tap('login_button');
      await driver.waitForText('Overview');
    }

    await driver.openDrawer();
    await driver.tap('menu_sales'); // Corrected Key from DashboardScreen
    
    // Wait for at least one order item or empty state
    // We assume there's "Order #" text or "No orders"
    // Let's just verify the page title "Sales History" or similar
    // And maybe check if a listview exists
    
    // Attempt to find at least one list tile or the empty view
    // driver.waitFor(find.byType(ListView)); 
  });
}
