import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:biztonic_pos/sync/inbound/pull_engine.dart';
import 'package:biztonic_pos/sync/outbound/outbound_manager.dart';
import 'package:biztonic_pos/sync/limits/limits_engine.dart';

/// The central brain of the sync system.
///
/// Responsible for orchestrating the high-level flow between
/// outbound pushing (OutboundManager) and inbound pulling (PullEngine),
/// while respecting plan policies and connectivity states.
class SyncOrchestrator {
  final PullEngine _pullEngine;
  final OutboundManager _outboundManager;
  
  final LimitsEngine _limitsEngine;

  // Callbacks to SyncService for UI/State updates
  final Function(String status) setStatus;
  final Function(String? error) setLastError;
  final Function(String? warning) setLastWarning;
  final Function(DateTime time) setLastSyncTime;
  final Future<void> Function({bool notify}) refreshCounts;
  final Future<bool> Function() checkConnectivity;
  final VoidCallback notifyListeners;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  SyncOrchestrator({
    required PullEngine pullEngine,
    required OutboundManager outboundManager,
    
    required LimitsEngine limitsEngine,
    required this.setStatus,
    required this.setLastError,
    required this.setLastWarning,
    required this.setLastSyncTime,
    required this.refreshCounts,
    required this.checkConnectivity,
    required this.notifyListeners,
  })  : _pullEngine = pullEngine,
        _outboundManager = outboundManager,
        
        _limitsEngine = limitsEngine;

  /// Executes a full synchronization cycle.
  ///
  /// Flow:
  /// 1. Validate connectivity.
  /// 2. Check plan-based pull throttling.
  /// 3. Push outbound queue (High Priority).
  /// 4. Pull inbound changes (Delta or Full).
  /// 5. Refresh local stats and update status.
  Future<void> processSync({bool forceManual = false, bool forceFull = false}) async {
    if (_isBusy) return;
    _isBusy = true;
    notifyListeners();

    try {
      setStatus("Syncing...");
      setLastError(null);
      setLastWarning(null);

      // 1. Connectivity Check (Real Internet)
      final hasInternet = await checkConnectivity();
      if (!hasInternet) {
        setStatus("Offline");
        return;
      }

      // 2. Throttling Check
      final canPull = forceManual || _limitsEngine.canPullSync();
      if (!canPull) {
        setLastWarning(_limitsEngine.syncThrottleReason);
        debugPrint('⏳ [Orchestrator] Pull sync throttled: ${_limitsEngine.syncThrottleReason}');
      }

      // 3. Outbound (Push local changes first)
      debugPrint('⬆️ [Orchestrator] Starting outbound push...');
      await _outboundManager.processQueue();

      // 4. Inbound (Pull cloud changes)
      if (canPull) {
        debugPrint('⬇️ [Orchestrator] Starting inbound pull (forceFull: $forceFull)...');
        await _pullEngine.pullAll(forceFull: forceFull);
      }

      // 5. Success Finalization
      setLastSyncTime(DateTime.now());
      setStatus("Synced");
      await refreshCounts(notify: true);
      
    } catch (e) {
      debugPrint('❌ [Orchestrator] Sync failed: $e');
      setStatus("Error");
      setLastError(e.toString());
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
