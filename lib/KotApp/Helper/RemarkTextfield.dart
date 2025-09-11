import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../screens/kot_screen/global/globals.dart';

class RemarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const RemarkTextField({
    super.key,
    required this.controller,
    this.label = 'Remark',
    this.hint = 'Enter remark for cancellation',
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: kMaxRemarkLength,
      inputFormatters: [
        LengthLimitingTextInputFormatter(kMaxRemarkLength),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        border: const OutlineInputBorder(),
      ),
    );
  }
}
