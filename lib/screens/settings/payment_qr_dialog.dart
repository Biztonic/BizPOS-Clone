import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/tokens/app_typography.dart';

class PaymentQrDialog extends StatefulWidget {
  final String planType;
  final String billingCycle;
  final double amount;
  final String adminUpiId;
  final List<String> selectedAddons;
  final Map<String, dynamic> addonRates;

  const PaymentQrDialog({
    super.key,
    required this.planType,
    required this.billingCycle,
    required this.amount,
    required this.adminUpiId,
    this.selectedAddons = const [],
    this.addonRates = const {},
  });

  @override
  State<PaymentQrDialog> createState() => _PaymentQrDialogState();
}

class _PaymentQrDialogState extends State<PaymentQrDialog> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    // Generate UPI URL
    final upiUrl = "upi://pay?pa=${widget.adminUpiId}&pn=BizPOS&am=${widget.amount.toStringAsFixed(2)}&cu=INR&tn=Standard%20Plan%20${widget.billingCycle}";

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.payment, size: 48, color: AppColors.primary),
              const SizedBox(height: AppSpacing.md),
              Text(AppLocalizations.t(context, 'Complete Payment'),
                style: AppTypography.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "Scan the QR code below to pay ₹${widget.amount} for the ${widget.billingCycle} Standard Plan.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary(context)),
              ),
              if (widget.selectedAddons.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLightGrey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Column(
                    children: [
                      Row(children: [const Icon(Icons.list, size: 16, color: AppColors.primary), const SizedBox(width: AppSpacing.sm), Text(AppLocalizations.t(context, 'Breakdown'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
                      const Divider(),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("${widget.billingCycle} Plan"), Text("₹${(widget.amount - _calculateAddonsTotal(context)).toStringAsFixed(2)}")]),
                      ...widget.selectedAddons.map((key) => Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_getAddonTitle(key)), Text("₹${_getAddonPrice(key, widget.billingCycle, context).toStringAsFixed(2)}")]),
                      )),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: QrImageView(
                  data: upiUrl,
                  version: QrVersions.auto,
                  size: MediaQuery.of(context).size.height < 600 ? 150.0 : 200.0,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                "Total Amount: ₹${widget.amount}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                "UPI ID: ${widget.adminUpiId}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              const Text(
                "Once you've made the payment, click 'I HAVE PAID' to submit your request for approval.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: Text(AppLocalizations.t(context, 'CANCEL')),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _isSubmitting ? null : () async {
                        setState(() {
                          _isSubmitting = true;
                        });
                        try {
                          final provider = Provider.of<DashboardProvider>(context, listen: false);
                          await provider.createSubscriptionRequest(
                            planType: widget.planType,
                            billingCycle: widget.billingCycle,
                            amount: widget.amount,
                            selectedAddons: widget.selectedAddons,
                          );
                          if (context.mounted) {
                            Navigator.pop(context, true);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error),
                            );
                            setState(() {
                              _isSubmitting = false;
                            });
                          }
                        }
                      },
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(AppLocalizations.t(context, 'I HAVE PAID')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateAddonsTotal(BuildContext context) {
    double total = 0;
    for (var key in widget.selectedAddons) {
      total += _getAddonPrice(key, widget.billingCycle, context);
    }
    return total;
  }

  double _getAddonPrice(String key, String cycle, BuildContext context) {
    final monthlyRate = (widget.addonRates['rate_$key'] ?? 0).toDouble();
    return cycle == 'Yearly' ? (monthlyRate * 10) : monthlyRate;
  }

  String _getAddonTitle(String key) {
    switch (key) {
      case 'employee_management': return 'Employee Mgmt';
      case 'table_reservation': return 'Table Res';
      case 'supplier_management': return 'Supplier Mgmt';
      case 'kds_management': return 'KDS Mgmt';
      case 'franchise_management': return 'Franchise Mgmt';
      case 'central_catalog': return 'Central Catalog';
      case 'customer_management': return 'Customer Mgmt';
      case 'data_center': return 'Data Center';
      case 'integration_hub': return 'Integration Hub';
      default: return key;
    }
  }
}





