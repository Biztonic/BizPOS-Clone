import '../../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';
import 'package:biztonic_pos/core/design/tokens/app_typography.dart';
import 'package:biztonic_pos/core/design/tokens/app_radius.dart';
import 'package:biztonic_pos/core/design/tokens/app_shadows.dart';

import 'dart:math' as math;
// ignore_for_file: unused_local_variable, unused_element
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' as legacy;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:battery_plus/battery_plus.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added
import 'dart:convert'; // Added
import 'widgets/calculator_widget.dart';
import 'widgets/calendar_widget.dart';

import '../../providers/dashboard_provider.dart';
import '../../widgets/feature_guard.dart';
import '../../services/printer_manager_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import '../../core/reporting/reporting_provider.dart';
import '../../features/reporting/domain/entities/dashboard_stats.dart';
enum QuickActionState { menu, reminders, lastBill, hold, refund }

class DashboardInsightsScreen extends ConsumerStatefulWidget {
  const DashboardInsightsScreen({super.key});

  @override
  ConsumerState<DashboardInsightsScreen> createState() => _DashboardInsightsScreenState();
}

class _DashboardInsightsScreenState extends ConsumerState<DashboardInsightsScreen> with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _now = DateTime.now();
  
  // Battery State
  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.full;
  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _batteryStateSubscription;
  Timer? _batteryTimer; // Polling timer

  // Reminders State
  QuickActionState _actionState = QuickActionState.menu;
  Timer? _reminderTimer;
  List<Map<String, dynamic>> _todayReminders = [];
  List<Map<String, dynamic>> _upcomingReminders = [];
  bool _hasCheckedPrinter = false; // Guard to show once per session

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startClock();
    _initBattery();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() => _now = DateTime.now());
    }
  }

  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _initBattery() async {
     try {
       // Initial fetch
       final level = await _battery.batteryLevel;
       if (mounted) setState(() => _batteryLevel = level);
       
       // Listen to state changes (Charging/Discharging)
       _batteryStateSubscription = _battery.onBatteryStateChanged.listen((state) {
         if (mounted) setState(() => _batteryState = state);
         _updateLevel();
       });
       
       // Poll level every 60s (Some devices don't push level updates frequent enough)
       _batteryTimer = Timer.periodic(const Duration(seconds: 60), (_) => _updateLevel());
     } catch (e) { /* Error ignored */ }
  }
  
  Future<void> _updateLevel() async {
     final level = await _battery.batteryLevel;
     if (mounted) setState(() => _batteryLevel = level);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _batteryTimer?.cancel();
    _batteryStateSubscription?.cancel();
    _reminderTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = legacy.Provider.of<DashboardProvider>(context);
    
    // AUTO-SHOW PRINTER PROMPT (One stay per session)
    if (provider.needsPrinterSetup && !_hasCheckedPrinter) {
       _hasCheckedPrinter = true; 
       WidgetsBinding.instance.addPostFrameCallback((_) {
          _showPrinterSetupDialog(context, provider);
       });
    }

    final isDarkMode = provider.isDarkMode;

    final reportingState = ref.watch(reportingProvider);
    final stats = reportingState.stats ?? DashboardStats.empty();
    
    // Calculate Insights
    double totalSales = stats.monthSales;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header (Store Name, Theme Switch, Battery, Clock)
              Row(
                children: [
                   // LEFT: Store Info
                   Container(
                      height: 60, width: 60,
                      decoration: BoxDecoration(
                         color: AppColors.adaptivePrimary(context).withValues(alpha: 0.1),
                         borderRadius: AppRadius.borderSm,
                      ),
                      child: Icon(Icons.store, color: AppColors.adaptivePrimary(context), size: 32),
                   ),
                   const SizedBox(width: AppSpacing.md),
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        Text(provider.activeStore?.name ?? "STORE", style: AppTypography.headlineMedium.copyWith(fontSize: 28, color: AppColors.textPrimary(context), fontWeight: FontWeight.bold)),
                        Text(provider.userProfile?.name ?? "User", style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context), fontWeight: FontWeight.w500)),
                     ],
                   ),
                   
                   const Spacer(), // PUSH TO CENTER
                   
                   // CENTER: Status Icons (Online, Settings, Theme, Battery)
                   Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Online Status
                        Container(
                           padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                           decoration: BoxDecoration(
                              color: (provider.isOnline ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                              borderRadius: AppRadius.borderSm,
                              border: Border.all(color: (provider.isOnline ? AppColors.success : AppColors.error).withValues(alpha: 0.5), width: 1),
                           ),
                           child: Row(
                              children: [
                                 Icon(provider.isOnline ? Icons.wifi : Icons.wifi_off, color: provider.isOnline ? AppColors.success : AppColors.error, size: 20),
                                 const SizedBox(width: AppSpacing.sm),
                                 Text(provider.isOnline ? "ONLINE" : "OFFLINE", style: AppTypography.labelLarge.copyWith(color: provider.isOnline ? AppColors.success : AppColors.error, fontSize: 13)),
                              ],
                           ),
                        ),
                        const SizedBox(width: AppSpacing.xl),

                        // Settings
                        IconButton(icon: Icon(Icons.settings, color: AppColors.textPrimary(context), size: 28), onPressed: () => context.go('/settings')),
                        const SizedBox(width: AppSpacing.md),

                        // Theme Switcher
                        IconButton(
                           icon: Icon(provider.isDarkMode ? Icons.light_mode : Icons.dark_mode, color: AppColors.textPrimary(context), size: 28),
                           onPressed: () => provider.toggleTheme(),
                           tooltip: "Toggle Theme",
                        ),
                        const SizedBox(width: AppSpacing.xl),
                        
                        // Battery Indicator (Standardized Size)
                        Row(
                           children: [
                              RotatedBox(
                                 quarterTurns: 3, 
                                 child: Icon(
                                    _batteryState == BatteryState.charging ? Icons.battery_charging_full : Icons.battery_full, 
                                    color: _batteryLevel < 20 ? AppColors.error : AppColors.success,
                                    size: 28
                                 ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text("$_batteryLevel%", style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                           ],
                        ),
                      ],
                   ),
                   
                   const Spacer(), // PUSH TO RIGHT

                   // RIGHT: Clock & Logout (Enhanced)
                   Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPrinterStatusIndicator(isDarkMode),
                        const SizedBox(width: AppSpacing.xl),
                        // Clock (Enhanced text style)
                        Column(
                           crossAxisAlignment: CrossAxisAlignment.end,
                           children: [
                              Text(DateFormat('hh:mm:ss a').format(_now), 
                                  style: AppTypography.displaySmall.copyWith(fontSize: 26, color: AppColors.adaptivePrimary(context), fontWeight: FontWeight.bold)), 
                              Text(DateFormat('EEEE, MMM d, yyyy').format(_now), 
                                  style: AppTypography.labelMedium.copyWith(
                                    color: AppColors.textSecondary(context)
                                  )),
                           ],
                        ),
                        const SizedBox(width: AppSpacing.xl),

                        // Logout
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: AppRadius.borderSm,
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: IconButton(
                             icon: const Icon(Icons.logout, color: AppColors.error, size: 24), 
                             onPressed: () {
                                provider.clearSession();
                                FirebaseAuth.instance.signOut();
                             }
                          ),
                        ),
                      ],
                   )
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // 2. Dashboard Content
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isPortrait = constraints.maxWidth < 600 || constraints.maxWidth < constraints.maxHeight;

                    if (isPortrait) {
                      return ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        children: [
                          // HERO BUTTON
                          SizedBox(
                            height: 200,
                            child: _AnimatedBillingButton(
                              onTap: () => context.go('/pos'),
                              isDarkMode: isDarkMode,
                              userName: provider.userProfile?.name ?? "User",
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          // INSIGHTS (Performance, Rushed Hours, Top Products)
                          FeatureGuard(
                            featureKey: 'card.sales_summary',
                            lockedChild: const SizedBox.shrink(),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 200,
                                  child: _PerformanceIndexCard(
                                     todaySales: stats.todaySales,
                                     todayCount: stats.todayOrders,
                                     avgDailySale: stats.avgDailySale,
                                     isDarkMode: isDarkMode,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                SizedBox(
                                  height: 200,
                                  child: _RushedHoursCard(
                                     peakHour: stats.peakHour,
                                     leastHour: stats.leastHour,
                                     hasOrders: provider.orders.isNotEmpty,
                                     isDarkMode: isDarkMode,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                SizedBox(
                                  height: 200,
                                  child: _TopSellingProductsCard(
                                     topProducts: stats.topProducts,
                                     isDarkMode: isDarkMode,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                SizedBox(
                                  height: 200,
                                  child: _PaymentBreakdownCard(
                                     paymentStats: stats.paymentStats,
                                     isDarkMode: isDarkMode,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          // QUICK ACTIONS
                          Text(AppLocalizations.t(context, 'QUICK ACTIONS'), style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary(context), letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            height: 350, 
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                               color: AppColors.surface(context),
                               borderRadius: AppRadius.borderMd,
                               border: Border.all(color: AppColors.border(context)),
                               boxShadow: AppShadows.adaptive(context),
                            ),
                            child: AnimatedSwitcher(
                               duration: const Duration(milliseconds: 300),
                               child: _buildQuickActionContent(provider, isDarkMode),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs), 
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT COLUMN: Hero Button & INSIGHTS
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              // HERO BUTTON
                              Expanded(
                                flex: 3, 
                                child: _AnimatedBillingButton(
                                  onTap: () => context.go('/pos'),
                                  isDarkMode: isDarkMode,
                                  userName: provider.userProfile?.name ?? "User",
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              // INSIGHTS ROW (Performance, Rushed Hours, Top Products)
                              Expanded(
                                flex: 2, 
                                child: FeatureGuard(
                                  featureKey: 'card.sales_summary',
                                  lockedChild: const SizedBox.shrink(),
                                  child: Row(
                                    children: [
                                      // 1. Store Performance Index
                                      Expanded(child: _PerformanceIndexCard(
                                         todaySales: stats.todaySales,
                                         todayCount: stats.todayOrders,
                                         avgDailySale: stats.avgDailySale,
                                         isDarkMode: isDarkMode,
                                      )),
                                      const SizedBox(width: AppSpacing.md),

                                      // 2. Rushed Hours (Historical Density)
                                      Expanded(child: _RushedHoursCard(
                                         peakHour: stats.peakHour,
                                         leastHour: stats.leastHour,
                                         hasOrders: provider.orders.isNotEmpty,
                                         isDarkMode: isDarkMode,
                                      )),
                                      const SizedBox(width: AppSpacing.md),

                                      // 3. Top Selling Products
                                      Expanded(child: _TopSellingProductsCard(
                                         topProducts: stats.topProducts,
                                         isDarkMode: isDarkMode,
                                      )),
                                      const SizedBox(width: AppSpacing.md),

                                      // 4. Payment Breakdown
                                      Expanded(child: _PaymentBreakdownCard(
                                         paymentStats: stats.paymentStats,
                                         isDarkMode: isDarkMode,
                                      )),
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xl),
                        
                        // RIGHT COLUMN: Quick Actions (Functional)
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                               color: AppColors.surface(context),
                               borderRadius: AppRadius.borderMd,
                               border: Border.all(color: AppColors.border(context)),
                               boxShadow: AppShadows.adaptive(context),
                            ),
                            child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                   Text(AppLocalizations.t(context, 'QUICK ACTIONS'), style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary(context), letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                                   const SizedBox(height: AppSpacing.lg),
                                   Expanded(
                                   child: AnimatedSwitcher(
                                       duration: const Duration(milliseconds: 300),
                                       child: _buildQuickActionContent(provider, isDarkMode),
                                     ),
                                   )
                                ],
                            ),
                          ),
                        )
                      ],
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- ACTIONS LOGIC ---
  
  void _showCalculator(BuildContext context, bool isDarkMode) {
     final provider = legacy.Provider.of<DashboardProvider>(context, listen: false);
     
     final reportingState = ref.read(reportingProvider);
     final stats = reportingState.stats ?? DashboardStats.empty();
     
     final todaysSale = stats.todaySales;
     final todaysOrders = stats.todayOrders;
     
     Navigator.push(
        context,
        MaterialPageRoute(
           builder: (context) => CalculatorWidget(
              isDarkMode: isDarkMode,
              todaysSale: todaysSale,
              totalOrders: todaysOrders,
              cashInHand: todaysSale, // Assuming Cash In Hand = Sales for now
           ),
        )
     );
  }

  void _showCalendar(BuildContext context, bool isDarkMode) {
      Navigator.push(
        context,
        MaterialPageRoute(
           builder: (context) => CalendarWidget(isDarkMode: isDarkMode)
        )
     );
  }

  void _showRefundOptions(DashboardProvider provider) { // test
      if (provider.orders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'No orders available for refund.'))));
        return;
     }
     // Show last 5
     final recentOrders = provider.orders.reversed.take(5).toList();
     
     showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
           title: Text(AppLocalizations.t(context, 'Select Order to Refund')),
           content: SizedBox(
              width: 350,
              height: 300,
              child: ListView.separated(
                 itemCount: recentOrders.length,
                 separatorBuilder: (_,__) => const Divider(),
                 itemBuilder: (context, index) {
                    final order = recentOrders[index];
                    return ListTile(
                       leading: const Icon(Icons.receipt_long),
                       title: Text("₹${order.total}"),
                       subtitle: Text("#${order.id.substring(0,6)} • ${DateFormat('HH:mm').format(order.date)}"),
                       trailing: const Icon(Icons.chevron_right),
                       onTap: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'Refund process initiated.'))));
                       },
                    );
                 },
              ),
           ),
           actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t(context, 'Cancel')))],
        )
     );
  }

  Widget _buildRemindersList(bool isDark) {
      // Safety check for nulls (though initialized to [])
      final todayEmpty = _todayReminders.isEmpty; 
      final upcomingEmpty = _upcomingReminders.isEmpty;
      
      if (todayEmpty && upcomingEmpty) {
         return Center(
            child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                  Icon(Icons.notifications_off, size: 48, color: AppColors.textSecondary(context)),
                  const SizedBox(height: AppSpacing.md),
                  Text(AppLocalizations.t(context, 'No reminders found.'), style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary(context)))
               ],
            ),
         );
      }

      return ListView(
         children: [
            if (_todayReminders.isNotEmpty) ...[
               Text(AppLocalizations.t(context, 'TODAY'), style: TextStyle(color: AppColors.adaptivePrimary(context), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
               const SizedBox(height: AppSpacing.sm),
               ..._todayReminders.map((e) => _buildReminderTile(e, isDark, true)),
               const SizedBox(height: AppSpacing.md),
            ],
            if (_upcomingReminders.isNotEmpty) ...[
               Text(AppLocalizations.t(context, 'UPCOMING'), style: TextStyle(color: AppColors.textSecondary(context), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
               const SizedBox(height: AppSpacing.sm),
               ..._upcomingReminders.map((e) => _buildReminderTile(e, isDark, false)),
            ]
         ],
      );
  }

  Widget _buildReminderTile(Map<String, dynamic> event, bool isDark, bool isToday) {
     final type = event['type']?.toString() ?? 'note';
     final text = event['text']?.toString() ?? '';
     final date = event['date']?.toString();

     return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
           color: AppColors.background(context),
           borderRadius: AppRadius.borderMd,
           border: Border.all(color: isToday ? AppColors.adaptivePrimary(context).withValues(alpha: 0.5) : AppColors.border(context)),
        ),
        child: Row(
           children: [
              Icon(
                  type == 'reminder' ? Icons.alarm : Icons.note, 
                  color: type == 'reminder' ? AppColors.primaryLight : AppColors.warning, 
                  size: 20
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                      Text(text, style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold)),
                      if (date != null)
                        Text(date, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 10)),
                   ],
                ),
              )
           ],
        ),
     );
  }

  Future<void> _toggleRemindersView() async {
     setState(() {
        _actionState = QuickActionState.reminders;
        _todayReminders = [];
        _upcomingReminders = [];
     });

     try {
        final provider = legacy.Provider.of<DashboardProvider>(context, listen: false);
        final userId = provider.userProfile?.uid ?? 'guest';
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getString('calendar_events_v2_$userId');
        if (stored != null) {
           final decoded = json.decode(stored) as Map<String, dynamic>;
           final today = DateTime.now();
           final todayStr = DateFormat('yyyy-MM-dd').format(today);
           
           decoded.forEach((dateKey, events) {
               if (events is! List) return;
               final dateEvents = events.map((e) => Map<String, dynamic>.from(e as Map)).toList();
               
               // Filter for Reminders & Notes
               for (var e in dateEvents) {
                   if (e['type'] == 'reminder' || e['type'] == 'note') {
                       e['date'] = dateKey; // Append date for display
                       
                       if (dateKey == todayStr) {
                          _todayReminders.add(e);
                       } else {
                          // Check if upcoming
                          try {
                             final d = DateFormat('yyyy-MM-dd').parse(dateKey);
                             if (d.isAfter(today)) {
                                _upcomingReminders.add(e);
                             }
                          } catch (_) { /* Error ignored */ }
                       }
                   }
               }
           });
           
           // Sort Upcoming
           _upcomingReminders.sort((a, b) => a['date']!.compareTo(b['date']!));
           // Take only top 5 upcoming to save space
           if (_upcomingReminders.length > 5) {
              _upcomingReminders = _upcomingReminders.sublist(0, 5);
           }
        }
     } catch (e) { /* Error ignored */ }

      if (mounted) setState(() {});

      _reminderTimer?.cancel();
      _reminderTimer = Timer(const Duration(seconds: 10), () {
         if (mounted && _actionState == QuickActionState.reminders) {
             setState(() => _actionState = QuickActionState.menu);
         }
      });
   }

   Widget _buildQuickActionContent(DashboardProvider provider, bool isDarkMode) {
      if (_actionState == QuickActionState.menu) {
          return GridView.count(
             key: const ValueKey('menu'),
             crossAxisCount: 2,
             mainAxisSpacing: 16,
             crossAxisSpacing: 16,
             childAspectRatio: 1.5,
             physics: const BouncingScrollPhysics(),
             children: [
                FeatureGuard(
                   featureKey: 'dashboard.action.calculator',
                   lockedChild: const SizedBox.shrink(),
                   child: _buildActionButton("Calculator", Icons.calculate, () => _showCalculator(context, isDarkMode), isDarkMode)
                ),
                FeatureGuard(
                   featureKey: 'dashboard.action.calendar',
                   lockedChild: const SizedBox.shrink(),
                   child: _buildActionButton("Calendar", Icons.calendar_month, () => _showCalendar(context, isDarkMode), isDarkMode)
                ),
                FeatureGuard(
                   featureKey: 'dashboard.action.reminders',
                   lockedChild: const SizedBox.shrink(),
                   child: _buildActionButton("Reminders", Icons.notifications_active, () => _toggleRemindersView(), isDarkMode)
                ),
                FeatureGuard(
                   featureKey: 'card.recent_orders', // Reuse recent orders for Last Bill
                   lockedChild: const SizedBox.shrink(),
                   child: _buildActionButton("Last Bill", Icons.history, () => setState(() => _actionState = QuickActionState.lastBill), isDarkMode)
                ),
                FeatureGuard(
                   featureKey: 'feature.pos.hold_order',
                   lockedChild: const SizedBox.shrink(),
                   child: _buildActionButton("Hold Orders", Icons.pause_circle_outline, () => setState(() => _actionState = QuickActionState.hold), isDarkMode)
                ),
                FeatureGuard(
                   featureKey: 'feature.pos.refund',
                   lockedChild: const SizedBox.shrink(),
                   child: _buildActionButton("Refund", Icons.replay, () => setState(() => _actionState = QuickActionState.refund), isDarkMode)
                ),
             ],
          );
      }
      
      // Header for generic back
      Widget header(String title) => Row(
         children: [
            IconButton(
               icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
               onPressed: () => setState(() => _actionState = QuickActionState.menu),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(title, style: TextStyle(
               color: AppColors.textPrimary(context), 
               fontWeight: FontWeight.bold, 
               fontSize: 18)
            ),
         ],
      );

      if (_actionState == QuickActionState.reminders) {
          return Column(
             key: const ValueKey('reminders'),
             children: [
                header("Reminders"),
                const SizedBox(height: AppSpacing.sm),
                Expanded(child: _buildRemindersList(isDarkMode)),
             ],
          );
      }
      
      if (_actionState == QuickActionState.lastBill || _actionState == QuickActionState.refund) {
          final isRefund = _actionState == QuickActionState.refund;
          final title = isRefund ? "Select Refund" : "Recent Orders";
          // Provider now returns DESC (Newest First), so we don't need reverse.
          final recentOrders = provider.orders.take(5).toList();
          
          if (recentOrders.isEmpty) {
             return Column(
               children: [
                  header(title),
                  const Spacer(),
                  Text(AppLocalizations.t(context, 'No recent orders.'), style: TextStyle(color: AppColors.textSecondary(context))),
                  const Spacer(),
               ],
             );
          }

          return Column(
             key: ValueKey(title),
             children: [
                header(title),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                   child: ListView.separated(
                      itemCount: recentOrders.length,
                      separatorBuilder: (_,__) => Divider(color: AppColors.border(context)),
                      itemBuilder: (ctx, i) {
                         final order = recentOrders[i];
                         return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                               padding: const EdgeInsets.all(AppSpacing.sm),
                               decoration: BoxDecoration(color: AppColors.background(context), borderRadius: AppRadius.borderSm),
                               child: Icon(Icons.receipt, color: AppColors.adaptivePrimary(context)),
                            ),
                            title: Text("₹${order.total.toStringAsFixed(0)}", style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 18)),
                            subtitle: Text("#${order.id.substring(0,6)} • ${DateFormat('HH:mm').format(order.date)}", style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14)),
                            trailing: isRefund 
                               ? Builder(
                                   builder: (context) {
                                      final isRefunded = order.status == 'Refunded';
                                      return Container(
                                         decoration: BoxDecoration(
                                            boxShadow: isRefunded ? [] : [
                                               BoxShadow(color: AppColors.error.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))
                                            ],
                                            borderRadius: AppRadius.borderSm,
                                            gradient: isRefunded 
                                               ? LinearGradient(colors: [AppColors.textSecondary(context), AppColors.textSecondary(context)])
                                               : const LinearGradient(colors: [AppColors.error, Color(0xFFFF1744)])
                                         ),
                                         child: ElevatedButton(
                                           style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.transparent, 
                                              shadowColor: AppColors.transparent,
                                              minimumSize: const Size(100, 45),
                                              shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderSm)
                                           ),
                                           onPressed: isRefunded ? null : () async { 
                                              if (isRefunded) return;
                                              
                                              // Confirm Refund
                                              final confirm = await showDialog<bool>(
                                                 context: context,
                                                 builder: (ctx) => AlertDialog(
                                                    title: Text(AppLocalizations.t(context, 'Confirm Refund')),
                                                    content: Text("Refund ₹${order.total.toStringAsFixed(0)}? This action cannot be undone."),
                                                    actions: [
                                                       TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.t(context, 'Cancel'))),
                                                       ElevatedButton(
                                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                                          onPressed: () => Navigator.pop(ctx, true), 
                                                          child: Text(AppLocalizations.t(context, 'Refund'))
                                                       )
                                                    ],
                                                 )
                                              );
                                              
                                              if (confirm == true) {
                                                  // ignore: use_build_context_synchronously
                                                  final provider = legacy.Provider.of<DashboardProvider>(context, listen: false); // Ensure fresh access if needed, though provider is passed
                                                  await provider.refundOrder(order.id);
                                              }
                                           }, 
                                           child: Text(isRefunded ? "Refunded" : "Refund", style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.surfaceLight))
                                         ),
                                       );
                                   }
                                 )
                               : IconButton(icon: const Icon(Icons.print, color: AppColors.secondary), onPressed: () {}), // Reprint Logic
                         );
                      },
                   ),
                )
             ],
          );
      }
      
      if (_actionState == QuickActionState.hold) {
          return Column(
             key: const ValueKey('hold'),
             children: [
                header("Held Orders"),
                const Spacer(),
                Icon(Icons.pause_circle_outline, size: 48, color: AppColors.textSecondary(context)),
                const SizedBox(height: AppSpacing.md),
                Text(AppLocalizations.t(context, 'No active held orders.'), style: TextStyle(color: AppColors.textSecondary(context))),
                const Spacer(),
             ],
          );
      }

      return const SizedBox.shrink();
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap, bool isDark) {
     return InkWell(
       onTap: onTap,
       borderRadius: AppRadius.borderSm,
       child: Container(
          decoration: BoxDecoration(
             color: AppColors.background(context),
             borderRadius: AppRadius.borderSm,
             border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
                Icon(icon, size: 36, color: AppColors.adaptivePrimary(context)),
                const SizedBox(height: AppSpacing.sm),
                Text(label, style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary(context))),
             ],
          ),
       ),
     );
  }

  Widget _buildPrinterStatusIndicator(bool isDarkMode) {
      return StreamBuilder<bool>(
        stream: PrinterManagerService().statusStream,
        initialData: PrinterManagerService().isConnected,
        builder: (context, snapshot) {
          final isConnected = snapshot.data ?? false;
          final isAssigned = PrinterManagerService().assignments.isNotEmpty;
          
          final Color statusColor = !isAssigned ? AppColors.warning : (isConnected ? AppColors.success : AppColors.error);
          final String statusText = !isAssigned ? "NO ASSIGNMENT" : (isConnected ? "PRINTER" : "DISCONNECTED");
          final IconData statusIcon = !isAssigned ? Icons.print_disabled : (isConnected ? Icons.print : Icons.print_disabled);
          return Container(
             padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
             decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: AppRadius.borderSm,
                border: Border.all(color: statusColor.withValues(alpha: 0.5)),
             ),
             child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Icon(
                      statusIcon, 
                      color: statusColor, 
                      size: 24
                   ),
                   const SizedBox(width: AppSpacing.sm),
                   Text(
                      statusText, 
                      style: TextStyle(
                         fontWeight: FontWeight.bold, 
                         fontSize: 14, 
                         color: statusColor
                      )
                   ),
                ],
             ),
          );
        },
      );
   }

   void _showPrinterSetupDialog(BuildContext context, DashboardProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
        title: Row(
          children: [
            const Icon(Icons.print, color: AppColors.primaryLightAccent),
            const SizedBox(width: AppSpacing.md),
            Text(AppLocalizations.t(context, 'Printer Setup'), style: const TextStyle(color: AppColors.surfaceLight)),
          ],
        ),
        content: const Text(
          "No printer is assigned to this store. To print receipts or KDS orders, please connect a printer in settings.\n\nWould you like to set it up now?",
          style: TextStyle(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () {
              provider.dismissPrinterSetup();
              Navigator.pop(ctx);
            },
            child: Text(AppLocalizations.t(context, 'Later'), style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () {
              provider.dismissPrinterSetup();
              Navigator.pop(ctx);
              context.push('/printer-management');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLightAccent,
              foregroundColor: AppColors.surfaceLight,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
            ),
            child: Text(AppLocalizations.t(context, 'Connect Now')),
          ),
        ],
      ),
    );
  }
}

