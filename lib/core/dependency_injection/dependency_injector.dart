import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dependency_injection/providers.dart';

import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/store_provider.dart';
import '../../providers/table_provider.dart';
import '../../providers/smart_insights_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/sync_service.dart';
import '../../routing/app_router.dart';

class DependencyInjector extends ConsumerWidget {
  final Widget child;

  const DependencyInjector({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return p.MultiProvider(
      providers: [
        p.ChangeNotifierProvider(create: (_) => RouterNotifier()),
        p.ChangeNotifierProvider.value(value: ref.watch(authProvider)),
        p.ChangeNotifierProvider(create: (_) => LocaleProvider()),
        p.ChangeNotifierProvider.value(value: ref.watch(inventoryProvider)),
        p.ChangeNotifierProvider.value(value: ref.watch(orderProvider)),
        p.ChangeNotifierProvider.value(value: ref.watch(customerProvider)),
        p.ChangeNotifierProvider.value(value: ref.watch(storeProvider)),
        p.ChangeNotifierProvider.value(value: ref.watch(dashboardProvider)),
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
      child: child,
    );
  }
}
