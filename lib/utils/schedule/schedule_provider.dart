
import 'package:firebase_orscheduler/screens/schedule.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SurgeryProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Future<void> addSurgery(Surgery surgery) async {
    try {
      await _firestore.collection('surgeries').add({
        'surgeryType': surgery.surgeryType,
        'room': surgery.room,
        'startTime': surgery.startTime,
        'endTime': surgery.endTime,
        'status': surgery.status,
        'surgeon': surgery.surgeon,
        'nurses': surgery.nurses,
        'technologists': surgery.technologists,
        'notes': surgery.notes,
      });
    } catch (e) {
      debugPrint('Error adding surgery: $e');
      rethrow;
    }
  }

  Future<void> updateSurgeryStatus(String surgeryId, String newStatus) async {
    try {
      await _firestore.collection('surgeries').doc(surgeryId).update({
        'status': newStatus,
      });
    } catch (e) {
      debugPrint('Error updating surgery status: $e');
      rethrow;
    }
  }

  Future<void> updateSurgery(Surgery surgery) async {
    try {
      await _firestore.collection('surgeries').doc(surgery.id).update({
        'surgeryType': surgery.surgeryType,
        'room': surgery.room,
        'startTime': surgery.startTime,
        'endTime': surgery.endTime,
        'status': surgery.status,
        'surgeon': surgery.surgeon,
        'nurses': surgery.nurses,
        'technologists': surgery.technologists,
        'notes': surgery.notes,
      });
    } catch (e) {
      debugPrint('Error updating surgery: $e');
      rethrow;
    }
  }

  Future<void> deleteSurgery(String surgeryId) async {
    try {
      await _firestore.collection('surgeries').doc(surgeryId).delete();
    } catch (e) {
      debugPrint('Error deleting surgery: $e');
      rethrow;
    }
  }
}
