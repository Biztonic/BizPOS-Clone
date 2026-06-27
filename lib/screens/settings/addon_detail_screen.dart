import '../../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';
import 'package:biztonic_pos/core/design/layouts/pos_scaffold.dart';

// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import 'payment_qr_dialog.dart';

class AddonDetailScreen extends StatefulWidget {
  final String addonKey;

  const AddonDetailScreen({
    super.key,
    required this.addonKey,
  });

  static final List<Map<String, dynamic>> addonsMetadata = [
    {
      'key': 'employee_management',
      'title': 'Employee Management',
      'description': 'Manage staff, roles, permissions, and attendance.',
      'icon': Icons.badge,
      'color': AppColors.primary,
      'version': '1.2',
      'size': '3.2 MB',
      'rating': '4.8',
      'category': 'Essentials',
    },
    {
      'key': 'table_reservation',
      'title': 'Table Reservation',
      'description': 'Floor plan, table status, and reservation management.',
      'icon': Icons.table_restaurant,
      'color': AppColors.secondary,
      'version': '1.1',
      'size': '2.8 MB',
      'rating': '4.7',
      'category': 'Operations',
    },
    {
      'key': 'supplier_management',
      'title': 'Supplier Management',
      'description': 'Track suppliers, purchase orders, and incoming stock.',
      'icon': Icons.local_shipping,
      'color': AppColors.warning,
      'version': '1.0',
      'size': '2.1 MB',
      'rating': '4.6',
      'category': 'Operations',
    },
    {
      'key': 'kds_management',
      'title': 'Display Integration',
      'description': 'Digital kitchen order tickets and status tracking.',
      'icon': Icons.monitor,
      'color': AppColors.primary,
      'version': '1.0',
      'size': '1.8 MB',
      'rating': '4.9',
      'category': 'Operations',
    },
    {
      'key': 'franchise_management',
      'title': 'Franchise Management',
      'description': 'Manage multiple locations and franchise partners.',
      'icon': Icons.business_center,
      'color': AppColors.primaryLight,
      'version': '1.0',
      'size': '4.5 MB',
      'rating': '4.8',
      'category': 'Scale & Cloud',
    },
    {
      'key': 'central_catalog',
      'title': 'Central Catalogue',
      'description': 'Access global products and scan menus via the standalone Catalogue app. Enables cloud import in Inventory.',
      'icon': Icons.inventory_2,
      'color': AppColors.warning,
      'version': '2.0',
      'size': '2.5 MB',
      'rating': '4.7',
      'category': 'Scale & Cloud',
    },
    {
      'key': 'customer_management',
      'title': 'Customer Management',
      'description': 'Customer profiles, loyalty points, and purchase history.',
      'icon': Icons.people,
      'color': AppColors.primaryLight,
      'version': '1.1',
      'size': '3.0 MB',
      'rating': '4.8',
      'category': 'Essentials',
    },
    {
      'key': 'data_center',
      'title': 'Data Center',
      'description': 'Advanced analytics, backups, and sync control.',
      'icon': Icons.storage,
      'color': AppColors.primaryLightGrey,
      'version': '1.0',
      'size': '1.5 MB',
      'rating': '4.5',
      'category': 'Essentials',
    },
    {
      'key': 'integration_hub',
      'title': 'Integration Hub',
      'description': 'Connect with Swiggy, Zomato, Uber Eats & more.',
      'icon': Icons.hub,
      'color': AppColors.warning,
      'version': '1.0',
      'size': '3.8 MB',
      'rating': '4.9',
      'category': 'Scale & Cloud',
    },
  ];

  @override
  State<AddonDetailScreen> createState() => _AddonDetailScreenState();
}

class _AddonDetailScreenState extends State<AddonDetailScreen> with TickerProviderStateMixin {
  bool _isProcessing = false;
  double _progress = 0.0;
  AnimationController? _progressController;

  String get _addonKey => widget.addonKey;

  Map<String, dynamic> get _addon {
    return AddonDetailScreen.addonsMetadata.firstWhere((a) => a['key'] == _addonKey);
  }

  bool get _isInstalled {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    return provider.activeStore?.addons.contains(_addonKey) ?? false;
  }

  bool get _isLocked {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    return !(provider.activeStore?.subscriptionPlan == 'Standard') &&
        !(provider.userProfile?.role == 'Super Admin') &&
        !(provider.activeStore?.purchasedAddons.contains(_addonKey) ?? false);
  }

