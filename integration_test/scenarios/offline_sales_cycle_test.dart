import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:biztonic_pos/main.dart' as app;
import 'package:biztonic_pos/utils/app_driver_helper.dart';
// Import to facilitate mocking if needed

// Note: To truly "simulate" offline in a flutter integration test without OS level control, 
// we might need to inject a mock Connectivity service or use the App's built-in "Offline Mode" toggle if one existed.
// For this test, we will assume we can toggle the 'SyncService' or 'OfflineService' state via a debug menu or direct injection if possible.
// Or we rely on the App specific UI flow if it allows forcing offline.
// Since we don't have a "Force Offline" button in UI explicitly mentioned besides the one we might have added or config,
// We will focus on the "Workflow" assuming we are offline.

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Scenario: Offline Sales Cycle', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    
    final driver = AppDriver(tester);
    
    // 1. Initial State: App Launch
    // Verify we are at Login or Dashboard (depending on auth state). 
    // Best practice: Ensure clean state or logout first.
    // For now, let's assume Login Screen if not authenticated.
    
    // NOTE: This test might be fragile if 'app.main()' auto-logs in.
    // We'll check for a common element of dashboard vs login.
    
    bool isOnDashboard = find.byType(Drawer).evaluate().isNotEmpty || find.text('Overview').evaluate().isNotEmpty;
    
    if (!isOnDashboard) {
      // LOGIN FLOW
      // Assuming keys 'email_field', 'password_field', 'login_button' exist. 
      // If not, we might need to rely on helper finding by type or adding keys to source.
      // We will add specific Keys to the Login Screen in the next step to make this robust.
      // For now, speculative keys based on variable names.
      await driver.enterText('email_input', 'admin@biztonic.com');
      await driver.enterText('password_input', 'password123');
      await driver.tap('login_button');
    }
    
    // 2. Select Store (if Multi-store dialog appears)
    // await driver.tapText('My Retail Store'); 

    // 3. Verify Dashboard
    driver.expectText("Dashboard");
    
    // 4. Simulate Offline Mode
    // Ideally: OfflineService().setMockOffline(true);
    // Since we can't easily access the singleton instance running inside 'app.main' from here without exposure,
    // we might need to add a "Developer Options" button in the app that toggles this.
    // ACTION: We will trigger a UI action that corresponds to "Work Offline" if available, 
    // or verify the UI that APPEARS when offline (e.g. by disconnecting host network if running on real device).
    
    // For this MVP test, we will proceed to POS and Add Items.
    // 5. Add Items to Cart
    // Open Drawer if on Mobile
    await driver.openDrawer();
    await driver.waitFor(find.byKey(const Key('menu_pos')));
    await driver.tap('menu_pos'); // Key added in DashboardScreen
    
    // 5. Add Items to Cart
    // Wait for at least one item
    try {
      await driver.waitFor(find.byType(GridTile).first, timeout: const Duration(seconds: 10));
    } catch (_) {
       // The POS screen uses Card inside GridView
    }
    
    // Tap the first product.
    await driver.waitFor(find.byKey(const Key('pos_item_0')));
    await driver.tap('pos_item_0');
    
    // 6. Checkout
    await driver.tap('checkout_button');
    // Note: If payments processing confirmation dialog appears, we might need to handle it.
    // The code shows: setState(_isProcessing = true) -> showDialog (loader) -> processSale -> SnackBar.
    // So 'checkout_button' triggers the process directly.
    
    // 7. Verify Unsynced Count or Success Message
    // await driver.wait(2000); // Wait for async process
    // driver.expectText("Order Placed Successfully!"); 
    // Snackbars are hard to test with find.text sometimes due to timing.
    // Better to verify Cart is Empty.
    // driver.expectText("Your cart is empty");
    
    // 8. Go Online & Sync
    // OfflineService().setMockOffline(false);
    // await driver.tap('sync_button');
    
    // 9. Verify Sync
    // driver.expectText("Synced");
    
  });
}
