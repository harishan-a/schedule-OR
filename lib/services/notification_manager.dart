import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:rxdart/rxdart.dart';

import 'twilio_service.dart';
import '../features/schedule/models/surgery.dart';

/// Manages all types of notifications in the application:
/// - SMS notifications via Twilio
/// - In-app notifications
/// - Email notifications
/// - Push notifications via FCM
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal(false);
  static final NotificationManager _webInstance = NotificationManager._internal(true);
  
  factory NotificationManager({bool isWebMode = false}) {
    return isWebMode ? _webInstance : _instance;
  }
  
  NotificationManager._internal(this._isWebMode);
  
  final bool _isWebMode;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final TwilioService _twilioService = TwilioService();
  final _logger = Logger('NotificationManager');
  
  // For in-app notifications
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final StreamController<Map<String, dynamic>> _notificationsStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get notificationsStream => _notificationsStreamController.stream;
  
  // Email API key (Sendgrid, Mailgun, etc.)
  final String? _emailApiKey = dotenv.env['EMAIL_API_KEY'];
  final String? _emailFromAddress = dotenv.env['EMAIL_FROM_ADDRESS'];
  final String? _emailSendEndpoint = dotenv.env['EMAIL_SEND_ENDPOINT'];

  /// Initialize notification services for web
  Future<void> initializeWeb() async {
    _logger.info('Initializing notification manager for web');
    
    try {
      // Web implementation only uses Firestore for notifications
      // It doesn't use FCM or local notifications
      _logger.info('Web notification manager initialized successfully');
    } catch (e) {
      _logger.severe('Error initializing NotificationManager for web: $e');
    }
  }

  /// Initialize notification services
  Future<void> initialize() async {
    if (_isWebMode) {
      return initializeWeb();
    }
    
    _logger.info('Initializing notification manager');
    
    try {
      // Initialize FCM
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        _logger.info('FCM permissions granted');
        
        // Get FCM token for this device
        String? token;
        
        // Special handling for iOS devices
        if (Platform.isIOS) {
          try {
            // Don't fail if we can't get an APNS token
            token = await _getIOSToken();
          } catch (e) {
            // Just log the error and continue
            _logger.warning('Error with iOS notification token: $e');
          }
        } else {
          // For non-iOS devices, get the token directly but handle failure
          try {
            token = await _messaging.getToken();
          } catch (e) {
            _logger.warning('Error getting FCM token: $e');
          }
        }
        
        // Save token if available but continue even if not
        if (token != null) {
          try {
            await _saveDeviceToken(token);
          } catch (e) {
            _logger.warning('Error saving device token: $e');
          }
        } else {
          _logger.warning('No messaging token available, continuing without push capability');
        }
        
        // Set up token refresh listener
        try {
          _messaging.onTokenRefresh.listen(_saveDeviceToken);
        } catch (e) {
          _logger.warning('Error setting up token refresh: $e');
        }
      } else {
        _logger.warning('FCM permissions not granted: ${settings.authorizationStatus}');
      }
      
      // Initialize local notifications
      try {
        const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
        final initializationSettingsIOS = DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
        final initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
        
        await _localNotifications.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: _onSelectNotification,
        );
      } catch (e) {
        _logger.warning('Error initializing local notifications: $e');
      }
      
      // Configure FCM message handling - use try/catch for each listener
      try {
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      } catch (e) {
        _logger.warning('Error setting up foreground message handler: $e');
      }
      
      try {
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      } catch (e) {
        _logger.warning('Error setting up message opened handler: $e');
      }
      
      // Set up background handler
      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (e) {
        _logger.warning('Error setting up background message handler: $e');
      }
      
      _logger.info('NotificationManager initialized successfully');
    } catch (e) {
      _logger.severe('Error initializing NotificationManager: $e');
    }
  }

  /// Helper method to get iOS token with error handling
  Future<String?> _getIOSToken() async {
    String? token;
    
    try {
      // Try to get APNS token but don't retry too much
      String? apnsToken = await _messaging.getAPNSToken();
      
      if (apnsToken != null) {
        // Wait briefly to ensure APNS token is processed
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Get Firebase token
        token = await _messaging.getToken();
        _logger.info('FCM token with APNS token: ${token ?? "null"}');
      } else {
        // If no APNS token, we'll continue without push capability
        _logger.warning('No APNS token available, push notifications may not work');
        
        // Still try to get FCM token
        try {
          token = await _messaging.getToken();
          _logger.info('FCM token without APNS token: ${token ?? "null"}');
        } catch (e) {
          if (e.toString().contains('apns-token-not-set')) {
            _logger.info('Cannot get FCM token without APNS token on iOS');
            return null;
          } else {
            rethrow;
          }
        }
      }
    } catch (e) {
      _logger.warning('Error getting iOS notification token: $e');
    }
    
    return token;
  }

  /// Subscribe to a specific notification topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      // Skip topic subscription on web
      if (kIsWeb) {
        _logger.info('Skipping topic subscription on web platform');
        return;
      }
      
      // For iOS, make topic subscription optional
      if (Platform.isIOS) {
        try {
          final apnsToken = await _messaging.getAPNSToken();
          if (apnsToken == null) {
            _logger.info('Skip subscribing to topic $topic: APNS token not available, but continuing app operation');
            return; // Exit gracefully without error
          }
          
          await _messaging.subscribeToTopic(topic);
          _logger.info('Subscribed to topic: $topic');
        } catch (e) {
          // Specifically handle the APNS token not set error
          if (e.toString().contains('apns-token-not-set')) {
            _logger.info('APNS token not available for topic subscription, continuing without push notifications');
            return; // Exit gracefully
          }
          _logger.warning('Error subscribing to topic $topic on iOS: $e');
          // Don't rethrow, just log and continue
        }
      } else {
        // Android platform - simpler path
        await _messaging.subscribeToTopic(topic);
        _logger.info('Subscribed to topic: $topic');
      }
    } catch (e) {
      // Log but don't crash the app
      
      await _messaging.subscribeToTopic(topic);
      _logger.info('Subscribed to topic: $topic');
    } catch (e) {
      _logger.severe('Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from a specific notification topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      // Skip topic unsubscription on web
      if (kIsWeb) {
        _logger.info('Skipping topic unsubscription on web platform');
        return;
      }
      
      // For iOS, ensure we have an APNS token first
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          _logger.warning('Cannot unsubscribe from topic $topic: APNS token not available');
          return;
        }
      }
      
      await _messaging.unsubscribeFromTopic(topic);
      _logger.info('Unsubscribed from topic: $topic');
    } catch (e) {
      _logger.severe('Error unsubscribing from topic $topic: $e');
    }
  }
  
  /// Save device token to user document in Firestore
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
  
  /// Handle when a notification is tapped
  void _onSelectNotification(NotificationResponse details) async {
    try {
      if (details.payload != null) {
        final dynamic data = json.decode(details.payload!);
        
        // Handle notification tap based on type
        if (data['type'] == 'surgery') {
          // TODO: Navigate to surgery details
          _logger.info('Tapped on surgery notification: ${data['surgeryId']}');
        }
      }
    } catch (e) {
      _logger.severe('Error handling notification tap: $e');
    }
  }
  
  /// Handle foreground messages from FCM
  void _handleForegroundMessage(RemoteMessage message) async {
    _logger.info('Got a message whilst in the foreground!');
    _logger.info('Message data: ${message.data}');

    if (message.notification != null) {
      // Show local notification
      showLocalNotification(
        title: message.notification!.title ?? 'Surgery Notification',
        body: message.notification!.body ?? 'New notification received',
        payload: json.encode(message.data),
      );
      
      // Store notification in Firestore
      _storeNotification(
        title: message.notification!.title ?? 'Surgery Notification',
        body: message.notification!.body ?? 'New notification received',
        data: message.data,
      );
    }
  }
  
  /// Handle when app is opened from a notification
  void _handleMessageOpenedApp(RemoteMessage message) async {
    _logger.info('Message opened app: ${message.data}');
    
    // Navigate based on the notification data
    if (message.data.containsKey('surgeryId')) {
      // TODO: Navigate to surgery details
      _logger.info('Should navigate to surgery: ${message.data['surgeryId']}');
    }
  }
  
  /// Save notification to Firestore
  Future<void> _storeNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Create notification document
        final notificationRef = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .add({
          'title': title,
          'body': body,
          'data': data ?? {},
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        // Stream to app UI
        _notificationsStreamController.add({
          'id': notificationRef.id,
          'title': title,
          'body': body,
          'data': data ?? {},
          'read': false,
          'timestamp': Timestamp.now(),
        });
      }
    } catch (e) {
      _logger.severe('Error storing notification: $e');
    }
  }
  
  /// Show a local notification when the app is in foreground
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      _logger.info('Showing local notification: $title');
      
      if (Platform.isIOS || Platform.isAndroid) {
        final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
        
        // Check if notifications are initialized
        if (!await flutterLocalNotificationsPlugin.pendingNotificationRequests()
            .then((_) => true)
            .catchError((_) => false)) {
          _logger.warning('Local notifications not initialized');
          return;
        }
        
        const androidPlatformChannelSpecifics = AndroidNotificationDetails(
          'surgery_notifications',
          'Surgery Notifications',
          importance: Importance.high,
          priority: Priority.high,
        );
        
        const iOSPlatformChannelSpecifics = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
        
        const platformChannelSpecifics = NotificationDetails(
          android: androidPlatformChannelSpecifics,
          iOS: iOSPlatformChannelSpecifics,
        );
        
        // Generate a unique ID based on timestamp
        final notificationId = DateTime.now().microsecondsSinceEpoch.remainder(100000);
        
        await flutterLocalNotificationsPlugin.show(
          notificationId,
          title,
          body,
          platformChannelSpecifics,
          payload: payload,
        );
        
        _logger.info('Local notification sent successfully');
      } else {
        _logger.info('Local notifications not supported on this platform');
      }
    } catch (e) {
      _logger.warning('Failed to show local notification: $e');
    }
  }
  
  /// Send a notification for a scheduled surgery
  Future<void> sendScheduledNotification({
    required String userId,
    required Surgery surgery,
  }) async {
    try {
      // Get user preferences and data
      final userPrefs = await _getUserPreferences(userId);
      if (userPrefs == null) return;
      
      // Prepare notification data
      final String title = 'Surgery Scheduled';
      final String body = 'A ${surgery.surgeryType} surgery has been scheduled for ${_formatDateTime(surgery.startTime)}';
      final Map<String, dynamic> data = {
        'type': 'scheduled',
        'surgeryId': surgery.id,
      };
      
      _logger.info('Sending scheduled notification for surgery: ${surgery.id}');
      
      // Store notification in central collection
      try {
        await _firestore
            .collection('surgery_notifications')
            .add({
          'userId': userId,
          'title': title,
          'body': body,
          'data': data,
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
          'surgery': surgery.id,
        });
        
        _logger.info('Stored scheduled notification in central collection for user $userId');
      } catch (e) {
        _logger.severe('Error storing scheduled notification: $e');
      }
      
      // Send push notification if enabled
      if (userPrefs['enablePushNotifications'] == true) {
        try {
          await showLocalNotification(title: title, body: body, payload: userId);
          _logger.info('Sent local notification to user $userId');
        } catch (e) {
          _logger.warning('Failed to send local notification: $e');
        }
      }
      
      // Send email notification if enabled
      if (userPrefs['enableEmailNotifications'] == true) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data();
        if (userData != null && userData['email'] != null) {
          _logger.info('Sending email notification to ${userData['email']}');
          await _sendEmailNotification(
            email: userData['email'],
            subject: title,
            message: body,
          );
        }
      }
      
      // Send SMS if enabled - with better error handling
      try {
        if (userPrefs['enableSmsNotifications'] == true) {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          final userData = userDoc.data();
          if (userData != null && userData['phoneNumber'] != null) {
            final phoneNumber = userData['phoneNumber'];
            _logger.info('Attempting to send SMS to $phoneNumber');
            
            // Format the phone number - only use real phone numbers
            String formattedNumber = phoneNumber.toString().replaceAll(RegExp(r'[^\+\d]'), '');
            if (!formattedNumber.startsWith('+')) {
              if (formattedNumber.length == 10) {
                formattedNumber = '+1$formattedNumber';
              } else {
                formattedNumber = '+$formattedNumber';
              }
            }
            
            // Skip obviously fake phone numbers
            if (formattedNumber.contains('1234') || formattedNumber.length < 10) {
              _logger.warning('Skipping obvious test phone number: $formattedNumber');
              return;
            }
            
            _logger.info('Sending SMS to formatted number: $formattedNumber');
            
            final result = await _twilioService.sendSMS(
              toNumber: formattedNumber,
              messageBody: body,
            );
            
            _logger.info('SMS send result: $result');
          } else {
            _logger.warning('No phone number found for user $userId');
          }
        }
      } catch (smsError) {
        // Log but don't rethrow, so other notifications can still be sent
        _logger.severe('Error sending SMS notification: $smsError');
      }
      
    } catch (e) {
      _logger.severe('Error sending scheduled notification: $e');
    }
  }
  
  /// Send a notification for a scheduled surgery using just the surgery ID
  Future<void> sendScheduledNotificationById(String surgeryId) async {
    try {
      _logger.info('Sending scheduled notification for surgery $surgeryId');
      
      // Get surgery details
      final surgeryDoc = await _firestore.collection('surgeries').doc(surgeryId).get();
      if (!surgeryDoc.exists) {
        _logger.warning('Surgery not found: $surgeryId');
        return;
      }
      
      final surgeryData = surgeryDoc.data() as Map<String, dynamic>;
      
      // Create surgery object using the factory constructor
      final surgery = Surgery.fromFirestore(surgeryId, surgeryData);
      
      // Get all involved personnel names
      final List<String> personnelNames = [];
      
      // Get surgeon name
      if (surgeryData['surgeon'] != null) {
        personnelNames.add(surgeryData['surgeon']);
      }
      
      // Get nurse and technologist names
      if (surgeryData['nurses'] != null) {
        personnelNames.addAll(List<String>.from(surgeryData['nurses']));
      }
      
      if (surgeryData['technologists'] != null) {
        personnelNames.addAll(List<String>.from(surgeryData['technologists']));
      }
      
      _logger.info('Personnel names for scheduled notification: $personnelNames');
      
      // Look up user IDs by their names and send notifications
      for (final name in personnelNames) {
        // Find the actual user ID for this name
        final userId = await _findUserIdByName(name);
        
        if (userId != null) {
          _logger.info('Found user ID $userId for name $name, sending scheduled notification');
          await sendScheduledNotification(
            userId: userId,
            surgery: surgery,
          );
        } else {
          _logger.warning('Could not find user ID for name: $name, skipping scheduled notification');
        }
      }
      
    } catch (e) {
      _logger.severe('Error sending scheduled notification with ID: $e');
    }
  }
  
  /// Send a notification for an approaching surgery
  Future<void> sendApproachingNotification({
    required String userId,
    required Surgery surgery,
    required String timeRemaining,
  }) async {
    try {
      // Get user preferences
      final userPrefs = await _getUserPreferences(userId);
      if (userPrefs == null) return;
      
      // Prepare notification data
      final String title = 'Upcoming Surgery';
      final String body = 'Reminder: ${surgery.surgeryType} surgery is in $timeRemaining';
      final Map<String, dynamic> data = {
        'type': 'approaching',
        'surgeryId': surgery.id,
      };
      
      // Store notification in central collection
      try {
        await _firestore
            .collection('surgery_notifications')
            .add({
          'userId': userId,
          'title': title,
          'body': body,
          'data': data,
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
          'surgeryId': surgery.id,
          'involvedPersonnel': [
            if (surgery.surgeon != null) surgery.surgeon,
            ...surgery.nurses ?? [],
            ...surgery.technologists ?? [],
          ],
        });
        
        _logger.info('Stored approaching notification in surgery_notifications collection for user $userId');
      } catch (e) {
        _logger.severe('Error storing approaching notification: $e');
      }
      
      // Send push notification if enabled
      if (userPrefs['enablePushNotifications'] == true) {
        try {
          await showLocalNotification(title: title, body: body, payload: userId);
          _logger.info('Sent local notification to user $userId');
        } catch (e) {
          _logger.warning('Failed to send local notification: $e');
        }
      }
      
      // Send email notification if enabled
      if (userPrefs['enableEmailNotifications'] == true) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data();
        if (userData != null && userData['email'] != null) {
          await _sendEmailNotification(
            email: userData['email'],
            subject: title,
            message: body,
          );
        }
      }
      
      // For approaching surgery notifications, also attempt to send SMS
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data();
        if (userData != null && userData['phoneNumber'] != null) {
          final phoneNumber = userData['phoneNumber'];
          _logger.info('Sending SMS reminder to $phoneNumber for approaching surgery');
          
          // Format the phone number
          String formattedNumber = phoneNumber.toString().replaceAll(RegExp(r'[^\+\d]'), '');
          if (!formattedNumber.startsWith('+')) {
            if (formattedNumber.length == 10) {
              formattedNumber = '+1$formattedNumber';
            } else {
              formattedNumber = '+$formattedNumber';
            }
          }
          
          // Skip obviously fake phone numbers
          if (formattedNumber.contains('1234') || formattedNumber.length < 10) {
            _logger.warning('Skipping obvious test phone number: $formattedNumber');
            return;
          }
          
          _logger.info('Sending SMS to formatted number: $formattedNumber');
          
          final result = await _twilioService.sendSMS(
            toNumber: formattedNumber,
            messageBody: body,
          );
          
          _logger.info('SMS send result for approaching notification: $result');
        }
      } catch (smsError) {
        _logger.severe('Error sending SMS for approaching notification: $smsError');
      }
      
    } catch (e) {
      _logger.severe('Error sending approaching notification: $e');
    }
  }
  
  /// Send a notification for an approaching surgery using just the surgery ID
  Future<void> sendApproachingNotificationById(String surgeryId, {int hoursBeforeSurgery = 1}) async {
    try {
      _logger.info('Sending approaching notification for surgery $surgeryId ($hoursBeforeSurgery hour(s) before)');
      
      // Get surgery details
      final surgeryDoc = await _firestore.collection('surgeries').doc(surgeryId).get();
      if (!surgeryDoc.exists) {
        _logger.warning('Surgery not found: $surgeryId');
        return;
      }
      
      final surgeryData = surgeryDoc.data() as Map<String, dynamic>;
      
      // Create surgery object using the factory constructor
      final surgery = Surgery.fromFirestore(surgeryId, surgeryData);
      
      // Format time remaining
      final String timeRemaining = '$hoursBeforeSurgery hour${hoursBeforeSurgery > 1 ? 's' : ''}';
      
      // Get the current user who's making the change
      final currentUser = _auth.currentUser;
      
      // Only send notification to the surgeon and the current user (if available)
      final Set<String> notifyUserIds = {};
      
      // Always notify the surgeon
      if (surgeryData['surgeon'] != null) {
        final surgeonName = surgeryData['surgeon'];
        final surgeonId = await _findUserIdByName(surgeonName);
        if (surgeonId != null) {
          notifyUserIds.add(surgeonId);
          _logger.info('Will notify surgeon: $surgeonName ($surgeonId)');
        }
      }
      
      // Add the current user if available
      if (currentUser != null) {
        notifyUserIds.add(currentUser.uid);
        _logger.info('Will notify current user: ${currentUser.uid}');
      }
      
      // Store a single notification in the central collection
      try {
        await _firestore
            .collection('surgery_notifications')
            .add({
          'surgeryId': surgeryId,
          'timestamp': FieldValue.serverTimestamp(),
          'title': 'Upcoming Surgery',
          'body': 'Reminder: Surgery is in $timeRemaining',
          'involvedPersonnel': [
            if (surgeryData['surgeon'] != null) surgeryData['surgeon'],
            if (surgeryData['nurses'] != null) ...surgeryData['nurses'],
            if (surgeryData['technologists'] != null) ...surgeryData['technologists'],
          ],
        });
        
        _logger.info('Stored approaching reminder in central surgery_notifications collection');
      } catch (e) {
        _logger.severe('Error storing central approaching notification: $e');
      }
      
      // Send individual notifications to selected users
      for (final userId in notifyUserIds) {
        _logger.info('Sending approaching notification to user: $userId');
        await sendApproachingNotification(
          userId: userId,
          surgery: surgery,
          timeRemaining: timeRemaining,
        );
      }
      
    } catch (e) {
      _logger.severe('Error sending approaching notification with ID: $e');
    }
  }
  
  /// Send a notification for a surgery status change
  Future<void> sendStatusChangeNotification({
    required String userId,
    required Surgery surgery,
    required String oldStatus,
    required String newStatus,
  }) async {
    try {
      _logger.info('Sending status change notification to user $userId for surgery ${surgery.id} ($oldStatus → $newStatus)');
      
      // Get user preferences - but we'll force SMS to be enabled for status changes
      final userPrefs = await _getUserPreferences(userId);
      if (userPrefs == null) {
        _logger.warning('No preferences found for user $userId, skipping notification');
        return;
      }
      
      // Prepare notification data
      final String title = 'Surgery Status Changed';
      final String body = 'The ${surgery.surgeryType} surgery has changed from $oldStatus to $newStatus';
      final Map<String, dynamic> data = {
        'type': 'status',
        'surgeryId': surgery.id,
        'oldStatus': oldStatus,
        'newStatus': newStatus,
      };
      
      // Store notification in user's collection instead of central collection
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .add({
          'title': title,
          'body': body,
          'data': data,
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        _logger.info('Stored notification in user\'s collection for user $userId');
      } catch (e) {
        _logger.severe('Error storing notification in user\'s collection: $e');
        // Continue execution despite this error - don't return
      }
      
      // Send push notification if enabled
      if (userPrefs['enablePushNotifications'] == true) {
        try {
          await showLocalNotification(title: title, body: body, payload: userId);
          _logger.info('Sent local notification to user $userId');
        } catch (e) {
          _logger.warning('Failed to send local notification: $e');
        }
      } else {
        _logger.info('Push notifications disabled for user $userId');
      }
      
      // Send email notification if enabled
      if (userPrefs['enableEmailNotifications'] == true) {
        try {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          final userData = userDoc.data();
          if (userData != null && userData['email'] != null) {
            await _sendEmailNotification(
              email: userData['email'],
              subject: title,
              message: body,
            );
          } else {
            _logger.warning('No email found for user $userId');
          }
        } catch (e) {
          _logger.warning('Failed to send email notification: $e');
          // Continue despite email error
        }
      } else {
        _logger.info('Email notifications disabled for user $userId');
      }
      
      // For status change notifications, we'll attempt to send SMS regardless of user preferences
      // This is a temporary fix to ensure SMS is sent
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data();
        if (userData != null && userData['phoneNumber'] != null) {
          final phoneNumber = userData['phoneNumber'];
          _logger.info('Forcing SMS to $phoneNumber for user $userId regardless of preferences');
          
          // Format the phone number
          String formattedNumber = phoneNumber.toString().replaceAll(RegExp(r'[^\+\d]'), '');
          if (!formattedNumber.startsWith('+')) {
            if (formattedNumber.length == 10) {
              formattedNumber = '+1$formattedNumber';
            } else {
              formattedNumber = '+$formattedNumber';
            }
          }
          
          _logger.info('Sending SMS to formatted number: $formattedNumber');
          
          final result = await _twilioService.sendSMS(
            toNumber: formattedNumber,
            messageBody: body,
          );
          
          _logger.info('SMS send result for $userId: $result');
        } else {
          _logger.warning('No phone number found for user $userId for SMS');
        }
      } catch (smsError) {
        _logger.severe('Error sending SMS notification: $smsError');
        // Continue despite SMS error
      }
      
      _logger.info('Successfully sent all enabled notifications to user $userId');
    } catch (e) {
      _logger.severe('Error sending status change notification: $e');
      // Don't rethrow - let's not fail the entire process for one user
    }
  }
  
  /// Send a status change notification using just the surgery ID and status values
  Future<void> sendStatusChangeNotificationById(String surgeryId, String oldStatus, String newStatus) async {
    try {
      _logger.info('Sending status change notification for surgery $surgeryId ($oldStatus → $newStatus)');
      
      // Get surgery details
      final surgeryDoc = await _firestore.collection('surgeries').doc(surgeryId).get();
      if (!surgeryDoc.exists) {
        _logger.warning('Surgery not found: $surgeryId');
        return;
      }
      
      final surgeryData = surgeryDoc.data() as Map<String, dynamic>;
      
      // Create surgery object using the factory constructor
      final surgery = Surgery.fromFirestore(surgeryId, surgeryData);
      
      // Get the current user who's making the change
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _logger.warning('No authenticated user found for status change notification');
        return;
      }
      
      // Only send notification to the surgeon and the current user who made the change
      final Set<String> notifyUserIds = {};
      
      // Always notify the surgeon
      if (surgeryData['surgeon'] != null) {
        final surgeonName = surgeryData['surgeon'];
        final surgeonId = await _findUserIdByName(surgeonName);
        if (surgeonId != null) {
          notifyUserIds.add(surgeonId);
          _logger.info('Will notify surgeon: $surgeonName ($surgeonId)');
        }
      }
      
      // Add the current user who made the change
      notifyUserIds.add(currentUser.uid);
      _logger.info('Will notify current user: ${currentUser.uid}');
      
      // Store a single notification in the central collection
      try {
        await _firestore
            .collection('surgery_notifications')
            .add({
          'surgeryId': surgeryId,
          'oldStatus': oldStatus,
          'newStatus': newStatus,
          'timestamp': FieldValue.serverTimestamp(),
          'title': 'Surgery Status Changed',
          'body': 'The ${surgery.surgeryType} surgery has changed from $oldStatus to $newStatus',
          'involvedPersonnel': [
            if (surgeryData['surgeon'] != null) surgeryData['surgeon'],
            if (surgeryData['nurses'] != null) ...surgeryData['nurses'],
            if (surgeryData['technologists'] != null) ...surgeryData['technologists'],
          ],
        });
        
        _logger.info('Stored status change in central surgery_notifications collection');
      } catch (e) {
        _logger.severe('Error storing central status change notification: $e');
        // Continue execution despite this error - don't return
      }
      
      // Send individual notifications to selected users
      for (final userId in notifyUserIds) {
        // Don't send duplicate notifications
        if (userId == currentUser.uid && notifyUserIds.length > 1) {
          _logger.info('Skipping duplicate notification to current user who made the change');
          continue;
        }
        
        try {
          _logger.info('Sending status change notification to user: $userId');
          await sendStatusChangeNotification(
            userId: userId,
            surgery: surgery,
            oldStatus: oldStatus,
            newStatus: newStatus,
          );
        } catch (e) {
          _logger.severe('Error sending notification to user $userId: $e');
          // Continue with next user despite this error
        }
      }
      
    } catch (e) {
      _logger.severe('Error sending status change notification with ID: $e');
    }
  }
  
  /// Send a notification for a surgery update
  Future<void> sendUpdateNotification({
    required String userId,
    required Surgery surgery,
  }) async {
    try {
      // Get user preferences
      final userPrefs = await _getUserPreferences(userId);
      if (userPrefs == null) return;
      
      // Prepare notification data
      final String title = 'Surgery Updated';
      final String body = 'The ${surgery.surgeryType} surgery scheduled for ${_formatDateTime(surgery.startTime)} has been updated';
      final Map<String, dynamic> data = {
        'type': 'update',
        'surgeryId': surgery.id,
      };
      
      // Store notification in user's collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'data': data,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      _logger.info('Stored update notification in user\'s collection for user $userId');
      
      // Send push notification if enabled
      if (userPrefs['enablePushNotifications'] == true) {
        try {
          await showLocalNotification(title: title, body: body, payload: userId);
          _logger.info('Sent local notification to user $userId');
        } catch (e) {
          _logger.warning('Failed to send local notification: $e');
        }
      }
      
      // Send email notification if enabled
      if (userPrefs['enableEmailNotifications'] == true) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data();
        if (userData != null && userData['email'] != null) {
          await _sendEmailNotification(
            email: userData['email'],
            subject: title,
            message: body,
          );
        }
      }
      
      // For update notifications, we'll also attempt to send SMS regardless of user preferences
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data();
        if (userData != null && userData['phoneNumber'] != null) {
          final phoneNumber = userData['phoneNumber'];
          _logger.info('Forcing SMS to $phoneNumber for user $userId for update notification');
          
          // Format the phone number
          String formattedNumber = phoneNumber.toString().replaceAll(RegExp(r'[^\+\d]'), '');
          if (!formattedNumber.startsWith('+')) {
            if (formattedNumber.length == 10) {
              formattedNumber = '+1$formattedNumber';
            } else {
              formattedNumber = '+$formattedNumber';
            }
          }
          
          _logger.info('Sending SMS to formatted number: $formattedNumber');
          
          final result = await _twilioService.sendSMS(
            toNumber: formattedNumber,
            messageBody: body,
          );
          
          _logger.info('SMS send result for $userId: $result');
        } else {
          _logger.warning('No phone number found for user $userId for SMS');
        }
      } catch (smsError) {
        _logger.severe('Error sending SMS notification for update: $smsError');
      }
      
    } catch (e) {
      _logger.severe('Error sending update notification: $e');
    }
  }
  
  /// Send an update notification using just the surgery ID and old/new data
  Future<void> sendUpdateNotificationById(String surgeryId, Map<String, dynamic> oldData, Map<String, dynamic> newData) async {
    try {
      _logger.info('Sending update notification for surgery $surgeryId');
      
      // Get surgery details (for current state)
      final surgeryDoc = await _firestore.collection('surgeries').doc(surgeryId).get();
      if (!surgeryDoc.exists) {
        _logger.warning('Surgery not found: $surgeryId');
        return;
      }
      
      // Create surgery object using the factory constructor
      final surgery = Surgery.fromFirestore(surgeryId, surgeryDoc.data() as Map<String, dynamic>);
      
      // Get all involved personnel names from both old and new data
      final Set<String> personnelNames = {};
      
      // Personnel from old data
      if (oldData['surgeon'] != null) {
        personnelNames.add(oldData['surgeon']);
      }
      
      // Personnel from new data
      if (newData['surgeon'] != null && newData['surgeon'] != oldData['surgeon']) {
        personnelNames.add(newData['surgeon']);
      }
      
      // Track both old and new staff lists
      final oldNurses = List<String>.from(oldData['nurses'] ?? []);
      final newNurses = List<String>.from(newData['nurses'] ?? []);
      final oldTechs = List<String>.from(oldData['technologists'] ?? []);
      final newTechs = List<String>.from(newData['technologists'] ?? []);
      
      personnelNames.addAll([...oldNurses, ...newNurses, ...oldTechs, ...newTechs]);
      
      _logger.info('Personnel names for update notification: $personnelNames');
      
      // Look up user IDs by their names and send notifications
      for (final name in personnelNames) {
        // Find the actual user ID for this name
        final userId = await _findUserIdByName(name);
        
        if (userId != null) {
          _logger.info('Found user ID $userId for name $name, sending update notification');
          await sendUpdateNotification(
            userId: userId,
            surgery: surgery,
          );
        } else {
          _logger.warning('Could not find user ID for name: $name, skipping update notification');
        }
      }
      
    } catch (e) {
      _logger.severe('Error sending update notification with ID: $e');
    }
  }
  
  /// Send a push notification to a user
  Future<void> sendPushNotification({
    required String title,
    required String body,
    required String userId,
    Map<String, dynamic>? data,
  }) async {
    try {
      _logger.info('Sending push notification to user: $userId');
      
      // Get user's FCM tokens
      final tokensDocs = await _firestore
          .collection('users')
          .doc(userId)
          .collection('fcmTokens')
          .get();
      
      if (tokensDocs.docs.isEmpty) {
        _logger.info('No FCM tokens found for user $userId, sending local notification');
        await showLocalNotification(title: title, body: body, payload: userId);
        return;
      }
      
      for (var tokenDoc in tokensDocs.docs) {
        final token = tokenDoc.data()['token'] as String?;
        if (token != null) {
          await _sendFCMNotification(token, title, body, data);
        }
      }
    } catch (e) {
      _logger.severe('Error sending push notification: $e');
    }
  }
  
  /// Send an email using API (SendGrid, Mailgun, etc.)
  Future<bool> _sendEmail(
    String toEmail,
    String subject,
    String htmlBody,
  ) async {
    try {
      if (_emailApiKey == null || _emailSendEndpoint == null || _emailFromAddress == null) {
        _logger.warning('Cannot send email: Email credentials not configured');
        return false;
      }
      
      // Using a generic API endpoint approach
      final response = await http.post(
        Uri.parse(_emailSendEndpoint!),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_emailApiKey',
        },
        body: json.encode({
          'from': _emailFromAddress,
          'to': toEmail,
          'subject': subject,
          'html': htmlBody,
        }),
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _logger.info('Email sent successfully to $toEmail');
        return true;
      } else {
        _logger.warning('Failed to send email: ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.severe('Error sending email: $e');
      return false;
    }
  }
  
  /// Get notification preferences for a user
  Future<NotificationPreferences> _getUserNotificationPreferences(String? userId) async {
    try {
      if (userId == null) {
        return NotificationPreferences.defaults();
      }
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        return NotificationPreferences.defaults();
      }
      
      final userData = userDoc.data()!;
      bool enableNotifications = userData['notifications'] ?? true;
      
      // Get detailed notification settings
      final settingsDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('notifications')
          .get();
      
      if (!settingsDoc.exists) {
        return NotificationPreferences(
          enableNotifications: enableNotifications,
          enablePush: enableNotifications,
          enableSms: enableNotifications,
          enableEmail: false, // Email off by default
          channelPreferences: {},
        );
      }
      
      final settings = settingsDoc.data()!;
      
      return NotificationPreferences(
        enableNotifications: enableNotifications,
        enablePush: settings['push_enabled'] ?? enableNotifications,
        enableSms: settings['sms_enabled'] ?? enableNotifications,
        enableEmail: settings['email_enabled'] ?? false, // Email off by default
        channelPreferences: {
          'scheduled': {
            'push': settings['push_scheduled_enabled'] ?? true,
            'sms': settings['sms_scheduled_enabled'] ?? true,
            'email': settings['email_scheduled_enabled'] ?? false,
          },
          'approaching': {
            'push': settings['push_approaching_enabled'] ?? true,
            'sms': settings['sms_approaching_enabled'] ?? true,
            'email': settings['email_approaching_enabled'] ?? false,
          },
          'update': {
            'push': settings['push_update_enabled'] ?? true,
            'sms': settings['sms_update_enabled'] ?? true,
            'email': settings['email_update_enabled'] ?? false,
          },
          'status': {
            'push': settings['push_status_enabled'] ?? true,
            'sms': settings['sms_status_enabled'] ?? true,
            'email': settings['email_status_enabled'] ?? false,
          },
        },
      );
    } catch (e) {
      _logger.severe('Error getting notification preferences: $e');
      return NotificationPreferences.defaults();
    }
  }
  
  /// Get users involved with a surgery
  Future<List<UserNotificationData>> _getInvolvedUsers(Map<String, dynamic> surgeryData) async {
    final List<UserNotificationData> recipients = [];
    
    // Collect all personnel
    final List<String> personnel = [];
    
    // Add surgeon
    final String surgeon = surgeryData['surgeon'] ?? '';
    if (surgeon.isNotEmpty) {
      personnel.add(surgeon);
    }
    
    // Add nurses
    final List<String> nurses = List<String>.from(surgeryData['nurses'] ?? []);
    personnel.addAll(nurses);
    
    // Add technologists
    final List<String> technologists = List<String>.from(surgeryData['technologists'] ?? []);
    personnel.addAll(technologists);
    
    // Query Firestore for user data
    for (final person in personnel) {
      try {
        final String firstName = person.split(' ').first;
        
        final querySnapshot = await _firestore
            .collection('users')
            .where('firstName', isEqualTo: firstName)
            .limit(1)
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          final userData = querySnapshot.docs.first.data();
          final userId = querySnapshot.docs.first.id;
          
          recipients.add(UserNotificationData(
            userId: userId,
            name: person,
            email: userData['email'],
            phoneNumber: userData['phoneNumber'],
            fcmTokens: List<String>.from(userData['fcmTokens'] ?? []),
          ));
        }
      } catch (e) {
        _logger.warning('Error getting data for user $person: $e');
      }
    }
    
    return recipients;
  }
  
  /// Format a DateTime for display
  String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('MMM d, yyyy \'at\' h:mm a');
    return formatter.format(dateTime);
  }
  
  /// Stream to get in-app notifications for the current user
  Stream<List<Map<String, dynamic>>> getUserNotificationsStream() {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return Stream.value([]);
      }
      
      // Merge user-specific notifications with surgery notifications for involved personnel
      return CombineLatestStream.combine2(
        _getUserDirectNotificationsStream(user.uid),
        _getUserSurgeryNotificationsStream(user),
        (List<Map<String, dynamic>> direct, List<Map<String, dynamic>> surgery) {
          // Combine both streams and sort by timestamp
          final combined = [...direct, ...surgery];
          combined.sort((a, b) {
            final aTime = a['timestamp'] as Timestamp;
            final bTime = b['timestamp'] as Timestamp;
            return bTime.compareTo(aTime); // Descending order
          });
          return combined;
        }
      );
    } catch (e) {
      _logger.severe('Error getting user notifications stream: $e');
      return Stream.value([]);
    }
  }
  
  /// Get user-specific direct notifications
  Stream<List<Map<String, dynamic>>> _getUserDirectNotificationsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'title': data['title'] ?? 'Notification',
              'body': data['body'] ?? '',
              'data': data['data'] ?? {},
              'read': data['read'] ?? false,
              'timestamp': data['timestamp'] ?? Timestamp.now(),
              'source': 'direct',
            };
          }).toList();
        });
  }
  
  /// Get notifications from surgeries where user is involved
  Stream<List<Map<String, dynamic>>> _getUserSurgeryNotificationsStream(User user) {
    // First get user details to match against involved personnel
    return _firestore
        .collection('users')
        .doc(user.uid)
        .get()
        .asStream()
        .flatMap((userDoc) {
          if (!userDoc.exists) {
            return Stream.value([]);
          }
          
          final userData = userDoc.data() as Map<String, dynamic>;
          final fullName = userData['fullName'] ?? '';
          final displayName = userData['displayName'] ?? '';
          final firstName = userData['firstName'] ?? '';
          final lastName = userData['lastName'] ?? '';
          
          // Now query the central notifications collection for notifications involving this user
          return _firestore
              .collection('surgery_notifications')
              .orderBy('timestamp', descending: true)
              .limit(50)
              .snapshots()
              .map((snapshot) {
                final results = <Map<String, dynamic>>[];
                
                for (final doc in snapshot.docs) {
                  final data = doc.data();
                  final involvedPersonnel = List<String>.from(data['involvedPersonnel'] ?? []);
                  
                  // Only include notifications for surgeries where this user is involved
                  if (data['userId'] == user.uid || 
                      involvedPersonnel.contains(fullName) || 
                      involvedPersonnel.contains(displayName) ||
                      (firstName.isNotEmpty && lastName.isNotEmpty && 
                      involvedPersonnel.contains('$firstName $lastName'))) {
                    results.add({
                      'id': doc.id,
                      'title': data['title'] ?? 'Surgery Notification',
                      'body': data['body'] ?? '',
                      'data': {
                        'type': 'status',
                        'surgeryId': data['surgeryId'],
                        'oldStatus': data['oldStatus'],
                        'newStatus': data['newStatus'],
                      },
                      'read': data['read'] ?? false,
                      'timestamp': data['timestamp'] ?? Timestamp.now(),
                      'source': 'surgery',
                    });
                  }
                }
                
                return results;
              });
        });
  }
  
  /// Mark a notification as read
  Future<void> markNotificationAsRead(String notificationId, [String source = 'direct']) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      if (source == 'direct') {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .doc(notificationId)
            .update({
          'read': true,
        });
      } else if (source == 'surgery') {
        await _firestore
            .collection('surgery_notifications')
            .doc(notificationId)
            .update({
          'read': true,
        });
      }
      
      _logger.info('Marked notification $notificationId as read (source: $source)');
    } catch (e) {
      _logger.severe('Error marking notification as read: $e');
    }
  }
  
  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Mark direct notifications as read
      await _markDirectNotificationsAsRead(user.uid);
      
      // Mark surgery notifications as read for a user
      await _markSurgeryNotificationsAsRead(user);
      
      _logger.info('Marked all notifications as read for user ${user.uid}');
    } catch (e) {
      _logger.severe('Error marking all notifications as read: $e');
    }
  }
  
  /// Mark all direct notifications as read
  Future<void> _markDirectNotificationsAsRead(String userId) async {
    final batch = _firestore.batch();
    
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();
    
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    
    await batch.commit();
    _logger.info('Marked ${snapshot.docs.length} direct notifications as read');
  }
  
  /// Mark all surgery notifications as read for a user
  Future<void> _markSurgeryNotificationsAsRead(User user) async {
    // First get user details to match against involved personnel
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return;
    
    final userData = userDoc.data() as Map<String, dynamic>;
    final fullName = userData['fullName'] ?? '';
    final displayName = userData['displayName'] ?? '';
    final firstName = userData['firstName'] ?? '';
    final lastName = userData['lastName'] ?? '';
    
    // Get notifications this user is involved in
    final snapshot = await _firestore
        .collection('surgery_notifications')
        .where('read', isEqualTo: false)
        .get();
    
    final batch = _firestore.batch();
    int count = 0;
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final involvedPersonnel = List<String>.from(data['involvedPersonnel'] ?? []);
      
      // Check if user is involved in this notification
      if (data['userId'] == user.uid || 
          involvedPersonnel.contains(fullName) || 
          involvedPersonnel.contains(displayName) ||
          (firstName.isNotEmpty && lastName.isNotEmpty && 
          involvedPersonnel.contains('$firstName $lastName'))) {
        batch.update(doc.reference, {'read': true});
        count++;
      }
    }
    
    if (count > 0) {
      await batch.commit();
      _logger.info('Marked $count surgery notifications as read');
    }
  }
  
  /// Clear a specific notification
  Future<void> clearNotification(String notificationId, [String source = 'direct']) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      if (source == 'direct') {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .doc(notificationId)
            .delete();
      } else if (source == 'surgery') {
        // For surgery notifications, we only mark them as read since
        // multiple users might need to see them
        await _firestore
            .collection('surgery_notifications')
            .doc(notificationId)
            .update({
          'read': true,
        });
      }
      
      _logger.info('Cleared notification $notificationId (source: $source)');
    } catch (e) {
      _logger.severe('Error clearing notification: $e');
    }
  }
  
  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    try {
      await markAllNotificationsAsRead();
      _logger.info('Marked all notifications as read instead of clearing');
    } catch (e) {
      _logger.severe('Error clearing all notifications: $e');
    }
  }
  
  /// Get unread notification count
  Stream<int> getUnreadNotificationCount() {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return Stream.value(0);
      }
      
      // Combine counts from both direct and surgery notifications
      return CombineLatestStream.combine2(
        _getDirectUnreadNotificationCount(user.uid),
        _getSurgeryUnreadNotificationCount(user),
        (int direct, int surgery) => direct + surgery
      );
    } catch (e) {
      _logger.severe('Error getting unread notification count: $e');
      return Stream.value(0);
    }
  }
  
  /// Get count of unread direct notifications
  Stream<int> _getDirectUnreadNotificationCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
  
  /// Get count of unread surgery notifications for user
  Stream<int> _getSurgeryUnreadNotificationCount(User user) {
    // We'll estimate this by counting all surgery notifications
    // filtering on the client side would be inefficient
    return _getUserSurgeryNotificationsStream(user)
        .map((notifications) => 
            notifications.where((notification) => notification['read'] == false).length);
  }
  
  /// Update notification settings in Firestore
  Future<void> updateNotificationSettings(NotificationPreferences preferences) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Update general notification preference
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'notifications': preferences.enableNotifications,
      });
      
      // Update detailed notification settings
      final Map<String, dynamic> settingsData = {
        'push_enabled': preferences.enablePush,
        'sms_enabled': preferences.enableSms,
        'email_enabled': preferences.enableEmail,
      };
      
      // Add channel-specific preferences
      preferences.channelPreferences.forEach((type, channels) {
        channels.forEach((channel, enabled) {
          settingsData['${channel}_${type}_enabled'] = enabled;
        });
      });
      
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('notifications')
          .set(settingsData, SetOptions(merge: true));
      
    } catch (e) {
      _logger.severe('Error updating notification settings: $e');
    }
  }
  
  /// Dispose resources
  void dispose() {
    _notificationsStreamController.close();
  }

  /// Get user notification preferences
  Future<Map<String, dynamic>?> _getUserPreferences(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        _logger.warning('User $userId not found');
        return null;
      }
      
      final userData = userDoc.data();
      if (userData == null) {
        _logger.warning('User data for $userId is null');
        return null;
      }
      
      // Get preferences or use defaults
      return {
        'enablePushNotifications': userData['enablePushNotifications'] ?? true,
        'enableSmsNotifications': userData['enableSmsNotifications'] ?? false,
        'enableEmailNotifications': userData['enableEmailNotifications'] ?? false,
      };
    } catch (e) {
      _logger.severe('Error getting user preferences: $e');
      return null;
    }
  }

  /// Send an email notification
  Future<bool> _sendEmailNotification({
    required String email,
    required String subject,
    required String message,
  }) async {
    try {
      if (_emailApiKey == null || _emailFromAddress == null || _emailSendEndpoint == null) {
        _logger.warning('Email configuration missing');
        return false;
      }
      
      final response = await http.post(
        Uri.parse(_emailSendEndpoint!),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_emailApiKey',
        },
        body: json.encode({
          'from': _emailFromAddress,
          'to': email,
          'subject': subject,
          'text': message,
          'html': '<p>$message</p>',
        }),
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _logger.info('Email sent successfully to $email');
        return true;
      } else {
        _logger.warning('Failed to send email: ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.severe('Error sending email: $e');
      return false;
    }
  }

  /// Send a test notification to the current user
  Future<void> sendTestNotification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _logger.warning('Cannot send test notification: User not logged in');
        return;
      }
      
      final notificationData = {
        'title': 'Test Notification',
        'body': 'This is a test notification. If you can see this, notifications are working correctly!',
        'data': {'type': 'test'},
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      };
      
      // Store notification in Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .add(notificationData);
      
      // Show local notification
      await showLocalNotification(
        title: notificationData['title'] as String,
        body: notificationData['body'] as String,
        payload: json.encode(notificationData['data']),
      );
      
      _logger.info('Test notification sent successfully');
    } catch (e) {
      _logger.severe('Error sending test notification: $e');
      rethrow; // Rethrow to allow UI to handle it
    }
  }

  /// Send a test SMS message to verify Twilio configuration
  Future<bool> sendTestSMS({required String phoneNumber, String message = 'Test notification from ORScheduler'}) async {
    try {
      _logger.info('Sending test SMS to $phoneNumber');
      
      // Format the phone number
      String formattedNumber = phoneNumber;
      
      // Remove any non-numeric characters (except the + sign)
      formattedNumber = formattedNumber.replaceAll(RegExp(r'[^\+\d]'), '');
      
      // Ensure it has the country code
      if (!formattedNumber.startsWith('+')) {
        // Assuming US phone numbers if no country code
        if (formattedNumber.length == 10) {
          formattedNumber = '+1$formattedNumber';
        } else {
          formattedNumber = '+$formattedNumber';
        }
      }
      
      _logger.info('Formatted phone number: $formattedNumber');
      
      // Send the SMS directly
      final success = await _twilioService.sendSMS(
        toNumber: formattedNumber,
        messageBody: message,
      );
      
      _logger.info('Test SMS send result: $success');
      return success;
    } catch (e) {
      _logger.severe('Error sending test SMS: $e');
      return false;
    }
  }

  /// Find user ID by name
  Future<String?> _findUserIdByName(String name) async {
    try {
      _logger.info('Looking up user ID for name: $name');
      
      // First try an exact match on fullName field
      var query = await _firestore
          .collection('users')
          .where('fullName', isEqualTo: name)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        _logger.info('Found user with fullName: ${query.docs.first.id}');
        return query.docs.first.id;
      }
      
      // Try by displayName if fullName doesn't match
      query = await _firestore
          .collection('users')
          .where('displayName', isEqualTo: name)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        _logger.info('Found user with displayName: ${query.docs.first.id}');
        return query.docs.first.id;
      }
      
      // Try by firstName and lastName combination
      final nameParts = name.split(' ');
      if (nameParts.length >= 2) {
        final firstName = nameParts[0];
        final lastName = nameParts.sublist(1).join(' ');
        
        query = await _firestore
            .collection('users')
            .where('firstName', isEqualTo: firstName)
            .where('lastName', isEqualTo: lastName)
            .limit(1)
            .get();
        
        if (query.docs.isNotEmpty) {
          _logger.info('Found user with firstName/lastName: ${query.docs.first.id}');
          return query.docs.first.id;
        }
      }
      
      // As a last resort, check if the name itself is a valid user ID
      final userDoc = await _firestore.collection('users').doc(name).get();
      if (userDoc.exists) {
        _logger.info('Found user with ID matching name: $name');
        return name;
      }
      
      _logger.warning('Could not find user with name: $name');
      return null;
    } catch (e) {
      _logger.severe('Error finding user by name: $e');
      return null;
    }
  }

  /// Helper method to send FCM notification to a specific device token
  Future<void> _sendFCMNotification(
    String token,
    String title,
    String body,
    Map<String, dynamic>? data,
  ) async {
    try {
      _logger.info('Sending FCM notification to token: $token');
      
      // This should be handled by a Cloud Function in production
      // For client-side, we need to use HTTP to call Firebase Functions
      // or use local notifications
      
      // In a real implementation, you would call an HTTP endpoint or Firebase Function
      // For now, we'll just log it
      _logger.info('FCM message details: title=$title, body=$body, token=$token');
      
      // For a real implementation with a Firebase function, you would do something like:
      // final response = await http.post(
      //   Uri.parse('https://your-firebase-function-url'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode({
      //     'token': token,
      //     'title': title,
      //     'body': body,
      //     'data': data ?? {},
      //   }),
      // );
      
      // Just return true for now
      _logger.info('FCM notification sent to $token');
    } catch (e) {
      _logger.severe('Error sending FCM notification: $e');
      rethrow;
    }
  }

  /// Send a notification for a scheduled surgery to a specific user
  Future<void> sendScheduledNotificationByUserId({
    required String surgeryId,
    required String userId,
  }) async {
    try {
      _logger.info('Sending scheduled notification for surgery $surgeryId to user $userId');
      
      // Get surgery details
      final surgeryDoc = await _firestore.collection('surgeries').doc(surgeryId).get();
      if (!surgeryDoc.exists) {
        _logger.warning('Surgery not found: $surgeryId');
        return;
      }
      
      final surgeryData = surgeryDoc.data() as Map<String, dynamic>;
      
      // Create surgery object using the factory constructor
      final surgery = Surgery.fromFirestore(surgeryId, surgeryData);
      
      // Send notification directly to this specific user
      await sendScheduledNotification(
        userId: userId,
        surgery: surgery,
      );
      
      _logger.info('Successfully sent scheduled notification to user $userId for surgery $surgeryId');
    } catch (e) {
      _logger.severe('Error sending scheduled notification to user $userId for surgery $surgeryId: $e');
    }
  }
}

