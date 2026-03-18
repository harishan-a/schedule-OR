import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'dart:convert';

/// Utility class for processing CSV data for bulk surgery import
class CsvDataProcessor {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// CSV column headers expected in the import file
  static const List<String> expectedHeaders = [
    'patient_name',
    'patient_id',
    'surgery_type',
    'doctor_id',
    'surgeon',
    'start_time',
    'duration',
    'room_id',
    'room',
    'status',
    'notes',
    'nurses',
    'technologists'
  ];

  /// Parse a CSV string into a list of maps representing surgeries
  ///
  /// Returns a map containing:
  /// - 'data': List of valid surgery data maps
  /// - 'errors': List of maps with error details for invalid rows
  /// - 'headers': The headers found in the CSV
  static Future<Map<String, dynamic>> parseAndValidateCsv(
      String csvString) async {
    try {
      // Parse CSV
      final List<List<dynamic>> rowsAsListOfValues =
          const CsvToListConverter().convert(csvString);

      // Extract headers and validate
      if (rowsAsListOfValues.isEmpty) {
        return {
          'data': <Map<String, dynamic>>[],
          'errors': [
            {'row': 0, 'error': 'CSV file is empty'}
          ],
          'headers': <String>[]
        };
      }

      final headers =
          rowsAsListOfValues[0].map((e) => e.toString().trim()).toList();

      // Validate headers
      final missingHeaders =
          expectedHeaders.where((h) => !headers.contains(h)).toList();
      if (missingHeaders.isNotEmpty) {
        return {
          'data': <Map<String, dynamic>>[],
          'errors': [
            {
              'row': 0,
              'error': 'Missing required headers: ${missingHeaders.join(", ")}'
            }
          ],
          'headers': headers
        };
      }

      final validData = <Map<String, dynamic>>[];
      final errors = <Map<String, dynamic>>[];

      // Process each row
      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        final row = rowsAsListOfValues[i];

        // Skip empty rows
        if (row.isEmpty ||
            (row.length == 1 && row[0].toString().trim().isEmpty)) {
          continue;
        }

        // Ensure row has enough columns
        if (row.length < headers.length) {
          errors.add({
            'row': i,
            'error':
                'Row has insufficient columns (found ${row.length}, expected ${headers.length})'
          });
          continue;
        }

        // Convert row to map
        final Map<String, dynamic> rowData = {};
        for (int j = 0; j < headers.length; j++) {
          rowData[headers[j]] = row[j];
        }

        // Validate required fields
        final validationResult = _validateRow(rowData, i);
        if (validationResult['isValid']) {
          validData.add(validationResult['data']);
        } else {
          errors.add(
              {'row': i, 'error': validationResult['error'], 'data': rowData});
        }
      }

      return {'data': validData, 'errors': errors, 'headers': headers};
    } catch (e) {
      return {
        'data': <Map<String, dynamic>>[],
        'errors': [
          {'row': 0, 'error': 'Error parsing CSV: ${e.toString()}'}
        ],
        'headers': <String>[]
      };
    }
  }

  /// Validates a row of data and formats it for Firestore
  ///
  /// Returns a map with:
  /// - 'isValid': Boolean indicating if the row is valid
  /// - 'data': Formatted data map if valid
  /// - 'error': Error message if invalid
  static Map<String, dynamic> _validateRow(
      Map<String, dynamic> row, int rowIndex) {
    // Required fields validation
    final requiredFields = [
      'patient_name',
      'surgery_type',
      'start_time',
      'duration',
      'room'
    ];
    for (final field in requiredFields) {
      if (row[field] == null || row[field].toString().trim().isEmpty) {
        return {
          'isValid': false,
          'error': 'Missing required field: $field',
          'data': null
        };
      }
    }

    // Parse and validate date
    DateTime? startTime;
    try {
      startTime = DateTime.parse(row['start_time'].toString());
    } catch (e) {
      return {
        'isValid': false,
        'error': 'Invalid date format for start_time: ${row['start_time']}',
        'data': null
      };
    }

    // Parse and validate duration
    int? duration;
    try {
      duration = int.parse(row['duration'].toString());
      if (duration <= 0) throw Exception('Duration must be positive');
    } catch (e) {
      return {
        'isValid': false,
        'error': 'Invalid duration: ${row['duration']}',
        'data': null
      };
    }

    // Calculate end time
    final endTime = startTime.add(Duration(minutes: duration));

    // Parse multi-value fields
    List<String> nurses = [];
    if (row['nurses'] != null && row['nurses'].toString().isNotEmpty) {
      nurses =
          row['nurses'].toString().split('|').map((e) => e.trim()).toList();
    }

    List<String> technologists = [];
    if (row['technologists'] != null &&
        row['technologists'].toString().isNotEmpty) {
      technologists = row['technologists']
          .toString()
          .split('|')
          .map((e) => e.trim())
          .toList();
    }

    List<String> roomList = [];
    if (row['room'] != null && row['room'].toString().isNotEmpty) {
      roomList =
          row['room'].toString().split('|').map((e) => e.trim()).toList();
    }

    // Create formatted data for Firestore
    final formattedData = {
      'patientName': row['patient_name'].toString(),
      'patientId': row['patient_id']?.toString() ?? '',
      'surgeryType': row['surgery_type'].toString(),
      'doctorId': row['doctor_id']?.toString() ?? '',
      'surgeon': row['surgeon']?.toString() ?? '',
      'dateTime': Timestamp.fromDate(startTime),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'roomId': row['room_id']?.toString() ?? '',
      'room': roomList,
      'duration': duration,
      'status': row['status']?.toString() ?? 'Scheduled',
      'type': row['surgery_type'].toString(),
      'notes': row['notes']?.toString() ?? '',
      'nurses': nurses,
      'technologists': technologists,
      'created': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    return {'isValid': true, 'data': formattedData, 'error': null};
  }

  /// Checks for scheduling conflicts with existing surgeries
  ///
  /// Returns a map with conflict details for any conflicts found
  static Future<List<Map<String, dynamic>>> checkSchedulingConflicts(
      List<Map<String, dynamic>> surgeries) async {
    final conflicts = <Map<String, dynamic>>[];

    // Group surgeries by date to reduce query count
    final Map<String, List<Map<String, dynamic>>> surgeryByDate = {};

    for (final surgery in surgeries) {
      final startTime = (surgery['startTime'] as Timestamp).toDate();
      final dateKey = '${startTime.year}-${startTime.month}-${startTime.day}';

      if (!surgeryByDate.containsKey(dateKey)) {
        surgeryByDate[dateKey] = [];
      }

      surgeryByDate[dateKey]!.add(surgery);
    }

    // Check conflicts for each date
    for (final entry in surgeryByDate.entries) {
      final dateString = entry.key;
      final dateSurgeries = entry.value;

      // Parse date components
      final parts = dateString.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      // Get start of day and end of day
      final startOfDay = DateTime(year, month, day);
      final endOfDay = DateTime(year, month, day, 23, 59, 59);

      // Query existing surgeries for this date
      final existingSurgeriesQuery = await _firestore
          .collection('surgeries')
          .where('startTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      final existingSurgeries = existingSurgeriesQuery.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // Check each new surgery against existing ones
      for (final newSurgery in dateSurgeries) {
        final newStart = (newSurgery['startTime'] as Timestamp).toDate();
        final newEnd = (newSurgery['endTime'] as Timestamp).toDate();
        final newRoomId = newSurgery['roomId'];
        final newSurgeon = newSurgery['surgeon'];

        for (final existingSurgery in existingSurgeries) {
          final existingStart =
              (existingSurgery['startTime'] as Timestamp).toDate();
          final existingEnd =
              (existingSurgery['endTime'] as Timestamp).toDate();

          // Check for time overlap
          final hasTimeOverlap =
              (newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart));

          if (hasTimeOverlap) {
            // Check for resource conflicts
            final sameRoom = newRoomId == existingSurgery['roomId'];
            final sameSurgeon = newSurgeon == existingSurgery['surgeon'];

            // Check for nurse or technologist overlap
            final newNurses = List<String>.from(newSurgery['nurses']);
            final existingNurses = List<String>.from(existingSurgery['nurses']);
            final hasNurseOverlap =
                newNurses.any((nurse) => existingNurses.contains(nurse));

            final newTechs = List<String>.from(newSurgery['technologists']);
            final existingTechs =
                List<String>.from(existingSurgery['technologists']);
            final hasTechOverlap =
                newTechs.any((tech) => existingTechs.contains(tech));

            if (sameRoom || sameSurgeon || hasNurseOverlap || hasTechOverlap) {
              conflicts.add({
                'surgery': newSurgery,
                'conflictWith': existingSurgery,
                'reason': [
                  if (sameRoom) 'Same room',
                  if (sameSurgeon) 'Same surgeon',
                  if (hasNurseOverlap) 'Nurse overlap',
                  if (hasTechOverlap) 'Technologist overlap',
                ].join(', ')
              });

              // No need to check further conflicts for this surgery
              break;
            }
          }
        }
      }
    }

    return conflicts;
  }

  /// Imports validated surgery data to Firestore using batch operations
  ///
  /// Returns a map with success and error counts
  static Future<Map<String, dynamic>> importSurgeries(
      List<Map<String, dynamic>> surgeries) async {
    int successCount = 0;
    final errors = <Map<String, dynamic>>[];

    // Process in batches of 500 (Firestore batch limit)
    final int batchSize = 500;

    for (int i = 0; i < surgeries.length; i += batchSize) {
      final int end =
          (i + batchSize < surgeries.length) ? i + batchSize : surgeries.length;
      final batch = _firestore.batch();

      for (int j = i; j < end; j++) {
        try {
          final surgeryRef = _firestore.collection('surgeries').doc();
          batch.set(surgeryRef, surgeries[j]);
          successCount++;
        } catch (e) {
          errors.add({'index': j, 'error': e.toString(), 'data': surgeries[j]});
        }
      }

      try {
        await batch.commit();
      } catch (e) {
        // If batch commit fails, mark all as failed
        successCount -= (end - i);
        for (int j = i; j < end; j++) {
          errors.add({
            'index': j,
            'error': 'Batch commit failed: ${e.toString()}',
            'data': surgeries[j]
          });
        }
      }
    }

    return {
      'success': successCount,
      'errors': errors,
      'total': surgeries.length
    };
  }
}
