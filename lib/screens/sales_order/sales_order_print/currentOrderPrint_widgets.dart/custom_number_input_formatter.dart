import 'package:flutter/services.dart';

class CustomNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final regExp = RegExp(r'^[6-9][0-9]{0,9}$');
    if (newValue.text.isEmpty) {
      return newValue;
    }
    if (regExp.hasMatch(newValue.text)) {
      return newValue;
    } else if (newValue.text.length > 10) {
      return oldValue;
    }
    return oldValue;
  }
}