  double get _price {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    return (provider.platformLimits['rate_$_addonKey'] ?? 0).toDouble();
  }

  // Reviews
  List<Map<String, dynamic>> _reviews = [];
  bool _loadingReviews = true;
  double _avgRating = 0.0;
  int _totalRatings = 0;
  Map<int, int> _ratingDistribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

  // Review form
  final _reviewController = TextEditingController();
  int _userRating = 5;
  bool _submittingReview = false;
  bool _hasUserReview = false;
  bool _showReviewForm = false;
  bool _submittingQuickRating = false;

  static final Map<String, List<String>> _addonFeatures = {
    'employee_management': [
      'Create and manage employee profiles',
      'Assign roles: Admin, Cashier, Kitchen, Waiter',
      'Set custom permissions per role',
      'Track attendance and shift hours',
      'Performance reports and analytics',
      'PIN-based employee login for POS',
    ],
    'table_reservation': [
      'Interactive floor plan editor',
      'Drag and drop table arrangement',
      'Real-time table status tracking',
      'Per-seat and per-table billing modes',
      'Table reservation with time slots',
      'Quick order from table view',
    ],
    'supplier_management': [
      'Create and manage supplier profiles',
      'Track purchase orders',
      'Incoming stock management',
      'Supplier payment tracking',
      'Purchase history reports',
    ],
    'kds_management': [
      'Digital kitchen order display',
      'Real-time order status tracking',
      'Order priority management',
      'Multi-station support',
      'Audio alerts for new orders',
    ],
    'franchise_management': [
      'Multi-location dashboard',
      'Centralized menu management',
      'Per-store analytics and reports',
      'Franchise partner onboarding',
      'Performance comparison across stores',
    ],
    'central_catalog': [
      'Global product catalog management',
      'Push products to all stores',
      'Centralized price management',
      'Bulk import/export products',
    ],
    'customer_management': [
      'Customer profile management',
      'Purchase history tracking',
      'Loyalty points system',
      'Customer segmentation',
      'Birthday and anniversary reminders',
    ],
    'data_center': [
      'Advanced data analytics dashboard',
      'Cloud backup management',
      'Custom sync frequency control',
      'Data export (CSV, PDF)',
      'Audit logs and activity tracking',
    ],
    'integration_hub': [
      'Connect with Swiggy & Zomato',
      'Unified order management',
      'Auto-accept online orders',
      'Menu sync to all platforms',
      'Commission tracking per platform',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _progressController?.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    try {
      final db = FirebaseFirestore.instance;
      final snapshot = await db
          .collection('addon_reviews')
          .where('addonKey', isEqualTo: _addonKey)
          .get();

      final provider = Provider.of<DashboardProvider>(context, listen: false);
      final currentUserId = provider.userProfile?.uid;

      final reviews = <Map<String, dynamic>>[];
      double totalStars = 0;
      final dist = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      bool hasUserReview = false;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rating = (data['rating'] as num?)?.toInt() ?? 5;
        reviews.add({
          'id': doc.id,
          'userId': data['userId'] ?? '',
          'userName': data['userName'] ?? 'Anonymous',
          'rating': rating,
          'comment': data['comment'] ?? '',
          'createdAt': data['createdAt'],
        });
        totalStars += rating;
        dist[rating] = (dist[rating] ?? 0) + 1;
        if (data['userId'] == currentUserId) hasUserReview = true;
      }

      reviews.sort((a, b) {
        final aTime = a['createdAt'];
        final bTime = b['createdAt'];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        if (aTime is Timestamp && bTime is Timestamp) return bTime.compareTo(aTime);
        return 0;
      });

      if (mounted) {
        setState(() {
          _reviews = reviews;
          _totalRatings = reviews.length;
          _avgRating = reviews.isNotEmpty ? totalStars / reviews.length : 0.0;
          _ratingDistribution = dist;
          _hasUserReview = hasUserReview;
          _loadingReviews = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reviews: $e');
      if (mounted) setState(() { _loadingReviews = false; _reviews = []; });
    }
  }

  Future<void> _submitReview() async {
    final comment = _reviewController.text.trim();
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final user = provider.userProfile;
    if (user == null) return;

    final userName = user.name.isNotEmpty ? user.name : user.email;

    setState(() {
      _submittingReview = true;
      _reviews.insert(0, {
        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'userId': user.uid,
        'userName': userName,
        'rating': _userRating,
        'comment': comment,
        'createdAt': Timestamp.now(),
      });
      _hasUserReview = true;
      _showReviewForm = false;
      _recalcStats();
    });
    _reviewController.clear();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.check_circle, color: Colors.white, size: 18), const SizedBox(width: AppSpacing.sm), Text(AppLocalizations.t(context, 'Review submitted!'))]),
      backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));

    try {
      await FirebaseFirestore.instance.collection('addon_reviews').add({
        'addonKey': _addonKey,
        'userId': user.uid,
        'userName': userName,
        'rating': _userRating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _loadReviews();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sync error: $e"), backgroundColor: AppColors.warning));
    } finally {
      if (mounted) setState(() => _submittingReview = false);
    }
  }

  Future<void> _submitQuickRating(int stars) async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final user = provider.userProfile;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'Please sign in to rate.')), backgroundColor: AppColors.warning));
      return;
    }

    final userName = user.name.isNotEmpty ? user.name : user.email;

    setState(() {
      _submittingQuickRating = true;
      _reviews.insert(0, {
        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'userId': user.uid,
        'userName': userName,
        'rating': stars,
        'comment': '',
        'createdAt': Timestamp.now(),
      });
      _hasUserReview = true;
      _recalcStats();
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.star, color: AppColors.warning, size: 18), const SizedBox(width: AppSpacing.sm), Text("Rated $stars stars!")]),
      backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));

    try {
      await FirebaseFirestore.instance.collection('addon_reviews').add({
        'addonKey': _addonKey,
        'userId': user.uid,
        'userName': userName,
        'rating': stars,
        'comment': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _loadReviews();
    } catch (e) {
      debugPrint('Quick rating sync error: $e');
    } finally {
      if (mounted) setState(() => _submittingQuickRating = false);
    }
  }

  void _recalcStats() {
    double totalStars = 0;
    final dist = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _reviews) {
      final rating = (r['rating'] as int?) ?? 5;
      totalStars += rating;
      dist[rating] = (dist[rating] ?? 0) + 1;
    }
    _totalRatings = _reviews.length;
    _avgRating = _reviews.isNotEmpty ? totalStars / _reviews.length : 0.0;
    _ratingDistribution = dist;
  }

  Future<void> _deleteReview(String reviewId) async {
    try {
      await FirebaseFirestore.instance.collection('addon_reviews').doc(reviewId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'Review deleted.'))));
      setState(() => _loadingReviews = true);
      await _loadReviews();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error));
    }
  }

  Future<void> _handleInstall() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final currentAddons = Set<String>.from(provider.activeStore?.addons ?? []);
    final title = _addon['title'] as String;
    final isSuperAdmin = provider.userProfile?.role == 'Super Admin';
    final isPurchased = (provider.activeStore?.purchasedAddons ?? []).contains(_addonKey);
    final isStandardPlan = provider.activeStore?.subscriptionPlan == 'Standard';
    if (!isStandardPlan && !isSuperAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.t(context, 'Addons are only available on the Standard plan. Please upgrade your store subscription first.')),
        backgroundColor: AppColors.warning,
      ));
      return;
    }

    final price = _price;

    if (!isSuperAdmin && !isPurchased) {
      final adminConfig = await provider.fetchAdminConfig();
      if (!mounted) return;
      final upiIdVal = adminConfig['adminUpiId']?.toString() ?? '';
      final upiId = upiIdVal.isEmpty ? 'biztonicautomation@okaxis' : upiIdVal;

      final selection = await showDialog<Map>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Select Billing for $title"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPlanOption(ctx, 'Monthly', price, Icons.calendar_view_month),
              const SizedBox(height: AppSpacing.md),
              _buildPlanOption(ctx, 'Yearly', price * 10, Icons.calendar_today, isBestValue: true),
              const SizedBox(height: AppSpacing.md),
              Text(AppLocalizations.t(context, 'Yearly plans include 2 months free!'), style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );

      if (!mounted) return;
      if (selection == null) return;

      final cycle = (selection['cycle'] as String?) ?? 'Monthly';
      final amount = (selection['amount'] ?? 0.0).toDouble();

      final paid = await showDialog<bool?>(
        context: context, 
        builder: (ctx) => PaymentQrDialog(
          planType: provider.activeStore?.subscriptionPlan ?? 'Standard',
          billingCycle: cycle, 
          amount: amount, 
          adminUpiId: upiId,
          selectedAddons: [_addonKey],
          addonRates: provider.platformLimits,
        ),
      );

      if (!mounted) return;
      if (paid != true) return;
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.t(context, 'Payment submitted! Module will be enabled once approved.')),
        backgroundColor: AppColors.primaryLight,
      ));
      return;
    }

    // --- Super Admin or Standard Plan Path ---
    final confirm = await showDialog<bool?>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const Icon(Icons.download_rounded, size: 48, color: AppColors.success),
      title: Text("Install $title?"),
      content: Text(AppLocalizations.t(context, 'This module will be added to your application.')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.t(context, 'CANCEL'))),
        ElevatedButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.download_rounded, size: 18), label: Text(AppLocalizations.t(context, 'INSTALL')),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      ],
    ));
    if (!mounted) return;
    if (confirm != true) return;

    setState(() { _isProcessing = true; _progress = 0.0; });
    _progressController?.dispose();
    _progressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    final anim = CurvedAnimation(parent: _progressController!, curve: const _ProgressCurve());
    anim.addListener(() { if (mounted) setState(() => _progress = anim.value); });
    _progressController!.forward();
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    try {
      final newAddons = List<String>.from(currentAddons)..add(_addonKey);
      await provider.updateStoreAddons(newAddons);
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() { _isProcessing = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [const Icon(Icons.check_circle, color: Colors.white, size: 20), const SizedBox(width: AppSpacing.sm), Text("$title installed!")]),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (mounted) { setState(() => _isProcessing = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error)); }
    } finally { _progressController?.dispose(); _progressController = null; }
  }

  Widget _buildPlanOption(BuildContext context, String cycle, double price, IconData icon, {bool isBestValue = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pop(context, <String, dynamic>{'cycle': cycle, 'amount': price}),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: isBestValue ? AppColors.warning : AppColors.textSecondary(context).withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16),
          color: isBestValue ? AppColors.warning.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isBestValue ? AppColors.warning : AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cycle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("\u20B9$price / ${cycle.toLowerCase()}", style: TextStyle(color: AppColors.textSecondary(context))),
                ],
              ),
            ),
            if (isBestValue)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(8)),
                child: Text(AppLocalizations.t(context, 'BEST VALUE'), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUninstall() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final currentAddons = Set<String>.from(provider.activeStore?.addons ?? []);
    final title = _addon['title'] as String;

    final confirm = await showDialog<bool?>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.error),
      title: Text("Uninstall $title?"),
      content: Text(AppLocalizations.t(context, 'Your data will be preserved if you reinstall later.')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.t(context, 'CANCEL'))),
        ElevatedButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.delete_outline, size: 18), label: Text(AppLocalizations.t(context, 'UNINSTALL')),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
      ],
    ));
    if (!mounted) return;
    if (confirm != true) return;

    setState(() { _isProcessing = true; _progress = 0.0; });
    _progressController?.dispose();
    _progressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    final anim = CurvedAnimation(parent: _progressController!, curve: const _ProgressCurve());
    anim.addListener(() { if (mounted) setState(() => _progress = anim.value); });
    _progressController!.forward();
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    try {
      final newAddons = List<String>.from(currentAddons)..remove(_addonKey);
      await provider.updateStoreAddons(newAddons);
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() { _isProcessing = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [const Icon(Icons.delete_outline, color: Colors.white, size: 20), const SizedBox(width: AppSpacing.sm), Text("$title uninstalled.")]),
        backgroundColor: AppColors.textSecondary(context), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (mounted) { setState(() => _isProcessing = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error)); }
    } finally { _progressController?.dispose(); _progressController = null; }
  }

  @override
  Widget build(BuildContext context) {
    final addon = _addon;
    final addonColor = addon['color'] as Color;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final features = _addonFeatures[_addonKey] ?? ['Feature details coming soon.'];
    final provider = Provider.of<DashboardProvider>(context);
    final currentUserId = provider.userProfile?.uid;

    return PosScaffold(
      title: addon['title'] as String,
      showGlobalActions: false,
      mainContent: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── HERO HEADER CARD ───
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    addonColor,
                    Color.lerp(addonColor, Colors.black, 0.35)!,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: addonColor.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      right: -40, top: -40,
                      child: Container(
                        width: 160, height: 160,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
                      ),
                    ),
                    Positioned(
                      left: -50, bottom: -30,
                      child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Row(
                        children: [
                          // App Icon
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                            ),
                            child: Icon(addon['icon'] as IconData, color: Colors.white, size: 36),
                          ),
                          const SizedBox(width: 20),
                          // Title and metadata
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  addon['title'] as String,
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppLocalizations.t(context, 'Biztonic Labs'),
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 12),
                                // Stats Row
                                Row(
                                  children: [
                                    _heroStat(Icons.star_rounded, _totalRatings > 0 ? _avgRating.toStringAsFixed(1) : "--"),
                                    const SizedBox(width: 16),
                                    _heroStat(Icons.sd_storage_outlined, addon['size'] as String),
                                    const SizedBox(width: 16),
                                    _heroStat(Icons.update, "v${addon['version']}"),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // ─── PLAY STORE CIRCULAR INSTALL BUTTON ───
                          _buildCircularInstallButton(addonColor, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ─── ABOUT SECTION ───
            _buildSectionCard(
              isDark: isDark,
              title: "About this module",
              icon: Icons.info_outline_rounded,
              iconColor: addonColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    addon['description'] as String,
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _modernChip(Icons.workspace_premium, "Standard Plan", addonColor, isDark),
                    _modernChip(Icons.calendar_today, "Feb 2026", addonColor, isDark),
                    _modernChip(Icons.download, addon['size'] as String, addonColor, isDark),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ─── FEATURES SECTION ───
            _buildSectionCard(
              isDark: isDark,
              title: "What's included",
              icon: Icons.checklist_rounded,
              iconColor: AppColors.success,
              child: Column(
                children: features.map((f) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, size: 12, color: AppColors.success),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(f, style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white70 : Colors.black87, height: 1.4)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // ─── RATINGS & REVIEWS SECTION ───
            _buildSectionCard(
              isDark: isDark,
              title: "Ratings & Reviews",
              icon: Icons.star_half_rounded,
              iconColor: AppColors.warning,
              child: _buildRatingsContent(isDark, currentUserId, provider),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── HERO STAT WIDGET ───
  Widget _heroStat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white60),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ─── PLAY STORE CIRCULAR INSTALL BUTTON ───
  Widget _buildCircularInstallButton(Color addonColor, bool isDark) {
    const double size = 64;

    // Currently installing: show circular progress with percentage
    if (_isProcessing) {
      return SizedBox(
        width: size, height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background track
            SizedBox(
              width: size, height: size,
              child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 3.5,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            // Animated progress arc
            SizedBox(
              width: size, height: size,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 3.5,
                color: Colors.white,
                strokeCap: StrokeCap.round,
              ),
            ),
            // Percentage text
            Text(
              "${(_progress * 100).toInt()}%",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    // Already installed: show green checkmark circle (tap to uninstall)
    if (_isInstalled) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _handleUninstall,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withValues(alpha: 0.2),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 6),
              const Text("Installed", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    // Locked: show lock icon
    if (_isLocked) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _handleInstall,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                ),
                child: const Icon(Icons.lock_outline, color: Colors.white54, size: 26),
              ),
              const SizedBox(height: 6),
              const Text("Locked", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    // Default: Install button (Play Store style)
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _handleInstall,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size, height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(Icons.download_rounded, color: addonColor, size: 30),
            ),
            const SizedBox(height: 6),
            const Text("Install", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ─── SECTION CARD WRAPPER ───
  Widget _buildSectionCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ─── RATINGS CONTENT ───
  Widget _buildRatingsContent(bool isDark, String? currentUserId, DashboardProvider provider) {
    if (_loadingReviews) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rating Summary
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(children: [
              Text(
                _totalRatings > 0 ? _avgRating.toStringAsFixed(1) : "--",
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              ),
              _starRow(_avgRating, 18),
              const SizedBox(height: 4),
              Text("$_totalRatings ratings", style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45)),
            ]),
            const SizedBox(width: 24),
            Expanded(child: _buildRatingBars(isDark)),
          ],
        ),

        const SizedBox(height: 20),

        // Quick Rate Card
        if (!_hasUserReview)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
            ),
            child: _submittingQuickRating
              ? const Center(child: Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
              : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.t(context, 'Rate this module'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 2),
                      Text(AppLocalizations.t(context, 'Tap a star to rate'), style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45)),
                    ],
                  ),
                ),
                ...List.generate(5, (i) => GestureDetector(
                  onTap: () => _submitQuickRating(i + 1),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3),
                    child: Icon(Icons.star_border_rounded, color: AppColors.warning, size: 32),
                  ),
                )),
              ],
            ),
          ),

        if (!_hasUserReview && !_showReviewForm)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextButton.icon(
              onPressed: () => setState(() => _showReviewForm = true),
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: Text(AppLocalizations.t(context, 'Write a detailed review')),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),

        if (_showReviewForm && !_hasUserReview)
          _buildWriteReviewForm(isDark),

        if (_reviews.isEmpty && !_loadingReviews)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Column(children: [
                Icon(Icons.rate_review_outlined, size: 36, color: isDark ? Colors.white24 : Colors.black26),
                const SizedBox(height: 8),
                Text(AppLocalizations.t(context, 'No reviews yet. Be the first!'), style: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 13)),
              ]),
            ),
          )
        else
          ..._reviews.map((r) => _buildReviewCard(r, currentUserId, isDark, provider.userProfile?.role == 'Super Admin')),
      ],
    );
  }

  Widget _buildWriteReviewForm(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(AppLocalizations.t(context, 'Write a Review'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87))),
            IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _showReviewForm = false), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Text(AppLocalizations.t(context, 'Your rating: '), style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54)),
            ...List.generate(5, (i) => GestureDetector(
              onTap: () => setState(() => _userRating = i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(i < _userRating ? Icons.star_rounded : Icons.star_border_rounded, color: AppColors.warning, size: 28),
              ),
            )),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _reviewController,
            maxLines: 3,
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: "Share your experience...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
              contentPadding: const EdgeInsets.all(14),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _submittingReview ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: _submittingReview
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(AppLocalizations.t(context, 'Submit'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review, String? currentUserId, bool isDark, bool isSuperAdmin) {
    final isOwn = review['userId'] == currentUserId;
    final createdAt = review['createdAt'];
    String dateStr = '';
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      dateStr = '${months[dt.month - 1]} ${dt.year}';
    }
    final comment = review['comment'] as String;
    final avatarColors = [AppColors.primary, AppColors.success, AppColors.warning, AppColors.error, const Color(0xFF8B5CF6)];
    final avatarColor = avatarColors[(review['userName'].hashCode).abs() % avatarColors.length];

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: isOwn ? 0.06 : 0.03)
              : (isOwn ? AppColors.primary.withValues(alpha: 0.04) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOwn ? AppColors.primary.withValues(alpha: 0.25) : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: avatarColor.withValues(alpha: 0.15),
                child: Text((review['userName'] as String).substring(0, 1).toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: avatarColor)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(review['userName'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis)),
                    if (isOwn) Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(AppLocalizations.t(context, 'You'), style: const TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  _starRow((review['rating'] as int).toDouble(), 13),
                ],
              )),
              if (dateStr.isNotEmpty) Text(dateStr, style: TextStyle(fontSize: 10, color: isDark ? Colors.white30 : Colors.black38)),
              if (isSuperAdmin) IconButton(icon: Icon(Icons.delete_outline, size: 16, color: AppColors.error.withValues(alpha: 0.7)), onPressed: () => _deleteReview(review['id']), visualDensity: VisualDensity.compact, padding: const EdgeInsets.only(left: 4)),
            ]),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(comment, style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54, height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }

  // ─── HELPER WIDGETS ───

  Widget _modernChip(IconData icon, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black54)),
      ]),
    );
  }

  Widget _starRow(double rating, double size) {
    return Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) {
      if (i < rating.floor()) return Icon(Icons.star_rounded, size: size, color: AppColors.warning);
      if (i < rating) return Icon(Icons.star_half_rounded, size: size, color: AppColors.warning);
      return Icon(Icons.star_border_rounded, size: size, color: AppColors.warning);
    }));
  }

  Widget _buildRatingBars(bool isDark) {
    return Column(children: List.generate(5, (i) {
      final star = 5 - i;
      final count = _ratingDistribution[star] ?? 0;
      final pct = _totalRatings > 0 ? count / _totalRatings : 0.0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(children: [
          SizedBox(width: 12, child: Text("$star", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.black45))),
          const SizedBox(width: 6),
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct, minHeight: 8,
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              valueColor: const AlwaysStoppedAnimation(AppColors.warning),
            ),
          )),
        ]),
      );
    }));
  }
}

class _ProgressCurve extends Curve {
  const _ProgressCurve();
  @override
  double transformInternal(double t) {
    if (t < 0.15) return t / 0.15 * 0.20;
    if (t < 0.5) return 0.20 + ((t - 0.15) / 0.35) * 0.35;
    if (t < 0.75) return 0.55 + ((t - 0.5) / 0.25) * 0.25;
    return 0.80 + ((t - 0.75) / 0.25) * 0.20;
  }
}
