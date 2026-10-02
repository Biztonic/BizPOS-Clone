import 'package:flutter_test/flutter_test.dart';
import 'package:biztonic_pos/features/billing/domain/entities/order_entity.dart';
import 'package:biztonic_pos/features/crm/domain/entities/customer.dart';
import 'package:biztonic_pos/models/customer_crm_models.dart';

void main() {
  group('Unit Tests: Udhari (Khata Credit), Payment Methods & Settlement Lifecycle', () {
    test('1. PaymentMethod enum contains udhari and handles case-insensitive string parsing', () {
      expect(PaymentMethod.udhari.value, 'Udhari');
      expect(PaymentMethod.fromString('Udhari'), PaymentMethod.udhari);
      expect(PaymentMethod.fromString('udhari'), PaymentMethod.udhari);
      expect(PaymentMethod.fromString('UDHARI'), PaymentMethod.udhari);
      expect(PaymentMethod.fromString('cash'), PaymentMethod.cash);
      expect(PaymentMethod.fromString('upi'), PaymentMethod.upi);
      expect(PaymentMethod.fromString('split'), PaymentMethod.split);
    });

    test('2. OrderEntity holds customer details and udhari payment method', () {
      final order = OrderEntity(
        id: 'ORD_UDHARI_101',
        storeId: 'STORE_001',
        items: const [
          OrderItemEntity(
            itemId: 'ITEM_001',
            itemName: 'Organic Basmati Rice 5kg',
            price: 450.0,
            cost: 320.0,
            quantity: 2,
          )
        ],
        total: 900.0,
        subtotal: 900.0,
        paymentMethod: PaymentMethod.udhari,
        customerId: 'CUST_42',
        customerName: 'Rahul Sharma',
        customerPhone: '9876543210',
        date: DateTime.now(),
      );

      expect(order.paymentMethod, PaymentMethod.udhari);
      expect(order.customerId, 'CUST_42');
      expect(order.customerName, 'Rahul Sharma');
      expect(order.customerPhone, '9876543210');
      expect(order.total, 900.0);
    });

    test('3. UdhariTransaction serialization round-trip (Borrow & Repayment)', () {
      final txBorrow = UdhariTransaction(
        id: 'TX_BORROW_001',
        customerId: 'CUST_42',
        storeId: 'STORE_001',
        type: 'borrow',
        amount: 900.0,
        balanceAfter: 900.0,
        date: DateTime(2026, 9, 27, 10, 0),
        referenceId: 'ORD_UDHARI_101',
        paymentMode: 'Udhari (Full Credit)',
        notes: 'Monthly grocery bill',
        createdBy: 'Cashier 1',
      );

      final map = txBorrow.toMap();
      expect(map['customerId'], 'CUST_42');
      expect(map['type'], 'borrow');
      expect(map['amount'], 900.0);
      expect(map['balanceAfter'], 900.0);
      expect(map['referenceId'], 'ORD_UDHARI_101');

      final reconstructed = UdhariTransaction.fromMap(map, txBorrow.id);
      expect(reconstructed.id, 'TX_BORROW_001');
      expect(reconstructed.amount, 900.0);
      expect(reconstructed.balanceAfter, 900.0);
      expect(reconstructed.type, 'borrow');
      expect(reconstructed.paymentMode, 'Udhari (Full Credit)');
    });

    test('4. Full lifecycle: Initial Borrow -> Partial Order Borrow -> Later Stage Partial Repayment -> Full Settlement', () {
      // Step A: New customer with zero balance
      var customer = Customer(
        id: 'CUST_100',
        storeId: 'STORE_001',
        name: 'Vikas Patel',
        email: 'vikas@example.com',
        phone: '9988776655',
        joinDate: DateTime.now(),
        totalSpent: 0,
        loyaltyPoints: 0,
        tier: 'Bronze',
        udhariBalance: 0.0,
        creditLimit: 5000.0,
      );

      expect(customer.udhariBalance, 0.0);

      // Step B: Customer buys ₹500 goods on 100% Full Udhari
      const bill1Total = 500.0;
      final tx1 = UdhariTransaction(
        id: 'TX_001',
        customerId: customer.id,
        storeId: customer.storeId,
        type: 'borrow',
        amount: bill1Total,
        balanceAfter: customer.udhariBalance + bill1Total,
        date: DateTime.now(),
        referenceId: 'ORD_001',
        paymentMode: 'Udhari (Full Credit)',
      );

      customer = customer.copyWith(
        udhariBalance: tx1.balanceAfter,
      );
      expect(customer.udhariBalance, 500.0);

      // Step C: Customer buys ₹1200 goods, asks for Partial Payment (pays ₹400 upfront via Cash, remaining ₹800 on Udhari)
      const bill2Total = 1200.0;
      const upfrontPaid = 400.0;
      const remainingUdhari = bill2Total - upfrontPaid; // ₹800
      expect(remainingUdhari, 800.0);

      final tx2 = UdhariTransaction(
        id: 'TX_002',
        customerId: customer.id,
        storeId: customer.storeId,
        type: 'borrow',
        amount: remainingUdhari,
        balanceAfter: customer.udhariBalance + remainingUdhari,
        date: DateTime.now(),
        referenceId: 'ORD_002',
        paymentMode: 'Partial (Cash: ₹400.00, Udhari: ₹800.00)',
      );

      customer = customer.copyWith(
        udhariBalance: tx2.balanceAfter,
      );
      // Previous 500 + New 800 = 1300
      expect(customer.udhariBalance, 1300.0);

      // Step D: Later Stage Repayment - Customer pays ₹600 via UPI to partially settle
      const partialSettlement = 600.0;
      final balanceAfterPartialPayment = (customer.udhariBalance - partialSettlement).clamp(0.0, double.infinity);
      final tx3 = UdhariTransaction(
        id: 'TX_003',
        customerId: customer.id,
        storeId: customer.storeId,
        type: 'payment',
        amount: partialSettlement,
        balanceAfter: balanceAfterPartialPayment,
        date: DateTime.now(),
        paymentMode: 'UPI',
        referenceId: 'UPI_REF_998124',
        notes: 'Partial settlement via GPay',
      );

      customer = customer.copyWith(
        udhariBalance: tx3.balanceAfter,
      );
      // 1300 - 600 = 700
      expect(customer.udhariBalance, 700.0);

      // Step E: Final Settlement - Customer clears remaining ₹700 in Cash
      const fullSettlement = 700.0;
      final balanceAfterFinalPayment = (customer.udhariBalance - fullSettlement).clamp(0.0, double.infinity);
      final tx4 = UdhariTransaction(
        id: 'TX_004',
        customerId: customer.id,
        storeId: customer.storeId,
        type: 'payment',
        amount: fullSettlement,
        balanceAfter: balanceAfterFinalPayment,
        date: DateTime.now(),
        paymentMode: 'Cash',
        notes: 'Full balance settled',
      );

      customer = customer.copyWith(
        udhariBalance: tx4.balanceAfter,
      );
      // 700 - 700 = 0
      expect(customer.udhariBalance, 0.0);
    });
  });
}
