import 'package:flutter_test/flutter_test.dart';
import 'package:biztonic_pos/features/billing/domain/policies/discount_policy.dart';

void main() {
  group('Unit Tests: Discount Validation Policies', () {
    test('1. Percentage discount within valid range [0%, 100%] passes', () {
      expect(DiscountPolicy.validatePercentage(0.0).isValid, isTrue);
      expect(DiscountPolicy.validatePercentage(15.0).isValid, isTrue);
      expect(DiscountPolicy.validatePercentage(50.0).isValid, isTrue);
      expect(DiscountPolicy.validatePercentage(100.0).isValid, isTrue);
    });

    test('2. Negative percentage discount is rejected with meaningful error',
        () {
      final result = DiscountPolicy.validatePercentage(-5.0);
      expect(result.isValid, isFalse);
      expect(result.message, 'Discount percentage cannot be negative.');
    });

    test('3. Percentage discount exceeding 100% is rejected', () {
      final result = DiscountPolicy.validatePercentage(105.0);
      expect(result.isValid, isFalse);
      expect(result.message, 'Discount percentage cannot exceed 100%.');
    });

    test('4. Fixed amount discount within subtotal passes', () {
      expect(DiscountPolicy.validateAmount(50.0, 200.0).isValid, isTrue);
      expect(DiscountPolicy.validateAmount(200.0, 200.0).isValid, isTrue);
      expect(DiscountPolicy.validateAmount(0.0, 200.0).isValid, isTrue);
    });

    test('5. Fixed amount discount exceeding subtotal is rejected', () {
      final result = DiscountPolicy.validateAmount(250.0, 200.0);
      expect(result.isValid, isFalse);
      expect(
          result.message, 'Discount amount cannot exceed the order subtotal.');
    });

    test('6. Negative fixed amount discount is rejected', () {
      final result = DiscountPolicy.validateAmount(-10.0, 200.0);
      expect(result.isValid, isFalse);
      expect(result.message, 'Discount amount cannot be negative.');
    });

    test('7. Minimum order value coupon threshold validation', () {
      final validCoupon = DiscountPolicy.validateCoupon(
        subtotal: 500.0,
        minOrderValue: 400.0,
      );
      expect(validCoupon.isValid, isTrue);

      final invalidCoupon = DiscountPolicy.validateCoupon(
        subtotal: 350.0,
        minOrderValue: 400.0,
      );
      expect(invalidCoupon.isValid, isFalse);
      expect(
          invalidCoupon.message, contains('minimum required coupon threshold'));
    });

    test('8. Maximum discount cap restricts excessive discount values', () {
      // 20% on 1000 = 200 discount, but cap is 150 -> returns 150
      final capped = DiscountPolicy.applyDiscountCap(
        calculatedDiscount: 200.0,
        maxDiscountCap: 150.0,
      );
      expect(capped, 150.0);

      // Discount within cap -> returns full discount
      final uncapped = DiscountPolicy.applyDiscountCap(
        calculatedDiscount: 100.0,
        maxDiscountCap: 150.0,
      );
      expect(uncapped, 100.0);

      // Zero or negative input
      expect(
          DiscountPolicy.applyDiscountCap(
              calculatedDiscount: 0.0, maxDiscountCap: 100.0),
          0.0);
      expect(
          DiscountPolicy.applyDiscountCap(
              calculatedDiscount: -50.0, maxDiscountCap: 100.0),
          0.0);
    });
  });
}
