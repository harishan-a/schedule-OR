/// A screen that displays detailed information about a specific surgery.
/// 
/// This screen provides a real-time view of surgery details using Firestore streaming,
/// featuring a modern, clean UI with:
/// - Material Design 3 components and styling
/// - Animated transitions and feedback
/// - Enhanced visual hierarchy and typography
/// - Responsive layout with proper spacing
/// - Card-based content organization with elevation
/// 
/// The screen supports both direct model and Firestore data sources,
/// and includes status update functionality via a floating action button.
library;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SurgeryDetailsScreen extends StatelessWidget {
  final String surgeryId;

  const SurgeryDetailsScreen({
    super.key,
    required this.surgeryId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : colorScheme.surface,
      appBar: AppBar(
        title: const Text('Surgery Details'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Surgery',
            onPressed: () {
              // TODO: Navigate to edit surgery screen
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('surgeries')
            .doc(surgeryId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, 
                    size: 64, 
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading surgery details...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_off_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Surgery not found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The requested surgery details are not available',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Surgery type and status
              Card(
                elevation: 2,
                shadowColor: colorScheme.shadow.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['surgeryType'] ?? 'Unknown Surgery Type',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildStatusChip(data['status'] ?? 'Unknown'),
                      if (data['lastUpdated'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Last updated: ${_formatDateTime(data['lastUpdated'] as Timestamp?)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Time & Location
              _buildCard(
                context,
                title: 'Time & Location',
                icon: Icons.schedule,
                children: [
                  _buildInfoRow(
                    context,
                    icon: Icons.access_time_outlined,
                    label: 'Start Time',
                    value: _formatDateTime(data['startTime'] as Timestamp?),
                  ),
                  _buildInfoRow(
                    context,
                    icon: Icons.timer_outlined,
                    label: 'End Time',
                    value: _formatDateTime(data['endTime'] as Timestamp?),
                  ),
                  _buildInfoRow(
                    context,
                    icon: Icons.room_outlined,
                    label: 'Operating Room',
                    value: data['room'] ?? 'N/A',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Patient Information
              _buildCard(
                context,
                title: 'Patient Information',
                icon: Icons.person_outline,
                children: [
                  _buildInfoRow(
                    context,
                    icon: Icons.badge_outlined,
                    label: 'Medical Record #',
                    value: data['medicalRecordNumber'] ?? 'N/A',
                    isHighlighted: true,
                  ),
                  _buildInfoRow(
                    context,
                    icon: Icons.person_outline,
                    label: 'Name',
                    value: data['patientName'] ?? 'N/A',
                  ),
                  _buildInfoRow(
                    context,
                    icon: Icons.cake_outlined,
                    label: 'Age',
                    value: data['patientAge']?.toString() ?? 'N/A',
                  ),
                  _buildInfoRow(
                    context,
                    icon: Icons.person_outline,
                    label: 'Gender',
                    value: data['patientGender'] ?? 'N/A',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Medical Team
              _buildCard(
                context,
                title: 'Medical Team',
                icon: Icons.medical_services_outlined,
                children: [
                  _buildInfoRow(
                    context,
                    icon: Icons.medical_services_outlined,
                    label: 'Surgeon',
                    value: data['surgeon'] ?? 'N/A',
                    isHighlighted: true,
                  ),
                  _buildStaffList(context, 'Nurses', (data['nurses'] as List?)?.cast<String>() ?? []),
                  _buildStaffList(context, 'Technologists', (data['technologists'] as List?)?.cast<String>() ?? []),
                ],
              ),
              if (data['notes']?.isNotEmpty == true || data['specialRequirements']?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                _buildCard(
                  context,
                  title: 'Additional Information',
                  icon: Icons.info_outline,
                  children: [
                    if (data['notes']?.isNotEmpty == true)
                      _buildInfoRow(
                        context,
                        icon: Icons.note_outlined,
                        label: 'Notes',
                        value: data['notes'],
                      ),
                    if (data['specialRequirements']?.isNotEmpty == true)
                      _buildInfoRow(
                        context,
                        icon: Icons.warning_outlined,
                        label: 'Special Requirements',
                        value: data['specialRequirements'],
                        isHighlighted: true,
                      ),
                  ],
                ),
              ],
              // Bottom padding for FAB
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStatusUpdateDialog(context),
        icon: const Icon(Icons.update_outlined),
        label: const Text('Update Status'),
        elevation: 2,
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      elevation: 1,
      shadowColor: colorScheme.shadow.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(
                color: colorScheme.outlineVariant,
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isHighlighted = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: isHighlighted ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffList(BuildContext context, String title, List<String> staff) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (staff.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No staff assigned',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: staff.map((person) => Chip(
                  avatar: Icon(
                    Icons.person_outline,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  label: Text(
                    person,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  side: BorderSide(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Builder(
      builder: (context) {
        final color = _getStatusColor(status);
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getStatusIcon(status),
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                status,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    return switch (status.toLowerCase()) {
      'scheduled' => Colors.blue,
      'in progress' => Colors.orange,
      'completed' => Colors.green,
      'cancelled' => Colors.red,
      _ => Colors.grey,
    };
  }

  IconData _getStatusIcon(String status) {
    return switch (status.toLowerCase()) {
      'scheduled' => Icons.schedule_outlined,
      'in progress' => Icons.sync_outlined,
      'completed' => Icons.check_circle_outlined,
      'cancelled' => Icons.cancel_outlined,
      _ => Icons.help_outline,
    };
  }

  void _showStatusUpdateDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.update_outlined,
              color: colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text('Update Surgery Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusOption(
              context,
              status: 'Scheduled',
              icon: Icons.schedule_outlined,
              color: Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildStatusOption(
              context,
              status: 'In Progress',
              icon: Icons.sync_outlined,
              color: Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildStatusOption(
              context,
              status: 'Completed',
              icon: Icons.check_circle_outlined,
              color: Colors.green,
            ),
            const SizedBox(height: 8),
            _buildStatusOption(
              context,
              status: 'Cancelled',
              icon: Icons.cancel_outlined,
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(
    BuildContext context, {
    required String status,
    required IconData icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          status,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        tileColor: color.withOpacity(isDark ? 0.12 : 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        onTap: () => _updateStatus(context, status),
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('surgeries')
          .doc(surgeryId)
          .update({
        'status': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text('Status updated to $newStatus'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _getStatusColor(newStatus),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Error updating status: $e'),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    return DateFormat('MMM d, y  h:mm a').format(date);
  }
} 