// --- FLIPPABLE STAT CARD ---

class _InteractiveKpiCard extends StatefulWidget {
   final String primaryTitle;
   final String primaryValue;
   final String secondaryTitle;
   final String secondaryValue;
   final IconData icon;
   final Color color;
   final bool isDarkMode;

   const _InteractiveKpiCard({
     required this.primaryTitle, 
     required this.primaryValue, 
     required this.secondaryTitle,
     required this.secondaryValue,
     required this.icon, 
     required this.color, 
     required this.isDarkMode
   });

  @override
  State<_InteractiveKpiCard> createState() => _InteractiveKpiCardState();
}

class _InteractiveKpiCardState extends State<_InteractiveKpiCard> {
   bool _showSecondary = false;
   Timer? _timer;

   void _toggle() {
      if (_showSecondary) return;
      setState(() => _showSecondary = true);
      
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 4), () {
         if (mounted) setState(() => _showSecondary = false);
      });
   }

   @override
   void dispose() {
      _timer?.cancel();
      super.dispose();
   }

   @override
   Widget build(BuildContext context) {
      final title = _showSecondary ? widget.secondaryTitle : widget.primaryTitle;
      final value = _showSecondary ? widget.secondaryValue : widget.primaryValue;
      final activeColor = _showSecondary ? widget.color.withValues(alpha: 0.8) : widget.color;

      return GestureDetector(
         onTap: _toggle,
         child: Container(
           padding: const EdgeInsets.all(AppSpacing.xxs),
           decoration: BoxDecoration(
             color: AppColors.surface(context),
             borderRadius: AppRadius.borderSm,
             border: Border.all(
                color: _showSecondary ? activeColor : AppColors.border(context),
                width: _showSecondary ? 1.5 : 1.0
             ),
             boxShadow: AppShadows.adaptive(context),
           ),
           child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 AnimatedContainer(
                   duration: const Duration(milliseconds: 300),
                   padding: const EdgeInsets.all(AppSpacing.md),
                   decoration: BoxDecoration(
                     color: activeColor.withValues(alpha: 0.1),
                     borderRadius: AppRadius.borderSm
                   ),
                   child: Icon(widget.icon, color: activeColor, size: 28),
                 ),
                 const Spacer(),
                 FittedBox(
                   fit: BoxFit.scaleDown, 
                   child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        value, 
                        key: ValueKey(value),
                        style: AppTypography.headlineLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))
                      ),
                   )
                 ),
                 const SizedBox(height: AppSpacing.xs),
                 AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      title, 
                      key: ValueKey(title),
                      style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary(context))
                    ),
                 ),
              ],
           ),
         ),
      );
   }
}

