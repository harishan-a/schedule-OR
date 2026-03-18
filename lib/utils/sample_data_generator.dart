import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SampleDataGenerator {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Adds sample surgeries to Firestore in a single batch operation
  static Future<void> addSampleSurgeries({int count = 20}) async {
    final batch = _firestore.batch();
    final surgeryRef = _firestore.collection('surgeries');

    // Surgery types from app
    final surgeryTypes = [
      'Cardiac Surgery',
      'Orthopedic Surgery',
      'Neurosurgery',
      'General Surgery',
      'Plastic Surgery'
    ];

    // Room names from app
    final rooms = [
      'OperatingRoom1',
      'OperatingRoom2',
      'OperatingRoom3',
      'OperatingRoom4',
      'OperatingRoom5'
    ];
    final roomIds = ['room1', 'room2', 'room3', 'room4', 'room5'];

    // Diverse surgeon names
    final surgeons = [
      'Dr. Sarah Patel',
      'Dr. James Wilson',
      'Dr. Maria Rodriguez',
      'Dr. David Kim',
      'Dr. Aisha Johnson',
      'Dr. Michael Chen',
      'Dr. Olivia Williams'
    ];

    final doctorIds = ['doc1', 'doc2', 'doc3', 'doc4', 'doc5', 'doc6', 'doc7'];

    final patientNames = [
      'Ahmed Hassan',
      'Jessica Wong',
      'Carlos Mendez',
      'Priya Sharma',
      'Jamal Washington',
      'Sofia Gonzalez',
      'Wei Zhang',
      'Elena Petrov',
      'Omar Abdullah',
      'Fatima Ahmed',
      'Raj Patel',
      'Nguyen Tran'
    ];

    final nurses = [
      'Nurse Maya Johnson',
      'Nurse Robert Chen',
      'Nurse Isabella Garcia',
      'Nurse Kwame Osei',
      'Nurse Leila Chaudry',
      'Nurse Thomas Brooks',
      'Nurse Yuki Tanaka'
    ];

    final technologists = [
      'Tech Alex Rivera',
      'Tech Sanjay Gupta',
      'Tech Min-Ji Park',
      'Tech Amir Khoury',
      'Tech Zoe Anderson',
      'Tech Marcus Johnson'
    ];

    final statuses = ['Scheduled', 'In Progress', 'Completed'];

    // Resource booking tracker to prevent conflicts
    Map<String, List<Map<String, dynamic>>> resourceBookings = {
      'rooms': [],
      'surgeons': [],
      'nurses': [],
      'technologists': [],
    };

    // Generate random surgeries with conflict avoidance
    for (int i = 0; i < count; i++) {
      // Assign day and hour
      final now = DateTime.now();
      final day = (i ~/ 5) + 1; // Distribute 5 surgeries per day
      final baseHour = 8 + (i % 5) * 2; // Starting at 8 AM, 2-hour slots

      final surgeryDate =
          DateTime(now.year, now.month, now.day + day, baseHour);
      final duration = [45, 60, 90, 120][i % 4]; // Different durations
      final endTime = surgeryDate.add(Duration(minutes: duration));

      // Pick resources without conflicts
      final roomIndex = i % rooms.length;
      final room = rooms[roomIndex];
      final roomId = roomIds[roomIndex];

      // Pick surgeon based on availability
      final surgeonIndex = i % surgeons.length;
      final surgeon = surgeons[surgeonIndex];
      final doctorId = doctorIds[surgeonIndex];

      // Pick patient
      final patientName = patientNames[i % patientNames.length];
      final patientId = 'MRN${100000 + i}';

      // Status based on date
      final statusIndex = surgeryDate.isBefore(now)
          ? 2
          : surgeryDate.day == now.day
              ? 1
              : 0;
      final status = statuses[statusIndex];

      // Get available nurses (different for each surgery to avoid conflicts)
      final nurseOffset = (i * 2) % nurses.length;
      final randomNurses = [
        nurses[nurseOffset % nurses.length],
        nurses[(nurseOffset + 1) % nurses.length]
      ];

      // Get available technologist
      final techOffset = i % technologists.length;
      final randomTechs = [technologists[techOffset]];

      // Generate notes
      final notesOptions = [
        'Patient has penicillin allergy',
        'Patient requires interpreter',
        'History of cardiac issues',
        'Follow-up appointment needed',
        'Previous surgery in 2022',
        '',
        'Patient prefers morning appointments',
        'Diabetic patient - monitor glucose'
      ];
      final notes = notesOptions[i % notesOptions.length];

      // Create surgery data map
      final surgeryData = {
        'patientName': patientName,
        'patientId': patientId,
        'surgeryType': surgeryTypes[i % surgeryTypes.length],
        'doctorId': doctorId,
        'surgeon': surgeon,
        'dateTime': Timestamp.fromDate(surgeryDate),
        'startTime': Timestamp.fromDate(surgeryDate),
        'endTime': Timestamp.fromDate(endTime),
        'roomId': roomId,
        'room': [room],
        'duration': duration,
        'status': status,
        'type': surgeryTypes[i % surgeryTypes.length],
        'notes': notes,
        'nurses': randomNurses,
        'technologists': randomTechs,
        'created': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Add to batch
      batch.set(surgeryRef.doc(), surgeryData);
    }

    // Commit the batch
    return batch.commit();
  }

  /// Deletes all sample surgeries - USE WITH CAUTION
  static Future<void> clearAllSurgeries() async {
    final snapshot = await _firestore.collection('surgeries').get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    return batch.commit();
  }
}
