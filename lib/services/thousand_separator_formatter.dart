import 'package:flutter/services.dart';

/// A [TextInputFormatter] that automatically inserts dot (.) as
/// thousand separator while the user types a number.
///
/// Only digits are kept internally; dots are purely visual.
/// To get the raw numeric value, strip non-digits:
/// ```dart
/// int value = int.parse(controller.text.replaceAll('.', ''));
/// ```
class ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Strip everything except digits.
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    // Format with dot separator.
    final formatted = _formatWithDots(digitsOnly);

    // Calculate new cursor position.
    // Count how many digits are before the cursor in the new (unformatted) value.
    final newCursorOffset = newValue.selection.baseOffset;
    int digitsBeforeCursor = 0;
    for (int i = 0; i < newCursorOffset && i < newValue.text.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(newValue.text[i])) {
        digitsBeforeCursor++;
      }
    }

    // Find the position in the formatted string that corresponds to
    // digitsBeforeCursor digits.
    int formattedCursor = 0;
    int digitsSeen = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (digitsSeen == digitsBeforeCursor) break;
      if (formatted[i] != '.') {
        digitsSeen++;
      }
      formattedCursor = i + 1;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: formattedCursor.clamp(0, formatted.length),
      ),
    );
  }

  static String _formatWithDots(String digits) {
    final buffer = StringBuffer();
    final length = digits.length;
    for (int i = 0; i < length; i++) {
      buffer.write(digits[i]);
      final remaining = length - 1 - i;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }

  /// Helper to format a plain number into dot-separated string.
  static String format(int value) {
    if (value == 0) return '0';
    return _formatWithDots(value.toString());
  }
}
