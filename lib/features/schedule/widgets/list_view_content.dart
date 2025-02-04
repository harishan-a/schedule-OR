// =============================================================================
// List View Content Widget
// =============================================================================
// A widget that displays a scrollable list of surgeries with:
// - Chronological ordering
// - Status-based color coding
// - Interactive surgery cards
// - Compact information display
//
// Features:
// - Surgery sorting by date/time
// - Status chip indicators
// - Card-based layout
// - Touch interaction support
//
// Note: This widget is used as one of the schedule view options and
// provides a simple, list-based view of surgeries optimized for quick scanning.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';
import 'package:intl/intl.dart';

/// Displays surgeries in a scrollable list format
class ListViewContent extends StatelessWidget {
  /// List of surgeries to display
  final List<Surgery> surgeries;

  const ListViewContent({
    super.key,
    required this.surgeries,
  });

  @override
  Widget build(BuildContext context) {
    // Sort surgeries chronologically
    final sortedSurgeries = [...surgeries]..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    
    return ListView.builder(
      itemCount: sortedSurgeries.length,
      itemBuilder: (context, index) {
        final surgery = sortedSurgeries[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(surgery.patientName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and time display
                Text(DateFormat('MMM d, y - h:mm a').format(surgery.dateTime)),
                // Room and duration information
                Text('Room: ${surgery.roomId} • Duration: ${surgery.duration} min'),
              ],
            ),
            trailing: _buildStatusChip(surgery.status),
            onTap: () {
              // TODO: Navigate to surgery details
            },
          ),
        );
      },
    );
  }

  /// Builds a status indicator chip with appropriate color
  /// 
  /// Parameters:
  /// - status: Current status of the surgery
  /// 
  /// Color coding:
  /// - Scheduled: Blue
  /// - In Progress: Orange
  /// - Completed: Green
  /// - Cancelled: Red
  /// - Default: Grey
  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'scheduled':
        color = Colors.blue;
        break;
      case 'in progress':
        color = Colors.orange;
        break;
      case 'completed':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        status,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
