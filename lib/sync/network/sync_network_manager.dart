import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// 4-tier network connectivity states for the POS.
enum SyncNetworkState {
  offline,
  localNetwork,
  internetAvailable,
  firebaseAvailable;

  String toDisplayString() {
    switch (this) {
      case SyncNetworkState.offline:
        return 'Offline';
      case SyncNetworkState.localNetwork:
        return 'Local Network (No Internet)';
      case SyncNetworkState.internetAvailable:
        return 'Internet Ready (Firebase Pending)';
      case SyncNetworkState.firebaseAvailable:
        return 'Connected (Firebase Available)';
    }
  }
}

/// Advanced network manager distinguishing Wi-Fi, Internet, and Firebase reachability.
class SyncNetworkManager {
  static bool isTesting = false;

  SyncNetworkState _currentState = SyncNetworkState.offline;
  SyncNetworkState get currentState => _currentState;

  final StreamController<SyncNetworkState> _stateController =
      StreamController<SyncNetworkState>.broadcast();
  Stream<SyncNetworkState> get onStateChanged => _stateController.stream;

  StreamSubscription? _connectivitySub;
  Timer? _heartbeatTimer;

  // Custom probe functions for dependency injection / test mocks
  Future<bool> Function()? internetProbeOverride;
  Future<bool> Function()? firebaseProbeOverride;

  bool get canSync => _currentState == SyncNetworkState.firebaseAvailable;

  SyncNetworkManager({
    this.internetProbeOverride,
    this.firebaseProbeOverride,
  });

  /// Initializes connectivity listeners and initial probe.
  Future<void> init() async {
    // Initial check
    await checkState();

    // Listen to OS connectivity changes
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;
      if (result == ConnectivityResult.none) {
        _updateState(SyncNetworkState.offline);
      } else {
        // Non-blocking background verification
        unawaited(checkState());
      }
    });

    // Heartbeat: periodic probe every 30 seconds
    if (!isTesting) {
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_currentState != SyncNetworkState.offline) {
          unawaited(checkState());
        }
      });
    }
  }

  /// Multi-tier network probe.
  Future<SyncNetworkState> checkState() async {
    if (isTesting &&
        internetProbeOverride != null &&
        firebaseProbeOverride != null) {
      final internet = await internetProbeOverride!();
      if (!internet) {
        _updateState(SyncNetworkState.localNetwork);
        return _currentState;
      }
      final fb = await firebaseProbeOverride!();
      _updateState(fb
          ? SyncNetworkState.firebaseAvailable
          : SyncNetworkState.internetAvailable);
      return _currentState;
    }

    try {
      // 1. Physical Interface Check
      final results = await Connectivity().checkConnectivity();
      final result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;
      if (result == ConnectivityResult.none) {
        _updateState(SyncNetworkState.offline);
        return SyncNetworkState.offline;
      }

      // 2. Internet Reachability Probe
      final hasInternet = await _probeInternet();
      if (!hasInternet) {
        _updateState(SyncNetworkState.localNetwork);
        return SyncNetworkState.localNetwork;
      }

      // 3. Firebase Reachability Probe
      final hasFirebase = await _probeFirebase();
      if (!hasFirebase) {
        _updateState(SyncNetworkState.internetAvailable);
        return SyncNetworkState.internetAvailable;
      }

      _updateState(SyncNetworkState.firebaseAvailable);
      return SyncNetworkState.firebaseAvailable;
    } catch (_) {
      _updateState(SyncNetworkState.offline);
      return SyncNetworkState.offline;
    }
  }

  Future<bool> _probeInternet() async {
    if (internetProbeOverride != null) {
      return internetProbeOverride!();
    }
    if (kIsWeb) return true;

    try {
      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _probeFirebase() async {
    if (firebaseProbeOverride != null) {
      return firebaseProbeOverride!();
    }
    if (isTesting) return true;

    try {
      if (kIsWeb) return true;

      // Fast DNS check for firestore endpoint
      final lookup = await InternetAddress.lookup('firestore.googleapis.com')
          .timeout(const Duration(seconds: 4));
      return lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _updateState(SyncNetworkState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(newState);
      debugPrint(
          '📶 [SyncNetworkManager] State changed to: ${newState.toDisplayString()}');
    }
  }

  @visibleForTesting
  void setStateForTesting(SyncNetworkState state) {
    _updateState(state);
  }

  void dispose() {
    _connectivitySub?.cancel();
    _heartbeatTimer?.cancel();
    _stateController.close();
  }
}
