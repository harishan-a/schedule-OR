import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_orscheduler/screens/auth.dart';
import 'package:firebase_orscheduler/screens/home.dart';
import 'package:firebase_orscheduler/screens/profile.dart'; // Import the Profile Screen
import 'package:firebase_orscheduler/screens/schedule.dart'; // Import the Schedule Screen
import 'package:firebase_orscheduler/screens/add_surgery.dart'; // Import the Add Surgery Screen
import 'package:firebase_orscheduler/screens/splash.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ORScheduler',
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 238, 83, 12), primary: const Color.fromARGB(255, 253, 227, 206)),
        useMaterial3: true,
      ),
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }

          if (snapshot.hasData) {
            return const HomeScreen();
          }

          return const AuthScreen();
        },
      ),
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/schedule': (context) => const ScheduleScreen(), // Add Schedule route
        '/add-surgery': (context) => AddSurgeryScreen(), // Add Add Surgery route
      },
    );
  }
}
