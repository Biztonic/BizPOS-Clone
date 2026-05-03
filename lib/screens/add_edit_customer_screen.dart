import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../providers/dashboard_provider.dart';
import 'package:uuid/uuid.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/components/atoms/app_button.dart';
import '../core/design/components/atoms/app_card.dart';
import '../core/design/components/atoms/app_text_field.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';

class AddEditCustomerScreen extends StatefulWidget {
  final Customer? customer;

  const AddEditCustomerScreen({super.key, this.customer});

  @override
  State<AddEditCustomerScreen> createState() => _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState extends State<AddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _taxController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController = TextEditingController(text: widget.customer?.phone ?? '');
    _emailController = TextEditingController(text: widget.customer?.email ?? '');
    _addressController = TextEditingController(text: widget.customer?.billingAddress ?? '');
    _taxController = TextEditingController(text: widget.customer?.taxNumber ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      
      final newCustomer = Customer(
        id: widget.customer?.id ?? const Uuid().v4(), // Generate ID if new
        storeId: provider.activeStoreId ?? '',
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        mobile: _phoneController.text.trim(),
        billingAddress: _addressController.text.trim(),
        taxNumber: _taxController.text.trim(),
        joinDate: widget.customer?.joinDate ?? DateTime.now(),
        totalSpent: widget.customer?.totalSpent ?? 0.0,
        loyaltyPoints: widget.customer?.loyaltyPoints ?? 0,
        tier: widget.customer?.tier ?? 'New',
        visitCount: widget.customer?.visitCount ?? 0,
      );

      if (widget.customer == null) {
        await provider.addCustomer(newCustomer);
      } else {
        await provider.updateCustomer(newCustomer);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer saved successfully'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PosScaffold(
      title: widget.customer == null ? 'Add Customer' : 'Edit Customer',
      mainContent: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Profile Information", style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            prefixIcon: const Icon(Icons.person_outline),
                            validator: (v) => v!.isEmpty ? 'Name required' : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _phoneController,
                            label: 'Phone / Mobile',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            keyboardType: TextInputType.phone,
                            validator: (v) => v!.isEmpty ? 'Phone required' : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _emailController,
                            label: 'Email Address',
                            prefixIcon: const Icon(Icons.email_outlined),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text("Business Details", style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField(
                            controller: _addressController,
                            label: 'Billing Address',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            maxLines: 2,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _taxController,
                            label: 'Tax / GST Number',
                            prefixIcon: const Icon(Icons.receipt_outlined),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton.primary(
                      onPressed: _save,
                      label: widget.customer == null ? 'Create Customer' : 'Update Customer',
                      width: double.infinity,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

