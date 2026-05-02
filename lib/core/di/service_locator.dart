import 'dart:collection';

/// A lightweight service locator for dependency injection.
///
/// Supports lazy singletons, factories, and explicit registration.
/// No external packages required — uses pure Dart.
///
/// Usage:
/// ```dart
/// // Register
/// ServiceLocator.instance.registerLazySingleton<OrderRepository>(() => OrderRepository());
///
/// // Resolve
/// final repo = ServiceLocator.instance.get<OrderRepository>();
/// ```
class ServiceLocator {
  ServiceLocator._();
  static final ServiceLocator instance = ServiceLocator._();

  final _singletons = HashMap<Type, dynamic>();
  final _factories = HashMap<Type, dynamic Function()>();
  final _lazySingletonFactories = HashMap<Type, dynamic Function()>();

  /// Register a pre-created singleton instance.
  void registerSingleton<T>(T instance) {
    _singletons[T] = instance;
  }

  /// Register a factory that creates a new instance each time.
  void registerFactory<T>(T Function() factory) {
    _factories[T] = factory;
  }

  /// Register a lazy singleton — created on first access, then cached.
  void registerLazySingleton<T>(T Function() factory) {
    _lazySingletonFactories[T] = factory;
  }

  /// Resolve a registered dependency.
  /// Priority: Singleton → Lazy Singleton → Factory
  T get<T>() {
    // 1. Check singletons
    if (_singletons.containsKey(T)) {
      return _singletons[T] as T;
    }

    // 2. Check lazy singletons (create + cache on first access)
    if (_lazySingletonFactories.containsKey(T)) {
      final instance = _lazySingletonFactories[T]!() as T;
      _singletons[T] = instance;
      _lazySingletonFactories.remove(T);
      return instance;
    }

    // 3. Check factories (new instance each time)
    if (_factories.containsKey(T)) {
      return _factories[T]!() as T;
    }

    throw StateError(
      'ServiceLocator: No registration found for type $T. '
      'Did you forget to call registerSingleton<$T>() or registerFactory<$T>()?',
    );
  }

  /// Check if a type is registered.
  bool isRegistered<T>() {
    return _singletons.containsKey(T) ||
        _lazySingletonFactories.containsKey(T) ||
        _factories.containsKey(T);
  }

  /// Unregister a type (useful for testing).
  void unregister<T>() {
    _singletons.remove(T);
    _factories.remove(T);
    _lazySingletonFactories.remove(T);
  }

  /// Reset all registrations (useful for testing).
  void reset() {
    _singletons.clear();
    _factories.clear();
    _lazySingletonFactories.clear();
  }
}

/// Convenience shorthand
ServiceLocator get locator => ServiceLocator.instance;
