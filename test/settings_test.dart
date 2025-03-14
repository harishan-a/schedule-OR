import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_orscheduler/features/settings/screens/settings.dart';

/// A small mock AppTheme to prevent "No AppTheme found in context" errors
class MockAppTheme extends InheritedWidget {
  const MockAppTheme({
    Key? key,
    required Widget child,
  }) : super(key: key, child: child);

  static MockAppTheme of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<MockAppTheme>();
    if (widget == null) {
      throw FlutterError('No MockAppTheme found in context');
    }
    return widget;
  }

  void updateTheme(bool darkMode, bool largeText, bool highContrast) {
    // Do nothing in tests
  }

  @override
  bool updateShouldNotify(MockAppTheme oldWidget) => false;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsScreen Widget Tests (Test Mode)', () {
    // Helper to pump the SettingsScreen in test mode
    Future<void> pumpSettingsScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MockAppTheme(
            child: SettingsScreen(isTestMode: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('toggles dark mode without crashing', (WidgetTester tester) async {
      await pumpSettingsScreen(tester);

      final darkModeSwitch = find.widgetWithText(SwitchListTile, 'Dark Mode');
      expect(darkModeSwitch, findsOneWidget);

      // Tap the switch
      await tester.tap(darkModeSwitch);
      await tester.pump();
    });

    testWidgets('toggles high contrast without crashing', (WidgetTester tester) async {
      await pumpSettingsScreen(tester);

      final highContrastSwitch = find.widgetWithText(SwitchListTile, 'High Contrast');
      expect(highContrastSwitch, findsOneWidget);

      await tester.tap(highContrastSwitch);
      await tester.pump();
    });

    testWidgets('toggles large text without crashing', (WidgetTester tester) async {
      await pumpSettingsScreen(tester);

      final largeTextSwitch = find.widgetWithText(SwitchListTile, 'Large Text');
      expect(largeTextSwitch, findsOneWidget);

      await tester.tap(largeTextSwitch);
      await tester.pump();
    });

    //
    // testWidgets('toggles sound effects without crashing', (WidgetTester tester) async {
    //   await pumpSettingsScreen(tester);
    //
    //   final soundEffectsSwitch = find.widgetWithText(SwitchListTile, 'Sound Effects');
    //   expect(soundEffectsSwitch, findsOneWidget);
    //
    //   await tester.tap(soundEffectsSwitch);
    //   await tester.pump();
    // });
    //
    // testWidgets('opens Resource Check screen', (WidgetTester tester) async {
    //   await pumpSettingsScreen(tester);
    //
    //   // Tap "Resource Check"
    //   final resourceCheckTile = find.text('Resource Check');
    //   expect(resourceCheckTile, findsOneWidget);
    //
    //   await tester.tap(resourceCheckTile);
    //   await tester.pumpAndSettle();
    //
    //   // We should now be on ResourceCheckScreen
    //   expect(find.byType(ResourceCheckScreen), findsOneWidget);
    // });
    //
    // testWidgets('shows Terms of Service dialog', (WidgetTester tester) async {
    //   await pumpSettingsScreen(tester);
    //
    //   final tosTile = find.text('Terms of Service');
    //   expect(tosTile, findsOneWidget);
    //
    //   await tester.tap(tosTile);
    //   await tester.pumpAndSettle();
    //
    //   // Dialog should appear
    //   expect(find.text('Terms of Service'), findsWidgets);
    //   // Close dialog
    //   final closeBtn = find.text('Close');
    //   await tester.tap(closeBtn);
    //   await tester.pumpAndSettle();
    // });
  });
}
