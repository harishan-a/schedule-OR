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
import 'package:provider/provider.dart';
import 'config/firebase_options.dart';
import 'features/auth/screens/auth.dart';
import 'features/home/screens/home.dart';
import 'features/profile/screens/profile.dart';
import 'features/schedule/screens/schedule.dart';
import 'features/schedule/screens/schedule_provider.dart';
import 'features/surgery/screens/add_surgery.dart';
import 'features/settings/screens/settings.dart';
import 'features/notifications/screens/notifications_screen.dart';
import 'shared/widgets/splash.dart';
import 'shared/theme/app_theme.dart';
import 'package:logging/logging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_orscheduler/services/reminder_service.dart';
import 'package:firebase_orscheduler/services/notification_manager.dart';

// Global preferences instance for app-wide settings
late SharedPreferences prefs;
bool _prefsInitialized = false;

// Global service instances
late ReminderService reminderService;
late NotificationManager notificationManager;

/// Application entry point
/// Initializes essential services before running the app:
/// - Firebase (Authentication, Firestore, Messaging)
/// - SharedPreferences for local settings
/// - Platform-specific configurations
Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
  // Initialize logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configure Firestore persistence based on platform
  try {
    if (kIsWeb) {
      await FirebaseFirestore.instance.enablePersistence();
    } else {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
  } catch (e) {
    debugPrint('Error configuring Firestore persistence: $e');
  }

  // Initialize SharedPreferences for local settings storage
  try {
    prefs = await SharedPreferences.getInstance();
    _prefsInitialized = true;
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
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
    }
  }

  // Initialize NotificationManager
  try {
    notificationManager = NotificationManager();
    await notificationManager.initialize();
    debugPrint('NotificationManager initialized successfully');
  } catch (e) {
    debugPrint('Error initializing NotificationManager: $e');
    // Create a fallback notification manager that doesn't use platform-specific features
    if (kIsWeb) {
      debugPrint('Using web fallback for NotificationManager');
      // In web, we'll at least initialize the Firestore part without the platform-specific features
      try {
        notificationManager = NotificationManager(isWebMode: true);
        await notificationManager.initializeWeb();
        debugPrint('Web fallback NotificationManager initialized');
      } catch (webError) {
        debugPrint('Error initializing web fallback NotificationManager: $webError');
      }
    }
  }

  // Initialize ReminderService for surgery notifications (mobile only)
  if (!kIsWeb) {
    try {
      reminderService = ReminderService();
      reminderService.startReminderService();
      
      // Explicitly run a manual check to verify reminders are working
      reminderService.manuallyCheckReminders().then((_) {
        debugPrint('Initial reminder check completed');
      }).catchError((e) {
        debugPrint('Error running initial reminder check: $e');
      });
      
      debugPrint('Reminder service initialized and started');
    } catch (e) {
      debugPrint('Error initializing ReminderService: $e');
    }
  }

  runApp(const MyApp());
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

    // Configure the app with theme support and providers
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SurgeryProvider()),
      ],
      child: AppTheme(
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
              home: StreamBuilder(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (ctx, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SplashScreen();
                  }
                  return snapshot.hasData ? const HomeScreen() : const AuthScreen();
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
                '/notifications': (context) => const NotificationsScreen(),
              },
            );
          },
        ),
      ),
    );
  }
}
