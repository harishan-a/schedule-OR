import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';

class SurgeryDetails extends StatelessWidget {
  final Surgery surgery;
  final ScrollController scrollController;

  const SurgeryDetails({
    super.key,
    required this.surgery,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            surgery.surgeryType,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          _buildStatusChip(surgery.status),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Time & Location',
            children: [
              _buildInfoRow(
                icon: Icons.access_time,
                label: 'Start Time',
                value: DateFormat('MMM d, y  h:mm a').format(surgery.startTime),
              ),
              _buildInfoRow(
                icon: Icons.timer,
                label: 'End Time',
                value: DateFormat('h:mm a').format(surgery.endTime),
              ),
              _buildInfoRow(
                icon: Icons.room,
                label: 'Operating Room',
                value: surgery.room.join(", "),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Staff',
            children: [
              _buildInfoRow(
                icon: Icons.person,
                label: 'Surgeon',
                value: surgery.surgeon,
              ),
              _buildStaffList('Nurses', surgery.nurses),
              _buildStaffList('Technologists', surgery.technologists),
            ],
          ),
          if (surgery.notes.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSection(
              title: 'Notes',
              children: [
                Text(surgery.notes),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffList(String title, List<String> staff) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: staff.map((person) => Chip(
              label: Text(person),
              backgroundColor: Colors.grey[200],
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
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
