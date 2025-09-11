import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yenposapp/Global/customAll_keyboard.dart';
import 'package:yenposapp/Global/custom_sized_box.dart';

class PaymentOption extends StatelessWidget {
  final String amount;
  final String method;
  final bool isSelected;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode focusNode;

  const PaymentOption({
    super.key,
    required this.amount,
    required this.method,
    required this.isSelected,
    required this.controller,
    required this.onChanged,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final customkeyboardProvider =
        Provider.of<KeyboardProvider>(context, listen: false);
    if (amount == 'Custom') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
        child: CustomSizedBox(
          width: 160,
          child: GestureDetector(
            onTap: () {
              final index =
                  customkeyboardProvider.controllers.indexOf(controller);
              customkeyboardProvider.setIndex(index);

              FocusScope.of(context).requestFocus(focusNode);
            },
            child: AbsorbPointer(
              child: TextField(
                focusNode: focusNode,
                controller: controller,
                readOnly: true,
                showCursor: true,
                cursorColor: Colors.blueAccent,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  labelText: 'Enter Custom $method Amount',
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.blue[700] : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: isSelected ? Colors.blue[50] : Colors.grey[200],
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
        child: ElevatedButton(
          onPressed: () => onChanged(amount),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Colors.blue[600] : Colors.white,
            foregroundColor: isSelected ? Colors.white : Colors.blue[600],
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 25),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(
                color: isSelected ? Colors.blue[800]! : Colors.blue[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            elevation: isSelected ? 8 : 3,
            shadowColor: Colors.grey[400],
          ),
          child: Text(
            amount,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
  }
}
