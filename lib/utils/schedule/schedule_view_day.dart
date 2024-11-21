import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DayListView extends StatelessWidget {
  final List<dynamic> surgeries;

  const DayListView({
    super.key,
    required this.surgeries,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    
    // Get surgeries for today
    final todaySurgeries = surgeries.where((surgery) {
      final surgeryDate = (surgery['startTime'] as Timestamp).toDate();
      return surgeryDate.year == now.year &&
          surgeryDate.month == now.month &&
          surgeryDate.day == now.day;
    }).toList();

    // Separate surgeries by status
    final inProgressSurgeries = todaySurgeries
        .where((s) => s['status'].toLowerCase() == 'in progress')
        .toList();
    final upcomingSurgeries = todaySurgeries
        .where((s) => s['status'].toLowerCase() == 'scheduled')
        .toList()
      ..sort((a, b) => (a['startTime'] as Timestamp)
          .compareTo(b['startTime'] as Timestamp));
    final completedSurgeries = todaySurgeries
        .where((s) => s['status'].toLowerCase() == 'completed')
        .toList();

    return CustomScrollView(
      slivers: [
        // Current Date Header
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Text(
              DateFormat('EEEE, MMMM d').format(now),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),

        // In Progress Section
        if (inProgressSurgeries.isNotEmpty) ...[
          _buildSectionHeader('In Progress'),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSurgeryCard(
                context,
                inProgressSurgeries[index],
                isInProgress: true,
              ),
              childCount: inProgressSurgeries.length,
            ),
          ),
        ],

        // Upcoming Section
        if (upcomingSurgeries.isNotEmpty) ...[
          _buildSectionHeader('Upcoming'),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSurgeryCard(
                context,
                upcomingSurgeries[index],
              ),
              childCount: upcomingSurgeries.length,
            ),
          ),
        ],

        // Completed Section
        if (completedSurgeries.isNotEmpty) ...[
          _buildSectionHeader('Completed'),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSurgeryCard(
                context,
                completedSurgeries[index],
                isCompleted: true,
              ),
              childCount: completedSurgeries.length,
            ),
          ),
        ],

        // Empty State
        if (todaySurgeries.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No surgeries scheduled for today',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSurgeryCard(
    BuildContext context,
    Map<String, dynamic> surgery, {
    bool isInProgress = false,
    bool isCompleted = false,
  }) {
    final startTime = (surgery['startTime'] as Timestamp).toDate();
    final endTime = (surgery['endTime'] as Timestamp).toDate();
    final status = surgery['status'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isInProgress ? 4 : 1,
      child: Container(
        decoration: BoxDecoration(
          border: isInProgress
              ? Border.all(
                  color: _getStatusColor(status),
                  width: 2,
                )
              : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  surgery['surgeryType'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 16, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 4),
                  Text(
                    '${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.meeting_room,
                      size: 16, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Room ${surgery['room'].join(", ")}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person,
                      size: 16, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Dr. ${surgery['surgeon']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          onTap: () => _showSurgeryDetails(context, surgery),
        ),
      ),
    );
  }

  void _showSurgeryDetails(BuildContext context, Map<String, dynamic> surgery) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                surgery['surgeryType'],
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Room', surgery['room'].join(", ")),
              _buildDetailRow('Status', surgery['status']),
              _buildDetailRow(
                'Time',
                '${DateFormat('h:mm a').format((surgery['startTime'] as Timestamp).toDate())} - '
                '${DateFormat('h:mm a').format((surgery['endTime'] as Timestamp).toDate())}',
              ),
              _buildDetailRow('Surgeon', surgery['surgeon']),
              _buildDetailRow('Nurses', (surgery['nurses'] as List).join(", ")),
              _buildDetailRow(
                'Technologists',
                (surgery['technologists'] as List).join(", "),
              ),
              if (surgery['notes'] != null && surgery['notes'].isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Notes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(surgery['notes']),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'in progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'canceled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}