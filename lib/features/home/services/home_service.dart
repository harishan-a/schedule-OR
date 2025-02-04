// =============================================================================
// Home Service
// =============================================================================
// Service class responsible for managing home screen data operations including:
// - Real-time surgery data streams
// - User statistics and profile management
// - System announcements
// - User settings and preferences
//
// Firebase Integration:
// - Firestore Collections: 'surgeries', 'users', 'announcements'
// - Authentication: User session management
// - Real-time Updates: Stream-based data delivery
//
// Note: Some query logic is duplicated between methods and could be
// consolidated in future updates (e.g., surgery filtering logic).
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/surgery_summary.dart';
import '../models/user_stats.dart';
import 'package:logging/logging.dart';

/// Service class for managing home screen data and operations
class HomeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _logger = Logger('HomeService');

  /// Streams upcoming surgeries for the current user
  /// 
  /// Filters surgeries where the user is either:
  /// - The primary surgeon
  /// - Part of the nursing staff
  /// - Part of the technical staff
  /// 
  /// Returns only scheduled surgeries with future start times
  Stream<List<SurgerySummary>> getUpcomingSurgeries() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    final userDisplayName = user.displayName ?? '';
    _logger.info('Getting upcoming surgeries for user: $userDisplayName');

    return _firestore
        .collection('surgeries')
        .where(Filter.or(
          Filter('surgeon', isEqualTo: userDisplayName),
          Filter('nurses', arrayContains: userDisplayName),
          Filter('technologists', arrayContains: userDisplayName),
        ))
        .where('status', isEqualTo: 'Scheduled')
        .where('startTime', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('startTime')
        .limit(5)
        .snapshots()
        .map((snapshot) {
          _logger.info('Found ${snapshot.docs.length} upcoming surgeries');
          return snapshot.docs
              .map((doc) => SurgerySummary.fromFirestore(doc))
              .toList();
        });
  }

  /// Streams the user's recent activities (last 5 surgeries)
  /// 
  /// Includes surgeries of all statuses where the user is part of the team
  /// Orders by start time descending to show most recent first
  Stream<List<SurgerySummary>> getRecentActivities() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    final userDisplayName = user.displayName ?? '';
    _logger.info('Getting recent activities for user: $userDisplayName');

    return _firestore
        .collection('surgeries')
        .where(Filter.or(
          Filter('surgeon', isEqualTo: userDisplayName),
          Filter('nurses', arrayContains: userDisplayName),
          Filter('technologists', arrayContains: userDisplayName),
        ))
        .orderBy('startTime', descending: true)
        .limit(5)
        .snapshots()
        .map((snapshot) {
          _logger.info('Found ${snapshot.docs.length} recent activities');
          return snapshot.docs
              .map((doc) => SurgerySummary.fromFirestore(doc))
              .toList();
        });
  }

  /// Streams real-time user statistics
  /// 
  /// Calculates counts for surgeries in different states:
  /// - Scheduled
  /// - Completed
  /// - Cancelled
  /// - In Progress
  Stream<UserStats> getUserStatsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(UserStats.empty());

    return _firestore
        .collection('surgeries')
        .where(Filter.or(
          Filter('surgeon', isEqualTo: user.displayName),
          Filter('nurses', arrayContains: user.displayName),
          Filter('technologists', arrayContains: user.displayName),
        ))
        .snapshots()
        .map((snapshot) {
          int scheduled = 0;
          int completed = 0;
          int cancelled = 0;
          int inProgress = 0;

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final status = data['status']?.toString().toLowerCase() ?? '';

            switch (status) {
              case 'scheduled':
                scheduled++;
                break;
              case 'completed':
                completed++;
                break;
              case 'cancelled':
                cancelled++;
                break;
              case 'in progress':
                inProgress++;
                break;
            }
          }

          return UserStats(
            scheduledSurgeries: scheduled,
            completedSurgeries: completed,
            cancelledSurgeries: cancelled,
            inProgressSurgeries: inProgress,
          );
        })
        .handleError((error) {
          _logger.warning('Error getting user stats: $error');
          return UserStats.empty();
        });
  }

  /// Legacy method for fetching user statistics
  /// @deprecated Use getUserStatsStream() for real-time updates instead
  Future<UserStats> getUserStats() async {
    final user = _auth.currentUser;
    if (user == null) return UserStats.empty();

    try {
      final userDisplayName = user.displayName ?? '';
      final snapshot = await _firestore
          .collection('surgeries')
          .where('surgeon', isEqualTo: userDisplayName)
          .get();

      int scheduled = 0;
      int completed = 0;
      int cancelled = 0;
      int inProgress = 0;
      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'Scheduled';
        final startTime = (data['startTime'] as Timestamp).toDate();

        switch (status.toLowerCase()) {
          case 'scheduled':
            if (startTime.isAfter(now)) {
              scheduled++;
            }
            break;
          case 'completed':
            completed++;
            break;
          case 'cancelled':
            cancelled++;
            break;
          case 'in progress':
            inProgress++;
            break;
        }
      }

      return UserStats(
        scheduledSurgeries: scheduled,
        completedSurgeries: completed,
        cancelledSurgeries: cancelled,
        inProgressSurgeries: inProgress,
      );
    } catch (e) {
      _logger.severe('Error fetching user stats: $e');
      return UserStats.empty();
    }
  }

  /// Fetches the current user's profile data
  /// 
  /// Attempts to read from both server and cache for optimal performance
  /// Returns an empty map if the user is not authenticated or data is unavailable
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache));

      if (!doc.exists) {
        return {};
      }

      return doc.data() ?? {};
    } catch (e) {
      _logger.severe('Error getting user profile: $e');
      return {};
    }
  }

  /// Streams system announcements
  /// 
  /// Returns the 3 most recent announcements ordered by timestamp
  /// Each announcement includes:
  /// - Title and message
  /// - Timestamp
  /// - Priority level
  Stream<List<Map<String, dynamic>>> getAnnouncements() {
    return _firestore
        .collection('announcements')
        .orderBy('timestamp', descending: true)
        .limit(3)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'title': doc['title'] ?? '',
                  'message': doc['message'] ?? '',
                  'timestamp': doc['timestamp'] as Timestamp,
                  'priority': doc['priority'] ?? 'normal',
                })
            .toList())
        .handleError((error) {
          _logger.warning('Error getting announcements: $error');
          return [];
        });
  }

  /// Streams all surgeries for the current user
  /// 
  /// Returns raw QueryDocumentSnapshot objects for flexibility in data handling
  /// Includes all surgeries where the user is part of the team
  Stream<List<QueryDocumentSnapshot>> getUserSurgeriesStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('surgeries')
        .where(Filter.or(
          Filter('surgeon', isEqualTo: user.displayName),
          Filter('nurses', arrayContains: user.displayName),
          Filter('technologists', arrayContains: user.displayName),
        ))
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs)
        .handleError((error) {
          _logger.warning('Error getting user surgeries: $error');
          return [];
        });
  }

  /// Streams all surgeries in the system
  /// 
  /// Returns raw QuerySnapshot for maximum flexibility
  /// Orders by start time descending
  Stream<QuerySnapshot> getSurgeriesStream() {
    return _firestore
        .collection('surgeries')
        .orderBy('startTime', descending: true)
        .snapshots()
        .handleError((error) {
          _logger.warning('Error getting surgeries: $error');
          throw error;
        });
  }

  /// Fetches user preferences and settings
  /// 
  /// Attempts to read from both server and cache
  /// Returns an empty map if data is unavailable
  Future<Map<String, dynamic>> getUserSettings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('preferences')
          .get(const GetOptions(source: Source.serverAndCache));

      return doc.data() ?? {};
    } catch (e) {
      _logger.severe('Error getting user settings: $e');
      return {};
    }
  }

  /// Updates user preferences and settings
  /// 
  /// Uses merge option to prevent overwriting unspecified fields
  /// Throws any errors for proper error handling by callers
  Future<void> saveUserSettings(Map<String, dynamic> settings) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('preferences')
          .set(settings, SetOptions(merge: true));
    } catch (e) {
      _logger.severe('Error saving user settings: $e');
      rethrow;
    }
  }

  Future<void> someMethod() async {
    try {
      _logger.info('Your log message here');
      // Replace all print statements with _logger.info or _logger.warning
    } catch (e) {
      _logger.severe('Error: $e');
    }
  }
}
