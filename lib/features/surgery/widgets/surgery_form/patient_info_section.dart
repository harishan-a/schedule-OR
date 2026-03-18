import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_orscheduler/features/surgery/providers/surgery_form_provider.dart';
import 'package:firebase_orscheduler/core/constants/surgery_constants.dart';
import 'package:firebase_orscheduler/core/utils/validators.dart';

/// Patient information form section (Step 0 of surgery form).
/// Reusable between add and edit surgery screens.
class PatientInfoSection extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController ageController;
  final TextEditingController mrnController;

  const PatientInfoSection({
    super.key,
    required this.nameController,
    required this.ageController,
    required this.mrnController,
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
            'Patient Information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the patient\'s details for the surgery',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),

          // Patient Name
          TextFormField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Patient Name *',
              hintText: 'Enter patient\'s full name',
              prefixIcon: const Icon(Icons.person_outline),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) => Validators.required(value, 'Patient name'),
            onChanged: (value) =>
                formProvider.updatePatientInfo(patientName: value),
          ),
          const SizedBox(height: 16),

          // Age and Gender Row
          Row(
            children: [
              // Patient Age
              Expanded(
                child: TextFormField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Age *',
                    hintText: 'Age',
                    prefixIcon: const Icon(Icons.cake_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Age is required';
                    return Validators.age(value);
                  },
                  onChanged: (value) =>
                      formProvider.updatePatientInfo(patientAge: value),
                ),
              ),
              const SizedBox(width: 16),
              // Gender
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: formProvider.patientGender,
                  decoration: InputDecoration(
                    labelText: 'Gender *',
                    prefixIcon: const Icon(Icons.wc_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: SurgeryConstants.genderOptions.map((gender) {
                    return DropdownMenuItem(value: gender, child: Text(gender));
                  }).toList(),
                  onChanged: (value) =>
                      formProvider.updatePatientInfo(patientGender: value),
                  validator: (value) =>
                      value == null ? 'Gender is required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Medical Record Number
          TextFormField(
            controller: mrnController,
            decoration: InputDecoration(
              labelText: 'Medical Record Number *',
              hintText: 'Enter MRN',
              prefixIcon: const Icon(Icons.badge_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) =>
                Validators.required(value, 'Medical record number'),
            onChanged: (value) =>
                formProvider.updatePatientInfo(medicalRecordNumber: value),
          ),
        ],
      ),
    );
  }
}
