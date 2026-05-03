import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/density/app_density.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/components/atoms/app_card.dart';

class PaymentSettingsSection extends StatefulWidget {
  const PaymentSettingsSection({super.key});

  @override
  State<PaymentSettingsSection> createState() => _PaymentSettingsSectionState();
}

class _PaymentSettingsSectionState extends State<PaymentSettingsSection> {
  bool _enableCash = true;
  bool _enableUPI = true;
  bool _enableCard = false;
  
  final TextEditingController _upiIdController = TextEditingController();
  final TextEditingController _upiNameController = TextEditingController();
  
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final store = Provider.of<DashboardProvider>(context, listen: false).activeStore;
      if (store != null) {
        _upiIdController.text = store.payment.upiId;
        _upiNameController.text = store.payment.upiName;
        _enableUPI = store.payment.upiId.isNotEmpty; 
      }
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _upiNameController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
     final provider = Provider.of<DashboardProvider>(context, listen: false);
     final store = provider.activeStore;
     if (store != null) {
       final updatedPayment = store.payment.copyWith(
         upiId: _upiIdController.text.trim(),
         upiName: _upiNameController.text.trim(),
       );
       
       final updatedStore = store.copyWith(payment: updatedPayment);
       await provider.updateStoreSettings(updatedStore);
       
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Settings Saved")));
       }
     }
  }

  @override
  Widget build(BuildContext context) {
    final density = AppDensityProvider.configOf(context);

    return PosScaffold(
      title: "Payment Settings",
      mainContent: ListView(
        padding: EdgeInsets.all(AppSpacing.lg),
        children: [
          Text("Payment Methods", style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.md),
          
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Column(
              children: [
                // Cash Toggle
                SwitchListTile(
                  title: const Text("Accept Cash", style: AppTypography.bodyLarge),
                  subtitle: const Text("Enable cash payments at POS", style: AppTypography.bodySmall),
                  value: _enableCash,
                  onChanged: (val) => setState(() => _enableCash = val),
                  secondary: Icon(Icons.money, color: AppColors.success),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                // UPI Toggle
                SwitchListTile(
                  title: const Text("Accept UPI", style: AppTypography.bodyLarge),
                  subtitle: const Text("Enable QR code payments", style: AppTypography.bodySmall),
                  value: _enableUPI,
                  onChanged: (val) => setState(() => _enableUPI = val),
                  secondary: Icon(Icons.qr_code, color: AppColors.primary),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                // Card Toggle
                SwitchListTile(
                  title: const Text("Accept Card", style: AppTypography.bodyLarge),
                  subtitle: const Text("Enable card reader integration", style: AppTypography.bodySmall),
                  value: _enableCard,
                  onChanged: (val) => setState(() => _enableCard = val),
                  secondary: const Icon(Icons.credit_card, color: AppColors.warning),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          if (_enableUPI) ...[
            const SizedBox(height: AppSpacing.xl),
            Text("UPI Configuration", style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                children: [
                  AppTextField(
                    controller: _upiIdController,
                    labelText: "UPI ID / VPA",
                    hintText: "merchant@upi",
                    prefixIcon: const Icon(Icons.link),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _upiNameController,
                    labelText: "Payee Name (Business Name)",
                    hintText: "My Store",
                    prefixIcon: const Icon(Icons.store),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: "Save Changes",
            onPressed: _saveSettings,
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}
