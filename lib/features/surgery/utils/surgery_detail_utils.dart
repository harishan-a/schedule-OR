import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_orscheduler/features/schedule/screens/surgery_details.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';

/// Shows a surgery detail bottom sheet that can be used anywhere in the app
///
/// This provides a consistent experience for viewing surgery details
/// regardless of where they are accessed from in the app.
void showSurgeryDetailBottomSheet(BuildContext context, String surgeryId) {
  // Get a stream of the surgery data
  final surgeryStream = FirebaseFirestore.instance
      .collection('surgeries')
      .doc(surgeryId)
      .snapshots();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => StreamBuilder<DocumentSnapshot>(
      stream: surgeryStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            builder: (_, controller) => Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;

        if (data == null) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            builder: (_, controller) => Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Center(
                child: Text('Surgery not found'),
              ),
            ),
          );
        }

        // Use the factory method to create a Surgery from Firestore data
        final surgery = Surgery.fromFirestore(snapshot.data!.id, data);

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (_, controller) => SurgeryDetails(
            surgery: surgery,
            scrollController: controller,
          ),
        );
      },
    ),
  );
}

/// Helper function to safely extract a list from a dynamic value
List<String> _extractList(dynamic value) {
  if (value == null) return [];
  if (value is List) return value.map((item) => item.toString()).toList();
  return [value.toString()];
}
