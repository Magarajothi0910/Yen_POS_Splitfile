import 'package:flutter/services.dart';

class CancelQuantityValidator extends TextInputFormatter {
  final double maxQuantity;

  CancelQuantityValidator(this.maxQuantity);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    double enteredQty = double.tryParse(newValue.text) ?? 0;

    if (enteredQty > maxQuantity) {
      return oldValue; // Prevent the user from entering a quantity larger than available
    }

    return newValue; // Accept the valid value
  }
}

class NoLeadingZeroAndZeroTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue; // Allow empty input
    }

    if (newValue.text == '0') {
      return oldValue; // Disallow the input of 0
    }

    if (newValue.text.length > 1 && newValue.text.startsWith('0')) {
      return oldValue; // Disallow numbers that start with 0, like 016
    }
    return newValue; // Accept the new value
  }
}
