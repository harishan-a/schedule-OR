/// A screen that manages user preferences and settings with real-time synchronization.
///
/// This screen provides:
/// - Theme customization (dark mode, high contrast, text size)
/// - Notification preferences with Firebase Messaging integration
/// - User profile management with Firestore
/// - Settings persistence using both SharedPreferences (local) and Firestore (cloud)
///
/// The settings are stored in two places:
/// 1. SharedPreferences: For immediate theme access on app startup
/// 2. Firestore: For cloud sync and cross-device consistency
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_orscheduler/shared/widgets/custom_navigation_bar.dart';
import 'package:firebase_orscheduler/shared/theme/app_theme.dart';
import 'package:firebase_orscheduler/features/schedule/screens/resource_check_screen.dart';
import 'package:firebase_orscheduler/services/notification_manager.dart';

class SettingsScreen extends StatefulWidget {
  final bool isTestMode;
  const SettingsScreen({
    Key? key,
    this.isTestMode = false,
  }) : super(key: key);


  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Firebase and SharedPreferences instances
  FirebaseAuth? _auth;             // CHANGED
  FirebaseFirestore? _firestore;   // CHANGED
  FirebaseMessaging? _messaging;   // CHANGED
  late SharedPreferences _prefs;

  // Theme and accessibility settings
  bool _isDarkMode = false;
  bool _useHighContrast = false;
  bool _useLargeText = false;

  // Notification and sound preferences
  bool _enableNotifications = true;
  bool _enableSoundEffects = true;
  
  // SMS notification preferences
  bool _enableSmsNotifications = true;
  bool _enableSmsScheduledNotifications = true;
  bool _enableSmsApproachingNotifications = true;
  bool _enableSmsUpdateNotifications = true;
  bool _enableSmsStatusNotifications = true;
  
  // Push notification preferences
  bool _enablePushNotifications = true;
  bool _enablePushScheduledNotifications = true;
  bool _enablePushApproachingNotifications = true;
  bool _enablePushUpdateNotifications = true;
  bool _enablePushStatusNotifications = true;
  
  // Email notification preferences
  bool _enableEmailNotifications = false;
  bool _enableEmailScheduledNotifications = false;
  bool _enableEmailApproachingNotifications = false;
  bool _enableEmailUpdateNotifications = false;
  bool _enableEmailStatusNotifications = false;

  // Loading and user data state
  bool _isLoading = true;
  Map<String, dynamic> _userProfile = {};
  
  // Notification manager
  final NotificationManager _notificationManager = NotificationManager();

  @override
  void initState() {
    super.initState();
    if (!widget.isTestMode) {
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _messaging = FirebaseMessaging.instance;
    }

    _initializeSettings();
  }

