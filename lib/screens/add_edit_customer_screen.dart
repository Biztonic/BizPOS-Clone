import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../providers/dashboard_provider.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/components/atoms/app_button.dart';
import '../core/design/components/atoms/app_card.dart';
import '../core/design/components/atoms/app_text_field.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';
import '../core/design/tokens/app_colors.dart';

class AddEditCustomerScreen extends StatefulWidget {
  final Customer? customer;
  final bool isDialog;

  const AddEditCustomerScreen({
    super.key,
    this.customer,
    this.isDialog = false,
  });

  /// Opens the Add/Edit Customer form in a modern, responsive dialog.
  static Future<Customer?> showAsDialog(BuildContext context, {Customer? customer}) {
    return showDialog<Customer>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
          child: AddEditCustomerScreen(customer: customer, isDialog: true),
        ),
      ),
    );
  }

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
  late TextEditingController _creditLimitController;
  late TextEditingController _udhariBalanceController;
  late TextEditingController _loyaltyPointsController;
  late String _tier;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController = TextEditingController(
        text: widget.customer?.mobile ?? widget.customer?.phone ?? '');
    _emailController = TextEditingController(text: widget.customer?.email ?? '');
    _addressController =
        TextEditingController(text: widget.customer?.billingAddress ?? '');
    _taxController = TextEditingController(text: widget.customer?.taxNumber ?? '');
    _creditLimitController = TextEditingController(
        text: (widget.customer?.creditLimit ?? 0.0) > 0
            ? widget.customer!.creditLimit.toStringAsFixed(0)
            : '');
    _udhariBalanceController = TextEditingController(
        text: (widget.customer?.udhariBalance ?? 0.0) > 0
            ? widget.customer!.udhariBalance.toStringAsFixed(0)
            : '0');
    _loyaltyPointsController = TextEditingController(
        text: (widget.customer?.loyaltyPoints ?? 0).toString());
    _tier = widget.customer?.tier.isNotEmpty == true
        ? widget.customer!.tier
        : 'Regular';
  }

  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit && widget.customer == null) {
      final store =
          Provider.of<DashboardProvider>(context, listen: false).activeStore;
      if (store != null) {
        final cs = store.customerSettings;
        if (_creditLimitController.text.isEmpty && cs.defaultCreditLimit > 0) {
          _creditLimitController.text =
              cs.defaultCreditLimit.toStringAsFixed(0);
        }
        if (_loyaltyPointsController.text == '0' &&
            cs.enableCoupons &&
            cs.welcomeBonusPoints > 0) {
          _loyaltyPointsController.text = cs.welcomeBonusPoints.toString();
        }
      }
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _taxController.dispose();
    _creditLimitController.dispose();
    _udhariBalanceController.dispose();
    _loyaltyPointsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<DashboardProvider>(context, listen: false);

      final String effectiveStoreId = provider.activeStoreId?.isNotEmpty == true
          ? provider.activeStoreId!
          : (provider.userProfile?.storeId ?? 'store_default');

      final double creditLimit =
          double.tryParse(_creditLimitController.text.trim()) ?? 0.0;
      final double udhariBalance =
          double.tryParse(_udhariBalanceController.text.trim()) ??
              (widget.customer?.udhariBalance ?? 0.0);
      final int loyaltyPoints =
          int.tryParse(_loyaltyPointsController.text.trim()) ??
              (widget.customer?.loyaltyPoints ?? 0);

      final newCustomer = Customer(
        id: widget.customer?.id ?? const Uuid().v4(),
        storeId: effectiveStoreId,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        mobile: _phoneController.text.trim(),
        billingAddress: _addressController.text.trim(),
        taxNumber: _taxController.text.trim(),
        joinDate: widget.customer?.joinDate ?? DateTime.now(),
        totalSpent: widget.customer?.totalSpent ?? 0.0,
        loyaltyPoints: loyaltyPoints,
        tier: _tier,
        visitCount: widget.customer?.visitCount ?? 0,
        creditLimit: creditLimit,
        udhariBalance: udhariBalance,
      );

      if (widget.customer == null) {
        await provider.addCustomer(newCustomer);
      } else {
        await provider.updateCustomer(newCustomer);
      }

      if (mounted) {
        Navigator.pop(context, newCustomer);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.customer == null
                ? AppLocalizations.t(context, 'Customer created successfully')
                : AppLocalizations.t(context, 'Customer updated successfully')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.adaptiveSuccess(context),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.adaptiveError(context),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.customer == null ? 'Add Customer' : 'Edit Customer';

    if (widget.isDialog) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dialog Header
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppColors.border(context))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.customer == null
                            ? Icons.person_add_outlined
                            : Icons.edit_outlined,
                        color: AppColors.adaptivePrimary(context),
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        title,
                        style: AppTypography.titleLarge
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context, false),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            // Form Body
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: _buildForm(),
                    ),
            ),
            // Dialog Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.border(context))),
                color: AppColors.background(context),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton.secondary(
                    label: "Cancel",
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppButton.primary(
                    label: widget.customer == null
                        ? "Save Customer"
                        : "Update Customer",
                    icon: Icons.check,
                    onPressed: _isLoading ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return PosScaffold(
      title: title,
      mainContent: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _buildForm(),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton.primary(
                    onPressed: _save,
                    label: widget.customer == null
                        ? 'Create Customer'
                        : 'Update Customer',
                    width: double.infinity,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Basic Info Card
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.badge_outlined,
                        size: 20, color: AppColors.adaptivePrimary(context)),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      AppLocalizations.t(context, 'Customer Information'),
                      style: AppTypography.titleMedium
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        controller: _nameController,
                        label: 'Full Name *',
                        hintText: 'e.g. Rahul Sharma',
                        prefixIcon: const Icon(Icons.person_outline),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Name is required' : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Membership Tier",
                              style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textSecondary(context)),
                            ),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _tier,
                                isDense: true,
                                isExpanded: true,
                                dropdownColor: AppColors.surface(context),
                                style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textPrimary(context)),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'Regular', child: Text('Regular')),
                                  DropdownMenuItem(
                                      value: 'Silver', child: Text('Silver')),
                                  DropdownMenuItem(
                                      value: 'Gold', child: Text('Gold')),
                                  DropdownMenuItem(
                                      value: 'Platinum', child: Text('Platinum')),
                                  DropdownMenuItem(
                                      value: 'VIP', child: Text('VIP')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _tier = v);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _phoneController,
                        label: 'Mobile / WhatsApp *',
                        hintText: 'e.g. 9876543210',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        keyboardType: TextInputType.phone,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Phone number is required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        hintText: 'e.g. customer@example.com',
                        prefixIcon: const Icon(Icons.email_outlined),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Khata / Udhari & Loyalty Card
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 20, color: AppColors.adaptiveWarning(context)),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      "Udhari (Customer Credit / Khata) & Loyalty",
                      style: AppTypography.titleMedium
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "Configure credit limit, opening borrow balance, and loyalty coins.",
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _creditLimitController,
                        label: 'Credit Limit (₹)',
                        hintText: 'e.g. 10000 (0 for no limit)',
                        prefixIcon: const Icon(Icons.credit_score_outlined),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        controller: _udhariBalanceController,
                        label: widget.customer == null
                            ? 'Opening Udhari Due (₹)'
                            : 'Current Udhari Due (₹)',
                        hintText: '0.0',
                        prefixIcon: const Icon(Icons.receipt_long_outlined),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        controller: _loyaltyPointsController,
                        label: 'Loyalty Points / Coins',
                        hintText: '0',
                        prefixIcon: const Icon(Icons.stars_outlined),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Business & Address Details
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.business_outlined,
                        size: 20, color: AppColors.adaptiveInfo(context)),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      AppLocalizations.t(context, 'Billing & Address Details'),
                      style: AppTypography.titleMedium
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _addressController,
                  label: 'Billing / Shipping Address',
                  hintText: 'Street address, city, state, pin code',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _taxController,
                  label: 'GST / Tax Number',
                  hintText: 'e.g. 22AAAAA0000A1Z5',
                  prefixIcon: const Icon(Icons.receipt_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
