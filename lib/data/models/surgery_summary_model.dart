import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a surgery summary for dashboard display.
/// Enhanced from original with copyWith, toString, equality (fixes TODO).
class SurgerySummary {
  final String id;
  final String surgeryType;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final String room;
  final String surgeon;
  final List<String> nurses;
  final List<String> technologists;
  final String notes;

  const SurgerySummary({
    required this.id,
    required this.surgeryType,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.room,
    required this.surgeon,
    required this.nurses,
    required this.technologists,
    required this.notes,
  });

  factory SurgerySummary.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SurgerySummary(
      id: doc.id,
      surgeryType: data['surgeryType'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      status: data['status'] ?? 'Scheduled',
      room: data['room'] is List
          ? (data['room'] as List).join(', ')
          : data['room']?.toString() ?? '',
      surgeon: data['surgeon'] ?? '',
      nurses: List<String>.from(data['nurses'] ?? []),
      technologists: List<String>.from(data['technologists'] ?? []),
      notes: data['notes'] ?? '',
    );
  }

  /// Creates a copy with modified fields (was TODO)
  SurgerySummary copyWith({
    String? id,
    String? surgeryType,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    String? room,
    String? surgeon,
    List<String>? nurses,
    List<String>? technologists,
    String? notes,
  }) {
    return SurgerySummary(
      id: id ?? this.id,
      surgeryType: surgeryType ?? this.surgeryType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      room: room ?? this.room,
      surgeon: surgeon ?? this.surgeon,
      nurses: nurses ?? this.nurses,
      technologists: technologists ?? this.technologists,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'SurgerySummary(id: $id, surgeryType: $surgeryType, '
        'status: $status, surgeon: $surgeon, '
        'startTime: $startTime, endTime: $endTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SurgerySummary && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