  /// Initializes settings from both SharedPreferences and Firestore.
  ///
  /// Order of operations:
  /// 1. Get SharedPreferences instance
  /// 2. Load user profile from Firestore
  /// 3. Load settings from Firestore
  /// 4. Apply theme preferences from SharedPreferences
  Future<void> _initializeSettings() async {
    try {
      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();

      if (widget.isTestMode || _auth == null) {
        setState(() {
          // Load local or default settings only.
          _isDarkMode = _prefs.getBool('darkMode') ?? false;
          _useLargeText = _prefs.getBool('largeText') ?? false;
          _useHighContrast = _prefs.getBool('highContrast') ?? false;
          _enableNotifications = true;
          _enableSoundEffects = true;
        });
      }else {
        final user = _auth!.currentUser;

        if (user != null) {
          // Load user profile from Firestore
          final profileDoc =
          await _firestore!.collection('users').doc(user.uid).get();
          _userProfile = profileDoc.data() ?? {};

          // Load settings from Firestore for cloud-synced preferences
          final settingsDoc = await _firestore!
              .collection('users')
              .doc(user.uid)
              .collection('settings')
              .doc('preferences')
              .get();
              
          // Load notification settings specifically
          final notificationSettingsDoc = await _firestore!
              .collection('users')
              .doc(user.uid)
              .collection('settings')
              .doc('notifications')
              .get();

          // Load theme preferences from SharedPreferences for immediate access
          setState(() {
            _isDarkMode = _prefs.getBool('darkMode') ?? false;
            _useLargeText = _prefs.getBool('largeText') ?? false;
            _useHighContrast = _prefs.getBool('highContrast') ?? false;

            // Apply cloud settings if they exist
            if (settingsDoc.exists) {
              final data = settingsDoc.data() ?? {};
              _enableNotifications = data['notifications'] ?? true;
              _enableSoundEffects = data['soundEffects'] ?? true;
            }
            
            // Apply notification settings
            if (notificationSettingsDoc.exists) {
              final data = notificationSettingsDoc.data() ?? {};
              
              // SMS settings
              _enableSmsNotifications = data['sms_enabled'] ?? true;
              _enableSmsScheduledNotifications = data['sms_scheduled_enabled'] ?? true;
              _enableSmsApproachingNotifications = data['sms_approaching_enabled'] ?? true;
              _enableSmsUpdateNotifications = data['sms_update_enabled'] ?? true;
              _enableSmsStatusNotifications = data['sms_status_enabled'] ?? true;
              
              // Push settings
              _enablePushNotifications = data['push_enabled'] ?? true;
              _enablePushScheduledNotifications = data['push_scheduled_enabled'] ?? true;
              _enablePushApproachingNotifications = data['push_approaching_enabled'] ?? true;
              _enablePushUpdateNotifications = data['push_update_enabled'] ?? true;
              _enablePushStatusNotifications = data['push_status_enabled'] ?? true;
              
              // Email settings
              _enableEmailNotifications = data['email_enabled'] ?? false;
              _enableEmailScheduledNotifications = data['email_scheduled_enabled'] ?? false;
              _enableEmailApproachingNotifications = data['email_approaching_enabled'] ?? false;
              _enableEmailUpdateNotifications = data['email_update_enabled'] ?? false;
              _enableEmailStatusNotifications = data['email_status_enabled'] ?? false;
            }
          });
        }
      }
    } catch (e) {
      // Error handling is kept minimal as settings will use defaults
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Applies theme settings through the AppTheme provider.
  /// This method should be called whenever theme settings change.
  void _applyThemeSettings() {
    if (!mounted) return;
    if (widget.isTestMode) {
      // Skip calling AppTheme.of(context) in test mode
      return;
    }
    final appTheme = AppTheme.of(context);
    appTheme.updateTheme(_isDarkMode, _useLargeText, _useHighContrast);
  }

  /// Saves all settings to both SharedPreferences and Firestore.
  /// Also handles notification permissions and theme updates.
  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    try {
      await _prefs.setBool('darkMode', _isDarkMode);
      await _prefs.setBool('largeText', _useLargeText);
      await _prefs.setBool('highContrast', _useHighContrast);

      if (!widget.isTestMode && _auth != null) {
        final user = _auth!.currentUser;
        if (user != null) {

          await _firestore!
              .collection('users')
              .doc(user.uid)
              .collection('settings')
              .doc('preferences')
              .set({
            'darkMode': _isDarkMode,
            'highContrast': _useHighContrast,
            'largeText': _useLargeText,
            'notifications': _enableNotifications,
            'soundEffects': _enableSoundEffects,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // Handle notification permissions and topic subscription
          if (_enableNotifications) {
            final settings = await _messaging!.requestPermission();
            if (settings.authorizationStatus == AuthorizationStatus.authorized) {
              try {
                final notificationManager = NotificationManager();
                
                if (Platform.isIOS) {
                  // On iOS, we need to wait for APNS token before subscribing to topics
                  await Future.delayed(const Duration(seconds: 2));
                  final apnsToken = await _messaging!.getAPNSToken();
                  if (apnsToken != null) {
                    await notificationManager.subscribeToTopic('app_notifications');
                  }
                } else {
                  // Android platform
                  await notificationManager.subscribeToTopic('app_notifications');
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error enabling notifications: $e'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            }
          } else {
            try {
              final notificationManager = NotificationManager();
              await notificationManager.unsubscribeFromTopic('app_notifications');
            } catch (e) {
              // Handle error silently
            }
          }

          // Apply theme settings immediately
          _applyThemeSettings();

          // Save notification settings in a separate document
          final notificationSettings = {
            // SMS notification settings
            'sms_enabled': _enableSmsNotifications,
            'sms_scheduled_enabled': _enableSmsScheduledNotifications,
            'sms_approaching_enabled': _enableSmsApproachingNotifications,
            'sms_update_enabled': _enableSmsUpdateNotifications,
            'sms_status_enabled': _enableSmsStatusNotifications,
            
            // Push notification settings
            'push_enabled': _enablePushNotifications,
            'push_scheduled_enabled': _enablePushScheduledNotifications,
            'push_approaching_enabled': _enablePushApproachingNotifications,
            'push_update_enabled': _enablePushUpdateNotifications,
            'push_status_enabled': _enablePushStatusNotifications,
            
            // Email notification settings
            'email_enabled': _enableEmailNotifications,
            'email_scheduled_enabled': _enableEmailScheduledNotifications,
            'email_approaching_enabled': _enableEmailApproachingNotifications,
            'email_update_enabled': _enableEmailUpdateNotifications,
            'email_status_enabled': _enableEmailStatusNotifications,
            
            'lastUpdated': FieldValue.serverTimestamp(),
          };
          
          await _firestore!
              .collection('users')
              .doc(user.uid)
              .collection('settings')
              .doc('notifications')
              .set(notificationSettings, SetOptions(merge: true));
          
          // Update notification preferences through the NotificationManager
          final preferences = NotificationPreferences(
            enableNotifications: _enableNotifications,
            enablePush: _enablePushNotifications,
            enableSms: _enableSmsNotifications,
            enableEmail: _enableEmailNotifications,
            channelPreferences: {
              'scheduled': {
                'push': _enablePushScheduledNotifications,
                'sms': _enableSmsScheduledNotifications,
                'email': _enableEmailScheduledNotifications,
              },
              'approaching': {
                'push': _enablePushApproachingNotifications,
                'sms': _enableSmsApproachingNotifications,
                'email': _enableEmailApproachingNotifications,
              },
              'update': {
                'push': _enablePushUpdateNotifications,
                'sms': _enableSmsUpdateNotifications,
                'email': _enableEmailUpdateNotifications,
              },
              'status': {
                'push': _enablePushStatusNotifications,
                'sms': _enableSmsStatusNotifications,
                'email': _enableEmailStatusNotifications,
              },
            },
          );
          
          await _notificationManager.updateNotificationSettings(preferences);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Settings saved successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        _applyThemeSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings saved locally'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Shows a dialog for editing user profile information.
  /// Updates are saved to Firestore and reflected in the UI.
  Future<void> _editProfile() async {
    final TextEditingController nameController = TextEditingController(text: _userProfile['name']);
    final TextEditingController phoneController = TextEditingController(text: _userProfile['phone']);
    final TextEditingController emailController = TextEditingController(text: _userProfile['email']);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email Address'),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                if (!widget.isTestMode && _auth != null) {
                final user = _auth!.currentUser;
                if (user != null) {
                  await _firestore!
                      .collection('users')
                      .doc(user.uid)
                      .update({
                    'name': nameController.text.trim(),
                    'phone': phoneController.text.trim(),
                    'email': emailController.text.trim(),
                    'lastUpdated': FieldValue.serverTimestamp(),
                  });

                  setState(() {
                    _userProfile['name'] = nameController.text.trim();
                    _userProfile['phone'] = phoneController.text.trim();
                    _userProfile['email'] = emailController.text.trim();
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              } else{
                  setState(() {
                    _userProfile['name'] = nameController.text.trim();
                    _userProfile['phone'] = phoneController.text.trim();
                    _userProfile['email'] = emailController.text.trim();
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated locally'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update profile: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Sends a test notification to the current user
  Future<void> _sendTestNotification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to test notifications')),
        );
        return;
      }
      
      // Use the notification manager to send a test notification
      final notificationManager = NotificationManager();
      await notificationManager.sendTestNotification();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification sent successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending test notification: $e')),
      );
    }
  }

  /// Test SMS notification
  Future<void> _testSMSNotification() async {
    try {
      final currentUser = _auth?.currentUser;
      if (currentUser == null) {
        _showSnackBar('Please sign in to test notifications');
        return;
      }
      
      // Get user phone number from Firestore
      final userDoc = await _firestore?.collection('users').doc(currentUser.uid).get();
      final userData = userDoc?.data();
      
      if (userData == null || userData['phoneNumber'] == null) {
        _showSnackBar('No phone number found. Please update your profile.');
        return;
      }
      
      final phoneNumber = userData['phoneNumber'];
      
      // Show loading dialog
      _showLoadingDialog('Sending test SMS...');
      
      // Send test SMS
      final result = await _notificationManager.sendTestSMS(
        phoneNumber: phoneNumber,
        message: 'Test notification from ORScheduler: ${DateTime.now().toString()}',
      );
      
      // Hide loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      // Show result
      if (result) {
        _showSnackBar('Test SMS sent successfully');
      } else {
        _showSnackBar('Failed to send test SMS. Check logs for details.');
      }
    } catch (e) {
      // Hide loading dialog if still showing
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      _showSnackBar('Error sending test SMS: $e');
    }
  }
  
  /// Test push notification
  Future<void> _testPushNotification() async {
    try {
      final currentUser = _auth?.currentUser;
      if (currentUser == null) {
        _showSnackBar('Please sign in to test notifications');
        return;
      }
      
      // Show loading dialog
      _showLoadingDialog('Sending test push notification...');
      
      // Send test push notification via local notification
      await _notificationManager.sendPushNotification(
        title: 'Test Notification',
        body: 'This is a test notification from ORScheduler: ${DateTime.now().toString()}',
        userId: currentUser.uid,
      );
      
      // Hide loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      _showSnackBar('Test push notification sent');
    } catch (e) {
      // Hide loading dialog if still showing
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      _showSnackBar('Error sending test push notification: $e');
    }
  }
  
  /// Show a loading dialog
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
  
  /// Show a snackbar with a message
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          // Quick Actions Section
          _buildSection(
            'Quick Actions',
            [
              ListTile(
                leading: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Resource Check'),
                subtitle: const Text('Check availability of rooms and staff'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ResourceCheckScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.notifications_active,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Send Test Notification'),
                subtitle: const Text('Test the notification system'),
                trailing: const Icon(Icons.send),
                onTap: _sendTestNotification,
              ),
            ],
          ),
          // Theme Settings Section
          _buildSection(
            'Appearance',
            [
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Use dark theme throughout the app'),
                value: _isDarkMode,
                onChanged: (value) {
                  setState(() {
                    _isDarkMode = value;
                    _applyThemeSettings();
                  });
                },
                secondary: Icon(
                  _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SwitchListTile(
                title: const Text('High Contrast'),
                subtitle: const Text('Increase contrast for better visibility'),
                value: _useHighContrast,
                onChanged: (value) {
                  setState(() {
                    _useHighContrast = value;
                    _applyThemeSettings();
                  });
                },
                secondary: Icon(
                  Icons.contrast,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SwitchListTile(
                title: const Text('Large Text'),
                subtitle: const Text('Increase text size for better reading'),
                value: _useLargeText,
                onChanged: (value) {
                  setState(() {
                    _useLargeText = value;
                    _applyThemeSettings();
                  });
                },
                secondary: Icon(
                  Icons.text_fields,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          // Main Notification Settings Section
          _buildSection(
            'Notifications',
            [
              SwitchListTile(
                title: const Text('Enable Notifications'),
                subtitle: const Text('Receive updates about surgeries and schedules'),
                value: _enableNotifications,
                onChanged: (value) async {
                  setState(() => _enableNotifications = value);
                  if (!widget.isTestMode && _messaging != null) {
                    if (value) {
                      final settings = await _messaging!.requestPermission();
                      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
                        setState(() => _enableNotifications = value);
                        await _saveSettings();
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enable notifications in your device settings'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      }
                    }else{
                      await _saveSettings();
                    }
                  } else {
                    setState(() => _enableNotifications = value);
                    await _saveSettings();
                  }
                },
                secondary: Icon(
                  _enableNotifications ? Icons.notifications_active : Icons.notifications_off,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SwitchListTile(
                title: const Text('Sound Effects'),
                subtitle: const Text('Play sounds for important notifications'),
                value: _enableSoundEffects,
                onChanged: _enableNotifications
                    ? (value) {
                  setState(() => _enableSoundEffects = value);
                  _saveSettings();
                }
                    : null,
                secondary: Icon(
                  Icons.volume_up,
                  color: _enableNotifications
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              ),
            ],
          ),
          // Push Notification Settings Section
          _buildSection(
            'Push Notifications',
            [
              SwitchListTile(
                title: const Text('Enable Push Notifications'),
                subtitle: const Text('Receive in-app notifications'),
                value: _enablePushNotifications,
                onChanged: _enableNotifications ? (value) async {
                  setState(() => _enablePushNotifications = value);
                  await _saveSettings();
                } : null,
                secondary: Icon(
                  _enablePushNotifications ? Icons.notifications : Icons.notifications_off,
                  color: _enableNotifications ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
              ),
              SwitchListTile(
                title: const Text('Scheduled Surgeries'),
                subtitle: const Text('Notifications when surgeries are scheduled'),
                value: _enablePushScheduledNotifications,
                onChanged: (_enableNotifications && _enablePushNotifications) ? (value) async {
                  setState(() => _enablePushScheduledNotifications = value);
                  await _saveSettings();
                } : null,
                secondary: Icon(
                  Icons.event_available,
                  color: (_enableNotifications && _enablePushNotifications) 
                    ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
              ),
              SwitchListTile(
                title: const Text('Approaching Surgeries'),
                subtitle: const Text('Reminders for upcoming surgeries'),
                value: _enablePushApproachingNotifications,
                onChanged: (_enableNotifications && _enablePushNotifications) ? (value) async {
                  setState(() => _enablePushApproachingNotifications = value);
                  await _saveSettings();
                } : null,
                secondary: Icon(
                  Icons.alarm,
                  color: (_enableNotifications && _enablePushNotifications) 
                    ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
              ),
              SwitchListTile(
                title: const Text('Updates'),
                subtitle: const Text('Notifications when surgeries are updated'),
                value: _enablePushUpdateNotifications,
                onChanged: (_enableNotifications && _enablePushNotifications) ? (value) async {
                  setState(() => _enablePushUpdateNotifications = value);
                  await _saveSettings();
                } : null,
                secondary: Icon(
                  Icons.update,
                  color: (_enableNotifications && _enablePushNotifications) 
                    ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
              ),
              SwitchListTile(
                title: const Text('Status Changes'),
                subtitle: const Text('Notifications when surgery status changes'),
                value: _enablePushStatusNotifications,
                onChanged: (_enableNotifications && _enablePushNotifications) ? (value) async {
                  setState(() => _enablePushStatusNotifications = value);
                  await _saveSettings();
                } : null,
                secondary: Icon(
                  Icons.loop,
                  color: (_enableNotifications && _enablePushNotifications) 
                    ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
              ),
            ],
          ),
          // SMS Notification Settings Section
          _buildSection(
            'SMS Notifications',
            [
              SwitchListTile(
                title: const Text('Enable SMS Notifications'),
                subtitle: const Text('Receive text message notifications'),
                value: _enableSmsNotifications,
                onChanged: _enableNotifications ? (value) async {
                  setState(() => _enableSmsNotifications = value);
                  await _saveSettings();
                } : null,
                secondary: Icon(
                  _enableSmsNotifications ? Icons.sms : Icons.sms_failed,
                  color: _enableNotifications ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
              ),
              SwitchListTile(
                title: const Text('Scheduled Surgeries'),
                subtitle: const Text('SMS when surgeries are scheduled'),
                value: _enableSmsScheduledNotifications,
                onChanged: (_enableNotifications && _enableSmsNotifications) ? (value) async {
                  setState(() => _enableSmsScheduledNotifications = value);
                  await _saveSettings();
                } : null,
                secondary: Icon(
                  Icons.event_available,
                  color: (_enableNotifications && _enableSmsNotifications) 
                    ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
              ),
              SwitchListTile(
                title: const Text('Approaching Surgeries'),
                subtitle: const Text('SMS reminders for upcoming surgeries'),
                value: _enableSmsApproachingNotifications,
                onChanged: (_enableNotifications && _enableSmsNotifications) ? (value) async {
                  setState(() => _enableSmsApproachingNotifications = value);
                  await _saveSettings();
                } : null,
                secondary: Icon(
                  Icons.alarm,
                  color: (_enableNotifications && _enableSmsNotifications) 
                    ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
              ),
              SwitchListTile(
                title: const Text('Updates'),
                subtitle: const Text('SMS when surgeries are updated'),
                value: _enableSmsUpdateNotifications,
                onChanged: (_enableNotifications && _enableSmsNotifications) ? (value) async {
                  setState(() => _enableSmsUpdateNotifications = value);
                  await _saveSettings();
                } : null,
                secondary: Icon(
                  Icons.update,
                  color: (_enableNotifications && _enableSmsNotifications) 
                    ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
              ),
              SwitchListTile(
                title: const Text('Status Changes'),
                subtitle: const Text('SMS when surgery status changes'),
                value: _enableSmsStatusNotifications,
                onChanged: (_enableNotifications && _enableSmsNotifications) ? (value) async {
                  setState(() => _enableSmsStatusNotifications = value);
                  await _saveSettings();
                } : null,
                secondary: Icon(
                  Icons.loop,
                  color: (_enableNotifications && _enableSmsNotifications) 
                    ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
              ),
            ],
          ),
          // Email Notification Settings Section
          _buildSection(
            'Email Notifications',
            [
              SwitchListTile(
                title: const Text('Enable Email Notifications'),
                subtitle: const Text('Receive email notifications (recommended for important updates)'),
                value: _enableEmailNotifications,
                onChanged: _enableNotifications ? (value) async {
                  setState(() => _enableEmailNotifications = value);
                  await _saveSettings();
                } : null,
                secondary: Icon(
                  _enableEmailNotifications ? Icons.email : Icons.email_outlined,
                  color: _enableNotifications ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
              ),
              SwitchListTile(
                title: const Text('Scheduled Surgeries'),
                subtitle: const Text('Emails when surgeries are scheduled'),
                value: _enableEmailScheduledNotifications,
                onChanged: (_enableNotifications && _enableEmailNotifications) ? (value) async {
                  setState(() => _enableEmailScheduledNotifications = value);
                  await _saveSettings();
                } : null,
                secondary: Icon(
                  Icons.event_available,
                  color: (_enableNotifications && _enableEmailNotifications) 
                    ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
              ),
              SwitchListTile(
                title: const Text('Approaching Surgeries'),
                subtitle: const Text('Email reminders for upcoming surgeries'),
                value: _enableEmailApproachingNotifications,
                onChanged: (_enableNotifications && _enableEmailNotifications) ? (value) async {
                  setState(() => _enableEmailApproachingNotifications = value);
                  await _saveSettings();
                } : null,
                secondary: Icon(
                  Icons.alarm,
                  color: (_enableNotifications && _enableEmailNotifications) 
                    ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
              ),
              SwitchListTile(
                title: const Text('Updates'),
                subtitle: const Text('Emails when surgeries are updated'),
                value: _enableEmailUpdateNotifications,
                onChanged: (_enableNotifications && _enableEmailNotifications) ? (value) async {
                  setState(() => _enableEmailUpdateNotifications = value);
                  await _saveSettings();
                } : null,
                secondary: Icon(
                  Icons.update,
                  color: (_enableNotifications && _enableEmailNotifications) 
                    ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
              ),
              SwitchListTile(
                title: const Text('Status Changes'),
                subtitle: const Text('Emails when surgery status changes'),
                value: _enableEmailStatusNotifications,
                onChanged: (_enableNotifications && _enableEmailNotifications) ? (value) async {
                  setState(() => _enableEmailStatusNotifications = value);
                  await _saveSettings();
                } : null,
                secondary: Icon(
                  Icons.loop,
                  color: (_enableNotifications && _enableEmailNotifications) 
                    ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
              ),
            ],
          ),
          // Account Management Section
          _buildSection(
            'Account',
            [
              ListTile(
                leading: Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Edit Profile'),
                subtitle: Text(_userProfile['name'] ?? 'Update your profile'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _editProfile,
              ),
              ListTile(
                leading: Icon(
                  Icons.password,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Change Password'),
                subtitle: Text(_auth?.currentUser?.email ?? ''),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  try {
                    if(!widget.isTestMode && _auth != null){
                      await _auth!.sendPasswordResetEmail(
                        email: _auth!.currentUser?.email ?? '',
                      );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password reset email sent'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Test mode: no real email sent'),
                            backgroundColor: Colors.blueGrey,
                          ),
                        );
                      }
                  }
                }catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to send password reset email: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          // About Section
          _buildSection(
            'About',
            [
              ListTile(
                leading: Icon(
                  Icons.info,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Version'),
                subtitle: const Text('1.0.0'),
              ),
              ListTile(
                leading: Icon(
                  Icons.description,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLegalDocument('Terms of Service'),
              ),
              ListTile(
                leading: Icon(
                  Icons.privacy_tip,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLegalDocument('Privacy Policy'),
              ),
            ],
          ),
          // Add additional settings section
          Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.more_horiz,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Additional Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Test notification feature
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Test Notifications',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Send a test notification to verify your notification settings',
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.sms),
                                label: const Text('Test SMS'),
                                onPressed: () => _testSMSNotification(),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.notifications),
                                label: const Text('Test Push'),
                                onPressed: () => _testPushNotification(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Other settings cards...
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save),
                  SizedBox(width: 8),
                  Text('Save Settings'),
                ],
              ),
            ),
          ),
          CustomNavigationBar(
            currentIndex: 4,
            onTap: (index) {
              // Handle navigation
            },
          ),
        ],
      ),
    );
  }

  /// Builds a section in the settings screen with a title and list of widgets
  Widget _buildSection(String title, List<Widget> children, {IconData? icon}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) 
                  Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                if (icon != null) const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Shows a dialog with legal document content fetched from Firestore
  Future<void> _showLegalDocument(String title) async {
    try {
      if (widget.isTestMode || _firestore == null) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) =>
                AlertDialog(
                  title: Text(title),
                  content: const Text(
                      'Default legal document content (Test Mode)'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
          );
        }
        } else {
          final docRef = await _firestore!
              .collection('legal_documents')
              .doc(title.toLowerCase().replaceAll(' ', '_'))
              .get();
          final content = docRef.data()?['content'] as String? ??
              'Content not available';

          if (mounted) {
            showDialog(
              context: context,
              builder: (context) =>
                  AlertDialog(
                    title: Text(title),
                    content: SingleChildScrollView(
                      child: Text(content),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
            );
          }
        }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to load $title: $e')),
            );
          }
    }
  }
}