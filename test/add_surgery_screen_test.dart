import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Import your updated widget.
import 'package:firebase_orscheduler/features/surgery/screens/add_surgery.dart';

void main() {
  // Set mock SharedPreferences.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('AddSurgeryScreen Widget Tests', () {
    testWidgets('renders all main sections', (WidgetTester tester) async {
      // Pass isTestMode: true to bypass Firebase calls.
      await tester.pumpWidget(MaterialApp(home: AddSurgeryScreen(isTestMode: true)));
      await tester.pumpAndSettle();

      expect(find.text('Schedule New Surgery'), findsOneWidget);
      expect(find.text('Patient Information'), findsOneWidget);
      expect(find.text('Surgery Details'), findsOneWidget);
      // Adjust this if "Schedule" appears more than once.
      expect(find.text('Schedule'), findsNWidgets(2));
      expect(find.text('Medical Team'), findsOneWidget);
      expect(find.text('Additional Notes'), findsOneWidget);
    });

    testWidgets('shows validation error if required fields are empty', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: AddSurgeryScreen(isTestMode: true)));
      await tester.pumpAndSettle();

      final previewButtonFinder = find.text('Preview Surgery Details');
      await tester.ensureVisible(previewButtonFinder);
      await tester.tap(previewButtonFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Please fill in all required fields correctly'), findsOneWidget);
    });

    testWidgets('preview mode displays entered data', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: AddSurgeryScreen(isTestMode: true)));
      await tester.pumpAndSettle();

      // Enter Patient Information.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Patient Name'),
        'Jane Doe',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Age'),
        '45',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Medical Record Number'),
        'MRN987654',
      );

      // Select Gender from the dropdown.
      final genderFieldFinder = find.byWidgetPredicate((widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Gender');
      await tester.ensureVisible(genderFieldFinder);
      await tester.tap(genderFieldFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Female').first);
      await tester.pumpAndSettle();

      // Select Surgery Type.
      final surgeryTypeFieldFinder = find.byWidgetPredicate((widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Surgery Type');
      await tester.ensureVisible(surgeryTypeFieldFinder);
      await tester.tap(surgeryTypeFieldFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cardiac Surgery').first);
      await tester.pumpAndSettle();

      // Select Operating Room.
      final operatingRoomFieldFinder = find.byWidgetPredicate((widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Operating Room');
      await tester.ensureVisible(operatingRoomFieldFinder);
      await tester.tap(operatingRoomFieldFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OperatingRoom1').first);
      await tester.pumpAndSettle();

      // For Nurse selection, tap the MultiSelect field.
      final nurseFieldFinder = find.text('Select Nurses');
      await tester.ensureVisible(nurseFieldFinder);
      await tester.tap(nurseFieldFinder);
      await tester.pumpAndSettle();
      if (find.textContaining('Nurse').evaluate().isNotEmpty) {
        await tester.tap(find.textContaining('Nurse').first);
        await tester.pumpAndSettle();
        final okButtonFinder = find.text('OK');
        if (okButtonFinder.evaluate().isNotEmpty) {
          await tester.tap(okButtonFinder.first);
          await tester.pumpAndSettle();
        }
      }

      final previewButtonFinder = find.text('Preview Surgery Details');
      await tester.ensureVisible(previewButtonFinder);
      await tester.tap(previewButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Jane Doe'), findsWidgets);
      expect(find.text('45'), findsWidgets);
      expect(find.text('MRN987654'), findsWidgets);
    });
  });
}
