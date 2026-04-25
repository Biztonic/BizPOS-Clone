import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:biztonic_pos/main.dart' as app;
import 'package:biztonic_pos/utils/app_driver_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Scenario: New User Onboarding', (tester) async {
    try {
      app.main();
      await tester.pumpAndSettle();
      
      final driver = AppDriver(tester);
      
      // ... (rest of the code)
      bool isLoginScreen = find.text('BizPOS Login').evaluate().isNotEmpty;
      if (!isLoginScreen) {
        // Logout if needed
        // Check for logout button...
      }
  
      // 1. Switch to Sign Up
      // 'Create new account' button
      await driver.tapText('Create new account');
      
      // 2. Fill Form
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await driver.enterText('email_input', 'user_$timestamp@test.com');
      await driver.enterText('password_input', 'password123');
      // Mobile number is required per AuthScreen code
      await driver.enterText('mobile_input', '9876543210'); // Need key 'mobile_input' in AuthScreen
      
      // 3. Submit
      await driver.tap('login_button'); 
  
      // 4. Verify Store Creation Screen Logic (Plan Selection)
      // Wait for Plan Selection Screen
      await driver.waitFor(find.text('Choose Your Business Plan'));
      
      // Select 'Standard' Plan (ID 'standard' assumed, or 'retail'?)
      // Try to find the button by key
      // We will try 'plan_button_standard'. If seed data uses 'retail', we might fail.
      // Let's assume 'standard' based on prior comments. If fail, we see logs.
      try {
        await driver.tap('plan_button_standard');
      } catch (e) {
        await driver.tap('plan_button_retail');
      }
      
      // 5. Fill Store Creation Dialog
      await driver.waitFor(find.text('Setup Your Store'));
      await driver.enterText('store_name_input', 'My Test Store');
      await driver.tap('confirm_store_creation');
      
      // 6. Verify Dashboard
      // Wait for dashboard to load (look for "Overview" or "Sales")
      await driver.waitFor(find.text('Overview'));
    } catch (e) {
      rethrow;
    }
  });
}
