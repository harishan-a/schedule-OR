import 'package:flutter/services.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove any characters that aren't digits
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.length <= 3) {
      digits = '($digits';
    } else if (digits.length <= 6) {
      digits = '(${digits.substring(0, 3)})-${digits.substring(3)}';
    } else if (digits.length <= 10) {
      digits = '(${digits.substring(0, 3)})-${digits.substring(3, 6)}-${digits.substring(6)}';
    } else {
      digits = '(${digits.substring(0, 3)})-${digits.substring(3, 6)}-${digits.substring(6, 10)}';
    }

    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
