import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/repository.dart';
import '../../services/sync_service.dart';
import '../../services/database_helper.dart';
import '../../features/store/data/store_repository.dart';
import '../../features/settings/data/settings_repository.dart';
import '../../features/subscriptions/data/subscription_repository.dart';
import '../../providers/order_provider.dart';
import '../../features/inventory/presentation/providers/inventory_provider.dart';
import '../../features/inventory/domain/repositories/inventory_repository_interface.dart';
import '../../features/inventory/data/repositories/inventory_repository_impl.dart';
import '../../features/inventory/application/inventory_orchestrator.dart';
import '../../providers/customer_provider.dart';
import '../../providers/store_provider.dart';
import '../theme/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../routing/router_notifier.dart';
import '../../features/billing/presentation/providers/billing_provider.dart';

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

// Inventory Feature Providers
final inventoryRepositoryInterfaceProvider = Provider<InventoryRepositoryInterface>((ref) {
  final legacyRepo = ref.watch(inventoryRepositoryProvider);
  return InventoryRepositoryImpl(legacyRepo: legacyRepo);
});

final inventoryOrchestratorProvider = Provider<InventoryOrchestrator>((ref) {
  final repository = ref.watch(inventoryRepositoryInterfaceProvider);
  return InventoryOrchestrator(repository: repository);
});

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
  final repository = ref.watch(inventoryRepositoryInterfaceProvider);
  final orchestrator = ref.watch(inventoryOrchestratorProvider);
  final syncService = ref.watch(syncServiceProvider);
  // Use ref.read for storeProvider because InventoryProvider already listens
  // to StoreProvider internally. Using ref.watch here would cause Riverpod to
  // dispose and recreate InventoryProvider every time the store changes,
  // leading to "used after disposal" errors in the legacy Provider bridge.
  final stores = ref.read(storeProvider);

  return InventoryProvider(
    repository: repository,
    orchestrator: orchestrator,
    storeProvider: stores,
    syncService: syncService,
  );
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

final routerNotifierProvider = ChangeNotifierProvider<RouterNotifier>((ref) {
  return RouterNotifier();
});

final billingProvider = ChangeNotifierProvider<BillingProvider>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return BillingProvider(syncService);
});

final dashboardProvider = ChangeNotifierProvider<DashboardProvider>((ref) {
  // Use ref.read instead of ref.watch for dependencies that should not trigger
  // a full recreation of the DashboardProvider. DashboardProvider handles
  // its own internal listening to these providers via inject methods.
  final auth = ref.read(authProvider);
  final inventory = ref.read(inventoryProvider);
  final orders = ref.read(orderProvider);
  final customers = ref.read(customerProvider);
  final stores = ref.read(storeProvider);
  final routerNotifier = ref.read(routerNotifierProvider);
  
  final themeNotifier = ref.watch(themeProvider.notifier);
  
  final dashboard = DashboardProvider();
  dashboard.injectAuthProvider(auth);
  dashboard.injectInventory(inventory);
  dashboard.injectOrderProvider(orders);
  dashboard.injectCustomerProvider(customers);
  dashboard.injectStoreProvider(stores);
  dashboard.injectRouterNotifier(routerNotifier);
  dashboard.injectThemeNotifier(themeNotifier);
  
  // Call init after all dependencies are injected
  dashboard.init();
  
  return dashboard;
});
