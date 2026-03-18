import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_orscheduler/features/surgery/providers/surgery_form_provider.dart';

/// Time selection form section (Step 2 of surgery form).
class TimeSelectionSection extends StatelessWidget {
  const TimeSelectionSection({super.key});

  @override
  Widget build(BuildContext context) {
    final formProvider = Provider.of<SurgeryFormProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Time Selection',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set the surgery schedule and preparation times',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),

          // Start Time
          _buildTimePicker(
            context,
            label: 'Start Time',
            icon: Icons.play_arrow_outlined,
            dateTime: formProvider.startTime,
            onDateChanged: (date) {
              final newStart = DateTime(
                date.year,
                date.month,
                date.day,
                formProvider.startTime.hour,
                formProvider.startTime.minute,
              );
              formProvider.updateTimeInfo(startTime: newStart);
            },
            onTimeChanged: (time) {
              final newStart = DateTime(
                formProvider.startTime.year,
                formProvider.startTime.month,
                formProvider.startTime.day,
                time.hour,
                time.minute,
              );
              formProvider.updateTimeInfo(startTime: newStart);
            },
          ),
          const SizedBox(height: 16),

          // End Time
          _buildTimePicker(
            context,
            label: 'End Time',
            icon: Icons.stop_outlined,
            dateTime: formProvider.endTime,
            onDateChanged: (date) {
              final newEnd = DateTime(
                date.year,
                date.month,
                date.day,
                formProvider.endTime.hour,
                formProvider.endTime.minute,
              );
              formProvider.updateTimeInfo(endTime: newEnd);
            },
            onTimeChanged: (time) {
              final newEnd = DateTime(
                formProvider.endTime.year,
                formProvider.endTime.month,
                formProvider.endTime.day,
                time.hour,
                time.minute,
              );
              formProvider.updateTimeInfo(endTime: newEnd);
            },
          ),
          const SizedBox(height: 24),

          // Duration Display
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Duration: ${formProvider.surgeryDuration} minutes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Prep Time
          _buildDurationField(
            context,
            label: 'Prep Time (minutes)',
            icon: Icons.hourglass_top,
            value: formProvider.prepTimeMinutes,
            onChanged: (value) =>
                formProvider.updateTimeInfo(prepTimeMinutes: value),
          ),
          const SizedBox(height: 12),

          // Cleanup Time
          _buildDurationField(
            context,
            label: 'Cleanup Time (minutes)',
            icon: Icons.hourglass_bottom,
            value: formProvider.cleanupTimeMinutes,
            onChanged: (value) =>
                formProvider.updateTimeInfo(cleanupTimeMinutes: value),
          ),
          const SizedBox(height: 16),

          // Total Duration
          Card(
            color: colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: colorScheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Text(
                    'Total: ${formProvider.totalDuration} minutes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker(
    BuildContext context, {
    required String label,
    required IconData icon,
    required DateTime dateTime,
    required ValueChanged<DateTime> onDateChanged,
    required ValueChanged<TimeOfDay> onTimeChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(label, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: dateTime,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) onDateChanged(date);
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(DateFormat('MMM dd, yyyy').format(dateTime)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(dateTime),
                      );
                      if (time != null) onTimeChanged(time);
                    },
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(DateFormat('hh:mm a').format(dateTime)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationField(
    BuildContext context, {
    required String label,
    required IconData icon,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: value > 0 ? () => onChanged(value - 5) : null,
              iconSize: 20,
            ),
            SizedBox(
              width: 40,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => onChanged(value + 5),
              iconSize: 20,
            ),
          ],
        ),
      ],
    );
  }
}
