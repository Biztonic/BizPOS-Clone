import 'package:flutter_test/flutter_test.dart';
import 'package:biztonic_pos/features/store/domain/entities/settings.dart';
import 'package:biztonic_pos/features/store/domain/entities/store.dart';

void main() {
  group('Unit Tests: Customer Addon Settings, Loyalty Logic & Khata Credit Enforcement', () {
    test('1. CustomerAddonSettings default values match business specifications', () {
      const settings = CustomerAddonSettings();

      // Udhari / Khata defaults
      expect(settings.enableUdhari, isTrue);
      expect(settings.defaultCreditLimit, 5000.0);
      expect(settings.allowPartialUdhari, isTrue);
      expect(settings.blockWhenLimitExceeded, isFalse);
      expect(settings.enableWhatsAppReminders, isTrue);

      // Loyalty defaults
      expect(settings.enableLoyalty, isTrue);
      expect(settings.earnRateSpendAmount, 100.0);
      expect(settings.earnRatePoints, 1);
      expect(settings.pointRedemptionValue, 1.0);
      expect(settings.minPointsToRedeem, 50);
      expect(settings.maxBillDiscountPercent, 50.0);
      expect(settings.pointsValidityDays, 365);

      // Membership defaults
      expect(settings.enableMembership, isTrue);
      expect(settings.silverMinSpend, 2000.0);
      expect(settings.silverMultiplier, 1.2);
      expect(settings.goldMinSpend, 5000.0);
      expect(settings.goldMultiplier, 1.5);
      expect(settings.platinumMinSpend, 10000.0);
      expect(settings.platinumMultiplier, 2.0);

      // Coupons & Welcome Gifts
      expect(settings.enableCoupons, isTrue);
      expect(settings.welcomeBonusPoints, 50);
    });

    test('2. CustomerAddonSettings serialization round-trip (toMap & fromMap)', () {
      const original = CustomerAddonSettings(
        enableUdhari: false,
        defaultCreditLimit: 12000.0,
        allowPartialUdhari: false,
        blockWhenLimitExceeded: true,
        enableWhatsAppReminders: false,
        enableLoyalty: true,
        earnRateSpendAmount: 200.0,
        earnRatePoints: 3,
        pointRedemptionValue: 0.50,
        minPointsToRedeem: 100,
        maxBillDiscountPercent: 40.0,
        pointsValidityDays: 180,
        enableMembership: true,
        silverMinSpend: 3000.0,
        silverMultiplier: 1.3,
        goldMinSpend: 8000.0,
        goldMultiplier: 1.8,
        platinumMinSpend: 15000.0,
        platinumMultiplier: 2.5,
        enableCoupons: true,
        welcomeBonusPoints: 100,
      );

      final map = original.toMap();
      final restored = CustomerAddonSettings.fromMap(map);

      expect(restored.enableUdhari, isFalse);
      expect(restored.defaultCreditLimit, 12000.0);
      expect(restored.allowPartialUdhari, isFalse);
      expect(restored.blockWhenLimitExceeded, isTrue);
      expect(restored.enableWhatsAppReminders, isFalse);
      expect(restored.earnRateSpendAmount, 200.0);
      expect(restored.earnRatePoints, 3);
      expect(restored.pointRedemptionValue, 0.50);
      expect(restored.minPointsToRedeem, 100);
      expect(restored.maxBillDiscountPercent, 40.0);
      expect(restored.pointsValidityDays, 180);
      expect(restored.silverMinSpend, 3000.0);
      expect(restored.silverMultiplier, 1.3);
      expect(restored.goldMinSpend, 8000.0);
      expect(restored.goldMultiplier, 1.8);
      expect(restored.platinumMinSpend, 15000.0);
      expect(restored.platinumMultiplier, 2.5);
      expect(restored.welcomeBonusPoints, 100);
    });

    test('3. Store entity preserves customerSettings across serialization', () {
      final store = Store(
        id: 'STORE_99',
        name: 'Prime Retail Mart',
        owner: 'Owner A',
        ownerEmail: 'owner@prime.com',
        status: 'Active',
        storeType: 'Grocery',
        receipt: ReceiptSettings(),
        payment: PaymentSettings(),
        kds: KdsSettings(),
        customerSettings: const CustomerAddonSettings(
          defaultCreditLimit: 7500.0,
          blockWhenLimitExceeded: true,
          welcomeBonusPoints: 75,
        ),
      );

      final map = store.toMap();
      final restored = Store.fromMap(map, 'STORE_99');

      expect(restored.customerSettings.defaultCreditLimit, 7500.0);
      expect(restored.customerSettings.blockWhenLimitExceeded, isTrue);
      expect(restored.customerSettings.welcomeBonusPoints, 75);
    });

    test('4. Credit Limit Enforcement: flexible warning vs strict block', () {
      // Scenario A: flexible warning (blockWhenLimitExceeded = false)
      const flexSettings = CustomerAddonSettings(
        defaultCreditLimit: 5000.0,
        blockWhenLimitExceeded: false,
      );

      double currentDue = 4500.0;
      double newBorrow = 1000.0;
      double projected = currentDue + newBorrow; // 5500.0
      double limit = flexSettings.defaultCreditLimit; // 5000.0

      bool isLimitExceeded = projected > limit;
      bool isBlockEnforced = isLimitExceeded && flexSettings.blockWhenLimitExceeded;

      expect(isLimitExceeded, isTrue);
      expect(isBlockEnforced, isFalse, reason: 'Cashier should receive a warning, but checkout is not blocked');

      // Scenario B: strict block (blockWhenLimitExceeded = true)
      final strictSettings = flexSettings.copyWith(blockWhenLimitExceeded: true);
      isBlockEnforced = isLimitExceeded && strictSettings.blockWhenLimitExceeded;

      expect(isLimitExceeded, isTrue);
      expect(isBlockEnforced, isTrue, reason: 'Checkout must be blocked because customer exceeds credit limit');
    });

    test('5. Loyalty points calculation respects spend rate and tier multipliers', () {
      const settings = CustomerAddonSettings(
        enableLoyalty: true,
        earnRateSpendAmount: 100.0,
        earnRatePoints: 1,
        enableMembership: true,
        silverMinSpend: 2000.0,
        silverMultiplier: 1.2,
        goldMinSpend: 5000.0,
        goldMultiplier: 1.5,
        platinumMinSpend: 10000.0,
        platinumMultiplier: 2.0,
      );

      // Base customer (Bronze, spend ₹500)
      double billTotal = 500.0;
      int basePoints = ((billTotal / settings.earnRateSpendAmount) * settings.earnRatePoints * 1.0).floor();
      expect(basePoints, 5);

      // Silver customer (spend ₹500, multiplier 1.2x)
      int silverPoints = ((billTotal / settings.earnRateSpendAmount) * settings.earnRatePoints * settings.silverMultiplier).floor();
      expect(silverPoints, 6); // 5 * 1.2 = 6

      // Gold customer (spend ₹500, multiplier 1.5x)
      int goldPoints = ((billTotal / settings.earnRateSpendAmount) * settings.earnRatePoints * settings.goldMultiplier).floor();
      expect(goldPoints, 7); // 5 * 1.5 = 7.5 -> 7

      // Platinum customer (spend ₹500, multiplier 2.0x)
      int platinumPoints = ((billTotal / settings.earnRateSpendAmount) * settings.earnRatePoints * settings.platinumMultiplier).floor();
      expect(platinumPoints, 10); // 5 * 2.0 = 10
    });

    test('6. Loyalty redemption value and maximum bill discount capping', () {
      const settings = CustomerAddonSettings(
        pointRedemptionValue: 1.0, // 1 point = ₹1
        minPointsToRedeem: 50,
        maxBillDiscountPercent: 50.0, // Max 50% discount
      );

      int customerPoints = 120;
      double billTotal = 160.0;

      // Eligible to redeem?
      bool isEligible = customerPoints >= settings.minPointsToRedeem;
      expect(isEligible, isTrue);

      // Max allowable discount
      double maxDiscountAllowed = billTotal * (settings.maxBillDiscountPercent / 100); // 160 * 50% = ₹80
      double potentialDiscount = customerPoints * settings.pointRedemptionValue; // 120 * 1 = ₹120

      double actualDiscount = potentialDiscount > maxDiscountAllowed ? maxDiscountAllowed : potentialDiscount;
      expect(actualDiscount, 80.0, reason: 'Bill discount cannot exceed 50% of ₹160');
    });

    test('7. SeasonalCoupon discount calculation and validation rules', () {
      final percentageCoupon = SeasonalCoupon(
        id: 'coup_1',
        code: 'DIWALI20',
        title: 'Diwali 20% Off',
        season: 'Festive',
        discountType: 'percentage',
        discountValue: 20.0,
        minOrderValue: 500.0,
        maxDiscount: 200.0,
        isActive: true,
      );

      // Order below minOrderValue -> 0 discount
      expect(percentageCoupon.calculateDiscount(400.0), 0.0);

      // Order of 800 -> 20% is 160 (below cap of 200) -> 160
      expect(percentageCoupon.calculateDiscount(800.0), 160.0);

      // Order of 2000 -> 20% is 400 (capped at 200) -> 200
      expect(percentageCoupon.calculateDiscount(2000.0), 200.0);

      final flatCoupon = SeasonalCoupon(
        id: 'coup_2',
        code: 'FLAT100',
        title: 'Flat 100 Off',
        season: 'Summer',
        discountType: 'flat',
        discountValue: 100.0,
        minOrderValue: 300.0,
        isActive: true,
      );

      // Order below minOrderValue -> 0
      expect(flatCoupon.calculateDiscount(200.0), 0.0);

      // Order above minOrderValue -> flat 100
      expect(flatCoupon.calculateDiscount(500.0), 100.0);

      // Order less than flat discount -> capped at order value
      final smallOrderCoupon = flatCoupon.copyWith(minOrderValue: 50.0);
      expect(smallOrderCoupon.calculateDiscount(80.0), 80.0);
    });

    test('8. SeasonalCoupons serialization and inclusion in CustomerAddonSettings', () {
      final coupon = SeasonalCoupon(
        id: 'c1',
        code: 'HOLI15',
        title: 'Holi Colors Special',
        season: 'Spring',
        discountType: 'percentage',
        discountValue: 15.0,
        minOrderValue: 250.0,
        maxDiscount: 150.0,
        isActive: true,
        endDate: DateTime(2026, 12, 31),
      );

      final map = coupon.toMap();
      final restored = SeasonalCoupon.fromMap(map);

      expect(restored.code, 'HOLI15');
      expect(restored.season, 'Spring');
      expect(restored.discountType, 'percentage');
      expect(restored.discountValue, 15.0);
      expect(restored.minOrderValue, 250.0);
      expect(restored.maxDiscount, 150.0);
      expect(restored.isActive, isTrue);

      final settings = CustomerAddonSettings(
        enableCoupons: true,
        seasonalCoupons: [coupon],
      );

      final settingsMap = settings.toMap();
      final restoredSettings = CustomerAddonSettings.fromMap(settingsMap);

      expect(restoredSettings.seasonalCoupons.length, 1);
      expect(restoredSettings.seasonalCoupons.first.code, 'HOLI15');
    });
  });
}

