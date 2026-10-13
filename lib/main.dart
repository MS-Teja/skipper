import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_router.dart';
import 'providers/attendance_provider.dart';
import 'providers/holiday_provider.dart';
import 'providers/planner_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/timetable_provider.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/demo_data.dart';
import 'services/holiday_api_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = StorageService();
  await storage.init();
  // Dev flag: `--dart-define=DEMO=true` loads the sample semester on launch.
  if (const bool.fromEnvironment('DEMO')) {
    await seedDemoSemester(storage, storage.loadSettings());
  }
  final notifications = NotificationService();
  await notifications.init();
  runApp(
    SkipperApp(
      storage: storage,
      notifications: notifications,
      api: HolidayApiService(),
    ),
  );
}

class SkipperApp extends StatelessWidget {
  const SkipperApp({
    super.key,
    required this.storage,
    required this.notifications,
    required this.api,
  });

  final StorageService storage;
  final NotificationService notifications;
  final HolidayApiService api;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: storage),
        Provider.value(value: notifications),
        ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
        ChangeNotifierProvider(create: (_) => TimetableProvider(storage)),
        ChangeNotifierProvider(create: (_) => HolidayProvider(storage, api)),
        ChangeNotifierProxyProvider3<
          SettingsProvider,
          TimetableProvider,
          HolidayProvider,
          AttendanceProvider
        >(
          create: (_) => AttendanceProvider(storage),
          update: (_, s, t, h, a) => a!..updateDeps(s, t, h),
        ),
        ChangeNotifierProxyProvider<AttendanceProvider, PlannerProvider>(
          create: (_) => PlannerProvider(),
          update: (_, a, p) => p!..updateDeps(a),
        ),
      ],
      // Rebuilds only when the look changes, not on every settings tweak.
      child: Builder(
        builder: (context) {
          final (themeMode, accent) = context
              .select<SettingsProvider, (ThemeMode, int)>(
                (p) => (p.settings.themeMode, p.settings.accentIndex),
              );
          return MaterialApp(
            title: 'Skipper',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            themeMode: themeMode,
            theme: themeFor(Brightness.light, accent),
            darkTheme: themeFor(Brightness.dark, accent),
            // Swap instantly: interpolating the whole theme rebuilds the
            // entire app every frame for the length of the animation.
            themeAnimationDuration: Duration.zero,
            onGenerateRoute: onGenerateRoute,
            scrollBehavior: const _AppScrollBehavior(),
            builder: (context, child) {
              final dark = Theme.of(context).brightness == Brightness.dark;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: dark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark,
                child: child!,
              );
            },
            home: const RootGate(),
          );
        },
      ),
    );
  }
}

/// Onboarding until the student has set things up, then the main app.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final onboarded = context.select<SettingsProvider, bool>(
      (s) => s.settings.onboarded,
    );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutCubic,
      child: onboarded
          ? const HomeShell(key: ValueKey('home'))
          : const OnboardingScreen(key: ValueKey('onboarding')),
    );
  }
}

/// iOS scrolling on every platform: rubber-band bounce, no Android glow.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