class _AnimatedBillingButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isDarkMode;
  final String userName;
  const _AnimatedBillingButton({required this.onTap, required this.isDarkMode, required this.userName});

  @override
  State<_AnimatedBillingButton> createState() => _AnimatedBillingButtonState();
}

class _AnimatedBillingButtonState extends State<_AnimatedBillingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _showWelcome = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // Speed of the cart
    )..repeat(); // Loop forever
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: () {
          HapticFeedback.mediumImpact();
          setState(() => _showWelcome = true);
          Future.delayed(const Duration(seconds: 4), () {
             if (mounted) setState(() => _showWelcome = false);
          });
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [
                AppColors.adaptivePrimary(context),
                AppColors.primaryLight
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: AppRadius.borderMd,
          boxShadow: AppShadows.adaptive(context),
        ),
        child: ClipRRect(
           borderRadius: AppRadius.borderSm,
           child: LayoutBuilder(
             builder: (context, constraints) {
               return AnimatedBuilder(
                 animation: _controller,
                 builder: (context, child) {
                   const double startPos = -150.0;
                   final double endPos = constraints.maxWidth.isFinite ? constraints.maxWidth : 300.0;
                   final double currentPos = startPos + (endPos - startPos) * _controller.value;

                   return Stack(
                     fit: StackFit.expand, 
                     children: [
                       Positioned(
                          left: currentPos,
                          bottom: -20,
                          child: child!,
                       ),
                       Center(
                         child: AnimatedSwitcher(
                           duration: const Duration(milliseconds: 300),
                           child: _showWelcome 
                             ? Padding(
                                 padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                                 child: Column(
                                   mainAxisAlignment: MainAxisAlignment.center,
                                   children: [
                                      const Icon(Icons.auto_awesome, color: AppColors.warning, size: 40),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text("Welcome ${widget.userName}", 
                                          textAlign: TextAlign.center,
                                          style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.surfaceLight)
                                      ),
                                      Text(AppLocalizations.t(context, 'to Biztonic Automation'), 
                                          textAlign: TextAlign.center,
                                          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.surfaceLight)
                                      ),
                                      Text(AppLocalizations.t(context, 'The Smart Billing Solution'), 
                                          textAlign: TextAlign.center,
                                          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w400, color: AppColors.textSecondaryDark)
                                      ),
                                   ],
                                 ),
                             )
                             : Row(
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: [
                                   const Icon(Icons.play_circle_fill, size: 48, color: AppColors.surfaceLight),
                                   const SizedBox(width: AppSpacing.md),
                                   Text(AppLocalizations.t(context, 'START BILLING'),
                                       style: const TextStyle(
                                           fontSize: 32,
                                           fontWeight: FontWeight.bold,
                                           color: AppColors.surfaceLight,
                                           letterSpacing: 1.5)),
                                 ],
                               ),
                         ),
                       )
                     ],
                   );
                 },
                 child: Transform.scale(
                    scaleX: 1, 
                    child: Icon(Icons.shopping_cart, size: 150, color: AppColors.surfaceLight.withValues(alpha: 0.15)),
                 ),
               );
             }
           ),
        ),
      ),
    );
  }
}
// --- INSIGHT WIDGETS ---

