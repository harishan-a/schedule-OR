// =============================================================================
// Formatters: Input Formatting Utilities
// =============================================================================
// This file contains text input formatters used throughout the application for
// consistent data formatting. Currently includes:
// - Phone number formatting (###)-###-####
//
// Usage:
//   TextField(
//     inputFormatters: [PhoneNumberFormatter()],
//   )
// =============================================================================

import 'package:flutter/services.dart';

/// A [TextInputFormatter] that formats phone numbers in the (###)-###-#### pattern
/// 
/// Input: Raw string of numbers
/// Output: Formatted string like (123)-456-7890
/// 
/// Example:
/// - Input "1234567890" becomes "(123)-456-7890"
/// - Input "12345" becomes "(123)-45"
/// 
/// Note: This formatter:
/// - Removes all non-digit characters from input
/// - Limits the number to 10 digits
/// - Automatically adds parentheses and hyphens
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove any characters that aren't digits
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Format the digits according to the pattern:
    // Less than 4 digits: (###
    // 4-6 digits: (###)-###
    // 7-10 digits: (###)-###-####
    if (digits.length <= 3) {
      digits = '($digits';
    } else if (digits.length <= 6) {
      digits = '(${digits.substring(0, 3)})-${digits.substring(3)}';
    } else if (digits.length <= 10) {
      digits = '(${digits.substring(0, 3)})-${digits.substring(3, 6)}-${digits.substring(6)}';
    } else {
      // Limit to 10 digits and maintain formatting
      digits = '(${digits.substring(0, 3)})-${digits.substring(3, 6)}-${digits.substring(6, 10)}';
    }

    // Return the formatted value with cursor at the end
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
