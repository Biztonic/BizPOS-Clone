/// Domain policies for discount calculation and validation.
///
/// Pure business rules — no infrastructure dependencies.
library;

import 'order_policy.dart';

class DiscountPolicy {
  /// Validates a percentage discount. Must be in the range [0.0, 100.0].
  static ValidationResult validatePercentage(double percentage) {
    if (percentage < 0.0) {
      return const ValidationResult.invalid(
          'Discount percentage cannot be negative.');
    }
    if (percentage > 100.0) {
      return const ValidationResult.invalid(
          'Discount percentage cannot exceed 100%.');
    }
    return const ValidationResult.valid();
  }

  /// Validates a fixed amount discount against the cart subtotal.
  static ValidationResult validateAmount(double amount, double subtotal) {
    if (amount < 0.0) {
      return const ValidationResult.invalid(
          'Discount amount cannot be negative.');
    }
    if (amount > subtotal) {
      return const ValidationResult.invalid(
        'Discount amount cannot exceed the order subtotal.',
      );
    }
    return const ValidationResult.valid();
  }

  /// Validates eligibility for a coupon discount requiring a minimum order value.
  static ValidationResult validateCoupon({
    required double subtotal,
    required double minOrderValue,
  }) {
    if (subtotal < minOrderValue) {
      return ValidationResult.invalid(
        'Order subtotal ($subtotal) does not meet the minimum required coupon threshold ($minOrderValue).',
      );
    }
    return const ValidationResult.valid();
  }

  /// Calculates effective discount with optional maximum cap.
  static double applyDiscountCap({
    required double calculatedDiscount,
    double? maxDiscountCap,
  }) {
    if (calculatedDiscount <= 0.0) return 0.0;
    if (maxDiscountCap != null && maxDiscountCap > 0.0) {
      return calculatedDiscount > maxDiscountCap
          ? maxDiscountCap
          : calculatedDiscount;
    }
    return calculatedDiscount;
  }
}
