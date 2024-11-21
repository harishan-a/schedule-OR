import 'package:firebase_orscheduler/screens/schedule.dart';
import 'package:firebase_orscheduler/utils/schedule/schedule_view_week.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'surgery_details.dart';

class TVViewContent extends StatefulWidget {
  final List<Surgery> surgeries;

  const TVViewContent({super.key, required this.surgeries});

  @override
  _TVViewContentState createState() => _TVViewContentState();
}

class _TVViewContentState extends State<TVViewContent> {
  @override
  void initState() {
    super.initState();
    // Set the preferred orientations to landscape mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  @override
  void dispose() {
    // Reset the preferred orientations to allow both portrait and landscape modes
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todaySurgeries = _getTodaySurgeries();
    final inProgressSurgeries = _getInProgressSurgeries();
    final upcomingSurgeries = _getUpcomingSurgeries();

    return Row(
      children: [
        // Main Calendar View (2/3 of screen)
        Expanded(
          flex: 2,
          child: WeekViewContent(surgeries: widget.surgeries),
        ),
        // Right panel with current and upcoming surgeries (1/3 of screen)
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                left: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              children: [
                _buildTVSection(
                  'In Progress',
                  inProgressSurgeries,
                  headerColor: Colors.orange,
                ),
                _buildTVSection(
                  'Up Next',
                  upcomingSurgeries.take(3).toList(),
                  headerColor: Colors.blue,
                ),
                Expanded(
                  child: _buildTVSection(
                    'Today\'s Schedule',
                    todaySurgeries,
                    headerColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTVSection(
    String title,
    List<Surgery> surgeries, {
    required Color headerColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: headerColor,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: surgeries.length,
            itemBuilder: (context, index) {
              final surgery = surgeries[index];
              return TVSurgeryCard(surgery: surgery);
            },
          ),
        ),
      ],
    );
  }

  List<Surgery> _getTodaySurgeries() {
    final now = DateTime.now();
    return widget.surgeries.where((surgery) {
      return surgery.startTime.year == now.year &&
          surgery.startTime.month == now.month &&
          surgery.startTime.day == now.day;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<Surgery> _getInProgressSurgeries() {
    return widget.surgeries
        .where((surgery) => surgery.status.toLowerCase() == 'in progress')
        .toList();
  }

  List<Surgery> _getUpcomingSurgeries() {
    final now = DateTime.now();
    return widget.surgeries
        .where((surgery) => 
            surgery.startTime.isAfter(now) &&
            surgery.status.toLowerCase() == 'scheduled')
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }
}

class TVSurgeryCard extends StatelessWidget {
  final Surgery surgery;

  const TVSurgeryCard({super.key, required this.surgery});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showSurgeryDetails(context, surgery),
      child: Card(
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      surgery.surgeryType,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(surgery.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      surgery.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${DateFormat('h:mm a').format(surgery.startTime)} - '
                    '${DateFormat('h:mm a').format(surgery.endTime)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.room, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Room ${surgery.room.join(", ")}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Dr. ${surgery.surgeon}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSurgeryDetails(BuildContext context, Surgery surgery) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, controller) => SurgeryDetails(
          surgery: surgery,
          scrollController: controller,
        ),
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
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}