class _PerformanceIndexCard extends StatelessWidget {
  final double todaySales;
  final int todayCount;
  final double avgDailySale;
  final bool isDarkMode;

  const _PerformanceIndexCard({
    required this.todaySales,
    required this.todayCount,
    required this.avgDailySale,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate performance and cap display at 100%
    double rawIndex = (avgDailySale > 0) ? (todaySales / avgDailySale) * 100 : 0;
    double displayIndex = rawIndex.clamp(0.0, 100.0);
    double displayProgress = displayIndex / 100.0;
    
    // Dynamic Colors based on raw performance (allows "Excellent" color even if capped at 100%)
    Color performanceColor = rawIndex >= 90 
      ? AppColors.success
      : (rawIndex >= 60 ? AppColors.warning : AppColors.error);
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.border(context).withValues(alpha: 0.5)),
        boxShadow: [
          if (rawIndex >= 90)
            BoxShadow(
              color: performanceColor.withValues(alpha: 0.2),
              blurRadius: 15,
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.borderSm,
        child: Stack(
          children: [
            // Background Gauge "Track"
            Positioned(
              bottom: -40, right: -20,
              child: Opacity(
                opacity: isDarkMode ? 0.05 : 0.08,
                child: Icon(Icons.speed, size: 120, color: performanceColor),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(AppLocalizations.t(context, 'PERFORMANCE'), 
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelLarge.copyWith(
                            fontSize: 10, 
                            fontWeight: FontWeight.w900, 
                            letterSpacing: 1.2,
                            color: AppColors.textSecondary(context)
                          )
                        ),
                      ),
                      Icon(Icons.trending_up, color: performanceColor, size: 16),
                    ],
                  ),
                  const Spacer(),
                  Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final gaugeSize = (constraints.maxWidth * 0.45).clamp(50.0, 80.0);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              height: gaugeSize, width: gaugeSize,
                              child: CircularProgressIndicator(
                                value: displayProgress,
                                strokeWidth: 6,
                                strokeCap: StrokeCap.round,
                                backgroundColor: isDarkMode ? AppColors.surfaceLight.withValues(alpha: 0.05) : AppColors.textPrimaryLight.withValues(alpha: 0.05),
                                valueColor: AlwaysStoppedAnimation<Color>(performanceColor),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("${displayIndex.toStringAsFixed(0)}%", 
                                  style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary(context))
                                ),
                                Text(AppLocalizations.t(context, 'GOAL'), 
                                  style: AppTypography.labelSmall.copyWith(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.textSecondary(context).withValues(alpha: 0.7))
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: performanceColor.withValues(alpha: 0.1),
                      borderRadius: AppRadius.borderSm,
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        rawIndex >= 100 ? "EXCEEDING TARGET" : (rawIndex >= 85 ? "OPTIMAL" : "BELOW TARGET"),
                        style: AppTypography.labelSmall.copyWith(fontSize: 10, fontWeight: FontWeight.w900, color: performanceColor, letterSpacing: 0.5)
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RushedHoursCard extends StatefulWidget {
  final int? peakHour;
  final int? leastHour;
  final bool hasOrders;
  final bool isDarkMode;

  const _RushedHoursCard({
    required this.peakHour, 
    required this.leastHour, 
    required this.hasOrders,
    required this.isDarkMode
  });

  @override
  State<_RushedHoursCard> createState() => _RushedHoursCardState();
}

class _RushedHoursCardState extends State<_RushedHoursCard> {
  bool _showFreeHours = false;

  @override
  Widget build(BuildContext context) {
    int peakHour = widget.peakHour ?? 0;
    int leastHour = widget.leastHour ?? 0;

    String formatHour(int hour) {
      final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return "$h ${hour >= 12 ? 'PM' : 'AM'}";
    }

    return GestureDetector(
      onTap: () => setState(() => _showFreeHours = !_showFreeHours),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final rotate = Tween(begin: 3.1415, end: 0.0).animate(animation);
          return AnimatedBuilder(
            animation: rotate,
            builder: (ctx, _) {
              final isUnder = (ValueKey(_showFreeHours) != child.key);
              final value = isUnder ? math.min(rotate.value, 3.1415/2) : rotate.value;
              return Transform(
                transform: Matrix4.rotationY(value)..setEntry(3, 2, 0.001),
                alignment: Alignment.center,
                child: child,
              );
            },
          );
        },
        child: Container(
          key: ValueKey(_showFreeHours),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: AppRadius.borderMd,
            border: Border.all(color: AppColors.border(context)),
            boxShadow: AppShadows.adaptive(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(_showFreeHours ? "OPPORTUNITY TIME" : "PEAK TRAFFIC", 
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge.copyWith(
                        fontSize: 10, 
                        fontWeight: FontWeight.w900, 
                        letterSpacing: 1.0,
                        color: _showFreeHours ? AppColors.primaryLightAccent : AppColors.warning
                      )
                    ),
                  ),
                  Icon(_showFreeHours ? Icons.eco : Icons.speed, color: _showFreeHours ? AppColors.primaryLightAccent : AppColors.warning, size: 16),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_showFreeHours ? "QUIETEST HOUR" : "RUSHED HOUR", 
                    style: AppTypography.labelSmall.copyWith(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary(context).withValues(alpha: 0.6))
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.hasOrders ? formatHour(_showFreeHours ? leastHour : peakHour) : "--", 
                      style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w900, color: AppColors.textPrimary(context), letterSpacing: -1)
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.touch_app, size: 10, color: AppColors.textSecondary(context).withValues(alpha: 0.4)),
                  const SizedBox(width: AppSpacing.xs),
                  Text(AppLocalizations.t(context, 'TAP TO FLIP'), style: AppTypography.labelSmall.copyWith(fontSize: 8, color: AppColors.textSecondary(context).withValues(alpha: 0.4), fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopSellingProductsCard extends StatelessWidget {
  final List<Map<String, dynamic>> topProducts;
  final bool isDarkMode;

  const _TopSellingProductsCard({required this.topProducts, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    // Take 4 to fit well
    var topDisplay = topProducts.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: AppColors.border(context)),
        boxShadow: AppShadows.adaptive(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(AppLocalizations.t(context, 'TOP SELLING'), 
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary(context), fontWeight: FontWeight.bold, fontSize: 10)),
              ),
              const Icon(Icons.auto_awesome, color: AppColors.warning, size: 16),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (topDisplay.isEmpty)
            Expanded(child: Center(child: Text(AppLocalizations.t(context, 'Waiting for sales...'), style: TextStyle(fontSize: 14, color: AppColors.textSecondary(context)))))
          else
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topDisplay.length,
                itemBuilder: (context, index) {
                  final item = topDisplay[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.borderXs, 
                            color: AppColors.adaptivePrimary(context).withValues(alpha: 0.1),
                          ),
                          alignment: Alignment.center,
                          child: Text("${index + 1}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.adaptivePrimary(context))),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(item['name'] ?? "", 
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                        ),
                        Text("${item['quantity'] ?? 0}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.adaptivePrimary(context))),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentBreakdownCard extends StatelessWidget {
  final Map<String, double> paymentStats;
  final bool isDarkMode;

  const _PaymentBreakdownCard({required this.paymentStats, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    // Sort by volume
    final sortedStats = paymentStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Calculate total for percentages
    final total = paymentStats.values.fold(0.0, (sum, val) => sum + val);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: AppColors.border(context).withValues(alpha: 0.5)),
        boxShadow: AppShadows.adaptive(context),
        gradient: isDarkMode ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface(context),
            AppColors.surface(context).withValues(alpha: 0.8),
          ],
        ) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.t(context, 'PAYMENT DISTRIBUTION'), 
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.textSecondary(context), 
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.2
                      )
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(AppLocalizations.t(context, 'Revenue Share'), style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    )),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.adaptivePrimary(context).withValues(alpha: 0.1),
                  borderRadius: AppRadius.borderXs,
                ),
                child: Icon(Icons.account_balance_wallet_rounded, 
                  color: AppColors.adaptivePrimary(context), size: 16),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          if (paymentStats.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.adaptivePrimary(context)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(AppLocalizations.t(context, 'Calculating stats...'), style: TextStyle(
                      fontSize: 12, 
                      color: AppColors.textSecondary(context),
                      fontStyle: FontStyle.italic,
                    )),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: math.min(sortedStats.length, 3),
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final entry = sortedStats[index];
                  final percentage = total > 0 ? (entry.value / total) : 0.0;
                  
                  // Premium Color selection
                  final Color primaryColor = entry.key.toUpperCase().contains('CASH') 
                    ? AppColors.success // Vibrant Green
                    : (entry.key.toUpperCase().contains('UPI') 
                        ? AppColors.info // Vibrant Blue
                        : AppColors.warning); // Vibrant Orange

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: AppRadius.borderXs,
                                  boxShadow: [
                                    BoxShadow(color: primaryColor.withValues(alpha: 0.5), blurRadius: 4),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(entry.key, style: TextStyle(
                                fontSize: 13, 
                                fontWeight: FontWeight.bold, 
                                color: AppColors.textPrimary(context)
                              )),
                            ],
                          ),
                          Text("₹${entry.value.toStringAsFixed(0)}", style: TextStyle(
                            fontSize: 13, 
                            fontWeight: FontWeight.w900, 
                            color: AppColors.textPrimary(context)
                          )),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Stack(
                        children: [
                          Container(
                            height: 4,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDarkMode ? AppColors.surfaceLight.withValues(alpha: 0.05) : AppColors.textPrimaryLight.withValues(alpha: 0.05),
                              borderRadius: AppRadius.borderSm,
                            ),
                          ),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: percentage),
                            duration: const Duration(seconds: 1),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => FractionallySizedBox(
                              widthFactor: value,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      primaryColor,
                                      primaryColor.withValues(alpha: 0.6),
                                    ],
                                  ),
                                  borderRadius: AppRadius.borderSm,
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}








