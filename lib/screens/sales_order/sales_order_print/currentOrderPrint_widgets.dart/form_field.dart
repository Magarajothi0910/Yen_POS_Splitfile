import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenposapp/Global/customAll_keyboard.dart';

class StyledFormField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData icon;
  final String? hintText;
  final TextInputType keyboardType;
  final String? prefixText;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;

  const StyledFormField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.icon,
    this.hintText,
    this.keyboardType = TextInputType.text,
    this.prefixText,
    this.readOnly = false,
    this.onChanged,
    this.focusNode,
  });

  @override
  State<StyledFormField> createState() => _StyledFormFieldState();
}

class _StyledFormFieldState extends State<StyledFormField> {
  KeyboardProvider? customKeyboardProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ Safe to access provider here
    customKeyboardProvider =
        Provider.of<KeyboardProvider>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final index =
            customKeyboardProvider!.controllers.indexOf(widget.controller);
        if (index != -1) {
          customKeyboardProvider!.setIndex(index);
        }

        FocusScope.of(context).requestFocus(widget.focusNode);
      },
      child: AbsorbPointer(
        // 🔐 Prevent default keyboard input but allow focus/cursor
        child: TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          readOnly: widget.readOnly,
          keyboardType: widget.keyboardType,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
          decoration: InputDecoration(
            prefixText: widget.prefixText,
            labelText: widget.labelText,
            hintText: widget.hintText,
            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
            filled: true,
            fillColor: Colors.grey[100],
            prefixIcon: Icon(widget.icon, color: Colors.blueAccent),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Colors.blueAccent, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}
