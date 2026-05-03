import 'dart:async';

/// A lightweight, type-safe event bus for inter-module communication.
///
/// Usage:
/// ```dart
/// // Subscribe (with lifecycle tracking)
/// final sub = EventBus.instance.on<OrderCreatedEvent>((event) {
///   print('Order created: ${event.order.id}');
/// });
///
/// // Fire
/// EventBus.instance.fire(OrderCreatedEvent(order));
///
/// // Cleanup (single subscription)
/// sub.cancel();
///
/// // Cleanup (all subscriptions for a scope)
/// final scope = EventBusScope();
/// scope.track(EventBus.instance.on<OrderCreatedEvent>(handler));
/// scope.track(EventBus.instance.on<InventoryAdjustedEvent>(handler2));
/// scope.disposeAll(); // Cancels both
/// ```
class EventBus {
  EventBus._();
  static final EventBus instance = EventBus._();

  final _controller = StreamController<dynamic>.broadcast();

  /// All tracked subscriptions across all scopes (for leak detection).
  final Set<StreamSubscription> _allSubscriptions = {};

  /// Listen for events of a specific type [T].
  /// Returns a [StreamSubscription] that should be cancelled in `dispose()`.
  StreamSubscription<T> on<T>(void Function(T event) handler) {
    final sub = _controller.stream
        .where((event) => event is T)
        .cast<T>()
        .listen(handler);
    _allSubscriptions.add(sub);
    return sub;
  }

  /// Fire an event to all listeners of its type.
  void fire<T>(T event) {
    _controller.add(event);
  }

  /// Cancel ALL active subscriptions. Use during hot reload or app shutdown.
  Future<void> cancelAll() async {
    for (final sub in _allSubscriptions) {
      await sub.cancel();
    }
    _allSubscriptions.clear();
  }

  /// Remove a subscription from tracking (called automatically on cancel).
  void untrack(StreamSubscription sub) {
    _allSubscriptions.remove(sub);
  }

  /// Returns the count of active subscriptions (for diagnostics).
  int get activeSubscriptionCount => _allSubscriptions.length;

  /// Dispose the event bus. Call only on app shutdown.
  void dispose() {
    cancelAll();
    _controller.close();
  }
}

/// Manages a group of [StreamSubscription]s with a shared lifecycle.
///
/// Use this in widgets, providers, or services to track all EventBus
/// subscriptions and cancel them together during dispose.
///
/// ```dart
/// class MyProvider extends ChangeNotifier {
///   final _eventScope = EventBusScope();
///
///   void init() {
///     _eventScope.track(EventBus.instance.on<OrderCreatedEvent>(_onOrder));
///     _eventScope.track(EventBus.instance.on<SyncCompletedEvent>(_onSync));
///   }
///
///   @override
///   void dispose() {
///     _eventScope.disposeAll();
///     super.dispose();
///   }
/// }
/// ```
class EventBusScope {
  final List<StreamSubscription> _subscriptions = [];

  /// Track a subscription for batch disposal.
  StreamSubscription<T> track<T>(StreamSubscription<T> subscription) {
    _subscriptions.add(subscription);
    return subscription;
  }

  /// Cancel all tracked subscriptions and clear the list.
  Future<void> disposeAll() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
      EventBus.instance.untrack(sub);
    }
    _subscriptions.clear();
  }

  /// Returns the number of active subscriptions in this scope.
  int get count => _subscriptions.length;
}
