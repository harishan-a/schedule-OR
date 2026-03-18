// =============================================================================
// Filtered Surgeries Screen
// =============================================================================
// A screen that displays surgeries filtered by status (Scheduled, In Progress,
// Completed, or Cancelled). Features include:
// - Real-time Firestore integration for surgery data
// - Animated list transitions
// - Interactive surgery cards
// - Detail view navigation
// - Empty state handling
// =============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_orscheduler/features/surgery/utils/surgery_detail_utils.dart';

class FilteredSurgeriesScreen extends StatelessWidget {
  /// The status to filter surgeries by (Scheduled, In Progress, Completed, Cancelled)
  final String status;

  /// Optional title override. If not provided, status will be used
  final String? title;

  /// Creates a filtered surgeries screen
  const FilteredSurgeriesScreen({
    super.key,
    required this.status,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final screenTitle = title ?? status;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle),
        elevation: 0,
      ),
      body: _buildSurgeryList(context),
    );
  }

  /// Builds the list of surgeries filtered by status
  Widget _buildSurgeryList(BuildContext context) {
    // Authentication check
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in to view surgeries'));
    }

    // Get user's display name for filtering
    final userDisplayName = user.displayName ?? '';

    // Get status color for visual consistency
    final statusColor = _getStatusColor(status);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('surgeries')
          .where('status', isEqualTo: status)
          .where(Filter.or(
            Filter('surgeon', isEqualTo: userDisplayName),
            Filter('nurses', arrayContains: userDisplayName),
            Filter('technologists', arrayContains: userDisplayName),
          ))
          .orderBy('startTime', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Handle error state
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error loading surgeries',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Handle empty state
        final surgeries = snapshot.data?.docs ?? [];
        if (surgeries.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getStatusIcon(status),
                  size: 64,
                  color: statusColor.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No $status Surgeries',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Check back later for updates',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        }

        // Build the list of surgeries
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: surgeries.length,
          itemBuilder: (context, index) {
            final surgeryDoc = surgeries[index];
            final surgeryId = surgeryDoc.id;
            final surgery = surgeryDoc.data() as Map<String, dynamic>;

            return _buildSurgeryCard(context, surgeryId, surgery);
          },
        );
      },
    );
  }

  /// Builds a card for a single surgery
  Widget _buildSurgeryCard(
      BuildContext context, String surgeryId, Map<String, dynamic> surgery) {
    final colorScheme = Theme.of(context).colorScheme;
    final startTime = (surgery['startTime'] as Timestamp).toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showSurgeryDetailBottomSheet(context, surgeryId),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Surgery type and patient name
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.medical_services_outlined,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          surgery['surgeryType'] ?? 'Unknown Surgery',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          surgery['patientName'] ?? 'Unknown Patient',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 24),

              // Surgery details
              Row(
                children: [
                  // Date and time
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat('MMM d, y').format(startTime),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Time
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat('h:mm a').format(startTime),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Room and surgeon
              Row(
                children: [
                  // Room
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.room_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatRoom(surgery['room']),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Surgeon
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            surgery['surgeon'] ?? 'Unknown',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper method to format the room field
  String _formatRoom(dynamic room) {
    if (room == null) return 'Unassigned';
    if (room is List) return room.join(', ');
    return room.toString();
  }

  /// Gets the appropriate color for a given status
  Color _getStatusColor(String status) {
    return switch (status.toLowerCase()) {
      'scheduled' => Colors.blue,
      'in progress' => Colors.orange,
      'completed' => Colors.green,
      'cancelled' => Colors.red,
      _ => Colors.grey,
    };
  }

  /// Gets the appropriate icon for a given status
  IconData _getStatusIcon(String status) {
    return switch (status.toLowerCase()) {
      'scheduled' => Icons.schedule_outlined,
      'in progress' => Icons.sync_outlined,
      'completed' => Icons.check_circle_outlined,
      'cancelled' => Icons.cancel_outlined,
      _ => Icons.help_outline,
    };
  }
}
