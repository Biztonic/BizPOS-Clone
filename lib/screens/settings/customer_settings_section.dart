import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as legacy_provider;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../providers/dashboard_provider.dart' as legacy;
import '../../features/store/providers/store_notifier.dart';
import '../../features/store/domain/entities/settings.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/tokens/app_radius.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../l10n/app_localizations.dart';

class CustomerSettingsSection extends ConsumerStatefulWidget {
  final bool isSubView;
  const CustomerSettingsSection({super.key, this.isSubView = false});

  @override
  ConsumerState<CustomerSettingsSection> createState() =>
      _CustomerSettingsSectionState();
}

class _CustomerSettingsSectionState
    extends ConsumerState<CustomerSettingsSection> {
  bool _isInit = true;

  // Udhari Settings
  bool _enableUdhari = true;
  final TextEditingController _defaultCreditLimitController =
      TextEditingController();
  bool _allowPartialUdhari = true;
  bool _blockWhenLimitExceeded = false;
  bool _enableWhatsAppReminders = true;

  // Loyalty Settings
  bool _enableLoyalty = true;
  final TextEditingController _earnRateSpendAmountController =
      TextEditingController();
  final TextEditingController _earnRatePointsController =
      TextEditingController();
  final TextEditingController _pointRedemptionValueController =
      TextEditingController();
  final TextEditingController _minPointsToRedeemController =
      TextEditingController();
  final TextEditingController _maxBillDiscountPercentController =
      TextEditingController();
  final TextEditingController _pointsValidityDaysController =
      TextEditingController();

  // Membership & Tiers
  bool _enableMembership = true;
  final TextEditingController _silverMinSpendController =
      TextEditingController();
  final TextEditingController _silverMultiplierController =
      TextEditingController();
  final TextEditingController _goldMinSpendController = TextEditingController();
  final TextEditingController _goldMultiplierController =
      TextEditingController();
  final TextEditingController _platinumMinSpendController =
      TextEditingController();
  final TextEditingController _platinumMultiplierController =
      TextEditingController();

  // Coupons & Welcome Gifts
  bool _enableCoupons = true;
  final TextEditingController _welcomeBonusPointsController =
      TextEditingController();
  List<SeasonalCoupon> _seasonalCoupons = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final store = ref.read(storeNotifierProvider).activeStore ??
          legacy_provider.Provider.of<legacy.DashboardProvider>(context,
                  listen: false)
              .activeStore;

      if (store != null) {
        final cs = store.customerSettings;
        _enableUdhari = cs.enableUdhari;
        _defaultCreditLimitController.text =
            cs.defaultCreditLimit.toStringAsFixed(0);
        _allowPartialUdhari = cs.allowPartialUdhari;
        _blockWhenLimitExceeded = cs.blockWhenLimitExceeded;
        _enableWhatsAppReminders = cs.enableWhatsAppReminders;

        _enableLoyalty = cs.enableLoyalty;
        _earnRateSpendAmountController.text =
            cs.earnRateSpendAmount.toStringAsFixed(0);
        _earnRatePointsController.text = cs.earnRatePoints.toString();
        _pointRedemptionValueController.text =
            cs.pointRedemptionValue.toStringAsFixed(2);
        _minPointsToRedeemController.text = cs.minPointsToRedeem.toString();
        _maxBillDiscountPercentController.text =
            cs.maxBillDiscountPercent.toStringAsFixed(0);
        _pointsValidityDaysController.text = cs.pointsValidityDays.toString();

        _enableMembership = cs.enableMembership;
        _silverMinSpendController.text = cs.silverMinSpend.toStringAsFixed(0);
        _silverMultiplierController.text =
            cs.silverMultiplier.toStringAsFixed(1);
        _goldMinSpendController.text = cs.goldMinSpend.toStringAsFixed(0);
        _goldMultiplierController.text = cs.goldMultiplier.toStringAsFixed(1);
        _platinumMinSpendController.text =
            cs.platinumMinSpend.toStringAsFixed(0);
        _platinumMultiplierController.text =
            cs.platinumMultiplier.toStringAsFixed(1);

        _enableCoupons = cs.enableCoupons;
        _welcomeBonusPointsController.text = cs.welcomeBonusPoints.toString();
        _seasonalCoupons = List.from(cs.seasonalCoupons.isEmpty
            ? CustomerAddonSettings.defaultSeasonalCoupons
            : cs.seasonalCoupons);
      }
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _defaultCreditLimitController.dispose();
    _earnRateSpendAmountController.dispose();
    _earnRatePointsController.dispose();
    _pointRedemptionValueController.dispose();
    _minPointsToRedeemController.dispose();
    _maxBillDiscountPercentController.dispose();
    _pointsValidityDaysController.dispose();
    _silverMinSpendController.dispose();
    _silverMultiplierController.dispose();
    _goldMinSpendController.dispose();
    _goldMultiplierController.dispose();
    _platinumMinSpendController.dispose();
    _platinumMultiplierController.dispose();
    _welcomeBonusPointsController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final storeNotifier = ref.read(storeNotifierProvider.notifier);
    final legacyDashboard =
        legacy_provider.Provider.of<legacy.DashboardProvider>(context,
            listen: false);

    final currentStore = ref.read(storeNotifierProvider).activeStore ??
        legacyDashboard.activeStore;

    if (currentStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error: No active store found to save settings."),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final newCustomerSettings = CustomerAddonSettings(
      enableUdhari: _enableUdhari,
      defaultCreditLimit:
          double.tryParse(_defaultCreditLimitController.text.trim()) ?? 5000.0,
      allowPartialUdhari: _allowPartialUdhari,
      blockWhenLimitExceeded: _blockWhenLimitExceeded,
      enableWhatsAppReminders: _enableWhatsAppReminders,
      enableLoyalty: _enableLoyalty,
      earnRateSpendAmount:
          double.tryParse(_earnRateSpendAmountController.text.trim()) ?? 100.0,
      earnRatePoints:
          int.tryParse(_earnRatePointsController.text.trim()) ?? 1,
      pointRedemptionValue:
          double.tryParse(_pointRedemptionValueController.text.trim()) ?? 1.0,
      minPointsToRedeem:
          int.tryParse(_minPointsToRedeemController.text.trim()) ?? 50,
      maxBillDiscountPercent:
          double.tryParse(_maxBillDiscountPercentController.text.trim()) ??
              50.0,
      pointsValidityDays:
          int.tryParse(_pointsValidityDaysController.text.trim()) ?? 365,
      enableMembership: _enableMembership,
      silverMinSpend:
          double.tryParse(_silverMinSpendController.text.trim()) ?? 2000.0,
      silverMultiplier:
          double.tryParse(_silverMultiplierController.text.trim()) ?? 1.2,
      goldMinSpend:
          double.tryParse(_goldMinSpendController.text.trim()) ?? 5000.0,
      goldMultiplier:
          double.tryParse(_goldMultiplierController.text.trim()) ?? 1.5,
      platinumMinSpend:
          double.tryParse(_platinumMinSpendController.text.trim()) ?? 10000.0,
      platinumMultiplier:
          double.tryParse(_platinumMultiplierController.text.trim()) ?? 2.0,
      enableCoupons: _enableCoupons,
      welcomeBonusPoints:
          int.tryParse(_welcomeBonusPointsController.text.trim()) ?? 50,
      seasonalCoupons: _seasonalCoupons,
    );

    final updatedStore = currentStore.copyWith(
      customerSettings: newCustomerSettings,
    );

    try {
      await storeNotifier.updateStoreSettings(updatedStore);
      await legacyDashboard.updateStoreSettings(updatedStore);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(AppLocalizations.t(
                    context, 'Customer & Khata Settings saved successfully!')),
              ],
            ),
            backgroundColor: AppColors.adaptiveSuccess(context),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save settings: $e"),
            backgroundColor: AppColors.adaptiveError(context),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.adaptivePrimary(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.people_alt_rounded,
                color: AppColors.adaptivePrimary(context),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Customer & Khata (CRM) Settings",
                    style: AppTypography.titleLarge
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Configure credit limits, borrowing policies, loyalty reward points, and member tiers.",
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // 1. UDHARI / KHATA FEATURE SETTINGS
        _buildSectionHeader(
          icon: Icons.account_balance_wallet_rounded,
          title: "Udhari & Khata (Credit) Settings",
          subtitle:
              "Manage borrowing toggles, default customer credit limits, and collection enforcement.",
          color: AppColors.adaptiveWarning(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: Text("Enable Udhari (Borrowing / Khata)",
                    style: AppTypography.bodyLarge
                        .copyWith(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  "Allow customers to purchase goods on credit. Tracks customer ledger, borrow balance, and repayments.",
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
                value: _enableUdhari,
                onChanged: (val) => setState(() => _enableUdhari = val),
                activeColor: AppColors.adaptiveWarning(context),
                contentPadding: EdgeInsets.zero,
              ),
              if (_enableUdhari) ...[
                const Divider(height: 24),
                AppTextField(
                  controller: _defaultCreditLimitController,
                  labelText: "Default Credit Limit for New Customers (₹)",
                  hintText: "e.g. 5000",
                  prefixIcon: const Icon(Icons.currency_rupee),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  title: const Text("Allow Partial Payment with Udhari"),
                  subtitle: Text(
                    "Customer can pay part upfront via Cash or UPI and put the rest on Udhari credit in POS.",
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary(context)),
                  ),
                  value: _allowPartialUdhari,
                  onChanged: (val) =>
                      setState(() => _allowPartialUdhari = val),
                  activeColor: AppColors.adaptivePrimary(context),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(height: 20),
                SwitchListTile(
                  title: const Text("Enforce Strict Credit Limit (Block Checkout)"),
                  subtitle: Text(
                    _blockWhenLimitExceeded
                        ? "STRICT: POS cashier will be blocked from completing checkout if credit limit is exceeded."
                        : "FLEXIBLE: Cashier receives a warning badge when limit is exceeded, but can still approve sale.",
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary(context)),
                  ),
                  value: _blockWhenLimitExceeded,
                  onChanged: (val) =>
                      setState(() => _blockWhenLimitExceeded = val),
                  activeColor: AppColors.adaptiveError(context),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(height: 20),
                SwitchListTile(
                  title: const Text("WhatsApp Khata Reminders"),
                  subtitle: Text(
                    "Show direct WhatsApp reminder buttons in customer profile to send dues notifications.",
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary(context)),
                  ),
                  value: _enableWhatsAppReminders,
                  onChanged: (val) =>
                      setState(() => _enableWhatsAppReminders = val),
                  activeColor: AppColors.adaptiveSuccess(context),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // 2. LOYALTY POINTS PROGRAM SETTINGS
        _buildSectionHeader(
          icon: Icons.stars_rounded,
          title: "Loyalty Points Program",
          subtitle:
              "Define how customers earn points on spending and how points are redeemed for bill discounts.",
          color: AppColors.adaptivePrimary(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: Text("Enable Loyalty Program",
                    style: AppTypography.bodyLarge
                        .copyWith(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  "Reward customers with points on POS checkout and allow points redemption.",
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
                value: _enableLoyalty,
                onChanged: (val) => setState(() => _enableLoyalty = val),
                activeColor: AppColors.adaptivePrimary(context),
                contentPadding: EdgeInsets.zero,
              ),
              if (_enableLoyalty) ...[
                const Divider(height: 24),
                Text(
                  "Points Earning Rate Logic",
                  style: AppTypography.titleSmall
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        controller: _earnRateSpendAmountController,
                        labelText: "Spend Amount (₹)",
                        hintText: "100",
                        prefixIcon: const Icon(Icons.currency_rupee),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.arrow_forward, size: 20),
                    ),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        controller: _earnRatePointsController,
                        labelText: "Earn Points",
                        hintText: "1",
                        prefixIcon: const Icon(Icons.star_rounded),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "Example: Spend ₹${_earnRateSpendAmountController.text.isEmpty ? '100' : _earnRateSpendAmountController.text} to earn ${_earnRatePointsController.text.isEmpty ? '1' : _earnRatePointsController.text} point.",
                  style: AppTypography.bodySmall.copyWith(
                      color: AppColors.adaptivePrimary(context),
                      fontStyle: FontStyle.italic),
                ),
                const Divider(height: 24),
                Text(
                  "Points Redemption & Value Logic",
                  style: AppTypography.titleSmall
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _pointRedemptionValueController,
                        labelText: "1 Point Value (₹)",
                        hintText: "1.00",
                        prefixIcon: const Icon(Icons.monetization_on_outlined),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _minPointsToRedeemController,
                        labelText: "Min Points to Redeem",
                        hintText: "50",
                        prefixIcon: const Icon(Icons.lock_open_rounded),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _maxBillDiscountPercentController,
                        labelText: "Max Bill Discount via Points (%)",
                        hintText: "50",
                        prefixIcon: const Icon(Icons.percent_rounded),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _pointsValidityDaysController,
                        labelText: "Points Validity (Days)",
                        hintText: "365 (0 = Lifetime)",
                        prefixIcon: const Icon(Icons.calendar_today_rounded),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // 3. MEMBERSHIP TIERS & MULTIPLIERS
        _buildSectionHeader(
          icon: Icons.military_tech_rounded,
          title: "Membership Tiers & Point Multipliers",
          subtitle:
              "Automatically upgrade high-value customers and accelerate their reward points.",
          color: Colors.amber.shade700,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: Text("Enable Membership Tiers",
                    style: AppTypography.bodyLarge
                        .copyWith(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  "Classify customers into Bronze, Silver, Gold, Platinum with spending thresholds and earn multipliers.",
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
                value: _enableMembership,
                onChanged: (val) => setState(() => _enableMembership = val),
                activeColor: Colors.amber.shade700,
                contentPadding: EdgeInsets.zero,
              ),
              if (_enableMembership) ...[
                const Divider(height: 24),
                // Bronze
                _buildTierRow(
                  tierName: "Bronze Tier (Base)",
                  color: Colors.brown.shade400,
                  minSpendInfo: "Min Spend: ₹0 (Default for all registered customers)",
                  multiplierInfo: "1.0x standard points multiplier",
                ),
                const SizedBox(height: AppSpacing.md),
                // Silver
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        controller: _silverMinSpendController,
                        labelText: "Silver Min Spend (₹)",
                        hintText: "2000",
                        prefixIcon: Icon(Icons.workspace_premium,
                            color: Colors.blueGrey.shade400),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        controller: _silverMultiplierController,
                        labelText: "Multiplier (x)",
                        hintText: "1.2",
                        prefixIcon: const Icon(Icons.trending_up),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Gold
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        controller: _goldMinSpendController,
                        labelText: "Gold Min Spend (₹)",
                        hintText: "5000",
                        prefixIcon: Icon(Icons.military_tech,
                            color: Colors.amber.shade700),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        controller: _goldMultiplierController,
                        labelText: "Multiplier (x)",
                        hintText: "1.5",
                        prefixIcon: const Icon(Icons.trending_up),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Platinum
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        controller: _platinumMinSpendController,
                        labelText: "Platinum Min Spend (₹)",
                        hintText: "10000",
                        prefixIcon: Icon(Icons.diamond,
                            color: Colors.purple.shade400),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        controller: _platinumMultiplierController,
                        labelText: "Multiplier (x)",
                        hintText: "2.0",
                        prefixIcon: const Icon(Icons.trending_up),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // 4. COUPONS & WELCOME GIFTS
        _buildSectionHeader(
          icon: Icons.card_giftcard_rounded,
          title: "Coupons & Promotional Rewards",
          subtitle:
              "Distribute promotional vouchers, gifts, and welcome rewards on customer signup.",
          color: AppColors.adaptiveSuccess(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: Text("Enable Coupons & Vouchers",
                    style: AppTypography.bodyLarge
                        .copyWith(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  "Allow discount coupons and promotional gifts to be issued and redeemed for customers.",
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
                value: _enableCoupons,
                onChanged: (val) => setState(() => _enableCoupons = val),
                activeColor: AppColors.adaptiveSuccess(context),
                contentPadding: EdgeInsets.zero,
              ),
              if (_enableCoupons) ...[
                const Divider(height: 24),
                AppTextField(
                  controller: _welcomeBonusPointsController,
                  labelText: "Welcome Bonus Points / Coins on Signup",
                  hintText: "e.g. 50",
                  prefixIcon: const Icon(Icons.celebration_rounded),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 6),
                Text(
                  "Automatically grants these bonus points to newly registered customers in your store.",
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Seasonal & Campaign Coupons",
                          style: AppTypography.titleMedium
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Manage seasonal discount coupons applicable at POS checkout.",
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textSecondary(context)),
                        ),
                      ],
                    ),
                    AppButton.primary(
                      icon: Icons.add,
                      label: "+ Add Seasonal Coupon",
                      onPressed: () => _showAddEditCouponDialog(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (_seasonalCoupons.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant(context),
                      borderRadius: AppRadius.borderSm,
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.local_offer_outlined,
                              size: 40, color: AppColors.textSecondary(context)),
                          const SizedBox(height: 8),
                          Text(
                            "No seasonal coupons added yet.",
                            style: AppTypography.bodyMedium
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Create coupons for festivals (Diwali, Eid, Christmas), seasons (Summer, Monsoon), or promotional campaigns.",
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary(context)),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: _seasonalCoupons.map((coupon) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surface(context),
                            borderRadius: AppRadius.borderSm,
                            border: Border.all(
                              color: coupon.isActive
                                  ? AppColors.adaptivePrimary(context)
                                      .withValues(alpha: 0.3)
                                  : AppColors.border(context),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.adaptivePrimary(context)
                                      .withValues(alpha: 0.12),
                                  borderRadius: AppRadius.borderSm,
                                ),
                                child: Text(
                                  coupon.code,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                    fontSize: 13,
                                    color: AppColors.adaptivePrimary(context),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          coupon.title,
                                          style: AppTypography.bodyMedium
                                              .copyWith(
                                                  fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceVariant(
                                                context),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            coupon.season,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textSecondary(
                                                  context),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      coupon.discountType == 'percentage'
                                          ? "${coupon.discountValue.toStringAsFixed(0)}% OFF${coupon.maxDiscount > 0 ? " (Max ₹${coupon.maxDiscount.toStringAsFixed(0)})" : ""} • Min Order ₹${coupon.minOrderValue.toStringAsFixed(0)}"
                                          : "Flat ₹${coupon.discountValue.toStringAsFixed(0)} OFF • Min Order ₹${coupon.minOrderValue.toStringAsFixed(0)}",
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                    if (coupon.endDate != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        "Valid till: ${DateFormat('dd MMM yyyy').format(coupon.endDate!)}",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: coupon.isExpired
                                              ? AppColors.adaptiveError(context)
                                              : AppColors.textSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Switch(
                                value: coupon.isActive,
                                activeColor: AppColors.adaptiveSuccess(context),
                                onChanged: (val) {
                                  setState(() {
                                    final idx = _seasonalCoupons
                                        .indexWhere((c) => c.id == coupon.id);
                                    if (idx != -1) {
                                      _seasonalCoupons[idx] =
                                          coupon.copyWith(isActive: val);
                                    }
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: "Edit Coupon",
                                onPressed: () =>
                                    _showAddEditCouponDialog(coupon: coupon),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    size: 18,
                                    color: AppColors.adaptiveError(context)),
                                tooltip: "Delete Coupon",
                                onPressed: () => _deleteCoupon(coupon.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        // Save Button
        AppButton(
          label: "Save Customer & Khata Settings",
          icon: Icons.save_rounded,
          onPressed: _saveSettings,
          width: double.infinity,
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );

    if (widget.isSubView) return content;

    return PosScaffold(
      title: "Customer & Khata Settings",
      showSidebar: false,
      mainContent: content,
    );
  }

  void _deleteCoupon(String couponId) {
    setState(() {
      _seasonalCoupons.removeWhere((c) => c.id == couponId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Coupon removed. Remember to save settings."),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAddEditCouponDialog({SeasonalCoupon? coupon}) {
    final isEditing = coupon != null;
    final codeCtrl = TextEditingController(text: coupon?.code ?? '');
    final titleCtrl = TextEditingController(text: coupon?.title ?? '');
    final seasonCtrl = TextEditingController(text: coupon?.season ?? 'General');
    String discountType = coupon?.discountType ?? 'percentage';
    final discountValCtrl = TextEditingController(
        text: coupon != null ? coupon.discountValue.toStringAsFixed(0) : '15');
    final minOrderCtrl = TextEditingController(
        text: coupon != null ? coupon.minOrderValue.toStringAsFixed(0) : '0');
    final maxDiscCtrl = TextEditingController(
        text: coupon != null ? coupon.maxDiscount.toStringAsFixed(0) : '0');
    DateTime? startDate = coupon?.startDate;
    DateTime? endDate = coupon?.endDate;
    bool isActive = coupon?.isActive ?? true;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            backgroundColor: AppColors.surface(context),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
            title: Row(
              children: [
                Icon(
                  isEditing ? Icons.edit_note : Icons.add_circle_outline,
                  color: AppColors.adaptivePrimary(context),
                ),
                const SizedBox(width: 8),
                Text(
                  isEditing ? "Edit Seasonal Coupon" : "Add Seasonal Coupon",
                  style: AppTypography.titleMedium
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      controller: codeCtrl,
                      labelText: "Coupon Code (e.g. DIWALI2026, SUMMER25)",
                      hintText: "DIWALI20",
                      prefixIcon: const Icon(Icons.confirmation_number_outlined),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: titleCtrl,
                      labelText: "Coupon Title / Description",
                      hintText: "e.g. Diwali Dhamaka Special",
                      prefixIcon: const Icon(Icons.title),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: seasonCtrl,
                            labelText: "Season / Campaign",
                            hintText: "e.g. Diwali, Summer, Festive",
                            prefixIcon: const Icon(Icons.celebration_outlined),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: discountType,
                            decoration: const InputDecoration(
                              labelText: "Discount Type",
                              border: OutlineInputBorder(),
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'percentage', child: Text("Percentage (%)")),
                              DropdownMenuItem(
                                  value: 'flat', child: Text("Flat Amount (₹)")),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => discountType = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: discountValCtrl,
                            labelText: discountType == 'percentage'
                                ? "Discount Percentage (%)"
                                : "Flat Discount (₹)",
                            hintText: discountType == 'percentage' ? "20" : "100",
                            prefixIcon: Icon(discountType == 'percentage'
                                ? Icons.percent
                                : Icons.currency_rupee),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppTextField(
                            controller: minOrderCtrl,
                            labelText: "Min Order Value (₹)",
                            hintText: "e.g. 500",
                            prefixIcon: const Icon(Icons.shopping_bag_outlined),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    if (discountType == 'percentage') ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: maxDiscCtrl,
                        labelText: "Max Discount Cap (₹) (0 for unlimited)",
                        hintText: "e.g. 200",
                        prefixIcon: const Icon(Icons.vertical_align_top),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              startDate == null
                                  ? "Valid From: Today"
                                  : DateFormat('dd/MM/yyyy').format(startDate!),
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate ?? DateTime.now(),
                                firstDate: DateTime(2025),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setModalState(() => startDate = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.event, size: 16),
                            label: Text(
                              endDate == null
                                  ? "Valid Till: No Expiry"
                                  : DateFormat('dd/MM/yyyy').format(endDate!),
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate ??
                                    DateTime.now().add(const Duration(days: 30)),
                                firstDate: DateTime(2025),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setModalState(() => endDate = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SwitchListTile(
                      title: const Text("Coupon Active Status"),
                      subtitle: const Text("Customers can redeem this coupon if enabled"),
                      value: isActive,
                      onChanged: (val) => setModalState(() => isActive = val),
                      activeColor: AppColors.adaptiveSuccess(context),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(AppLocalizations.t(context, 'Cancel'),
                    style: TextStyle(color: AppColors.textSecondary(context))),
              ),
              AppButton.primary(
                label: isEditing ? "Update Coupon" : "Add Coupon",
                onPressed: () {
                  final code = codeCtrl.text.trim().toUpperCase();
                  if (code.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Coupon code cannot be empty.")),
                    );
                    return;
                  }
                  final newCoupon = SeasonalCoupon(
                    id: coupon?.id ?? const Uuid().v4(),
                    code: code,
                    title: titleCtrl.text.trim().isNotEmpty
                        ? titleCtrl.text.trim()
                        : code,
                    season: seasonCtrl.text.trim().isNotEmpty
                        ? seasonCtrl.text.trim()
                        : 'General',
                    discountType: discountType,
                    discountValue: double.tryParse(discountValCtrl.text.trim()) ?? 0.0,
                    minOrderValue: double.tryParse(minOrderCtrl.text.trim()) ?? 0.0,
                    maxDiscount: double.tryParse(maxDiscCtrl.text.trim()) ?? 0.0,
                    startDate: startDate,
                    endDate: endDate,
                    isActive: isActive,
                  );

                  setState(() {
                    if (isEditing) {
                      final idx =
                          _seasonalCoupons.indexWhere((c) => c.id == coupon.id);
                      if (idx != -1) {
                        _seasonalCoupons[idx] = newCoupon;
                      }
                    } else {
                      _seasonalCoupons.add(newCoupon);
                    }
                  });

                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          "Coupon '$code' ${isEditing ? 'updated' : 'added'}! Click Save Settings to persist."),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.titleMedium
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                subtitle,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary(context)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTierRow({
    required String tierName,
    required Color color,
    required String minSpendInfo,
    required String multiplierInfo,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_rounded, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tierName,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: color)),
                Text(minSpendInfo,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text(multiplierInfo,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
