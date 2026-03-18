import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_orscheduler/data/repositories/user_repository.dart';
import 'package:firebase_orscheduler/data/services/firebase_auth_service.dart';
import 'package:firebase_orscheduler/data/services/image_service.dart';
import 'package:logging/logging.dart';
import 'dart:typed_data';

/// ViewModel for the profile screen.
class ProfileViewModel extends ChangeNotifier {
  final UserRepository _userRepository;
  final FirebaseAuthService _authService;
  final ImageService _imageService;
  final _logger = Logger('ProfileViewModel');

  Map<String, dynamic>? _profileData;
  bool _isLoading = false;
  bool _isEditing = false;
  String? _error;

  ProfileViewModel({
    UserRepository? userRepository,
    FirebaseAuthService? authService,
    ImageService? imageService,
  })  : _userRepository = userRepository ?? UserRepository(),
        _authService = authService ?? FirebaseAuthService(),
        _imageService = imageService ?? ImageService();

  Map<String, dynamic>? get profileData => _profileData;
  bool get isLoading => _isLoading;
  bool get isEditing => _isEditing;
  String? get error => _error;
  User? get currentUser => _authService.currentUser;

  String get displayName {
    if (_profileData == null) return '';
    return '${_profileData!['firstName'] ?? ''} ${_profileData!['lastName'] ?? ''}'
        .trim();
  }

  /// Load the current user's profile.
  Future<void> loadProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profileData = await _userRepository.getCurrentUserProfile();
    } catch (e) {
      _error = 'Failed to load profile';
      _logger.warning('Error loading profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Stream the current user's profile.
  Stream<Map<String, dynamic>?> getProfileStream() {
    return _userRepository.getCurrentUserProfileStream();
  }

  /// Toggle editing mode.
  void toggleEditing() {
    _isEditing = !_isEditing;
    notifyListeners();
  }

  /// Update profile fields.
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _userRepository.updateCurrentUserProfile(data);

      // Update display name if name changed
      final firstName = data['firstName'] as String?;
      final lastName = data['lastName'] as String?;
      if (firstName != null || lastName != null) {
        final newName = '${firstName ?? _profileData?['firstName'] ?? ''} '
                '${lastName ?? _profileData?['lastName'] ?? ''}'
            .trim();
        await _authService.updateDisplayName(newName);
      }

      _profileData = {...?_profileData, ...data};
      _isEditing = false;
      _logger.info('Profile updated');
      return true;
    } catch (e) {
      _error = 'Failed to update profile';
      _logger.warning('Error updating profile: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Upload a profile image.
  Future<String?> uploadProfileImage(Uint8List imageBytes) async {
    final userId = _authService.currentUser?.uid;
    if (userId == null) return null;

    try {
      final url = await _imageService.uploadProfileImage(
        userId: userId,
        imageBytes: imageBytes,
      );

      if (url != null) {
        await _userRepository
            .updateCurrentUserProfile({'profileImageUrl': url});
        await _authService.updatePhotoURL(url);
        _profileData?['profileImageUrl'] = url;
        notifyListeners();
      }

      return url;
    } catch (e) {
      _logger.warning('Error uploading profile image: $e');
      return null;
    }
  }

  /// Set a default avatar.
  Future<void> setDefaultAvatar(String avatarPath) async {
    try {
      await _userRepository.updateCurrentUserProfile({
        'selectedDefaultAvatar': avatarPath,
        'profileImageUrl': '',
      });
      _profileData?['selectedDefaultAvatar'] = avatarPath;
      _profileData?['profileImageUrl'] = '';
      notifyListeners();
    } catch (e) {
      _logger.warning('Error setting default avatar: $e');
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    await _authService.signOut();
  }
}
