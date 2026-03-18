import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'dart:io' show Platform;

/// Service for Firebase Cloud Messaging setup and token management.
/// Extracted from NotificationManager.
class FirebaseMessagingService {
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final _logger = Logger('FirebaseMessagingService');

  FirebaseMessagingService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Request notification permissions and get FCM token.
  Future<String?> initialize() async {
    if (kIsWeb) {
      _logger.info('Skipping FCM initialization on web');
      return null;
    }

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        _logger.warning('FCM permissions not granted');
        return null;
      }

      _logger.info('FCM permissions granted');
      String? token;

      if (!kIsWeb && Platform.isIOS) {
        token = await _getIOSToken();
      } else {
        try {
          token = await _messaging.getToken();
        } catch (e) {
          _logger.warning('Error getting FCM token: $e');
        }
      }

      if (token != null) {
        await _saveDeviceToken(token);
      }

      // Set up token refresh listener
      _messaging.onTokenRefresh.listen(_saveDeviceToken);

      return token;
    } catch (e) {
      _logger.severe('Error initializing FCM: $e');
      return null;
    }
  }

  /// Get iOS token with APNS handling.
  Future<String?> _getIOSToken() async {
    try {
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        return await _messaging.getToken();
      } else {
        _logger.warning('No APNS token available');
        try {
          return await _messaging.getToken();
        } catch (e) {
          if (e.toString().contains('apns-token-not-set')) {
            return null;
          }
          rethrow;
        }
      }
    } catch (e) {
      _logger.warning('Error getting iOS token: $e');
      return null;
    }
  }

  /// Save device token to Firestore.
  Future<void> _saveDeviceToken(String token) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _logger.info('FCM token saved for user ${user.uid}');
      }
    } catch (e) {
      _logger.severe('Error saving FCM token: $e');
    }
  }

  /// Subscribe to a notification topic.
  Future<void> subscribeToTopic(String topic) async {
    if (kIsWeb) return;
    try {
      if (!kIsWeb && Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          _logger.info('Skip topic $topic: no APNS token');
          return;
        }
      }
      await _messaging.subscribeToTopic(topic);
      _logger.info('Subscribed to topic: $topic');
    } catch (e) {
      _logger.warning('Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from a topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb) return;
    try {
      await _messaging.unsubscribeFromTopic(topic);
      _logger.info('Unsubscribed from topic: $topic');
    } catch (e) {
      _logger.warning('Error unsubscribing from topic $topic: $e');
    }
  }

  /// Set foreground message handler.
  void onForegroundMessage(void Function(RemoteMessage) handler) {
    FirebaseMessaging.onMessage.listen(handler);
  }

  /// Set message opened handler.
  void onMessageOpened(void Function(RemoteMessage) handler) {
    FirebaseMessaging.onMessageOpenedApp.listen(handler);
  }
}
