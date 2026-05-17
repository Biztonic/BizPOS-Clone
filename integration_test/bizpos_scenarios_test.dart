import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:biztonic_pos/main.dart' as app;

void main() {
  patrolTest(
    'BizPOS Full Flow: Onboarding -> Inventory -> POS -> Orders',
    ($) async {
      // 1. Start the app
      app.main();
      await $.pumpAndSettle();

      // Note: In a real test environment, we might need to handle Login/Store Selection.
      // For this test, we assume the app starts at the Dashboard or we navigate there.
      
      // 2. Navigate to Inventory
      await $(Icons.inventory_2).tap(); // Sidebar icon
      await $.pumpAndSettle();
      expect($('Inventory'), findsOneWidget);

      // 3. Add a new item
      await $(const Key('add_new_item')).tap();
      await $.pumpAndSettle();
      
      await $(const Key('item_name_field')).enterText('Test Patrol Burger');
      await $(const Key('item_price_field')).enterText('150');
      await $(const Key('item_category_field')).enterText('Patrol Burgers');
      await $(const Key('save_item_button')).tap();
      await $.pumpAndSettle();

      // 4. Verify item exists in Inventory list
      await $(const Key('inventory_search_field')).enterText('Patrol Burger');
      await $.pumpAndSettle();
      expect($('Test Patrol Burger'), findsOneWidget);

      // 5. Navigate to POS
      await $(Icons.point_of_sale).tap(); // Sidebar icon
      await $.pumpAndSettle();
      expect($('Point of Sale'), findsOneWidget);

      // 6. Select Category & Add to Cart
      await $(const Key('pos_category_patrol_burgers')).tap();
      await $.pumpAndSettle();
      
      final productItem = $(const Key('pos_product_test_patrol_burger')); // ID used in Key
      if (productItem.exists) {
        await productItem.tap();
      } else {
        // Fallback for demo: just tap the first item if specific key not found in mock data
        await $(const Key('pos_search_field')).enterText('Patrol Burger');
        await $.pumpAndSettle();
        await $(Icons.add).first.tap();
      }
      await $.pumpAndSettle();

      // 7. Verify Cart & Checkout
      expect($('Total'), findsOneWidget);
      await $(const Key('checkout_button')).tap();
      await $.pumpAndSettle();

      // 8. Verify Order in Sales
      await $(Icons.history).tap(); // Sidebar icon for Sales
      await $.pumpAndSettle();
      expect($('Order History'), findsOneWidget);
      expect($('Test Patrol Burger'), findsOneWidget);

      // 9. Navigate to Settings/Subscription
      await $(Icons.settings).tap();
      await $.pumpAndSettle();
      await $(const Key('settings_menu_subscription')).tap();
      await $.pumpAndSettle();
      expect($('Subscription Plan'), findsOneWidget);
    },
  );
}
