import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer.dart';
import '../providers/dashboard_provider.dart';
import '../features/store/domain/entities/settings.dart';
import '../core/design/tokens/app_colors.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';
import '../core/design/tokens/app_radius.dart';
import '../core/design/components/atoms/app_card.dart';
import '../core/design/components/atoms/app_text_field.dart';

enum WhatsAppTemplateCategory {
  udhariDue,
  promotions,
  transactions,
  loyalty,
  seasonal,
  paymentReceived,
  custom,
}

class WhatsAppTemplateItem {
  final WhatsAppTemplateCategory category;
  final String label;
  final IconData icon;
  final Color color;
  final String description;

  const WhatsAppTemplateItem({
    required this.category,
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
  });
}

class CustomerWhatsAppDialog extends StatefulWidget {
  final Customer customer;
  final DashboardProvider provider;
  final WhatsAppTemplateCategory initialCategory;
  final double? customAmount;

  const CustomerWhatsAppDialog({
    super.key,
    required this.customer,
    required this.provider,
    this.initialCategory = WhatsAppTemplateCategory.udhariDue,
    this.customAmount,
  });

  static Future<void> show(
    BuildContext context, {
    required Customer customer,
    required DashboardProvider provider,
    WhatsAppTemplateCategory initialCategory =
        WhatsAppTemplateCategory.udhariDue,
    double? customAmount,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CustomerWhatsAppDialog(
        customer: customer,
        provider: provider,
        initialCategory: initialCategory,
        customAmount: customAmount,
      ),
    );
  }

  static String generateTemplateText({
    required Customer customer,
    String? storeName,
    CustomerAddonSettings? customerSettings,
    required WhatsAppTemplateCategory category,
    double? customAmount,
  }) {
    final customerName = customer.name.trim().isNotEmpty
        ? customer.name.trim()
        : "Valued Customer";
    final effectiveStoreName =
        (storeName != null && storeName.trim().isNotEmpty)
            ? storeName.trim()
            : "BizPOS Store";
    final balance = customer.udhariBalance;
    final points = customer.loyaltyPoints;
    final coinValue = points * (customerSettings?.pointRedemptionValue ?? 1.0);
    final totalSpent = customer.totalSpent;
    final visitCount = customer.visitCount;
    final tier =
        customer.tier.isNotEmpty ? customer.tier.toUpperCase() : "REGULAR";

    switch (category) {
      case WhatsAppTemplateCategory.udhariDue:
        return "Namaste $customerName,\n\n"
            "This is a gentle payment reminder from *$effectiveStoreName*.\n"
            "Your outstanding Khata (Udhari) balance is *₹${balance.toStringAsFixed(0)}*.\n\n"
            "Kindly settle the due amount at your earliest convenience via Cash or UPI.\n\n"
            "Thank you for your continued trust and patronage!\n"
            "- *$effectiveStoreName*";

      case WhatsAppTemplateCategory.promotions:
        return "Special Offer For You, *$customerName*! 🎉\n\n"
            "We have exclusive promotional discounts waiting for you at *$effectiveStoreName*.\n"
            "Show this WhatsApp message at our billing counter to unlock special savings on your next visit!\n\n"
            "Hurry, offer valid for a limited time.\n"
            "- *$effectiveStoreName*";

      case WhatsAppTemplateCategory.transactions:
        return "Namaste $customerName,\n\n"
            "Thank you for shopping at *$effectiveStoreName*! 🛍️\n"
            "Total Purchases: *₹${totalSpent.toStringAsFixed(0)}* across $visitCount visits.\n"
            "Reward Points: *$points pts*.\n\n"
            "We truly appreciate your visit and look forward to serving you again soon!\n"
            "- *$effectiveStoreName*";

      case WhatsAppTemplateCategory.loyalty:
        return "Hello $customerName! ⭐\n\n"
            "Great news from *$effectiveStoreName*!\n"
            "You currently have *$points Loyalty Reward Points* (Status: *$tier*) worth approximately *₹${coinValue.toStringAsFixed(0)}*.\n\n"
            "Visit us today to redeem your points for instant discounts on your bill!\n"
            "- *$effectiveStoreName*";

      case WhatsAppTemplateCategory.seasonal:
        return "Warm Festive & Seasonal Greetings from *$effectiveStoreName*! 🪔✨\n\n"
            "Wishing you and your family joy, health, and prosperity this festive season!\n"
            "Celebrate with us and enjoy special seasonal offers and festive discounts across our store.\n\n"
            "Visit *$effectiveStoreName* today to explore our seasonal specials!\n"
            "- *$effectiveStoreName*";

      case WhatsAppTemplateCategory.paymentReceived:
        final amountPaid = customAmount ?? 0.0;
        final amountText =
            amountPaid > 0 ? " of *₹${amountPaid.toStringAsFixed(0)}*" : "";
        return "Namaste $customerName,\n\n"
            "Thank you! We have successfully received and recorded your payment$amountText at *$effectiveStoreName*.\n"
            "Updated Khata Balance: *₹${balance.toStringAsFixed(0)}*.\n\n"
            "Thank you for keeping your account in great standing!\n"
            "- *$effectiveStoreName*";

      case WhatsAppTemplateCategory.custom:
        return "Namaste $customerName,\n\n"
            "Greetings from *$effectiveStoreName*!\n\n"
            "Thank you for choosing us.\n"
            "- *$effectiveStoreName*";
    }
  }

