// =============================================================================
// Main Application Entry Point
// =============================================================================
// This file serves as the entry point for the OR Scheduler application.
// It handles:
// - Firebase initialization and configuration
// - Theme and preferences management
// - Authentication state management
// - Route configuration
// - Platform-specific adaptations
//
// The app uses Material Design 3 and follows a feature-first architecture:
// /features
//   /auth - Authentication related screens
//   /home - Main dashboard
//   /profile - User profile management
//   /schedule - Surgery scheduling
//   /settings - App settings and preferences
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:workmanager/workmanager.dart';
import 'config/firebase_options.dart';
import 'features/auth/screens/auth.dart';
import 'features/home/screens/home.dart';
import 'features/profile/screens/profile.dart';
import 'features/schedule/screens/schedule.dart';
import 'features/surgery/screens/add_surgery.dart';
import 'features/settings/screens/settings.dart';
import 'shared/widgets/splash.dart';
import 'shared/theme/app_theme.dart';
import 'package:logging/logging.dart';

// Global preferences instance for app-wide settings
late SharedPreferences prefs;
bool _prefsInitialized = false;

/// Background task callback
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final snapshot = await _firestore.collection('surgeries').get();
    final currentTime = DateTime.now();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final scheduledTime = (data['scheduledTime'] as Timestamp).toDate();

      if (currentTime.isAfter(scheduledTime) && data['status'] == 'Scheduled') {
        await _firestore.collection('surgeries').doc(doc.id).update({'status': 'In Progress'});
      } else if (currentTime.isAfter(scheduledTime.add(Duration(hours: 1))) && data['status'] == 'In Progress') {
        await _firestore.collection('surgeries').doc(doc.id).update({'status': 'Completed'});
      }
    }
    return Future.value(true);
  });
}

/// Application entry point
/// Initializes essential services before running the app:
/// - Firebase (Authentication, Firestore, Messaging)
/// - SharedPreferences for local settings
/// - Platform-specific configurations
Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  try {
    // Initialize Firebase with platform-specific options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully.');

    // Initialize SharedPreferences for local settings storage
    try {
      prefs = await SharedPreferences.getInstance();
      _prefsInitialized = true;
      debugPrint('SharedPreferences initialized successfully.');
    } catch (e) {
      debugPrint('Error initializing SharedPreferences: $e');
      _prefsInitialized = false;
    }

    // Configure Firebase Messaging for notifications (mobile only)
    if (!kIsWeb) {
      try {
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission();
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('Firebase Messaging initialized successfully.');
      } catch (e) {
        debugPrint('Error initializing Firebase Messaging: $e');
      }
    }

    // Configure Firestore persistence based on platform
    if (kIsWeb) {
      await FirebaseFirestore.instance.enablePersistence();
      debugPrint('Firestore persistence enabled for web.');
    } else {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      debugPrint('Firestore persistence enabled for mobile.');
    }

    // Initialize Workmanager for mobile platforms only
    if (!kIsWeb) {
      Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
      Workmanager().registerPeriodicTask(
        "1",
        "updateSurgeryStatus",
        frequency: Duration(minutes: 15),
      );
      debugPrint('Workmanager initialized successfully.');
    }

    runApp(const MyApp());
  } catch (e) {
    debugPrint('Error during initialization: $e');
  }
}

/// Root application widget that configures the app-wide settings:
/// - Theme management
/// - Authentication state
/// - Navigation routes
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Theme state variables
  bool _isDark = false;
  bool _isLargeText = false;
  bool _isHighContrast = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThemePreferences();
  }

  /// Loads theme preferences from SharedPreferences
  Future<void> _loadThemePreferences() async {
    try {
      if (_prefsInitialized) {
        setState(() {
          _isDark = prefs.getBool('darkMode') ?? false;
          _isLargeText = prefs.getBool('largeText') ?? false;
          _isHighContrast = prefs.getBool('highContrast') ?? false;
        });
        debugPrint('Theme preferences loaded successfully.');
      }
    } catch (e) {
      debugPrint('Error loading theme preferences: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Updates theme preferences and persists changes
  Future<void> _updateTheme(bool isDark, bool isLargeText, bool isHighContrast) async {
    if (!mounted) return;
    
    setState(() {
      _isDark = isDark;
      _isLargeText = isLargeText;
      _isHighContrast = isHighContrast;
    });

    if (_prefsInitialized) {
      try {
        await Future.wait([
          prefs.setBool('darkMode', isDark),
          prefs.setBool('largeText', isLargeText),
          prefs.setBool('highContrast', isHighContrast),
        ]);
        debugPrint('Theme preferences updated successfully.');
      } catch (e) {
        debugPrint('Error saving theme preferences: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while initializing preferences
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Container(
            color: _isDark ? Colors.black : Colors.white,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );
    }

    // Configure the app with theme support
    return AppTheme(
      isDark: _isDark,
      isLargeText: _isLargeText,
      isHighContrast: _isHighContrast,
      updateTheme: _updateTheme,
      child: Builder(
        builder: (context) {
          final appTheme = AppTheme.of(context);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'ORScheduler',
            // Configure theme settings
            theme: appTheme.theme,
            darkTheme: appTheme.darkTheme,
            themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
            // Handle authentication state for initial route
            home: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SplashScreen();
                } else if (snapshot.hasError) {
                  debugPrint('Error in authStateChanges: ${snapshot.error}');
                  return Scaffold(
                    body: Center(
                      child: Text('Error: ${snapshot.error}'),
                    ),
                  );
                } else if (snapshot.hasData) {
                  debugPrint('User is authenticated: ${snapshot.data?.uid}');
                  return const HomeScreen();
                } else {
                  debugPrint('User is not authenticated');
                  return const AuthScreen();
                }
              },
            ),
            // Define named routes for navigation
            routes: {
              '/auth': (context) => const AuthScreen(),
              '/home': (context) => const HomeScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/schedule': (context) => const ScheduleScreen(),
              '/add-surgery': (context) => AddSurgeryScreen(),
              '/settings': (context) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }
}
