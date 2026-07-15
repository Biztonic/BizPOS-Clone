import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as legacy_provider;
import 'package:flutter_localizations/flutter_localizations.dart';

import 'providers/locale_provider.dart';
import 'providers/dashboard_provider.dart';
import 'screens/error/clock_tampered_screen.dart';
import 'routing/app_router.dart';
import 'utils/theme.dart';
import 'utils/car_dashboard_theme.dart';
import 'core/design/density/app_density.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/theme_provider.dart';
import 'core/dependency_injection/dependency_injector.dart';
import 'announcement/announcement.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: DependencyInjector(
        child: BizPOSApp(),
      ),
    );
  }
}

class BizPOSApp extends ConsumerStatefulWidget {
  const BizPOSApp({super.key});

  @override
  ConsumerState<BizPOSApp> createState() => _BizPOSAppState();
}

class _BizPOSAppState extends ConsumerState<BizPOSApp> {
  late final _router = AppRouter.createRouter(context);

  @override
  Widget build(BuildContext context) {
    final themeData = ref.watch(themeProvider);
    
    return legacy_provider.Consumer2<LocaleProvider, DashboardProvider>(
      builder: (context, localeProvider, dashboardProvider, _) {
        final view = View.of(context);
        final size = view.physicalSize / view.devicePixelRatio;
        final isMobile = size.width < 600;
        final isCarDashboard = themeData.uiStyle == UIStyle.car_dashboard && !isMobile;

        final appDensity = isCarDashboard 
            ? AppDensity.touch 
            : AppDensity.comfortable;

        if (dashboardProvider.isClockTampered) {
          return AppDensityProvider(
            density: appDensity,
            child: MaterialApp(
              title: 'BizPOS Lockout',
              theme: isCarDashboard 
                  ? CarDashboardTheme.getThemeData(isDark: themeData.isDarkMode)
                  : AppTheme.getTheme(themeData.currentTheme, false,
                      customSeed: themeData.customThemeColor != null
                          ? Color(themeData.customThemeColor!)
                          : null),
              darkTheme: isCarDashboard
                  ? CarDashboardTheme.getThemeData(isDark: themeData.isDarkMode)
                  : AppTheme.getTheme(themeData.currentTheme, true,
                      customSeed: themeData.customThemeColor != null
                          ? Color(themeData.customThemeColor!)
                          : null),
              themeMode: themeData.isDarkMode ? ThemeMode.dark : ThemeMode.light,
              locale: localeProvider.locale,
              localizationsDelegates: const [
                AppLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('en'),
                Locale('hi'),
                Locale('bn'),
                Locale('mr'),
                Locale('te'),
                Locale('ta'),
                Locale('gu'),
                Locale('ur'),
                Locale('kn'),
                Locale('or'),
                Locale('ml'),
              ],
              home: const ClockTamperedScreen(),
              debugShowCheckedModeBanner: false,
            ),
          );
        }

        return AppDensityProvider(
          density: appDensity,
          child: MaterialApp.router(
            title: isCarDashboard ? 'BizPOS Auto' : 'BizPOS',
            theme: isCarDashboard 
                ? CarDashboardTheme.getThemeData(isDark: themeData.isDarkMode)
                : AppTheme.getTheme(themeData.currentTheme, false,
                    customSeed: themeData.customThemeColor != null
                        ? Color(themeData.customThemeColor!)
                        : null),
            darkTheme: isCarDashboard
                ? CarDashboardTheme.getThemeData(isDark: themeData.isDarkMode)
                : AppTheme.getTheme(themeData.currentTheme, true,
                    customSeed: themeData.customThemeColor != null
                        ? Color(themeData.customThemeColor!)
                        : null),
            themeMode: themeData.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            locale: localeProvider.locale,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('hi'),
              Locale('bn'),
              Locale('mr'),
              Locale('te'),
              Locale('ta'),
              Locale('gu'),
              Locale('ur'),
              Locale('kn'),
              Locale('or'),
              Locale('ml'),
            ],
            routerConfig: _router,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              return Listener(
                onPointerDown: (_) {
                  AnnouncementService().playInteractionSound();
                },
                child: child!,
              );
            },
          ),
        );
      },
    );
  }
}