  @override
  State<CustomerWhatsAppDialog> createState() => _CustomerWhatsAppDialogState();
}

class _CustomerWhatsAppDialogState extends State<CustomerWhatsAppDialog> {
  late WhatsAppTemplateCategory _selectedCategory;
  late TextEditingController _phoneController;
  late TextEditingController _messageController;
  bool _isSending = false;

  static const List<WhatsAppTemplateItem> _templates = [
    WhatsAppTemplateItem(
      category: WhatsAppTemplateCategory.udhariDue,
      label: "Udhari Reminder",
      icon: Icons.account_balance_wallet_outlined,
      color: Color(0xFFE53935),
      description: "Pending Khata / credit balance reminder",
    ),
    WhatsAppTemplateItem(
      category: WhatsAppTemplateCategory.promotions,
      label: "Promotions & Offers",
      icon: Icons.local_offer_outlined,
      color: Color(0xFF8E24AA),
      description: "Special discounts and store offers",
    ),
    WhatsAppTemplateItem(
      category: WhatsAppTemplateCategory.transactions,
      label: "Bill & Purchases",
      icon: Icons.receipt_long_outlined,
      color: Color(0xFF1E88E5),
      description: "Order receipt & visit summary",
    ),
    WhatsAppTemplateItem(
      category: WhatsAppTemplateCategory.loyalty,
      label: "Loyalty Points",
      icon: Icons.stars_outlined,
      color: Color(0xFFFB8C00),
      description: "Reward coins balance & redemption",
    ),
    WhatsAppTemplateItem(
      category: WhatsAppTemplateCategory.seasonal,
      label: "Seasonal Offers",
      icon: Icons.celebration_outlined,
      color: Color(0xFF43A047),
      description: "Festive greetings & seasonal deals",
    ),
    WhatsAppTemplateItem(
      category: WhatsAppTemplateCategory.paymentReceived,
      label: "Payment Receipt",
      icon: Icons.check_circle_outline,
      color: Color(0xFF00897B),
      description: "Acknowledge Khata payment received",
    ),
    WhatsAppTemplateItem(
      category: WhatsAppTemplateCategory.custom,
      label: "Custom Note",
      icon: Icons.edit_note_outlined,
      color: Color(0xFF546E7A),
      description: "Free text message to customer",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;

    final rawPhone = widget.customer.mobile?.isNotEmpty == true
        ? widget.customer.mobile!
        : (widget.customer.phone ?? '');
    _phoneController = TextEditingController(text: rawPhone);
    _messageController = TextEditingController();

    _loadTemplateMessage(_selectedCategory);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String _getStoreName() {
    final name = widget.provider.activeStore?.name;
    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }
    return "BizPOS Store";
  }

  String _generateTemplateText(WhatsAppTemplateCategory category) {
    return CustomerWhatsAppDialog.generateTemplateText(
      customer: widget.customer,
      storeName: _getStoreName(),
      customerSettings: widget.provider.activeStore?.customerSettings,
      category: category,
      customAmount: widget.customAmount,
    );
  }

  void _loadTemplateMessage(WhatsAppTemplateCategory category) {
    setState(() {
      _selectedCategory = category;
      _messageController.text = _generateTemplateText(category);
    });
  }

  Future<void> _sendWhatsApp() async {
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty || phone.length < 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid customer mobile number."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Message cannot be empty."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    // Format phone with Indian country code 91 if standard 10 digits
    final formattedPhone = phone.length == 10 ? "91$phone" : phone;
    final urlString =
        "https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}";

    try {
      // 1. Copy message text to clipboard for merchant convenience
      await Clipboard.setData(ClipboardData(text: message));

      // 2. Launch WhatsApp URL
      final uri = Uri.parse(urlString);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    launched
                        ? "Opening WhatsApp for ${widget.customer.name} (Message copied to clipboard!)"
                        : "Message copied to clipboard! (Unable to open WhatsApp automatically)",
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF25D366),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error launching WhatsApp: $e"),
            backgroundColor: AppColors.adaptiveError(context),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _copyMessageToClipboard() async {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Message copied to clipboard!"),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 680 : double.infinity,
          maxHeight: 740,
        ),
        child: ClipRRect(
          borderRadius: AppRadius.borderLg,
          child: Scaffold(
            backgroundColor: AppColors.surface(context),
            appBar: AppBar(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              elevation: 0,
              leading: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "WhatsApp Messaging Hub",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.customer.name,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Header Info Card
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                          child: const Icon(Icons.person, color: Color(0xFF25D366), size: 22),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.customer.name,
                                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: [
                                  if (widget.customer.udhariBalance > 0) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.adaptiveError(context).withValues(alpha: 0.1),
                                        borderRadius: AppRadius.borderSm,
                                      ),
                                      child: Text(
                                        "Due: ₹${widget.customer.udhariBalance.toStringAsFixed(0)}",
                                        style: TextStyle(
                                          color: AppColors.adaptiveError(context),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                  ],
                                  Text(
                                    "Points: ${widget.customer.loyaltyPoints} • Spent: ₹${widget.customer.totalSpent.toStringAsFixed(0)}",
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Phone Number Input
                  AppTextField(
                    controller: _phoneController,
                    label: "Customer Mobile Number (WhatsApp)",
                    hintText: "e.g. 9876543210",
                    prefixIcon: const Icon(Icons.phone_android, color: Color(0xFF25D366)),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Template Selection Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Select Message Template",
                        style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "${_templates.length} Prebuilt Templates",
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // Horizontal Template Selector
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _templates.length,
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
                      itemBuilder: (context, i) {
                        final tmpl = _templates[i];
                        final isSelected = _selectedCategory == tmpl.category;
                        return InkWell(
                          onTap: () => _loadTemplateMessage(tmpl.category),
                          borderRadius: AppRadius.borderMd,
                          child: Container(
                            width: 140,
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? tmpl.color.withValues(alpha: 0.12)
                                  : AppColors.surfaceVariant(context),
                              borderRadius: AppRadius.borderMd,
                              border: Border.all(
                                color: isSelected ? tmpl.color : AppColors.border(context),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(tmpl.icon, size: 18, color: tmpl.color),
                                    const Spacer(),
                                    if (isSelected)
                                      Icon(Icons.check_circle, size: 14, color: tmpl.color),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tmpl.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? tmpl.color : null,
                                  ),
                                ),
                                Text(
                                  tmpl.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Message Editor & Preview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Message Preview (Editable)",
                        style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: _copyMessageToClipboard,
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text("Copy", style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // Text area
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: TextField(
                      controller: _messageController,
                      maxLines: 8,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: "Type or customize your WhatsApp message here...",
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // Dynamic Variable Tags
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: 4,
                    children: [
                      _buildVariableChip("{Customer}", widget.customer.name),
                      _buildVariableChip("{Store}", _getStoreName()),
                      if (widget.customer.udhariBalance > 0)
                        _buildVariableChip(
                            "{Due}", "₹${widget.customer.udhariBalance.toStringAsFixed(0)}"),
                      _buildVariableChip("{Points}", "${widget.customer.loyaltyPoints}"),
                      _buildVariableChip(
                          "{Spent}", "₹${widget.customer.totalSpent.toStringAsFixed(0)}"),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text("Cancel"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isSending ? null : _sendWhatsApp,
                          icon: _isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 20),
                          label: Text(
                            _isSending ? "Opening WhatsApp..." : "Share on WhatsApp",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.borderMd,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVariableChip(String tag, String value) {
    return ActionChip(
      avatar: const Icon(Icons.add, size: 12),
      label: Text("$tag: $value", style: const TextStyle(fontSize: 10)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      onPressed: () {
        final current = _messageController.text;
        _messageController.text = "$current $value";
      },
    );
  }
}
