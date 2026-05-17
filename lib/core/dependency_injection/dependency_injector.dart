import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dependency_injection/providers.dart';

import '../../providers/dashboard_provider.dart';
import '../../features/inventory/presentation/providers/inventory_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/table_provider.dart';
import '../../providers/smart_insights_provider.dart';
import '../../providers/locale_provider.dart';

class DependencyInjector extends ConsumerStatefulWidget {
  final Widget child;

  const DependencyInjector({super.key, required this.child});

  @override
  ConsumerState<DependencyInjector> createState() => _DependencyInjectorState();
}

class _DependencyInjectorState extends ConsumerState<DependencyInjector> {
  @override
  Widget build(BuildContext context) {
    // CRITICAL: Use ref.watch(provider.notifier) instead of ref.read() or ref.watch().
    // .notifier provides the instance WITHOUT subscribing to notifyListeners() calls.
    // This ensures that if Riverpod recreates the provider instance (e.g. during a hot reload 
    // or dependency change), the MultiProvider tree is updated with the NEW instance.
    // Using ref.read() would leave the tree with a STALE, DISPOSED instance, causing crashes.
    // Using ref.watch() would cause massive flickering on every notification.
    final auth = ref.watch(authProvider.notifier);
    final inventory = ref.watch(inventoryProvider.notifier);
    final order = ref.watch(orderProvider.notifier);
    final customer = ref.watch(customerProvider.notifier);
    final store = ref.watch(storeProvider.notifier);
    final dashboard = ref.watch(dashboardProvider.notifier);
    final routerNotifier = ref.watch(routerNotifierProvider.notifier);
    final billing = ref.watch(billingProvider.notifier);

    return p.MultiProvider(
      providers: [
        p.ChangeNotifierProvider.value(value: routerNotifier),
        p.ChangeNotifierProvider.value(value: auth),
        p.ChangeNotifierProvider(create: (_) => LocaleProvider()),
        p.ChangeNotifierProvider.value(value: inventory),
        p.ChangeNotifierProvider.value(value: order),
        p.ChangeNotifierProvider.value(value: customer),
        p.ChangeNotifierProvider.value(value: store),
        p.ChangeNotifierProvider.value(value: dashboard),
        p.ChangeNotifierProvider.value(value: billing),
        p.ChangeNotifierProxyProvider<DashboardProvider, TableProvider>(
          create: (_) => TableProvider(),
          update: (_, dashboard, tableProvider) => tableProvider!..setActiveStoreId(dashboard.activeStoreId),
        ),
        p.ChangeNotifierProxyProvider3<DashboardProvider, OrderProvider, InventoryProvider, SmartInsightsProvider>(
          create: (context) => SmartInsightsProvider(
            p.Provider.of<DashboardProvider>(context, listen: false),
            p.Provider.of<OrderProvider>(context, listen: false),
            p.Provider.of<InventoryProvider>(context, listen: false),
          ),
          update: (_, dashboard, orders, inventory, prev) =>
              prev ?? SmartInsightsProvider(dashboard, orders, inventory),
        ),
      ],
      child: widget.child,
    );
  }
}
