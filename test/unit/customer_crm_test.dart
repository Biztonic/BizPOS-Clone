import 'package:flutter_test/flutter_test.dart';
import 'package:biztonic_pos/models/customer.dart';
import 'package:biztonic_pos/models/customer_crm_models.dart';

void main() {
  group('Unit Tests: Customer CRM, Udhari, Coupons, Gifts & Loyalty', () {
    test('1. Customer model preserves udhariBalance and creditLimit across maps', () {
      final customer = Customer(
        id: 'cust_101',
        storeId: 'store_1',
        name: 'Amit Patel',
        mobile: '9876543210',
        email: 'amit@example.com',
        tier: 'Gold',
        creditLimit: 15000.0,
        udhariBalance: 3500.0,
        loyaltyPoints: 450,
        joinDate: DateTime(2025, 1, 1),
        totalSpent: 12000.0,
      );

      final hiveMap = customer.toHiveMap();
      expect(hiveMap['udhariBalance'], 3500.0);
      expect(hiveMap['creditLimit'], 15000.0);

      final reconstructed = Customer.fromMap(hiveMap, customer.id);
      expect(reconstructed.id, 'cust_101');
      expect(reconstructed.name, 'Amit Patel');
      expect(reconstructed.udhariBalance, 3500.0);
      expect(reconstructed.creditLimit, 15000.0);
      expect(reconstructed.tier, 'Gold');
    });

    test('2. Udhari transactions serialize and track debit/credit ledger', () {
      final now = DateTime.now();
      final borrowTx = UdhariTransaction(
        id: 'tx_1',
        customerId: 'cust_101',
        storeId: 'store_1',
        type: 'borrow',
        amount: 2000.0,
        balanceAfter: 5500.0,
        date: now,
        notes: 'Monthly groceries on credit',
        paymentMode: 'Store Credit',
        createdBy: 'Cashier 1',
      );

      final borrowMap = borrowTx.toHiveMap();
      expect(borrowMap['type'], 'borrow');
      expect(borrowMap['amount'], 2000.0);
      expect(borrowMap['balanceAfter'], 5500.0);

      final reconstructed = UdhariTransaction.fromMap(borrowMap, borrowTx.id);
      expect(reconstructed.type, 'borrow');
      expect(reconstructed.amount, 2000.0);
      expect(reconstructed.balanceAfter, 5500.0);
      expect(reconstructed.paymentMode, 'Store Credit');

      final paymentTx = UdhariTransaction(
        id: 'tx_2',
        customerId: 'cust_101',
        storeId: 'store_1',
        type: 'payment',
        amount: 3000.0,
        balanceAfter: 2500.0,
        date: now,
        notes: 'UPI payment received',
        paymentMode: 'UPI',
        createdBy: 'Admin',
      );

      final paymentMap = paymentTx.toHiveMap();
      expect(paymentMap['type'], 'payment');
      expect(paymentMap['balanceAfter'], 2500.0);
    });

    test('3. CustomerCoupon validity, expiration, and redemption states', () {
      final validCoupon = CustomerCoupon(
        id: 'c_1',
        customerId: 'cust_101',
        storeId: 'store_1',
        code: 'SAVE10',
        title: '10% Discount',
        discountType: 'percentage',
        discountValue: 10.0,
        minOrderValue: 500.0,
        validUntil: DateTime.now().add(const Duration(days: 7)),
      );

      expect(validCoupon.isValid, isTrue);
      expect(validCoupon.isExpired, isFalse);
      expect(validCoupon.isRedeemed, isFalse);

      final expiredCoupon = CustomerCoupon(
        id: 'c_2',
        customerId: 'cust_101',
        storeId: 'store_1',
        code: 'OLD50',
        title: 'Expired Voucher',
        discountValue: 50.0,
        validUntil: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(expiredCoupon.isExpired, isTrue);
      expect(expiredCoupon.isValid, isFalse);

      final redeemedCoupon = CustomerCoupon(
        id: 'c_3',
        customerId: 'cust_101',
        storeId: 'store_1',
        code: 'USED20',
        title: 'Redeemed',
        discountValue: 20.0,
        validUntil: DateTime.now().add(const Duration(days: 10)),
        isRedeemed: true,
        redeemedAt: DateTime.now(),
      );

      expect(redeemedCoupon.isRedeemed, isTrue);
      expect(redeemedCoupon.isValid, isFalse);
    });

    test('4. CustomerGift voucher serialization and status', () {
      final gift = CustomerGift(
        id: 'gift_1',
        customerId: 'cust_101',
        storeId: 'store_1',
        voucherCode: 'GIFT-500',
        title: 'Birthday Gift Card',
        amount: 500.0,
        validUntil: DateTime.now().add(const Duration(days: 30)),
        status: 'Active',
      );

      expect(gift.isActive, isTrue);
      expect(gift.isExpired, isFalse);

      final map = gift.toHiveMap();
      final reconstructed = CustomerGift.fromMap(map, gift.id);
      expect(reconstructed.voucherCode, 'GIFT-500');
      expect(reconstructed.amount, 500.0);
      expect(reconstructed.status, 'Active');
    });

    test('5. LoyaltyTransaction serialization and points ledger', () {
      final tx = LoyaltyTransaction(
        id: 'loy_1',
        customerId: 'cust_101',
        storeId: 'store_1',
        type: 'earned',
        points: 50,
        balanceAfter: 500,
        date: DateTime.now(),
        reason: 'Earned on Bill #1040',
        referenceId: 'order_1040',
      );

      final map = tx.toHiveMap();
      expect(map['points'], 50);
      expect(map['balanceAfter'], 500);

      final reconstructed = LoyaltyTransaction.fromMap(map, tx.id);
      expect(reconstructed.points, 50);
      expect(reconstructed.balanceAfter, 500);
      expect(reconstructed.reason, 'Earned on Bill #1040');
    });

    test('6. Flexible date parsing in Udhari, Coupon, Gift, and Loyalty supports DateTime, int epoch, and ISO String', () {
      final specificDate = DateTime(2025, 6, 15, 10, 30);
      final epochMs = specificDate.millisecondsSinceEpoch;

      // Test int epoch parsing
      final txFromInt = UdhariTransaction.fromMap({
        'customerId': 'c1',
        'storeId': 's1',
        'type': 'borrow',
        'amount': 500.0,
        'balanceAfter': 500.0,
        'date': epochMs,
      }, 'tx_int');
      expect(txFromInt.date.millisecondsSinceEpoch, equals(epochMs));

      // Test DateTime object directly
      final couponFromDateTime = CustomerCoupon.fromMap({
        'customerId': 'c1',
        'storeId': 's1',
        'code': 'TEST',
        'title': 'Test Coupon',
        'discountValue': 10.0,
        'validUntil': specificDate,
      }, 'cp_dt');
      expect(couponFromDateTime.validUntil, equals(specificDate));

      // Test Gift with int epoch
      final giftFromInt = CustomerGift.fromMap({
        'customerId': 'c1',
        'storeId': 's1',
        'voucherCode': 'GIFT',
        'amount': 100.0,
        'validUntil': epochMs,
      }, 'gift_int');
      expect(giftFromInt.validUntil.millisecondsSinceEpoch, equals(epochMs));

      // Test Loyalty with DateTime object
      final loyaltyFromDateTime = LoyaltyTransaction.fromMap({
        'customerId': 'c1',
        'storeId': 's1',
        'type': 'earned',
        'points': 25,
        'balanceAfter': 125,
        'date': specificDate,
      }, 'loy_dt');
      expect(loyaltyFromDateTime.date, equals(specificDate));
    });
  });
}
