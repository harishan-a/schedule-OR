// =============================================================================
// SplashScreen: Initial Loading Screen
// =============================================================================
// This widget serves as the application's loading screen, displayed during:
// - Initial app launch
// - Authentication state checks
// - Resource loading
//
// The screen provides a minimal interface to indicate that the app is loading,
// following Material Design guidelines for loading states.
// =============================================================================

import 'package:flutter/material.dart';

/// A minimal splash screen widget displayed during app initialization
///
/// This screen is typically shown while:
/// - Firebase is initializing
/// - Authentication state is being checked
/// - Initial app resources are being loaded
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OR Scheduler'),
      ),
      body: const Center(
        child: Text('Loading...'),
      ),
    );
  }
}
