import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';

/// Repository for surgery CRUD operations.
/// Single source of truth for surgery data access.
class SurgeryRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final _logger = Logger('SurgeryRepository');

  SurgeryRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference get _surgeriesRef => _firestore.collection('surgeries');

  /// Add a new surgery. Returns the document ID.
  Future<String> addSurgery(Map<String, dynamic> data) async {
    if (!data.containsKey('surgeryType') || !data.containsKey('startTime')) {
      throw ArgumentError(
          'Surgery data must contain surgeryType and startTime');
    }
    data['created'] = FieldValue.serverTimestamp();
    data['lastUpdated'] = FieldValue.serverTimestamp();
    final docRef = await _surgeriesRef.add(data);
    _logger.info('Added surgery: ${docRef.id}');
    return docRef.id;
  }

  /// Update an existing surgery by ID.
  Future<void> updateSurgery(
      String surgeryId, Map<String, dynamic> data) async {
    if (surgeryId.isEmpty) throw ArgumentError('Surgery ID cannot be empty');
    data['lastUpdated'] = FieldValue.serverTimestamp();
    await _surgeriesRef.doc(surgeryId).update(data);
    _logger.info('Updated surgery: $surgeryId');
  }

  /// Update surgery from Surgery object.
  Future<void> updateSurgeryFromModel(Surgery surgery) async {
    if (surgery.id.isEmpty) throw ArgumentError('Surgery ID cannot be empty');
    await _surgeriesRef.doc(surgery.id).update({
      ...surgery.toFirestore(),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    _logger.info('Updated surgery from model: ${surgery.id}');
  }

  /// Update just the status field.
  Future<void> updateSurgeryStatus(String surgeryId, String newStatus) async {
    await _surgeriesRef.doc(surgeryId).update({
      'status': newStatus,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    _logger.info('Updated surgery status: $surgeryId -> $newStatus');
  }

  /// Delete a surgery.
  Future<void> deleteSurgery(String surgeryId) async {
    if (surgeryId.isEmpty) throw ArgumentError('Surgery ID cannot be empty');
    await _surgeriesRef.doc(surgeryId).delete();
    _logger.info('Deleted surgery: $surgeryId');
  }

  /// Get a single surgery by ID.
  Future<Surgery?> getSurgery(String surgeryId) async {
    final doc = await _surgeriesRef.doc(surgeryId).get();
    if (!doc.exists) return null;
    return Surgery.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
  }

  /// Get a single surgery document data (raw).
  Future<Map<String, dynamic>?> getSurgeryData(String surgeryId) async {
    final doc = await _surgeriesRef.doc(surgeryId).get();
    if (!doc.exists) return null;
    return doc.data() as Map<String, dynamic>;
  }

  /// Stream a single surgery.
  Stream<Surgery?> getSurgeryStream(String surgeryId) {
    return _surgeriesRef.doc(surgeryId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Surgery.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
    });
  }

  /// Stream all surgeries ordered by startTime.
  Stream<List<Surgery>> getSurgeriesStream() {
    return _surgeriesRef.orderBy('startTime', descending: true).snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => Surgery.fromFirestore(
                doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  /// Stream all surgeries as raw QuerySnapshot (for backward compat).
  Stream<QuerySnapshot> getSurgeriesQueryStream() {
    return _surgeriesRef.orderBy('startTime', descending: true).snapshots();
  }

  /// Get surgeries for a specific date range.
  Stream<List<Surgery>> getSurgeriesByDateRange(DateTime start, DateTime end) {
    return _surgeriesRef
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Surgery.fromFirestore(
                doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  /// Get surgeries for the current user (by display name across surgeon/nurses/technologists).
  Stream<List<Surgery>> getUserSurgeriesStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    final displayName = user.displayName ?? '';

    return _surgeriesRef
        .where(Filter.or(
          Filter('surgeon', isEqualTo: displayName),
          Filter('nurses', arrayContains: displayName),
          Filter('technologists', arrayContains: displayName),
        ))
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Surgery.fromFirestore(
                doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  /// Get upcoming scheduled surgeries for the current user (limit 5).
  Stream<List<Surgery>> getUpcomingSurgeriesStream({int limit = 5}) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    final displayName = user.displayName ?? '';

    return _surgeriesRef
        .where(Filter.or(
          Filter('surgeon', isEqualTo: displayName),
          Filter('nurses', arrayContains: displayName),
          Filter('technologists', arrayContains: displayName),
        ))
        .where('status', isEqualTo: 'Scheduled')
        .where('startTime', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('startTime')
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Surgery.fromFirestore(
                doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  /// Get surgeries by patient name (for patient lookup).
  Future<List<Surgery>> searchByPatientName(String name) async {
    // Firestore doesn't support full-text search natively,
    // so we fetch and filter client-side
    final snapshot = await _surgeriesRef.get();
    final lowerName = name.toLowerCase();
    return snapshot.docs
        .map((doc) =>
            Surgery.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
        .where((s) => s.patientName.toLowerCase().contains(lowerName))
        .toList();
  }

  /// Get surgeries by patient ID.
  Future<List<Surgery>> searchByPatientId(String patientId) async {
    final snapshot =
        await _surgeriesRef.where('patientId', isEqualTo: patientId).get();
    return snapshot.docs
        .map((doc) =>
            Surgery.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
  }
}
