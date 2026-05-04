import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/repository.dart';
import '../../services/sync_service.dart';
import '../../services/database_helper.dart';
import '../../features/store/data/store_repository.dart';
import '../../features/settings/data/settings_repository.dart';
import '../../features/subscriptions/data/subscription_repository.dart';
import '../../providers/order_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';

/// Provider for the base DatabaseHelper
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

/// Provider for the SyncService singleton
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService();
});

/// Provider for the Repository façade
final repositoryProvider = Provider<Repository>((ref) {
  return Repository();
});

/// Specialized Repository Providers
final orderRepositoryProvider = Provider((ref) => ref.watch(repositoryProvider).orders);
final inventoryRepositoryProvider = Provider((ref) => ref.watch(repositoryProvider).inventory);
final customerRepositoryProvider = Provider((ref) => ref.watch(repositoryProvider).customers);
final storeRepositoryProvider = Provider((ref) => ref.watch(repositoryProvider).store);
final reportingRepositoryProvider = Provider((ref) => ref.watch(repositoryProvider).reporting);
final syncRepositoryProvider = Provider((ref) => ref.watch(repositoryProvider).sync);

// New Feature Repositories
final storeFeatureRepositoryProvider = Provider<StoreRepository>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return StoreRepository(syncService);
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

// --- Legacy Provider Wrappers (Bridge) ---
// These allow Riverpod providers to watch legacy ChangeNotifier providers

final authProvider = ChangeNotifierProvider<AuthProvider>((ref) {
  return AuthProvider();
});

final inventoryProvider = ChangeNotifierProvider<InventoryProvider>((ref) {
  return InventoryProvider();
});

final orderProvider = ChangeNotifierProvider<OrderProvider>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return OrderProvider(syncService);
});

final customerProvider = ChangeNotifierProvider<CustomerProvider>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return CustomerProvider(syncService);
});

final storeProvider = ChangeNotifierProvider<StoreProvider>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return StoreProvider(syncService);
});

final dashboardProvider = ChangeNotifierProvider<DashboardProvider>((ref) {
  final auth = ref.watch(authProvider);
  final inventory = ref.watch(inventoryProvider);
  final orders = ref.watch(orderProvider);
  final customers = ref.watch(customerProvider);
  final stores = ref.watch(storeProvider);
  
  final dashboard = DashboardProvider();
  dashboard.updateAuthStatus(auth.isOfflineLoggedIn);
  dashboard.init();
  dashboard.injectInventory(inventory);
  dashboard.injectOrderProvider(orders);
  dashboard.injectCustomerProvider(customers);
  dashboard.injectStoreProvider(stores);
  
  return dashboard;
});
