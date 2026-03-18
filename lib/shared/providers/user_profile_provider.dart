import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;
  final String? role;
  final String? department;
  final String? profileImageUrl;
  final String? selectedDefaultAvatar;

  UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phoneNumber,
    this.role,
    this.department,
    this.profileImageUrl,
    this.selectedDefaultAvatar,
  });

  String get fullName => '$firstName $lastName';

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return UserProfile(
      id: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'],
      role: data['role'],
      department: data['department'],
      profileImageUrl: data['profileImageUrl'],
      selectedDefaultAvatar: data['selectedDefaultAvatar'],
    );
  }

  factory UserProfile.empty() {
    return UserProfile(
      id: '',
      firstName: '',
      lastName: '',
      email: '',
    );
  }
}

class UserProfileProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserProfile? _userProfile;
  bool _isLoading = false;
  String? _error;

  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Stream<UserProfile?> getUserProfileStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _firestore.collection('users').doc(user.uid).snapshots().map(
        (snapshot) =>
            snapshot.exists ? UserProfile.fromFirestore(snapshot) : null);
  }

  Future<void> loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      _userProfile = null;
      _error = 'No user logged in';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists) {
        _userProfile = UserProfile.fromFirestore(doc);
      } else {
        _userProfile = null;
        _error = 'User profile not found';
      }
    } catch (e) {
      _error = 'Error loading profile: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // For testing purposes
  void setTestProfile(UserProfile profile) {
    _userProfile = profile;
    notifyListeners();
  }
}
