/// Abstract use case pattern for domain-layer business logic.
///
/// Each use case represents a single business operation, isolated from
/// UI and infrastructure concerns.
///
/// Usage:
/// ```dart
/// class CreateOrder extends UseCase<CreateOrderParams, OrderModel> {
///   @override
///   Future<OrderModel> execute(CreateOrderParams params) async {
///     // Business logic here
///   }
/// }
/// ```
abstract class UseCase<Input, Output> {
  /// Execute the use case with the given input.
  Future<Output> execute(Input input);
}

/// Use case that takes no input parameters.
abstract class UseCaseNoInput<Output> {
  Future<Output> execute();
}

/// Synchronous use case for non-async operations.
abstract class SyncUseCase<Input, Output> {
  Output execute(Input input);
}

/// Use case result wrapper for operations that can fail gracefully.
class UseCaseResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  UseCaseResult.success(this.data)
      : error = null,
        isSuccess = true;

  UseCaseResult.failure(this.error)
      : data = null,
        isSuccess = false;
}
