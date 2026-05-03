/// Pure domain use case: Calculate tax for an order.
///
/// This encapsulates the Indian GST calculation rules as a
/// single-responsibility business operation.
///
/// No infrastructure imports allowed.

import 'package:biztonic_pos/core/base/use_case.dart';
import '../entities/order_entity.dart';

class CalculateTaxParams {
  final List<OrderItemEntity> items;
  final double taxRate; // Total tax rate (e.g., 5.0 for 5%)
  final double discountAmount;

  const CalculateTaxParams({
    required this.items,
    required this.taxRate,
    this.discountAmount = 0.0,
  });
}

class TaxResult {
  final double subtotal;
  final double cgst;
  final double sgst;
  final double total;
  final double discount;

  const TaxResult({
    required this.subtotal,
    required this.cgst,
    required this.sgst,
    required this.total,
    required this.discount,
  });
}

/// Calculates GST split (CGST/SGST) and final total for an order.
///
/// Business Rule: Tax is calculated on (subtotal - discount).
/// CGST and SGST are always equal halves of the total tax rate.
class CalculateTaxUseCase extends SyncUseCase<CalculateTaxParams, TaxResult> {
  @override
  TaxResult execute(CalculateTaxParams params) {
    final subtotal = params.items.fold<double>(
      0.0,
      (sum, item) => sum + item.lineTotal,
    );

    final taxableAmount = subtotal - params.discountAmount;
    final halfRate = params.taxRate / 2;
    final cgst = taxableAmount * (halfRate / 100);
    final sgst = taxableAmount * (halfRate / 100);
    final total = taxableAmount + cgst + sgst;

    return TaxResult(
      subtotal: subtotal,
      cgst: cgst,
      sgst: sgst,
      total: total,
      discount: params.discountAmount,
    );
  }
}
