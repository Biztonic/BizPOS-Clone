// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import 'payment_qr_dialog.dart';

class AddonDetailScreen extends StatefulWidget {
  final Map<String, dynamic> addon;
  final bool isInstalled;
  final bool isLocked;
  final dynamic price;

  const AddonDetailScreen({
    super.key,
    required this.addon,
    required this.isInstalled,
    required this.isLocked,
    this.price = 0,
  });

  @override
  State<AddonDetailScreen> createState() => _AddonDetailScreenState();
}

class _AddonDetailScreenState extends State<AddonDetailScreen> with TickerProviderStateMixin {
  bool _isProcessing = false;
  double _progress = 0.0;
  AnimationController? _progressController;
  late bool _isInstalled;

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
    _isInstalled = widget.isInstalled;
    _loadReviews();
  }

  @override
  void dispose() {
    _progressController?.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  String get _addonKey => widget.addon['key'] as String;

  Future<void> _loadReviews() async {
    try {
      final db = FirebaseFirestore.instance;
      // Simple query without orderBy to avoid needing composite index
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

      // Sort client-side by createdAt descending
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

    // Optimistic UI — update instantly
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
      content: const Row(children: [Icon(Icons.check_circle, color: Colors.white, size: 18), SizedBox(width: 8), Text("Review submitted!")]),
      backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      // Silently reload to sync with actual Firestore IDs
      _loadReviews();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sync error: $e"), backgroundColor: Colors.orange));
    } finally {
      if (mounted) setState(() => _submittingReview = false);
    }
  }

  /// Quick rating only (no comment required)
  Future<void> _submitQuickRating(int stars) async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final user = provider.userProfile;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please sign in to rate."), backgroundColor: Colors.orange));
      return;
    }

    final userName = user.name.isNotEmpty ? user.name : user.email;

    // Optimistic UI — update instantly
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
      content: Row(children: [const Icon(Icons.star, color: Colors.amber, size: 18), const SizedBox(width: 8), Text("Rated $stars stars!")]),
      backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      // Silently reload to sync with actual Firestore IDs
      _loadReviews();
    } catch (e) {
      debugPrint('Quick rating sync error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sync error: $e"), backgroundColor: Colors.orange));
    } finally {
      if (mounted) setState(() => _submittingQuickRating = false);
    }
  }

  /// Recalculate stats from local _reviews list (for optimistic updates)
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Review deleted.")));
      setState(() => _loadingReviews = true);
      await _loadReviews();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _handleInstall() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final currentAddons = Set<String>.from(provider.activeStore?.addons ?? []);
    final title = widget.addon['title'] as String;
    final isSuperAdmin = provider.userProfile?.role == 'Super Admin';
    final isPurchased = (provider.activeStore?.purchasedAddons ?? []).contains(_addonKey);

    if (!isSuperAdmin && !isPurchased) {
      // 1. Fetch Admin Config for UPI and Rates
      final adminConfig = await provider.fetchAdminConfig();
      final upiId = adminConfig['adminUpiId'] ?? '';
      
      if (upiId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment system currently unavailable. Please contact support.")));
        return;
      }

      // 2. Select Billing Cycle
      final selection = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text("Select Billing for $title"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPlanOption(ctx, 'Monthly', (widget.price).toDouble(), Icons.calendar_view_month),
              const SizedBox(height: 12),
              _buildPlanOption(ctx, 'Yearly', (widget.price * 10).toDouble(), Icons.calendar_today, isBestValue: true),
              const SizedBox(height: 12),
              const Text("Yearly plans include 2 months free!", style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );

      if (selection == null) return;

      final cycle = selection['cycle'] as String;
      final amount = selection['amount'] as double;

      // 3. Show Payment QR Dialog
      final paid = await showDialog<bool>(
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

      if (paid != true) return;
      
      // Notify about pending approval
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Payment submitted! Module will be enabled once approved."),
        backgroundColor: Colors.blue,
      ));
      return; // Skip local install as it needs admin approval now
    }

    // --- Super Admin Path (Legacy/Bypass) ---
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(Icons.download_rounded, size: 48, color: Colors.green),
      title: Text("Install $title?"),
      content: const Text("This module will be added to your application."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
        ElevatedButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.download_rounded, size: 18), label: const Text("INSTALL"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
      ],
    ));
    if (confirm != true) return;

    setState(() { _isProcessing = true; _progress = 0.0; });
    _progressController?.dispose();
    _progressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    final anim = CurvedAnimation(parent: _progressController!, curve: const _ProgressCurve());
    anim.addListener(() { if (mounted) setState(() => _progress = anim.value); });
    _progressController!.forward();
    await Future.delayed(const Duration(milliseconds: 2000));
    try {
      final newAddons = List<String>.from(currentAddons)..add(_addonKey);
      await provider.updateStoreAddons(newAddons);
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() { _isInstalled = true; _isProcessing = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [const Icon(Icons.check_circle, color: Colors.white, size: 20), const SizedBox(width: 8), Text("$title installed!")]),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    } catch (e) {
      if (mounted) { setState(() => _isProcessing = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)); }
    } finally { _progressController?.dispose(); _progressController = null; }
  }

  Widget _buildPlanOption(BuildContext context, String cycle, double price, IconData icon, {bool isBestValue = false}) {
    return InkWell(
      onTap: () => Navigator.pop(context, {'cycle': cycle, 'amount': price}),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: isBestValue ? Colors.orange : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: isBestValue ? Colors.orange.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: isBestValue ? Colors.orange : Colors.indigo),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cycle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("₹$price / ${cycle.toLowerCase()}", style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            if (isBestValue)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                child: const Text("BEST VALUE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUninstall() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final currentAddons = Set<String>.from(provider.activeStore?.addons ?? []);
    final title = widget.addon['title'] as String;

    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: Icon(Icons.warning_amber_rounded, size: 48, color: Colors.red.shade400),
      title: Text("Uninstall $title?"),
      content: const Text("Your data will be preserved if you reinstall later."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
        ElevatedButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.delete_outline, size: 18), label: const Text("UNINSTALL"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
      ],
    ));
    if (confirm != true) return;

    setState(() { _isProcessing = true; _progress = 0.0; });
    _progressController?.dispose();
    _progressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    final anim = CurvedAnimation(parent: _progressController!, curve: const _ProgressCurve());
    anim.addListener(() { if (mounted) setState(() => _progress = anim.value); });
    _progressController!.forward();
    await Future.delayed(const Duration(milliseconds: 1400));
    try {
      final newAddons = List<String>.from(currentAddons)..remove(_addonKey);
      await provider.updateStoreAddons(newAddons);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() { _isInstalled = false; _isProcessing = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [const Icon(Icons.delete_outline, color: Colors.white, size: 20), const SizedBox(width: 8), Text("$title uninstalled.")]),
          backgroundColor: Colors.grey.shade700, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    } catch (e) {
      if (mounted) { setState(() => _isProcessing = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)); }
    } finally { _progressController?.dispose(); _progressController = null; }
  }

  @override
  Widget build(BuildContext context) {
    final addon = widget.addon;
    final addonColor = addon['color'] as Color;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final features = _addonFeatures[_addonKey] ?? ['Feature details coming soon.'];
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final currentUserId = provider.userProfile?.uid;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // HERO APP BAR - responsive height
          SliverAppBar(
            expandedHeight: isMobile ? 160 : 180,
            pinned: true,
            backgroundColor: addonColor,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [addonColor, addonColor.withValues(alpha: 0.7)]),
                ),
                child: SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          width: isMobile ? 56 : 72, height: isMobile ? 56 : 72,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                          child: Icon(addon['icon'] as IconData, color: Colors.white, size: isMobile ? 30 : 40),
                        ),
                        const SizedBox(height: 8),
                        Text(addon['title'] as String, style: TextStyle(color: Colors.white, fontSize: isMobile ? 17 : 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        Text("Biztonic Labs", style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final compact = w < 500;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // STATS ROW
                    Container(
                      padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statCol(_totalRatings > 0 ? "${_avgRating.toStringAsFixed(1)} ★" : "—", "$_totalRatings ratings", compact),
                          Container(width: 1, height: compact ? 24 : 30, color: Theme.of(context).dividerColor),
                          _statCol(addon['size'] as String, "Size", compact),
                          Container(width: 1, height: compact ? 24 : 30, color: Theme.of(context).dividerColor),
                          _statCol("v${addon['version']}", "Version", compact),
                        ],
                      ),
                    ),

                    // INSTALL / UNINSTALL
                    Padding(padding: EdgeInsets.all(compact ? 12 : 16), child: _buildActionArea(isDark)),

                    const Divider(height: 1),

                    // ABOUT
                    _sectionTitle("About", compact),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
                      child: Text(addon['description'] as String, style: TextStyle(fontSize: compact ? 13 : 14, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.75))),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
                      child: Wrap(spacing: 6, runSpacing: 6, children: [
                        _chip(Icons.workspace_premium, "Standard Plan", isDark, compact),
                        _chip(Icons.calendar_today, "Feb 2026", isDark, compact),
                        _chip(Icons.download, addon['size'] as String, isDark, compact),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),

                    // FEATURES
                    _sectionTitle("Features", compact),
                    ...features.map((f) => Padding(
                      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 3),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.check_circle_outline, size: compact ? 14 : 16, color: addonColor),
                        const SizedBox(width: 8),
                        Expanded(child: Text(f, style: TextStyle(fontSize: compact ? 12 : 13))),
                      ]),
                    )),
                    const SizedBox(height: 10),
                    const Divider(height: 1),

                    // RATINGS & REVIEWS
                    _sectionTitle("Ratings & Reviews", compact),

                    if (_loadingReviews)
                      const Padding(padding: EdgeInsets.all(20), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))))
                    else ...[
                      // Rating summary — stack vertically on mobile
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
                        child: compact
                          ? Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(_totalRatings > 0 ? _avgRating.toStringAsFixed(1) : "—", style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      _starRow(_avgRating, 16),
                                      Text("$_totalRatings ratings", style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color)),
                                    ]),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildRatingBars(isDark),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Column(children: [
                                  Text(_totalRatings > 0 ? _avgRating.toStringAsFixed(1) : "—", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                                  _starRow(_avgRating, 16),
                                  const SizedBox(height: 4),
                                  Text("$_totalRatings ratings", style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color)),
                                ]),
                                const SizedBox(width: 24),
                                Expanded(child: _buildRatingBars(isDark)),
                              ],
                            ),
                      ),
                      const SizedBox(height: 12),

                      // Quick Rate (tap stars) — only if user hasn't reviewed
                      if (!_hasUserReview)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: _submittingQuickRating
                              ? const Center(child: Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
                              : Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Rate this module", style: TextStyle(fontWeight: FontWeight.bold, fontSize: compact ? 13 : 14, color: isDark ? Colors.white : Colors.black87)),
                                      const SizedBox(height: 4),
                                      Text("Tap a star to rate", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Theme.of(context).textTheme.bodySmall?.color)),
                                    ],
                                  ),
                                ),
                                // Tap-to-rate stars
                                ...List.generate(5, (i) => GestureDetector(
                                  onTap: () => _submitQuickRating(i + 1),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    child: Icon(Icons.star_border, color: Colors.amber, size: compact ? 28 : 32),
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ),

                      // Write detailed review button
                      if (!_hasUserReview && !_showReviewForm)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 8),
                          child: TextButton.icon(
                            onPressed: () => setState(() => _showReviewForm = true),
                            icon: const Icon(Icons.rate_review_outlined, size: 18),
                            label: const Text("Write a detailed review"),
                            style: TextButton.styleFrom(foregroundColor: Colors.indigo),
                          ),
                        ),

                      // Review form
                      if (_showReviewForm && !_hasUserReview)
                        _buildWriteReviewForm(isDark, compact),

                      // Review list
                      if (_reviews.isEmpty && !_loadingReviews)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(child: Text("No reviews yet. Be the first!", style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13))),
                        )
                      else
                        ..._reviews.map((r) => _buildReviewCard(r, currentUserId, isDark, compact, provider.userProfile?.role == 'Super Admin')),
                    ],

                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionArea(bool isDark) {
    if (widget.isLocked) {
      return SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(
        onPressed: null, icon: const Icon(Icons.lock_outline, size: 18), label: const Text("Upgrade to Install"),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.grey.shade400 : Colors.grey,
          side: BorderSide(color: isDark ? Colors.grey.shade600 : Colors.grey),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ));
    }
    if (_isProcessing) {
      return Column(children: [
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
            foregroundColor: isDark ? Colors.white : Colors.black87,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(_isInstalled ? "Uninstalling... ${(_progress * 100).toInt()}%" : "Installing... ${(_progress * 100).toInt()}%"),
        )),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(
          value: _progress, minHeight: 4,
          backgroundColor: isDark ? Colors.white24 : Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(_isInstalled ? Colors.red.shade400 : Colors.green),
        )),
      ]);
    }
    if (_isInstalled) {
      return SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(
        onPressed: _handleUninstall, icon: const Icon(Icons.delete_outline, size: 18), label: const Text("Uninstall"),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.red.shade300 : Colors.red.shade400,
          side: BorderSide(color: isDark ? Colors.red.shade300 : Colors.red.shade300, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ));
    }
    final isPurchased = (Provider.of<DashboardProvider>(context, listen: false).activeStore?.purchasedAddons ?? []).contains(_addonKey);
    
    return SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
      onPressed: _handleInstall, 
      icon: Icon(isPurchased ? Icons.install_desktop : Icons.download_rounded, size: 18), 
      label: Text(isPurchased ? "Install Purchased Module" : "Install", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPurchased ? Colors.indigo : Colors.green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    ));
  }

  Widget _buildWriteReviewForm(bool isDark, bool compact) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 8),
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text("Write a Review", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _showReviewForm = false), visualDensity: VisualDensity.compact),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text("Your rating: ", style: TextStyle(fontSize: compact ? 12 : 13)),
              ...List.generate(5, (i) => GestureDetector(
                onTap: () => setState(() => _userRating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(i < _userRating ? Icons.star : Icons.star_border, color: Colors.amber, size: compact ? 24 : 28),
                ),
              )),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reviewController,
            maxLines: 3,
            style: TextStyle(fontSize: compact ? 13 : 14),
            decoration: InputDecoration(
              hintText: "Share your experience...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
              contentPadding: const EdgeInsets.all(10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _submittingReview ? null : _submitReview,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8)),
              child: _submittingReview ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Submit", style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review, String? currentUserId, bool isDark, bool compact, bool isSuperAdmin) {
    final isOwn = review['userId'] == currentUserId;
    final createdAt = review['createdAt'];
    String dateStr = '';
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      dateStr = '${months[dt.month - 1]} ${dt.year}';
    }
    final comment = review['comment'] as String;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 4),
      child: Container(
        padding: EdgeInsets.all(compact ? 10 : 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isOwn ? Colors.indigo.withValues(alpha: 0.3) : Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                radius: compact ? 12 : 14,
                backgroundColor: Colors.primaries[(review['userName'].hashCode).abs() % Colors.primaries.length].withValues(alpha: 0.2),
                child: Text((review['userName'] as String).substring(0, 1).toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: compact ? 10 : 12, color: Colors.primaries[(review['userName'].hashCode).abs() % Colors.primaries.length])),
              ),
              const SizedBox(width: 8),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(review['userName'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: compact ? 12 : 13), overflow: TextOverflow.ellipsis)),
                    if (isOwn) Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: const Text("You", style: TextStyle(fontSize: 8, color: Colors.indigo, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  _starRow((review['rating'] as int).toDouble(), compact ? 11 : 12),
                ],
              )),
              if (dateStr.isNotEmpty) Text(dateStr, style: TextStyle(fontSize: compact ? 9 : 10, color: Theme.of(context).textTheme.bodySmall?.color)),
              // Only Super Admin can delete any review
              if (isSuperAdmin)
                IconButton(icon: Icon(Icons.delete_outline, size: compact ? 14 : 16, color: Colors.red), onPressed: () => _deleteReview(review['id']), visualDensity: VisualDensity.compact, padding: const EdgeInsets.only(left: 4)),
            ]),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(comment, style: TextStyle(fontSize: compact ? 12 : 13, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statCol(String value, String label, bool compact) {
    return Column(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: compact ? 13 : 15)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: compact ? 10 : 11, color: Theme.of(context).textTheme.bodySmall?.color)),
    ]);
  }

  Widget _sectionTitle(String title, bool compact) {
    return Padding(padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 14, 16, 8), child: Text(title, style: TextStyle(fontSize: compact ? 15 : 17, fontWeight: FontWeight.bold)));
  }

  Widget _chip(IconData icon, String label, bool isDark, bool compact) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 5),
      decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100, borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: compact ? 11 : 13, color: Colors.grey), SizedBox(width: compact ? 4 : 5), Text(label, style: TextStyle(fontSize: compact ? 10 : 12))]),
    );
  }

  Widget _starRow(double rating, double size) {
    return Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) {
      if (i < rating.floor()) return Icon(Icons.star, size: size, color: Colors.amber);
      if (i < rating) return Icon(Icons.star_half, size: size, color: Colors.amber);
      return Icon(Icons.star_border, size: size, color: Colors.amber);
    }));
  }

  Widget _buildRatingBars(bool isDark) {
    return Column(children: List.generate(5, (i) {
      final star = 5 - i;
      final count = _ratingDistribution[star] ?? 0;
      final pct = _totalRatings > 0 ? count / _totalRatings : 0.0;
      return Padding(padding: const EdgeInsets.symmetric(vertical: 1.5), child: Row(children: [
        SizedBox(width: 10, child: Text("$star", style: const TextStyle(fontSize: 10))),
        const SizedBox(width: 4),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(
          value: pct, minHeight: 6,
          backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation(Colors.amber),
        ))),
      ]));
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
