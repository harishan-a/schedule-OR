import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';

/// Service for sending emails via SendGrid/Mailgun API.
/// Extracted from NotificationManager.
class EmailService {
  final _logger = Logger('EmailService');

  String? get _apiKey => dotenv.env['EMAIL_API_KEY'];
  String? get _fromAddress => dotenv.env['EMAIL_FROM_ADDRESS'];
  String? get _sendEndpoint => dotenv.env['EMAIL_SEND_ENDPOINT'];

  bool get isConfigured =>
      _apiKey != null && _fromAddress != null && _sendEndpoint != null;

  /// Send an email notification.
  Future<bool> sendEmail({
    required String toEmail,
    required String subject,
    required String htmlBody,
    String? textBody,
  }) async {
    if (!isConfigured) {
      _logger.warning('Email service not configured');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse(_sendEndpoint!),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'personalizations': [
            {
              'to': [
                {'email': toEmail}
              ],
              'subject': subject,
            }
          ],
          'from': {'email': _fromAddress},
          'content': [
            if (textBody != null) {'type': 'text/plain', 'value': textBody},
            {'type': 'text/html', 'value': htmlBody},
          ],
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 202) {
        _logger.info('Email sent to $toEmail');
        return true;
      } else {
        _logger
            .warning('Email failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      _logger.warning('Error sending email: $e');
      return false;
    }
  }

  /// Send a surgery notification email.
  Future<bool> sendSurgeryNotificationEmail({
    required String toEmail,
    required String patientName,
    required String surgeryType,
    required String notificationType,
    String? details,
  }) async {
    final subject = 'OR Scheduler: $notificationType - $surgeryType';
    final html = '''
    <h2>$notificationType</h2>
    <p><strong>Surgery:</strong> $surgeryType</p>
    <p><strong>Patient:</strong> $patientName</p>
    ${details != null ? '<p>$details</p>' : ''}
    <hr>
    <p style="color: #666; font-size: 12px;">This is an automated notification from OR Scheduler.</p>
    ''';

    return sendEmail(toEmail: toEmail, subject: subject, htmlBody: html);
  }
}
