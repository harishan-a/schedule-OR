import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'package:intl/intl.dart';
import 'twilio_service.dart';

/// Service for handling notifications related to surgeries
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TwilioService _twilioService = TwilioService();
  final _logger = Logger('NotificationService');

  final DateFormat _dateFormatter = DateFormat('EEEE, MMM d, yyyy');
  final DateFormat _timeFormatter = DateFormat('h:mm a');

  /// Sends an SMS notification for a newly scheduled surgery
  Future<bool> sendScheduledNotification(String surgeryId) async {
    try {
      final surgeryDoc =
          await _firestore.collection('surgeries').doc(surgeryId).get();
      if (!surgeryDoc.exists) {
        _logger
            .warning('Cannot send scheduled notification: Surgery not found');
        return false;
      }

      final surgeryData = surgeryDoc.data()!;
      final String surgeryType = surgeryData['surgeryType'] ?? 'Surgery';
      final DateTime startTime =
          (surgeryData['startTime'] as Timestamp).toDate();

      final String formattedDate = _dateFormatter.format(startTime);
      final String formattedTime = _timeFormatter.format(startTime);

      // Get phone numbers for all involved personnel
      final List<String> phoneNumbers =
          await _getPersonnelPhoneNumbers(surgeryData);

      // Message template
      final String message =
          'Your $surgeryType is scheduled for $formattedDate at $formattedTime. Please check your app for details.';

      // Send SMS to each recipient
      bool allSuccessful = true;
      for (String phoneNumber in phoneNumbers) {
        final success = await _sendSMSIfEnabled(
          phoneNumber: phoneNumber,
          messageBody: message,
          notificationType: 'scheduled',
        );
        if (!success) allSuccessful = false;
      }

      return allSuccessful;
    } catch (e) {
      _logger.severe('Error sending scheduled notification: $e');
      return false;
    }
  }

  /// Sends a reminder before an upcoming surgery
  Future<bool> sendApproachingNotification(String surgeryId,
      {required int hoursBeforeSurgery}) async {
    try {
      final surgeryDoc =
          await _firestore.collection('surgeries').doc(surgeryId).get();
      if (!surgeryDoc.exists) {
        _logger
            .warning('Cannot send approaching notification: Surgery not found');
        return false;
      }

      final surgeryData = surgeryDoc.data()!;
      final String surgeryType = surgeryData['surgeryType'] ?? 'Surgery';
      final DateTime startTime =
          (surgeryData['startTime'] as Timestamp).toDate();

      final String formattedDate = _dateFormatter.format(startTime);
      final String formattedTime = _timeFormatter.format(startTime);

      final String hourText = hoursBeforeSurgery == 1 ? 'hour' : 'hours';

      // Get phone numbers for all involved personnel
      final List<String> phoneNumbers =
          await _getPersonnelPhoneNumbers(surgeryData);

      // Message template
      final String message =
          'Reminder: You have a $surgeryType scheduled in $hoursBeforeSurgery $hourText (on $formattedDate at $formattedTime). Please prepare accordingly.';

      // Send SMS to each recipient
      bool allSuccessful = true;
      for (String phoneNumber in phoneNumbers) {
        final success = await _sendSMSIfEnabled(
          phoneNumber: phoneNumber,
          messageBody: message,
          notificationType: 'approaching',
        );
        if (!success) allSuccessful = false;
      }

      return allSuccessful;
    } catch (e) {
      _logger.severe('Error sending approaching notification: $e');
      return false;
    }
  }

  /// Sends a notification when a surgery's details are updated
  Future<bool> sendUpdateNotification(String surgeryId,
      Map<String, dynamic> oldData, Map<String, dynamic> newData) async {
    try {
      if (!newData.containsKey('surgeryType') ||
          !newData.containsKey('startTime')) {
        _logger.warning(
            'Cannot send update notification: Missing required fields');
        return false;
      }

      final String surgeryType = newData['surgeryType'] ?? 'Surgery';
      final DateTime oldStartTime =
          (oldData['startTime'] as Timestamp).toDate();
      final DateTime newStartTime =
          (newData['startTime'] as Timestamp).toDate();

      final String oldFormattedDate = _dateFormatter.format(oldStartTime);
      final String oldFormattedTime = _timeFormatter.format(oldStartTime);
      final String newFormattedDate = _dateFormatter.format(newStartTime);
      final String newFormattedTime = _timeFormatter.format(newStartTime);

      // Get phone numbers for all involved personnel
      final List<String> phoneNumbers =
          await _getPersonnelPhoneNumbers(newData);

      // Message template
      String message =
          'Notice: Your $surgeryType scheduled for $oldFormattedDate at $oldFormattedTime has been updated.';

      // Add specifics about what changed
      if (oldStartTime != newStartTime) {
        message += ' New time: $newFormattedDate at $newFormattedTime.';
      }

      if (oldData['room'] != newData['room']) {
        message += ' Room updated to ${newData['room']}.';
      }

      message += ' Check your app for more details.';

      // Send SMS to each recipient
      bool allSuccessful = true;
      for (String phoneNumber in phoneNumbers) {
        final success = await _sendSMSIfEnabled(
          phoneNumber: phoneNumber,
          messageBody: message,
          notificationType: 'update',
        );
        if (!success) allSuccessful = false;
      }

      return allSuccessful;
    } catch (e) {
      _logger.severe('Error sending update notification: $e');
      return false;
    }
  }

  /// Sends a notification when a surgery's status changes
  Future<bool> sendStatusChangeNotification(
      String surgeryId, String oldStatus, String newStatus) async {
    try {
      final surgeryDoc =
          await _firestore.collection('surgeries').doc(surgeryId).get();
      if (!surgeryDoc.exists) {
        _logger.warning(
            'Cannot send status change notification: Surgery not found');
        return false;
      }

      final surgeryData = surgeryDoc.data()!;
      final String surgeryType = surgeryData['surgeryType'] ?? 'Surgery';
      final DateTime startTime =
          (surgeryData['startTime'] as Timestamp).toDate();

      final String formattedDate = _dateFormatter.format(startTime);
      final String formattedTime = _timeFormatter.format(startTime);

      // Get phone numbers for all involved personnel
      final List<String> phoneNumbers =
          await _getPersonnelPhoneNumbers(surgeryData);

      // Message template
      final String message =
          'Update: The status of your $surgeryType at $formattedDate, $formattedTime is now "$newStatus". Check your app for details.';

      // Send SMS to each recipient
      bool allSuccessful = true;
      for (String phoneNumber in phoneNumbers) {
        final success = await _sendSMSIfEnabled(
          phoneNumber: phoneNumber,
          messageBody: message,
          notificationType: 'status',
        );
        if (!success) allSuccessful = false;
      }

      return allSuccessful;
    } catch (e) {
      _logger.severe('Error sending status change notification: $e');
      return false;
    }
  }

  /// Helper method to get phone numbers of all personnel involved with a surgery
  Future<List<String>> _getPersonnelPhoneNumbers(
      Map<String, dynamic> surgeryData) async {
    final List<String> phoneNumbers = [];

    // Add surgeon's phone number
    final String surgeon = surgeryData['surgeon'] ?? '';
    if (surgeon.isNotEmpty) {
      final String? surgeonPhone = await _getUserPhoneNumber(surgeon);
      if (surgeonPhone != null) phoneNumbers.add(surgeonPhone);
    }

    // Add nurses' phone numbers
    final List<String> nurses = List<String>.from(surgeryData['nurses'] ?? []);
    for (String nurse in nurses) {
      final String? nursePhone = await _getUserPhoneNumber(nurse);
      if (nursePhone != null) phoneNumbers.add(nursePhone);
    }

    // Add technologists' phone numbers
    final List<String> technologists =
        List<String>.from(surgeryData['technologists'] ?? []);
    for (String tech in technologists) {
      final String? techPhone = await _getUserPhoneNumber(tech);
      if (techPhone != null) phoneNumbers.add(techPhone);
    }

    return phoneNumbers;
  }

  /// Helper method to get a user's phone number by their display name
  Future<String?> _getUserPhoneNumber(String userName) async {
    try {
      // First try by exact match
      var querySnapshot = await _firestore
          .collection('users')
          .where('fullName', isEqualTo: userName)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data();
        return userData['phoneNumber'];
      }

      // Try by firstName and lastName combination
      final nameParts = userName.split(' ');
      if (nameParts.length >= 2) {
        final firstName = nameParts[0];
        final lastName = nameParts.sublist(1).join(' ');

        querySnapshot = await _firestore
            .collection('users')
            .where('firstName', isEqualTo: firstName)
            .where('lastName', isEqualTo: lastName)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final userData = querySnapshot.docs.first.data();
          return userData['phoneNumber'];
        }
      }

      // Special handling for role-prefixed names (like "Nurse John Smith")
      if (userName.startsWith("Nurse ") ||
          userName.startsWith("Doctor ") ||
          userName.startsWith("Technologist ") ||
          userName.startsWith("Dr. ")) {
        String actualName;
        if (userName.startsWith("Nurse ")) {
          actualName = userName.substring("Nurse ".length);
        } else if (userName.startsWith("Doctor ")) {
          actualName = userName.substring("Doctor ".length);
        } else if (userName.startsWith("Technologist ")) {
          actualName = userName.substring("Technologist ".length);
        } else {
          // Dr.
          actualName = userName.substring("Dr. ".length);
        }

        _logger.info('Trying phone lookup without role prefix: $actualName');

        // Try fullName with actual name
        querySnapshot = await _firestore
            .collection('users')
            .where('fullName', isEqualTo: actualName)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final userData = querySnapshot.docs.first.data();
          return userData['phoneNumber'];
        }

        // Try firstName/lastName with actual name
        final actualNameParts = actualName.split(' ');
        if (actualNameParts.length >= 2) {
          final firstName = actualNameParts[0];
          final lastName = actualNameParts.sublist(1).join(' ');

          querySnapshot = await _firestore
              .collection('users')
              .where('firstName', isEqualTo: firstName)
              .where('lastName', isEqualTo: lastName)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            final userData = querySnapshot.docs.first.data();
            return userData['phoneNumber'];
          }
        }

        // Try with just the first name as a fallback
        querySnapshot = await _firestore
            .collection('users')
            .where('firstName', isEqualTo: actualNameParts[0])
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final userData = querySnapshot.docs.first.data();
          return userData['phoneNumber'];
        }
      }

      // Original fallback - try with just the first name
      final firstName = userName.split(' ').first;
      querySnapshot = await _firestore
          .collection('users')
          .where('firstName', isEqualTo: firstName)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data();
        return userData['phoneNumber'];
      }

      _logger.warning('Could not find phone number for user $userName');
      return null;
    } catch (e) {
      _logger.warning('Error getting phone number for $userName: $e');
      return null;
    }
  }

  /// Helper method to check user notification preferences before sending SMS
  Future<bool> _sendSMSIfEnabled({
    required String phoneNumber,
    required String messageBody,
    required String notificationType,
  }) async {
    try {
      // Log for debugging
      _logger
          .info('Attempting to send SMS to $phoneNumber for $notificationType');

      // Format the phone number properly
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

      // Send the SMS directly without checking preferences
      // (Firebase functions will handle the permission checks)
      final success = await _twilioService.sendSMS(
        toNumber: formattedNumber,
        messageBody: messageBody,
      );

      _logger.info('SMS send result for $formattedNumber: $success');
      return success;
    } catch (e) {
      _logger.severe('Error sending SMS: $e');
      return false;
    }
  }
}
