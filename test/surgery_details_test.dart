import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Adjust the import to point to your SurgeryDetailsScreen.
import 'package:firebase_orscheduler/features/surgery/screens/surgery_details.dart';

// ignore: subtype_of_sealed_class
class FakeDocumentSnapshot extends Fake implements DocumentSnapshot {
  final Map<String, dynamic>? _data;
  FakeDocumentSnapshot(this._data);

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => _data != null;

  @override
  String get id => 'fakeId';
}

void main() {
  group('SurgeryDetailsScreen Widget Tests', () {
    late StreamController<DocumentSnapshot> streamController;

    setUp(() {
      streamController = StreamController<DocumentSnapshot>();
    });

    tearDown(() {
      streamController.close();
    });

    testWidgets('displays loading state', (WidgetTester tester) async {
      // Do not emit any data; widget should show loading state.
      await tester.pumpWidget(MaterialApp(
        home: SurgeryDetailsScreen(
          surgeryId: 'testId',
          stream: streamController.stream,
        ),
      ));
      expect(find.text('Loading surgery details...'), findsOneWidget);
    });

    testWidgets('displays error state', (WidgetTester tester) async {
      streamController.addError('Test error');

      await tester.pumpWidget(MaterialApp(
        home: SurgeryDetailsScreen(
          surgeryId: 'testId',
          stream: streamController.stream,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('Error: Test error'), findsOneWidget);
    });

    testWidgets('displays "Surgery not found" if data is null', (WidgetTester tester) async {
      // Emit a snapshot with null data.
      streamController.add(FakeDocumentSnapshot(null));

      await tester.pumpWidget(MaterialApp(
        home: SurgeryDetailsScreen(
          surgeryId: 'testId',
          stream: streamController.stream,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Surgery not found'), findsOneWidget);
    });
  });
}
