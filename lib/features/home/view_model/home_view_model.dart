import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_orscheduler/data/repositories/surgery_repository.dart';
import 'package:firebase_orscheduler/data/repositories/user_repository.dart';
import 'package:firebase_orscheduler/features/schedule/models/surgery.dart';
import 'package:firebase_orscheduler/features/home/services/home_service.dart';
import 'package:firebase_orscheduler/features/home/models/user_stats.dart';
import 'package:logging/logging.dart';

/// ViewModel for the home dashboard screen.
class HomeViewModel extends ChangeNotifier {
  final HomeService _homeService;
  final SurgeryRepository _surgeryRepository;
  final UserRepository _userRepository;
  final _logger = Logger('HomeViewModel');

  String _userName = '';
  String _profileImageUrl = '';
  String _selectedDefaultAvatar = '';
  bool _isLoading = true;

  HomeViewModel({
    HomeService? homeService,
    SurgeryRepository? surgeryRepository,
    UserRepository? userRepository,
  })  : _homeService = homeService ?? HomeService(),
        _surgeryRepository = surgeryRepository ?? SurgeryRepository(),
        _userRepository = userRepository ?? UserRepository();

  String get userName => _userName;
  String get profileImageUrl => _profileImageUrl;
  String get selectedDefaultAvatar => _selectedDefaultAvatar;
  bool get isLoading => _isLoading;

  /// Load initial user data.
  Future<void> loadUserData() async {
    try {
      final profile = await _userRepository.getCurrentUserProfile();
      if (profile != null) {
        _userName =
            '${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}'.trim();
        _profileImageUrl = profile['profileImageUrl'] as String? ?? '';
        _selectedDefaultAvatar =
            profile['selectedDefaultAvatar'] as String? ?? '';
      }
    } catch (e) {
      _logger.warning('Error loading user data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Stream user statistics.
  Stream<UserStats> getUserStatsStream() {
    return _homeService.getUserStatsStream();
  }

  /// Stream user's surgeries.
  Stream<List<QueryDocumentSnapshot>> getUserSurgeriesStream() {
    return _homeService.getUserSurgeriesStream();
  }

  /// Stream announcements.
  Stream<List<Map<String, dynamic>>> getAnnouncementsStream() {
    return _homeService.getAnnouncements();
  }

  /// Get upcoming surgeries.
  Stream<List<Surgery>> getUpcomingSurgeriesStream() {
    return _surgeryRepository.getUpcomingSurgeriesStream();
  }
}
