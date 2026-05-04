import '../domain/entities/store.dart';
import '../domain/entities/counter_model.dart';

class StoreState {
  final List<Store> stores;
  final Store? activeStore;
  final String? activeStoreId;
  final List<CounterModel> counters;
  final bool isLoading;
  final String? error;

  StoreState({
    this.stores = const [],
    this.activeStore,
    this.activeStoreId,
    this.counters = const [],
    this.isLoading = false,
    this.error,
  });

  StoreState copyWith({
    List<Store>? stores,
    Store? activeStore,
    String? activeStoreId,
    List<CounterModel>? counters,
    bool? isLoading,
    String? error,
    bool clearActiveStore = false,
    bool clearError = false,
  }) {
    return StoreState(
      stores: stores ?? this.stores,
      activeStore: clearActiveStore ? null : (activeStore ?? this.activeStore),
      activeStoreId: clearActiveStore ? null : (activeStoreId ?? this.activeStoreId),
      counters: counters ?? this.counters,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
