import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as legacy_provider;
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'providers/dashboard_provider.dart';
import 'providers/locale_provider.dart';
import 'routing/app_router.dart';
import 'utils/theme.dart';
import 'utils/car_dashboard_theme.dart';
import 'core/design/density/app_density.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/theme_provider.dart';
import 'core/dependency_injection/dependency_injector.dart';

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
    
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        final appDensity = themeData.uiStyle == UIStyle.car_dashboard 
            ? AppDensity.touch 
            : AppDensity.comfortable;

        return AppDensityProvider(
          density: appDensity,
          child: MaterialApp.router(
            title: themeData.uiStyle == UIStyle.car_dashboard ? 'BizPOS Auto' : 'BizPOS',
            theme: themeData.uiStyle == UIStyle.car_dashboard 
                ? CarDashboardTheme.getThemeData(isDark: themeData.isDarkMode)
                : AppTheme.getTheme(themeData.currentTheme, false,
                    customSeed: themeData.customThemeColor != null
                        ? Color(themeData.customThemeColor!)
                        : null),
            darkTheme: themeData.uiStyle == UIStyle.car_dashboard
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
              Locale('mr'),
            ],
            routerConfig: _router,
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }
}

class _RootThemeData {
  final UIStyle uiStyle;
  final bool isDarkMode;
  final AppColorTheme currentTheme;
  final int? customThemeColor;

  _RootThemeData({
    required this.uiStyle,
    required this.isDarkMode,
    required this.currentTheme,
    this.customThemeColor,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _RootThemeData &&
          runtimeType == other.runtimeType &&
          uiStyle == other.uiStyle &&
          isDarkMode == other.isDarkMode &&
          currentTheme == other.currentTheme &&
          customThemeColor == other.customThemeColor;

  @override
  int get hashCode => Object.hash(uiStyle, isDarkMode, currentTheme, customThemeColor);
}
