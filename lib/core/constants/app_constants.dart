class AppConstants {
  AppConstants._();

  // Firestore collection names
  static const String surgeriesCollection = 'surgeries';
  static const String usersCollection = 'users';
  static const String equipmentCollection = 'equipment';
  static const String notificationsCollection = 'notifications';
  static const String settingsCollection = 'settings';

  // App config
  static const String appName = 'ORScheduler';
  static const int defaultSurgeryDurationMinutes = 30;
  static const int maxSurgeryDurationMinutes = 720;
  static const int reminderIntervalMinutes = 15;
}
