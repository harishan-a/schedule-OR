import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for sending SMS notifications through Twilio API
///
/// Uses credentials from .env file:
/// - TWILIO_ACCOUNT_SID: Your Twilio account SID
/// - TWILIO_AUTH_TOKEN: Your Twilio auth token
/// - TWILIO_PHONE_NUMBER: Your Twilio phone number
class TwilioService {
  final _logger = Logger('TwilioService');

  // Twilio credentials from .env
  final String? _accountSid;
  final String? _authToken;
  final String? _twilioNumber;

  // Firebase auth for Cloud Functions authentication
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cloud Functions URL from environment
  final String _cloudFunctionUrl = dotenv.env['CLOUD_FUNCTION_URL'] ?? '';

  TwilioService()
      : _accountSid = dotenv.env['TWILIO_ACCOUNT_SID'],
        _authToken = dotenv.env['TWILIO_AUTH_TOKEN'],
        _twilioNumber = dotenv.env['TWILIO_PHONE_NUMBER'] {
    _logger.info(
        'TwilioService initialized with: ${_accountSid != null ? 'SID: YES' : 'SID: NO'}, ${_authToken != null ? 'Token: YES' : 'Token: NO'}, ${_twilioNumber != null ? 'Number: $_twilioNumber' : 'Number: NO'}');
  }

  /// Check if Twilio credentials are configured
  bool get isConfigured {
    final hasCredentials = _accountSid != null &&
        _authToken != null &&
        _twilioNumber != null &&
        _accountSid!.isNotEmpty &&
        _authToken!.isNotEmpty &&
        _twilioNumber!.isNotEmpty;

    if (!hasCredentials) {
      _logger.warning('Twilio credentials not fully configured.');
    }

    return hasCredentials;
  }

  /// Send SMS via Twilio
  Future<bool> sendSMS({
    required String toNumber,
    required String messageBody,
  }) async {
    try {
      _logger.info('Attempting to send SMS to: $toNumber');

      if (!isConfigured) {
        _logger.severe('Cannot send SMS: Twilio not configured');
        return false;
      }

      // Skip test numbers (containing 1234)
      if (toNumber.contains('1234')) {
        _logger.warning('Skipping test phone number: $toNumber');
        return false;
      }

      // Make sure to format the phone number correctly
      String formattedNumber =
          toNumber.toString().replaceAll(RegExp(r'[^\+\d]'), '');
      if (!formattedNumber.startsWith('+')) {
        formattedNumber = '+$formattedNumber';
        _logger.info('Added + prefix to phone number: $formattedNumber');
      }

      _logger.info('Using formatted phone number: $formattedNumber');

      // Skip the Firebase Cloud Function since it's returning 404 error
      // Go directly to Twilio API
      return await _sendDirectSMS(formattedNumber, messageBody);
    } catch (e) {
      _logger.severe('Error in sendSMS: $e');
      return false;
    }
  }

  /// Send SMS directly using Twilio API
  Future<bool> _sendDirectSMS(String toNumber, String messageBody) async {
    try {
      _logger.info('Sending SMS directly via Twilio API to $toNumber');

      if (!isConfigured) {
        _logger.severe('Cannot send direct SMS: Twilio not configured');
        return false;
      }

      // Make sure we have valid recipient and message
      if (toNumber.isEmpty) {
        _logger.severe('Cannot send SMS: Empty recipient number');
        return false;
      }

      // Skip test numbers (containing 1234)
      if (toNumber.contains('1234')) {
        _logger.warning('Skipping test phone number: $toNumber');
        return false;
      }

      if (messageBody.isEmpty) {
        _logger.warning('Sending SMS with empty message body');
      }

      // Construct Twilio API endpoint for sending SMS
      final twilioEndpoint =
          'https://api.twilio.com/2010-04-01/Accounts/$_accountSid/Messages.json';

      // Twilio requires Basic Auth with account SID and auth token
      final authString = base64Encode(utf8.encode('$_accountSid:$_authToken'));

      // Debug the URL and credentials being used
      _logger.info('Calling Twilio API at: $twilioEndpoint');

      // Make the HTTP request to Twilio
      final response = await http.post(
        Uri.parse(twilioEndpoint),
        headers: {
          'Authorization': 'Basic $authString',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'To': toNumber,
          'From': _twilioNumber!,
          'Body': messageBody,
        },
      );

      // Log the full response for debugging
      _logger.info(
          'Twilio API response: Status ${response.statusCode}, Body length: ${response.body.length}');

      // Check if the request was successful
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _logger.info('SMS sent successfully to $toNumber');
        return true;
      } else {
        // Parse the error message from Twilio
        try {
          final responseData = json.decode(response.body);
          final errorMessage =
              responseData['message'] as String? ?? 'No message provided';
          final errorCode = responseData['code']
              .toString(); // Convert to string in case it's a number

          _logger.severe('Twilio API error: [$errorCode] $errorMessage');
        } catch (e) {
          _logger.severe('Failed to parse Twilio error response: $e');
          _logger.severe('Raw response: ${response.body}');
        }

        return false;
      }
    } catch (e) {
      _logger.severe('Error sending direct SMS: $e');
      return false;
    }
  }
}
