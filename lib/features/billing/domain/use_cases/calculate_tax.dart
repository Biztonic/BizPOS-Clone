/// Pure domain use case: Calculate tax for an order.
///
/// This encapsulates the Indian GST calculation rules as a
/// single-responsibility business operation.
///
/// No infrastructure imports allowed.
library;

import 'dart:math';
import 'package:biztonic_pos/core/base/use_case.dart';
import '../entities/order_entity.dart';

class CalculateTaxParams {
  final List<OrderItemEntity> items;
  final double taxRate; // Total tax rate (e.g., 5.0 for 5%)
  final double discountAmount;
  final bool isInterState;
  final bool roundToNearestRupee;

  const CalculateTaxParams({
    required this.items,
    required this.taxRate,
    this.discountAmount = 0.0,
    this.isInterState = false,
    this.roundToNearestRupee = false,
  });
}

class TaxResult {
  final double subtotal;
  final double cgst;
  final double sgst;
  final double igst;
  final double total;
  final double discount;
  final double taxableAmount;
  final double roundOff;

  const TaxResult({
    required this.subtotal,
    required this.cgst,
    required this.sgst,
    this.igst = 0.0,
    required this.total,
    required this.discount,
    this.taxableAmount = 0.0,
    this.roundOff = 0.0,
  });
}

/// Calculates GST split (CGST/SGST or IGST), rounding, and final total for an order.
///
/// Business Rules:
/// 1. Subtotal is sum of (item.price * item.quantity).
/// 2. Discount is clamped between 0.0 and subtotal.
/// 3. Taxable amount = max(0.0, subtotal - discount).
/// 4. Intra-state: CGST and SGST are equal halves of taxRate.
/// 5. Inter-state: IGST is full taxRate.
class CalculateTaxUseCase extends SyncUseCase<CalculateTaxParams, TaxResult> {
  @override
  TaxResult execute(CalculateTaxParams params) {
    final subtotal = params.items.fold<double>(
      0.0,
      (sum, item) => sum + item.lineTotal,
    );

    // Clamp discount between 0.0 and subtotal
    final clampedDiscount = max(0.0, min(params.discountAmount, subtotal));
    final taxableAmount = max(0.0, subtotal - clampedDiscount);

    double cgst = 0.0;
    double sgst = 0.0;
    double igst = 0.0;

    if (params.taxRate > 0 && taxableAmount > 0) {
      if (params.isInterState) {
        igst = taxableAmount * (params.taxRate / 100);
      } else {
        final halfRate = params.taxRate / 2;
        cgst = taxableAmount * (halfRate / 100);
        sgst = taxableAmount * (halfRate / 100);
      }
    }

    final unroundedTotal = taxableAmount + cgst + sgst + igst;

    double total = unroundedTotal;
    double roundOff = 0.0;

    if (params.roundToNearestRupee) {
      total = unroundedTotal.roundToDouble();
      roundOff = total - unroundedTotal;
    }

    return TaxResult(
      subtotal: subtotal,
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      total: total,
      discount: clampedDiscount,
      taxableAmount: taxableAmount,
      roundOff: roundOff,
    );
  }
}
