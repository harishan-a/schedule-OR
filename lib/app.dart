import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'core/routing/route_names.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/splash.dart';

import 'features/auth/screens/auth.dart';
import 'features/home/screens/home.dart';
import 'features/profile/screens/profile.dart';
import 'features/schedule/screens/schedule.dart';
import 'features/surgery/screens/add_surgery.dart';
import 'features/settings/screens/settings.dart';
import 'features/notifications/screens/notifications_screen.dart';
import 'features/patient/screens/patient_lookup.dart';
import 'features/schedule/screens/schedule_provider.dart';
import 'shared/providers/user_profile_provider.dart';
import 'features/surgery/providers/surgery_form_provider.dart';

/// The root application widget for the OR Scheduler.
///
/// Configures:
/// - MultiProvider for state management
/// - Theme system with accessibility support
/// - Authentication-based routing
/// - Named routes for navigation
class App extends StatefulWidget {
  final bool isDark;
  final bool isLargeText;
  final bool isHighContrast;
  final Function(bool isDark, bool isLargeText, bool isHighContrast)
      updateTheme;

  const App({
    super.key,
    required this.isDark,
    required this.isLargeText,
    required this.isHighContrast,
    required this.updateTheme,
  });

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SurgeryProvider()),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()),
        ChangeNotifierProvider(create: (_) => SurgeryFormProvider()),
      ],
      child: AppTheme(
        isDark: widget.isDark,
        isLargeText: widget.isLargeText,
        isHighContrast: widget.isHighContrast,
        updateTheme: widget.updateTheme,
        child: Builder(
          builder: (context) {
            final appTheme = AppTheme.of(context);
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'ORScheduler',
              theme: appTheme.theme,
              darkTheme: appTheme.darkTheme,
              themeMode: widget.isDark ? ThemeMode.dark : ThemeMode.light,
              home: StreamBuilder(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (ctx, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SplashScreen();
                  }
                  return snapshot.hasData
                      ? const HomeScreen()
                      : const AuthScreen();
                },
              ),
              routes: {
                RouteNames.auth: (context) => const AuthScreen(),
                RouteNames.home: (context) => const HomeScreen(),
                RouteNames.profile: (context) =>
                    const ProfileScreen(fromMoreScreen: false),
                RouteNames.schedule: (context) => const ScheduleScreen(),
                RouteNames.addSurgery: (context) => AddSurgeryScreen(),
                RouteNames.settings: (context) => const SettingsScreen(),
                RouteNames.notifications: (context) =>
                    const NotificationsScreen(),
                RouteNames.patientLookup: (context) =>
                    const PatientLookupScreen(),
              },
            );
          },
        ),
      ),
    );
  }
}
