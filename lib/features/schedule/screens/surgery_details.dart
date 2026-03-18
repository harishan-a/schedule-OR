import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';
import 'package:firebase_orscheduler/features/surgery/screens/edit_surgery.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header with surgery type and status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surgery.surgeryType,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatusChip(context, surgery.status),
                  ],
                ),
              ),

              // Edit button (always show regardless of status)
              FilledButton.tonal(
                onPressed: () {
                  // Close the bottom sheet
                  Navigator.pop(context);

                  // Navigate to edit surgery screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EditSurgeryScreen(surgeryId: surgery.id),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Time & Location Card
          _buildCard(
            context,
            title: 'Time & Location',
            icon: Icons.schedule_outlined,
            children: [
              _buildInfoRow(
                context,
                icon: Icons.access_time_outlined,
                label: 'Start Time',
                value: DateFormat('MMM d, y  h:mm a').format(surgery.startTime),
              ),
              _buildInfoRow(
                context,
                icon: Icons.timer_outlined,
                label: 'End Time',
                value: DateFormat('h:mm a').format(surgery.endTime),
              ),
              _buildInfoRow(
                context,
                icon: Icons.room_outlined,
                label: 'Operating Room',
                value: surgery.room.join(", "),
              ),
              // Add prep and cleanup times if available
              if (surgery.firestoreData.containsKey('prepTimeMinutes') &&
                  (surgery.firestoreData['prepTimeMinutes'] as int?) != null &&
                  (surgery.firestoreData['prepTimeMinutes'] as int) > 0)
                _buildInfoRow(
                  context,
                  icon: Icons.timer_outlined,
                  label: 'Preparation Time',
                  value: '${surgery.firestoreData['prepTimeMinutes']} minutes',
                ),
              if (surgery.firestoreData.containsKey('cleanupTimeMinutes') &&
                  (surgery.firestoreData['cleanupTimeMinutes'] as int?) !=
                      null &&
                  (surgery.firestoreData['cleanupTimeMinutes'] as int) > 0)
                _buildInfoRow(
                  context,
                  icon: Icons.cleaning_services_outlined,
                  label: 'Cleanup Time',
                  value:
                      '${surgery.firestoreData['cleanupTimeMinutes']} minutes',
                ),
              // Display custom time blocks if available
              if (surgery.firestoreData.containsKey('customTimeBlocks') &&
                  (surgery.firestoreData['customTimeBlocks'] as List?)
                          ?.isNotEmpty ==
                      true)
                _buildCustomTimeBlocks(
                    context, surgery.firestoreData['customTimeBlocks'] as List),
            ],
          ),

          const SizedBox(height: 16),

          // Staff Card
          _buildCard(
            context,
            title: 'Medical Team',
            icon: Icons.medical_services_outlined,
            children: [
              _buildInfoRow(
                context,
                icon: Icons.person_outlined,
                label: 'Surgeon',
                value: surgery.surgeon,
                isHighlighted: true,
              ),
              _buildStaffList(context, 'Nurses', surgery.nurses),
              _buildStaffList(context, 'Technologists', surgery.technologists),
            ],
          ),

          // Patient Info Card
          const SizedBox(height: 16),
          _buildCard(
            context,
            title: 'Patient Information',
            icon: Icons.person_outlined,
            children: [
              _buildInfoRow(
                context,
                icon: Icons.badge_outlined,
                label: 'Patient Name',
                value: surgery.patientName,
              ),
              // Add patient gender if available
              if (surgery.firestoreData.containsKey('patientGender') &&
                  surgery.firestoreData['patientGender'] != null)
                _buildInfoRow(
                  context,
                  icon: Icons.person_outlined,
                  label: 'Gender',
                  value: surgery.firestoreData['patientGender'] as String,
                ),
              // Add patient age if available
              if (surgery.firestoreData.containsKey('patientAge') &&
                  surgery.firestoreData['patientAge'] != null)
                _buildInfoRow(
                  context,
                  icon: Icons.cake_outlined,
                  label: 'Age',
                  value: '${surgery.firestoreData['patientAge']}',
                ),
              if (surgery.patientId != null)
                _buildInfoRow(
                  context,
                  icon: Icons.badge_outlined,
                  label: 'Medical Record Number',
                  value: surgery.patientId!,
                ),
            ],
          ),

          // Equipment Card (if available)
          if (surgery.firestoreData.containsKey('requiredEquipment') &&
              (surgery.firestoreData['requiredEquipment'] as List?)
                      ?.isNotEmpty ==
                  true) ...[
            const SizedBox(height: 16),
            _buildCard(
              context,
              title: 'Required Equipment',
              icon: Icons.medical_services_outlined,
              children: [
                _buildEquipmentList(
                  context,
                  surgery.firestoreData['requiredEquipment'] as List<dynamic>,
                  surgery.firestoreData['equipmentRequirements']
                      as List<dynamic>?,
                ),
              ],
            ),
          ],

          // Notes (if present)
          if (surgery.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildCard(
              context,
              title: 'Notes',
              icon: Icons.note_outlined,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    surgery.notes,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          height: 1.5,
                        ),
                  ),
                ),
              ],
            ),
          ],

          // Safe area at bottom
          const SizedBox(height: 20),
        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(
                color: colorScheme.outlineVariant.withOpacity(0.5),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: isHighlighted
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
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
                        fontWeight:
                            isHighlighted ? FontWeight.bold : FontWeight.normal,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight:
                            isHighlighted ? FontWeight.w600 : FontWeight.normal,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffList(
      BuildContext context, String title, List<String> staff) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          if (staff.isEmpty)
            Text(
              'None assigned',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                    fontStyle: FontStyle.italic,
                  ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: staff
                  .map((person) => Chip(
                        avatar: Icon(
                          Icons.person_outline,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        label: Text(
                          person,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface,
                                  ),
                        ),
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        side: BorderSide(
                          color: colorScheme.outline.withOpacity(0.2),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 0),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    final color = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1,
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
          const SizedBox(width: 6),
          Text(
            status,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
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

  /// Builds a display of custom time blocks
  Widget _buildCustomTimeBlocks(BuildContext context, List timeBlocks) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Custom Time Blocks',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: timeBlocks.map<Widget>((block) {
            final name = block['name'] ?? 'Custom Block';
            final duration = block['durationMinutes']?.toString() ?? '0';

            return Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$name: $duration minutes',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Builds a list of required equipment
  Widget _buildEquipmentList(BuildContext context, List<dynamic> equipmentIds,
      List<dynamic>? requirements) {
    final colorScheme = Theme.of(context).colorScheme;

    // Get equipment name mapping
    final equipmentMap = _getEquipmentNameMap();

    // Try to match requirements with IDs if available
    Map<String, Map<String, dynamic>> equipmentDetails = {};
    if (requirements != null) {
      for (var req in requirements) {
        if (req is Map &&
            req.containsKey('equipmentId') &&
            req.containsKey('equipmentName')) {
          equipmentDetails[req['equipmentId'].toString()] =
              Map<String, dynamic>.from(req as Map);
        }
      }
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: equipmentIds.map<Widget>((id) {
        // Get name from equipment details if available
        String displayName = id.toString();
        bool isRequired = true;

        // First try to get name from the equipment map
        if (equipmentMap.containsKey(id)) {
          displayName = equipmentMap[id]!;
        }
        // If not found, try to get from equipment details
        else if (equipmentDetails.containsKey(id.toString())) {
          final details = equipmentDetails[id.toString()]!;
          displayName = details['equipmentName'] ?? id.toString();
          isRequired = details['isRequired'] ?? true;
        }

        return Chip(
          avatar: Icon(
            Icons.medical_services_outlined,
            size: 16,
            color:
                isRequired ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          label: Text(
            displayName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: isRequired ? FontWeight.bold : FontWeight.normal,
                ),
          ),
          backgroundColor: isRequired
              ? colorScheme.primaryContainer.withOpacity(0.5)
              : colorScheme.surfaceContainerHighest,
          side: BorderSide(
            color: isRequired
                ? colorScheme.primary.withOpacity(0.5)
                : colorScheme.outline.withOpacity(0.2),
          ),
        );
      }).toList(),
    );
  }

  /// Returns a mapping of equipment IDs to their human-readable names
  Map<String, String> _getEquipmentNameMap() {
    return {
      'E001': 'Anesthesia Machine',
      'E002': 'Patient Monitor',
      'E003': 'Surgical Table',
      'E004': 'Defibrillator',
      'E005': 'Surgical Lights',
      'E006': 'Electrosurgical Unit',
      'E007': 'Suction Machine',
      'E008': 'Ultrasound Machine',
      'E009': 'Surgical Microscope',
      'E010': 'Surgical Robot',
    };
  }
}
