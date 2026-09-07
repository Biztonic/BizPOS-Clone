import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:biztonic_pos/models/store_hardware.dart';
import 'package:biztonic_pos/features/store/domain/entities/subscription_request.dart';
import 'package:provider/provider.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/core/design/tokens/app_typography.dart';
import 'package:go_router/go_router.dart';

class EmiPaymentScreen extends StatefulWidget {
  final StoreHardware hardware;

  const EmiPaymentScreen({super.key, required this.hardware});

  @override
  State<EmiPaymentScreen> createState() => _EmiPaymentScreenState();
}

class _EmiPaymentScreenState extends State<EmiPaymentScreen> {
  bool _isSubmitting = false;

  void _submitPayment() async {
    setState(() => _isSubmitting = true);
    
    try {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      final store = provider.activeStore;
      
      final emiAmount = widget.hardware.remainingAmount / (widget.hardware.totalEmis - widget.hardware.emisPaid);
      final currentUser = FirebaseAuth.instance.currentUser;
      
      final request = SubscriptionRequest(
        id: '', 
        storeId: store?.id ?? '',
        storeName: store?.name ?? '',
        ownerEmail: currentUser?.email ?? '',
        planType: 'Hardware EMI',
        billingCycle: 'Fixed',
        amount: emiAmount,
        userId: currentUser?.uid ?? '',
        createdAt: DateTime.now(),
        requestType: 'hardware_emi',
        hardwareId: widget.hardware.hardwareId,
        requestedAmount: emiAmount,
        paymentMode: 'QR',
        // In a real flow, a receipt image URL would be attached here
        receiptUrl: 'dummy_receipt.jpg',
      );
      
      await FirebaseFirestore.instance.collection('subscription_requests').add(request.toMap());
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('EMI Payment request submitted for approval!'), backgroundColor: AppColors.success),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting EMI payment: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emiAmount = widget.hardware.remainingAmount / (widget.hardware.totalEmis - widget.hardware.emisPaid);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Hardware EMI'),
        backgroundColor: AppColors.surface(context),
      ),
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hardware EMI Payment', style: AppTypography.headlineMedium),
              const SizedBox(height: 16),
              Text('Hardware ID: ${widget.hardware.hardwareId}', style: AppTypography.titleMedium),
              const SizedBox(height: 8),
              Text('EMI Amount: ₹${emiAmount.toStringAsFixed(2)}', style: AppTypography.headlineLarge.copyWith(color: AppColors.primary)),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Icon(Icons.qr_code_2, size: 200, color: Colors.black87), // Mock QR
              ),
              const SizedBox(height: 16),
              Text('Scan this QR code with any UPI app to pay', style: AppTypography.bodyMedium),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.surfaceLight,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('I have paid via QR Code'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
