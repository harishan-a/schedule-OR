import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'config/firebase_options.dart';
import 'core/utils/logger.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/splash.dart';
import 'core/routing/route_names.dart';

// Screens
import 'features/auth/screens/auth.dart';
import 'features/home/screens/home.dart';
import 'features/profile/screens/profile.dart';
import 'features/schedule/screens/schedule.dart';
import 'features/surgery/screens/add_surgery.dart';
import 'features/settings/screens/settings.dart';
import 'features/notifications/screens/notifications_screen.dart';
import 'features/patient/screens/patient_lookup.dart';

// Providers
import 'features/schedule/screens/schedule_provider.dart';
import 'shared/providers/user_profile_provider.dart';
import 'features/surgery/providers/surgery_form_provider.dart';

// Services (kept for backward compatibility during transition)
import 'services/notification_manager.dart';
import 'services/reminder_service.dart';

// @deprecated - these globals are kept for backward compatibility.
// New code should use SettingsRepository and service classes instead.
late SharedPreferences prefs;
bool _prefsInitialized = false;
late ReminderService reminderService;
late NotificationManager notificationManager;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging
  AppLogger.init();
  final logger = AppLogger.getLogger('main');

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Warning: .env file not found, using defaults');
  }

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Connect to Firebase emulators for local development.
  // Auto-detects localhost on web, or use --dart-define=USE_EMULATORS=true.
  await _connectToEmulatorsIfLocal(logger);

  // Configure Firestore persistence
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
    logger.warning('Error configuring Firestore persistence: $e');
  }

  // Initialize SharedPreferences
  try {
    prefs = await SharedPreferences.getInstance();
    _prefsInitialized = true;
  } catch (e) {
    logger.warning('Error initializing SharedPreferences: $e');
    _prefsInitialized = false;
  }

  // Configure Firebase Messaging (mobile only)
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
      logger.warning('Error initializing Firebase Messaging: $e');
    }
  }

  // Initialize NotificationManager (backward compatibility)
  try {
    notificationManager = NotificationManager();
    await notificationManager.initialize();
    logger.info('NotificationManager initialized');
  } catch (e) {
    logger.warning('Error initializing NotificationManager: $e');
    if (kIsWeb) {
      try {
        notificationManager = NotificationManager(isWebMode: true);
        await notificationManager.initializeWeb();
      } catch (webError) {
        logger.warning('Error initializing web NotificationManager: $webError');
      }
    }
  }

  // Initialize ReminderService (mobile only, backward compatibility)
  if (!kIsWeb) {
    try {
      reminderService = ReminderService();
      reminderService.startReminderService();
      reminderService.manuallyCheckReminders().catchError((e) {
        logger.warning('Error running initial reminder check: $e');
      });
      logger.info('Reminder service started');
    } catch (e) {
      logger.warning('Error initializing ReminderService: $e');
    }
  }

  runApp(const MyApp());
}

/// Root application widget.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDark = false;
  bool _isLargeText = false;
  bool _isHighContrast = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThemePreferences();
  }

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

  Future<void> _updateTheme(
      bool isDark, bool isLargeText, bool isHighContrast) async {
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
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Container(
            color: _isDark ? Colors.black : Colors.white,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SurgeryProvider()),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()),
        ChangeNotifierProvider(create: (_) => SurgeryFormProvider()),
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
              theme: appTheme.theme,
              darkTheme: appTheme.darkTheme,
              themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
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

/// Connects to Firebase emulators if running locally.
///
/// Detection logic:
/// 1. --dart-define=USE_EMULATORS=true (compile-time, any platform)
/// 2. Web on localhost or 127.0.0.1 (runtime, auto-detected)
/// 3. Web with ?emulator query parameter (runtime, explicit)
///
/// This gives zero-config local development: `firebase emulators:start`
/// then `flutter run -d chrome` — emulators are used automatically.
/// Deployed to a real domain → production Firebase, no changes needed.
Future<void> _connectToEmulatorsIfLocal(dynamic logger) async {
  const emulatorFlag =
      String.fromEnvironment('USE_EMULATORS', defaultValue: 'false');

  bool useEmulators = emulatorFlag == 'true';

  if (!useEmulators && kIsWeb) {
    try {
      final host = Uri.base.host;
      useEmulators =
          host == 'localhost' ||
          host == '127.0.0.1' ||
          Uri.base.queryParameters.containsKey('emulator');
    } catch (_) {
      // Uri.base may fail in some environments; skip auto-detection
    }
  }

  if (!useEmulators) return;

  logger.info('Local development detected — connecting to Firebase emulators');
  try {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8181);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    logger.info('Connected to emulators (Auth :9099, Firestore :8181)');
  } catch (e) {
    logger.warning('Failed to connect to emulators: $e');
  }
}

