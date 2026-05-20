import 'package:flutter_test/flutter_test.dart';
import 'package:biztonic_pos/features/billing/domain/entities/order_entity.dart';
import 'package:biztonic_pos/features/billing/domain/use_cases/calculate_tax.dart';

void main() {
  group('CalculateTaxUseCase Tests', () {
    final useCase = CalculateTaxUseCase();

    test('Should calculate correct CGST, SGST and total without discount', () {
      const items = [
        OrderItemEntity(
          itemId: 'item_1',
          itemName: 'Item 1',
          price: 100.0,
          cost: 60.0,
          quantity: 2,
        ),
        OrderItemEntity(
          itemId: 'item_2',
          itemName: 'Item 2',
          price: 50.0,
          cost: 30.0,
          quantity: 1,
        ),
      ];

      // Total subtotal = (100 * 2) + (50 * 1) = 250
      // Tax rate = 18% -> CGST = 9%, SGST = 9%
      // CGST = 250 * 0.09 = 22.50
      // SGST = 250 * 0.09 = 22.50
      // Total = 250 + 22.50 + 22.50 = 295.0

      final result = useCase.execute(const CalculateTaxParams(
        items: items,
        taxRate: 18.0,
        discountAmount: 0.0,
      ));

      expect(result.subtotal, 250.0);
      expect(result.discount, 0.0);
      expect(result.cgst, 22.50);
      expect(result.sgst, 22.50);
      expect(result.total, 295.0);
    });

    test('Should calculate correct tax after applying discount', () {
      const items = [
        OrderItemEntity(
          itemId: 'item_1',
          itemName: 'Item 1',
          price: 100.0,
          cost: 60.0,
          quantity: 2,
        ),
      ];

      // Subtotal = 200.0
      // Discount = 20.0
      // Taxable amount = 180.0
      // Tax rate = 5% -> CGST = 2.5%, SGST = 2.5%
      // CGST = 180 * 0.025 = 4.5
      // SGST = 180 * 0.025 = 4.5
      // Total = 180 + 4.5 + 4.5 = 189.0

      final result = useCase.execute(const CalculateTaxParams(
        items: items,
        taxRate: 5.0,
        discountAmount: 20.0,
      ));

      expect(result.subtotal, 200.0);
      expect(result.discount, 20.0);
      expect(result.cgst, 4.5);
      expect(result.sgst, 4.5);
      expect(result.total, 189.0);
    });

    test('Should handle zero tax rate correctly', () {
      const items = [
        OrderItemEntity(
          itemId: 'item_1',
          itemName: 'Item 1',
          price: 100.0,
          cost: 60.0,
          quantity: 1,
        ),
      ];

      final result = useCase.execute(const CalculateTaxParams(
        items: items,
        taxRate: 0.0,
      ));

      expect(result.subtotal, 100.0);
      expect(result.discount, 0.0);
      expect(result.cgst, 0.0);
      expect(result.sgst, 0.0);
      expect(result.total, 100.0);
    });
  });
}