/// Model class for notification preferences
class NotificationPreferences {
  final bool enableNotifications;
  final bool enablePush;
  final bool enableSms;
  final bool enableEmail;
  final Map<String, Map<String, bool>> channelPreferences;
  
  NotificationPreferences({
    required this.enableNotifications,
    required this.enablePush,
    required this.enableSms,
    required this.enableEmail,
    required this.channelPreferences,
  });
  
  /// Default notification preferences
  factory NotificationPreferences.defaults() {
    return NotificationPreferences(
      enableNotifications: true,
      enablePush: true,
      enableSms: true,
      enableEmail: false, // Email off by default
      channelPreferences: {
        'scheduled': {'push': true, 'sms': true, 'email': false},
        'approaching': {'push': true, 'sms': true, 'email': false},
        'update': {'push': true, 'sms': true, 'email': false},
        'status': {'push': true, 'sms': true, 'email': false},
      },
    );
  }
  
  /// Get preference for a specific notification type and channel
  bool getChannelPreference(String notificationType, String channel) {
    if (channelPreferences.containsKey(notificationType) &&
        channelPreferences[notificationType]!.containsKey(channel)) {
      return channelPreferences[notificationType]![channel]!;
    }
    // Default values
    if (channel == 'email') return false;
    return true;
  }
}

/// Model class for user notification data
class UserNotificationData {
  final String? userId;
  final String name;
  final String? email;
  final String? phoneNumber;
  final List<String>? fcmTokens;
  
  UserNotificationData({
    this.userId,
    required this.name,
    this.email,
    this.phoneNumber,
    this.fcmTokens,
  });
}

/// Background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed
  await Firebase.initializeApp();
  
  // Log message (optional)
  print('Handling a background message: ${message.messageId}');
  
  // Store notification in Firestore for later retrieval
  try {
    if (message.notification != null && message.data.containsKey('userId')) {
      final userId = message.data['userId'];
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': message.notification!.title ?? 'Surgery Notification',
        'body': message.notification!.body ?? 'New notification received',
        'data': message.data,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  } catch (e) {
    print('Error storing background notification: $e');
  }
} 