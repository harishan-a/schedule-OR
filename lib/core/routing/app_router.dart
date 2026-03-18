import 'package:flutter/material.dart';
import 'route_names.dart';
import 'package:firebase_orscheduler/features/auth/screens/auth.dart';
import 'package:firebase_orscheduler/features/home/screens/home.dart';
import 'package:firebase_orscheduler/features/profile/screens/profile.dart';
import 'package:firebase_orscheduler/features/schedule/screens/schedule.dart';
import 'package:firebase_orscheduler/features/surgery/screens/add_surgery.dart';
import 'package:firebase_orscheduler/features/surgery/screens/surgery_details.dart';
import 'package:firebase_orscheduler/features/settings/screens/settings.dart';
import 'package:firebase_orscheduler/features/notifications/screens/notifications_screen.dart';
import 'package:firebase_orscheduler/features/patient/screens/patient_lookup.dart';

/// Centralized route generation for the app.
class AppRouter {
  AppRouter._();

  /// Generate routes from route settings.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.auth:
        return _buildRoute(page: const AuthScreen(), settings: settings);
      case RouteNames.home:
        return _buildRoute(page: const HomeScreen(), settings: settings);
      case RouteNames.profile:
        return _buildRoute(
          page: const ProfileScreen(fromMoreScreen: false),
          settings: settings,
        );
      case RouteNames.schedule:
        return _buildRoute(page: const ScheduleScreen(), settings: settings);
      case RouteNames.addSurgery:
        return _buildRoute(page: AddSurgeryScreen(), settings: settings);
      case RouteNames.surgeryDetails:
        final surgeryId = settings.arguments as String?;
        if (surgeryId != null) {
          return _buildRoute(
            page: SurgeryDetailsScreen(surgeryId: surgeryId),
            settings: settings,
          );
        }
        return null;
      case RouteNames.settings:
        return _buildRoute(page: const SettingsScreen(), settings: settings);
      case RouteNames.notifications:
        return _buildRoute(
            page: const NotificationsScreen(), settings: settings);
      case RouteNames.patientLookup:
        return _buildRoute(
            page: const PatientLookupScreen(), settings: settings);
      default:
        return null;
    }
  }

  static MaterialPageRoute<T> _buildRoute<T>({
    required Widget page,
    required RouteSettings settings,
    bool fullscreenDialog = false,
  }) {
    return MaterialPageRoute<T>(
      builder: (_) => page,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
    );
  }
}
