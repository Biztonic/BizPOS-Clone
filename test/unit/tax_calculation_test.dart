import 'package:flutter_test/flutter_test.dart';
import 'package:biztonic_pos/features/billing/domain/entities/order_entity.dart';
import 'package:biztonic_pos/features/billing/domain/use_cases/calculate_tax.dart';

void main() {
  group('Unit Tests: Tax Calculation (GST Compliance & Multi-Slab)', () {
    final useCase = CalculateTaxUseCase();

    test('1. Standard CGST and SGST equal split on undiscounted order', () {
      const items = [
        OrderItemEntity(
          itemId: 'ITEM_BURGER',
          itemName: 'Burger',
          price: 150.0,
          cost: 80.0,
          quantity: 2, // 300.0
        ),
        OrderItemEntity(
          itemId: 'ITEM_FRIES',
          itemName: 'Fries',
          price: 100.0,
          cost: 40.0,
          quantity: 1, // 100.0
        ),
      ];

      // Subtotal = 400.0
      // GST Rate = 18.0% -> CGST = 9.0%, SGST = 9.0%
      // CGST = 400 * 0.09 = 36.00
      // SGST = 400 * 0.09 = 36.00
      // Total = 400 + 36 + 36 = 472.00
      final result = useCase.execute(const CalculateTaxParams(
        items: items,
        taxRate: 18.0,
        discountAmount: 0.0,
      ));

      expect(result.subtotal, 400.0);
      expect(result.discount, 0.0);
      expect(result.cgst, 36.0);
      expect(result.sgst, 36.0);
      expect(result.total, 472.0);
    });

    test('2. Tax calculated strictly on net taxable amount after discount', () {
      const items = [
        OrderItemEntity(
          itemId: 'ITEM_PIZZA',
          itemName: 'Margherita Pizza',
          price: 500.0,
          cost: 200.0,
          quantity: 1,
        ),
      ];

      // Subtotal = 500.0
      // Flat Discount = 100.0
      // Net Taxable Amount = 400.0
      // GST Rate = 5.0% -> CGST = 2.5%, SGST = 2.5%
      // CGST = 400 * 0.025 = 10.00
      // SGST = 400 * 0.025 = 10.00
      // Total = 400 + 10 + 10 = 420.00
      final result = useCase.execute(const CalculateTaxParams(
        items: items,
        taxRate: 5.0,
        discountAmount: 100.0,
      ));

      expect(result.subtotal, 500.0);
      expect(result.discount, 100.0);
      expect(result.cgst, 10.0);
      expect(result.sgst, 10.0);
      expect(result.total, 420.0);
    });

    test('3. Zero percent tax rate (Tax-Exempt / Essential Goods)', () {
      const items = [
        OrderItemEntity(
          itemId: 'ITEM_MILK',
          itemName: 'Organic Milk 1L',
          price: 65.0,
          cost: 50.0,
          quantity: 3, // 195.0
        ),
      ];

      final result = useCase.execute(const CalculateTaxParams(
        items: items,
        taxRate: 0.0,
        discountAmount: 0.0,
      ));

      expect(result.subtotal, 195.0);
      expect(result.discount, 0.0);
      expect(result.cgst, 0.0);
      expect(result.sgst, 0.0);
      expect(result.total, 195.0);
    });

    test('4. Full 100% discount yields zero tax and zero total', () {
      const items = [
        OrderItemEntity(
          itemId: 'ITEM_COFFEE',
          itemName: 'Espresso',
          price: 120.0,
          cost: 30.0,
          quantity: 1,
        ),
      ];

      final result = useCase.execute(const CalculateTaxParams(
        items: items,
        taxRate: 18.0,
        discountAmount: 120.0,
      ));

      expect(result.subtotal, 120.0);
      expect(result.discount, 120.0);
      expect(result.cgst, 0.0);
      expect(result.sgst, 0.0);
      expect(result.total, 0.0);
    });

    test('5. Precision and fractional paise rounding consistency', () {
      const items = [
        OrderItemEntity(
          itemId: 'ITEM_ODD_PRICE',
          itemName: 'Special Item',
          price: 33.33,
          cost: 15.0,
          quantity: 3, // 99.99
        ),
      ];

      // Tax rate: 12.0% -> 6% CGST, 6% SGST
      // Taxable = 99.99
      // CGST = 99.99 * 0.06 = 5.9994
      // SGST = 99.99 * 0.06 = 5.9994
      // Total = 99.99 + 5.9994 + 5.9994 = 111.9888
      final result = useCase.execute(const CalculateTaxParams(
        items: items,
        taxRate: 12.0,
      ));

      expect(result.subtotal, closeTo(99.99, 0.0001));
      expect(result.cgst, closeTo(5.9994, 0.0001));
      expect(result.sgst, closeTo(5.9994, 0.0001));
      expect(result.total, closeTo(111.9888, 0.0001));
    });
  });
}
