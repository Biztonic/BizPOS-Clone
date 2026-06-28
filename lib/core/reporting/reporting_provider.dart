import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/reporting/domain/entities/dashboard_stats.dart';
import '../../features/reporting/domain/entities/report_period.dart';
import '../../features/reporting/domain/use_cases/get_dashboard_stats.dart';
import '../dependency_injection/providers.dart';

part 'reporting_provider.g.dart';

class ReportingState {
  final DashboardStats? stats;
  final ReportPeriod selectedPeriod;
  final bool isComputing;
  final List<String> smartInsights;

  ReportingState({
    this.stats,
    this.selectedPeriod = ReportPeriod.today,
    this.isComputing = false,
    this.smartInsights = const [],
  });

  ReportingState copyWith({
    DashboardStats? stats,
    ReportPeriod? selectedPeriod,
    bool? isComputing,
    List<String>? smartInsights,
  }) {
    return ReportingState(
      stats: stats ?? this.stats,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      isComputing: isComputing ?? this.isComputing,
      smartInsights: smartInsights ?? this.smartInsights,
    );
  }
}

@riverpod
class Reporting extends _$Reporting {
  @override
  ReportingState build() {
    // We use ref.listen to react to changes without resetting the entire state
    // which would happen if we used ref.watch(provider).
    ref.listen(orderProvider, (previous, next) {
      // Re-compute if orders changed
      _scheduleComputation();
    });

    ref.listen(dashboardProvider, (previous, next) {
      // Re-compute if active store changed
      if (previous?.activeStoreId != next.activeStoreId) {
        _scheduleComputation();
      }
    });

    // Initial computation
    Future.microtask(() => computeStats());

    return ReportingState(selectedPeriod: ReportPeriod.last7Days);
  }

  Timer? _debounceTimer;

  void _scheduleComputation() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      computeStats();
    });
  }

  void setPeriod(ReportPeriod period) {
    state = state.copyWith(selectedPeriod: period);
    computeStats();
  }

  Future<void> computeStats() async {
    if (state.isComputing) return;

    state = state.copyWith(isComputing: true);

    try {
      final repository = ref.read(repositoryProvider);
      final orders = ref.read(orderProvider).orders;
      final dashboard = ref.read(dashboardProvider);
      
      final useCase = GetDashboardStatsUseCase(repository);
      final params = GetDashboardStatsParams(
        orders: orders,
        activeStoreId: dashboard.activeStoreId,
        period: state.selectedPeriod,
        isNative: !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS),
      );

      final newStats = await useCase.execute(params);
      
      // Generate some smart insights based on stats
      final insights = _generateInsights(newStats);
      
      state = state.copyWith(
        stats: newStats, 
        isComputing: false,
        smartInsights: insights,
      );
    } catch (e) {
      debugPrint("❌ ReportingProvider: Error computing stats: $e");
      state = state.copyWith(isComputing: false);
    }
  }

  List<String> _generateInsights(DashboardStats stats) {
    final List<String> insights = [];
    if (stats.totalSales > 0) {
      insights.add("Your average order value is ${stats.avgOrderValue.toStringAsFixed(2)}.");
      if (stats.peakHour >= 0) {
        insights.add("Peak sales hour detected at ${stats.peakHour}:00.");
      }
    } else {
      insights.add("No sales data available for the selected period.");
    }
    return insights;
  }
}
