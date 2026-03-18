import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_orscheduler/features/profile/screens/profile.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({}); // Prevents real local storage usage
  });

  group('ProfileScreen Widget Tests (Test Mode)', () {
    Future<void> pumpProfileScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(isTestMode: true),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('displays dummy user info in test mode', (WidgetTester tester) async {
      await pumpProfileScreen(tester);

      // The app bar
      expect(find.text('Edit Profile'), findsOneWidget);

      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('(000) 000-0000'), findsOneWidget);
      expect(find.text('Developer'), findsOneWidget);
      expect(find.text('Engineering'), findsOneWidget);
    });

    testWidgets('shows "Change Password" button', (WidgetTester tester) async {
      await pumpProfileScreen(tester);
      expect(find.text('Change Password'), findsOneWidget);
    });

    // testWidgets('has a CustomNavigationBar at the bottom', (WidgetTester tester) async {
    //   await pumpProfileScreen(tester);
    //
    //   // The custom nav bar should be rendered
    //   expect(find.byType(CustomNavigationBar), findsOneWidget);
    // });

    testWidgets('profile picture placeholder is displayed in test mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(isTestMode: true),
        ),
      );
      await tester.pumpAndSettle();

      final circleAvatar = find.byType(CircleAvatar);
      expect(circleAvatar, findsOneWidget);

      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    // testWidgets('tapping camera icon does not crash in test mode', (WidgetTester tester) async {
    //   await pumpProfileScreen(tester);
    //
    //   // Tap the small camera icon
    //   final cameraIcon = find.byIcon(Icons.camera_alt);
    //   expect(cameraIcon, findsOneWidget);
    //
    //   await tester.tap(cameraIcon);
    //   await tester.pump();
    //
    //   // No crash => success
    // });
  });
}
