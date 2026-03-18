class EquipmentConstants {
  EquipmentConstants._();

  static const Map<String, String> equipmentNameMap = {
    'eq1': 'Surgical Robot',
    'eq2': 'Anesthesia Machine',
    'eq3': 'Patient Monitor',
    'eq4': 'Electrosurgical Unit',
    'eq5': 'Surgical Lights',
    'eq6': 'Ventilator',
    'eq7': 'Defibrillator',
    'eq8': 'Infusion Pump',
    'eq9': 'Suction Machine',
    'eq10': 'Ultrasound Machine',
  };

  static const List<String> equipmentCategories = [
    'Imaging',
    'Monitoring',
    'Surgical',
    'Anesthesia',
    'Support',
  ];

  static String getEquipmentName(String equipmentId) {
    return equipmentNameMap[equipmentId] ?? equipmentId;
  }
}
