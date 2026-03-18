import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_orscheduler/features/surgery/providers/surgery_form_provider.dart';
import 'package:firebase_orscheduler/features/equipment/repositories/equipment_repository.dart';
import 'package:firebase_orscheduler/features/equipment/models/equipment.dart';

/// Equipment selection form section (Step 4 of surgery form).
class EquipmentSection extends StatefulWidget {
  const EquipmentSection({super.key});

  @override
  State<EquipmentSection> createState() => _EquipmentSectionState();
}

class _EquipmentSectionState extends State<EquipmentSection> {
  final EquipmentRepository _equipmentRepository = EquipmentRepository();
  List<Equipment> _availableEquipment = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEquipment();
  }

  Future<void> _loadEquipment() async {
    try {
      final equipment = await _equipmentRepository.getAllEquipment();
      if (mounted) {
        setState(() {
          _availableEquipment = equipment;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formProvider = Provider.of<SurgeryFormProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Equipment Selection',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select equipment needed for the surgery (optional)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          if (_availableEquipment.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 48, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text('No equipment available',
                      style: TextStyle(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          else
            ..._availableEquipment.map((equipment) {
              final isSelected =
                  formProvider.selectedEquipmentIds.contains(equipment.id);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isSelected
                      ? BorderSide(color: colorScheme.primary, width: 2)
                      : BorderSide.none,
                ),
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: (checked) {
                    final ids =
                        Set<String>.from(formProvider.selectedEquipmentIds);
                    final required =
                        Map<String, bool>.from(formProvider.requiredEquipment);
                    if (checked == true) {
                      ids.add(equipment.id);
                      required[equipment.id] = false;
                    } else {
                      ids.remove(equipment.id);
                      required.remove(equipment.id);
                    }
                    formProvider.updateEquipmentSelections(ids, required);
                  },
                  title: Text(equipment.name),
                  subtitle: Text(
                    '${equipment.category} \u2022 ${equipment.isAvailable ? "Available" : "Unavailable"}',
                    style: TextStyle(
                      color: equipment.isAvailable
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.error,
                    ),
                  ),
                  secondary: Icon(
                    Icons.medical_services,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            }),
        ],
      ),
    );
  }
}
