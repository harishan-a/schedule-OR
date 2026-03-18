import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_orscheduler/features/surgery/providers/surgery_form_provider.dart';
import 'package:firebase_orscheduler/core/constants/surgery_constants.dart';

/// Surgery information form section (Step 1 of surgery form).
class SurgeryInfoSection extends StatelessWidget {
  final TextEditingController notesController;

  const SurgeryInfoSection({
    super.key,
    required this.notesController,
  });

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
            'Surgery Details',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the type of surgery and operating room',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),

          // Surgery Type
          DropdownButtonFormField<String>(
            value: formProvider.surgeryType,
            decoration: InputDecoration(
              labelText: 'Surgery Type *',
              prefixIcon: const Icon(Icons.medical_services_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: SurgeryConstants.surgeryTypes.map((type) {
              return DropdownMenuItem(value: type, child: Text(type));
            }).toList(),
            onChanged: (value) =>
                formProvider.updateSurgeryDetails(surgeryType: value),
            validator: (value) =>
                value == null ? 'Surgery type is required' : null,
          ),
          const SizedBox(height: 16),

          // Operating Room
          DropdownButtonFormField<String>(
            value: formProvider.operatingRoom,
            decoration: InputDecoration(
              labelText: 'Operating Room *',
              prefixIcon: const Icon(Icons.room_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: SurgeryConstants.operatingRooms.map((room) {
              return DropdownMenuItem(value: room, child: Text(room));
            }).toList(),
            onChanged: (value) =>
                formProvider.updateSurgeryDetails(operatingRoom: value),
            validator: (value) =>
                value == null ? 'Operating room is required' : null,
          ),
          const SizedBox(height: 16),

          // Notes
          TextFormField(
            controller: notesController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Notes',
              hintText: 'Enter any additional notes...',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: Icon(Icons.note_outlined),
              ),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (value) =>
                formProvider.updateSurgeryDetails(notes: value),
          ),
        ],
      ),
    );
  }
}
