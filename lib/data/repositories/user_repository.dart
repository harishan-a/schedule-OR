import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';

/// Repository for user CRUD operations.
class UserRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final _logger = Logger('UserRepository');

  UserRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference get _usersRef => _firestore.collection('users');

  /// Get current user's profile data.
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _usersRef.doc(user.uid).get();
    if (!doc.exists) return null;
    return doc.data() as Map<String, dynamic>;
  }

  /// Stream current user's profile.
  Stream<Map<String, dynamic>?> getCurrentUserProfileStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);
    return _usersRef.doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data() as Map<String, dynamic>;
    });
  }

  /// Get a user profile by ID.
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final doc = await _usersRef.doc(userId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
  }

  /// Update current user's profile.
  Future<void> updateCurrentUserProfile(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');
    await _usersRef.doc(user.uid).set(data, SetOptions(merge: true));
    _logger.info('Updated profile for user: ${user.uid}');
  }

  /// Create a new user profile.
  Future<void> createUserProfile(
      String userId, Map<String, dynamic> data) async {
    await _usersRef.doc(userId).set(data);
    _logger.info('Created profile for user: $userId');
  }

  /// Get all staff members.
  Future<List<Map<String, dynamic>>> getAllStaff() async {
    final snapshot = await _usersRef.get();
    return snapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            })
        .toList();
  }

  /// Stream all staff members.
  Stream<List<Map<String, dynamic>>> getAllStaffStream() {
    return _usersRef.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            })
        .toList());
  }

  /// Get staff filtered by role.
  Future<List<Map<String, dynamic>>> getStaffByRole(String role) async {
    final snapshot = await _usersRef.where('role', isEqualTo: role).get();
    return snapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            })
        .toList();
  }

  /// Get doctors (convenience method).
  Future<List<String>> getDoctorNames() async {
    final staff = await getStaffByRole('Doctor');
    return staff
        .map((s) {
          final first = s['firstName'] as String? ?? '';
          final last = s['lastName'] as String? ?? '';
          return '$first $last'.trim();
        })
        .where((name) => name.isNotEmpty)
        .toList();
  }

  /// Get nurses (convenience method).
  Future<List<String>> getNurseNames() async {
    final staff = await getStaffByRole('Nurse');
    return staff
        .map((s) {
          final first = s['firstName'] as String? ?? '';
          final last = s['lastName'] as String? ?? '';
          return '$first $last'.trim();
        })
        .where((name) => name.isNotEmpty)
        .toList();
  }

  /// Get technologists (convenience method).
  Future<List<String>> getTechnologistNames() async {
    final staff = await getStaffByRole('Technologist');
    return staff
        .map((s) {
          final first = s['firstName'] as String? ?? '';
          final last = s['lastName'] as String? ?? '';
          return '$first $last'.trim();
        })
        .where((name) => name.isNotEmpty)
        .toList();
  }

  /// Search staff by name.
  Future<List<Map<String, dynamic>>> searchStaff(String query) async {
    final allStaff = await getAllStaff();
    final lowerQuery = query.toLowerCase();
    return allStaff.where((staff) {
      final firstName = (staff['firstName'] as String? ?? '').toLowerCase();
      final lastName = (staff['lastName'] as String? ?? '').toLowerCase();
      final role = (staff['role'] as String? ?? '').toLowerCase();
      return firstName.contains(lowerQuery) ||
          lastName.contains(lowerQuery) ||
          role.contains(lowerQuery);
    }).toList();
  }

  /// Update FCM token for a user.
  Future<void> updateFcmToken(String userId, String token) async {
    await _usersRef.doc(userId).update({'fcmToken': token});
    _logger.info('Updated FCM token for user: $userId');
  }
}
