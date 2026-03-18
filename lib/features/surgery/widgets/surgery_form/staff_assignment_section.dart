import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:firebase_orscheduler/features/surgery/providers/surgery_form_provider.dart';

/// Staff assignment form section (Step 3 of surgery form).
class StaffAssignmentSection extends StatelessWidget {
  final List<String> doctors;
  final List<String> nurses;
  final List<String> technologists;

  const StaffAssignmentSection({
    super.key,
    required this.doctors,
    required this.nurses,
    required this.technologists,
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
            'Staff Assignment',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Assign the surgical team',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),

          // Surgeon Selection
          DropdownSearch<String>(
            popupProps: const PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  hintText: 'Search for a surgeon...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            items: doctors,
            selectedItem: formProvider.selectedDoctor,
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                labelText: 'Surgeon *',
                prefixIcon: const Icon(Icons.person_outline),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            onChanged: (value) =>
                formProvider.updateStaffAssignments(selectedDoctor: value),
            validator: (value) => value == null ? 'Surgeon is required' : null,
          ),
          const SizedBox(height: 16),

          // Nurses Multi-Select
          MultiSelectDialogField<String>(
            items: nurses.map((n) => MultiSelectItem(n, n)).toList(),
            initialValue: formProvider.selectedNurses,
            title: const Text('Select Nurses'),
            selectedColor: colorScheme.primary,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline),
            ),
            buttonIcon: const Icon(Icons.people_outline),
            buttonText: Text(
              formProvider.selectedNurses.isEmpty
                  ? 'Select Nurses *'
                  : '${formProvider.selectedNurses.length} nurse(s) selected',
              style: TextStyle(
                color: formProvider.selectedNurses.isEmpty
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurface,
              ),
            ),
            onConfirm: (values) {
              formProvider.updateStaffAssignments(selectedNurses: values);
            },
            chipDisplay: MultiSelectChipDisplay(
              onTap: (value) {
                final updated = List<String>.from(formProvider.selectedNurses)
                  ..remove(value);
                formProvider.updateStaffAssignments(selectedNurses: updated);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Technologist Selection
          DropdownSearch<String>(
            popupProps: const PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  hintText: 'Search for a technologist...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            items: technologists,
            selectedItem: formProvider.selectedTechnologist,
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                labelText: 'Technologist',
                prefixIcon: const Icon(Icons.engineering_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            onChanged: (value) => formProvider.updateStaffAssignments(
                selectedTechnologist: value),
          ),
        ],
      ),
    );
  }
}
