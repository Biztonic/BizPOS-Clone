import 'dart:async';

/// A lightweight, type-safe event bus for inter-module communication.
///
/// Usage:
/// ```dart
/// // Subscribe
/// final sub = EventBus.instance.on<OrderCreatedEvent>((event) {
///   print('Order created: ${event.order.id}');
/// });
///
/// // Fire
/// EventBus.instance.fire(OrderCreatedEvent(order));
///
/// // Cleanup
/// sub.cancel();
/// ```
class EventBus {
  EventBus._();
  static final EventBus instance = EventBus._();

  final _controller = StreamController<dynamic>.broadcast();

  /// Listen for events of a specific type [T].
  /// Returns a [StreamSubscription] that should be cancelled in `dispose()`.
  StreamSubscription<T> on<T>(void Function(T event) handler) {
    return _controller.stream
        .where((event) => event is T)
        .cast<T>()
        .listen(handler);
  }

  /// Fire an event to all listeners of its type.
  void fire<T>(T event) {
    _controller.add(event);
  }

  /// Dispose the event bus. Call only on app shutdown.
  void dispose() {
    _controller.close();
  }
}
