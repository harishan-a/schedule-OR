/// A widget that displays a list of scheduled surgeries with real-time updates.
/// 
/// This widget provides:
/// - Direct Firestore integration for real-time surgery data
/// - Authentication state handling
/// - Filterable list of scheduled surgeries
/// - Interactive surgery cards with detailed information
/// - Dialog-based detailed view for each surgery
/// 
/// The widget specifically shows surgeries with 'Scheduled' status,
/// ordered by start time in ascending order.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SurgeryList extends StatelessWidget {
  const SurgeryList({super.key});

  @override
  Widget build(BuildContext context) {
    // Authentication check
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Please log in'));

    // Real-time surgery data stream
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('surgeries')
          .where('status', isEqualTo: 'Scheduled') // Filter for scheduled surgeries only
          .orderBy('startTime', descending: false) // Chronological order
          .snapshots(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Error handling
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        // Empty state
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No scheduled surgeries found'));
        }

        // Build list of surgery cards
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            // Extract surgery data
            final surgery = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final startTime = (surgery['startTime'] as Timestamp).toDate();
            final endTime = (surgery['endTime'] as Timestamp).toDate();

            // Surgery card with basic information
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: ListTile(
                title: Text(
                  surgery['surgeryType'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                // Summary information in list tile
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Room: ${surgery['room']}'),
                    Text('Date: ${DateFormat('MMM dd, yyyy').format(startTime)}'),
                    Text('Time: ${DateFormat('hh:mm a').format(startTime)} - ${DateFormat('hh:mm a').format(endTime)}'),
                    Text('Surgeon: ${surgery['surgeon']}'),
                    Text('Status: ${surgery['status']}'),
                  ],
                ),
                isThreeLine: true,
                // Show detailed information in dialog
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(surgery['surgeryType']),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Detailed surgery information
                            Text('Room: ${surgery['room']}'),
                            Text('Date: ${DateFormat('MMM dd, yyyy').format(startTime)}'),
                            Text('Time: ${DateFormat('hh:mm a').format(startTime)} - ${DateFormat('hh:mm a').format(endTime)}'),
                            Text('Surgeon: ${surgery['surgeon']}'),
                            // Staff information with null checks
                            Text('Nurses: ${(surgery['nurses'] as List).join(", ")}'),
                            if (surgery['technologists'] != null && (surgery['technologists'] as List).isNotEmpty)
                              Text('Technologist: ${(surgery['technologists'] as List).join(", ")}'),
                            Text('Status: ${surgery['status']}'),
                            // Optional notes section
                            if (surgery['notes'] != null && surgery['notes'].toString().isNotEmpty)
                              Text('Notes: ${surgery['notes']}'),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
