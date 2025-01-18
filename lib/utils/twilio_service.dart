import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:twilio_flutter/twilio_flutter.dart';

class TwilioService {
  late TwilioFlutter twilioFlutter;

  TwilioService() {
    twilioFlutter = TwilioFlutter(
      accountSid: dotenv.env['TWILIO_ACCOUNT_SID']!,
      authToken: dotenv.env['TWILIO_AUTH_TOKEN']!,
      twilioNumber: dotenv.env['TWILIO_NUMBER']!,
    );
  }

  Future<void> sendSMS({
    required String toNumber,
    required String messageBody,
  }) async {
    try {
      print('Attempting to send SMS to $toNumber with message: $messageBody');
      final response = await twilioFlutter.sendSMS(
        toNumber: toNumber,
        messageBody: messageBody,
      );

      if (response.responseState == ResponseState.SUCCESS) {
        print('SMS sent successfully to $toNumber');
      } else {
        print('Failed to send SMS: ${response.errorData?.message}');
      }
    } catch (e) {
      print('Error sending SMS: $e');
    }
  }
}
