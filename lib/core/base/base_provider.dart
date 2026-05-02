import 'dart:async';
import 'package:flutter/foundation.dart';
import '../events/event_bus.dart';

/// Base class for all providers in the application.
///
/// Provides:
/// - Automatic EventBus subscription management
/// - Safe notifyListeners (won't throw after dispose)
/// - Loading state management
/// - Error state management
abstract class BaseProvider extends ChangeNotifier {
  final List<StreamSubscription> _subscriptions = [];
  bool _isDisposed = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  /// Subscribe to an EventBus event. Subscription is auto-cancelled on dispose.
  void listenTo<T>(void Function(T event) handler) {
    final sub = EventBus.instance.on<T>(handler);
    _subscriptions.add(sub);
  }

  /// Fire an event on the EventBus.
  void fireEvent<T>(T event) {
    EventBus.instance.fire(event);
  }

  /// Set loading state and notify.
  @protected
  void setLoading(bool loading) {
    _isLoading = loading;
    safeNotify();
  }

  /// Set error state and notify.
  @protected
  void setError(String? message) {
    _errorMessage = message;
    safeNotify();
  }

  /// Clear error state.
  @protected
  void clearError() {
    _errorMessage = null;
  }

  /// Safe version of notifyListeners — won't throw after dispose.
  @protected
  void safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
