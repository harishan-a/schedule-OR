import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_orscheduler/features/surgery/screens/add_surgery.dart'; // Correct import path
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mockito/mockito.dart';
import 'package:dropdown_search/dropdown_search.dart';

class MockFirestore extends Mock implements FirebaseFirestore {}

void main() async {
  // Initialize Firebase before tests
  setUpAll(() async {
    await Firebase.initializeApp();
  });

  // Mock Firestore instance
  final mockFirestore = MockFirestore();

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: Scaffold(
        body: AddSurgeryScreen(),
      ),
    );
  }

  group('AddSurgeryScreen Tests', () {
    testWidgets('displays surgery type dropdown', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      expect(find.text('Surgery Type'), findsOneWidget);
    });

    testWidgets('selects a surgery type', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.byType(DropdownButtonFormField).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cardiac Surgery').last);
      await tester.pumpAndSettle();
      expect(find.text('Cardiac Surgery'), findsOneWidget);
    });

    testWidgets('validates form input fields', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // Submit without filling form to trigger validation errors
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Please enter the surgery type'), findsOneWidget);
      expect(find.text('Please enter the room'), findsOneWidget);
    });

    testWidgets('successful form submission adds surgery to Firestore',
        (WidgetTester tester) async {
      // Update AddSurgeryScreen to accept Firestore instance for testing
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AddSurgeryScreen(),
        ),
      ));

      // Select surgery type
      await tester.tap(find.byType(DropdownButtonFormField).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cardiac Surgery').last);
      await tester.pumpAndSettle();

      // Select operating room
      await tester.tap(find.byType(DropdownButtonFormField).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OperatingRoom1').last);
      await tester.pumpAndSettle();

      // Select doctor
      await tester.tap(find.byType(DropdownSearch).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Dr. Smith');
      await tester.pumpAndSettle();

      // Fill in notes
      await tester.enterText(find.byType(TextFormField), 'Scheduled surgery');

      // Submit form
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Check if data was added to Firestore
      final addedSurgery = await mockFirestore
          .collection('surgeries')
          .where('surgeryType', isEqualTo: 'Cardiac Surgery')
          .get();

      expect(addedSurgery.docs.isNotEmpty, true);
    });
  });
}