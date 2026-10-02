import 'package:flutter_test/flutter_test.dart';
import 'package:biztonic_pos/models/customer.dart';
import 'package:biztonic_pos/widgets/customer_whatsapp_dialog.dart';
import 'package:biztonic_pos/features/store/domain/entities/settings.dart';

void main() {
  group('Customer WhatsApp Template Engine & Control Panel Tests', () {
    final testCustomer = Customer(
      id: 'cust_test_101',
      storeId: 'store_test',
      name: 'Ramesh Sharma',
      mobile: '9876543210',
      email: 'ramesh@example.com',
      udhariBalance: 3450.0,
      loyaltyPoints: 420,
      totalSpent: 18900.0,
      visitCount: 14,
      tier: 'VIP',
      joinDate: DateTime(2025, 1, 15),
    );

    const testStoreName = "Sharma Supermarket";
    const testSettings = CustomerAddonSettings(
      enableUdhari: true,
      enableLoyalty: true,
      pointRedemptionValue: 1.0,
    );

    test('1. Generates Udhari (Khata) due reminder template correctly', () {
      final text = CustomerWhatsAppDialog.generateTemplateText(
        customer: testCustomer,
        storeName: testStoreName,
        customerSettings: testSettings,
        category: WhatsAppTemplateCategory.udhariDue,
      );

      expect(text, contains("Namaste Ramesh Sharma"));
      expect(text, contains("Sharma Supermarket"));
      expect(text, contains("₹3450"));
      expect(text, contains("settle the due amount"));
    });

    test('2. Generates Promotions & Discounts template correctly', () {
      final text = CustomerWhatsAppDialog.generateTemplateText(
        customer: testCustomer,
        storeName: testStoreName,
        customerSettings: testSettings,
        category: WhatsAppTemplateCategory.promotions,
      );

      expect(text, contains("Special Offer For You, *Ramesh Sharma*!"));
      expect(text, contains("Sharma Supermarket"));
      expect(text, contains("Show this WhatsApp message"));
    });

    test('3. Generates Transactions / Purchase history template correctly', () {
      final text = CustomerWhatsAppDialog.generateTemplateText(
        customer: testCustomer,
        storeName: testStoreName,
        customerSettings: testSettings,
        category: WhatsAppTemplateCategory.transactions,
      );

      expect(text, contains("Total Purchases: *₹18900* across 14 visits"));
      expect(text, contains("Reward Points: *420 pts*"));
    });

    test('4. Generates Loyalty points & rewards template correctly', () {
      final text = CustomerWhatsAppDialog.generateTemplateText(
        customer: testCustomer,
        storeName: testStoreName,
        customerSettings: testSettings,
        category: WhatsAppTemplateCategory.loyalty,
      );

      expect(text, contains("420 Loyalty Reward Points"));
      expect(text, contains("Status: *VIP*"));
      expect(text, contains("₹420"));
    });

    test('5. Generates Seasonal & Festive greetings template correctly', () {
      final text = CustomerWhatsAppDialog.generateTemplateText(
        customer: testCustomer,
        storeName: testStoreName,
        customerSettings: testSettings,
        category: WhatsAppTemplateCategory.seasonal,
      );

      expect(text, contains("Warm Festive & Seasonal Greetings"));
      expect(text, contains("Sharma Supermarket"));
      expect(text, contains("festive discounts"));
    });

    test('6. Generates Payment Received / Settlement receipt template correctly', () {
      final text = CustomerWhatsAppDialog.generateTemplateText(
        customer: testCustomer,
        storeName: testStoreName,
        customerSettings: testSettings,
        category: WhatsAppTemplateCategory.paymentReceived,
        customAmount: 2000.0,
      );

      expect(text, contains("received and recorded your payment of *₹2000*"));
      expect(text, contains("Updated Khata Balance: *₹3450*"));
    });

    test('7. Fallback gracefully when storeName or customer name is blank', () {
      final emptyCustomer = Customer(
        id: 'cust_empty',
        storeId: 'store_empty',
        name: '',
        email: '',
        joinDate: DateTime(2025, 1, 1),
        totalSpent: 0.0,
        loyaltyPoints: 0,
        tier: '',
      );

      final text = CustomerWhatsAppDialog.generateTemplateText(
        customer: emptyCustomer,
        storeName: '',
        customerSettings: null,
        category: WhatsAppTemplateCategory.custom,
      );

      expect(text, contains("Namaste Valued Customer"));
      expect(text, contains("BizPOS Store"));
    });
  });
}
